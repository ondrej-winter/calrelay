import Foundation

public enum ReconcileCalendarsError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidSettings(String)
    case calendarNotFound(CalendarSelector)
    case calendarAmbiguous(CalendarSelector)
    case calendarReadOnly(CalendarReference)

    public var description: String {
        switch self {
        case .invalidSettings(let message):
            "Invalid settings: \(message)"
        case .calendarNotFound(let selector):
            "Calendar not found: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .calendarAmbiguous(let selector):
            "Calendar selector is ambiguous: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .calendarReadOnly(let calendar):
            "Calendar is read-only: \(calendar.sourceTitle) / \(calendar.title)."
        }
    }
}

public struct ReconcileCalendarsUseCase: Sendable {
    private let calendarStore: CalendarStorePort

    public init(calendarStore: CalendarStorePort) {
        self.calendarStore = calendarStore
    }

    public func dryRun(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationPlan {
        try await plan(settings: settings, now: now).plan
    }

    /// Explains inclusion/exclusion decisions for every candidate hub and work event in the
    /// sync window. This is diagnostic-only and does not affect reconciliation planning.
    public func explain(settings: CalendarRelaySettings, now: Date) async throws -> [EventExplanation] {
        try Task.checkCancellation()
        try validate(settings)

        let calendars = try await calendarStore.listCalendars()
        try Task.checkCancellation()

        let hubCalendar = try resolve(settings.hubCalendar, from: calendars)
        let workCalendars = try settings.workCalendars.map { workCalendar in
            WorkCalendarResolution(
                settings: workCalendar,
                calendar: try resolve(workCalendar.calendar, from: calendars)
            )
        }

        let syncWindowEnd = now.addingTimeInterval(Double(settings.syncWindowDays) * 24 * 60 * 60)

        var explanations: [EventExplanation] = []

        let hubEvents = try await calendarStore.events(in: hubCalendar.reference, from: now, to: syncWindowEnd)
        try Task.checkCancellation()
        explanations.append(contentsOf: hubEvents.map(explanation(for:)))

        for workCalendar in workCalendars {
            try Task.checkCancellation()
            let events = try await calendarStore.events(
                in: workCalendar.calendar.reference,
                from: now,
                to: syncWindowEnd
            )
            explanations.append(contentsOf: events.map(explanation(for:)))
        }

        return explanations
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
            try await calendarStore.deleteEvent(event)
        }

        return plannedRun.plan
    }

    private func plan(settings: CalendarRelaySettings, now: Date) async throws -> PlannedRun {
        try Task.checkCancellation()
        try validate(settings)

        let calendars = try await calendarStore.listCalendars()
        try Task.checkCancellation()

        let hubCalendar = try resolve(settings.hubCalendar, from: calendars)
        let workCalendars = try settings.workCalendars.map { workCalendar in
            WorkCalendarResolution(
                settings: workCalendar,
                calendar: try resolve(workCalendar.calendar, from: calendars)
            )
        }

        let syncWindowEnd = now.addingTimeInterval(Double(settings.syncWindowDays) * 24 * 60 * 60)

        let managedPrefixes = Set(settings.workCalendars.map(\.prefix) + [settings.personalPrefix])

        let hubEvents = try await calendarStore.events(
            in: hubCalendar.reference,
            from: now,
            to: syncWindowEnd
        )
        try Task.checkCancellation()

        var workEventsByCalendarID: [String: [EventSnapshot]] = [:]
        for workCalendar in workCalendars {
            try Task.checkCancellation()
            workEventsByCalendarID[workCalendar.calendar.snapshot.id] = try await calendarStore.events(
                in: workCalendar.calendar.reference,
                from: now,
                to: syncWindowEnd
            )
        }

        let expectedHubEvents = workCalendars.flatMap { workCalendar in
            WorkToHubProjector.project(
                events: workEventsByCalendarID[workCalendar.calendar.snapshot.id, default: []].filter { event in
                    !isRelayedWorkBlocker(event, managedPrefixes: managedPrefixes)
                },
                from: workCalendar.settings,
                to: hubCalendar.reference
            )
        }

        let workTargets = workCalendars.map { workCalendar in
            WorkCalendarProjectionTarget(
                settings: workCalendar.settings,
                calendar: workCalendar.calendar.reference
            )
        }
        let expectedHubEventSnapshots = expectedHubEvents.map { projectedEvent in
            snapshot(for: projectedEvent, idPrefix: "expected-hub")
        }
        let expectedWorkEvents = HubToWorkProjector.project(
            hubEvents: hubEvents + expectedHubEventSnapshots,
            to: workTargets,
            personalPrefix: settings.personalPrefix
        )

        let existingEvents = hubEvents + workEventsByCalendarID.values.flatMap { $0 }
        let reconciliationPlan = ReconciliationPlanner.plan(
            expected: expectedHubEvents + expectedWorkEvents,
            existing: existingEvents,
            managedPrefixes: managedPrefixes
        )

        return PlannedRun(
            plan: reconciliationPlan,
            calendarsByID: Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
        )
    }

    private func snapshot(for event: ProjectedEvent, idPrefix: String) -> EventSnapshot {
        EventSnapshot(
            id: "\(idPrefix)-\(event.destinationCalendar.id)-\(event.title)-\(event.start.timeIntervalSince1970)-\(event.end.timeIntervalSince1970)",
            calendar: event.destinationCalendar,
            title: event.title,
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            availability: .busy,
            status: .confirmed
        )
    }

    private func explanation(for event: EventSnapshot) -> EventExplanation {
        EventExplanation(
            calendar: event.calendar,
            title: event.title,
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            availability: event.availability,
            status: event.status,
            reason: EventInclusionPolicy.evaluate(event)
        )
    }

    private func isRelayedWorkBlocker(_ event: EventSnapshot, managedPrefixes: Set<String>) -> Bool {
        hasBracketedPrefix(event.title) || isManagedProjection(event, managedPrefixes: managedPrefixes)
    }

    private func hasBracketedPrefix(_ title: String) -> Bool {
        title.hasPrefix("[") && title.contains("]")
    }

    private func isManagedProjection(_ event: EventSnapshot, managedPrefixes: Set<String>) -> Bool {
        managedPrefixes.contains { prefix in
            event.title.hasPrefix(prefix)
        }
    }

    private func validate(_ settings: CalendarRelaySettings) throws {
        do {
            try SettingsValidator.validate(settings)
        } catch let error as SettingsValidationError {
            throw ReconcileCalendarsError.invalidSettings(error.description)
        }
    }

    private func resolve(_ selector: CalendarSelector, from calendars: [CalendarSnapshot]) throws -> ResolvedCalendar {
        let matches = calendars.filter { calendar in
            calendar.sourceTitle == selector.sourceTitle && calendar.title == selector.calendarTitle
        }

        guard let match = matches.first else {
            throw ReconcileCalendarsError.calendarNotFound(selector)
        }

        guard matches.count == 1 else {
            throw ReconcileCalendarsError.calendarAmbiguous(selector)
        }

        return ResolvedCalendar(snapshot: match)
    }

    private func validateWritableCalendars(
        for plan: ReconciliationPlan,
        calendarsByID: [String: CalendarSnapshot]
    ) throws {
        for event in plan.creates {
            try validateWritable(event.destinationCalendar, calendarsByID: calendarsByID)
        }

        for event in plan.deletes {
            try validateWritable(event.calendar, calendarsByID: calendarsByID)
        }
    }

    private func validateWritable(
        _ calendar: CalendarReference,
        calendarsByID: [String: CalendarSnapshot]
    ) throws {
        guard calendarsByID[calendar.id]?.isWritable == true else {
            throw ReconcileCalendarsError.calendarReadOnly(calendar)
        }
    }
}

private struct PlannedRun {
    let plan: ReconciliationPlan
    let calendarsByID: [String: CalendarSnapshot]
}

private struct WorkCalendarResolution {
    let settings: WorkCalendarSettings
    let calendar: ResolvedCalendar
}

private struct ResolvedCalendar {
    let snapshot: CalendarSnapshot

    var reference: CalendarReference {
        CalendarReference(id: snapshot.id, title: snapshot.title, sourceTitle: snapshot.sourceTitle)
    }
}