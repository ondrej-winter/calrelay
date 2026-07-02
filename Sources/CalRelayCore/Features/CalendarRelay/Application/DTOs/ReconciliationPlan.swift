import Foundation

public struct ReconciliationPlan: Equatable, Sendable {
    public let creates: [ProjectedEvent]
    public let deletes: [EventSnapshot]

    public init(creates: [ProjectedEvent], deletes: [EventSnapshot]) {
        self.creates = creates
        self.deletes = deletes
    }
}

public struct ProjectedEvent: Equatable, Sendable {
    public let destinationCalendar: CalendarReference
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool

    public init(destinationCalendar: CalendarReference, title: String, start: Date, end: Date, isAllDay: Bool) {
        self.destinationCalendar = destinationCalendar
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }
}
