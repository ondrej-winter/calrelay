import Foundation

public enum EventInclusionPolicy {
    public static func includes(_ event: EventSnapshot) -> Bool {
        guard !event.isAllDay else {
            return false
        }

        guard event.status != .cancelled, event.status != .declined else {
            return false
        }

        return event.availability == .busy || event.availability == .tentative
    }
}