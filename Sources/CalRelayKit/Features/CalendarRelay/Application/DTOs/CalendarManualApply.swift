import Foundation

public struct CalendarManualApplyReview: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let summary: CalendarManualDryRunSummary

    init(summary: CalendarManualDryRunSummary) {
        id = UUID()
        self.summary = summary
    }
}

public enum CalendarManualApplyOutcome: Equatable, Sendable {
    case reviewRequired(CalendarManualApplyReview)
    case applied(CalendarMutationExecutionResult)
}

public enum CalendarManualApplyError: Error, Equatable, Sendable {
    case operationInProgress
    case reviewRequired
    case configurationChanged
}
