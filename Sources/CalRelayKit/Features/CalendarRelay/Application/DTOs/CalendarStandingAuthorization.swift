import Foundation

public struct CalendarStandingAuthorizationReview: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let summary: CalendarManualDryRunSummary

    public init(id: UUID = UUID(), summary: CalendarManualDryRunSummary) {
        self.id = id
        self.summary = summary
    }
}

public enum CalendarStandingAuthorizationOutcome: Equatable, Sendable {
    case granted
    case reviewRequired(CalendarStandingAuthorizationReview)
}

public enum CalendarStandingAuthorizationValidation: Equatable, Sendable {
    case notGranted
    case valid
    case invalidated
}

public enum CalendarStandingAuthorizationError: Error, Equatable, Sendable {
    case operationInProgress
    case reviewRequired
}
