import Foundation

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