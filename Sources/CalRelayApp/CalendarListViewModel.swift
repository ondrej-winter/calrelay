import CalRelayKit
import SwiftUI

@MainActor final class CalendarListViewModel: ObservableObject {
    @Published var output = "Use the setup or recovery action, then show the separate calendar inventory."
    @Published var primaryStatus = "Status has not been refreshed."
    @Published var configurationSummary = "Configuration has not been checked."
    @Published var authorizationSummary = "Calendar access has not been checked in this app session."
    @Published var readinessSummary = "Configured readiness has not been checked."
    @Published var migrationSummary = "Migration state has not been checked."
    @Published var isLoading = false
    @Published var canRunOrdinarySync = false
    @Published var manualReview: CalendarManualApplyReview?
    @Published var reviewNotice = ""
    @Published var isMigrationPending = false
    @Published var canReviewCleanup = false
    @Published var cleanupReview: CalendarManualCleanupReview?
    @Published var cleanupNotice = ""
    @Published var cleanupAllowsConfirmation = false
    @Published var standingAuthorizationSummary = "Scheduled sync standing authorization has not been checked."
    @Published var canReviewStandingAuthorization = false
    @Published var standingAuthorizationReview: CalendarStandingAuthorizationReview?
    @Published var standingAuthorizationNotice = ""
    @Published var schedulingPreference = CalendarSchedulingPreference.disabled
    @Published var schedulingSummary = "Scheduled sync has not been checked."
    @Published var launchAtLoginSummary = "Launch at login has not been checked."
    @Published var automaticOperationSummary = "No automatic operation status has been loaded."
    @Published var automationAttentionSummary = "Automation attention state has not been checked."
    @Published var notificationSummary = "Notification permission has not been checked."

    var isOperationBlocked: Bool {
        isLoading || manualReview != nil || cleanupReview != nil || standingAuthorizationReview != nil
    }
    let manualCleanup: CalendarManualCleanupUseCase

    private let inventory: CalendarInventoryUseCase
    private let setup: CalendarAccessSetupUseCase
    private let status: CalendarControlPanelStatusUseCase
    private let manualDryRun: CalendarManualDryRunUseCase
    private let manualApply: CalendarManualApplyUseCase
    let standingAuthorization: CalendarStandingAuthorizationUseCase
    private let configurationObserver: ConfigurationFileObserver
    let automaticReconciliation: CalendarAutomaticReconciliationUseCase
    let automationState: CalendarAutomationStateUseCase
    let automationTriggers: CalendarAutomationTriggerSource
    let launchAtLogin: CalendarLaunchAtLoginController
    let automationAttention: CalendarAutomationAttentionController
    let launchContext: () -> CalendarAppLaunchContext
    let resolveInitialLaunchPresentation: (CalendarLoginLaunchPresentation) -> Void
    let automaticAttemptsEnabled: Bool
    var operationCoordinator = CalendarAppOperationCoordinator()
    var pendingAutomaticKind: CalendarAutomaticAttemptKind?
    var isAutomationTriggerSourceRunning = false
    private var didStart = false
    private var didRestoreAutomationLifecycle = false
    var didResolveInitialLaunchPresentation = false
    var isAwaitingInitialAutomaticAttempt = false
    var controlPanelPrimaryState: CalendarControlPanelPrimaryState?

    init(
        inventory: CalendarInventoryUseCase, setup: CalendarAccessSetupUseCase,
        status: CalendarControlPanelStatusUseCase, manualDryRun: CalendarManualDryRunUseCase,
        manualApply: CalendarManualApplyUseCase, manualCleanup: CalendarManualCleanupUseCase,
        standingAuthorization: CalendarStandingAuthorizationUseCase,
        automaticReconciliation: CalendarAutomaticReconciliationUseCase,
        automationState: CalendarAutomationStateUseCase,
        configurationObserver: ConfigurationFileObserver,
        automationTriggers: CalendarAutomationTriggerSource,
        launchAtLogin: CalendarLaunchAtLoginController,
        automationAttention: CalendarAutomationAttentionController,
        launchContext: @escaping () -> CalendarAppLaunchContext,
        resolveInitialLaunchPresentation: @escaping (CalendarLoginLaunchPresentation) -> Void,
        automaticAttemptsEnabled: Bool = true
    ) {
        self.inventory = inventory
        self.setup = setup
        self.status = status
        self.manualDryRun = manualDryRun
        self.manualApply = manualApply
        self.manualCleanup = manualCleanup
        self.standingAuthorization = standingAuthorization
        self.automaticReconciliation = automaticReconciliation
        self.automationState = automationState
        self.configurationObserver = configurationObserver
        self.automationTriggers = automationTriggers
        self.launchAtLogin = launchAtLogin
        self.automationAttention = automationAttention
        self.launchContext = launchContext
        self.resolveInitialLaunchPresentation = resolveInitialLaunchPresentation
        self.automaticAttemptsEnabled = automaticAttemptsEnabled
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        configurationObserver.start { [weak self] in Task { @MainActor in self?.configurationDidChange() } }
        refreshStatus()
    }

    func refreshStatus() {
        guard beginOperation(.statusRefresh) else { return }
        canRunOrdinarySync = false
        canReviewCleanup = false
        isMigrationPending = false
        output = "Refreshing configuration, Calendar access, and configured readiness…"

        Task {
            do {
                apply(try await status.run())
                await refreshStandingAuthorizationSummary()
                await refreshAutomationPresentation()
                output = "Status refresh completed without requesting Calendar access."
            } catch {
                primaryStatus = "Status refresh failed."
                canRunOrdinarySync = false
                output = "Status could not be refreshed. Check the configuration and try again."
                completeInitialLaunchPresentation(.showControlPanel)
            }

            if !didRestoreAutomationLifecycle {
                didRestoreAutomationLifecycle = true
                await restoreAutomationLifecycle()
            }

            finishOperation()
        }
    }

    func setUpCalendarAccess() {
        guard beginOperation(.calendarAccessSetup) else { return }
        canRunOrdinarySync = false
        canReviewCleanup = false
        output = "Checking Calendar access…"

        Task {
            do {
                let result = try await setup.run()
                authorizationSummary = Self.authorizationSummary(for: result.authorizationState)
                let setupOutput =
                    result.didRequestAccess
                    ? "Calendar access request completed. Review the authorization state above."
                    : "Calendar access was checked without showing a permission prompt."
                do {
                    apply(try await status.run())
                    await refreshStandingAuthorizationSummary()
                    await refreshAutomationPresentation()
                    output = setupOutput + " Status was refreshed."
                } catch {
                    canRunOrdinarySync = false
                    output = setupOutput + " Status refresh failed; use Refresh Status to try again."
                }
            } catch {
                authorizationSummary = "Calendar access setup failed."
                output = Self.safeErrorMessage(error)
            }

            finishOperation()
        }
    }

    private func apply(_ status: CalendarControlPanelStatus) {
        controlPanelPrimaryState = status.primaryState
        primaryStatus = Self.primaryStatus(for: status.primaryState)
        configurationSummary = Self.configurationSummary(for: status.configurationState)
        authorizationSummary =
            status.authorizationState.map(Self.authorizationSummary(for:))
            ?? "Calendar access was not checked because configuration must be fixed first."
        readinessSummary = Self.readinessSummary(for: status.readinessState)
        migrationSummary =
            status.isMigrationPending
            ? "Migration is pending. Ordinary sync remains blocked until explicit cleanup completes and legacyMarkers is removed manually."
            : "No legacy-marker migration is pending."
        canRunOrdinarySync = status.primaryState == .ready
        canReviewStandingAuthorization = status.primaryState == .ready
        isMigrationPending = status.isMigrationPending
        // Ordinary-window readiness is not a cleanup preflight. The cleanup use case
        // independently checks the entire topology over the complete cleanup range.
        canReviewCleanup = status.isMigrationPending && status.authorizationState == .fullAccess
    }

    private static func primaryStatus(for state: CalendarControlPanelPrimaryState) -> String {
        switch state {
        case .configurationMissing: "Configuration is missing. Create the canonical YAML file first."
        case .configurationInvalid: "Configuration is invalid. Fix the YAML before checking Calendar access."
        case .calendarAccessUnavailable: "Full Calendar access is unavailable. Use the setup or recovery action."
        case .topologyNotReady: "Configured calendars are not currently ready. Review the readiness issues."
        case .migrationPending: "Configured topology is ready, but explicit legacy cleanup is required."
        case .ready: "Calendar access and the complete configured topology are currently ready."
        }
    }

    private static func configurationSummary(for state: CalendarControlPanelConfigurationState) -> String {
        switch state {
        case .missing(let displayPath): "Missing: \(displayPath)"
        case .invalid(let displayPath): "Invalid: \(displayPath)"
        case .valid(let displayPath): "Valid: \(displayPath)"
        }
    }

    private static func readinessSummary(for state: CalendarControlPanelReadinessState) -> String {
        switch state {
        case .notChecked: "Not checked."
        case .ready: "Every configured role resolved uniquely, was writable, and was readable over the ordinary window."
        case .notReady(let issues): issues.map(\.description).joined(separator: "\n")
        }
    }

    func listCalendars() {
        guard beginOperation(.inventory) else { return }
        output = "Loading the non-prompting Calendar inventory…"

        Task {
            do { output = CalendarListFormatter.formatForApp(try await inventory.run()) } catch {
                output = Self.safeErrorMessage(error)
            }

            finishOperation()
        }
    }

    func runDryRun() {
        guard beginOperation(.manualDryRun) else { return }
        output = "Loading fresh configuration and Calendar state for a dry run…"

        Task {
            do { output = CalendarManualDryRunFormatter.format(try await manualDryRun.run()) } catch {
                canRunOrdinarySync = false
                output = Self.safeOperationErrorMessage(error)
            }

            finishOperation()
        }
    }

    func reviewSync() {
        guard beginOperation(.manualApply) else { return }
        output = "Loading a fresh sync plan for review…"
        Task {
            do {
                manualReview = try await manualApply.review()
                reviewNotice = "No calendar mutations have been performed."
                pauseOperationForReview()
            } catch {
                canRunOrdinarySync = false
                output = CalendarManualApplyFormatter.formatFailure(error)
                finishOperation()
            }
        }
    }

    func reviewStandingAuthorization() {
        guard canReviewStandingAuthorization, beginOperation(.standingAuthorization) else { return }
        output = "Loading a fresh ordinary plan for scheduled sync authorization…"
        Task {
            do {
                let review = try await standingAuthorization.review()
                standingAuthorizationNotice =
                    "Nothing has been applied. Confirm to authorize future launch, wake, timer, and bounded-retry ordinary runs."
                standingAuthorizationReview = review
                pauseOperationForReview()
            } catch {
                canReviewStandingAuthorization = false
                output = Self.safeStandingAuthorizationErrorMessage(error)
                finishOperation()
            }
        }
    }

    func cancelStandingAuthorizationReview() {
        guard !isLoading, standingAuthorizationReview != nil else { return }
        isLoading = true
        Task {
            await standingAuthorization.cancelReview()
            standingAuthorizationReview = nil
            output = "Scheduled sync authorization review cancelled. No calendar mutations were performed."
            finishOperation()
        }
    }

    func confirmStandingAuthorization() {
        guard !isLoading, let review = standingAuthorizationReview else { return }
        isLoading = true
        Task {
            do {
                switch try await standingAuthorization.confirm(reviewID: review.id) {
                case .reviewRequired(let fresh):
                    standingAuthorizationNotice =
                        "The authorization binding or aggregate plan changed. Nothing was authorized. Review this fresh summary and confirm again."
                    standingAuthorizationReview = fresh
                    pauseOperationForReview()
                    return
                case .granted:
                    standingAuthorizationReview = nil
                    standingAuthorizationSummary =
                        "Enabled for the current configuration, reconciliation policy, and resolved calendar topology."
                    output =
                        "Scheduled sync standing authorization granted. No calendar mutations were performed by setup."
                    await automationAttention.requestAuthorization()
                    enableLaunchAtLoginForScheduling()
                    await refreshAutomationPresentation()
                    await startAutomationTriggersIfNeeded(runLaunchAttempt: true)
                }
            } catch {
                standingAuthorizationReview = nil
                canReviewStandingAuthorization = false
                output = Self.safeStandingAuthorizationErrorMessage(error)
            }
            finishOperation()
        }
    }

    func cancelSyncReview() {
        guard !isLoading, manualReview != nil, cleanupReview == nil else { return }
        isLoading = true
        Task {
            await manualApply.cancelReview()
            manualReview = nil
            output = "Sync review cancelled. No calendar mutations were performed."
            finishOperation()
        }
    }

    func confirmSync() {
        guard !isLoading, let review = manualReview else { return }
        isLoading = true
        Task {
            do {
                switch try await manualApply.confirm(reviewID: review.id) {
                case .reviewRequired(let fresh):
                    reviewNotice =
                        "The executable plan changed. Nothing was applied. Review and confirm this fresh plan, even if its counts look unchanged."
                    manualReview = fresh
                    pauseOperationForReview()
                    return
                case .applied(let result):
                    manualReview = nil
                    output = CalendarManualApplyFormatter.format(result)
                }
            } catch {
                manualReview = nil
                canRunOrdinarySync = false
                output = CalendarManualApplyFormatter.formatFailure(error)
            }
            finishOperation()
        }
    }

    private func configurationDidChange() {
        markConfigurationStatusStale()
        Task {
            do { try await standingAuthorization.invalidateAuthorizationForObservedConfigurationChange() } catch {
                standingAuthorizationSummary =
                    "The observed configuration change could not revoke scheduled sync authorization. Refresh status before continuing."
            }
            let hadOpenReview = manualReview != nil || cleanupReview != nil || standingAuthorizationReview != nil
            let request = operationCoordinator.request(.configurationRecovery)
            if hadOpenReview && !isLoading {
                await cancelOpenReviewsForConfigurationChange()
                finishOperation()
            } else if request == .start {
                recoverFromConfigurationChange(preservingOperationOutput: false)
            }
        }
    }

    private func markConfigurationStatusStale() {
        canRunOrdinarySync = false
        canReviewCleanup = false
        canReviewStandingAuthorization = false
        standingAuthorizationSummary =
            "Revoked after the observed configuration change. Review a fresh dry run to enable it again."
        configurationSummary = "Changed on disk. A fresh validation is pending."
        readinessSummary = "Not checked after the observed configuration change."
        migrationSummary = "Migration state will be checked from the current file."
        primaryStatus = "Configuration changed. Refreshing current status."
    }

    private func recoverFromConfigurationChange(preservingOperationOutput: Bool) {
        isLoading = true
        manualReview = nil
        cleanupReview = nil
        cleanupAllowsConfirmation = false
        standingAuthorizationReview = nil
        let previousOutput = output
        if !preservingOperationOutput {
            output = "Configuration changed on disk. Invalidating prior reviews and refreshing status…"
        }

        Task {
            await manualApply.cancelReview()
            await manualCleanup.cancelReview()
            await standingAuthorization.cancelReview()
            do {
                apply(try await status.run())
                await refreshStandingAuthorizationSummary()
                await refreshAutomationPresentation()
                let recovery =
                    "Configuration change detected. Status refreshed from the current file without prompting."
                output = preservingOperationOutput ? previousOutput + "\n\n" + recovery : recovery
            } catch {
                primaryStatus = "Status refresh failed after a configuration change."
                let recovery = "The changed configuration could not be checked. Fix the file and try Refresh Status."
                output = preservingOperationOutput ? previousOutput + "\n\n" + recovery : recovery
            }
            finishOperation()
        }
    }

    func finishOperation() {
        isLoading = false
        guard let next = operationCoordinator.finish() else { return }
        switch next {
        case .configurationRecovery:
            recoverFromConfigurationChange(preservingOperationOutput: true)
        case .automaticReconciliation:
            runAutomaticAttempt(kind: takePendingAutomaticKind())
        default:
            break
        }
    }

    func beginOperation(_ operation: CalendarAppOperation) -> Bool {
        guard !isOperationBlocked, operationCoordinator.request(operation) == .start else { return false }
        isLoading = true
        return true
    }

    func pauseOperationForReview() { isLoading = false }

    private func cancelOpenReviewsForConfigurationChange() async {
        await manualApply.cancelReview()
        await manualCleanup.cancelReview()
        await standingAuthorization.cancelReview()
        manualReview = nil
        cleanupReview = nil
        cleanupAllowsConfirmation = false
        standingAuthorizationReview = nil
    }

    private func refreshStandingAuthorizationSummary() async {
        do {
            switch try await standingAuthorization.validateCurrentAuthorization() {
            case .notGranted:
                standingAuthorizationSummary = "Not enabled. Review a fresh dry run before authorizing scheduled sync."
            case .valid:
                standingAuthorizationSummary =
                    "Enabled for the current configuration, reconciliation policy, and resolved calendar topology."
            case .invalidated:
                standingAuthorizationSummary = "Invalidated. Review a fresh dry run to enable scheduled sync again."
            }
        } catch {
            standingAuthorizationSummary =
                "Could not validate standing authorization. Resolve the earlier configuration, access, or readiness state."
        }
    }

    private static func authorizationSummary(for state: CalendarAuthorizationState) -> String {
        switch state {
        case .notDetermined: "Calendar access is not determined. Use this setup action to request full access."
        case .restricted: "Calendar access is restricted and must be resolved outside CalRelay."
        case .denied: "Calendar access is denied or revoked. Enable full access in System Settings."
        case .writeOnly: "Calendar access is write-only. Enable full access in System Settings."
        case .fullAccess:
            "Full Calendar access is available. Inventory and configured readiness remain separate checks."
        case .unknown:
            "The Calendar authorization state is unavailable. CalRelay will not request or use access automatically."
        }
    }

    private static func safeErrorMessage(_ error: Error) -> String {
        if let calendarAccessError = error as? CalendarAccessError { return calendarAccessError.description }
        return "Calendar access could not be completed. Try the setup or recovery action again."
    }

    private static func safeStandingAuthorizationErrorMessage(_ error: Error) -> String {
        if let providerError = error as? CalendarRelaySettingsProviderError {
            switch providerError {
            case .missing:
                return "The canonical configuration file is missing. Restore it before enabling scheduled sync."
            case .invalid: return "The canonical configuration file is invalid. Fix it before enabling scheduled sync."
            }
        }
        if let reconciliationError = error as? ReconcileCalendarsError { return reconciliationError.description }
        if let calendarAccessError = error as? CalendarAccessError { return calendarAccessError.description }
        if let standingError = error as? CalendarStandingAuthorizationError {
            switch standingError {
            case .operationInProgress: return "Another authorization operation is already in progress."
            case .reviewRequired: return "The reviewed authorization is stale. Load and confirm a fresh review."
            }
        }
        return "Scheduled sync authorization could not be completed. Refresh status and try again."
    }

    private static func safeOperationErrorMessage(_ error: Error) -> String {
        if let providerError = error as? CalendarRelaySettingsProviderError {
            switch providerError {
            case .missing: return "The canonical configuration file is missing. Create it, then refresh status."
            case .invalid: return "The canonical configuration file is invalid. Fix it, then refresh status."
            }
        }
        if let reconciliationError = error as? ReconcileCalendarsError { return reconciliationError.description }
        if let calendarAccessError = error as? CalendarAccessError { return calendarAccessError.description }
        return "The dry run could not be completed. Refresh status, resolve the reported prerequisite, and try again."
    }
}
