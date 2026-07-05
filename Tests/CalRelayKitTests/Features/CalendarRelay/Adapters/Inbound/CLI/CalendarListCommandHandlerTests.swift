import CalRelayKit

enum CalendarListCommandHandlerTests {
    static func runAll() async throws {
        try await testCalendarListHandlerFormatsCalendarsFromInjectedStore()
    }

    private static func testCalendarListHandlerFormatsCalendarsFromInjectedStore() async throws {
        let store = CommandHandlerCalendarStore(calendars: [hubCalendar()])
        let output = try await CalendarListCommandHandler(calendarStore: store).run()

        try expect(output.contains("Calendars (1)"), "Calendar list handler should format calendar count")
        try expect(output.contains("iCloud / Personal Work"), "Calendar list handler should format calendar selector")
    }

    private static func hubCalendar() -> RelayCalendar {
        RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}