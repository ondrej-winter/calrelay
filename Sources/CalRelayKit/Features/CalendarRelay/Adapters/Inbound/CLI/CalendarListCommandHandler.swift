public struct CalendarListCommandHandler: Sendable {
    private let calendarStore: CalendarStorePort

    public init(calendarStore: CalendarStorePort = EventKitCalendarStore()) {
        self.calendarStore = calendarStore
    }

    public func run() async throws -> String {
        let calendars = try await calendarStore.listCalendars()
        return CalendarListFormatter.format(calendars)
    }
}