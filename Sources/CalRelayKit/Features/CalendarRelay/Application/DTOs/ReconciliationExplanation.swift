/// Diagnostic view of an ordinary reconciliation run.
public struct ReconciliationExplanation: Equatable, Sendable {
    public let window: CalendarAccessWindow
    public let syncWindowDays: Int
    public let candidates: [CandidateEventExplanation]
    public let actions: [PlannedActionExplanation]

    public init(
        window: CalendarAccessWindow, syncWindowDays: Int, candidates: [CandidateEventExplanation],
        actions: [PlannedActionExplanation] = []
    ) {
        self.window = window
        self.syncWindowDays = syncWindowDays
        self.candidates = candidates
        self.actions = actions
    }
}

public struct CandidateEventExplanation: Equatable, Sendable {
    public let event: CalendarEvent
    public let eligibility: CandidateEventEligibilityExplanation
    public let routing: CandidateEventRoutingExplanation
    public let expectation: CandidateEventExpectationExplanation
    public let disposition: CandidateEventDispositionExplanation

    public init(
        event: CalendarEvent, eligibility: CandidateEventEligibilityExplanation,
        routing: CandidateEventRoutingExplanation, expectation: CandidateEventExpectationExplanation,
        disposition: CandidateEventDispositionExplanation
    ) {
        self.event = event
        self.eligibility = eligibility
        self.routing = routing
        self.expectation = expectation
        self.disposition = disposition
    }
}

public enum CandidateEventEligibilityExplanation: Equatable, Sendable {
    case reliableCancellation
    case currentUserAccepted
    case currentUserNonAccepted(CurrentUserParticipantStatus)
    case noCurrentUserAttendeeIncluded(EventAvailability)
    case noCurrentUserAttendeeExcluded(EventAvailability)
    case markedHubEligibilityBypass
}

public enum CandidateEventRoutingExplanation: Equatable, Sendable {
    case workToHubSource
    case hubPersonalSource
    case exactLocalMarkerHubSource(role: ConfiguredCalendarRole)
    case nonLocalValidMarkerHubSource
    case cancelledMarkedHubPreservation
    case invalidOrUnmarkedHubSource
    case feedbackSuppressedMarkedWorkProjection
}

public enum CandidateEventExpectationExplanation: Equatable, Sendable {
    case matchesExpectedProjection
    case noMatchingExpectation
}

public enum CandidateEventDispositionExplanation: Equatable, Sendable {
    case retained
    case preservedUnmanagedOrNonLocal
    case selectedStaleManagedDeletion
    case selectedCancelledManagedDeletion
    case selectedDuplicateSetDeletion
}

public struct PlannedActionExplanation: Equatable, Sendable {
    public let action: CalendarMutationAction
    public let reason: PlannedActionExplanationReason
    public let causalEvents: [CalendarEventIdentity]

    public init(
        action: CalendarMutationAction, reason: PlannedActionExplanationReason,
        causalEvents: [CalendarEventIdentity] = []
    ) {
        self.action = action
        self.reason = reason
        self.causalEvents = causalEvents
    }
}

public enum PlannedActionExplanationReason: Equatable, Sendable {
    case missingExpectedProjection
    case staleManagedProjection
    case cancelledManagedProjection
    case replaceAllManagedDuplicate
}
