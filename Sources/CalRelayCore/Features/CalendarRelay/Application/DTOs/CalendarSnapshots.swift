import Foundation

public struct CalendarSelector: Equatable, Sendable {
    public let sourceTitle: String
    public let calendarTitle: String

    public init(sourceTitle: String, calendarTitle: String) {
        self.sourceTitle = sourceTitle
        self.calendarTitle = calendarTitle
    }
}

public struct CalendarSnapshot: Equatable, Identifiable, Sendable {
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

public struct CalendarReference: Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String

    public init(id: String, title: String, sourceTitle: String) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
    }
}
