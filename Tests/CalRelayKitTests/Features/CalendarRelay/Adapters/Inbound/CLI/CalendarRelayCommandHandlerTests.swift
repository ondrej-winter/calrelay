import CalRelayKit
import Foundation

enum CalendarRelayCommandHandlerTests {
    static func runAll() async throws {
        try await testCalendarListHandlerFormatsCalendarsFromInjectedStore()
        try await testReconcileHandlerFormatsDryRunPlanFromInjectedStoreAndConfig()
        try await testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig()
    }

    private static func testCalendarListHandlerFormatsCalendarsFromInjectedStore() async throws {
        let store = CommandHandlerCalendarStore(calendars: [hubCalendar()])
        let output = try await CalendarListCommandHandler(calendarStore: store).run()

        try expect(output.contains("Calendars (1)"), "Calendar list handler should format calendar count")
        try expect(output.contains("iCloud / Personal Work"), "Calendar list handler should format calendar selector")
    }

    private static func testReconcileHandlerFormatsDryRunPlanFromInjectedStoreAndConfig() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false)

        try expect(output.contains("Dry-run mode. No calendar mutations were performed."), "Dry-run output should include mode message")
        try expect(output.contains("Creates (1)"), "Dry-run output should include planned create count")
        try expect(output.contains("[ACME] Client Planning"), "Dry-run output should include planned projection title")
        try expect((await store.createdEvents()).isEmpty, "Dry-run handler should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Dry-run handler should not delete events")
    }

    private static func testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: true)

        try expect(output.contains("Google / ACME Work"), "Explanation output should include candidate calendar")
        try expect(output.contains("Client Planning"), "Explanation output should include candidate event title")
        try expect(output.contains("-> included"), "Explanation output should include inclusion reason")
        try expect(!output.contains("Dry-run mode"), "Explanation output should not include dry-run plan mode")
    }

    private static func reconciliationFixture() -> CommandHandlerFixture {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = Self.hubCalendar()
        let workCalendar = RelayCalendar(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let workReference = CalendarIdentity(
            id: workCalendar.id, title: workCalendar.title, sourceTitle: workCalendar.sourceTitle)
        let workEvent = CalendarEvent(
            id: "acme-source-1", calendar: workReference, title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000), end: Date(timeIntervalSince1970: 12_000), isAllDay: false,
            availability: .busy, status: .confirmed)

        return CommandHandlerFixture(now: now, hubCalendar: hubCalendar, workCalendar: workCalendar, workEvent: workEvent)
    }

    private static func hubCalendar() -> RelayCalendar {
        RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
    }

    private static func writeTemporaryConfigFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        try canonicalSettingsYAML().write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func canonicalSettingsYAML() -> String {
        """
        hubCalendar:
          sourceTitle: "iCloud"
          calendarTitle: "Personal Work"
        personalPrefix: "[ME]"
        syncWindowDays: 1
        workCalendars:
          - name: "ACME"
            prefix: "[ACME]"
            calendar:
              sourceTitle: "Google"
              calendarTitle: "ACME Work"
        """
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct CommandHandlerFixture {
    let now: Date
    let hubCalendar: RelayCalendar
    let workCalendar: RelayCalendar
    let workEvent: CalendarEvent
}

private actor CommandHandlerCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let eventsByCalendarID: [String: [CalendarEvent]]
    private var recordedCreates: [CalendarEventProjection] = []
    private var recordedDeletes: [CalendarEventIdentity] = []

    init(calendars: [RelayCalendar], eventsByCalendarID: [String: [CalendarEvent]] = [:]) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { recordedCreates.append(event) }

    func deleteEvent(_ event: CalendarEventIdentity) async throws { recordedDeletes.append(event) }

    func createdEvents() -> [CalendarEventProjection] { recordedCreates }

    func deletedEvents() -> [CalendarEventIdentity] { recordedDeletes }
}