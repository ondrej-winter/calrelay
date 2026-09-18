import Foundation

/// Owns standing authorization for future automatic ordinary reconciliation.
/// Calendar permission requests and calendar mutation are intentionally absent.
public actor CalendarStandingAuthorizationUseCase {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let reconciliation: ReconcileCalendarsUseCase
    private let stateStore: any CalendarAutomationStateStore
    private let policyVersion: CalendarReconciliationPolicyVersion
    private let now: @Sendable () -> Date
    private var pending: PendingStandingAuthorizationReview?
    private var isRunning = false

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, stateStore: any CalendarAutomationStateStore,
        policyVersion: CalendarReconciliationPolicyVersion = .current, now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.settingsProvider = settingsProvider
        reconciliation = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)
        self.stateStore = stateStore
        self.policyVersion = policyVersion
        self.now = now
    }

    public func review() async throws -> CalendarStandingAuthorizationReview {
        guard !isRunning else { throw CalendarStandingAuthorizationError.operationInProgress }
        isRunning = true
        pending = nil
        defer { isRunning = false }
        let candidate = try await currentCandidate()
        try await invalidateStoredAuthorization(ifDifferentFrom: candidate.binding)
        return remember(candidate)
    }

    public func cancelReview() {
        guard !isRunning else { return }
        pending = nil
    }

    public func confirm(reviewID: UUID) async throws -> CalendarStandingAuthorizationOutcome {
        guard !isRunning else { throw CalendarStandingAuthorizationError.operationInProgress }
        guard let reviewed = pending, reviewed.review.id == reviewID else {
            throw CalendarStandingAuthorizationError.reviewRequired
        }
        isRunning = true
        pending = nil
        defer { isRunning = false }

        let fresh = try await currentCandidate()
        try await invalidateStoredAuthorization(ifDifferentFrom: fresh.binding)
        guard reviewed.binding == fresh.binding, reviewed.review.summary == fresh.summary else {
            return .reviewRequired(remember(fresh))
        }

        let existing = await stateStore.loadState()
        let schedulingPreference: CalendarSchedulingPreference =
            existing.schedulingPreference == .disabled ? .enabled : existing.schedulingPreference
        try await stateStore.saveState(
            CalendarAutomationPersistentState(
                schedulingPreference: schedulingPreference, standingAuthorization: fresh.binding,
                operationalStatus: existing.operationalStatus))
        return .granted
    }

    public func validateCurrentAuthorization() async throws -> CalendarStandingAuthorizationValidation {
        guard !isRunning else { throw CalendarStandingAuthorizationError.operationInProgress }
        let existing = await stateStore.loadState()
        guard let authorizedBinding = existing.standingAuthorization else { return .notGranted }
        isRunning = true
        defer { isRunning = false }

        let current = try await currentCandidate()
        guard current.binding == authorizedBinding else {
            try await removeAuthorization(from: existing)
            return .invalidated
        }
        return .valid
    }

    private func currentCandidate() async throws -> StandingAuthorizationCandidate {
        let settings = try await settingsProvider.loadSettings().settings
        let dryRun = try await reconciliation.standingAuthorizationDryRun(settings: settings, now: now())
        try Task.checkCancellation()
        return StandingAuthorizationCandidate(
            summary: CalendarManualDryRunSummary(
                plannedDeletes: dryRun.result.plan.deletes.count, plannedCreates: dryRun.result.plan.creates.count),
            binding: CalendarStandingAuthorizationBinding.derive(
                configurationIdentity: OrdinaryConfigurationMutationIdentity(settings),
                topologyIdentity: dryRun.topologyIdentity, policyVersion: policyVersion))
    }

    private func remember(_ candidate: StandingAuthorizationCandidate) -> CalendarStandingAuthorizationReview {
        let review = CalendarStandingAuthorizationReview(summary: candidate.summary)
        pending = PendingStandingAuthorizationReview(review: review, binding: candidate.binding)
        return review
    }

    private func invalidateStoredAuthorization(ifDifferentFrom binding: CalendarStandingAuthorizationBinding)
        async throws
    {
        let state = await stateStore.loadState()
        guard let authorizedBinding = state.standingAuthorization, authorizedBinding != binding else { return }
        try await removeAuthorization(from: state)
    }

    private func removeAuthorization(from state: CalendarAutomationPersistentState) async throws {
        pending = nil
        try await stateStore.saveState(
            CalendarAutomationPersistentState(
                schedulingPreference: state.schedulingPreference, standingAuthorization: nil,
                operationalStatus: state.operationalStatus))
    }
}

private struct StandingAuthorizationCandidate {
    let summary: CalendarManualDryRunSummary
    let binding: CalendarStandingAuthorizationBinding
}

private struct PendingStandingAuthorizationReview {
    let review: CalendarStandingAuthorizationReview
    let binding: CalendarStandingAuthorizationBinding
}
