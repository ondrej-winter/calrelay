import Foundation

public enum CalendarSchedulingPreference: Equatable, Sendable {
    case disabled
    case enabled
    case paused
}

public enum CalendarAutomationOutcomeCategory: Equatable, Sendable {
    case noChanges
    case applied
    case partialMutation
    case configurationUnavailable
    case migrationPending
    case calendarAccessUnavailable
    case topologyNotReady
    case standingAuthorizationRequired
    case transientFailure
}

public struct CalendarAutomationMutationCounts: Equatable, Sendable {
    public static let zero = CalendarAutomationMutationCounts(confirmedCreates: 0, confirmedDeletes: 0)

    public let confirmedCreates: Int
    public let confirmedDeletes: Int

    public init(confirmedCreates: Int, confirmedDeletes: Int) {
        self.confirmedCreates = confirmedCreates
        self.confirmedDeletes = confirmedDeletes
    }
}

public enum CalendarAutomationRetryState: Equatable, Sendable {
    case none
    case scheduled(attempt: Int, nextAttemptAt: Date)
}

public struct CalendarAutomationFreshnessMetadata: Equatable, Sendable {
    public let lastSuccessAt: Date?
    public let nextNominalRunAt: Date?

    public init(lastSuccessAt: Date?, nextNominalRunAt: Date?) {
        self.lastSuccessAt = lastSuccessAt
        self.nextNominalRunAt = nextNominalRunAt
    }
}

public struct CalendarAutomationOperationalStatus: Equatable, Sendable {
    public static let empty = CalendarAutomationOperationalStatus(
        lastAttemptAt: nil, latestOutcome: nil, confirmedCounts: .zero, retryState: .none,
        freshness: CalendarAutomationFreshnessMetadata(lastSuccessAt: nil, nextNominalRunAt: nil))

    public let lastAttemptAt: Date?
    public let latestOutcome: CalendarAutomationOutcomeCategory?
    public let confirmedCounts: CalendarAutomationMutationCounts
    public let retryState: CalendarAutomationRetryState
    public let freshness: CalendarAutomationFreshnessMetadata

    public init(
        lastAttemptAt: Date?, latestOutcome: CalendarAutomationOutcomeCategory?,
        confirmedCounts: CalendarAutomationMutationCounts, retryState: CalendarAutomationRetryState,
        freshness: CalendarAutomationFreshnessMetadata
    ) {
        self.lastAttemptAt = lastAttemptAt
        self.latestOutcome = latestOutcome
        self.confirmedCounts = confirmedCounts
        self.retryState = retryState
        self.freshness = freshness
    }
}

public struct CalendarAutomationPersistentState: Equatable, Sendable {
    public static let empty = CalendarAutomationPersistentState(
        schedulingPreference: .disabled, standingAuthorization: nil, operationalStatus: .empty)

    public let schedulingPreference: CalendarSchedulingPreference
    public let standingAuthorization: CalendarStandingAuthorizationBinding?
    public let operationalStatus: CalendarAutomationOperationalStatus

    public init(
        schedulingPreference: CalendarSchedulingPreference,
        standingAuthorization: CalendarStandingAuthorizationBinding?,
        operationalStatus: CalendarAutomationOperationalStatus
    ) {
        self.schedulingPreference = schedulingPreference
        self.standingAuthorization = standingAuthorization
        self.operationalStatus = operationalStatus
    }
}
