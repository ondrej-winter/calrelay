import Foundation

public struct CalendarAutomationSchedulingPolicy: Sendable {
    public static let nominalInterval: TimeInterval = 15 * 60
    public static let freshnessInterval: TimeInterval = 60 * 60

    private let retryDelays: [TimeInterval]

    public init(retryDelays: [TimeInterval] = [60, 5 * 60, 15 * 60]) { self.retryDelays = retryDelays }

    public func nextNominalRun(after now: Date, previousNominalRun: Date? = nil) -> Date {
        (previousNominalRun ?? now).addingTimeInterval(Self.nominalInterval)
    }

    public func nextRetry(
        after outcome: CalendarAutomationOutcomeCategory,
        previousRetry: CalendarAutomationRetryState,
        now: Date
    ) -> CalendarAutomationRetryState {
        guard outcome == .transientFailure || outcome == .partialMutation else { return .none }
        let previousAttempt: Int
        switch previousRetry {
        case .none: previousAttempt = 0
        case .scheduled(let attempt, _): previousAttempt = attempt
        }
        guard previousAttempt < retryDelays.count else { return .none }
        let attempt = previousAttempt + 1
        return .scheduled(attempt: attempt, nextAttemptAt: now.addingTimeInterval(retryDelays[previousAttempt]))
    }

    public func isFreshnessOverdue(
        schedulingPreference: CalendarSchedulingPreference,
        lastSuccessAt: Date?,
        now: Date
    ) -> Bool {
        guard schedulingPreference == .enabled else { return false }
        guard let lastSuccessAt else { return true }
        return now.timeIntervalSince(lastSuccessAt) > Self.freshnessInterval
    }
}