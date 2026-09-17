import CalRelayKit
import Foundation

enum CalendarManualDryRunTests {
    static func runAll() async throws {
        try await testDryRunLoadsFreshSettingsAndReturnsAggregateCountsWithoutMutation()
        try await testMigrationPendingFailsBeforeCalendarAccess()
        try testFormatterReportsOnlyAggregateCounts()
    }

    private static func testDryRunLoadsFreshSettingsAndReturnsAggregateCountsWithoutMutation() async throws {
        let fixture = dryRunFixture()
        let provider = CountingManualDryRunSettingsProvider(settings: fixture.settings)
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [fixture.workEvent]])
        let useCase = CalendarManualDryRunUseCase(
            settingsProvider: provider, authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            now: { fixture.now }, calendar: utcCalendar())

        let firstSummary = try await useCase.run()
        let secondSummary = try await useCase.run()

        let expectedSummary = CalendarManualDryRunSummary(plannedDeletes: 0, plannedCreates: 1)
        try expect(firstSummary == expectedSummary, "Manual dry run should expose only aggregate planned counts")
        try expect(
            secondSummary == expectedSummary,
            "Repeated manual dry runs should use a fresh plan with the same aggregate shape")
        try expect(await provider.callCount() == 2, "Manual dry run should load fresh settings for each invocation")
        try expect((await store.createdEvents()).isEmpty, "Manual dry run should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Manual dry run should not delete events")
    }

    private static func testMigrationPendingFailsBeforeCalendarAccess() async throws {
        let fixture = dryRunFixture(legacyMarkers: ["[OLD]"])
        let provider = CountingManualDryRunSettingsProvider(settings: fixture.settings)
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let useCase = CalendarManualDryRunUseCase(
            settingsProvider: provider, authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            now: { fixture.now }, calendar: utcCalendar())

        do {
            _ = try await useCase.run()
            throw TestFailure("Expected migration-pending manual dry run to fail")
        } catch let error as ReconcileCalendarsError {
            try expect(error == .migrationPending, "Manual dry run should preserve the shared migration-pending error")
        }

        try expect(
            await store.listCalendarsCallCount() == 0,
            "Migration-pending manual dry run should fail before Calendar access")
    }

    private static func testFormatterReportsOnlyAggregateCounts() throws {
        let output = CalendarManualDryRunFormatter.format(
            CalendarManualDryRunSummary(plannedDeletes: 2, plannedCreates: 3))

        try expect(
            output.contains("No calendar mutations were performed"),
            "Manual dry-run output should make non-mutation explicit")
        try expect(output.contains("Planned deletes: 2"), "Manual dry-run output should include aggregate delete count")
        try expect(output.contains("Planned creates: 3"), "Manual dry-run output should include aggregate create count")
        try expect(!output.contains("Client Planning"), "Manual dry-run output should omit event titles")
        try expect(!output.contains("hub-1"), "Manual dry-run output should omit physical calendar identifiers")
    }

    private static func dryRunFixture(legacyMarkers: [String] = []) -> ManualDryRunFixture {
        let hubCalendar = RelayCalendar(id: "hub", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let workCalendar = RelayCalendar(id: "work", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let workEvent = CalendarEvent(
            id: "source",
            calendar: CalendarIdentity(
                id: workCalendar.id, title: workCalendar.title, sourceTitle: workCalendar.sourceTitle),
            title: "Client Planning", start: Date(timeIntervalSince1970: 11_000),
            end: Date(timeIntervalSince1970: 12_000), isAllDay: false, availability: .busy, status: .confirmed)
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Personal Work")),
            personalPrefix: "[ME]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
            ], legacyMarkers: legacyMarkers)
        return ManualDryRunFixture(
            now: Date(timeIntervalSince1970: 10_000), settings: settings, hubCalendar: hubCalendar,
            workCalendar: workCalendar, workEvent: workEvent)
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private actor CountingManualDryRunSettingsProvider: CalendarRelaySettingsProvider {
    private let settings: CalendarRelaySettings
    private var calls = 0

    init(settings: CalendarRelaySettings) { self.settings = settings }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        return LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings)
    }

    func callCount() -> Int { calls }
}

private struct ManualDryRunFixture {
    let now: Date
    let settings: CalendarRelaySettings
    let hubCalendar: RelayCalendar
    let workCalendar: RelayCalendar
    let workEvent: CalendarEvent
}
