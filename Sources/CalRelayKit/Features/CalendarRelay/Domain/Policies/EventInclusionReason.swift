/// Explains why `EventInclusionPolicy` accepted or rejected a candidate event.
///
/// `EventInclusionPolicy.includes` remains the single source of truth for the boolean
/// decision. `evaluate` exposes the same decision with a stable, non-sensitive reason so
/// diagnostic tooling can explain sync behavior without duplicating the inclusion rules.
public enum EventInclusionReason: Equatable, Sendable {
    case cancelled
    case currentUserAccepted
    case currentUserNonAccepted(CurrentUserParticipantStatus)
    case noCurrentUserAttendeeIncluded(EventAvailability)
    case noCurrentUserAttendeeExcluded(EventAvailability)
}
