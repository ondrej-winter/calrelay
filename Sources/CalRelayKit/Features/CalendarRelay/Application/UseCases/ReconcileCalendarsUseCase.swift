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

    func standingAuthorizationDryRun(settings: CalendarRelaySettings, now: Date) async throws
        -> CalendarStandingAuthorizationDryRun
    {
        let computation = try await compute(settings: settings, now: now)
        let resolvedCalendars =
            [computation.context.hubCalendar.reference.id]
            + computation.context.workCalendars.map { $0.calendar.reference.id }
        return CalendarStandingAuthorizationDryRun(
            result: computation.result, topologyIdentity: ResolvedCalendarTopologyIdentity(resolvedCalendars))
    }

    /// Explains every loaded input event and the ordered executable actions produced by the
    /// shared ordinary reconciliation computation.
    public func explain(settings: CalendarRelaySettings, now: Date) async throws -> ReconciliationExplanation {
        let computation = try await compute(settings: settings, now: now)
        let candidates = (computation.context.hubEvents + computation.context.allWorkEvents).map({
            candidateExplanation(for: $0, computation: computation)
        })
        let actions = computation.result.actions.map { action in
            PlannedActionExplanation(
                action: action, reason: explanationReason(for: action, computation: computation),
                causalEvents: causalEvents(for: action, computation: computation))
        }

        return ReconciliationExplanation(
            window: computation.context.window, syncWindowDays: computation.context.syncWindowDays,
            candidates: candidates, actions: actions)
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
        try await compute(settings: settings, now: now).result
    }

    private func compute(settings: CalendarRelaySettings, now: Date) async throws -> OrdinaryReconciliationComputation {
        let context = try await loadRunContext(settings: settings, now: now)
        let titlePolicy = ManagedEventTitlePolicy(managedPrefixes: context.managedPrefixes)
        let workTargets = context.workCalendars.map { workCalendar in
            WorkCalendarProjectionTarget(settings: workCalendar.settings, calendar: workCalendar.calendar.reference)
        }

        let hubExpectations = context.workCalendars.flatMap { workCalendar in
            let sourceEvents = context.workEvents(for: workCalendar).filter { event in
                !titlePolicy.isRelayedWorkBlocker(event)
            }
            return sourceEvents.flatMap { event in
                WorkToHubProjector.project(
                    events: [event], from: workCalendar.settings, to: context.hubCalendar.reference
                ).map { projection in ProjectionExpectation(projection: projection, causalEvents: [event.identity]) }
            }
        }
        let expectedHubEvents = hubExpectations.map(\.projection)
        let hubPlan = ReconciliationPlanner.plan(
            expected: expectedHubEvents, existing: context.hubEvents, managedPrefixes: context.managedPrefixes)
        let reconciledExistingHubEvents = context.hubEvents.filter { !hubPlan.deletes.contains($0) }

        let existingHubExpectations = reconciledExistingHubEvents.flatMap { event in
            HubToWorkProjector.project(hubEvents: [event], to: workTargets, personalPrefix: settings.personalPrefix).map
            { projection in ProjectionExpectation(projection: projection, causalEvents: [event.identity]) }
        }
        let projectedHubExpectations = hubExpectations.flatMap { expectation in
            let event = calendarEvent(for: expectation.projection, idPrefix: "expected-hub")
            return HubToWorkProjector.project(
                hubEvents: [event], to: workTargets, personalPrefix: settings.personalPrefix
            ).map { projection in ProjectionExpectation(projection: projection, causalEvents: expectation.causalEvents)
            }
        }
        let workExpectations = existingHubExpectations + projectedHubExpectations
        let expectedWorkEvents = workExpectations.map(\.projection)

        let shouldDeleteWorkEvent: (CalendarEvent) -> Bool = titlePolicy.isRelayedWorkBlocker
        let workPlan = ReconciliationPlanner.plan(
            expected: expectedWorkEvents, existing: context.allWorkEvents, shouldDeleteStaleEvent: shouldDeleteWorkEvent
        )
        let reconciliationPlan = ReconciliationPlan(
            creates: hubPlan.creates + workPlan.creates, deletes: hubPlan.deletes + workPlan.deletes)
        let result = OrdinaryReconciliationResult(
            plan: reconciliationPlan, actions: ordinaryActions(for: reconciliationPlan, context: context))

        return OrdinaryReconciliationComputation(
            context: context, result: result, expectations: hubExpectations + workExpectations)
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
            personalPrefix: settings.personalPrefix, window: snapshot.window, syncWindowDays: settings.syncWindowDays,
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

    private func causalEvents(for action: CalendarMutationAction, computation: OrdinaryReconciliationComputation)
        -> [CalendarEventIdentity]
    {
        guard case .create(_, let event) = action else {
            if case .delete(_, let event) = action { return [event.identity] }
            return []
        }
        var causalEvents: [CalendarEventIdentity] = []
        for expectation in computation.expectations where expectation.projection == event {
            for causalEvent in expectation.causalEvents where !causalEvents.contains(causalEvent) {
                causalEvents.append(causalEvent)
            }
        }
        return causalEvents
    }

    private func explanationReason(for action: CalendarMutationAction, computation: OrdinaryReconciliationComputation)
        -> PlannedActionExplanationReason
    {
        switch action {
        case .create: return .missingExpectedProjection
        case .delete(_, let event):
            if event.status == .cancelled { return .cancelledManagedProjection }
            let key = VisibleEventKey(event: event)
            let hasExpectation = computation.expectations.contains { visibleKey(for: $0.projection) == key }
            let duplicateCount = (computation.context.hubEvents + computation.context.allWorkEvents).count {
                VisibleEventKey(event: $0) == key
            }
            if hasExpectation && duplicateCount > 1 { return .replaceAllManagedDuplicate }
            return .staleManagedProjection
        }
    }

    private func visibleKey(for projection: CalendarEventProjection) -> VisibleEventKey {
        VisibleEventKey(
            calendar: projection.destinationCalendar, title: projection.title, start: projection.start,
            end: projection.end, isAllDay: projection.isAllDay)
    }

    private func candidateExplanation(for event: CalendarEvent, computation: OrdinaryReconciliationComputation)
        -> CandidateEventExplanation
    {
        CandidateEventExplanation(
            event: event, eligibility: candidateEligibility(for: event, context: computation.context),
            routing: candidateRouting(for: event, context: computation.context),
            expectation: candidateExpectation(for: event, computation: computation),
            disposition: candidateDisposition(for: event, computation: computation))
    }

    private func candidateEligibility(for event: CalendarEvent, context: ReconciliationRunContext)
        -> CandidateEventEligibilityExplanation
    {
        if event.status == .cancelled { return .reliableCancellation }
        if event.calendar == context.hubCalendar.reference, MarkedEventTitle.marker(in: event.title) != nil {
            return .markedHubEligibilityBypass
        }

        switch EventInclusionPolicy.evaluate(event) {
        case .cancelled: return .reliableCancellation
        case .currentUserAccepted: return .currentUserAccepted
        case .currentUserNonAccepted(let status): return .currentUserNonAccepted(status)
        case .noCurrentUserAttendeeIncluded(let availability): return .noCurrentUserAttendeeIncluded(availability)
        case .noCurrentUserAttendeeExcluded(let availability): return .noCurrentUserAttendeeExcluded(availability)
        }
    }

    private func candidateRouting(for event: CalendarEvent, context: ReconciliationRunContext)
        -> CandidateEventRoutingExplanation
    {
        guard event.calendar == context.hubCalendar.reference else {
            return MarkedEventTitle.marker(in: event.title) == nil
                ? .workToHubSource : .feedbackSuppressedMarkedWorkProjection
        }

        guard let marker = MarkedEventTitle.marker(in: event.title) else {
            return EventInclusionPolicy.includes(event) ? .hubPersonalSource : .invalidOrUnmarkedHubSource
        }
        if event.status == .cancelled { return .cancelledMarkedHubPreservation }
        if marker == context.personalPrefix { return .exactLocalMarkerHubSource(role: .hub) }
        if let index = context.workCalendars.firstIndex(where: { $0.settings.prefix == marker }) {
            let workCalendar = context.workCalendars[index]
            return .exactLocalMarkerHubSource(role: .work(name: workCalendar.settings.name, declarationIndex: index))
        }
        return .nonLocalValidMarkerHubSource
    }

    private func candidateExpectation(for event: CalendarEvent, computation: OrdinaryReconciliationComputation)
        -> CandidateEventExpectationExplanation
    {
        let key = VisibleEventKey(event: event)
        return computation.expectations.contains { visibleKey(for: $0.projection) == key }
            ? .matchesExpectedProjection : .noMatchingExpectation
    }

    private func candidateDisposition(for event: CalendarEvent, computation: OrdinaryReconciliationComputation)
        -> CandidateEventDispositionExplanation
    {
        if let deletion = computation.result.actions.first(where: { action in
            guard case .delete(_, let deletedEvent) = action else { return false }
            return deletedEvent.identity == event.identity
        }) {
            switch explanationReason(for: deletion, computation: computation) {
            case .staleManagedProjection: return .selectedStaleManagedDeletion
            case .cancelledManagedProjection: return .selectedCancelledManagedDeletion
            case .replaceAllManagedDuplicate: return .selectedDuplicateSetDeletion
            case .missingExpectedProjection: break
            }
        }

        let titlePolicy = ManagedEventTitlePolicy(managedPrefixes: computation.context.managedPrefixes)
        let isManaged =
            event.calendar == computation.context.hubCalendar.reference
            ? titlePolicy.isManagedProjection(event) : titlePolicy.isRelayedWorkBlocker(event)
        if isManaged, candidateExpectation(for: event, computation: computation) == .matchesExpectedProjection {
            return .retained
        }
        return .preservedUnmanagedOrNonLocal
    }

    private func validate(_ settings: CalendarRelaySettings) throws {
        do { try SettingsValidator.validate(settings) } catch let error as SettingsValidationError {
            throw ReconcileCalendarsError.invalidSettings(error.description)
        }
        guard settings.legacyMarkers.isEmpty else { throw ReconcileCalendarsError.migrationPending }
    }

}

private struct OrdinaryReconciliationComputation {
    let context: ReconciliationRunContext
    let result: OrdinaryReconciliationResult
    let expectations: [ProjectionExpectation]
}

private struct ProjectionExpectation {
    let projection: CalendarEventProjection
    let causalEvents: [CalendarEventIdentity]
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
