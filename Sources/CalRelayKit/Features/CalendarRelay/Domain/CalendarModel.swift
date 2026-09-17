import Foundation

public struct RelayCalendar: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let isWritable: Bool

    public init(id: String, title: String, sourceTitle: String, isWritable: Bool) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.isWritable = isWritable
    }
}

public struct CalendarIdentity: Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String

    public init(id: String, title: String, sourceTitle: String) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
    }
}

public struct CalendarSelector: Equatable, Sendable {
    public let sourceTitle: String
    public let calendarTitle: String

    public init(sourceTitle: String, calendarTitle: String) {
        self.sourceTitle = sourceTitle
        self.calendarTitle = calendarTitle
    }
}

public struct CalendarEventIdentity: Equatable, Sendable {
    public let id: String
    public let calendar: CalendarIdentity
    public let occurrenceDate: Date?
    public let lookupStart: Date?
    public let lookupEnd: Date?

    public init(
        id: String, calendar: CalendarIdentity, occurrenceDate: Date? = nil, lookupStart: Date? = nil,
        lookupEnd: Date? = nil
    ) {
        self.id = id
        self.calendar = calendar
        self.occurrenceDate = occurrenceDate
        self.lookupStart = lookupStart
        self.lookupEnd = lookupEnd
    }
}
