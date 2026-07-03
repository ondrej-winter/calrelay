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
