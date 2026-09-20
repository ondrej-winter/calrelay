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

public struct CalendarAutomationAttentionNotification: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(reason: CalendarAutomationAttentionReason) {
        title = "CalRelay needs attention"
        body = switch reason {
        case .schedulingPaused: "Scheduled sync is paused."
        case .standingAuthorizationRequired: "Review a fresh dry run and renew scheduled sync authorization."
        case .launchAtLoginUnavailable: "Enable or approve CalRelay in Login Items."
        case .configurationUnavailable: "Restore or fix the canonical configuration file."
        case .migrationPending: "Complete explicit legacy cleanup before scheduled sync can resume."
        case .calendarAccessUnavailable: "Restore full Calendar access in the CalRelay control panel."
        case .topologyNotReady: "Resolve the configured calendar readiness issue."
        case .partialMutation: "A scheduled run partially applied and bounded retries are exhausted."
        case .transientFailure: "Scheduled sync retries are exhausted after a transient failure."
        case .freshnessOverdue: "No successful ordinary reconciliation has completed within the last hour."
        }
    }
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