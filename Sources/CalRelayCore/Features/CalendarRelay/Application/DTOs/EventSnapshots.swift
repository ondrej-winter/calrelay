import Foundation

public struct EventSnapshot: Equatable, Identifiable, Sendable {
    public let id: String
    public let calendar: CalendarReference
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let availability: EventAvailability
    public let status: EventStatus

    public init(
        id: String, calendar: CalendarReference, title: String, start: Date, end: Date, isAllDay: Bool,
        availability: EventAvailability, status: EventStatus
    ) {
        self.id = id
        self.calendar = calendar
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.availability = availability
        self.status = status
    }
}

public enum EventAvailability: Equatable, Sendable, CustomStringConvertible {
    case busy
    case tentative
    case free
    case unavailable
    case notSupported
    case unknown

    public var description: String {
        switch self {
        case .busy: "busy"
        case .tentative: "tentative"
        case .free: "free"
        case .unavailable: "unavailable"
        case .notSupported: "notSupported"
        case .unknown: "unknown"
        }
    }
}

public enum EventStatus: Equatable, Sendable, CustomStringConvertible {
    case confirmed
    case tentative
    case cancelled
    case declined
    case unknown

    public var description: String {
        switch self {
        case .confirmed: "confirmed"
        case .tentative: "tentative"
        case .cancelled: "cancelled"
        case .declined: "declined"
        case .unknown: "unknown"
        }
    }
}
