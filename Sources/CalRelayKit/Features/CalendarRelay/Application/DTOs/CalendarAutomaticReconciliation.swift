public enum CalendarAutomaticAttemptKind: Equatable, Sendable {
    case ordinary
    case retry
}

public enum CalendarAutomaticReconciliationError: Error, Equatable, Sendable {
    case schedulingNotEnabled
}

public struct CalendarAutomaticReconciliationResult: Equatable, Sendable {
    public let outcome: CalendarAutomationOutcomeCategory
    public let confirmedCounts: CalendarAutomationMutationCounts
    public let retryState: CalendarAutomationRetryState

    public init(
        outcome: CalendarAutomationOutcomeCategory,
        confirmedCounts: CalendarAutomationMutationCounts,
        retryState: CalendarAutomationRetryState
    ) {
        self.outcome = outcome
        self.confirmedCounts = confirmedCounts
        self.retryState = retryState
    }
}