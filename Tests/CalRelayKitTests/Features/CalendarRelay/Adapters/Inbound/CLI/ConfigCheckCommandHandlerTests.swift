import CalRelayKit
import Foundation

enum ConfigCheckCommandHandlerTests {
    static func runAll() async throws {
        try await testConfigCheckReportsReadyTopologyWithoutMutation()
        try await testMigrationPendingConfigCheckStillRunsPreflightAndFails()
    }

    private static func testConfigCheckReportsReadyTopologyWithoutMutation() async throws {
        let fixture = configCheckFixture()
        let configURL = try writeConfig(legacyMarkers: [])
        let store = CommandHandlerCalendarStore(calendars: fixture.calendars)
        let handler = ConfigCheckCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path)

        try expect(output.contains(configURL.path), "Config check should report the selected path")
        try expect(
            output.contains("complete configured topology is currently ready"),
            "Config check should report current readiness")
        try expect((await store.createdEvents()).isEmpty, "Config check should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Config check should not delete events")
    }

    private static func testMigrationPendingConfigCheckStillRunsPreflightAndFails() async throws {
        let fixture = configCheckFixture()
        let configURL = try writeConfig(legacyMarkers: ["[OLD]"])
        let store = CommandHandlerCalendarStore(calendars: fixture.calendars)
        let handler = ConfigCheckCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do { _ = try await handler.run(config: configURL.path) } catch let error as ConfigCheckCommandError {
            try expect(
                error == .migrationPending(selectedPath: configURL.path), "Config check should report migration pending"
            )
            try expect(
                await store.listCalendarsCallCount() == 1, "Migration-pending config check should still run preflight")
            try expect(
                await store.eventRequestCalendarIDs() == [
                    PhysicalCalendarReference(providerIdentifier: "hub-1"),
                    PhysicalCalendarReference(providerIdentifier: "work-1")
                ], "Config check should read the complete topology")
            return
        }

        throw TestFailure("Expected migration-pending config check failure")
    }

    private static func configCheckFixture() -> (now: Date, calendars: [RelayCalendar]) {
        (
            Date(timeIntervalSince1970: 10_000),
            [
                RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true),
                RelayCalendar(id: "work-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
            ]
        )
    }

    private static func writeConfig(legacyMarkers: [String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        let legacySection =
            legacyMarkers.isEmpty
            ? "" : "\nlegacyMarkers:\n" + legacyMarkers.map { "  - \"\($0)\"" }.joined(separator: "\n")
        let yaml = """
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
            \(legacySection)
            """
        try yaml.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
