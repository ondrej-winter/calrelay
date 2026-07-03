import Foundation

public struct CalendarEvent: Equatable, Identifiable, Sendable {
    public let id: String
    public let calendar: CalendarIdentity
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let availability: EventAvailability
    public let status: EventStatus

    public init(
        id: String, calendar: CalendarIdentity, title: String, start: Date, end: Date, isAllDay: Bool,
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

    public var identity: CalendarEventIdentity { CalendarEventIdentity(id: id, calendar: calendar) }
}

public struct CalendarEventProjection: Equatable, Sendable {
    public let destinationCalendar: CalendarIdentity
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool

    public init(destinationCalendar: CalendarIdentity, title: String, start: Date, end: Date, isAllDay: Bool) {
        self.destinationCalendar = destinationCalendar
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
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

public struct VisibleEventKey: Equatable, Hashable, Sendable {
    public let calendar: CalendarIdentity
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool

    public init(calendar: CalendarIdentity, title: String, start: Date, end: Date, isAllDay: Bool) {
        self.calendar = calendar
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }

    public init(event: CalendarEvent) {
        self.init(
            calendar: event.calendar, title: event.title, start: event.start, end: event.end, isAllDay: event.isAllDay)
    }
}