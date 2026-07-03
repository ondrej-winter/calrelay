public struct CalendarEventIdentity: Equatable, Sendable {
    public let id: String
    public let calendar: CalendarIdentity

    public init(id: String, calendar: CalendarIdentity) {
        self.id = id
        self.calendar = calendar
    }
}