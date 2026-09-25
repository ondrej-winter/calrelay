import Foundation

public struct CalendarControlPanelPresentationPolicy: Sendable {
    private let schedulingPolicy: CalendarAutomationSchedulingPolicy

    public init(schedulingPolicy: CalendarAutomationSchedulingPolicy = CalendarAutomationSchedulingPolicy()) {
        self.schedulingPolicy = schedulingPolicy
    }

    public func primaryState(
        controlPanelState: CalendarControlPanelPrimaryState,
        standingAuthorizationValidation: CalendarStandingAuthorizationValidation,
        automationState: CalendarAutomationPersistentState,
        launchAtLoginHealthy: Bool,
        now: Date
    ) -> CalendarControlPanelPresentationState {
        if let prerequisite = prerequisiteState(for: controlPanelState) { return prerequisite }
        guard standingAuthorizationValidation == .valid, automationState.standingAuthorization != nil else {
            return .standingAuthorizationRequired
        }
        guard launchAtLoginHealthy else { return .launchAtLoginUnavailable }
        if let scheduling = schedulingState(for: automationState.schedulingPreference) { return scheduling }
        if case .scheduled(let attempt, _) = automationState.operationalStatus.retryState {
            return .retryPending(attempt: attempt)
        }
        if let failure = exhaustedFailureState(for: automationState.operationalStatus.latestOutcome) { return failure }

        let isOverdue = schedulingPolicy.isFreshnessOverdue(
            schedulingPreference: automationState.schedulingPreference,
            lastSuccessAt: automationState.operationalStatus.freshness.lastSuccessAt,
            now: now)
        return isOverdue ? .freshnessOverdue : .healthy
    }

    private func prerequisiteState(for state: CalendarControlPanelPrimaryState)
        -> CalendarControlPanelPresentationState?
    {
        switch state {
        case .configurationMissing: return .configurationMissing
        case .configurationInvalid: return .configurationInvalid
        case .calendarAccessUnavailable(let state): return .calendarAccessUnavailable(state)
        case .topologyNotReady: return .topologyNotReady
        case .migrationPending: return .migrationPending
        case .ready: return nil
        }
    }

    private func schedulingState(for preference: CalendarSchedulingPreference)
        -> CalendarControlPanelPresentationState?
    {
        switch preference {
        case .disabled: return .schedulingDisabled
        case .paused: return .schedulingPaused
        case .enabled: return nil
        }
    }

    private func exhaustedFailureState(for outcome: CalendarAutomationOutcomeCategory?)
        -> CalendarControlPanelPresentationState?
    {
        switch outcome {
        case .partialMutation?: return .partialMutation
        case .transientFailure?: return .transientFailure
        default: return nil
        }
    }
}