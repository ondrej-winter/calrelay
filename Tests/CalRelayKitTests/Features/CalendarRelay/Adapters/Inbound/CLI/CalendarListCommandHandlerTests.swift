import CalRelayKit

enum CalendarListCommandHandlerTests {
    static func runAll() async throws {
        try await testCalendarListHandlerFormatsCalendarsFromInjectedStore()
        try await testCalendarListHandlerTreatsEmptyInventoryAsSuccessWithoutReadinessClaim()
        try await testCalendarListHandlerReportsReadOnlyCalendars()
        try testAppInventoryFormattingOmitsEventKitCalendarIDs()
    }

    private static func testCalendarListHandlerFormatsCalendarsFromInjectedStore() async throws {
        let store = CommandHandlerCalendarStore(calendars: [hubCalendar()])
        let authorization = CalendarListAuthorizationStatus(state: .fullAccess)
        let inventory = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: store)
        let output = try await CalendarListCommandHandler(inventory: inventory).run()

        try expect(output.contains("Calendars (1)"), "Calendar list handler should format calendar count")
        try expect(output.contains("iCloud / Personal Work"), "Calendar list handler should format calendar selector")
        try expect(output.contains("id: hub-1"), "CLI inventory should include EventKit calendar IDs")
        try expect(
            output.contains("does not verify configured readiness"), "Inventory should not make a readiness claim")
    }

    private static func testCalendarListHandlerTreatsEmptyInventoryAsSuccessWithoutReadinessClaim() async throws {
        let store = CommandHandlerCalendarStore(calendars: [])
        let authorization = CalendarListAuthorizationStatus(state: .fullAccess)
        let inventory = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: store)

        let output = try await CalendarListCommandHandler(inventory: inventory).run()

        try expect(
            output.contains("No EventKit-visible calendars"),
            "Empty inventory should produce an understandable success result")
        try expect(
            output.contains("Inventory discovery succeeded"), "Empty inventory should explicitly remain successful")
        try expect(!output.contains("configured topology is ready"), "Inventory must not claim configured readiness")
    }

    private static func testCalendarListHandlerReportsReadOnlyCalendars() async throws {
        let readOnly = RelayCalendar(
            id: "readonly-1", title: "Shared Calendar", sourceTitle: "Exchange", isWritable: false)
        let store = CommandHandlerCalendarStore(calendars: [readOnly])
        let authorization = CalendarListAuthorizationStatus(state: .fullAccess)
        let inventory = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: store)

        let output = try await CalendarListCommandHandler(inventory: inventory).run()

        try expect(output.contains("Exchange / Shared Calendar"), "Inventory should include source and title")
        try expect(output.contains("id: readonly-1"), "Inventory should include the EventKit calendar ID")
        try expect(output.contains("read-only"), "Inventory should report read-only status")
    }

    private static func testAppInventoryFormattingOmitsEventKitCalendarIDs() throws {
        let output = CalendarListFormatter.formatForApp([hubCalendar()])

        try expect(output.contains("iCloud / Personal Work"), "App inventory should include source and title")
        try expect(output.contains("writable"), "App inventory should include writability")
        try expect(!output.contains("hub-1"), "App inventory must omit EventKit calendar IDs")
        try expect(output.contains("separate from configured readiness"), "App inventory should distinguish readiness")
    }

    private static func hubCalendar() -> RelayCalendar {
        RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct CalendarListAuthorizationStatus: CalendarAuthorizationStatusPort {
    let state: CalendarAuthorizationState

    func authorizationStatus() async -> CalendarAuthorizationState { state }
}
