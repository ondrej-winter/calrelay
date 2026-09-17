import CalRelayKit
import Foundation

enum ReconcileCommandHandlerTests {
    static func runAll() async throws {
        try await testReconcileHandlerFormatsDryRunPlanFromInjectedStoreAndConfig()
        try await testDryRunFormatsActionsInExecutionOrder()
        try await testReconcileHandlerFormatsApplyPlanFromInjectedStoreAndConfig()
        try await testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig()
        try await testOrdinaryMigrationPendingFailsBeforeCalendarAccess()
        try await testCleanupDryRunFormatsReviewWithoutMutation()
        try await testCleanupApplyEmitsFreshReviewAndProgressiveConfirmation()
    }

    private static func testReconcileHandlerFormatsDryRunPlanFromInjectedStoreAndConfig() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)

        try expect(
            output.contains("Dry-run mode. No calendar mutations were performed."),
            "Dry-run output should include mode message")
        try expect(output.contains("Creates (1)"), "Dry-run output should include planned create count")
        try expect(output.contains("[ACME] Client Planning"), "Dry-run output should include planned projection title")
        try expect((await store.createdEvents()).isEmpty, "Dry-run handler should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Dry-run handler should not delete events")
    }

    private static func testDryRunFormatsActionsInExecutionOrder() async throws {
        let fixture = reconciliationFixture()
        let staleHubEvent = CalendarEvent(
            id: "stale-hub",
            calendar: CalendarIdentity(
                id: fixture.hubCalendar.id, title: fixture.hubCalendar.title,
                sourceTitle: fixture.hubCalendar.sourceTitle), title: "[ACME] Old Planning",
            start: fixture.workEvent.start, end: fixture.workEvent.end, isAllDay: false, availability: .busy,
            status: .confirmed)
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.hubCalendar.id: [staleHubEvent], fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)

        guard let deleteIndex = output.range(of: "- delete")?.lowerBound,
            let createIndex = output.range(of: "- create")?.lowerBound
        else { throw TestFailure("Expected dry-run delete and create rows") }
        try expect(deleteIndex < createIndex, "Dry-run rows should follow delete-first execution order")
    }

    private static func testReconcileHandlerFormatsApplyPlanFromInjectedStoreAndConfig() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let progressiveOutput = CommandOutputRecorder()
        let output = try await handler.run(
            config: configURL.path, apply: true, explain: false, cleanupLegacy: false,
            onOutput: { line in await progressiveOutput.record(line) })

        try expect(
            output.contains("Apply mode. Planned calendar mutations were performed."),
            "Apply output should include mode message")
        try expect(output.contains("Creates (1)"), "Apply output should include planned create count")
        try expect(await store.createdEvents().count == 1, "Apply handler should create planned events")
        try expect((await store.deletedEvents()).isEmpty, "Apply handler should not delete events in this fixture")
        try expect(
            await progressiveOutput.values() == ["Confirmed create for Hub."],
            "Apply should emit confirmation only after the successful mutation")
    }

    private static func testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig() async throws {
        let fixture = reconciliationFixture()
        let staleHubEvent = CalendarEvent(
            id: "stale-hub",
            calendar: CalendarIdentity(
                id: fixture.hubCalendar.id, title: fixture.hubCalendar.title,
                sourceTitle: fixture.hubCalendar.sourceTitle), title: "[ACME] Old Planning",
            start: fixture.workEvent.start, end: fixture.workEvent.end, isAllDay: false, availability: .busy,
            status: .confirmed)
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.hubCalendar.id: [staleHubEvent], fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: true, cleanupLegacy: false)

        try expect(output.contains("Google / ACME Work"), "Explanation output should include candidate calendar")
        try expect(output.contains("Client Planning"), "Explanation output should include candidate event title")
        try expect(output.contains("event-id=acme-source-1"), "Successful explanation may include the source event ID")
        try expect(output.contains("calendar-id=acme-1"), "Successful explanation may include the source calendar ID")
        try expect(output.contains("caused-by=acme-source-1"), "Create explanation should cite its causal event ID")
        try expect(output.contains("Effective window:"), "Explanation should include the effective window boundaries")
        try expect(output.contains("configuredForwardDays=1"), "Explanation should include the configured horizon")
        try expect(output.contains("routing=work-to-hub-source"), "Explanation should include routing treatment")
        try expect(
            output.contains("expectation=no-matching-expectation"), "Explanation should include expectation state")
        try expect(
            output.contains("disposition=preserved-unmanaged-or-non-local"),
            "Explanation should include existing-state disposition")
        guard let deleteIndex = output.range(of: "- delete")?.lowerBound,
            let createIndex = output.range(of: "- create")?.lowerBound
        else { throw TestFailure("Expected explained delete and create rows") }
        try expect(deleteIndex < createIndex, "Explanation action rows should follow execution order")
        try expect(
            output.contains("eligibility=included (no current-user attendee; availability: busy)"),
            "Explanation output should include eligibility classification")
        try expect(!output.contains("Dry-run mode"), "Explanation output should not include dry-run plan mode")
        try expect((await store.createdEvents()).isEmpty, "Explanation should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Explanation should not delete events")
    }

    private static func testOrdinaryMigrationPendingFailsBeforeCalendarAccess() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)
        } catch let error as ReconcileCommandError {
            try expect(error == .migrationPending, "Ordinary reconciliation should report migration pending")
            try expect(
                await store.listCalendarsCallCount() == 0, "Migration pending should block before Calendar access")
            return
        }

        throw TestFailure("Expected migration-pending ordinary reconciliation failure")
    }

    private static func testCleanupDryRunFormatsReviewWithoutMutation() async throws {
        let fixture = reconciliationFixture()
        let cleanupEvent = CalendarEvent(
            id: "legacy-1", calendar: fixture.workEvent.calendar, title: "[OLD] Client Planning",
            start: fixture.workEvent.start, end: fixture.workEvent.end, isAllDay: false, availability: .busy,
            status: .confirmed)
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [cleanupEvent]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: true)

        try expect(output.contains("Cleanup dry-run"), "Cleanup dry-run should identify its mode")
        try expect(output.contains("Client Planning"), "Cleanup review should include the selected event title text")
        try expect(!output.contains("[OLD]"), "Cleanup review should omit configured marker values")
        try expect(output.contains("Work role ACME"), "Cleanup review should include the configured role")
        try expect(!output.contains("legacy-1"), "Cleanup output should omit EventKit event IDs")
        try expect(!output.contains("acme-1"), "Cleanup output should omit EventKit calendar IDs")
        try expect((await store.deletedEvents()).isEmpty, "Cleanup dry-run should not delete events")
    }

    private static func testCleanupApplyEmitsFreshReviewAndProgressiveConfirmation() async throws {
        let fixture = reconciliationFixture()
        let cleanupEvent = CalendarEvent(
            id: "legacy-1", calendar: fixture.workEvent.calendar, title: "[OLD] Client Planning",
            start: fixture.workEvent.start, end: fixture.workEvent.end, isAllDay: false, availability: .busy,
            status: .confirmed)
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.workCalendar.id: [cleanupEvent]])
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(
            config: configURL.path, apply: true, explain: false, cleanupLegacy: true,
            onOutput: { line in await progressiveOutput.record(line) })

        let lines = await progressiveOutput.values()
        try expect(
            lines.first?.contains("Fresh cleanup plan") == true,
            "Cleanup apply should emit its fresh plan before mutation")
        try expect(
            lines.last == "Confirmed delete for Work role ACME.", "Cleanup should confirm deletion only after success")
        try expect(
            output.contains("verified no matching legacy-marker events"),
            "Cleanup apply should report verified local success")
        try expect(
            await store.deletedEvents().map(\.id) == [CalendarEventReference(providerIdentifier: "legacy-1")],
            "Cleanup apply should delete the planned event")
    }

    private static func reconciliationFixture() -> CommandHandlerFixture {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let workCalendar = RelayCalendar(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let workReference = CalendarIdentity(
            id: workCalendar.id, title: workCalendar.title, sourceTitle: workCalendar.sourceTitle)
        let workEvent = CalendarEvent(
            id: "acme-source-1", calendar: workReference, title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000), end: Date(timeIntervalSince1970: 12_000), isAllDay: false,
            availability: .busy, status: .confirmed)

        return CommandHandlerFixture(
            now: now, hubCalendar: hubCalendar, workCalendar: workCalendar, workEvent: workEvent)
    }

    private static func writeTemporaryConfigFile(legacyMarkers: [String] = []) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        try canonicalSettingsYAML(legacyMarkers: legacyMarkers).write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func canonicalSettingsYAML(legacyMarkers: [String]) -> String {
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

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private actor CommandOutputRecorder {
    private var output: [String] = []

    func record(_ line: String) { output.append(line) }

    func values() -> [String] { output }
}

private struct CommandHandlerFixture {
    let now: Date
    let hubCalendar: RelayCalendar
    let workCalendar: RelayCalendar
    let workEvent: CalendarEvent
}
