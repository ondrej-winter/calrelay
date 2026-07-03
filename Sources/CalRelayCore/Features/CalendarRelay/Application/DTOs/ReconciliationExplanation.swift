/// Diagnostic view of a reconciliation run.
///
/// The current explanation focuses on candidate event inclusion decisions. The result type is
/// intentionally scoped to reconciliation so it can grow to include planned creates, deletes,
/// preserved events, and ignored events without redefining the public explain API.
public struct ReconciliationExplanation: Equatable, Sendable {
    public let candidates: [CandidateEventExplanation]

    public init(candidates: [CandidateEventExplanation]) {
        self.candidates = candidates
    }
}

public struct CandidateEventExplanation: Equatable, Sendable {
    public let event: CalendarEvent
    public let inclusion: EventInclusionReason

    public init(event: CalendarEvent, inclusion: EventInclusionReason) {
        self.event = event
        self.inclusion = inclusion
    }
}