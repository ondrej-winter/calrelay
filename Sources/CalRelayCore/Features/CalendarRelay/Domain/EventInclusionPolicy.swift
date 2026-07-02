import Foundation

/// Explains why `EventInclusionPolicy` accepted or rejected a candidate event.
///
/// `EventInclusionPolicy.includes` remains the single source of truth for the boolean
/// decision. `evaluate` exposes the same decision with a stable, non-sensitive reason so
/// diagnostic tooling can explain sync behavior without duplicating the inclusion rules.
public enum EventInclusionReason: Equatable, Sendable {
    case included
    case allDay
    case cancelled
    case declined
    case tentative
    case unsupportedAvailability(EventAvailability)
}

public enum EventInclusionPolicy {
    public static func includes(_ event: EventSnapshot) -> Bool {
        evaluate(event) == .included
    }

    public static func evaluate(_ event: EventSnapshot) -> EventInclusionReason {
        guard !event.isAllDay else {
            return .allDay
        }

        guard event.status != .cancelled else {
            return .cancelled
        }

        guard event.status != .declined else {
            return .declined
        }

        guard event.status != .tentative else {
            return .tentative
        }

        switch event.availability {
        case .busy, .notSupported:
            return .included
        case .tentative, .free, .unavailable, .unknown:
            return .unsupportedAvailability(event.availability)
        }
    }
}
