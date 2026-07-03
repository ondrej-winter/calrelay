public struct CalendarSelector: Equatable, Sendable {
    public let sourceTitle: String
    public let calendarTitle: String

    public init(sourceTitle: String, calendarTitle: String) {
        self.sourceTitle = sourceTitle
        self.calendarTitle = calendarTitle
    }
}