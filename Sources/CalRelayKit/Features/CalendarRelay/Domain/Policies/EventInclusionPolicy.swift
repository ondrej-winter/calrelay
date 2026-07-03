import Foundation

public enum EventInclusionPolicy {
    public static func includes(_ event: CalendarEvent) -> Bool { evaluate(event) == .included }

    public static func evaluate(_ event: CalendarEvent) -> EventInclusionReason {
        guard !event.isAllDay else { return .allDay }

        guard event.status != .cancelled else { return .cancelled }

        guard event.status != .declined else { return .declined }

        guard event.status != .tentative else { return .tentative }

        switch event.availability {
        case .busy, .notSupported: return .included
        case .tentative, .free, .unavailable, .unknown: return .unsupportedAvailability(event.availability)
        }
    }
}
