import Foundation

public enum EventInclusionPolicy {
    public static func includes(_ event: CalendarEvent) -> Bool {
        switch evaluate(event) {
        case .currentUserAccepted, .noCurrentUserAttendeeIncluded: true
        case .cancelled, .currentUserNonAccepted, .noCurrentUserAttendeeExcluded: false
        }
    }

    public static func evaluate(_ event: CalendarEvent) -> EventInclusionReason {
        guard event.status != .cancelled else { return .cancelled }

        if let currentUserParticipantStatus = event.currentUserParticipantStatus {
            if currentUserParticipantStatus == .accepted { return .currentUserAccepted }
            return .currentUserNonAccepted(currentUserParticipantStatus)
        }

        switch event.availability {
        case .busy, .unavailable, .notSupported: return .noCurrentUserAttendeeIncluded(event.availability)
        case .tentative, .free, .unknown: return .noCurrentUserAttendeeExcluded(event.availability)
        }
    }
}
