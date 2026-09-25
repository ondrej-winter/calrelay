import Foundation

/// Owns one-use manual authorization. No permission-request capability is injected.
public actor CalendarManualApplyUseCase {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let reconciliation: ReconcileCalendarsUseCase
    private let executor: CalendarMutationExecutor
    private let now: @Sendable () -> Date
    private var pending: PendingManualReview?
    private var isRunning = false

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendarProvider: @escaping @Sendable () -> Calendar = { .current }
    ) {
        self.settingsProvider = settingsProvider
        reconciliation = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore,
            calendarProvider: calendarProvider)
        executor = CalendarMutationExecutor(calendarStore: calendarStore)
        self.now = now
    }

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar
    ) {
        self.settingsProvider = settingsProvider
        reconciliation = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)
        executor = CalendarMutationExecutor(calendarStore: calendarStore)
        self.now = now
    }

    public func review() async throws -> CalendarManualApplyReview {
        guard !isRunning else { throw CalendarManualApplyError.operationInProgress }
        isRunning = true
        pending = nil
        defer { isRunning = false }
        let settings = try await settingsProvider.loadSettings().settings
        let result = try await reconciliation.dryRunResult(settings: settings, now: now())
        try Task.checkCancellation()
        return remember(result, settings: settings)
    }

    public func cancelReview() {
        // An in-flight confirmation has already consumed its authorization.
        guard !isRunning else { return }
        pending = nil
    }

    public func confirm(reviewID: UUID) async throws -> CalendarManualApplyOutcome {
        guard !isRunning else { throw CalendarManualApplyError.operationInProgress }
        guard let reviewed = pending, reviewed.review.id == reviewID else {
            throw CalendarManualApplyError.reviewRequired
        }
        isRunning = true
        pending = nil
        defer { isRunning = false }
        let settings = try await settingsProvider.loadSettings().settings
        let fresh = try await reconciliation.dryRunResult(settings: settings, now: now())
        try Task.checkCancellation()
        guard reviewed.identities == fresh.actions.map(\.executableIdentity),
            reviewed.configuration == OrdinaryConfigurationMutationIdentity(settings)
        else { return .reviewRequired(remember(fresh, settings: settings)) }
        // File I/O belongs to the provider. Revalidate after the calendar reads and
        // immediately before executing, without replanning after mutation starts.
        let current = try await settingsProvider.loadSettings().settings
        try SettingsValidator.validate(current)
        guard OrdinaryConfigurationMutationIdentity(settings) == OrdinaryConfigurationMutationIdentity(current),
            current.legacyMarkers.isEmpty
        else { throw CalendarManualApplyError.configurationChanged }
        try Task.checkCancellation()
        return .applied(try await executor.execute(fresh.actions))
    }

    private func remember(_ result: OrdinaryReconciliationResult, settings: CalendarRelaySettings)
        -> CalendarManualApplyReview
    {
        let review = CalendarManualApplyReview(
            summary: CalendarManualDryRunSummary(
                plannedDeletes: result.plan.deletes.count, plannedCreates: result.plan.creates.count))
        pending = PendingManualReview(
            review: review, identities: result.actions.map(\.executableIdentity),
            configuration: OrdinaryConfigurationMutationIdentity(settings))
        return review
    }
}

private struct PendingManualReview {
    let review: CalendarManualApplyReview
    let identities: [CalendarExecutableActionIdentity]
    let configuration: OrdinaryConfigurationMutationIdentity
}
