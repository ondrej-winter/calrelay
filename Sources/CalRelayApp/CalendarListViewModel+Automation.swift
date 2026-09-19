import CalRelayKit
import Foundation

extension CalendarListViewModel {
    var isSchedulingEnabled: Bool { schedulingPreference == .enabled }
    var isSchedulingPaused: Bool { schedulingPreference == .paused }

    func pauseScheduling() {
        guard beginOperation(.automationSettings) else { return }
        Task {
            do {
                try await automationState.setSchedulingPreference(.paused)
                stopAutomationTriggers()
                try await automationState.setNextNominalRunAt(nil)
                await refreshAutomationPresentation()
                output = "Scheduled sync paused. Launch at login remains unchanged."
            } catch {
                output = "Scheduled sync could not be paused. Try again."
            }
            finishOperation()
        }
    }

    func resumeScheduling() {
        guard beginOperation(.automationSettings) else { return }
        Task {
            do {
                guard try await standingAuthorization.validateCurrentAuthorization() == .valid else {
                    output = "Scheduled sync cannot resume until a fresh dry run is reviewed and authorized."
                    finishOperation()
                    return
                }
                try await automationState.setSchedulingPreference(.enabled)
                enableLaunchAtLoginForScheduling()
                await refreshAutomationPresentation()
                await startAutomationTriggersIfNeeded(runLaunchAttempt: true)
                output = "Scheduled sync resumed. A fresh automatic attempt is queued."
            } catch {
                output = "Scheduled sync could not be resumed. Refresh status and try again."
            }
            finishOperation()
        }
    }

    func enableLaunchAtLogin() {
        guard beginOperation(.automationSettings) else { return }
        Task {
            do {
                try launchAtLogin.enable()
                output = "Launch at login is enabled for the normal CalRelay app."
            } catch {
                output = "Launch at login could not be enabled. Review Login Items in System Settings."
            }
            await refreshAutomationPresentation()
            finishOperation()
        }
    }

    func restoreAutomationLifecycle() async {
        let state = await automationState.loadState()
        applyAutomationState(state)
        refreshLaunchAtLoginSummary()
        await refreshNotificationSummary()
        if state.schedulingPreference == .enabled {
            automationTriggers.scheduleRetry(state.operationalStatus.retryState)
            await startAutomationTriggersIfNeeded(runLaunchAttempt: true)
        }
    }

    func refreshAutomationPresentation() async {
        let state = await automationState.loadState()
        applyAutomationState(state)
        refreshLaunchAtLoginSummary()
        await refreshNotificationSummary()
    }

    func requestAutomaticAttempt(kind: CalendarAutomaticAttemptKind) {
        switch operationCoordinator.request(.automaticReconciliation) {
        case .start:
            runAutomaticAttempt(kind: kind)
        case .coalesced:
            pendingAutomaticKind = mergedAutomaticKind(pendingAutomaticKind, kind)
        case .rejected:
            break
        }
    }

    func runAutomaticAttempt(kind: CalendarAutomaticAttemptKind) {
        isLoading = true
        output = kind == .retry ? "Running a fresh scheduled retry…" : "Running a fresh scheduled sync…"
        Task {
            do {
                let result = try await automaticReconciliation.run(kind: kind)
                automationTriggers.scheduleRetry(result.retryState)
                applyAutomationState(await automationState.loadState())
                output = Self.automaticOutput(result)
            } catch CalendarAutomaticReconciliationError.schedulingNotEnabled {
                applyAutomationState(await automationState.loadState())
            } catch {
                output = "Scheduled sync could not record its result. Refresh status and try again."
            }
            finishOperation()
        }
    }

    func startAutomationTriggersIfNeeded(runLaunchAttempt: Bool) async {
        if !isAutomationTriggerSourceRunning {
            let nextNominalRunAt = automationTriggers.start { [weak self] trigger, nextNominalRunAt in
                self?.handleAutomaticTrigger(trigger, nextNominalRunAt: nextNominalRunAt)
            }
            isAutomationTriggerSourceRunning = true
            try? await automationState.setNextNominalRunAt(nextNominalRunAt)
        }
        if runLaunchAttempt { requestAutomaticAttempt(kind: .ordinary) }
    }

    func stopAutomationTriggers() {
        automationTriggers.stop()
        isAutomationTriggerSourceRunning = false
    }

    func enableLaunchAtLoginForScheduling() {
        do { try launchAtLogin.enable() } catch {}
    }

    func takePendingAutomaticKind() -> CalendarAutomaticAttemptKind {
        defer { pendingAutomaticKind = nil }
        return pendingAutomaticKind ?? .ordinary
    }

    private func handleAutomaticTrigger(_ trigger: CalendarAutomaticTrigger, nextNominalRunAt: Date?) {
        Task {
            if let nextNominalRunAt { try? await automationState.setNextNominalRunAt(nextNominalRunAt) }
            requestAutomaticAttempt(kind: trigger == .retry ? .retry : .ordinary)
        }
    }

    private func mergedAutomaticKind(
        _ existing: CalendarAutomaticAttemptKind?,
        _ incoming: CalendarAutomaticAttemptKind
    ) -> CalendarAutomaticAttemptKind {
        existing == .ordinary || incoming == .ordinary ? .ordinary : .retry
    }

    func applyAutomationState(_ state: CalendarAutomationPersistentState) {
        schedulingPreference = state.schedulingPreference
        switch state.schedulingPreference {
        case .disabled: schedulingSummary = "Disabled until scheduled sync is explicitly authorized."
        case .enabled: schedulingSummary = "Enabled while the normal CalRelay app is running."
        case .paused: schedulingSummary = "Paused. CalRelay is not maintaining freshness."
        }

        let status = state.operationalStatus
        let policy = CalendarAutomationSchedulingPolicy()
        let overdue = policy.isFreshnessOverdue(
            schedulingPreference: state.schedulingPreference, lastSuccessAt: status.freshness.lastSuccessAt, now: Date())
        automaticOperationSummary = [
            "Last attempt: \(Self.format(status.lastAttemptAt))",
            "Latest outcome: \(Self.outcomeDescription(status.latestOutcome))",
            "Confirmed creates/deletes: \(status.confirmedCounts.confirmedCreates)/\(status.confirmedCounts.confirmedDeletes)",
            "Last success: \(Self.format(status.freshness.lastSuccessAt))",
            "Next nominal run: \(Self.format(status.freshness.nextNominalRunAt))",
            "Retry: \(Self.retryDescription(status.retryState))",
            "Freshness: \(overdue ? "overdue" : "not overdue")"
        ].joined(separator: "\n")
        applyAutomationAttention(state, overdue: overdue)
        applyAutomationPrimaryState(state, overdue: overdue)
    }

    func refreshLaunchAtLoginSummary() {
        switch launchAtLogin.currentState() {
        case .enabled: launchAtLoginSummary = "Enabled for the normal Dock-visible app."
        case .disabled:
            launchAtLoginSummary =
                isSchedulingEnabled ? "Disabled while scheduling is enabled; post-login freshness is degraded." : "Disabled."
        case .requiresApproval:
            launchAtLoginSummary = "Requires approval in System Settings > General > Login Items."
        case .unavailable: launchAtLoginSummary = "Unavailable for the current app installation."
        }
    }

    func refreshNotificationSummary() async {
        notificationSummary = await automationAttention.authorizationSummary()
    }

    private func applyAutomationAttention(_ state: CalendarAutomationPersistentState, overdue: Bool) {
        let reason = CalendarAutomationAttentionPolicy().reason(
            schedulingPreference: state.schedulingPreference,
            hasStandingAuthorization: state.standingAuthorization != nil,
            launchAtLoginHealthy: launchAtLogin.currentState() == .enabled,
            operationalStatus: state.operationalStatus,
            now: Date())
        automationAttention.update(reason: reason)
        automationAttentionSummary = Self.attentionDescription(reason, overdue: overdue)
    }

    private func applyAutomationPrimaryState(_ state: CalendarAutomationPersistentState, overdue: Bool) {
        guard controlPanelPrimaryState == .ready else { return }
        if state.standingAuthorization == nil {
            primaryStatus = "Scheduled sync requires a fresh reviewed authorization."
        } else if state.schedulingPreference == .enabled, launchAtLogin.currentState() != .enabled {
            primaryStatus = "Scheduling is enabled, but launch at login requires recovery."
        } else if state.schedulingPreference == .paused {
            primaryStatus = "Scheduled sync is paused and freshness is not being maintained."
        } else if case .scheduled(let attempt, _) = state.operationalStatus.retryState {
            primaryStatus = "Scheduled sync is active with bounded retry attempt \(attempt) pending."
        } else if overdue {
            primaryStatus = "Scheduled sync freshness is overdue."
        } else if state.schedulingPreference == .enabled {
            primaryStatus = "Scheduled sync is healthy while the normal app is running."
        }
    }

    private static func attentionDescription(_ reason: CalendarAutomationAttentionReason?, overdue: Bool) -> String {
        guard let reason else {
            return overdue ? "Freshness is overdue." : "No automation recovery attention is required."
        }
        return attentionDescription(reason)
    }

    private static func attentionDescription(_ reason: CalendarAutomationAttentionReason) -> String {
        return switch reason {
        case .schedulingPaused: "Scheduling is paused; the Dock badge remains until scheduling resumes."
        case .standingAuthorizationRequired: "A fresh reviewed standing authorization is required."
        case .launchAtLoginUnavailable: "Launch at login is unavailable, disabled, or awaiting approval."
        case .configurationUnavailable: "The canonical configuration is missing or invalid."
        case .migrationPending: "Explicit legacy cleanup is required."
        case .calendarAccessUnavailable: "Full Calendar access is unavailable."
        case .topologyNotReady: "The configured calendar topology is not ready."
        case .partialMutation: "A partial mutation remains after bounded retries were exhausted."
        case .transientFailure: "A transient failure remains after bounded retries were exhausted."
        case .freshnessOverdue: "No successful ordinary reconciliation has completed within the last hour."
        }
    }

    private static func automaticOutput(_ result: CalendarAutomaticReconciliationResult) -> String {
        switch result.outcome {
        case .noChanges: "Scheduled sync completed with no changes."
        case .applied:
            "Scheduled sync applied \(result.confirmedCounts.confirmedDeletes) deletes and \(result.confirmedCounts.confirmedCreates) creates."
        case .partialMutation:
            "Scheduled sync partially applied. Confirmed deletes: \(result.confirmedCounts.confirmedDeletes); creates: \(result.confirmedCounts.confirmedCreates). A bounded fresh retry may follow."
        case .configurationUnavailable: "Scheduled sync is waiting for a valid configuration."
        case .migrationPending: "Scheduled sync is blocked until explicit legacy cleanup is completed."
        case .calendarAccessUnavailable: "Scheduled sync is waiting for full Calendar access."
        case .topologyNotReady: "Scheduled sync is waiting for the configured calendar topology to be ready."
        case .standingAuthorizationRequired: "Scheduled sync requires a fresh reviewed authorization."
        case .transientFailure: "Scheduled sync hit a transient read failure. A bounded fresh retry may follow."
        }
    }

    private static func format(_ date: Date?) -> String {
        guard let date else { return "none" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private static func outcomeDescription(_ outcome: CalendarAutomationOutcomeCategory?) -> String {
        guard let outcome else { return "none" }
        return switch outcome {
        case .noChanges: "no changes"
        case .applied: "applied"
        case .partialMutation: "partial mutation"
        case .configurationUnavailable: "configuration unavailable"
        case .migrationPending: "migration pending"
        case .calendarAccessUnavailable: "Calendar access unavailable"
        case .topologyNotReady: "topology not ready"
        case .standingAuthorizationRequired: "standing authorization required"
        case .transientFailure: "transient failure"
        }
    }

    private static func retryDescription(_ state: CalendarAutomationRetryState) -> String {
        switch state {
        case .none: "none"
        case .scheduled(let attempt, let date): "attempt \(attempt) at \(format(date))"
        }
    }
}