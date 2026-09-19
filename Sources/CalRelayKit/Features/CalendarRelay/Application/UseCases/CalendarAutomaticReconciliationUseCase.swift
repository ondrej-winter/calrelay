import Foundation

/// Runs one fresh, non-prompting automatic ordinary reconciliation attempt.
public actor CalendarAutomaticReconciliationUseCase {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let reconciliation: ReconcileCalendarsUseCase
    private let executor: CalendarMutationExecutor
    private let stateStore: any CalendarAutomationStateStore
    private let configurationChanges: CalendarConfigurationChangeTracker
    private let policyVersion: CalendarReconciliationPolicyVersion
    private let schedulingPolicy: CalendarAutomationSchedulingPolicy
    private let now: @Sendable () -> Date

    public init(
        settingsProvider: any CalendarRelaySettingsProvider,
        authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort,
        stateStore: any CalendarAutomationStateStore,
        configurationChanges: CalendarConfigurationChangeTracker,
        policyVersion: CalendarReconciliationPolicyVersion = .current,
        schedulingPolicy: CalendarAutomationSchedulingPolicy = CalendarAutomationSchedulingPolicy(),
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.settingsProvider = settingsProvider
        self.authorizationStatus = authorizationStatus
        reconciliation = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)
        executor = CalendarMutationExecutor(calendarStore: calendarStore)
        self.stateStore = stateStore
        self.configurationChanges = configurationChanges
        self.policyVersion = policyVersion
        self.schedulingPolicy = schedulingPolicy
        self.now = now
    }

    public func run(kind: CalendarAutomaticAttemptKind = .ordinary) async throws
        -> CalendarAutomaticReconciliationResult
    {
        let context = try await attemptContext(for: kind)
        guard let authorizedBinding = context.authorizedBinding else {
            return try await finish(
                AutomaticAttemptBlocker(outcome: .standingAuthorizationRequired), context: context)
        }

        let prepared: PreparedAutomaticAttempt
        do {
            prepared = try await prepareAttempt(
                authorizedBinding: authorizedBinding, attemptDate: context.attemptDate)
            try await validateBeforeMutation(prepared)
        } catch let blocker as AutomaticAttemptBlocker {
            return try await finish(blocker, context: context)
        }

        return try await execute(prepared.dryRun.result.actions, context: context)
    }

    private func attemptContext(for kind: CalendarAutomaticAttemptKind) async throws -> AutomaticAttemptContext {
        let attemptDate = now()
        let state = await stateStore.loadState()
        guard state.schedulingPreference == .enabled else {
            throw CalendarAutomaticReconciliationError.schedulingNotEnabled
        }
        let previousRetry = kind == .retry ? state.operationalStatus.retryState : .none
        return AutomaticAttemptContext(
            attemptDate: attemptDate, previousRetry: previousRetry,
            authorizedBinding: state.standingAuthorization)
    }

    private func prepareAttempt(
        authorizedBinding: CalendarStandingAuthorizationBinding,
        attemptDate: Date
    ) async throws -> PreparedAutomaticAttempt {
        let observedRevision = await configurationChanges.currentRevision()
        let settings = try await loadInitialSettings()
        let dryRun = try await loadDryRun(settings: settings, attemptDate: attemptDate)
        let currentBinding = CalendarStandingAuthorizationBinding.derive(
            configurationIdentity: OrdinaryConfigurationMutationIdentity(settings),
            topologyIdentity: dryRun.topologyIdentity, policyVersion: policyVersion)
        guard currentBinding == authorizedBinding else {
            throw AutomaticAttemptBlocker(outcome: .standingAuthorizationRequired, revokeAuthorization: true)
        }
        guard await configurationChanges.currentRevision() == observedRevision else {
            throw AutomaticAttemptBlocker(outcome: .standingAuthorizationRequired, revokeAuthorization: true)
        }
        return PreparedAutomaticAttempt(
            settings: settings, dryRun: dryRun, observedRevision: observedRevision)
    }

    private func loadInitialSettings() async throws -> CalendarRelaySettings {
        do {
            return try await settingsProvider.loadSettings().settings
        } catch is CalendarRelaySettingsProviderError {
            throw AutomaticAttemptBlocker(outcome: .configurationUnavailable)
        }
    }

    private func loadDryRun(
        settings: CalendarRelaySettings,
        attemptDate: Date
    ) async throws -> CalendarStandingAuthorizationDryRun {
        do {
            return try await reconciliation.standingAuthorizationDryRun(settings: settings, now: attemptDate)
        } catch ReconcileCalendarsError.migrationPending {
            throw AutomaticAttemptBlocker(outcome: .migrationPending)
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) {
            throw AutomaticAttemptBlocker(outcome: Self.outcome(for: issues))
        } catch ReconcileCalendarsError.invalidSettings {
            throw AutomaticAttemptBlocker(outcome: .configurationUnavailable)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AutomaticAttemptBlocker(outcome: .transientFailure)
        }
    }

    private func validateBeforeMutation(_ prepared: PreparedAutomaticAttempt) async throws {
        let currentSettings: CalendarRelaySettings
        do {
            currentSettings = try await settingsProvider.loadSettings().settings
            try SettingsValidator.validate(currentSettings)
        } catch {
            throw AutomaticAttemptBlocker(outcome: .configurationUnavailable, revokeAuthorization: true)
        }
        guard currentSettings.legacyMarkers.isEmpty else {
            throw AutomaticAttemptBlocker(outcome: .migrationPending, revokeAuthorization: true)
        }
        guard
            OrdinaryConfigurationMutationIdentity(currentSettings)
                == OrdinaryConfigurationMutationIdentity(prepared.settings)
        else {
            throw AutomaticAttemptBlocker(outcome: .standingAuthorizationRequired, revokeAuthorization: true)
        }
        guard await authorizationStatus.authorizationStatus() == .fullAccess else {
            throw AutomaticAttemptBlocker(outcome: .calendarAccessUnavailable)
        }
        guard await configurationChanges.currentRevision() == prepared.observedRevision else {
            throw AutomaticAttemptBlocker(outcome: .standingAuthorizationRequired, revokeAuthorization: true)
        }
    }

    private func execute(
        _ actions: [CalendarMutationAction],
        context: AutomaticAttemptContext
    ) async throws -> CalendarAutomaticReconciliationResult {
        do {
            let execution = try await executor.execute(actions)
            let counts = Self.aggregate(execution.confirmedCounts)
            let outcome: CalendarAutomationOutcomeCategory = actions.isEmpty ? .noChanges : .applied
            return try await finish(
                outcome: outcome, counts: counts, attemptDate: context.attemptDate, marksSuccess: true,
                previousRetry: context.previousRetry)
        } catch let error as CalendarMutationExecutionError {
            guard case .partial(let partial) = error else { throw error }
            return try await finish(
                outcome: .partialMutation, counts: Self.aggregate(partial.confirmedCounts),
                attemptDate: context.attemptDate, marksSuccess: false, previousRetry: context.previousRetry)
        }
    }

    private func finish(
        _ blocker: AutomaticAttemptBlocker,
        context: AutomaticAttemptContext
    ) async throws -> CalendarAutomaticReconciliationResult {
        try await finish(
            outcome: blocker.outcome, counts: .zero, attemptDate: context.attemptDate,
            marksSuccess: false, previousRetry: context.previousRetry,
            revokeAuthorization: blocker.revokeAuthorization)
    }

    private func finish(
        outcome: CalendarAutomationOutcomeCategory,
        counts: CalendarAutomationMutationCounts,
        attemptDate: Date,
        marksSuccess: Bool,
        previousRetry: CalendarAutomationRetryState,
        revokeAuthorization: Bool = false
    ) async throws -> CalendarAutomaticReconciliationResult {
        let retryState = schedulingPolicy.nextRetry(after: outcome, previousRetry: previousRetry, now: attemptDate)
        _ = try await stateStore.updateState { current in
            let previousFreshness = current.operationalStatus.freshness
            let status = CalendarAutomationOperationalStatus(
                lastAttemptAt: attemptDate, latestOutcome: outcome, confirmedCounts: counts, retryState: retryState,
                freshness: CalendarAutomationFreshnessMetadata(
                    lastSuccessAt: marksSuccess ? attemptDate : previousFreshness.lastSuccessAt,
                    nextNominalRunAt: previousFreshness.nextNominalRunAt))
            return CalendarAutomationPersistentState(
                schedulingPreference: current.schedulingPreference,
                standingAuthorization: revokeAuthorization ? nil : current.standingAuthorization,
                operationalStatus: status)
        }
        return CalendarAutomaticReconciliationResult(
            outcome: outcome, confirmedCounts: counts, retryState: retryState)
    }

    private static func aggregate(_ counts: [CalendarRoleMutationCounts]) -> CalendarAutomationMutationCounts {
        CalendarAutomationMutationCounts(
            confirmedCreates: counts.reduce(0) { $0 + $1.confirmedCreates },
            confirmedDeletes: counts.reduce(0) { $0 + $1.confirmedDeletes })
    }

    private static func outcome(for issues: [CalendarAccessPreflightIssue]) -> CalendarAutomationOutcomeCategory {
        if issues.contains(where: { issue in
            if case .authorizationUnavailable = issue { return true }
            return false
        }) { return .calendarAccessUnavailable }
        if issues.contains(where: { issue in
            switch issue {
            case .calendarInventoryReadFailed, .eventReadFailed: true
            default: false
            }
        }) { return .transientFailure }
        return .topologyNotReady
    }
}

private struct AutomaticAttemptContext {
    let attemptDate: Date
    let previousRetry: CalendarAutomationRetryState
    let authorizedBinding: CalendarStandingAuthorizationBinding?
}

private struct PreparedAutomaticAttempt {
    let settings: CalendarRelaySettings
    let dryRun: CalendarStandingAuthorizationDryRun
    let observedRevision: Int
}

private struct AutomaticAttemptBlocker: Error {
    let outcome: CalendarAutomationOutcomeCategory
    let revokeAuthorization: Bool

    init(outcome: CalendarAutomationOutcomeCategory, revokeAuthorization: Bool = false) {
        self.outcome = outcome
        self.revokeAuthorization = revokeAuthorization
    }
}