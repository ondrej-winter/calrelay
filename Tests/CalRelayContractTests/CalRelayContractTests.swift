import CalRelayAdapters
import CalRelayCore
import Foundation
import Testing

@Suite("CalRelay contract tests")
struct CalRelayContractTests {
    @Test("Deterministic contract suite")
    func contractSuite() async throws {
        try Self.testAcceptsValidSettings()
        try Self.testRejectsMissingWorkCalendars()
        try Self.testRejectsEmptyHubSelectorFields()
        try Self.testRejectsEmptyWorkCalendarSelectorFields()
        try Self.testRejectsEmptyWorkCalendarNameAndPrefix()
        try Self.testRejectsNonPositiveSyncWindow()
        try Self.testRejectsDuplicateWorkPrefixes()
        try Self.testRejectsPersonalPrefixConflictingWithWorkPrefix()
        try Self.testIncludesTimedBusyEvents()
        try Self.testIncludesTimedTentativeEvents()
        try Self.testIncludesTimedEventsWhenAvailabilityIsNotSupported()
        try Self.testSkipsAllDayEvents()
        try Self.testSkipsDeclinedEvents()
        try Self.testSkipsCancelledEvents()
        try Self.testVisibleEventKeysRemainDistinctForAdjacentMeetings()
        try Self.testProjectsIncludedWorkEventToHub()
        try Self.testDoesNotProjectExcludedWorkEventToHub()
        try Self.testProjectsPrefixedHubEventToOtherWorkCalendars()
        try Self.testProjectsUnprefixedHubEventToAllWorkCalendarsWithPersonalPrefix()
        try Self.testProjectsRemotePrefixedHubEventToLocalWorkCalendars()
        try Self.testPlansCreateForMissingExpectedProjection()
        try Self.testPlansDeleteForStaleManagedProjection()
        try Self.testNeverDeletesUnprefixedEvents()
        try Self.testPreservesUnknownPrefixedEvents()
        try Self.testPlansRenameAsDeleteOldAndCreateNew()
        try Self.testPlansNoChangesWhenExpectedStateAlreadyExists()
        try Self.testParsesCanonicalYAMLSettings()
        try Self.testDefaultsSyncWindowDaysWhenOmitted()
        try Self.testReportsSafeYAMLShapeErrors()
        try Self.testReportsSettingsValidationErrorsFromYAML()
        try await Self.testDryRunPlansChangesWithoutMutatingCalendarStore()
        try await Self.testRejectsMissingCalendarSelectorDuringReconciliation()
        try await Self.testRejectsAmbiguousCalendarSelectorDuringReconciliation()
        try await Self.testApplyRejectsReadOnlyDestinationBeforeMutation()
        try await Self.testApplyCreatesAndDeletesPlannedChanges()
        try await Self.testDoesNotReprojectManagedWorkProjectionsToHub()
        try await Self.testProjectsWorkSourceToOtherWorkCalendarsInSamePlan()
        try await Self.testDoesNotProjectUnknownPrefixedWorkBlockersBackToHub()
        try await Self.testReconciliationPropagatesCancellation()
        try Self.testFormatsEmptyReconciliationPlan()
        try Self.testFormatsPlannedCreatesAndDeletes()
        try Self.testReconciliationPlanOutputAvoidsDebugDumps()
        try Self.testFormatsCalendarList()
    }

    private static func testAcceptsValidSettings() throws {
        try SettingsValidator.validate(validSettings())
    }

    private static func testRejectsMissingWorkCalendars() throws {
        let baseSettings = validSettings()
        let settings = CalendarRelaySettings(
            hubCalendar: baseSettings.hubCalendar,
            personalPrefix: baseSettings.personalPrefix,
            syncWindowDays: baseSettings.syncWindowDays,
            workCalendars: []
        )

        try expectValidationError(.missingWorkCalendars, for: settings)
    }

    private static func testRejectsEmptyHubSelectorFields() throws {
        try expectValidationError(
            .emptyHubCalendarSourceTitle,
            for: validSettings(hubCalendar: CalendarSelector(sourceTitle: "", calendarTitle: "Personal Work"))
        )

        try expectValidationError(
            .emptyHubCalendarTitle,
            for: validSettings(hubCalendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: ""))
        )
    }

    private static func testRejectsEmptyWorkCalendarSelectorFields() throws {
        try expectValidationError(
            .emptyWorkCalendarSourceTitle(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "", calendarTitle: "ACME Work")
                )
            ])
        )

        try expectValidationError(
            .emptyWorkCalendarTitle(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "")
                )
            ])
        )
    }

    private static func testRejectsEmptyWorkCalendarNameAndPrefix() throws {
        try expectValidationError(
            .emptyWorkCalendarName,
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "",
                    prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
                )
            ])
        )

        try expectValidationError(
            .emptyWorkCalendarPrefix(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
                )
            ])
        )
    }

    private static func testRejectsNonPositiveSyncWindow() throws {
        try expectValidationError(.nonPositiveSyncWindowDays, for: validSettings(syncWindowDays: 0))
        try expectValidationError(.nonPositiveSyncWindowDays, for: validSettings(syncWindowDays: -1))
    }

    private static func testRejectsDuplicateWorkPrefixes() throws {
        try expectValidationError(
            .duplicateWorkCalendarPrefix("[WORK]"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
                ),
                WorkCalendarSettings(
                    name: "BETA",
                    prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Exchange", calendarTitle: "BETA Work")
                )
            ])
        )
    }

    private static func testRejectsPersonalPrefixConflictingWithWorkPrefix() throws {
        try expectValidationError(
            .personalPrefixConflictsWithWorkPrefix("[ACME]"),
            for: validSettings(personalPrefix: "[ACME]")
        )
    }

    private static func testIncludesTimedBusyEvents() throws {
        let event = eventSnapshot(availability: .busy, status: .confirmed)

        try expect(EventInclusionPolicy.includes(event), "Timed busy events should be included")
    }

    private static func testIncludesTimedTentativeEvents() throws {
        let event = eventSnapshot(availability: .tentative, status: .tentative)

        try expect(EventInclusionPolicy.includes(event), "Timed tentative events should be included")
    }

    private static func testIncludesTimedEventsWhenAvailabilityIsNotSupported() throws {
        let event = eventSnapshot(availability: .notSupported, status: .confirmed)

        try expect(EventInclusionPolicy.includes(event), "Timed events from calendars without availability support should be included")
    }

    private static func testSkipsAllDayEvents() throws {
        let event = eventSnapshot(isAllDay: true, availability: .busy, status: .confirmed)

        try expect(!EventInclusionPolicy.includes(event), "All-day events should be skipped")
    }

    private static func testSkipsDeclinedEvents() throws {
        let event = eventSnapshot(availability: .busy, status: .declined)

        try expect(!EventInclusionPolicy.includes(event), "Declined events should be skipped")
    }

    private static func testSkipsCancelledEvents() throws {
        let event = eventSnapshot(availability: .busy, status: .cancelled)

        try expect(!EventInclusionPolicy.includes(event), "Cancelled events should be skipped")
    }

    private static func testVisibleEventKeysRemainDistinctForAdjacentMeetings() throws {
        let first = eventSnapshot(
            id: "event-1",
            title: "Planning",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let adjacent = eventSnapshot(
            id: "event-2",
            title: "Planning",
            start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_000)
        )

        try expect(
            VisibleEventKey(event: first) != VisibleEventKey(event: adjacent),
            "Repeated titles and adjacent meetings should remain distinct when start/end differ"
        )
    }

    private static func testProjectsIncludedWorkEventToHub() throws {
        let hubCalendar = CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud")
        let sourceEvent = eventSnapshot(
            id: "acme-1",
            calendar: CalendarReference(id: "acme-1", title: "ACME Work", sourceTitle: "Google"),
            title: "Client Planning",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000),
            isAllDay: false,
            availability: .busy,
            status: .confirmed
        )

        let projections = WorkToHubProjector.project(
            events: [sourceEvent],
            from: workCalendarSettings(),
            to: hubCalendar
        )

        try expect(projections.count == 1, "Expected one hub projection")
        try expect(projections[0].destinationCalendar == hubCalendar, "Projection should target hub calendar")
        try expect(projections[0].title == "[ACME] Client Planning", "Projection should prefix source title")
        try expect(projections[0].start == sourceEvent.start, "Projection should copy start")
        try expect(projections[0].end == sourceEvent.end, "Projection should copy end")
        try expect(projections[0].isAllDay == sourceEvent.isAllDay, "Projection should copy all-day flag")
    }

    private static func testDoesNotProjectExcludedWorkEventToHub() throws {
        let sourceEvent = eventSnapshot(isAllDay: true, availability: .busy, status: .confirmed)

        let projections = WorkToHubProjector.project(
            events: [sourceEvent],
            from: workCalendarSettings(),
            to: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud")
        )

        try expect(projections.isEmpty, "Excluded source events should not produce hub projections")
    }

    private static func testProjectsPrefixedHubEventToOtherWorkCalendars() throws {
        let hubEvent = eventSnapshot(
            calendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[ACME] Client Planning"
        )

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: workCalendarTargets(),
            personalPrefix: "[ME]"
        )

        try expect(projections.count == 2, "Expected prefixed hub event to project to non-source work calendars")
        try expect(!projections.contains { $0.destinationCalendar.title == "ACME Work" }, "Prefixed hub event should not route back to matching source calendar")
        try expect(projections.contains { $0.destinationCalendar.title == "BETA Work" && $0.title == "[ACME] Client Planning" }, "Prefixed hub event should route to BETA unchanged")
        try expect(projections.contains { $0.destinationCalendar.title == "CONTOSO Work" && $0.title == "[ACME] Client Planning" }, "Prefixed hub event should route to CONTOSO unchanged")
    }

    private static func testProjectsUnprefixedHubEventToAllWorkCalendarsWithPersonalPrefix() throws {
        let hubEvent = eventSnapshot(
            calendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "Dentist"
        )

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: workCalendarTargets(),
            personalPrefix: "[ME]"
        )

        try expect(projections.count == 3, "Expected unprefixed hub event to project to all work calendars")
        try expect(projections.allSatisfy { $0.title == "[ME] Dentist" }, "Unprefixed hub event should use personal prefix")
    }

    private static func testProjectsRemotePrefixedHubEventToLocalWorkCalendars() throws {
        let hubEvent = eventSnapshot(
            calendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[BETA] Sales Call"
        )

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: [workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work")],
            personalPrefix: "[ME]"
        )

        try expect(projections.count == 1, "Expected remote prefixed hub event to project to local work calendar")
        try expect(projections[0].destinationCalendar.title == "ACME Work", "Remote prefixed hub event should target locally configured work calendar")
        try expect(projections[0].title == "[BETA] Sales Call", "Remote prefixed hub event should preserve remote prefix")
    }

    private static func testPlansCreateForMissingExpectedProjection() throws {
        let expected = projectedEvent(title: "[ACME] Client Planning")

        let plan = ReconciliationPlanner.plan(
            expected: [expected],
            existing: [],
            managedPrefixes: ["[ACME]"]
        )

        try expect(plan.creates == [expected], "Missing expected projection should be planned as create")
        try expect(plan.deletes.isEmpty, "Missing expected projection should not create deletes")
    }

    private static func testPlansDeleteForStaleManagedProjection() throws {
        let stale = eventSnapshot(title: "[ACME] Old Planning")

        let plan = ReconciliationPlanner.plan(
            expected: [],
            existing: [stale],
            managedPrefixes: ["[ACME]"]
        )

        try expect(plan.creates.isEmpty, "Stale managed projection should not create events")
        try expect(plan.deletes == [stale], "Stale managed projection should be planned as delete")
    }

    private static func testNeverDeletesUnprefixedEvents() throws {
        let original = eventSnapshot(title: "Client Planning")

        let plan = ReconciliationPlanner.plan(
            expected: [],
            existing: [original],
            managedPrefixes: ["[ACME]"]
        )

        try expect(plan.deletes.isEmpty, "Unprefixed events should never be deleted")
    }

    private static func testPreservesUnknownPrefixedEvents() throws {
        let remote = eventSnapshot(title: "[BETA] Sales Call")

        let plan = ReconciliationPlanner.plan(
            expected: [],
            existing: [remote],
            managedPrefixes: ["[ACME]"]
        )

        try expect(plan.deletes.isEmpty, "Unknown prefixed events should be preserved")
    }

    private static func testPlansRenameAsDeleteOldAndCreateNew() throws {
        let old = eventSnapshot(title: "[ACME] Old Planning")
        let new = projectedEvent(title: "[ACME] New Planning")

        let plan = ReconciliationPlanner.plan(
            expected: [new],
            existing: [old],
            managedPrefixes: ["[ACME]"]
        )

        try expect(plan.creates == [new], "Renamed projection should create new visible event")
        try expect(plan.deletes == [old], "Renamed projection should delete old managed event")
    }

    private static func testPlansNoChangesWhenExpectedStateAlreadyExists() throws {
        let existing = eventSnapshot(title: "[ACME] Client Planning")
        let expected = projectedEvent(
            destinationCalendar: existing.calendar,
            title: existing.title,
            start: existing.start,
            end: existing.end,
            isAllDay: existing.isAllDay
        )

        let plan = ReconciliationPlanner.plan(
            expected: [expected],
            existing: [existing],
            managedPrefixes: ["[ACME]"]
        )

        try expect(plan.creates.isEmpty, "Existing expected projection should not be created again")
        try expect(plan.deletes.isEmpty, "Existing expected projection should not be deleted")
    }

    private static func testParsesCanonicalYAMLSettings() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(canonicalSettingsYAML(syncWindowDays: 45))

        try expect(settings == validSettings(syncWindowDays: 45), "Canonical YAML should parse into expected settings")
    }

    private static func testDefaultsSyncWindowDaysWhenOmitted() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(canonicalSettingsYAML(syncWindowDays: nil))

        try expect(settings.syncWindowDays == 60, "Omitted syncWindowDays should default to 60")
    }

    private static func testReportsSafeYAMLShapeErrors() throws {
        do {
            _ = try YAMLCalendarRelaySettingsLoader.load("hubCalendar: [not, a, selector]")
        } catch let error as YAMLCalendarRelaySettingsError {
            try expect(error.description.contains("Invalid configuration"), "Shape errors should be clear")
            try expect(!error.description.contains("hubCalendar: [not, a, selector]"), "Shape errors should not echo raw YAML")
            return
        } catch {
            throw ContractTestFailure("Expected YAMLCalendarRelaySettingsError, got \(error)")
        }

        throw ContractTestFailure("Expected invalid YAML shape error")
    }

    private static func testReportsSettingsValidationErrorsFromYAML() throws {
        let yaml = """
        hubCalendar:
          sourceTitle: "iCloud"
          calendarTitle: "Personal Work"
        personalPrefix: "[ME]"
        syncWindowDays: 60
        workCalendars:
          - name: "ACME"
            prefix: "[WORK]"
            calendar:
              sourceTitle: "Google"
              calendarTitle: "ACME Work"
          - name: "BETA"
            prefix: "[WORK]"
            calendar:
              sourceTitle: "Exchange"
              calendarTitle: "BETA Work"
        """

        do {
            _ = try YAMLCalendarRelaySettingsLoader.load(yaml)
        } catch let error as YAMLCalendarRelaySettingsError {
            try expect(error.description.contains("Work calendar prefix must be unique"), "Validation errors should surface actionable messages")
            return
        } catch {
            throw ContractTestFailure("Expected YAMLCalendarRelaySettingsError, got \(error)")
        }

        throw ContractTestFailure("Expected settings validation error")
    }

    private static func testDryRunPlansChangesWithoutMutatingCalendarStore() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.workCalendar.id: [fixtures.workEvent]]
        )
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)
        let createdEvents = await store.createdEvents()
        let deletedEvents = await store.deletedEvents()

        try expect(plan.creates == [fixtures.expectedHubProjection], "Dry-run should plan missing hub projection")
        try expect(plan.deletes.isEmpty, "Dry-run should not plan deletes for this scenario")
        try expect(createdEvents.isEmpty, "Dry-run should not create events")
        try expect(deletedEvents.isEmpty, "Dry-run should not delete events")
    }

    private static func testRejectsMissingCalendarSelectorDuringReconciliation() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(calendars: [fixtures.workCalendar])
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        try await expectReconciliationError(
            .calendarNotFound(fixtures.settings.hubCalendar),
            from: { try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now) }
        )
    }

    private static func testRejectsAmbiguousCalendarSelectorDuringReconciliation() async throws {
        let fixtures = applicationFixtures()
        let duplicateHub = CalendarSnapshot(
            id: "hub-duplicate",
            title: fixtures.hubCalendar.title,
            sourceTitle: fixtures.hubCalendar.sourceTitle,
            isWritable: true
        )
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, duplicateHub, fixtures.workCalendar])
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        try await expectReconciliationError(
            .calendarAmbiguous(fixtures.settings.hubCalendar),
            from: { try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now) }
        )
    }

    private static func testApplyRejectsReadOnlyDestinationBeforeMutation() async throws {
        let fixtures = applicationFixtures(hubIsWritable: false)
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.workCalendar.id: [fixtures.workEvent]]
        )
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        try await expectReconciliationError(
            .calendarReadOnly(fixtures.hubReference),
            from: { try await useCase.apply(settings: fixtures.settings, now: fixtures.now) }
        )

        try expect((await store.createdEvents()).isEmpty, "Read-only apply should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Read-only apply should not delete events")
    }

    private static func testApplyCreatesAndDeletesPlannedChanges() async throws {
        let fixtures = applicationFixtures()
        let staleHubProjection = eventSnapshot(
            id: "hub-stale-1",
            calendar: fixtures.hubReference,
            title: "[ACME] Old Planning"
        )
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [staleHubProjection],
                fixtures.workCalendar.id: [fixtures.workEvent]
            ]
        )
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        let plan = try await useCase.apply(settings: fixtures.settings, now: fixtures.now)

        try expect(plan.creates == [fixtures.expectedHubProjection], "Apply should return planned create")
        try expect(plan.deletes == [staleHubProjection], "Apply should return planned delete")
        try expect(await store.createdEvents() == [fixtures.expectedHubProjection], "Apply should create planned projections")
        try expect(await store.deletedEvents() == [staleHubProjection], "Apply should delete stale managed projections")
    }

    private static func testDoesNotReprojectManagedWorkProjectionsToHub() async throws {
        let fixtures = applicationFixtures()
        let managedWorkProjection = eventSnapshot(
            id: "work-projection-1",
            calendar: fixtures.workReference,
            title: "[ME] Dentist",
            start: Date(timeIntervalSince1970: 13_000),
            end: Date(timeIntervalSince1970: 14_000)
        )
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [],
                fixtures.workCalendar.id: [managedWorkProjection]
            ]
        )
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(!plan.creates.contains { $0.destinationCalendar == fixtures.hubReference && $0.title == "[ACME] [ME] Dentist" }, "Managed work projections should not be projected back into the hub")
        try expect(plan.deletes == [managedWorkProjection], "Stale managed work projection should still be deleted when no longer expected")
    }

    private static func testProjectsWorkSourceToOtherWorkCalendarsInSamePlan() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = CalendarSnapshot(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let acmeCalendar = CalendarSnapshot(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let betaCalendar = CalendarSnapshot(id: "beta-1", title: "BETA Work", sourceTitle: "Google", isWritable: true)
        let acmeReference = CalendarReference(id: acmeCalendar.id, title: acmeCalendar.title, sourceTitle: acmeCalendar.sourceTitle)
        let betaReference = CalendarReference(id: betaCalendar.id, title: betaCalendar.title, sourceTitle: betaCalendar.sourceTitle)
        let sourceEvent = eventSnapshot(
            id: "acme-source-1",
            calendar: acmeReference,
            title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000),
            end: Date(timeIntervalSince1970: 12_000)
        )
        let settings = CalendarRelaySettings(
            hubCalendar: CalendarSelector(sourceTitle: hubCalendar.sourceTitle, calendarTitle: hubCalendar.title),
            personalPrefix: "[ME]",
            syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(name: "ACME", prefix: "[ACME]", calendar: CalendarSelector(sourceTitle: acmeCalendar.sourceTitle, calendarTitle: acmeCalendar.title)),
                WorkCalendarSettings(name: "BETA", prefix: "[BETA]", calendar: CalendarSelector(sourceTitle: betaCalendar.sourceTitle, calendarTitle: betaCalendar.title))
            ]
        )
        let store = FakeCalendarStore(
            calendars: [hubCalendar, acmeCalendar, betaCalendar],
            eventsByCalendarID: [acmeCalendar.id: [sourceEvent]]
        )
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        let plan = try await useCase.dryRun(settings: settings, now: now)

        try expect(plan.creates.contains { $0.destinationCalendar == betaReference && $0.title == "[ACME] Client Planning" }, "Work source events should project to other work calendars through the expected hub projection in the same plan")
    }

    private static func testDoesNotProjectUnknownPrefixedWorkBlockersBackToHub() async throws {
        let fixtures = applicationFixtures()
        let remoteWorkProjection = eventSnapshot(
            id: "remote-work-projection-1",
            calendar: fixtures.workReference,
            title: "[REMOTE] Partner Planning",
            start: Date(timeIntervalSince1970: 13_000),
            end: Date(timeIntervalSince1970: 14_000)
        )
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [],
                fixtures.workCalendar.id: [remoteWorkProjection]
            ]
        )
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(!plan.creates.contains { $0.destinationCalendar == fixtures.hubReference && $0.title == "[ACME] [REMOTE] Partner Planning" }, "Unknown prefixed work blockers should not be projected back into the hub")
        try expect(plan.deletes.isEmpty, "Unknown prefixed work blockers should be preserved rather than deleted")
    }

    private static func testReconciliationPropagatesCancellation() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, fixtures.workCalendar])
        let useCase = ReconcileCalendarsUseCase(calendarStore: store)

        let task = Task {
            try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)
        }
        task.cancel()

        do {
            _ = try await task.value
        } catch is CancellationError {
            return
        } catch {
            throw ContractTestFailure("Expected CancellationError, got \(error)")
        }

        throw ContractTestFailure("Expected reconciliation cancellation to propagate")
    }

    private static func testFormatsEmptyReconciliationPlan() throws {
        let output = ReconciliationPlanFormatter.format(ReconciliationPlan(creates: [], deletes: []))

        try expect(output.contains("No changes planned."), "Empty plans should produce understandable output")
    }

    private static func testFormatsPlannedCreatesAndDeletes() throws {
        let create = projectedEvent(
            destinationCalendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[ACME] Client Planning",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let delete = eventSnapshot(
            id: "stale-1",
            calendar: CalendarReference(id: "acme-1", title: "ACME Work", sourceTitle: "Google"),
            title: "[ME] Dentist",
            start: Date(timeIntervalSince1970: 3_000),
            end: Date(timeIntervalSince1970: 4_000)
        )

        let output = ReconciliationPlanFormatter.format(ReconciliationPlan(creates: [create], deletes: [delete]))

        try expect(output.contains("Creates (1)"), "Output should summarize create count")
        try expect(output.contains("Deletes (1)"), "Output should summarize delete count")
        try expect(output.contains("iCloud / Personal Work"), "Create output should include destination selector")
        try expect(output.contains("Google / ACME Work"), "Delete output should include event calendar selector")
        try expect(output.contains("[ACME] Client Planning"), "Create output should include title")
        try expect(output.contains("[ME] Dentist"), "Delete output should include title")
        try expect(output.contains("1970-01-01 00:16:40 +0000 → 1970-01-01 00:33:20 +0000"), "Output should include create time range")
        try expect(output.contains("1970-01-01 00:50:00 +0000 → 1970-01-01 01:06:40 +0000"), "Output should include delete time range")
    }

    private static func testReconciliationPlanOutputAvoidsDebugDumps() throws {
        let output = ReconciliationPlanFormatter.format(ReconciliationPlan(creates: [projectedEvent(title: "[ACME] Client Planning")], deletes: []))

        try expect(!output.contains("ProjectedEvent("), "Output should not expose Swift debug dumps")
        try expect(!output.contains("CalendarReference("), "Output should not expose Swift type internals")
    }

    private static func testFormatsCalendarList() throws {
        let output = CalendarListFormatter.format([
            CalendarSnapshot(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true),
            CalendarSnapshot(id: "readonly-1", title: "Shared Holidays", sourceTitle: "Subscribed", isWritable: false)
        ])

        try expect(output.contains("Calendars (2)"), "Calendar output should summarize count")
        try expect(output.contains("iCloud / Personal Work"), "Calendar output should include source/title selector")
        try expect(output.contains("id: hub-1"), "Calendar output should include IDs for troubleshooting")
        try expect(output.contains("writable"), "Calendar output should show writable state")
        try expect(output.contains("read-only"), "Calendar output should show read-only state")
        try expect(!output.contains("CalendarSnapshot("), "Calendar output should not expose Swift debug dumps")
    }

    private static func validSettings(
        hubCalendar: CalendarSelector = CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Personal Work"),
        personalPrefix: String = "[ME]",
        syncWindowDays: Int = 60,
        workCalendars: [WorkCalendarSettings] = [
            WorkCalendarSettings(
                name: "ACME",
                prefix: "[ACME]",
                calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
            )
        ]
    ) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: hubCalendar,
            personalPrefix: personalPrefix,
            syncWindowDays: syncWindowDays,
            workCalendars: workCalendars
        )
    }

    private static func eventSnapshot(
        id: String = "event-1",
        calendar: CalendarReference = CalendarReference(id: "calendar-1", title: "ACME Work", sourceTitle: "Google"),
        title: String = "Client Planning",
        start: Date = Date(timeIntervalSince1970: 1_000),
        end: Date = Date(timeIntervalSince1970: 2_000),
        isAllDay: Bool = false,
        availability: EventAvailability = .busy,
        status: EventStatus = .confirmed
    ) -> EventSnapshot {
        EventSnapshot(
            id: id,
            calendar: calendar,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            availability: availability,
            status: status
        )
    }

    private static func projectedEvent(
        destinationCalendar: CalendarReference = CalendarReference(id: "calendar-1", title: "ACME Work", sourceTitle: "Google"),
        title: String,
        start: Date = Date(timeIntervalSince1970: 1_000),
        end: Date = Date(timeIntervalSince1970: 2_000),
        isAllDay: Bool = false
    ) -> ProjectedEvent {
        ProjectedEvent(
            destinationCalendar: destinationCalendar,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay
        )
    }

    private static func workCalendarSettings() -> WorkCalendarSettings {
        WorkCalendarSettings(
            name: "ACME",
            prefix: "[ACME]",
            calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
        )
    }

    private static func workCalendarTargets() -> [WorkCalendarProjectionTarget] {
        [
            workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work"),
            workCalendarTarget(name: "BETA", prefix: "[BETA]", calendarID: "beta-1", calendarTitle: "BETA Work"),
            workCalendarTarget(name: "CONTOSO", prefix: "[CONTOSO]", calendarID: "contoso-1", calendarTitle: "CONTOSO Work")
        ]
    }

    private static func workCalendarTarget(
        name: String,
        prefix: String,
        calendarID: String,
        calendarTitle: String
    ) -> WorkCalendarProjectionTarget {
        WorkCalendarProjectionTarget(
            settings: WorkCalendarSettings(
                name: name,
                prefix: prefix,
                calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: calendarTitle)
            ),
            calendar: CalendarReference(id: calendarID, title: calendarTitle, sourceTitle: "Google")
        )
    }

    private static func canonicalSettingsYAML(syncWindowDays: Int?) -> String {
        let syncWindowLine = syncWindowDays.map { "syncWindowDays: \($0)\n" } ?? ""

        return """
        hubCalendar:
          sourceTitle: "iCloud"
          calendarTitle: "Personal Work"
        personalPrefix: "[ME]"
        \(syncWindowLine)workCalendars:
          - name: "ACME"
            prefix: "[ACME]"
            calendar:
              sourceTitle: "Google"
              calendarTitle: "ACME Work"
        """
    }

    private static func applicationFixtures(hubIsWritable: Bool = true) -> ApplicationFixtures {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = CalendarSnapshot(
            id: "hub-1",
            title: "Personal Work",
            sourceTitle: "iCloud",
            isWritable: hubIsWritable
        )
        let workCalendar = CalendarSnapshot(
            id: "acme-1",
            title: "ACME Work",
            sourceTitle: "Google",
            isWritable: true
        )
        let hubReference = CalendarReference(id: hubCalendar.id, title: hubCalendar.title, sourceTitle: hubCalendar.sourceTitle)
        let workReference = CalendarReference(id: workCalendar.id, title: workCalendar.title, sourceTitle: workCalendar.sourceTitle)
        let workEvent = eventSnapshot(
            id: "acme-source-1",
            calendar: workReference,
            title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000),
            end: Date(timeIntervalSince1970: 12_000)
        )
        let settings = validSettings()
        let expectedHubProjection = ProjectedEvent(
            destinationCalendar: hubReference,
            title: "[ACME] Client Planning",
            start: workEvent.start,
            end: workEvent.end,
            isAllDay: workEvent.isAllDay
        )

        return ApplicationFixtures(
            now: now,
            settings: settings,
            hubCalendar: hubCalendar,
            hubReference: hubReference,
            workCalendar: workCalendar,
            workReference: workReference,
            workEvent: workEvent,
            expectedHubProjection: expectedHubProjection
        )
    }

    private static func expectValidationError(
        _ expectedError: SettingsValidationError,
        for settings: CalendarRelaySettings
    ) throws {
        do {
            try SettingsValidator.validate(settings)
        } catch let error as SettingsValidationError {
            guard error == expectedError else {
                throw ContractTestFailure("Expected \(expectedError), got \(error)")
            }
            return
        } catch {
            throw ContractTestFailure("Expected SettingsValidationError, got \(error)")
        }

        throw ContractTestFailure("Expected validation error: \(expectedError)")
    }

    private static func expectReconciliationError(
        _ expectedError: ReconcileCalendarsError,
        from operation: () async throws -> ReconciliationPlan
    ) async throws {
        do {
            _ = try await operation()
        } catch let error as ReconcileCalendarsError {
            guard error == expectedError else {
                throw ContractTestFailure("Expected \(expectedError), got \(error)")
            }
            return
        } catch {
            throw ContractTestFailure("Expected ReconcileCalendarsError, got \(error)")
        }

        throw ContractTestFailure("Expected reconciliation error: \(expectedError)")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw ContractTestFailure(message)
        }
    }
}

private struct ApplicationFixtures {
    let now: Date
    let settings: CalendarRelaySettings
    let hubCalendar: CalendarSnapshot
    let hubReference: CalendarReference
    let workCalendar: CalendarSnapshot
    let workReference: CalendarReference
    let workEvent: EventSnapshot
    let expectedHubProjection: ProjectedEvent
}

private actor FakeCalendarStore: CalendarStorePort {
    private let calendars: [CalendarSnapshot]
    private let eventsByCalendarID: [String: [EventSnapshot]]
    private var recordedCreates: [ProjectedEvent] = []
    private var recordedDeletes: [EventSnapshot] = []

    init(
        calendars: [CalendarSnapshot],
        eventsByCalendarID: [String: [EventSnapshot]] = [:]
    ) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
    }

    func listCalendars() async throws -> [CalendarSnapshot] {
        calendars
    }

    func events(
        in calendar: CalendarReference,
        from start: Date,
        to end: Date
    ) async throws -> [EventSnapshot] {
        eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: ProjectedEvent) async throws {
        recordedCreates.append(event)
    }

    func deleteEvent(_ event: EventSnapshot) async throws {
        recordedDeletes.append(event)
    }

    func createdEvents() -> [ProjectedEvent] {
        recordedCreates
    }

    func deletedEvents() -> [EventSnapshot] {
        recordedDeletes
    }
}

private struct ContractTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}