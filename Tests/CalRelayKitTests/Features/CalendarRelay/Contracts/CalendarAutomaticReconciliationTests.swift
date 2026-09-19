import CalRelayKit
import Foundation

enum CalendarAutomaticReconciliationTests {
    static func runAll() async throws {
        try await testFreshAuthorizedAttemptAppliesAndPersistsAggregateSuccess()
        try await testMissingStandingAuthorizationPerformsNoMutation()
        try await testReadyEmptyPlanUpdatesSuccessWithoutMutation()
        try await testBindingMismatchRevokesAuthorizationWithoutMutation()
        try await testObservedConfigurationChangeBeforeMutationRevokesAuthorization()
        try await testAuthorizationRevocationBeforeMutationPreservesMatchingGrant()
        try await testPartialMutationPersistsOnlyAggregateConfirmedCounts()
        try await testDisabledSchedulingFailsClosedEvenWithStandingAuthorization()
        try await testTransientReadFailureSchedulesBoundedFreshRetry()
        try await testConcurrentRevocationDuringMutationCannotBeResurrected()
    }

    private static func testFreshAuthorizedAttemptAppliesAndPersistsAggregateSuccess() async throws {
        let fixture = AutomaticReconciliationFixture()
        let stateStore = AutomaticStateStore(state: fixture.authorizedState())
        let store = fixture.storeWithSourceEvent()
        let useCase = fixture.useCase(calendarStore: store, stateStore: stateStore)

        let result = try await useCase.run()

        try expect(result.outcome == .applied, "An authorized mutating attempt should report applied")
        try expect(
            result.confirmedCounts == CalendarAutomationMutationCounts(confirmedCreates: 1, confirmedDeletes: 0),
            "Automatic success should disclose only aggregate confirmed counts")
        try expect(await store.mutationCount() == 1, "The fresh authorized plan should be applied once")
        let persisted = await stateStore.currentState()
        try expect(persisted.operationalStatus.latestOutcome == .applied, "Applied outcome should persist")
        try expect(
            persisted.operationalStatus.freshness.lastSuccessAt == fixture.now,
            "Success should update freshness")
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

    private static func testBindingMismatchRevokesAuthorizationWithoutMutation() async throws {
        let fixture = AutomaticReconciliationFixture()
        let mismatched = CalendarStandingAuthorizationBinding.derive(
            settings: fixture.settings, resolvedCalendars: [fixture.hub.id, fixture.work.id],
            policyVersion: CalendarReconciliationPolicyVersion(rawValue: "different-policy"))
        let stateStore = AutomaticStateStore(
            state: CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: mismatched, operationalStatus: .empty))
        let store = fixture.storeWithSourceEvent()

        let result = try await fixture.useCase(calendarStore: store, stateStore: stateStore).run()

        try expect(result.outcome == .standingAuthorizationRequired, "A binding mismatch should suspend automation")
        try expect(await store.mutationCount() == 0, "A binding mismatch must prevent mutation")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "A mismatched binding should be removed rather than silently reactivated")
    }

    private static func testObservedConfigurationChangeBeforeMutationRevokesAuthorization() async throws {
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
            "An observed selected-file change should invalidate the automatic attempt")
        try expect(await store.mutationCount() == 0, "An observed selected-file change must prevent mutation")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "Observed selected-file change should revoke the prior grant")
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

    func storeWithSourceEvent(
        hubEvents: [CalendarEvent] = [], failOperationNumber: Int? = nil
    ) -> AutomaticCalendarStore {
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
            authorizationStatus: authorization, calendarStore: calendarStore,
            stateStore: stateStore, configurationChanges: configurationChanges, now: { now }, calendar: calendar)
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

private actor ScriptedAutomaticAuthorization: CalendarAuthorizationStatusPort {
    private var states: [CalendarAuthorizationState]

    init(states: [CalendarAuthorizationState]) { self.states = states }

    func authorizationStatus() async -> CalendarAuthorizationState {
        guard !states.isEmpty else { return .unknown }
        return states.removeFirst()
    }
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
    func updateState(
        _ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState
    ) async throws -> CalendarAutomationPersistentState {
        state = transform(state)
        return state
    }
    func currentState() -> CalendarAutomationPersistentState { state }
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
                end: fixture.now.addingTimeInterval(100), isAllDay: false, availability: .busy,
                status: .confirmed)
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
    private var operations = 0
    private var creates = 0
    private var deletes = 0

    init(
        calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]],
        failOperationNumber: Int? = nil, failCalendarInventory: Bool = false
    ) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
        self.failOperationNumber = failOperationNumber
        self.failCalendarInventory = failCalendarInventory
    }

    func listCalendars() async throws -> [RelayCalendar] {
        if failCalendarInventory { throw AutomaticStoreFailure() }
        return calendars
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        try recordOperation()
        creates += 1
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        try recordOperation()
        deletes += 1
    }

    func mutationCount() -> Int { creates + deletes }

    private func recordOperation() throws {
        operations += 1
        if operations == failOperationNumber { throw AutomaticStoreFailure() }
    }
}

private struct AutomaticStoreFailure: Error {}