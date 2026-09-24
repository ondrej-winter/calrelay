import CalRelayKit
import Foundation

enum CalendarAutomaticReconciliationTests {
    static func runAll() async throws {
        try await testFreshAuthorizedAttemptAppliesAndPersistsAggregateSuccess()
        try await testAutomaticAndRetryAttemptsNeverRequestCalendarAccess()
        try await testAutomaticPreflightFailuresPreventAllMutations()
        try await testConfigurationAndMigrationFailuresStopBeforeCalendarAccess()
        try await testMissingStandingAuthorizationPerformsNoMutation()
        try await testReadyEmptyPlanUpdatesSuccessWithoutMutation()
        try await testLegacyPolicyAuthorizationIsRevokedWithoutMutation()
        try await testPreMutationConfigurationTransitionsFailClosed()
        try await testObservedAtoBtoATransitionBeforeMutationRevokesAuthorization()
        try await testAuthorizationRevocationBeforeMutationPreservesMatchingGrant()
        try await testAuthorizationRevocationBetweenAttemptsDoesNotRequestAgain()
        try await testPartialMutationPersistsOnlyAggregateConfirmedCounts()
        try await testDisabledSchedulingFailsClosedEvenWithStandingAuthorization()
        try await testTransientReadFailureSchedulesBoundedFreshRetry()
        try await testRetryReloadsFreshConfigurationSnapshotAndPlan()
        try await testLargeValidPlanAppliesWithoutHeuristicLimit()
        try await testConcurrentRevocationDuringMutationCannotBeResurrected()
    }

    private static func testFreshAuthorizedAttemptAppliesAndPersistsAggregateSuccess() async throws {
        let fixture = AutomaticReconciliationFixture()
        let provider = CountingAutomaticSettingsProvider(settings: fixture.settings)
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = fixture.storeWithSourceEvent()
        let useCase = fixture.useCase(settingsProvider: provider, calendarStore: store, stateStore: stateStore)

        let result = try await useCase.run()

        try expect(result.outcome == .applied, "An authorized mutating attempt should report applied")
        try expect(
            result.confirmedCounts == CalendarAutomationMutationCounts(confirmedCreates: 1, confirmedDeletes: 0),
            "Automatic success should disclose only aggregate confirmed counts")
        try expect(await store.mutationCount() == 1, "The fresh authorized plan should be applied once")
        try expect(await provider.callCount() == 2, "An automatic attempt should load and recheck current settings")
        try expect(await store.listCalendarsCallCount() == 1, "Automatic preflight should load one fresh inventory")
        try expect(
            await store.eventRequestCalendarIDs() == [fixture.hub.id, fixture.work.id],
            "Automatic preflight should read hub first, then work calendars, without a verification reread")
        let persisted = await stateStore.currentState()
        try expect(persisted.operationalStatus.latestOutcome == .applied, "Applied outcome should persist")
        try expect(
            persisted.operationalStatus.freshness.lastSuccessAt == fixture.now, "Success should update freshness")
    }

    private static func testMissingStandingAuthorizationPerformsNoMutation() async throws {
        let fixture = AutomaticReconciliationFixture()
        let stateStore = AutomaticStateStore(
            state: CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: nil, operationalStatus: .empty))
        let store = fixture.storeWithSourceEvent()
        let useCase = fixture.useCase(calendarStore: store, stateStore: stateStore)

        let result = try await useCase.run()

        try expect(
            result.outcome == .standingAuthorizationRequired,
            "An attempt without standing authorization should fail closed")
        try expect(await store.mutationCount() == 0, "Missing standing authorization must prevent every mutation")
    }

    private static func testReadyEmptyPlanUpdatesSuccessWithoutMutation() async throws {
        let fixture = AutomaticReconciliationFixture()
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = AutomaticCalendarStore(calendars: [fixture.hub, fixture.work], eventsByCalendarID: [:])

        let result = try await fixture.useCase(calendarStore: store, stateStore: stateStore).run()

        try expect(result.outcome == .noChanges, "A ready empty plan should be a successful automatic attempt")
        try expect(result.confirmedCounts == .zero, "Empty success should retain zero aggregate counts")
        try expect(await store.mutationCount() == 0, "An empty plan should not call mutation adapters")
        try expect(
            (await stateStore.currentState()).operationalStatus.freshness.lastSuccessAt == fixture.now,
            "Empty success should update last-success freshness")
    }

    // ACCESS-AC-01: automatic and retry attempts inspect authorization without requesting.
    private static func testAutomaticAndRetryAttemptsNeverRequestCalendarAccess() async throws {
        let fixture = AutomaticReconciliationFixture()

        for kind in [CalendarAutomaticAttemptKind.ordinary, .retry] {
            for state in CalendarAuthorizationState.allCases {
                let authorization = RequestCapableAutomaticAuthorization(state: state)
                let stateStore = AutomaticStateStore(state: fixture.authorizedState())
                let store = fixture.storeWithSourceEvent()

                let result = try await fixture.useCase(
                    authorization: authorization, calendarStore: store, stateStore: stateStore
                ).run(kind: kind)

                let expectedOutcome: CalendarAutomationOutcomeCategory =
                    state == .fullAccess ? .applied : .calendarAccessUnavailable
                try expect(
                    result.outcome == expectedOutcome,
                    "Automatic \(kind) should handle \(state) without requesting access")
                try expect(
                    await authorization.requestCount() == 0,
                    "Automatic \(kind) must never request Calendar access for \(state)")
                if state != .fullAccess {
                    try expect(
                        await store.mutationCount() == 0,
                        "Automatic \(kind) must not mutate when Calendar access is unavailable")
                }
            }
        }
    }

    private static func testAutomaticPreflightFailuresPreventAllMutations() async throws {
        let fixture = AutomaticReconciliationFixture()
        let duplicateWork = RelayCalendar(
            id: "work-duplicate", title: fixture.work.title, sourceTitle: fixture.work.sourceTitle, isWritable: true)
        let collisionHub = RelayCalendar(
            id: "shared", title: fixture.hub.title, sourceTitle: fixture.hub.sourceTitle, isWritable: true)
        let collisionWork = RelayCalendar(
            id: "shared", title: fixture.work.title, sourceTitle: fixture.work.sourceTitle, isWritable: true)
        let readOnlyWork = RelayCalendar(
            id: fixture.work.id, title: fixture.work.title, sourceTitle: fixture.work.sourceTitle, isWritable: false)
        let scenarios: [AutomaticPreflightFailureScenario] = [
            AutomaticPreflightFailureScenario(
                name: "missing", store: AutomaticCalendarStore(calendars: [fixture.hub], eventsByCalendarID: [:]),
                expectedOutcome: .topologyNotReady, expectedReads: [fixture.hub.id]),
            AutomaticPreflightFailureScenario(
                name: "ambiguous",
                store: AutomaticCalendarStore(
                    calendars: [fixture.hub, fixture.work, duplicateWork], eventsByCalendarID: [:]),
                expectedOutcome: .topologyNotReady, expectedReads: [fixture.hub.id]),
            AutomaticPreflightFailureScenario(
                name: "colliding",
                store: AutomaticCalendarStore(calendars: [collisionHub, collisionWork], eventsByCalendarID: [:]),
                expectedOutcome: .topologyNotReady, expectedReads: [collisionHub.id, collisionWork.id]),
            AutomaticPreflightFailureScenario(
                name: "read-only",
                store: AutomaticCalendarStore(calendars: [fixture.hub, readOnlyWork], eventsByCalendarID: [:]),
                expectedOutcome: .topologyNotReady, expectedReads: [fixture.hub.id, fixture.work.id]),
            AutomaticPreflightFailureScenario(
                name: "unreadable",
                store: AutomaticCalendarStore(
                    calendars: [fixture.hub, fixture.work], eventsByCalendarID: [:],
                    readFailureCalendarIDs: [fixture.work.id]), expectedOutcome: .transientFailure,
                expectedReads: [fixture.hub.id, fixture.work.id])
        ]

        for scenario in scenarios {
            let result = try await fixture.useCase(
                calendarStore: scenario.store, stateStore: AutomaticStateStore(state: fixture.authorizedState())
            ).run()

            try expect(
                result.outcome == scenario.expectedOutcome,
                "Automatic preflight should categorize the \(scenario.name) case")
            try expect(
                await scenario.store.mutationCount() == 0,
                "The \(scenario.name) preflight failure must prevent all mutation")
            try expect(
                await scenario.store.eventRequestCalendarIDs() == scenario.expectedReads,
                "The \(scenario.name) preflight should read every safely resolvable role in topology order")
        }
    }

    private static func testConfigurationAndMigrationFailuresStopBeforeCalendarAccess() async throws {
        let fixture = AutomaticReconciliationFixture()
        let cases: [AutomaticConfigurationFailureScenario] = [
            AutomaticConfigurationFailureScenario(
                name: "missing",
                provider: FailingAutomaticSettingsProvider(
                    error: .missing(displayPath: "~/.config/calrelay/config.yaml")),
                expectedOutcome: .configurationUnavailable),
            AutomaticConfigurationFailureScenario(
                name: "invalid",
                provider: AutomaticSettingsProvider(
                    settings: CalendarRelaySettings(
                        hubCalendar: fixture.settings.hubCalendar, personalPrefix: fixture.settings.personalPrefix,
                        syncWindowDays: fixture.settings.syncWindowDays, workCalendars: [], legacyMarkers: [])),
                expectedOutcome: .configurationUnavailable),
            AutomaticConfigurationFailureScenario(
                name: "migration pending",
                provider: AutomaticSettingsProvider(
                    settings: CalendarRelaySettings(
                        hubCalendar: fixture.settings.hubCalendar, personalPrefix: fixture.settings.personalPrefix,
                        syncWindowDays: fixture.settings.syncWindowDays, workCalendars: fixture.settings.workCalendars,
                        legacyMarkers: ["[OLD]"])), expectedOutcome: .migrationPending)
        ]

        for scenario in cases {
            let store = fixture.storeWithSourceEvent()
            let stateStore = AutomaticStateStore(state: fixture.authorizedState())
            let result = try await fixture.useCase(
                settingsProvider: scenario.provider, calendarStore: store, stateStore: stateStore
            ).run()

            try expect(
                result.outcome == scenario.expectedOutcome, "Automatic attempt should report \(scenario.name) safely")
            try expect(
                (await stateStore.currentState()).operationalStatus.latestOutcome == scenario.expectedOutcome,
                "Automatic scheduling should persist the \(scenario.name) gate outcome")
            try expect(
                await store.listCalendarsCallCount() == 0,
                "The \(scenario.name) configuration gate should fail before Calendar inventory")
            try expect(
                await store.mutationCount() == 0, "The \(scenario.name) configuration gate must prevent mutation")
        }
    }

    private static func testLegacyPolicyAuthorizationIsRevokedWithoutMutation() async throws {
        let fixture = AutomaticReconciliationFixture()
        let legacyPolicyBinding = CalendarStandingAuthorizationBinding.derive(
            settings: fixture.settings, resolvedCalendars: [fixture.hub.id, fixture.work.id],
            policyVersion: CalendarReconciliationPolicyVersion(rawValue: "ordinary-reconciliation-policy-v1"))
        let stateStore = AutomaticStateStore(
            state: CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: legacyPolicyBinding,
                operationalStatus: .empty))
        let store = fixture.storeWithSourceEvent()

        let result = try await fixture.useCase(calendarStore: store, stateStore: stateStore).run()

        try expect(
            result.outcome == .standingAuthorizationRequired,
            "A legacy-policy standing authorization should suspend automation")
        try expect(await store.mutationCount() == 0, "A legacy-policy authorization must prevent mutation")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "A legacy-policy authorization should be removed rather than silently reactivated")
    }

    private static func testPreMutationConfigurationTransitionsFailClosed() async throws {
        let fixture = AutomaticReconciliationFixture()
        let changedSettings = CalendarRelaySettings(
            hubCalendar: fixture.settings.hubCalendar, personalPrefix: "[CHANGED]",
            syncWindowDays: fixture.settings.syncWindowDays, workCalendars: fixture.settings.workCalendars,
            legacyMarkers: [])
        let migrationSettings = CalendarRelaySettings(
            hubCalendar: fixture.settings.hubCalendar, personalPrefix: fixture.settings.personalPrefix,
            syncWindowDays: fixture.settings.syncWindowDays, workCalendars: fixture.settings.workCalendars,
            legacyMarkers: ["[OLD]"])
        let scenarios: [AutomaticPreMutationConfigScenario] = [
            AutomaticPreMutationConfigScenario(
                name: "changed", finalLoad: .success(changedSettings), expectedOutcome: .standingAuthorizationRequired),
            AutomaticPreMutationConfigScenario(
                name: "missing", finalLoad: .failure(.missing(displayPath: "test")),
                expectedOutcome: .configurationUnavailable),
            AutomaticPreMutationConfigScenario(
                name: "invalid", finalLoad: .failure(.invalid(displayPath: "test")),
                expectedOutcome: .configurationUnavailable),
            AutomaticPreMutationConfigScenario(
                name: "migration pending", finalLoad: .success(migrationSettings), expectedOutcome: .migrationPending)
        ]

        for scenario in scenarios {
            let provider = ScriptedAutomaticSettingsProvider(loads: [.success(fixture.settings), scenario.finalLoad])
            let stateStore = AutomaticStateStore(state: fixture.authorizedState())
            let store = fixture.storeWithSourceEvent()

            let result = try await fixture.useCase(
                settingsProvider: provider, calendarStore: store, stateStore: stateStore
            ).run()

            try expect(
                result.outcome == scenario.expectedOutcome,
                "The \(scenario.name) pre-mutation transition should fail closed with its safe outcome")
            try expect(await provider.callCount() == 2, "The \(scenario.name) case should reach the fresh pre-mutation read")
            try expect(await store.mutationCount() == 0, "The \(scenario.name) transition must prevent every mutation")
            try expect(
                (await stateStore.currentState()).standingAuthorization == nil,
                "The \(scenario.name) transition must consume the prior standing authorization")
        }
    }

    private static func testObservedAtoBtoATransitionBeforeMutationRevokesAuthorization() async throws {
        let fixture = AutomaticReconciliationFixture()
        let changes = CalendarConfigurationChangeTracker()
        let provider = ChangingAutomaticSettingsProvider(settings: fixture.settings, changes: changes)
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = fixture.storeWithSourceEvent()

        let result = try await fixture.useCase(
            settingsProvider: provider, authorization: TestCalendarAuthorizationStatus(), calendarStore: store,
            stateStore: stateStore, configurationChanges: changes
        ).run()

        try expect(
            result.outcome == .standingAuthorizationRequired,
            "An observed A-to-B-to-A selected-file transition should invalidate the automatic attempt")
        try expect(await store.mutationCount() == 0, "An observed A-to-B-to-A transition must prevent mutation")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "Returning to the earlier identity must not reactivate the prior grant")
    }

    private static func testAuthorizationRevocationBeforeMutationPreservesMatchingGrant() async throws {
        let fixture = AutomaticReconciliationFixture()
        let authorization = ScriptedAutomaticAuthorization(states: [.fullAccess, .denied])
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = fixture.storeWithSourceEvent()

        let result = try await fixture.useCase(
            settingsProvider: AutomaticSettingsProvider(settings: fixture.settings), authorization: authorization,
            calendarStore: store, stateStore: stateStore
        ).run()

        try expect(result.outcome == .calendarAccessUnavailable, "Revocation should stop the attempt before mutation")
        try expect(await store.mutationCount() == 0, "Revoked access must prevent mutation")
        try expect(
            (await stateStore.currentState()).standingAuthorization != nil,
            "Temporary unavailable access should preserve a still-matching standing grant")
    }

    // ACCESS-AC-01: authorization revocation remains non-prompting on the next attempt.
    private static func testAuthorizationRevocationBetweenAttemptsDoesNotRequestAgain() async throws {
        let fixture = AutomaticReconciliationFixture()
        let authorization = RequestCapableAutomaticAuthorization(state: .fullAccess)
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = fixture.storeWithSourceEvent()
        let useCase = fixture.useCase(authorization: authorization, calendarStore: store, stateStore: stateStore)

        let first = try await useCase.run()
        await authorization.replace(.denied)
        let revoked = try await useCase.run()

        try expect(first.outcome == .applied, "The first authorized automatic attempt should proceed")
        try expect(
            revoked.outcome == .calendarAccessUnavailable,
            "A later automatic attempt should report revoked Calendar access")
        try expect(await store.mutationCount() == 1, "The revoked attempt must not add another calendar mutation")
        try expect(await authorization.requestCount() == 0, "Revocation between attempts must not request access again")
    }

    private static func testPartialMutationPersistsOnlyAggregateConfirmedCounts() async throws {
        let fixture = AutomaticReconciliationFixture()
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = fixture.storeWithSourceEvent(
            hubEvents: [
                CalendarEvent(
                    id: "stale", calendar: CalendarIdentity(id: fixture.hub.id, title: "Hub", sourceTitle: "iCloud"),
                    title: "[WORK] Stale", start: fixture.now, end: fixture.now.addingTimeInterval(100),
                    isAllDay: false, availability: .busy, status: .confirmed)
            ], failOperationNumber: 2)

        let result = try await fixture.useCase(calendarStore: store, stateStore: stateStore).run()

        try expect(result.outcome == .partialMutation, "A mutation failure after confirmation should report partial")
        try expect(
            result.confirmedCounts == CalendarAutomationMutationCounts(confirmedCreates: 0, confirmedDeletes: 1),
            "Partial results should persist aggregate confirmed counts only")
        let persisted = await stateStore.currentState()
        try expect(persisted.operationalStatus.latestOutcome == .partialMutation, "Partial outcome should persist")
        try expect(
            persisted.operationalStatus.freshness.lastSuccessAt == nil,
            "Partial mutation must not update last-success freshness")
        try expect(
            result.retryState == .scheduled(attempt: 1, nextAttemptAt: fixture.now.addingTimeInterval(60)),
            "Partial automatic mutation should schedule a bounded fresh retry")
        try expect(await store.operationAttemptCount() == 2, "Automatic mutation should stop at the first failure")
    }

    private static func testDisabledSchedulingFailsClosedEvenWithStandingAuthorization() async throws {
        let fixture = AutomaticReconciliationFixture()
        let authorized = fixture.authorizedState()
        let stateStore = AutomaticStateStore(
            state: CalendarAutomationPersistentState(
                schedulingPreference: .paused, standingAuthorization: authorized.standingAuthorization,
                operationalStatus: .empty))
        let store = fixture.storeWithSourceEvent()

        do {
            _ = try await fixture.useCase(calendarStore: store, stateStore: stateStore).run()
            throw TestFailure("Paused scheduling should reject an automatic attempt")
        } catch CalendarAutomaticReconciliationError.schedulingNotEnabled {}

        try expect(await store.mutationCount() == 0, "Paused scheduling must prevent mutation")
        try expect(
            (await stateStore.currentState()).operationalStatus == .empty,
            "A skipped paused attempt should not replace operation history")
    }

    private static func testTransientReadFailureSchedulesBoundedFreshRetry() async throws {
        let fixture = AutomaticReconciliationFixture()
        let priorRetry = CalendarAutomationRetryState.scheduled(
            attempt: 1, nextAttemptAt: fixture.now.addingTimeInterval(-1))
        let authorized = fixture.authorizedState()
        let stateStore = AutomaticStateStore(
            state: CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: authorized.standingAuthorization,
                operationalStatus: CalendarAutomationOperationalStatus(
                    lastAttemptAt: nil, latestOutcome: nil, confirmedCounts: .zero, retryState: priorRetry,
                    freshness: CalendarAutomationFreshnessMetadata(lastSuccessAt: nil, nextNominalRunAt: nil))))
        let store = AutomaticCalendarStore(
            calendars: [fixture.hub, fixture.work], eventsByCalendarID: [:], failCalendarInventory: true)

        let result = try await fixture.useCase(calendarStore: store, stateStore: stateStore).run(kind: .retry)

        try expect(result.outcome == .transientFailure, "Calendar inventory read failure should be transient")
        try expect(
            result.retryState == .scheduled(attempt: 2, nextAttemptAt: fixture.now.addingTimeInterval(5 * 60)),
            "A retry attempt should advance the bounded backoff series")
        try expect(await store.mutationCount() == 0, "Transient snapshot failure must not mutate")
    }

    private static func testRetryReloadsFreshConfigurationSnapshotAndPlan() async throws {
        let fixture = AutomaticReconciliationFixture()
        let provider = CountingAutomaticSettingsProvider(settings: fixture.settings)
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = RecoveringAutomaticCalendarStore(fixture: fixture)
        let useCase = fixture.useCase(settingsProvider: provider, calendarStore: store, stateStore: stateStore)

        let first = try await useCase.run()
        let retry = try await useCase.run(kind: .retry)

        try expect(first.outcome == .transientFailure, "The first inventory failure should schedule a fresh retry")
        try expect(retry.outcome == .applied, "The recovered retry should build and apply a fresh plan")
        try expect(
            await provider.callCount() == 3, "The retry should reload configuration and recheck it before mutation")
        try expect(await store.listCalendarsCallCount() == 2, "The retry should reload Calendar inventory")
        try expect(
            await store.eventRequestCalendarIDs() == [fixture.hub.id, fixture.work.id],
            "Only the recovered attempt should load a fresh ordered snapshot")
        try expect(await store.mutationCount() == 1, "The retry should apply only its fresh plan")
    }

    private static func testLargeValidPlanAppliesWithoutHeuristicLimit() async throws {
        let fixture = AutomaticReconciliationFixture()
        let eventCount = 128
        let workIdentity = CalendarIdentity(
            id: fixture.work.id, title: fixture.work.title, sourceTitle: fixture.work.sourceTitle)
        let workEvents = (0..<eventCount).map { index in
            let start = fixture.now.addingTimeInterval(TimeInterval(index * 10))
            return CalendarEvent(
                id: "source-\(index)", calendar: workIdentity, title: "Example \(index)", start: start,
                end: start.addingTimeInterval(5), isAllDay: false, availability: .busy, status: .confirmed)
        }
        let store = AutomaticCalendarStore(
            calendars: [fixture.hub, fixture.work], eventsByCalendarID: [fixture.work.id: workEvents])

        let result = try await fixture.useCase(
            calendarStore: store, stateStore: AutomaticStateStore(state: fixture.authorizedState())
        ).run()

        try expect(result.outcome == .applied, "A large valid deterministic plan should remain authoritative")
        try expect(
            result.confirmedCounts.confirmedCreates == eventCount,
            "Automatic apply should confirm every valid action without a size threshold")
        try expect(await store.mutationCount() == eventCount, "No valid action should be dropped by a heuristic limit")
    }

    private static func testConcurrentRevocationDuringMutationCannotBeResurrected() async throws {
        let fixture = AutomaticReconciliationFixture()
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = BlockingAutomaticCalendarStore(fixture: fixture)
        let useCase = fixture.useCase(calendarStore: store, stateStore: stateStore)

        let task = Task { try await useCase.run() }
        await store.waitUntilMutationStarted()
        _ = try await stateStore.updateState { current in
            CalendarAutomationPersistentState(
                schedulingPreference: current.schedulingPreference, standingAuthorization: nil,
                operationalStatus: current.operationalStatus)
        }
        await store.resumeMutation()
        let result = try await task.value

        try expect(result.outcome == .applied, "The already-started ordered mutation may complete")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "Completing an automatic attempt must not resurrect a concurrently revoked authorization")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct AutomaticReconciliationFixture {
    let now = Date(timeIntervalSince1970: 10_000)
    let hub = RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true)
    let work = RelayCalendar(id: "work", title: "Work", sourceTitle: "Google", isWritable: true)

    var settings: CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[ME]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Work role", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: [])
    }

    func authorizedState() -> CalendarAutomationPersistentState {
        CalendarAutomationPersistentState(
            schedulingPreference: .enabled,
            standingAuthorization: CalendarStandingAuthorizationBinding.derive(
                settings: settings, resolvedCalendars: [hub.id, work.id], policyVersion: .current),
            operationalStatus: .empty)
    }

    func storeWithSourceEvent(hubEvents: [CalendarEvent] = [], failOperationNumber: Int? = nil)
        -> AutomaticCalendarStore
    {
        AutomaticCalendarStore(
            calendars: [hub, work],
            eventsByCalendarID: [
                hub.id: hubEvents,
                work.id: [
                    CalendarEvent(
                        id: "source",
                        calendar: CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle),
                        title: "Example", start: now, end: now.addingTimeInterval(100), isAllDay: false,
                        availability: .busy, status: .confirmed)
                ]
            ], failOperationNumber: failOperationNumber)
    }

    func useCase(
        settingsProvider: any CalendarRelaySettingsProvider? = nil,
        authorization: any CalendarAuthorizationStatusPort = TestCalendarAuthorizationStatus(),
        calendarStore: any CalendarStorePort, stateStore: any CalendarAutomationStateStore,
        configurationChanges: CalendarConfigurationChangeTracker = CalendarConfigurationChangeTracker()
    ) -> CalendarAutomaticReconciliationUseCase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return CalendarAutomaticReconciliationUseCase(
            settingsProvider: settingsProvider ?? AutomaticSettingsProvider(settings: settings),
            authorizationStatus: authorization, calendarStore: calendarStore, stateStore: stateStore,
            configurationChanges: configurationChanges, now: { now }, calendar: calendar)
    }
}

private actor ChangingAutomaticSettingsProvider: CalendarRelaySettingsProvider {
    let settings: CalendarRelaySettings
    let changes: CalendarConfigurationChangeTracker
    private var calls = 0

    init(settings: CalendarRelaySettings, changes: CalendarConfigurationChangeTracker) {
        self.settings = settings
        self.changes = changes
    }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        if calls == 2 { await changes.recordObservedChange() }
        return LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: settings)
    }
}

private actor RequestCapableAutomaticAuthorization: CalendarAuthorizationStatusPort, CalendarFullAccessRequestPort {
    private var state: CalendarAuthorizationState
    private var requests = 0

    init(state: CalendarAuthorizationState) { self.state = state }

    func authorizationStatus() async -> CalendarAuthorizationState { state }

    func requestFullAccess() async throws -> Bool {
        requests += 1
        return state == .fullAccess
    }

    func replace(_ state: CalendarAuthorizationState) { self.state = state }
    func requestCount() -> Int { requests }
}

private actor ScriptedAutomaticAuthorization: CalendarAuthorizationStatusPort {
    private var states: [CalendarAuthorizationState]

    init(states: [CalendarAuthorizationState]) { self.states = states }

    func authorizationStatus() async -> CalendarAuthorizationState {
        guard !states.isEmpty else { return .unknown }
        return states.removeFirst()
    }
}

private struct AutomaticPreflightFailureScenario {
    let name: String
    let store: AutomaticCalendarStore
    let expectedOutcome: CalendarAutomationOutcomeCategory
    let expectedReads: [PhysicalCalendarReference]
}

private struct AutomaticConfigurationFailureScenario {
    let name: String
    let provider: any CalendarRelaySettingsProvider
    let expectedOutcome: CalendarAutomationOutcomeCategory
}

private struct AutomaticPreMutationConfigScenario {
    let name: String
    let finalLoad: Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>
    let expectedOutcome: CalendarAutomationOutcomeCategory
}

private actor ScriptedAutomaticSettingsProvider: CalendarRelaySettingsProvider {
    private var loads: [Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>]
    private var calls = 0

    init(loads: [Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>]) { self.loads = loads }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        guard !loads.isEmpty else { throw TestFailure("Unexpected automatic settings read") }
        return LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: try loads.removeFirst().get())
    }

    func callCount() -> Int { calls }
}

private struct FailingAutomaticSettingsProvider: CalendarRelaySettingsProvider {
    let error: CalendarRelaySettingsProviderError

    func loadSettings() async throws -> LoadedCalendarRelaySettings { throw error }
}

private actor CountingAutomaticSettingsProvider: CalendarRelaySettingsProvider {
    private let settings: CalendarRelaySettings
    private var calls = 0

    init(settings: CalendarRelaySettings) { self.settings = settings }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        return LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: settings)
    }

    func callCount() -> Int { calls }
}

private struct AutomaticSettingsProvider: CalendarRelaySettingsProvider {
    let settings: CalendarRelaySettings

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: settings)
    }
}

private actor AutomaticStateStore: CalendarAutomationStateStore {
    private var state: CalendarAutomationPersistentState

    init(state: CalendarAutomationPersistentState) { self.state = state }

    func loadState() async -> CalendarAutomationPersistentState { state }
    func saveState(_ state: CalendarAutomationPersistentState) async throws { self.state = state }
    func updateState(_ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState)
        async throws -> CalendarAutomationPersistentState
    {
        state = transform(state)
        return state
    }
    func currentState() -> CalendarAutomationPersistentState { state }
}

private actor RecoveringAutomaticCalendarStore: CalendarStorePort {
    private let fixture: AutomaticReconciliationFixture
    private var listCalls = 0
    private var eventRequests: [PhysicalCalendarReference] = []
    private var mutations = 0

    init(fixture: AutomaticReconciliationFixture) { self.fixture = fixture }

    func listCalendars() async throws -> [RelayCalendar] {
        listCalls += 1
        if listCalls == 1 { throw AutomaticStoreFailure() }
        return [fixture.hub, fixture.work]
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventRequests.append(calendar.id)
        guard calendar.id == fixture.work.id else { return [] }
        return [
            CalendarEvent(
                id: "source", calendar: calendar, title: "Example", start: fixture.now,
                end: fixture.now.addingTimeInterval(100), isAllDay: false, availability: .busy, status: .confirmed)
        ]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { mutations += 1 }
    func deleteEvent(_ event: CalendarEventIdentity) async throws { mutations += 1 }

    func listCalendarsCallCount() -> Int { listCalls }
    func eventRequestCalendarIDs() -> [PhysicalCalendarReference] { eventRequests }
    func mutationCount() -> Int { mutations }
}

private actor BlockingAutomaticCalendarStore: CalendarStorePort {
    private let fixture: AutomaticReconciliationFixture
    private var mutationStarted = false
    private var mutationStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var mutationResumeWaiter: CheckedContinuation<Void, Never>?

    init(fixture: AutomaticReconciliationFixture) { self.fixture = fixture }

    func listCalendars() async throws -> [RelayCalendar] { [fixture.hub, fixture.work] }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        guard calendar.id == fixture.work.id else { return [] }
        return [
            CalendarEvent(
                id: "source", calendar: calendar, title: "Example", start: fixture.now,
                end: fixture.now.addingTimeInterval(100), isAllDay: false, availability: .busy, status: .confirmed)
        ]
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        mutationStarted = true
        mutationStartWaiters.forEach { $0.resume() }
        mutationStartWaiters.removeAll()
        await withCheckedContinuation { mutationResumeWaiter = $0 }
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {}

    func waitUntilMutationStarted() async {
        guard !mutationStarted else { return }
        await withCheckedContinuation { mutationStartWaiters.append($0) }
    }

    func resumeMutation() {
        mutationResumeWaiter?.resume()
        mutationResumeWaiter = nil
    }
}

private actor AutomaticCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]
    private let failOperationNumber: Int?
    private let failCalendarInventory: Bool
    private let readFailureCalendarIDs: Set<PhysicalCalendarReference>
    private var listCalls = 0
    private var eventRequests: [PhysicalCalendarReference] = []
    private var operations = 0
    private var creates = 0
    private var deletes = 0

    init(
        calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]],
        failOperationNumber: Int? = nil, failCalendarInventory: Bool = false,
        readFailureCalendarIDs: Set<PhysicalCalendarReference> = []
    ) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
        self.failOperationNumber = failOperationNumber
        self.failCalendarInventory = failCalendarInventory
        self.readFailureCalendarIDs = readFailureCalendarIDs
    }

    func listCalendars() async throws -> [RelayCalendar] {
        listCalls += 1
        if failCalendarInventory { throw AutomaticStoreFailure() }
        return calendars
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventRequests.append(calendar.id)
        if readFailureCalendarIDs.contains(calendar.id) { throw AutomaticStoreFailure() }
        return eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        try recordOperation()
        creates += 1
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        try recordOperation()
        deletes += 1
    }

    func listCalendarsCallCount() -> Int { listCalls }
    func eventRequestCalendarIDs() -> [PhysicalCalendarReference] { eventRequests }
    func mutationCount() -> Int { creates + deletes }
    func operationAttemptCount() -> Int { operations }

    private func recordOperation() throws {
        operations += 1
        if operations == failOperationNumber { throw AutomaticStoreFailure() }
    }
}

private struct AutomaticStoreFailure: Error {}
