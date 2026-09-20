import CalRelayKit
import Foundation

enum ReconcileCommandHandlerTests {
    static func runAll() async throws {
        try await testReconcileHandlerFormatsDryRunPlanFromInjectedStoreAndConfig()
        try await testDryRunFormatsActionsInExecutionOrder()
        try await testEmptyDryRunReportsSuccessfulNoChange()
        try await testReconcileHandlerFormatsApplyPlanFromInjectedStoreAndConfig()
        try await testEmptyApplyReportsSuccessfulNoChange()
        try await testApplyFailureOnlyConfirmsCompletedActions()
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
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let acmeCalendar = RelayCalendar(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let betaCalendar = RelayCalendar(id: "beta-1", title: "Beta Work", sourceTitle: "Microsoft", isWritable: true)
        let hub = CalendarIdentity(id: hubCalendar.id, title: hubCalendar.title, sourceTitle: hubCalendar.sourceTitle)
        let acme = CalendarIdentity(
            id: acmeCalendar.id, title: acmeCalendar.title, sourceTitle: acmeCalendar.sourceTitle)
        let beta = CalendarIdentity(
            id: betaCalendar.id, title: betaCalendar.title, sourceTitle: betaCalendar.sourceTitle)
        let staleHubEvent = CalendarEvent(
            id: "stale-hub", calendar: hub, title: "[ACME] 01 stale hub", start: Date(timeIntervalSince1970: 10_500),
            end: Date(timeIntervalSince1970: 10_600), isAllDay: false, availability: .busy, status: .confirmed)
        let personalHubEvent = CalendarEvent(
            id: "personal-hub", calendar: hub, title: "Personal appointment",
            start: Date(timeIntervalSince1970: 15_000), end: Date(timeIntervalSince1970: 16_000), isAllDay: false,
            availability: .busy, status: .confirmed)
        let staleAcmeEvent = CalendarEvent(
            id: "stale-acme", calendar: acme, title: "[ME] 02 stale ACME", start: Date(timeIntervalSince1970: 10_700),
            end: Date(timeIntervalSince1970: 10_800), isAllDay: false, availability: .busy, status: .confirmed)
        let acmeSourceEvent = CalendarEvent(
            id: "acme-source", calendar: acme, title: "ACME source", start: Date(timeIntervalSince1970: 11_000),
            end: Date(timeIntervalSince1970: 12_000), isAllDay: false, availability: .busy, status: .confirmed)
        let staleBetaEvent = CalendarEvent(
            id: "stale-beta", calendar: beta, title: "[ME] 03 stale Beta", start: Date(timeIntervalSince1970: 10_900),
            end: Date(timeIntervalSince1970: 11_000), isAllDay: false, availability: .busy, status: .confirmed)
        let betaSourceEvent = CalendarEvent(
            id: "beta-source", calendar: beta, title: "Beta source", start: Date(timeIntervalSince1970: 13_000),
            end: Date(timeIntervalSince1970: 14_000), isAllDay: false, availability: .busy, status: .confirmed)
        let configURL = try writeTemporaryConfigFile(contents: multiRoleSettingsYAML())
        let store = CommandHandlerCalendarStore(
            calendars: [hubCalendar, acmeCalendar, betaCalendar],
            eventsByCalendarID: [
                hubCalendar.id: [staleHubEvent, personalHubEvent], acmeCalendar.id: [staleAcmeEvent, acmeSourceEvent],
                betaCalendar.id: [staleBetaEvent, betaSourceEvent]
            ])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)

        try expectOutputOrder(
            [
                "- delete iCloud / Personal Work: [ACME] 01 stale hub",
                "- delete Google / ACME Work: [ME] 02 stale ACME", "- delete Microsoft / Beta Work: [ME] 03 stale Beta",
                "- create iCloud / Personal Work: [ACME] ACME source",
                "- create iCloud / Personal Work: [BETA] Beta source",
                "- create Google / ACME Work: [BETA] Beta source",
                "- create Google / ACME Work: [ME] Personal appointment",
                "- create Microsoft / Beta Work: [ACME] ACME source",
                "- create Microsoft / Beta Work: [ME] Personal appointment"
            ], in: output, message: "Dry-run rows should follow the complete ordinary execution order")
    }

    private static func testEmptyDryRunReportsSuccessfulNoChange() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)

        try expect(
            output.contains(
                "Dry-run mode completed successfully. No ordinary reconciliation changes are needed; no calendar mutations were performed."
            ), "Empty dry-run should report successful no-change")
        try expect(output.contains("No changes planned."), "Empty dry-run should retain the empty-plan summary")
        try expect(
            !output.contains("Planned calendar mutations were performed."),
            "Empty dry-run should not claim planned mutation")
        try expect((await store.createdEvents()).isEmpty, "Empty dry-run should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Empty dry-run should not delete events")
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
            output.contains("Apply mode completed successfully. All planned calendar mutations were confirmed."),
            "Apply output should report local completion after every confirmation")
        try expect(output.contains("Creates (1)"), "Apply output should include planned create count")
        try expect(!output.contains("verified"), "Ordinary apply should not claim post-apply verification")
        try expect(!output.contains("converged"), "Ordinary apply should not claim provider convergence")
        try expect(!output.contains("immediate"), "Ordinary apply should not promise immediate provider visibility")
        try expect(await store.createdEvents().count == 1, "Apply handler should create planned events")
        try expect((await store.deletedEvents()).isEmpty, "Apply handler should not delete events in this fixture")
        try expect(
            await store.eventRequestCalendarIDs() == [fixture.hubCalendar.id, fixture.workCalendar.id],
            "Ordinary apply should use only the initial configured-calendar snapshot")
        try expect(
            await progressiveOutput.values() == ["Confirmed create for Hub."],
            "Apply should emit confirmation only after the successful mutation")
    }

    private static func testEmptyApplyReportsSuccessfulNoChange() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(
            config: configURL.path, apply: true, explain: false, cleanupLegacy: false,
            onOutput: { line in await progressiveOutput.record(line) })

        try expect(
            output.contains(
                "Apply mode completed successfully. No ordinary reconciliation changes were needed; no calendar mutations were performed."
            ), "Empty apply should report successful no-change without claiming mutation")
        try expect(output.contains("No changes planned."), "Empty apply should retain the empty-plan summary")
        try expect(
            !output.contains("Planned calendar mutations were performed."), "Empty apply should not claim mutation")
        try expect(!output.contains("verified"), "Empty ordinary apply should not claim post-apply verification")
        try expect((await progressiveOutput.values()).isEmpty, "Empty apply should emit no mutation confirmations")
        try expect(
            await store.eventRequestCalendarIDs() == [fixture.hubCalendar.id, fixture.workCalendar.id],
            "Empty ordinary apply should not perform a verification snapshot read")
    }

    private static func testApplyFailureOnlyConfirmsCompletedActions() async throws {
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
            eventsByCalendarID: [fixture.hubCalendar.id: [staleHubEvent], fixture.workCalendar.id: [fixture.workEvent]],
            failMutationNumber: 2)
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(
                config: configURL.path, apply: true, explain: false, cleanupLegacy: false,
                onOutput: { line in await progressiveOutput.record(line) })
        } catch is CalendarMutationExecutionError {
            try expect(
                await progressiveOutput.values() == ["Confirmed delete for Hub."],
                "Failed apply should retain confirmations only for completed actions")
            try expect(
                await store.deletedEvents().map(\.id) == [CalendarEventReference(providerIdentifier: "stale-hub")],
                "The successful action before failure should remain applied")
            try expect((await store.createdEvents()).isEmpty, "The failed create should not be recorded as successful")
            return
        }

        throw TestFailure("Expected ordinary apply mutation failure")
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
        try writeTemporaryConfigFile(contents: canonicalSettingsYAML(legacyMarkers: legacyMarkers))
    }

    private static func writeTemporaryConfigFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        try contents.write(to: file, atomically: true, encoding: .utf8)
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

    private static func multiRoleSettingsYAML() -> String {
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
          - name: "Beta"
            prefix: "[BETA]"
            calendar:
              sourceTitle: "Microsoft"
              calendarTitle: "Beta Work"
        """
    }

    private static func expectOutputOrder(_ values: [String], in output: String, message: String) throws {
        var searchStart = output.startIndex
        for value in values {
            guard let range = output.range(of: value, range: searchStart..<output.endIndex) else {
                throw TestFailure("\(message): missing \(value)")
            }
            searchStart = range.upperBound
        }
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
