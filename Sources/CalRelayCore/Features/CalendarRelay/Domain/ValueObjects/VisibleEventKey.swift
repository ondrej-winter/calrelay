import Foundation

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
