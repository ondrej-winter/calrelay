import CalRelayKit
import Foundation

enum CalRelayContractTests {
    static func runAll() async throws {
        try runDomainAndConfigurationTests()
        try await runApplicationAndPresentationTests()
    }

    private static func runDomainAndConfigurationTests() throws {
        try Self.testAcceptsValidSettings()
        try Self.testRejectsMissingWorkCalendars()
        try Self.testRejectsEmptyHubSelectorFields()
        try Self.testRejectsEmptyWorkCalendarSelectorFields()
        try Self.testRejectsEmptyWorkCalendarNameAndPrefix()
        try Self.testRejectsNonPositiveSyncWindow()
        try Self.testRejectsDuplicateWorkPrefixes()
        try Self.testRejectsPersonalPrefixConflictingWithWorkPrefix()
        try Self.testRejectsDuplicateCalendarSelectors()
        try Self.testIncludesTimedBusyEvents()
        try Self.testSkipsTimedTentativeEvents()
        try Self.testIncludesTimedEventsWhenAvailabilityIsNotSupported()
        try Self.testIncludesUnavailableEvents()
        try Self.testIncludesAllDayBusyEvents()
        try Self.testIncludesAcceptedCurrentUserRegardlessOfAvailability()
        try Self.testSkipsEveryNonAcceptedCurrentUserResponse()
        try Self.testIgnoresNonCancelledOverallStatusWithoutCurrentUserAttendee()
        try Self.testSkipsCancelledEvents()
        try Self.testEvaluateReturnsAvailabilityIncludedForBusyEvents()
        try Self.testEvaluateReturnsAvailabilityIncludedForAllDayBusyEvents()
        try Self.testEvaluateReturnsCancelledReason()
        try Self.testEvaluateReturnsCurrentUserAcceptedReason()
        try Self.testEvaluateReturnsCurrentUserNonAcceptedReason()
        try Self.testEvaluateReturnsAvailabilityExcludedForTentativeEvents()
        try Self.testEvaluateReturnsAvailabilityExcludedForFreeEvents()
        try Self.testEvaluateReturnsAvailabilityIncludedForUnavailableEvents()
        try Self.testVisibleEventKeysRemainDistinctForAdjacentMeetings()

        try Self.testProjectsIncludedWorkEventToHub()
        try Self.testDoesNotProjectExcludedWorkEventToHub()
        try Self.testWorkProjectionNormalizesSourceTitle()
        try Self.testProjectsPrefixedHubEventToOtherWorkCalendars()
        try Self.testProjectsUnprefixedHubEventToAllWorkCalendarsWithPersonalPrefix()
        try Self.testPersonalProjectionNormalizesSourceTitle()
        try Self.testProjectsRemotePrefixedHubEventToLocalWorkCalendars()
        try Self.testProjectsMarkedHubEventRegardlessOfAvailability()
        try Self.testDoesNotProjectCancelledMarkedHubEvent()
        try Self.testTreatsMalformedBracketedHubTitleAsPersonalSource()
        try Self.testPlansCreateForMissingExpectedProjection()
        try Self.testPlansOneCreateForDuplicateExpectedProjection()
        try Self.testPlansDeleteForStaleManagedProjection()
        try Self.testReplacesAllManagedDuplicatesForExpectedKey()
        try Self.testReplacesCancelledManagedProjectionForExpectedKey()
        try Self.testDeletesCancelledDuplicateWithoutReplacingRetainedProjection()
        try Self.testNeverDeletesUnprefixedEvents()
        try Self.testPreservesUnmanagedMatchesWithoutTreatingThemAsManagedProjection()
        try Self.testPreservesUnknownPrefixedEvents()
        try Self.testPlansRenameAsDeleteOldAndCreateNew()
        try Self.testPlansNoChangesWhenExpectedStateAlreadyExists()
        try Self.testParsesCanonicalYAMLSettings()
        try Self.testDefaultsSyncWindowDaysWhenOmitted()
        try Self.testReportsSafeYAMLShapeErrors()
        try Self.testRejectsUnknownYAMLFields()
        try Self.testRejectsDuplicateYAMLKeys()
        try Self.testReportsSettingsValidationErrorsFromYAML()
        try Self.testMapsCurrentUserParticipantStatusSeparatelyFromOverallStatus()
        try Self.testMapsCancellationAndAcceptedParticipantIndependently()
        try Self.testMapsAbsentCurrentUserParticipantWithoutChangingOverallStatus()
    }

    private static func runApplicationAndPresentationTests() async throws {
        try await Self.testDryRunPlansChangesWithoutMutatingCalendarStore()
        try await Self.testOrdinaryReconciliationRejectsMigrationBeforeCalendarAccess()
        try await Self.testReconciliationLoadsTwoDaysInThePast()
        try await Self.testRejectsMissingCalendarSelectorDuringReconciliation()
        try await Self.testRejectsAmbiguousCalendarSelectorDuringReconciliation()
        try await Self.testDryRunRejectsReadOnlyConfiguredRoleBeforePlanning()
        try await Self.testApplyRejectsReadOnlyDestinationBeforeMutation()
        try await Self.testApplyCreatesAndDeletesPlannedChanges()
        try await Self.testApplyExecutesDeleteBeforeCreate()
        try await Self.testApplyStopsAfterFailureWithoutRollback()
        try await Self.testDoesNotReprojectManagedWorkProjectionsToHub()
        try await Self.testProjectsMalformedBracketedWorkEventAsOrdinarySource()
        try await Self.testProjectsWorkSourceToOtherWorkCalendarsInSamePlan()
        try await Self.testDoesNotDoublePrefixRelayedWorkBlockers()
        try await Self.testDeletesUnknownPrefixedWorkBlockersWhenAbsentFromHub()
        try await Self.testPreservesUnknownPrefixedHubEvents()
        try await Self.testStaleLocalHubProjectionDoesNotRouteForExtraCycle()
        try await Self.testReconciliationPropagatesCancellation()
        try await Self.testExplainReportsIncludedAndExcludedEvents()
        try await Self.testExplanationClassifiesEveryInputDimensionAndReportsWindow()
        try await Self.testExplanationUsesSharedOrderedActionsAndCreateCausality()
        try Self.testFormatsEmptyReconciliationPlan()
        try Self.testFormatsPlannedCreatesAndDeletes()
        try Self.testReconciliationPlanOutputAvoidsDebugDumps()
        try Self.testFormatsCalendarList()
        try Self.testFormatsEventExplanations()
        try Self.testFormatsEmptyEventExplanations()
    }

    private static func testAcceptsValidSettings() throws { try SettingsValidator.validate(validSettings()) }

    private static func testRejectsMissingWorkCalendars() throws {
        let baseSettings = validSettings()
        let settings = CalendarRelaySettings(
            hubCalendar: baseSettings.hubCalendar, personalPrefix: baseSettings.personalPrefix,
            syncWindowDays: baseSettings.syncWindowDays, workCalendars: [])

        try expectValidationError(.missingWorkCalendars, for: settings)
    }

    private static func testRejectsEmptyHubSelectorFields() throws {
        try expectValidationError(
            .emptyHubCalendarSourceTitle,
            for: validSettings(
                hubCalendar: HubCalendarSettings(
                    calendar: CalendarSelector(sourceTitle: "", calendarTitle: "Personal Work"))))

        try expectValidationError(
            .emptyHubCalendarTitle,
            for: validSettings(
                hubCalendar: HubCalendarSettings(calendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: ""))))
    }

    private static func testRejectsEmptyWorkCalendarSelectorFields() throws {
        try expectValidationError(
            .emptyWorkCalendarSourceTitle(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "", calendarTitle: "ACME Work"))
            ]))

        try expectValidationError(
            .emptyWorkCalendarTitle(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]", calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "")
                )
            ]))
    }

    private static func testRejectsEmptyWorkCalendarNameAndPrefix() throws {
        try expectValidationError(
            .emptyWorkCalendarName,
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
            ]))

        try expectValidationError(
            .emptyWorkCalendarPrefix(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
            ]))
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
                    name: "ACME", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")),
                WorkCalendarSettings(
                    name: "BETA", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Exchange", calendarTitle: "BETA Work"))
            ]))
    }

    private static func testRejectsDuplicateCalendarSelectors() throws {
        let selector = CalendarSelector(sourceTitle: "Google", calendarTitle: "Shared Work")
        try expectValidationError(
            .duplicateCalendarSelector(selector, roles: [.hub, .work(name: "ACME", declarationIndex: 0)]),
            for: validSettings(
                hubCalendar: HubCalendarSettings(calendar: selector),
                workCalendars: [WorkCalendarSettings(name: "ACME", prefix: "[ACME]", calendar: selector)]))
    }

    private static func testRejectsPersonalPrefixConflictingWithWorkPrefix() throws {
        try expectValidationError(
            .personalPrefixConflictsWithWorkPrefix("[ACME]"), for: validSettings(personalPrefix: "[ACME]"))
    }

    private static func testIncludesTimedBusyEvents() throws {
        let event = calendarEvent(availability: .busy, status: .confirmed)

        try expect(EventInclusionPolicy.includes(event), "Timed busy events should be included")
    }

    private static func testSkipsTimedTentativeEvents() throws {
        let event = calendarEvent(availability: .tentative, status: .tentative)

        try expect(!EventInclusionPolicy.includes(event), "Timed tentative events should be skipped by default")
    }

    private static func testIncludesTimedEventsWhenAvailabilityIsNotSupported() throws {
        let event = calendarEvent(availability: .notSupported, status: .confirmed)

        try expect(
            EventInclusionPolicy.includes(event),
            "Timed events from calendars without availability support should be included")
    }

    private static func testIncludesUnavailableEvents() throws {
        let event = calendarEvent(availability: .unavailable, status: .confirmed)

        try expect(EventInclusionPolicy.includes(event), "Unavailable events should be included")
    }

    private static func testIncludesAllDayBusyEvents() throws {
        let event = calendarEvent(isAllDay: true, availability: .busy, status: .confirmed)

        try expect(EventInclusionPolicy.includes(event), "All-day events should use the same eligibility policy")
    }

    private static func testIncludesAcceptedCurrentUserRegardlessOfAvailability() throws {
        let event = calendarEvent(availability: .free, status: .tentative, currentUserParticipantStatus: .accepted)

        try expect(
            EventInclusionPolicy.includes(event), "An accepted current-user response should override availability")
    }

    private static func testSkipsEveryNonAcceptedCurrentUserResponse() throws {
        for response in [CurrentUserParticipantStatus.declined, .tentative, .other] {
            let event = calendarEvent(availability: .busy, status: .confirmed, currentUserParticipantStatus: response)

            try expect(
                !EventInclusionPolicy.includes(event),
                "Every non-accepted current-user response should make the event ineligible")
        }
    }

    private static func testIgnoresNonCancelledOverallStatusWithoutCurrentUserAttendee() throws {
        let event = calendarEvent(availability: .busy, status: .tentative)

        try expect(
            EventInclusionPolicy.includes(event),
            "Non-cancelled overall event status should not override no-attendee availability")
    }

    private static func testSkipsCancelledEvents() throws {
        let event = calendarEvent(availability: .busy, status: .cancelled)

        try expect(!EventInclusionPolicy.includes(event), "Cancelled events should be skipped")
    }

    private static func testEvaluateReturnsAvailabilityIncludedForBusyEvents() throws {
        let event = calendarEvent(availability: .busy, status: .confirmed)

        try expect(
            EventInclusionPolicy.evaluate(event) == .noCurrentUserAttendeeIncluded(.busy),
            "Busy timed events should identify the no-attendee availability decision")
    }

    private static func testEvaluateReturnsAvailabilityIncludedForAllDayBusyEvents() throws {
        let event = calendarEvent(isAllDay: true, availability: .busy, status: .confirmed)

        try expect(
            EventInclusionPolicy.evaluate(event) == .noCurrentUserAttendeeIncluded(.busy),
            "All-day busy events should use the same no-attendee availability reason")
    }

    private static func testEvaluateReturnsCancelledReason() throws {
        let event = calendarEvent(availability: .busy, status: .cancelled)

        try expect(
            EventInclusionPolicy.evaluate(event) == .cancelled,
            "Cancelled events should evaluate with the cancelled reason")
    }

    private static func testEvaluateReturnsCurrentUserAcceptedReason() throws {
        let event = calendarEvent(availability: .free, status: .confirmed, currentUserParticipantStatus: .accepted)

        try expect(
            EventInclusionPolicy.evaluate(event) == .currentUserAccepted,
            "Accepted attendee events should identify current-user acceptance")
    }

    private static func testEvaluateReturnsCurrentUserNonAcceptedReason() throws {
        let event = calendarEvent(availability: .busy, status: .confirmed, currentUserParticipantStatus: .tentative)

        try expect(
            EventInclusionPolicy.evaluate(event) == .currentUserNonAccepted(.tentative),
            "Non-accepted attendee events should identify the current-user response")
    }

    private static func testEvaluateReturnsAvailabilityExcludedForTentativeEvents() throws {
        let event = calendarEvent(availability: .tentative, status: .confirmed)

        try expect(
            EventInclusionPolicy.evaluate(event) == .noCurrentUserAttendeeExcluded(.tentative),
            "Tentative availability should identify the no-attendee exclusion")
    }

    private static func testEvaluateReturnsAvailabilityExcludedForFreeEvents() throws {
        let event = calendarEvent(availability: .free, status: .confirmed)

        try expect(
            EventInclusionPolicy.evaluate(event) == .noCurrentUserAttendeeExcluded(.free),
            "Free availability should identify the no-attendee exclusion")
    }

    private static func testEvaluateReturnsAvailabilityIncludedForUnavailableEvents() throws {
        let event = calendarEvent(availability: .unavailable, status: .confirmed)

        try expect(
            EventInclusionPolicy.evaluate(event) == .noCurrentUserAttendeeIncluded(.unavailable),
            "Unavailable events should identify the no-attendee inclusion")
    }

    private static func testVisibleEventKeysRemainDistinctForAdjacentMeetings() throws {
        let first = calendarEvent(
            id: "event-1", title: "Planning", start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000))
        let adjacent = calendarEvent(
            id: "event-2", title: "Planning", start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_000))

        try expect(
            VisibleEventKey(event: first) != VisibleEventKey(event: adjacent),
            "Repeated titles and adjacent meetings should remain distinct when start/end differ")
    }

    private static func testProjectsIncludedWorkEventToHub() throws {
        let hubCalendar = CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud")
        let sourceEvent = calendarEvent(
            id: "acme-1", calendar: CalendarIdentity(id: "acme-1", title: "ACME Work", sourceTitle: "Google"),
            title: "Client Planning", start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000), isAllDay: false, availability: .busy, status: .confirmed)

        let projections = WorkToHubProjector.project(
            events: [sourceEvent], from: workCalendarSettings(), to: hubCalendar)

        try expect(projections.count == 1, "Expected one hub projection")
        try expect(projections[0].destinationCalendar == hubCalendar, "Projection should target hub calendar")
        try expect(projections[0].title == "[ACME] Client Planning", "Projection should prefix source title")
        try expect(projections[0].start == sourceEvent.start, "Projection should copy start")
        try expect(projections[0].end == sourceEvent.end, "Projection should copy end")
        try expect(projections[0].isAllDay == sourceEvent.isAllDay, "Projection should copy all-day flag")
    }

    private static func testDoesNotProjectExcludedWorkEventToHub() throws {
        let sourceEvent = calendarEvent(availability: .free, status: .confirmed)

        let projections = WorkToHubProjector.project(
            events: [sourceEvent], from: workCalendarSettings(),
            to: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"))

        try expect(projections.isEmpty, "Excluded source events should not produce hub projections")
    }

    private static func testWorkProjectionNormalizesSourceTitle() throws {
        let hubCalendar = CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud")
        let sourceEvents = [
            calendarEvent(id: "trimmed", title: "  Client Planning \n"), calendarEvent(id: "empty", title: " \t")
        ]

        let projections = WorkToHubProjector.project(
            events: sourceEvents, from: workCalendarSettings(), to: hubCalendar)

        try expect(
            projections.map(\.title) == ["[ACME] Client Planning", "[ACME] (Untitled)"],
            "Work projections should trim source titles and replace empty normalized titles")
    }

    private static func testProjectsPrefixedHubEventToOtherWorkCalendars() throws {
        let hubEvent = calendarEvent(
            calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[ACME] Client Planning")

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent], to: workCalendarTargets(), personalPrefix: "[ME]")

        try expect(projections.count == 2, "Expected prefixed hub event to project to non-source work calendars")
        try expect(
            !projections.contains { $0.destinationCalendar.title == "ACME Work" },
            "Prefixed hub event should not route back to matching source calendar")
        try expect(
            projections.contains {
                $0.destinationCalendar.title == "BETA Work" && $0.title == "[ACME] Client Planning"
            }, "Prefixed hub event should route to BETA unchanged")
        try expect(
            projections.contains {
                $0.destinationCalendar.title == "CONTOSO Work" && $0.title == "[ACME] Client Planning"
            }, "Prefixed hub event should route to CONTOSO unchanged")
    }

    private static func testProjectsUnprefixedHubEventToAllWorkCalendarsWithPersonalPrefix() throws {
        let hubEvent = calendarEvent(
            calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"), title: "Dentist")

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent], to: workCalendarTargets(), personalPrefix: "[ME]")

        try expect(projections.count == 3, "Expected unprefixed hub event to project to all work calendars")
        try expect(
            projections.allSatisfy { $0.title == "[ME] Dentist" }, "Unprefixed hub event should use personal prefix")
    }

    private static func testPersonalProjectionNormalizesSourceTitle() throws {
        let hubEvents = [
            calendarEvent(
                id: "trimmed", calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
                title: "  Dentist \n"),
            calendarEvent(
                id: "empty", calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
                title: " \t")
        ]
        let target = workCalendarTarget(
            name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work")

        let projections = HubToWorkProjector.project(hubEvents: hubEvents, to: [target], personalPrefix: "[ME]")

        try expect(
            projections.map(\.title) == ["[ME] Dentist", "[ME] (Untitled)"],
            "Personal projections should trim source titles and replace empty normalized titles")
    }

    private static func testProjectsRemotePrefixedHubEventToLocalWorkCalendars() throws {
        let hubEvent = calendarEvent(
            calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[BETA] Sales Call")

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: [workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work")],
            personalPrefix: "[ME]")

        try expect(projections.count == 1, "Expected remote prefixed hub event to project to local work calendar")
        try expect(
            projections[0].destinationCalendar.title == "ACME Work",
            "Remote prefixed hub event should target locally configured work calendar")
        try expect(
            projections[0].title == "[BETA] Sales Call", "Remote prefixed hub event should preserve remote prefix")
    }

    private static func testProjectsMarkedHubEventRegardlessOfAvailability() throws {
        let hubEvent = calendarEvent(
            calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[REMOTE] Partner Planning", availability: .free, status: .confirmed)

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: [workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work")],
            personalPrefix: "[ME]")

        try expect(projections.count == 1, "A valid marked hub event should bypass availability eligibility")
        try expect(projections[0].title == hubEvent.title, "A valid marked hub event should retain its title")
    }

    private static func testDoesNotProjectCancelledMarkedHubEvent() throws {
        let hubEvent = calendarEvent(
            calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[REMOTE] Partner Planning", availability: .busy, status: .cancelled)

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: [workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work")],
            personalPrefix: "[ME]")

        try expect(projections.isEmpty, "A cancelled valid marked hub event should not route")
    }

    private static func testTreatsMalformedBracketedHubTitleAsPersonalSource() throws {
        let hubEvent = calendarEvent(
            calendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[ACME]Planning")

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent], to: workCalendarTargets(), personalPrefix: "[ME]")

        try expect(projections.count == 3, "A malformed marked title should not suppress any work-calendar target")
        try expect(
            projections.allSatisfy { $0.title == "[ME] [ACME]Planning" },
            "A malformed marked title should be treated as an ordinary personal source")
    }

    private static func testPlansCreateForMissingExpectedProjection() throws {
        let expected = calendarEventProjection(title: "[ACME] Client Planning")

        let plan = ReconciliationPlanner.plan(expected: [expected], existing: [], managedPrefixes: ["[ACME]"])

        try expect(plan.creates == [expected], "Missing expected projection should be planned as create")
        try expect(plan.deletes.isEmpty, "Missing expected projection should not create deletes")
    }

    private static func testPlansOneCreateForDuplicateExpectedProjection() throws {
        let expected = calendarEventProjection(title: "[ACME] Client Planning")

        let plan = ReconciliationPlanner.plan(expected: [expected, expected], existing: [], managedPrefixes: ["[ACME]"])

        try expect(plan.creates == [expected], "Duplicate expected projections should result in one create")
        try expect(plan.deletes.isEmpty, "Duplicate expected projections should not create deletes")
    }

    private static func testPlansDeleteForStaleManagedProjection() throws {
        let stale = calendarEvent(title: "[ACME] Old Planning")

        let plan = ReconciliationPlanner.plan(expected: [], existing: [stale], managedPrefixes: ["[ACME]"])

        try expect(plan.creates.isEmpty, "Stale managed projection should not create events")
        try expect(plan.deletes == [stale], "Stale managed projection should be planned as delete")
    }

    private static func testReplacesAllManagedDuplicatesForExpectedKey() throws {
        let existing = calendarEvent(id: "managed-1", title: "[ACME] Client Planning")
        let duplicate = calendarEvent(
            id: "managed-2", calendar: existing.calendar, title: existing.title, start: existing.start,
            end: existing.end, isAllDay: existing.isAllDay)
        let expected = calendarEventProjection(
            destinationCalendar: existing.calendar, title: existing.title, start: existing.start, end: existing.end,
            isAllDay: existing.isAllDay)

        let plan = ReconciliationPlanner.plan(
            expected: [expected], existing: [existing, duplicate], managedPrefixes: ["[ACME]"])

        try expect(plan.creates == [expected], "Managed duplicates should produce one canonical replacement create")
        try expect(plan.deletes == [existing, duplicate], "Every managed duplicate should be removed")
    }

    private static func testReplacesCancelledManagedProjectionForExpectedKey() throws {
        let cancelled = calendarEvent(title: "[ACME] Client Planning", status: .cancelled)
        let expected = calendarEventProjection(
            destinationCalendar: cancelled.calendar, title: cancelled.title, start: cancelled.start, end: cancelled.end,
            isAllDay: cancelled.isAllDay)

        let plan = ReconciliationPlanner.plan(expected: [expected], existing: [cancelled], managedPrefixes: ["[ACME]"])

        try expect(plan.creates == [expected], "A cancelled managed match should not satisfy the expectation")
        try expect(plan.deletes == [cancelled], "A cancelled managed match should be deleted")
    }

    private static func testDeletesCancelledDuplicateWithoutReplacingRetainedProjection() throws {
        let retained = calendarEvent(title: "[ACME] Client Planning")
        let cancelled = calendarEvent(
            id: "event-2", calendar: retained.calendar, title: retained.title, start: retained.start, end: retained.end,
            isAllDay: retained.isAllDay, status: .cancelled)
        let expected = calendarEventProjection(
            destinationCalendar: retained.calendar, title: retained.title, start: retained.start, end: retained.end,
            isAllDay: retained.isAllDay)

        let plan = ReconciliationPlanner.plan(
            expected: [expected], existing: [retained, cancelled], managedPrefixes: ["[ACME]"])

        try expect(plan.creates.isEmpty, "One active managed match should still satisfy the expectation")
        try expect(plan.deletes == [cancelled], "The cancelled managed duplicate should be removed")
    }

    private static func testNeverDeletesUnprefixedEvents() throws {
        let original = calendarEvent(title: "Client Planning")

        let plan = ReconciliationPlanner.plan(expected: [], existing: [original], managedPrefixes: ["[ACME]"])

        try expect(plan.deletes.isEmpty, "Unprefixed events should never be deleted")
    }

    private static func testPreservesUnmanagedMatchesWithoutTreatingThemAsManagedProjection() throws {
        let existing = calendarEvent(id: "manual-1", title: "Client Planning")
        let duplicate = calendarEvent(
            id: "manual-2", calendar: existing.calendar, title: existing.title, start: existing.start,
            end: existing.end, isAllDay: existing.isAllDay)
        let expected = calendarEventProjection(
            destinationCalendar: existing.calendar, title: existing.title, start: existing.start, end: existing.end,
            isAllDay: existing.isAllDay)

        let plan = ReconciliationPlanner.plan(
            expected: [expected], existing: [existing, duplicate], managedPrefixes: ["[ACME]"])

        try expect(plan.creates == [expected], "Unmanaged matches should not satisfy a managed projection expectation")
        try expect(plan.deletes.isEmpty, "Unmanaged matches should remain protected from deletion")
    }

    private static func testPreservesUnknownPrefixedEvents() throws {
        let remote = calendarEvent(title: "[BETA] Sales Call")

        let plan = ReconciliationPlanner.plan(expected: [], existing: [remote], managedPrefixes: ["[ACME]"])

        try expect(plan.deletes.isEmpty, "Unknown prefixed events should be preserved")
    }

    private static func testPlansRenameAsDeleteOldAndCreateNew() throws {
        let old = calendarEvent(title: "[ACME] Old Planning")
        let new = calendarEventProjection(title: "[ACME] New Planning")

        let plan = ReconciliationPlanner.plan(expected: [new], existing: [old], managedPrefixes: ["[ACME]"])

        try expect(plan.creates == [new], "Renamed projection should create new visible event")
        try expect(plan.deletes == [old], "Renamed projection should delete old managed event")
    }

    private static func testPlansNoChangesWhenExpectedStateAlreadyExists() throws {
        let existing = calendarEvent(title: "[ACME] Client Planning")
        let expected = calendarEventProjection(
            destinationCalendar: existing.calendar, title: existing.title, start: existing.start, end: existing.end,
            isAllDay: existing.isAllDay)

        let plan = ReconciliationPlanner.plan(expected: [expected], existing: [existing], managedPrefixes: ["[ACME]"])

        try expect(plan.creates.isEmpty, "Existing expected projection should not be created again")
        try expect(plan.deletes.isEmpty, "Existing expected projection should not be deleted")
    }

    private static func testParsesCanonicalYAMLSettings() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(canonicalSettingsYAML(syncWindowDays: 45))

        try expect(settings == validSettings(syncWindowDays: 45), "Canonical YAML should parse into expected settings")
    }

    private static func testDefaultsSyncWindowDaysWhenOmitted() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(canonicalSettingsYAML(syncWindowDays: nil))

        try expect(settings.syncWindowDays == 100, "Omitted syncWindowDays should default to 100")
    }

    private static func testReportsSafeYAMLShapeErrors() throws {
        do { _ = try YAMLCalendarRelaySettingsLoader.load("hubCalendar: [not, a, selector]") } catch let error
            as YAMLCalendarRelaySettingsError
        {
            try expect(error.description.contains("Invalid configuration"), "Shape errors should be clear")
            try expect(
                !error.description.contains("hubCalendar: [not, a, selector]"), "Shape errors should not echo raw YAML")
            return
        } catch { throw ContractTestFailure("Expected YAMLCalendarRelaySettingsError, got \(error)") }

        throw ContractTestFailure("Expected invalid YAML shape error")
    }

    private static func testRejectsUnknownYAMLFields() throws {
        let rootUnknown = canonicalSettingsYAML(syncWindowDays: 45) + "\nsecretField: private-value\n"
        try expectInvalidConfiguration(rootUnknown, prohibitedText: "private-value")

        let nestedUnknown = """
            hubCalendar:
              sourceTitle: "iCloud"
              calendarTitle: "Personal Work"
              privateField: "private-value"
            personalPrefix: "[ME]"
            workCalendars:
              - name: "ACME"
                prefix: "[ACME]"
                calendar:
                  sourceTitle: "Google"
                  calendarTitle: "ACME Work"
            """
        try expectInvalidConfiguration(nestedUnknown, prohibitedText: "private-value")
    }

    private static func testRejectsDuplicateYAMLKeys() throws {
        let duplicateRoot = """
            hubCalendar:
              sourceTitle: "iCloud"
              calendarTitle: "Personal Work"
            personalPrefix: "[ME]"
            personalPrefix: "[PRIVATE]"
            workCalendars:
              - name: "ACME"
                prefix: "[ACME]"
                calendar:
                  sourceTitle: "Google"
                  calendarTitle: "ACME Work"
            """
        try expectInvalidConfiguration(duplicateRoot, prohibitedText: "[PRIVATE]")

        let duplicateNested = """
            hubCalendar:
              sourceTitle: "iCloud"
              sourceTitle: "Private Account"
              calendarTitle: "Personal Work"
            personalPrefix: "[ME]"
            workCalendars:
              - name: "ACME"
                prefix: "[ACME]"
                calendar:
                  sourceTitle: "Google"
                  calendarTitle: "ACME Work"
            """
        try expectInvalidConfiguration(duplicateNested, prohibitedText: "Private Account")
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

        do { _ = try YAMLCalendarRelaySettingsLoader.load(yaml) } catch let error as YAMLCalendarRelaySettingsError {
            try expect(
                error.description.contains("Work calendar prefix must be unique"),
                "Validation errors should surface actionable messages")
            return
        } catch { throw ContractTestFailure("Expected YAMLCalendarRelaySettingsError, got \(error)") }

        throw ContractTestFailure("Expected settings validation error")
    }

    private static func testMapsCurrentUserParticipantStatusSeparatelyFromOverallStatus() throws {
        let values = EventKitEventStatusMapper.map(currentUserParticipantStatus: .tentative, eventStatus: .confirmed)

        try expect(
            values.eventStatus == .confirmed,
            "Current-user response should not replace the overall EventKit event status")
        try expect(
            values.currentUserParticipantStatus == .tentative,
            "Current-user tentative response should remain separately available")
    }

    private static func testMapsCancellationAndAcceptedParticipantIndependently() throws {
        let values = EventKitEventStatusMapper.map(currentUserParticipantStatus: .accepted, eventStatus: .cancelled)

        try expect(values.eventStatus == .cancelled, "Reliable cancellation should remain the overall event status")
        try expect(
            values.currentUserParticipantStatus == .accepted,
            "Accepted current-user response should remain available alongside cancellation")
    }

    private static func testMapsAbsentCurrentUserParticipantWithoutChangingOverallStatus() throws {
        let values = EventKitEventStatusMapper.map(currentUserParticipantStatus: nil, eventStatus: .tentative)

        try expect(
            values.eventStatus == .tentative, "Overall non-cancelled status should remain available for diagnostics")
        try expect(
            values.currentUserParticipantStatus == nil,
            "An absent current-user attendee should remain distinct from an unknown response")
    }

    private static func testDryRunPlansChangesWithoutMutatingCalendarStore() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.workCalendar.id: [fixtures.workEvent]])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)
        let createdEvents = await store.createdEvents()
        let deletedEvents = await store.deletedEvents()

        try expect(plan.creates == [fixtures.expectedHubProjection], "Dry-run should plan missing hub projection")
        try expect(plan.deletes.isEmpty, "Dry-run should not plan deletes for this scenario")
        try expect(createdEvents.isEmpty, "Dry-run should not create events")
        try expect(deletedEvents.isEmpty, "Dry-run should not delete events")
    }

    private static func testOrdinaryReconciliationRejectsMigrationBeforeCalendarAccess() async throws {
        let fixtures = applicationFixtures()
        let settings = CalendarRelaySettings(
            hubCalendar: fixtures.settings.hubCalendar, personalPrefix: fixtures.settings.personalPrefix,
            syncWindowDays: fixtures.settings.syncWindowDays, workCalendars: fixtures.settings.workCalendars,
            legacyMarkers: ["[OLD]"])
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, fixtures.workCalendar])

        try await expectReconciliationError(
            .migrationPending,
            from: { try await reconciliationUseCase(store: store).dryRun(settings: settings, now: fixtures.now) })
        try expect((await store.eventRequests()).isEmpty, "Migration pending should block before event reads")
    }

    private static func testReconciliationLoadsTwoDaysInThePast() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, fixtures.workCalendar])
        let useCase = reconciliationUseCase(store: store)

        _ = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)

        let requests = await store.eventRequests()
        let expectedWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixtures.now, calendar: .current, syncWindowDays: fixtures.settings.syncWindowDays)

        try expect(requests.count == 2, "Reconciliation should load events for the hub and work calendars")
        try expect(
            requests.allSatisfy { $0.start == expectedWindow.start && $0.end == expectedWindow.end },
            "Reconciliation should use the canonical whole-local-date window")
    }

    private static func testRejectsMissingCalendarSelectorDuringReconciliation() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(calendars: [fixtures.workCalendar])
        let useCase = reconciliationUseCase(store: store)

        try await expectReconciliationError(
            .accessPreflightFailed([.calendarMissing(role: .hub, selector: fixtures.settings.hubCalendar.calendar)]),
            from: { try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now) })
    }

    private static func testRejectsAmbiguousCalendarSelectorDuringReconciliation() async throws {
        let fixtures = applicationFixtures()
        let duplicateHub = RelayCalendar(
            id: "hub-duplicate", title: fixtures.hubCalendar.title, sourceTitle: fixtures.hubCalendar.sourceTitle,
            isWritable: true)
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, duplicateHub, fixtures.workCalendar])
        let useCase = reconciliationUseCase(store: store)

        try await expectReconciliationError(
            .accessPreflightFailed([.calendarAmbiguous(role: .hub, selector: fixtures.settings.hubCalendar.calendar)]),
            from: { try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now) })
    }

    private static func testApplyRejectsReadOnlyDestinationBeforeMutation() async throws {
        let fixtures = applicationFixtures(hubIsWritable: false)
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.workCalendar.id: [fixtures.workEvent]])
        let useCase = reconciliationUseCase(store: store)

        try await expectReconciliationError(
            .accessPreflightFailed([.calendarReadOnly(role: .hub, selector: fixtures.settings.hubCalendar.calendar)]),
            from: { try await useCase.apply(settings: fixtures.settings, now: fixtures.now) })

        try expect((await store.createdEvents()).isEmpty, "Read-only apply should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Read-only apply should not delete events")
    }

    private static func testDryRunRejectsReadOnlyConfiguredRoleBeforePlanning() async throws {
        let fixtures = applicationFixtures(hubIsWritable: false)
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, fixtures.workCalendar])
        let useCase = reconciliationUseCase(store: store)

        do { _ = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now) } catch {
            try expect((await store.createdEvents()).isEmpty, "Read-only dry-run should not create events")
            try expect((await store.deletedEvents()).isEmpty, "Read-only dry-run should not delete events")
            return
        }

        throw ContractTestFailure("Expected dry-run to reject a read-only configured role")
    }

    private static func testApplyCreatesAndDeletesPlannedChanges() async throws {
        let fixtures = applicationFixtures()
        let staleHubProjection = calendarEvent(
            id: "hub-stale-1", calendar: fixtures.hubReference, title: "[ACME] Old Planning")
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [staleHubProjection], fixtures.workCalendar.id: [fixtures.workEvent]
            ])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.apply(settings: fixtures.settings, now: fixtures.now)

        try expect(plan.creates == [fixtures.expectedHubProjection], "Apply should return planned create")
        try expect(plan.deletes == [staleHubProjection], "Apply should return planned delete")
        try expect(
            await store.createdEvents() == [fixtures.expectedHubProjection], "Apply should create planned projections")
        try expect(
            await store.deletedEvents() == [staleHubProjection.identity],
            "Apply should delete stale managed projections by identity")
    }

    private static func testApplyExecutesDeleteBeforeCreate() async throws {
        let fixtures = applicationFixtures()
        let staleHubProjection = calendarEvent(
            id: "hub-stale-1", calendar: fixtures.hubReference, title: "[ACME] Old Planning")
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [staleHubProjection], fixtures.workCalendar.id: [fixtures.workEvent]
            ])

        _ = try await reconciliationUseCase(store: store).apply(settings: fixtures.settings, now: fixtures.now)

        try expect(
            await store.mutationAttempts() == [
                .delete(CalendarEventReference(providerIdentifier: "hub-stale-1")),
                .create(PhysicalCalendarReference(providerIdentifier: "hub-1"))
            ], "Ordinary apply should execute hub deletes before hub creates")
    }

    private static func testApplyStopsAfterFailureWithoutRollback() async throws {
        let fixtures = applicationFixtures()
        let staleHubProjection = calendarEvent(
            id: "hub-stale-1", calendar: fixtures.hubReference, title: "[ACME] Old Planning")
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [staleHubProjection], fixtures.workCalendar.id: [fixtures.workEvent]
            ], failMutationNumber: 2)

        do {
            _ = try await reconciliationUseCase(store: store).apply(settings: fixtures.settings, now: fixtures.now)
        } catch let error as CalendarMutationExecutionError {
            guard case .partial(let partial) = error else {
                throw ContractTestFailure("Expected partial mutation result")
            }
            try expect(
                partial.confirmedCounts == [
                    CalendarRoleMutationCounts(role: .hub, confirmedDeletes: 1, confirmedCreates: 0)
                ], "Partial result should disclose only confirmed role counts")
            try expect(partial.failedRole == .hub, "Partial result should identify the failed role")
            try expect(partial.failureCategory == .createFailed, "Partial result should identify create failure")
            try expect(
                await store.deletedEvents() == [staleHubProjection.identity],
                "Confirmed deletion should remain applied without rollback")
            try expect((await store.createdEvents()).isEmpty, "Failed create should not be confirmed")
            try expect(
                await store.mutationAttempts() == [
                    .delete(CalendarEventReference(providerIdentifier: "hub-stale-1")),
                    .create(PhysicalCalendarReference(providerIdentifier: "hub-1"))
                ], "No later action should run after failure")
            return
        }

        throw ContractTestFailure("Expected ordinary apply failure")
    }

    private static func testDoesNotReprojectManagedWorkProjectionsToHub() async throws {
        let fixtures = applicationFixtures()
        let managedWorkProjection = calendarEvent(
            id: "work-projection-1", calendar: fixtures.workReference, title: "[ME] Dentist",
            start: Date(timeIntervalSince1970: 13_000), end: Date(timeIntervalSince1970: 14_000))
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.hubCalendar.id: [], fixtures.workCalendar.id: [managedWorkProjection]])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(
            !plan.creates.contains {
                $0.destinationCalendar == fixtures.hubReference && $0.title == "[ACME] [ME] Dentist"
            }, "Managed work projections should not be projected back into the hub")
        try expect(
            plan.deletes == [managedWorkProjection],
            "Stale managed work projection should still be deleted when no longer expected")
    }

    private static func testProjectsMalformedBracketedWorkEventAsOrdinarySource() async throws {
        let fixtures = applicationFixtures()
        let malformedWorkEvent = calendarEvent(
            id: "work-source-1", calendar: fixtures.workReference, title: "[ME]Dentist",
            start: Date(timeIntervalSince1970: 13_000), end: Date(timeIntervalSince1970: 14_000))
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.hubCalendar.id: [], fixtures.workCalendar.id: [malformedWorkEvent]])

        let plan = try await reconciliationUseCase(store: store).dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(
            plan.creates.contains {
                $0.destinationCalendar == fixtures.hubReference && $0.title == "[ACME] [ME]Dentist"
            }, "A malformed bracketed work title should remain an ordinary work-to-hub source")
        try expect(!plan.deletes.contains(malformedWorkEvent), "A malformed bracketed work title should not be managed")
    }

    private static func testProjectsWorkSourceToOtherWorkCalendarsInSamePlan() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let acmeCalendar = RelayCalendar(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let betaCalendar = RelayCalendar(id: "beta-1", title: "BETA Work", sourceTitle: "Google", isWritable: true)
        let acmeReference = CalendarIdentity(
            id: acmeCalendar.id, title: acmeCalendar.title, sourceTitle: acmeCalendar.sourceTitle)
        let betaReference = CalendarIdentity(
            id: betaCalendar.id, title: betaCalendar.title, sourceTitle: betaCalendar.sourceTitle)
        let sourceEvent = calendarEvent(
            id: "acme-source-1", calendar: acmeReference, title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000), end: Date(timeIntervalSince1970: 12_000))
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hubCalendar.sourceTitle, calendarTitle: hubCalendar.title)),
            personalPrefix: "[ME]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: acmeCalendar.sourceTitle, calendarTitle: acmeCalendar.title)
                ),
                WorkCalendarSettings(
                    name: "BETA", prefix: "[BETA]",
                    calendar: CalendarSelector(sourceTitle: betaCalendar.sourceTitle, calendarTitle: betaCalendar.title)
                )
            ])
        let store = FakeCalendarStore(
            calendars: [hubCalendar, acmeCalendar, betaCalendar], eventsByCalendarID: [acmeCalendar.id: [sourceEvent]])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.dryRun(settings: settings, now: now)

        try expect(
            plan.creates.contains { $0.destinationCalendar == betaReference && $0.title == "[ACME] Client Planning" },
            "Work source events should project to other work calendars through the expected hub projection in the same plan"
        )
    }

    private static func testDoesNotDoublePrefixRelayedWorkBlockers() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let hubCalendar = RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
        let acmeCalendar = RelayCalendar(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let betaCalendar = RelayCalendar(id: "beta-1", title: "BETA Work", sourceTitle: "Google", isWritable: true)
        let acmeReference = CalendarIdentity(
            id: acmeCalendar.id, title: acmeCalendar.title, sourceTitle: acmeCalendar.sourceTitle)
        let betaReference = CalendarIdentity(
            id: betaCalendar.id, title: betaCalendar.title, sourceTitle: betaCalendar.sourceTitle)
        let sourceEvent = calendarEvent(
            id: "acme-source-1", calendar: acmeReference, title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000), end: Date(timeIntervalSince1970: 12_000))
        let relayedWorkBlocker = calendarEvent(
            id: "beta-relayed-1", calendar: betaReference, title: "[ACME] Client Planning", start: sourceEvent.start,
            end: sourceEvent.end)
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hubCalendar.sourceTitle, calendarTitle: hubCalendar.title)),
            personalPrefix: "[ME]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: acmeCalendar.sourceTitle, calendarTitle: acmeCalendar.title)
                ),
                WorkCalendarSettings(
                    name: "BETA", prefix: "[BETA]",
                    calendar: CalendarSelector(sourceTitle: betaCalendar.sourceTitle, calendarTitle: betaCalendar.title)
                )
            ])
        let store = FakeCalendarStore(
            calendars: [hubCalendar, acmeCalendar, betaCalendar],
            eventsByCalendarID: [acmeCalendar.id: [sourceEvent], betaCalendar.id: [relayedWorkBlocker]])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.dryRun(settings: settings, now: now)

        try expect(
            !plan.creates.contains {
                $0.destinationCalendar.id == hubCalendar.id && $0.title == "[BETA] [ACME] Client Planning"
            }, "Relayed work blockers must not be treated as new source events and double-prefixed back into the hub")
        try expect(
            plan.creates.contains {
                $0.destinationCalendar.id == hubCalendar.id && $0.title == "[ACME] Client Planning"
            }, "Original work source should still project to the hub")
    }

    private static func testDeletesUnknownPrefixedWorkBlockersWhenAbsentFromHub() async throws {
        let fixtures = applicationFixtures()
        let remoteWorkProjection = calendarEvent(
            id: "remote-work-projection-1", calendar: fixtures.workReference, title: "[REMOTE] Partner Planning",
            start: Date(timeIntervalSince1970: 13_000), end: Date(timeIntervalSince1970: 14_000))
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.hubCalendar.id: [], fixtures.workCalendar.id: [remoteWorkProjection]])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(
            !plan.creates.contains {
                $0.destinationCalendar == fixtures.hubReference && $0.title == "[ACME] [REMOTE] Partner Planning"
            }, "Unknown prefixed work blockers should not be double-prefixed back into the hub")
        try expect(
            plan.deletes == [remoteWorkProjection],
            "Unknown prefixed work blockers should be deleted from work calendars when absent from the hub")
    }

    private static func testPreservesUnknownPrefixedHubEvents() async throws {
        let fixtures = applicationFixtures()
        let remoteHubProjection = calendarEvent(
            id: "remote-hub-projection-1", calendar: fixtures.hubReference, title: "[REMOTE] Partner Planning",
            start: Date(timeIntervalSince1970: 13_000), end: Date(timeIntervalSince1970: 14_000))
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.hubCalendar.id: [remoteHubProjection], fixtures.workCalendar.id: []])
        let useCase = reconciliationUseCase(store: store)

        let plan = try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(!plan.deletes.contains(remoteHubProjection), "Unknown prefixed hub events should still be preserved")
    }

    private static func testStaleLocalHubProjectionDoesNotRouteForExtraCycle() async throws {
        let fixtures = applicationFixtures()
        let staleHubProjection = calendarEvent(
            id: "stale-personal-hub-1", calendar: fixtures.hubReference, title: "[ME] Dentist",
            start: Date(timeIntervalSince1970: 13_000), end: Date(timeIntervalSince1970: 14_000))
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [fixtures.hubCalendar.id: [staleHubProjection], fixtures.workCalendar.id: []])

        let plan = try await reconciliationUseCase(store: store).dryRun(settings: fixtures.settings, now: fixtures.now)

        try expect(plan.deletes.contains(staleHubProjection), "The stale local hub projection should be deleted")
        try expect(
            !plan.creates.contains {
                $0.destinationCalendar == fixtures.workReference && $0.title == staleHubProjection.title
            }, "A stale local hub projection should not route to work calendars for an extra cycle")
    }

    private static func testReconciliationPropagatesCancellation() async throws {
        let fixtures = applicationFixtures()
        let store = FakeCalendarStore(calendars: [fixtures.hubCalendar, fixtures.workCalendar])
        let useCase = reconciliationUseCase(store: store)

        let task = Task { try await useCase.dryRun(settings: fixtures.settings, now: fixtures.now) }
        task.cancel()

        do { _ = try await task.value } catch is CancellationError { return } catch {
            throw ContractTestFailure("Expected CancellationError, got \(error)")
        }

        throw ContractTestFailure("Expected reconciliation cancellation to propagate")
    }

    private static func testFormatsEmptyReconciliationPlan() throws {
        let output = ReconciliationPlanFormatter.format(ReconciliationPlan(creates: [], deletes: []))

        try expect(output.contains("No changes planned."), "Empty plans should produce understandable output")
    }

    private static func testFormatsPlannedCreatesAndDeletes() throws {
        let create = calendarEventProjection(
            destinationCalendar: CalendarIdentity(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[ACME] Client Planning", start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000))
        let delete = calendarEvent(
            id: "stale-1", calendar: CalendarIdentity(id: "acme-1", title: "ACME Work", sourceTitle: "Google"),
            title: "[ME] Dentist", start: Date(timeIntervalSince1970: 3_000), end: Date(timeIntervalSince1970: 4_000))

        let output = ReconciliationPlanFormatter.format(ReconciliationPlan(creates: [create], deletes: [delete]))

        try expect(output.contains("Creates (1)"), "Output should summarize create count")
        try expect(output.contains("Deletes (1)"), "Output should summarize delete count")
        try expect(output.contains("iCloud / Personal Work"), "Create output should include destination selector")
        try expect(output.contains("Google / ACME Work"), "Delete output should include event calendar selector")
        try expect(output.contains("[ACME] Client Planning"), "Create output should include title")
        try expect(output.contains("[ME] Dentist"), "Delete output should include title")
        try expect(
            output.contains("1970-01-01 00:16:40 +0000 → 1970-01-01 00:33:20 +0000"),
            "Output should include create time range")
        try expect(
            output.contains("1970-01-01 00:50:00 +0000 → 1970-01-01 01:06:40 +0000"),
            "Output should include delete time range")
    }

    private static func testReconciliationPlanOutputAvoidsDebugDumps() throws {
        let output = ReconciliationPlanFormatter.format(
            ReconciliationPlan(creates: [calendarEventProjection(title: "[ACME] Client Planning")], deletes: []))

        try expect(!output.contains("CalendarEventProjection("), "Output should not expose Swift debug dumps")
        try expect(!output.contains("CalendarIdentity("), "Output should not expose Swift type internals")
    }

    private static func testExplainReportsIncludedAndExcludedEvents() async throws {
        let fixtures = applicationFixtures()
        let excludedWorkEvent = calendarEvent(
            id: "acme-excluded-1", calendar: fixtures.workReference, title: "AI QA Learning path sync",
            start: Date(timeIntervalSince1970: 15_000), end: Date(timeIntervalSince1970: 16_000), availability: .free,
            status: .confirmed)
        let acceptedWorkEvent = calendarEvent(
            id: "acme-accepted-1", calendar: fixtures.workReference, title: "Accepted Invitation",
            start: Date(timeIntervalSince1970: 17_000), end: Date(timeIntervalSince1970: 18_000), availability: .free,
            currentUserParticipantStatus: .accepted)
        let tentativeWorkEvent = calendarEvent(
            id: "acme-tentative-1", calendar: fixtures.workReference, title: "Tentative Invitation",
            start: Date(timeIntervalSince1970: 19_000), end: Date(timeIntervalSince1970: 20_000), availability: .busy,
            currentUserParticipantStatus: .tentative)
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [],
                fixtures.workCalendar.id: [fixtures.workEvent, excludedWorkEvent, acceptedWorkEvent, tentativeWorkEvent]
            ])
        let useCase = reconciliationUseCase(store: store)

        let explanation = try await useCase.explain(settings: fixtures.settings, now: fixtures.now)

        try expect(
            explanation.candidates.contains {
                $0.event.title == fixtures.workEvent.title && $0.eligibility == .noCurrentUserAttendeeIncluded(.busy)
            }, "Explain should report included events with the included reason")
        try expect(
            explanation.candidates.contains {
                $0.event.title == "AI QA Learning path sync" && $0.eligibility == .noCurrentUserAttendeeExcluded(.free)
            }, "Explain should report excluded events with their exclusion reason")
        try expect(
            explanation.candidates.contains {
                $0.event.identity == acceptedWorkEvent.identity && $0.eligibility == .currentUserAccepted
            }, "Explain should report accepted current-user attendee eligibility")
        try expect(
            explanation.candidates.contains {
                $0.event.identity == tentativeWorkEvent.identity
                    && $0.eligibility == .currentUserNonAccepted(.tentative)
            }, "Explain should report non-accepted current-user attendee eligibility")
        try expect((await store.createdEvents()).isEmpty, "Explain should never mutate the calendar store")
        try expect((await store.deletedEvents()).isEmpty, "Explain should never mutate the calendar store")
    }

    private static func testExplanationClassifiesEveryInputDimensionAndReportsWindow() async throws {
        let fixture = explanationClassificationFixture()
        let explanation = try await ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: fixture.store,
            calendar: utcCalendar()
        ).explain(settings: fixture.base.settings, now: fixture.base.now)

        let expectedWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.base.now, calendar: utcCalendar(),
            syncWindowDays: fixture.base.settings.syncWindowDays)
        try expect(explanation.window == expectedWindow, "Explanation should report the shared effective window")
        try expect(
            explanation.syncWindowDays == fixture.base.settings.syncWindowDays,
            "Explanation should report the configured forward horizon")
        try expectCandidateClassifications(fixture, explanation: explanation)
        try expectActionReasons(fixture, explanation: explanation)
    }

    private static func testExplanationUsesSharedOrderedActionsAndCreateCausality() async throws {
        let fixtures = applicationFixtures()
        let staleHubProjection = calendarEvent(
            id: "hub-stale-1", calendar: fixtures.hubReference, title: "[ACME] Old Planning",
            start: fixtures.workEvent.start, end: fixtures.workEvent.end)
        let duplicateCausalWorkEvent = calendarEvent(
            id: "acme-source-2", calendar: fixtures.workReference, title: fixtures.workEvent.title,
            start: fixtures.workEvent.start, end: fixtures.workEvent.end)
        let store = FakeCalendarStore(
            calendars: [fixtures.hubCalendar, fixtures.workCalendar],
            eventsByCalendarID: [
                fixtures.hubCalendar.id: [staleHubProjection],
                fixtures.workCalendar.id: [fixtures.workEvent, duplicateCausalWorkEvent]
            ])
        let useCase = reconciliationUseCase(store: store)

        let dryRun = try await useCase.dryRunResult(settings: fixtures.settings, now: fixtures.now)
        let explanation = try await useCase.explain(settings: fixtures.settings, now: fixtures.now)

        try expect(
            explanation.actions.map(\.action) == dryRun.actions,
            "Explanation should use the shared ordered executable actions")
        guard
            let create = explanation.actions.first(where: {
                $0.action == .create(role: .hub, event: fixtures.expectedHubProjection)
            })
        else { throw ContractTestFailure("Expected explained hub create") }
        try expect(
            create.reason == .missingExpectedProjection,
            "A planned create should identify the missing expected projection reason")
        try expect(
            create.causalEvents == [fixtures.workEvent.identity, duplicateCausalWorkEvent.identity],
            "A planned create should retain every causal source event identity")
        guard
            let deletion = explanation.actions.first(where: {
                $0.action == .delete(role: .hub, event: staleHubProjection)
            })
        else { throw ContractTestFailure("Expected explained hub delete") }
        try expect(
            deletion.causalEvents == [staleHubProjection.identity],
            "A planned delete should retain its exact input occurrence identity")
        try expect((await store.createdEvents()).isEmpty, "Explain should not create events")
        try expect((await store.deletedEvents()).isEmpty, "Explain should not delete events")
    }

    private static func testFormatsEventExplanations() throws {
        let calendar = CalendarIdentity(id: "acme-1", title: "ACME Work", sourceTitle: "Google")
        let output = EventExplanationFormatter.format(
            ReconciliationExplanation(
                window: explanationWindow(), syncWindowDays: 10,
                candidates: [
                    CandidateEventExplanation(
                        event: calendarEvent(
                            calendar: calendar, title: "Client Planning", start: Date(timeIntervalSince1970: 1_000),
                            end: Date(timeIntervalSince1970: 2_000), availability: .busy, status: .confirmed),
                        eligibility: .noCurrentUserAttendeeIncluded(.busy), routing: .workToHubSource,
                        expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal),
                    CandidateEventExplanation(
                        event: calendarEvent(
                            calendar: calendar, title: "AI QA Learning path sync",
                            start: Date(timeIntervalSince1970: 3_000), end: Date(timeIntervalSince1970: 4_000),
                            availability: .free, status: .confirmed),
                        eligibility: .noCurrentUserAttendeeExcluded(.free), routing: .workToHubSource,
                        expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal)
                ]))

        try expect(output.contains("Google / ACME Work"), "Explanation output should include calendar selector")
        try expect(output.contains("Client Planning"), "Explanation output should include event title")
        try expect(
            output.contains("included (no current-user attendee; availability: busy)"),
            "Explanation output should show the no-attendee inclusion reason")
        try expect(
            output.contains("AI QA Learning path sync"), "Explanation output should include excluded event title")
        try expect(
            output.contains("excluded (no current-user attendee; availability: free)"),
            "Explanation output should explain the exclusion reason")
        try expect(!output.contains("EventExplanation("), "Explanation output should not expose Swift debug dumps")
    }

    private static func testFormatsEmptyEventExplanations() throws {
        let output = EventExplanationFormatter.format(
            ReconciliationExplanation(window: explanationWindow(), syncWindowDays: 10, candidates: []))

        try expect(
            output.contains("No candidate events found in the sync window."),
            "Empty explanations should produce understandable output")
    }

    private static func testFormatsCalendarList() throws {
        let output = CalendarListFormatter.format([
            RelayCalendar(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true),
            RelayCalendar(id: "readonly-1", title: "Shared Holidays", sourceTitle: "Subscribed", isWritable: false)
        ])

        try expect(output.contains("Calendars (2)"), "Calendar output should summarize count")
        try expect(output.contains("iCloud / Personal Work"), "Calendar output should include source/title selector")
        try expect(output.contains("id: hub-1"), "Calendar output should include IDs for troubleshooting")
        try expect(output.contains("writable"), "Calendar output should show writable state")
        try expect(output.contains("read-only"), "Calendar output should show read-only state")
        try expect(!output.contains("RelayCalendar("), "Calendar output should not expose Swift debug dumps")
    }

    private static func validSettings(
        hubCalendar: HubCalendarSettings = HubCalendarSettings(
            calendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Personal Work")),
        personalPrefix: String = "[ME]", syncWindowDays: Int = 60,
        workCalendars: [WorkCalendarSettings] = [
            WorkCalendarSettings(
                name: "ACME", prefix: "[ACME]",
                calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
        ]
    ) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: hubCalendar, personalPrefix: personalPrefix, syncWindowDays: syncWindowDays,
            workCalendars: workCalendars)
    }

    private static func calendarEvent(
        id: String = "event-1",
        calendar: CalendarIdentity = CalendarIdentity(id: "calendar-1", title: "ACME Work", sourceTitle: "Google"),
        title: String = "Client Planning", start: Date = Date(timeIntervalSince1970: 1_000),
        end: Date = Date(timeIntervalSince1970: 2_000), isAllDay: Bool = false, availability: EventAvailability = .busy,
        status: EventStatus = .confirmed, currentUserParticipantStatus: CurrentUserParticipantStatus? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, calendar: calendar, title: title, start: start, end: end, isAllDay: isAllDay,
            availability: availability, status: status, currentUserParticipantStatus: currentUserParticipantStatus)
    }

    private static func calendarEventProjection(
        destinationCalendar: CalendarIdentity = CalendarIdentity(
            id: "calendar-1", title: "ACME Work", sourceTitle: "Google"), title: String,
        start: Date = Date(timeIntervalSince1970: 1_000), end: Date = Date(timeIntervalSince1970: 2_000),
        isAllDay: Bool = false
    ) -> CalendarEventProjection {
        CalendarEventProjection(
            destinationCalendar: destinationCalendar, title: title, start: start, end: end, isAllDay: isAllDay)
    }

    private static func workCalendarSettings() -> WorkCalendarSettings {
        WorkCalendarSettings(
            name: "ACME", prefix: "[ACME]",
            calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
    }

    private static func workCalendarTargets() -> [WorkCalendarProjectionTarget] {
        [
            workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work"),
            workCalendarTarget(name: "BETA", prefix: "[BETA]", calendarID: "beta-1", calendarTitle: "BETA Work"),
            workCalendarTarget(
                name: "CONTOSO", prefix: "[CONTOSO]", calendarID: "contoso-1", calendarTitle: "CONTOSO Work")
        ]
    }

    private static func workCalendarTarget(name: String, prefix: String, calendarID: String, calendarTitle: String)
        -> WorkCalendarProjectionTarget
    {
        WorkCalendarProjectionTarget(
            settings: WorkCalendarSettings(
                name: name, prefix: prefix,
                calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: calendarTitle)),
            calendar: CalendarIdentity(id: calendarID, title: calendarTitle, sourceTitle: "Google"))
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
        let hubCalendar = RelayCalendar(
            id: "hub-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: hubIsWritable)
        let workCalendar = RelayCalendar(id: "acme-1", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        let hubReference = CalendarIdentity(
            id: hubCalendar.id, title: hubCalendar.title, sourceTitle: hubCalendar.sourceTitle)
        let workReference = CalendarIdentity(
            id: workCalendar.id, title: workCalendar.title, sourceTitle: workCalendar.sourceTitle)
        let workEvent = calendarEvent(
            id: "acme-source-1", calendar: workReference, title: "Client Planning",
            start: Date(timeIntervalSince1970: 11_000), end: Date(timeIntervalSince1970: 12_000))
        let settings = validSettings()
        let expectedHubProjection = CalendarEventProjection(
            destinationCalendar: hubReference, title: "[ACME] Client Planning", start: workEvent.start,
            end: workEvent.end, isAllDay: workEvent.isAllDay)

        return ApplicationFixtures(
            now: now, settings: settings, hubCalendar: hubCalendar, hubReference: hubReference,
            workCalendar: workCalendar, workReference: workReference, workEvent: workEvent,
            expectedHubProjection: expectedHubProjection)
    }

    private static func expectValidationError(
        _ expectedError: SettingsValidationError, for settings: CalendarRelaySettings
    ) throws {
        do { try SettingsValidator.validate(settings) } catch let error as SettingsValidationError {
            guard error == expectedError else { throw ContractTestFailure("Expected \(expectedError), got \(error)") }
            return
        } catch { throw ContractTestFailure("Expected SettingsValidationError, got \(error)") }

        throw ContractTestFailure("Expected validation error: \(expectedError)")
    }

    private static func expectInvalidConfiguration(_ yaml: String, prohibitedText: String) throws {
        do { _ = try YAMLCalendarRelaySettingsLoader.load(yaml) } catch let error as YAMLCalendarRelaySettingsError {
            try expect(
                error.description.contains("Invalid configuration"), "Strict YAML failure should remain actionable")
            try expect(
                !error.description.contains(prohibitedText), "Strict YAML failure must not echo sensitive values")
            return
        }
        throw ContractTestFailure("Expected strict YAML validation failure")
    }

    private static func reconciliationUseCase(store: FakeCalendarStore) -> ReconcileCalendarsUseCase {
        ReconcileCalendarsUseCase(authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store)
    }

    private static func explanationClassificationFixture() -> ExplanationClassificationFixture {
        let base = applicationFixtures()
        let reviewSource = calendarEvent(
            id: "acme-source-2", calendar: base.workReference, title: "Review",
            start: Date(timeIntervalSince1970: 15_000), end: Date(timeIntervalSince1970: 16_000))
        let retainedHubProjection = calendarEvent(
            id: "hub-retained", calendar: base.hubReference, title: base.expectedHubProjection.title,
            start: base.workEvent.start, end: base.workEvent.end)
        let cancelledHubProjection = calendarEvent(
            id: "hub-cancelled", calendar: base.hubReference, title: base.expectedHubProjection.title,
            start: base.workEvent.start, end: base.workEvent.end, status: .cancelled)
        let duplicateOne = calendarEvent(
            id: "hub-duplicate-1", calendar: base.hubReference, title: "[ACME] Review", start: reviewSource.start,
            end: reviewSource.end)
        let duplicateTwo = calendarEvent(
            id: "hub-duplicate-2", calendar: base.hubReference, title: "[ACME] Review", start: reviewSource.start,
            end: reviewSource.end)
        let personalHubSource = calendarEvent(
            id: "hub-personal", calendar: base.hubReference, title: "Dentist",
            start: Date(timeIntervalSince1970: 17_000), end: Date(timeIntervalSince1970: 18_000))
        let remoteHubSource = calendarEvent(
            id: "hub-remote", calendar: base.hubReference, title: "[REMOTE] Partner Planning",
            start: Date(timeIntervalSince1970: 19_000), end: Date(timeIntervalSince1970: 20_000), availability: .free)
        let cancelledRemoteHubSource = calendarEvent(
            id: "hub-remote-cancelled", calendar: base.hubReference, title: "[REMOTE] Cancelled",
            start: Date(timeIntervalSince1970: 21_000), end: Date(timeIntervalSince1970: 22_000), status: .cancelled)
        let invalidHubSource = calendarEvent(
            id: "hub-invalid", calendar: base.hubReference, title: "[ACME]Planning",
            start: Date(timeIntervalSince1970: 23_000), end: Date(timeIntervalSince1970: 24_000), availability: .free)
        let staleWorkProjection = calendarEvent(
            id: "work-stale", calendar: base.workReference, title: "[REMOTE] Stale",
            start: Date(timeIntervalSince1970: 25_000), end: Date(timeIntervalSince1970: 26_000))
        let store = FakeCalendarStore(
            calendars: [base.hubCalendar, base.workCalendar],
            eventsByCalendarID: [
                base.hubCalendar.id: [
                    retainedHubProjection, cancelledHubProjection, duplicateOne, duplicateTwo, personalHubSource,
                    remoteHubSource, cancelledRemoteHubSource, invalidHubSource
                ], base.workCalendar.id: [base.workEvent, reviewSource, staleWorkProjection]
            ])
        return ExplanationClassificationFixture(
            base: base, reviewSource: reviewSource, retainedHubProjection: retainedHubProjection,
            cancelledHubProjection: cancelledHubProjection, duplicateOne: duplicateOne, duplicateTwo: duplicateTwo,
            personalHubSource: personalHubSource, remoteHubSource: remoteHubSource,
            cancelledRemoteHubSource: cancelledRemoteHubSource, invalidHubSource: invalidHubSource,
            staleWorkProjection: staleWorkProjection, store: store)
    }

    private static func expectCandidateClassifications(
        _ fixture: ExplanationClassificationFixture, explanation: ReconciliationExplanation
    ) throws {
        let localMarker = CandidateClassificationExpectation(
            eligibility: .markedHubEligibilityBypass,
            routing: .exactLocalMarkerHubSource(role: .work(name: "ACME", declarationIndex: 0)),
            expectation: .matchesExpectedProjection, disposition: .retained)
        try expectCandidate(fixture.retainedHubProjection, in: explanation, expected: localMarker)
        try expectCandidate(
            fixture.cancelledHubProjection, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .reliableCancellation, routing: .cancelledMarkedHubPreservation,
                expectation: .matchesExpectedProjection, disposition: .selectedCancelledManagedDeletion))
        try expectCandidate(
            fixture.duplicateOne, in: explanation, expected: localMarker.withDisposition(.selectedDuplicateSetDeletion))
        try expectCandidate(
            fixture.duplicateTwo, in: explanation, expected: localMarker.withDisposition(.selectedDuplicateSetDeletion))
        try expectPreservedSourceClassifications(fixture, explanation: explanation)
    }

    private static func expectPreservedSourceClassifications(
        _ fixture: ExplanationClassificationFixture, explanation: ReconciliationExplanation
    ) throws {
        try expectCandidate(
            fixture.personalHubSource, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .noCurrentUserAttendeeIncluded(.busy), routing: .hubPersonalSource,
                expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal))
        try expectCandidate(
            fixture.remoteHubSource, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .markedHubEligibilityBypass, routing: .nonLocalValidMarkerHubSource,
                expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal))
        try expectCandidate(
            fixture.cancelledRemoteHubSource, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .reliableCancellation, routing: .cancelledMarkedHubPreservation,
                expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal))
        try expectCandidate(
            fixture.invalidHubSource, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .noCurrentUserAttendeeExcluded(.free), routing: .invalidOrUnmarkedHubSource,
                expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal))
        try expectCandidate(
            fixture.base.workEvent, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .noCurrentUserAttendeeIncluded(.busy), routing: .workToHubSource,
                expectation: .noMatchingExpectation, disposition: .preservedUnmanagedOrNonLocal))
        try expectCandidate(
            fixture.staleWorkProjection, in: explanation,
            expected: CandidateClassificationExpectation(
                eligibility: .noCurrentUserAttendeeIncluded(.busy), routing: .feedbackSuppressedMarkedWorkProjection,
                expectation: .noMatchingExpectation, disposition: .selectedStaleManagedDeletion))
    }

    private static func expectActionReasons(
        _ fixture: ExplanationClassificationFixture, explanation: ReconciliationExplanation
    ) throws {
        try expectActionReason(
            .cancelledManagedProjection, forDeletedEvent: fixture.cancelledHubProjection, in: explanation)
        try expectActionReason(.replaceAllManagedDuplicate, forDeletedEvent: fixture.duplicateOne, in: explanation)
        try expectActionReason(.replaceAllManagedDuplicate, forDeletedEvent: fixture.duplicateTwo, in: explanation)
        try expectActionReason(.staleManagedProjection, forDeletedEvent: fixture.staleWorkProjection, in: explanation)
        try expect(
            explanation.actions.contains { $0.reason == .missingExpectedProjection },
            "Explanation should classify planned missing-projection creates")
    }

    private static func expectCandidate(
        _ event: CalendarEvent, in explanation: ReconciliationExplanation, expected: CandidateClassificationExpectation
    ) throws {
        guard let candidate = explanation.candidates.first(where: { $0.event.identity == event.identity }) else {
            throw ContractTestFailure("Missing candidate explanation for \(event.title)")
        }
        try expect(candidate.eligibility == expected.eligibility, "Unexpected eligibility for \(event.title)")
        try expect(candidate.routing == expected.routing, "Unexpected routing treatment for \(event.title)")
        try expect(candidate.expectation == expected.expectation, "Unexpected expectation match for \(event.title)")
        try expect(candidate.disposition == expected.disposition, "Unexpected disposition for \(event.title)")
    }

    private static func expectActionReason(
        _ reason: PlannedActionExplanationReason, forDeletedEvent event: CalendarEvent,
        in explanation: ReconciliationExplanation
    ) throws {
        try expect(
            explanation.actions.contains { explainedAction in
                guard case .delete(_, let deletedEvent) = explainedAction.action else { return false }
                return deletedEvent.identity == event.identity && explainedAction.reason == reason
            }, "Missing \(reason) explanation for \(event.title)")
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func explanationWindow() -> CalendarAccessWindow {
        CalendarAccessWindow(start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 100_000))
    }

    private static func expectReconciliationError(
        _ expectedError: ReconcileCalendarsError, from operation: () async throws -> ReconciliationPlan
    ) async throws {
        do { _ = try await operation() } catch let error as ReconcileCalendarsError {
            guard error == expectedError else { throw ContractTestFailure("Expected \(expectedError), got \(error)") }
            return
        } catch { throw ContractTestFailure("Expected ReconcileCalendarsError, got \(error)") }

        throw ContractTestFailure("Expected reconciliation error: \(expectedError)")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ContractTestFailure(message) }
    }
}

private struct ApplicationFixtures {
    let now: Date
    let settings: CalendarRelaySettings
    let hubCalendar: RelayCalendar
    let hubReference: CalendarIdentity
    let workCalendar: RelayCalendar
    let workReference: CalendarIdentity
    let workEvent: CalendarEvent
    let expectedHubProjection: CalendarEventProjection
}

private struct ExplanationClassificationFixture {
    let base: ApplicationFixtures
    let reviewSource: CalendarEvent
    let retainedHubProjection: CalendarEvent
    let cancelledHubProjection: CalendarEvent
    let duplicateOne: CalendarEvent
    let duplicateTwo: CalendarEvent
    let personalHubSource: CalendarEvent
    let remoteHubSource: CalendarEvent
    let cancelledRemoteHubSource: CalendarEvent
    let invalidHubSource: CalendarEvent
    let staleWorkProjection: CalendarEvent
    let store: FakeCalendarStore
}

private struct CandidateClassificationExpectation {
    let eligibility: CandidateEventEligibilityExplanation
    let routing: CandidateEventRoutingExplanation
    let expectation: CandidateEventExpectationExplanation
    let disposition: CandidateEventDispositionExplanation

    func withDisposition(_ disposition: CandidateEventDispositionExplanation) -> Self {
        Self(eligibility: eligibility, routing: routing, expectation: expectation, disposition: disposition)
    }
}

private actor FakeCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]
    private let failMutationNumber: Int?
    private var recordedCreates: [CalendarEventProjection] = []
    private var recordedDeletes: [CalendarEventIdentity] = []
    private var recordedEventRequests: [(start: Date, end: Date)] = []
    private var recordedMutationAttempts: [FakeMutationAttempt] = []

    init(
        calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]] = [:],
        failMutationNumber: Int? = nil
    ) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
        self.failMutationNumber = failMutationNumber
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        recordedEventRequests.append((start: start, end: end))
        return eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        recordedMutationAttempts.append(.create(event.destinationCalendar.id))
        if failMutationNumber == recordedMutationAttempts.count { throw FakeMutationFailure() }
        recordedCreates.append(event)
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        recordedMutationAttempts.append(.delete(event.id))
        if failMutationNumber == recordedMutationAttempts.count { throw FakeMutationFailure() }
        recordedDeletes.append(event)
    }

    func createdEvents() -> [CalendarEventProjection] { recordedCreates }

    func deletedEvents() -> [CalendarEventIdentity] { recordedDeletes }

    func eventRequests() -> [(start: Date, end: Date)] { recordedEventRequests }

    func mutationAttempts() -> [FakeMutationAttempt] { recordedMutationAttempts }
}

private enum FakeMutationAttempt: Equatable {
    case delete(CalendarEventReference)
    case create(PhysicalCalendarReference)
}

private struct FakeMutationFailure: Error {}

private struct ContractTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}
