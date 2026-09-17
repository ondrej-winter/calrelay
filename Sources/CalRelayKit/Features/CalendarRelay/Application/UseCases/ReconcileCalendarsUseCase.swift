import Foundation

public enum ReconcileCalendarsError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidSettings(String)
    case migrationPending
    case accessPreflightFailed([CalendarAccessPreflightIssue])

    public var description: String {
        switch self {
        case .invalidSettings(let message): "Invalid settings: \(message)"
        case .migrationPending:
            "Ordinary reconciliation is blocked while legacyMarkers is nonempty. Run explicit legacy cleanup first."
        case .accessPreflightFailed(let issues): issues.map(\.description).joined(separator: "\n")
        }
    }
}

public struct ReconcileCalendarsUseCase: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort
    private let calendar: Calendar

    public init(
        authorizationStatus: any CalendarAuthorizationStatusPort, calendarStore: any CalendarStorePort,
        calendar: Calendar = .current
    ) {
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
        self.calendar = calendar
    }

    public func dryRun(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationPlan {
        try await dryRunResult(settings: settings, now: now).plan
    }

    public func dryRunResult(settings: CalendarRelaySettings, now: Date) async throws -> OrdinaryReconciliationResult {
        try await plan(settings: settings, now: now)
    }

    /// Explains inclusion/exclusion decisions for every candidate hub and work event in the
    /// sync window. This is diagnostic-only and does not affect reconciliation planning.
    public func explain(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationExplanation {
        let context = try await loadRunContext(settings: settings, now: now)
        let candidates = (context.hubEvents + context.allWorkEvents).map(candidateExplanation(for:))

        return ReconciliationExplanation(candidates: candidates)
    }

    public func apply(
        settings: CalendarRelaySettings, now: Date,
        onConfirmation: @escaping @Sendable (CalendarMutationConfirmation) async -> Void = { _ in }
    ) async throws -> ReconciliationPlan {
        try await applyResult(settings: settings, now: now, onConfirmation: onConfirmation).plan
    }

    public func applyResult(
        settings: CalendarRelaySettings, now: Date,
        onConfirmation: @escaping @Sendable (CalendarMutationConfirmation) async -> Void = { _ in }
    ) async throws -> OrdinaryReconciliationResult {
        let plannedRun = try await plan(settings: settings, now: now)
        _ = try await CalendarMutationExecutor(calendarStore: calendarStore).execute(
            plannedRun.actions, onConfirmation: onConfirmation)

        return plannedRun
    }

    private func plan(settings: CalendarRelaySettings, now: Date) async throws -> OrdinaryReconciliationResult {
        let context = try await loadRunContext(settings: settings, now: now)
        let titlePolicy = ManagedEventTitlePolicy(managedPrefixes: context.managedPrefixes)

        let expectedHubEvents = context.workCalendars.flatMap { workCalendar in
            WorkToHubProjector.project(
                events: context.workEvents(for: workCalendar).filter { event in !titlePolicy.isRelayedWorkBlocker(event)
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
        let shouldDeleteWorkEvent: (CalendarEvent) -> Bool = titlePolicy.isRelayedWorkBlocker
        let workPlan = ReconciliationPlanner.plan(
            expected: expectedWorkEvents, existing: context.allWorkEvents, shouldDeleteStaleEvent: shouldDeleteWorkEvent
        )
        let reconciliationPlan = ReconciliationPlan(
            creates: hubPlan.creates + workPlan.creates, deletes: hubPlan.deletes + workPlan.deletes)

        return OrdinaryReconciliationResult(
            plan: reconciliationPlan, actions: ordinaryActions(for: reconciliationPlan, context: context))
    }

    private func loadRunContext(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationRunContext {
        try Task.checkCancellation()
        try validate(settings)

        let window = OrdinaryReconciliationWindow.calculate(
            referenceDate: now, calendar: calendar, syncWindowDays: settings.syncWindowDays)
        let preflight = CalendarAccessPreflightUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore)
        let preflightResult = try await preflight.run(settings: settings, window: window)
        let snapshot: CalendarAccessPreflightSnapshot
        switch preflightResult {
        case .ready(let readySnapshot): snapshot = readySnapshot
        case .failed(let issues): throw ReconcileCalendarsError.accessPreflightFailed(issues)
        }
        try Task.checkCancellation()

        guard let hubSnapshot = snapshot.calendars.first(where: { $0.role == .hub }) else {
            throw ReconcileCalendarsError.accessPreflightFailed([
                .calendarMissing(role: .hub, selector: settings.hubCalendar.calendar)
            ])
        }
        let hubCalendar = ResolvedCalendar(reference: hubSnapshot.calendar)
        let workCalendars: [WorkCalendarResolution] = settings.workCalendars.enumerated().compactMap { entry in
            let (index, workCalendar) = entry
            let role = ConfiguredCalendarRole.work(name: workCalendar.name, declarationIndex: index)
            guard let calendarSnapshot = snapshot.calendars.first(where: { $0.role == role }) else { return nil }
            return WorkCalendarResolution(
                settings: workCalendar, calendar: ResolvedCalendar(reference: calendarSnapshot.calendar),
                events: calendarSnapshot.events)
        }
        let managedPrefixes = Set(settings.workCalendars.map(\.prefix) + [settings.personalPrefix])

        return ReconciliationRunContext(
            hubCalendar: hubCalendar, workCalendars: workCalendars, managedPrefixes: managedPrefixes,
            hubEvents: hubSnapshot.events)
    }

    private func calendarEvent(for event: CalendarEventProjection, idPrefix: String) -> CalendarEvent {
        CalendarEvent(
            id: event.destinationCalendar.id.syntheticEventReference(
                idPrefix: idPrefix, title: event.title, start: event.start, end: event.end),
            calendar: event.destinationCalendar, title: event.title, start: event.start, end: event.end,
            isAllDay: event.isAllDay, availability: .busy, status: .confirmed)
    }

    private func ordinaryActions(for plan: ReconciliationPlan, context: ReconciliationRunContext)
        -> [CalendarMutationAction]
    {
        var actions: [CalendarMutationAction] = []
        actions.append(
            contentsOf: plan.deletes.filter { $0.calendar == context.hubCalendar.reference }.sorted(by: eventOrder).map
            { .delete(role: .hub, event: $0) })

        for (index, workCalendar) in context.workCalendars.enumerated() {
            let role = ConfiguredCalendarRole.work(name: workCalendar.settings.name, declarationIndex: index)
            actions.append(
                contentsOf: plan.deletes.filter { $0.calendar == workCalendar.calendar.reference }.sorted(
                    by: eventOrder
                ).map { .delete(role: role, event: $0) })
        }

        actions.append(
            contentsOf: plan.creates.filter { $0.destinationCalendar == context.hubCalendar.reference }.sorted(
                by: projectionOrder
            ).map { .create(role: .hub, event: $0) })

        for (index, workCalendar) in context.workCalendars.enumerated() {
            let role = ConfiguredCalendarRole.work(name: workCalendar.settings.name, declarationIndex: index)
            actions.append(
                contentsOf: plan.creates.filter { $0.destinationCalendar == workCalendar.calendar.reference }.sorted(
                    by: projectionOrder
                ).map { .create(role: role, event: $0) })
        }

        return actions
    }

    private func eventOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        ActionSortKey(event: lhs) < ActionSortKey(event: rhs)
    }

    private func projectionOrder(_ lhs: CalendarEventProjection, _ rhs: CalendarEventProjection) -> Bool {
        ActionSortKey(projection: lhs) < ActionSortKey(projection: rhs)
    }

    private func candidateExplanation(for event: CalendarEvent) -> CandidateEventExplanation {
        CandidateEventExplanation(event: event, inclusion: EventInclusionPolicy.evaluate(event))
    }

    private func validate(_ settings: CalendarRelaySettings) throws {
        do { try SettingsValidator.validate(settings) } catch let error as SettingsValidationError {
            throw ReconcileCalendarsError.invalidSettings(error.description)
        }
        guard settings.legacyMarkers.isEmpty else { throw ReconcileCalendarsError.migrationPending }
    }

}

private struct ActionSortKey: Comparable {
    let start: Date
    let end: Date
    let isAllDay: Bool
    let title: String
    let tieBreaker: String

    init(event: CalendarEvent) {
        start = event.start
        end = event.end
        isAllDay = event.isAllDay
        title = event.title
        tieBreaker = event.id.totalOrderKey(occurrenceDate: event.occurrenceDate)
    }

    init(projection: CalendarEventProjection) {
        start = projection.start
        end = projection.end
        isAllDay = projection.isAllDay
        title = projection.title
        tieBreaker = ""
    }

    static func < (lhs: ActionSortKey, rhs: ActionSortKey) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.end != rhs.end { return lhs.end < rhs.end }
        if lhs.isAllDay != rhs.isAllDay { return !lhs.isAllDay }
        if lhs.title != rhs.title {
            return lhs.title.unicodeScalars.lexicographicallyPrecedes(rhs.title.unicodeScalars) { left, right in
                left.value < right.value
            }
        }
        return lhs.tieBreaker < rhs.tieBreaker
    }
}
