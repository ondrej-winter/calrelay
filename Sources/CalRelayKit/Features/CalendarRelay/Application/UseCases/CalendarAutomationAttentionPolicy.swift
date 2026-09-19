import Foundation

public enum CalendarAutomationAttentionReason: Equatable, Sendable {
    case schedulingPaused
    case standingAuthorizationRequired
    case launchAtLoginUnavailable
    case configurationUnavailable
    case migrationPending
    case calendarAccessUnavailable
    case topologyNotReady
    case partialMutation
    case transientFailure
    case freshnessOverdue
}

public struct CalendarAutomationAttentionPolicy: Sendable {
    private let schedulingPolicy: CalendarAutomationSchedulingPolicy

    public init(schedulingPolicy: CalendarAutomationSchedulingPolicy = CalendarAutomationSchedulingPolicy()) {
        self.schedulingPolicy = schedulingPolicy
    }

    public func reason(
        schedulingPreference: CalendarSchedulingPreference,
        hasStandingAuthorization: Bool,
        launchAtLoginHealthy: Bool,
        operationalStatus: CalendarAutomationOperationalStatus,
        now: Date
    ) -> CalendarAutomationAttentionReason? {
        guard schedulingPreference != .disabled else { return nil }
        if let prerequisite = prerequisiteReason(
            schedulingPreference: schedulingPreference,
            hasStandingAuthorization: hasStandingAuthorization,
            launchAtLoginHealthy: launchAtLoginHealthy)
        {
            return prerequisite
        }
        if let outcome = outcomeReason(
            operationalStatus.latestOutcome, retryState: operationalStatus.retryState)
        {
            return outcome
        }
        return schedulingPolicy.isFreshnessOverdue(
            schedulingPreference: schedulingPreference,
            lastSuccessAt: operationalStatus.freshness.lastSuccessAt,
            now: now
        ) ? .freshnessOverdue : nil
    }

    private func prerequisiteReason(
        schedulingPreference: CalendarSchedulingPreference,
        hasStandingAuthorization: Bool,
        launchAtLoginHealthy: Bool
    ) -> CalendarAutomationAttentionReason? {
        switch schedulingPreference {
        case .disabled: return nil
        case .paused: return .schedulingPaused
        case .enabled: break
        }
        guard hasStandingAuthorization else { return .standingAuthorizationRequired }
        return launchAtLoginHealthy ? nil : .launchAtLoginUnavailable
    }

    private func outcomeReason(
        _ outcome: CalendarAutomationOutcomeCategory?,
        retryState: CalendarAutomationRetryState
    ) -> CalendarAutomationAttentionReason? {
        switch outcome {
        case .configurationUnavailable?: return .configurationUnavailable
        case .migrationPending?: return .migrationPending
        case .calendarAccessUnavailable?: return .calendarAccessUnavailable
        case .topologyNotReady?: return .topologyNotReady
        case .standingAuthorizationRequired?: return .standingAuthorizationRequired
        case .partialMutation?: return retryState == .none ? .partialMutation : nil
        case .transientFailure?: return retryState == .none ? .transientFailure : nil
        case .noChanges?, .applied?, nil: break
        }
        return nil
    }
}