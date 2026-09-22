import CalRelayKit
import Foundation

enum ConfigCheckCommandHandlerTests {
    static func runAll() async throws {
        try await testConfigCheckReportsReadyTopologyWithoutMutation()
        try await testMigrationPendingConfigCheckStillRunsPreflightAndFails()
        try await testMigrationPendingConfigCheckAggregatesPreflightFailuresWithoutReadinessClaim()
        try await testStructurallyInvalidConfigFailsBeforeCalendarAccess()
        try await testConfigCheckUsesOrdinaryAccessWindow()
        try await testUnavailableAccessIsActionableAndStopsBeforeStoreAccess()
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

    private static func testMigrationPendingConfigCheckAggregatesPreflightFailuresWithoutReadinessClaim() async throws {
        let configURL = try writeConfig(legacyMarkers: ["[OLD]"])
        let originalYAML = try String(contentsOf: configURL, encoding: .utf8)
        let hub = RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: false)
        let store = CommandHandlerCalendarStore(calendars: [hub])
        let handler = ConfigCheckCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            now: { configCheckFixture().now })

        do {
            _ = try await handler.run(config: configURL.path)
            throw TestFailure("Expected migration-pending config check with access failures")
        } catch let error as ConfigCheckCommandError {
            guard case .migrationPendingWithPreflightFailures(let selectedPath, let issues) = error else {
                throw TestFailure("Expected migration pending with aggregated preflight failures")
            }
            try expect(selectedPath == configURL.path, "Migration-pending failure should retain the selected path")
            try expect(
                issues.contains(
                    .calendarReadOnly(
                        role: .hub, selector: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Personal Work"))),
                "Migration-pending config check should report the read-only hub")
            try expect(
                issues.contains(
                    .calendarMissing(
                        role: .work(name: "ACME", declarationIndex: 0),
                        selector: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))),
                "Migration-pending config check should report the missing work calendar")
            try expect(
                error.description.contains("migration pending")
                    && error.description.contains("topology is not currently ready"),
                "Migration-pending config check should report both migration and readiness failures")
            try expect(
                !error.description.contains("complete configured topology is currently ready"),
                "Migration-pending config check must not make a readiness success claim")
        }

        try expect(await store.listCalendarsCallCount() == 1, "Migration-pending config check should run preflight")
        try expect(
            await store.eventRequestCalendarIDs() == [hub.id],
            "Migration-pending config check should read every uniquely resolved role")
        try expect((await store.createdEvents()).isEmpty, "Migration-pending config check must not create events")
        try expect((await store.deletedEvents()).isEmpty, "Migration-pending config check must not delete events")
        try expect(
            try String(contentsOf: configURL, encoding: .utf8) == originalYAML,
            "Migration-pending config check must not rewrite the selected YAML")
    }

    private static func testStructurallyInvalidConfigFailsBeforeCalendarAccess() async throws {
        let configURL = try writeConfig(
            contents: canonicalConfigYAML().replacingOccurrences(
                of: "personalPrefix: \"[ME]\"", with: "personalPrefix: \"invalid\""))
        let store = CommandHandlerCalendarStore(calendars: configCheckFixture().calendars)
        let handler = ConfigCheckCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store)

        do { _ = try await handler.run(config: configURL.path) } catch is YAMLCalendarRelaySettingsError {
            try expect(
                await store.listCalendarsCallCount() == 0, "Invalid configuration should fail before Calendar access")
            return
        }

        throw TestFailure("Expected structurally invalid configuration failure")
    }

    private static func testConfigCheckUsesOrdinaryAccessWindow() async throws {
        let fixture = configCheckFixture()
        let configURL = try writeConfig(legacyMarkers: [])
        let store = CommandHandlerCalendarStore(calendars: fixture.calendars)
        let calendar = utcCalendar()
        let handler = ConfigCheckCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now },
            calendar: calendar)

        _ = try await handler.run(config: configURL.path)

        let expected = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: calendar, syncWindowDays: 1)
        try expect(
            await store.eventRequestWindows() == [expected, expected],
            "Config check should use the ordinary reconciliation window for every configured role")
    }

    private static func testUnavailableAccessIsActionableAndStopsBeforeStoreAccess() async throws {
        let fixture = configCheckFixture()
        let configURL = try writeConfig(legacyMarkers: [])
        let store = CommandHandlerCalendarStore(calendars: fixture.calendars)
        let handler = ConfigCheckCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(state: .denied), calendarStore: store,
            now: { fixture.now })

        do { _ = try await handler.run(config: configURL.path) } catch let error as ConfigCheckCommandError {
            try expect(
                error.description.contains("Enable full access for CalRelay in System Settings"),
                "Access failure should include actionable recovery guidance")
            try expect(!error.description.contains("hub-1"), "Access failure should omit physical calendar identifiers")
            try expect(await store.listCalendarsCallCount() == 0, "Denied access should prevent store access")
            try expect((await store.createdEvents()).isEmpty, "Access failure should not create events")
            try expect((await store.deletedEvents()).isEmpty, "Access failure should not delete events")
            return
        }

        throw TestFailure("Expected unavailable Calendar access failure")
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
        try writeConfig(contents: canonicalConfigYAML(legacyMarkers: legacyMarkers))
    }

    private static func writeConfig(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func canonicalConfigYAML(legacyMarkers: [String] = []) -> String {
        let legacySection =
            legacyMarkers.isEmpty
            ? "" : "\nlegacyMarkers:\n" + legacyMarkers.map { "  - \"\($0)\"" }.joined(separator: "\n")
        return """
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
