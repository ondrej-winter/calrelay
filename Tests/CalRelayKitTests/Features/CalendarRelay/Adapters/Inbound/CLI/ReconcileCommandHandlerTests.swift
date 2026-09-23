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
        try await testExplanationAccessFailureEmitsNoPartialOutputOrIdentifiers()
        try await testMissingConfigurationFailsBeforeCalendarAccess()
        try await testStructurallyInvalidConfigurationFailsBeforeCalendarAccess()
        try await testCleanupRequiresLegacyMarkersBeforeCalendarAccess()
        try await testOrdinaryModesUseOrdinaryAccessWindow()
        try await testCleanupModesUseCleanupAccessWindow()
        try await testOrdinaryMigrationPendingFailsBeforeCalendarAccess()
        try await testCleanupDryRunReportsCompleteRoleSummariesAndPrivateOrderedReview()
        try await testCleanupDryRunNoMatchUsesLoadedSnapshotScope()
        try await testCleanupApplyEmitsFreshReviewAndProgressiveConfirmation()
        try await testCleanupApplyFailureOnlyConfirmsCompletedActionsAndStaysPrivate()
        try await testCleanupApplyNoMatchUsesVerificationSnapshotScope()
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
        let personalHubEvent = CalendarEvent(
            id: "personal-hub",
            calendar: CalendarIdentity(
                id: fixture.hubCalendar.id, title: fixture.hubCalendar.title,
                sourceTitle: fixture.hubCalendar.sourceTitle), title: "Personal appointment",
            start: Date(timeIntervalSince1970: 15_000), end: Date(timeIntervalSince1970: 16_000), isAllDay: false,
            availability: .busy, status: .confirmed)
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [
                fixture.hubCalendar.id: [staleHubEvent, personalHubEvent], fixture.workCalendar.id: [fixture.workEvent]
            ], failMutationNumber: 2)
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(
                config: configURL.path, apply: true, explain: false, cleanupLegacy: false,
                onOutput: { line in await progressiveOutput.record(line) })
        } catch let error as CalendarMutationExecutionError {
            try expect(
                await progressiveOutput.values() == ["Confirmed delete for Hub."],
                "Failed apply should retain confirmations only for completed actions")
            try expect(
                await store.deletedEvents().map(\.id) == [CalendarEventReference(providerIdentifier: "stale-hub")],
                "The successful action before failure should remain applied")
            try expect(
                (await store.createdEvents()).isEmpty, "The failed create and later work create should not succeed")
            try expect(await store.mutationAttemptCount() == 2, "Ordinary apply should stop at the first failure")
            try expect(
                error.description.contains("No rollback was attempted"),
                "Failure should give no-rollback recovery guidance")
            return
        }

        throw TestFailure("Expected ordinary apply mutation failure")
    }

    private static func testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig() async throws {
        let fixture = explanationPrivacyFixture()
        let staleHubEvent = CalendarEvent(
            id: "EVENT_ID_SENTINEL_EXPLANATION_STALE",
            calendar: CalendarIdentity(
                id: fixture.hubCalendar.id, title: fixture.hubCalendar.title,
                sourceTitle: fixture.hubCalendar.sourceTitle),
            title: "[WORK_MARKER_SENTINEL_EXPLANATION] EVENT_TITLE_SENTINEL_EXPLANATION_STALE",
            start: fixture.workEvent.start, end: fixture.workEvent.end, isAllDay: false, availability: .busy,
            status: .confirmed)
        let configURL = try writeTemporaryConfigFile(contents: explanationPrivacySettingsYAML())
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.hubCalendar.id: [staleHubEvent], fixture.workCalendar.id: [fixture.workEvent]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: true, cleanupLegacy: false)

        for approved in [
            "EVENT_ID_SENTINEL_EXPLANATION_SOURCE", "EVENT_ID_SENTINEL_EXPLANATION_STALE",
            "CALENDAR_ID_SENTINEL_EXPLANATION_HUB", "CALENDAR_ID_SENTINEL_EXPLANATION_WORK"
        ] {
            try expect(output.contains(approved), "Successful explanation should include approved identifier: \(approved)")
        }
        try expect(
            output.contains("SOURCE_SELECTOR_SENTINEL_EXPLANATION_WORK / CALENDAR_TITLE_SENTINEL_EXPLANATION_WORK"),
            "Explanation output should include the candidate calendar")
        try expect(
            output.contains("EVENT_TITLE_SENTINEL_EXPLANATION_SOURCE"),
            "Explanation output should include the candidate event title")
        try expect(
            output.contains("caused-by=EVENT_ID_SENTINEL_EXPLANATION_SOURCE"),
            "Create explanation should cite its causal event ID")
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

    private static func testExplanationAccessFailureEmitsNoPartialOutputOrIdentifiers() async throws {
        let fixture = explanationPrivacyFixture()
        let protectedHubEvent = CalendarEvent(
            id: "EVENT_ID_SENTINEL_EXPLANATION_PARTIAL",
            calendar: CalendarIdentity(
                id: fixture.hubCalendar.id, title: fixture.hubCalendar.title,
                sourceTitle: fixture.hubCalendar.sourceTitle),
            title: "EVENT_TITLE_SENTINEL_EXPLANATION_PARTIAL", start: fixture.workEvent.start,
            end: fixture.workEvent.end, isAllDay: false, availability: .busy, status: .confirmed)
        let configURL = try writeTemporaryConfigFile(contents: explanationPrivacySettingsYAML())
        let store = ExplanationPrivacyFailureStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar], hubEvent: protectedHubEvent,
            failedCalendarID: fixture.workCalendar.id)
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(
                config: configURL.path, apply: false, explain: true, cleanupLegacy: false,
                onOutput: { line in await progressiveOutput.record(line) })
        } catch let error as ReconcileCalendarsError {
            try expect((await progressiveOutput.values()).isEmpty, "Failed explanation should emit no partial output")
            try expect(
                error.description.contains("SOURCE_SELECTOR_SENTINEL_EXPLANATION_WORK")
                    && error.description.contains("CALENDAR_TITLE_SENTINEL_EXPLANATION_WORK"),
                "Explanation access failure may identify the configured selector that could not be read")
            for forbidden in [
                "EVENT_ID_SENTINEL_EXPLANATION_PARTIAL", "EVENT_TITLE_SENTINEL_EXPLANATION_PARTIAL",
                "CALENDAR_ID_SENTINEL_EXPLANATION_HUB", "CALENDAR_ID_SENTINEL_EXPLANATION_WORK",
                "WORK_MARKER_SENTINEL_EXPLANATION", "PERSONAL_MARKER_SENTINEL_EXPLANATION"
            ] {
                try expect(!error.description.contains(forbidden), "Explanation failure should omit \(forbidden)")
            }
            try expect(
                await store.eventRequestCalendarIDs() == [fixture.hubCalendar.id, fixture.workCalendar.id],
                "Explanation failure fixture must load the protected hub event before the work read fails")
            try expect(await store.mutationAttemptCount() == 0, "Failed explanation must remain non-mutating")
            return
        }

        throw TestFailure("Expected explanation access failure")
    }

    private static func testMissingConfigurationFailsBeforeCalendarAccess() async throws {
        let fixture = reconciliationFixture()
        let missingPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(config: missingPath, apply: false, explain: false, cleanupLegacy: false)
        } catch let error as MissingConfigurationFileError {
            try expect(
                error.selectedFile.displayPath == missingPath, "Missing explicit path should retain its display value")
            try expect(
                await store.listCalendarsCallCount() == 0, "Missing configuration should fail before Calendar access")
            return
        }

        throw TestFailure("Expected missing configuration failure")
    }

    private static func testStructurallyInvalidConfigurationFailsBeforeCalendarAccess() async throws {
        let fixture = reconciliationFixture()
        let invalidYAML = canonicalSettingsYAML(legacyMarkers: []).replacingOccurrences(
            of: "personalPrefix: \"[ME]\"", with: "personalPrefix: \"invalid\"")
        let configURL = try writeTemporaryConfigFile(contents: invalidYAML)
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)
        } catch is YAMLCalendarRelaySettingsError {
            try expect(
                await store.listCalendarsCallCount() == 0, "Invalid configuration should fail before Calendar access")
            return
        }

        throw TestFailure("Expected structurally invalid configuration failure")
    }

    private static func testCleanupRequiresLegacyMarkersBeforeCalendarAccess() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: true)
        } catch let error as CalendarCleanupError {
            try expect(error == .legacyMarkersRequired, "Cleanup should require at least one legacy marker")
            try expect(
                await store.listCalendarsCallCount() == 0, "Missing legacy markers should fail before Calendar access")
            return
        }

        throw TestFailure("Expected cleanup to require legacy markers")
    }

    private static func testOrdinaryModesUseOrdinaryAccessWindow() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile()
        let calendar = utcCalendar()
        let expected = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: calendar, syncWindowDays: 1)

        let dryRunStore = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        _ = try await ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: dryRunStore, now: { fixture.now },
            calendar: calendar
        ).run(config: configURL.path, apply: false, explain: false, cleanupLegacy: false)
        try expect(
            await dryRunStore.eventRequestWindows() == [expected, expected],
            "Ordinary dry-run should use the ordinary access window")

        let applyStore = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        _ = try await ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: applyStore, now: { fixture.now },
            calendar: calendar
        ).run(config: configURL.path, apply: true, explain: false, cleanupLegacy: false)
        try expect(
            await applyStore.eventRequestWindows() == [expected, expected],
            "Ordinary apply should use one ordinary preflight snapshot without verification")

        let explainStore = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        _ = try await ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: explainStore, now: { fixture.now },
            calendar: calendar
        ).run(config: configURL.path, apply: false, explain: true, cleanupLegacy: false)
        try expect(
            await explainStore.eventRequestWindows() == [expected, expected],
            "Ordinary explanation should use the ordinary access window")
    }

    private static func testCleanupModesUseCleanupAccessWindow() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let calendar = utcCalendar()
        let expected = LegacyCleanupWindow.calculate(referenceDate: fixture.now, calendar: calendar)

        let dryRunStore = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        _ = try await ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: dryRunStore, now: { fixture.now },
            calendar: calendar
        ).run(config: configURL.path, apply: false, explain: false, cleanupLegacy: true)
        try expect(
            await dryRunStore.eventRequestWindows() == [expected, expected],
            "Cleanup dry-run should use the complete cleanup window")

        let applyStore = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        _ = try await ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: applyStore, now: { fixture.now },
            calendar: calendar
        ).run(config: configURL.path, apply: true, explain: false, cleanupLegacy: true)
        try expect(
            await applyStore.eventRequestWindows() == [expected, expected, expected, expected],
            "Cleanup apply should repeat the complete cleanup window for verification")
    }

    private static func testOrdinaryMigrationPendingFailsBeforeCalendarAccess() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let originalYAML = try String(contentsOf: configURL, encoding: .utf8)
        let modes = [
            (name: "dry run", apply: false, explain: false), (name: "apply", apply: true, explain: false),
            (name: "explanation", apply: false, explain: true)
        ]

        for mode in modes {
            let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
            let handler = ReconcileCommandHandler(
                authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

            do {
                _ = try await handler.run(
                    config: configURL.path, apply: mode.apply, explain: mode.explain, cleanupLegacy: false)
                throw TestFailure("Expected migration-pending ordinary " + mode.name + " failure")
            } catch let error as ReconcileCommandError {
                try expect(error == .migrationPending, "Ordinary " + mode.name + " should report migration pending")
                try expect(
                    error.description.contains("explicit legacy cleanup"),
                    "Ordinary " + mode.name + " should direct the operator to explicit cleanup")
                try expect(!error.description.contains("[OLD]"), "Migration failure should not disclose marker values")
            }

            try expect(
                await store.listCalendarsCallCount() == 0,
                "Migration-pending ordinary " + mode.name + " should fail before Calendar access")
            try expect(
                await store.mutationAttemptCount() == 0,
                "Migration-pending ordinary " + mode.name + " must not attempt mutation")
            try expect(
                try String(contentsOf: configURL, encoding: .utf8) == originalYAML,
                "Migration-pending ordinary " + mode.name + " must not rewrite the selected YAML")
        }
    }

    private static func testCleanupDryRunReportsCompleteRoleSummariesAndPrivateOrderedReview() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = RelayCalendar(
            id: "private-hub-id", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let acmeCalendar = RelayCalendar(
            id: "private-acme-id", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let betaCalendar = RelayCalendar(
            id: "private-beta-id", title: "Beta Work", sourceTitle: "Microsoft", isWritable: true)
        let hub = CalendarIdentity(id: hubCalendar.id, title: hubCalendar.title, sourceTitle: hubCalendar.sourceTitle)
        let acme = CalendarIdentity(
            id: acmeCalendar.id, title: acmeCalendar.title, sourceTitle: acmeCalendar.sourceTitle)
        let hubEvent = CalendarEvent(
            id: "private-hub-event", calendar: hub, title: "[SECRET_OLD] Hub Review",
            start: Date(timeIntervalSince1970: 10_100), end: Date(timeIntervalSince1970: 10_200), isAllDay: false,
            availability: .busy, status: .confirmed)
        let acmeFirst = CalendarEvent(
            id: "private-acme-first", calendar: acme, title: "[SECRET_OLD] ACME First",
            start: Date(timeIntervalSince1970: 10_300), end: Date(timeIntervalSince1970: 10_400), isAllDay: false,
            availability: .busy, status: .confirmed)
        let acmeAllDay = CalendarEvent(
            id: "private-acme-all-day", calendar: acme, title: "[SECRET_OLD] ACME All Day",
            start: Date(timeIntervalSince1970: 86_400), end: Date(timeIntervalSince1970: 172_800), isAllDay: true,
            availability: .busy, status: .confirmed)
        let configURL = try writeTemporaryConfigFile(
            contents: multiRoleSettingsYAML() + "\nlegacyMarkers:\n  - \"[SECRET_OLD]\"\n")
        let store = CommandHandlerCalendarStore(
            calendars: [hubCalendar, acmeCalendar, betaCalendar],
            eventsByCalendarID: [hubCalendar.id: [hubEvent], acmeCalendar.id: [acmeAllDay, acmeFirst]])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: true)

        try expect(output.contains("Cleanup dry-run"), "Cleanup dry-run should identify its mode")
        try expect(output.contains("Selected deletions: 3"), "Cleanup dry-run should report the total selected count")
        try expect(output.contains("Configured roles covered: 3"), "Cleanup should report every configured role")
        try expectOutputOrder(
            [
                "- Hub: 1 selected deletion", "- Work role ACME: 2 selected deletions",
                "- Work role Beta: 0 selected deletions"
            ], in: output, message: "Role summaries should be hub-first and declaration ordered, including zero counts")
        try expectOutputOrder(
            [
                "- delete from Hub: Hub Review", "- delete from Work role ACME: ACME First",
                "- delete from Work role ACME: ACME All Day"
            ], in: output, message: "Cleanup review rows should remain in execution order")
        try expect(
            output.contains("local point-in-time scope; end exclusive"),
            "Cleanup range should state its bounded local point-in-time interval semantics")
        try expect(output.contains("all-day dates; end exclusive"), "All-day review should state date-range semantics")
        for forbidden in [
            "[SECRET_OLD]", "private-hub-id", "private-acme-id", "private-beta-id", "private-hub-event",
            "private-acme-first", "private-acme-all-day", "iCloud", "Google", "Microsoft", "Personal Work", "ACME Work",
            "Beta Work"
        ] { try expect(!output.contains(forbidden), "Cleanup output should omit prohibited detail: \(forbidden)") }
        try expectTruthfulCleanupScope(output)
        try expect((await store.deletedEvents()).isEmpty, "Cleanup dry-run should not delete events")
        try expect((await store.createdEvents()).isEmpty, "Cleanup dry-run should never create ordinary projections")
    }

    private static func testCleanupDryRunNoMatchUsesLoadedSnapshotScope() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(config: configURL.path, apply: false, explain: false, cleanupLegacy: true)

        try expect(
            output.contains("no matching legacy-marker events in the loaded local snapshot"),
            "Dry-run no-match should be scoped to the loaded local snapshot")
        try expect(
            !output.contains("post-mutation verification snapshot"), "Dry-run should not claim apply verification")
        try expect(output.contains("- Hub: 0 selected deletions"), "Dry-run should include a zero-count hub summary")
        try expect(
            output.contains("- Work role ACME: 0 selected deletions"), "Dry-run should include zero-count work roles")
        try expect((await store.deletedEvents()).isEmpty, "No-match dry-run should not mutate")
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
            lines.first?.contains("A prior cleanup dry-run is recommended but not required") == true,
            "Direct cleanup apply should recommend dry-run without requiring it")
        try expect(
            lines.first?.contains("--apply authorizes this non-interactive cleanup") == true,
            "Fresh cleanup plan should state that apply is sufficient non-interactive authorization")
        try expect(
            output.contains("post-mutation verification snapshot contained no matching legacy-marker events"),
            "Cleanup apply should scope no-match success to its verification snapshot")
        try expectTruthfulCleanupScope(output)
        try expect(
            output.contains("Configuration was not changed") && output.contains("Remove legacyMarkers manually")
                && output.contains("eventual-convergence migration is complete for your topology"),
            "Cleanup success should provide manual eventual-convergence tombstone guidance")
        try expect(
            !output.contains("Client Planning") && !output.contains("Work role ACME"),
            "Cleanup completion should retain no transient review details")
        try expect(
            await store.deletedEvents().map(\.id) == [CalendarEventReference(providerIdentifier: "legacy-1")],
            "Cleanup apply should delete the planned event")
        try expect((await store.createdEvents()).isEmpty, "Cleanup apply should never create ordinary projections")
    }

    private static func testCleanupApplyFailureOnlyConfirmsCompletedActionsAndStaysPrivate() async throws {
        let fixture = reconciliationFixture()
        let hub = CalendarIdentity(
            id: fixture.hubCalendar.id, title: fixture.hubCalendar.title, sourceTitle: fixture.hubCalendar.sourceTitle)
        let first = CalendarEvent(
            id: "private-hub-event", calendar: hub, title: "[SECRET_OLD] Hub Review",
            start: Date(timeIntervalSince1970: 10_100), end: Date(timeIntervalSince1970: 10_200), isAllDay: false,
            availability: .busy, status: .confirmed)
        let second = CalendarEvent(
            id: "private-work-first", calendar: fixture.workEvent.calendar, title: "[SECRET_OLD] Work First",
            start: Date(timeIntervalSince1970: 10_300), end: Date(timeIntervalSince1970: 10_400), isAllDay: false,
            availability: .busy, status: .confirmed)
        let later = CalendarEvent(
            id: "private-work-later", calendar: fixture.workEvent.calendar, title: "[SECRET_OLD] Work Later",
            start: Date(timeIntervalSince1970: 10_500), end: Date(timeIntervalSince1970: 10_600), isAllDay: false,
            availability: .busy, status: .confirmed)
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[SECRET_OLD]"])
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hubCalendar, fixture.workCalendar],
            eventsByCalendarID: [fixture.hubCalendar.id: [first], fixture.workCalendar.id: [later, second]],
            failMutationNumber: 2)
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        do {
            _ = try await handler.run(
                config: configURL.path, apply: true, explain: false, cleanupLegacy: true,
                onOutput: { line in await progressiveOutput.record(line) })
        } catch let error as CalendarCleanupError {
            guard case .mutationFailed(let partial) = error else {
                throw TestFailure("Expected cleanup mutation failure, got \(error)")
            }
            let lines = await progressiveOutput.values()
            try expect(lines.count == 2, "Failed cleanup should retain its fresh plan and one successful confirmation")
            try expect(lines[0].contains("Fresh cleanup plan before mutation"), "Cleanup should review the fresh plan")
            try expect(lines[1] == "Confirmed delete for Hub.", "Only the successful deletion should be confirmed")
            try expect(partial.confirmedActionCount == 1, "Partial cleanup result should count only confirmed deletion")
            try expect(
                partial.failedRole == .work(name: "ACME", declarationIndex: 0),
                "Failure should identify the configured role")
            try expect(partial.failureCategory == .deleteFailed, "Cleanup failure should identify delete category")
            try expect(await store.mutationAttemptCount() == 2, "Cleanup should stop before the later deletion")
            try expect(
                await store.deletedEvents().map(\.id) == [
                    CalendarEventReference(providerIdentifier: "private-hub-event")
                ], "Confirmed deletion should remain applied without rollback")
            let description = error.description
            try expect(description.contains("partially applied"), "Cleanup failure should report partial application")
            try expect(
                description.contains("No rollback was attempted"), "Cleanup failure should give recovery guidance")
            for forbidden in [
                "[SECRET_OLD]", "private-hub-event", "private-work-first", "private-work-later", "Hub Review",
                "Work First", "Work Later", "hub-1", "acme-1"
            ] {
                try expect(
                    !description.contains(forbidden), "Cleanup failure should omit prohibited detail: \(forbidden)")
            }
            return
        }

        throw TestFailure("Expected cleanup apply mutation failure")
    }

    private static func testCleanupApplyNoMatchUsesVerificationSnapshotScope() async throws {
        let fixture = reconciliationFixture()
        let configURL = try writeTemporaryConfigFile(legacyMarkers: ["[OLD]"])
        let store = CommandHandlerCalendarStore(calendars: [fixture.hubCalendar, fixture.workCalendar])
        let progressiveOutput = CommandOutputRecorder()
        let handler = ReconcileCommandHandler(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now })

        let output = try await handler.run(
            config: configURL.path, apply: true, explain: false, cleanupLegacy: true,
            onOutput: { line in await progressiveOutput.record(line) })

        let lines = await progressiveOutput.values()
        try expect(lines.count == 1, "Empty direct apply should emit only its fresh review before verification")
        try expect(
            lines[0].contains("Fresh cleanup plan before mutation"), "Empty apply should still show a fresh plan")
        try expect(lines[0].contains("- Hub: 0 selected deletions"), "Fresh apply should summarize the zero-count hub")
        try expect(
            lines[0].contains("- Work role ACME: 0 selected deletions"),
            "Fresh apply should summarize zero-count work roles")
        try expect(
            output.contains("post-mutation verification snapshot contained no matching legacy-marker events"),
            "No-match apply should report its verified snapshot rather than the initial loaded snapshot")
        try expect(
            !output.contains("loaded local snapshot"), "Apply completion should not reuse dry-run no-match wording")
        try expect(
            await store.eventRequestCalendarIDs() == [
                fixture.hubCalendar.id, fixture.workCalendar.id, fixture.hubCalendar.id, fixture.workCalendar.id
            ], "Even no-match cleanup apply should perform a complete verification snapshot read")
        try expect((await store.deletedEvents()).isEmpty, "No-match cleanup apply should perform no deletion")
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

    private static func explanationPrivacyFixture() -> CommandHandlerFixture {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = RelayCalendar(
            id: "CALENDAR_ID_SENTINEL_EXPLANATION_HUB", title: "CALENDAR_TITLE_SENTINEL_EXPLANATION_HUB",
            sourceTitle: "SOURCE_SELECTOR_SENTINEL_EXPLANATION_HUB", isWritable: true)
        let workCalendar = RelayCalendar(
            id: "CALENDAR_ID_SENTINEL_EXPLANATION_WORK", title: "CALENDAR_TITLE_SENTINEL_EXPLANATION_WORK",
            sourceTitle: "SOURCE_SELECTOR_SENTINEL_EXPLANATION_WORK", isWritable: true)
        let workEvent = CalendarEvent(
            id: "EVENT_ID_SENTINEL_EXPLANATION_SOURCE",
            calendar: CalendarIdentity(
                id: workCalendar.id, title: workCalendar.title, sourceTitle: workCalendar.sourceTitle),
            title: "EVENT_TITLE_SENTINEL_EXPLANATION_SOURCE", start: Date(timeIntervalSince1970: 11_000),
            end: Date(timeIntervalSince1970: 12_000), isAllDay: false, availability: .busy, status: .confirmed)
        return CommandHandlerFixture(
            now: now, hubCalendar: hubCalendar, workCalendar: workCalendar, workEvent: workEvent)
    }

    private static func explanationPrivacySettingsYAML() -> String {
        """
        hubCalendar:
          sourceTitle: "SOURCE_SELECTOR_SENTINEL_EXPLANATION_HUB"
          calendarTitle: "CALENDAR_TITLE_SENTINEL_EXPLANATION_HUB"
        personalPrefix: "[PERSONAL_MARKER_SENTINEL_EXPLANATION]"
        syncWindowDays: 1
        workCalendars:
          - name: "Approved explanation role"
            prefix: "[WORK_MARKER_SENTINEL_EXPLANATION]"
            calendar:
              sourceTitle: "SOURCE_SELECTOR_SENTINEL_EXPLANATION_WORK"
              calendarTitle: "CALENDAR_TITLE_SENTINEL_EXPLANATION_WORK"
        """
    }

    private static func expectTruthfulCleanupScope(_ output: String) throws {
        try expect(
            output.localizedCaseInsensitiveContains("local")
                && output.localizedCaseInsensitiveContains("point-in-time"),
            "Cleanup output should state its local point-in-time scope")
        for forbiddenClaim in [
            "all calendars", "entire history", "globally retired", "retired everywhere", "recurring series removed",
            "all recurring series retired", "removed calendars are covered", "covers removed calendars",
            "cannot be recreated", "will not be recreated"
        ] {
            try expect(
                !output.localizedCaseInsensitiveContains(forbiddenClaim),
                "Cleanup output must not claim global, historical, recurring-series, or future-retirement scope")
        }
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

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
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

private struct ExplanationPrivacyFailure: Error {}

private actor ExplanationPrivacyFailureStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let hubEvent: CalendarEvent
    private let failedCalendarID: PhysicalCalendarReference
    private var eventRequests: [PhysicalCalendarReference] = []
    private var mutationAttempts = 0

    init(calendars: [RelayCalendar], hubEvent: CalendarEvent, failedCalendarID: PhysicalCalendarReference) {
        self.calendars = calendars
        self.hubEvent = hubEvent
        self.failedCalendarID = failedCalendarID
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventRequests.append(calendar.id)
        if calendar.id == failedCalendarID { throw ExplanationPrivacyFailure() }
        return calendar.id == hubEvent.calendar.id ? [hubEvent] : []
    }

    func createEvent(_ event: CalendarEventProjection) async throws { mutationAttempts += 1 }
    func deleteEvent(_ event: CalendarEventIdentity) async throws { mutationAttempts += 1 }
    func eventRequestCalendarIDs() -> [PhysicalCalendarReference] { eventRequests }
    func mutationAttemptCount() -> Int { mutationAttempts }
}
