import Foundation

public enum ReconcileCalendarsError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidSettings(String)
    case calendarNotFound(CalendarSelector)
    case calendarAmbiguous(CalendarSelector)
    case calendarReadOnly(CalendarIdentity)

    public var description: String {
        switch self {
        case .invalidSettings(let message): "Invalid settings: \(message)"
        case .calendarNotFound(let selector): "Calendar not found: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .calendarAmbiguous(let selector):
            "Calendar selector is ambiguous: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .calendarReadOnly(let calendar): "Calendar is read-only: \(calendar.sourceTitle) / \(calendar.title)."
        }
    }
}

public struct ReconcileCalendarsUseCase: Sendable {
    private let calendarStore: CalendarStorePort

    public init(calendarStore: CalendarStorePort) { self.calendarStore = calendarStore }

    public func dryRun(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationPlan {
        try await plan(settings: settings, now: now).plan
    }

    /// Explains inclusion/exclusion decisions for every candidate hub and work event in the
    /// sync window. This is diagnostic-only and does not affect reconciliation planning.
    public func explain(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationExplanation {
        let context = try await loadRunContext(settings: settings, now: now)
        let candidates = (context.hubEvents + context.workEventsByCalendarID.values.flatMap { $0 }).map(
            candidateExplanation(for:))

        return ReconciliationExplanation(candidates: candidates)
    }

    public func apply(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationPlan {
        let plannedRun = try await plan(settings: settings, now: now)

        try validateWritableCalendars(for: plannedRun.plan, calendarsByID: plannedRun.calendarsByID)

        for event in plannedRun.plan.creates {
            try Task.checkCancellation()
            try await calendarStore.createEvent(event)
        }

        for event in plannedRun.plan.deletes {
            try Task.checkCancellation()
            try await calendarStore.deleteEvent(event.identity)
        }

        return plannedRun.plan
    }

    private func plan(settings: CalendarRelaySettings, now: Date) async throws -> PlannedRun {
        let context = try await loadRunContext(settings: settings, now: now)
        let titlePolicy = ManagedEventTitlePolicy(managedPrefixes: context.managedPrefixes)

        let expectedHubEvents = context.workCalendars.flatMap { workCalendar in
            WorkToHubProjector.project(
                events: context.workEvents(for: workCalendar).filter { event in
                    !titlePolicy.isRelayedWorkBlocker(event)
                }, from: workCalendar.settings, to: context.hubCalendar.reference)
        }

        let workTargets = context.workCalendars.map { workCalendar in
            WorkCalendarProjectionTarget(settings: workCalendar.settings, calendar: workCalendar.calendar.reference)
        }
        let expectedHubCalendarEvents = expectedHubEvents.map { calendarEventProjection in
            calendarEvent(for: calendarEventProjection, idPrefix: "expected-hub")
        }
        let expectedWorkEvents = HubToWorkProjector.project(
            hubEvents: context.hubEvents + expectedHubCalendarEvents, to: workTargets,
            personalPrefix: settings.personalPrefix)

        let hubPlan = ReconciliationPlanner.plan(
            expected: expectedHubEvents, existing: context.hubEvents, managedPrefixes: context.managedPrefixes)
        let workPlan = ReconciliationPlanner.plan(expected: expectedWorkEvents, existing: context.allWorkEvents) {
            event in titlePolicy.isRelayedWorkBlocker(event)
        }
        let reconciliationPlan = ReconciliationPlan(
            creates: hubPlan.creates + workPlan.creates, deletes: hubPlan.deletes + workPlan.deletes)

        return PlannedRun(plan: reconciliationPlan, calendarsByID: context.calendarsByID)
    }

    private func loadRunContext(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationRunContext {
        try Task.checkCancellation()
        try validate(settings)

        let calendars = try await calendarStore.listCalendars()
        try Task.checkCancellation()

        let hubCalendar = try resolve(settings.hubCalendar.calendar, from: calendars)
        let workCalendars = try settings.workCalendars.map { workCalendar in
            WorkCalendarResolution(
                settings: workCalendar, calendar: try resolve(workCalendar.calendar, from: calendars))
        }

        let syncWindowEnd = now.addingTimeInterval(Double(settings.syncWindowDays) * 24 * 60 * 60)
        let managedPrefixes = Set(settings.workCalendars.map(\.prefix) + [settings.personalPrefix])

        let hubEvents = try await calendarStore.events(in: hubCalendar.reference, from: now, to: syncWindowEnd)
        try Task.checkCancellation()

        var workEventsByCalendarID: [String: [CalendarEvent]] = [:]
        for workCalendar in workCalendars {
            try Task.checkCancellation()
            workEventsByCalendarID[workCalendar.calendar.snapshot.id] = try await calendarStore.events(
                in: workCalendar.calendar.reference, from: now, to: syncWindowEnd)
        }

        return ReconciliationRunContext(
            hubCalendar: hubCalendar, workCalendars: workCalendars, managedPrefixes: managedPrefixes,
            hubEvents: hubEvents, workEventsByCalendarID: workEventsByCalendarID,
            calendarsByID: Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) }))
    }

    private func calendarEvent(for event: CalendarEventProjection, idPrefix: String) -> CalendarEvent {
        CalendarEvent(
            id:
                "\(idPrefix)-\(event.destinationCalendar.id)-\(event.title)-\(event.start.timeIntervalSince1970)-\(event.end.timeIntervalSince1970)",
            calendar: event.destinationCalendar, title: event.title, start: event.start, end: event.end,
            isAllDay: event.isAllDay, availability: .busy, status: .confirmed)
    }

    private func candidateExplanation(for event: CalendarEvent) -> CandidateEventExplanation {
        CandidateEventExplanation(event: event, inclusion: EventInclusionPolicy.evaluate(event))
    }

    private func validate(_ settings: CalendarRelaySettings) throws {
        do { try SettingsValidator.validate(settings) } catch let error as SettingsValidationError {
            throw ReconcileCalendarsError.invalidSettings(error.description)
        }
    }

    private func resolve(_ selector: CalendarSelector, from calendars: [RelayCalendar]) throws -> ResolvedCalendar {
        let matches = calendars.filter { calendar in
            calendar.sourceTitle == selector.sourceTitle && calendar.title == selector.calendarTitle
        }

        guard let match = matches.first else { throw ReconcileCalendarsError.calendarNotFound(selector) }

        guard matches.count == 1 else { throw ReconcileCalendarsError.calendarAmbiguous(selector) }

        return ResolvedCalendar(snapshot: match)
    }

    private func validateWritableCalendars(for plan: ReconciliationPlan, calendarsByID: [String: RelayCalendar]) throws
    {
        for event in plan.creates { try validateWritable(event.destinationCalendar, calendarsByID: calendarsByID) }

        for event in plan.deletes { try validateWritable(event.calendar, calendarsByID: calendarsByID) }
    }

    private func validateWritable(_ calendar: CalendarIdentity, calendarsByID: [String: RelayCalendar]) throws {
        guard calendarsByID[calendar.id]?.isWritable == true else {
            throw ReconcileCalendarsError.calendarReadOnly(calendar)
        }
    }
}
