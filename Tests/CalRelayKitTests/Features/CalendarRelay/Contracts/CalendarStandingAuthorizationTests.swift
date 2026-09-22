import CalRelayKit
import Foundation

enum CalendarStandingAuthorizationTests {
    static func runAll() async throws {
        try await testGrantRequiresFreshSuccessfulReviewAndExplicitConfirmation()
        try await testChangedBindingRequiresFreshReviewBeforeGrant()
        try await testRenewalInvalidatesObservedMismatchAndPreservesPause()
        try await testConfigurationTopologyAndPolicyChangesInvalidateWithoutReactivation()
        try await testUnavailableAccessSuspendsWithoutErasingMatchingAuthorization()
        try await testMigrationAndAccessFailuresCannotGrantAuthorization()
        try await testObservedConfigurationChangeImmediatelyRevokesAuthorization()
        try await testObservedConfigurationChangeInvalidatesOpenReview()
    }

    private static func testObservedConfigurationChangeImmediatelyRevokesAuthorization() async throws {
        let fixture = StandingAuthorizationFixture()
        let provider = StandingSettingsProvider(settings: fixture.settings())
        let store = fixture.store()
        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: fixture.settings(),
            resolvedCalendars: [
                PhysicalCalendarReference(providerIdentifier: "hub"),
                PhysicalCalendarReference(providerIdentifier: "work")
            ], policyVersion: .current)
        let stateStore = StandingStateStore()
        await stateStore.replace(
            CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: binding, operationalStatus: .empty))
        let useCase = fixture.useCase(provider: provider, calendarStore: store, stateStore: stateStore)

        try await useCase.invalidateAuthorizationForObservedConfigurationChange()

        let persisted = await stateStore.currentState()
        try expect(
            persisted.standingAuthorization == nil,
            "An observed file change should immediately revoke standing authorization")
        try expect(persisted.schedulingPreference == .enabled, "Revocation should preserve the scheduling preference")
        try expect(await store.listCalendarsCallCount() == 0, "Immediate revocation should not inspect Calendar state")
        try expect(
            try await useCase.validateCurrentAuthorization() == .notGranted,
            "Returning to the earlier A identity after an observed A-to-B-to-A transition must not reactivate its grant")
    }

    private static func testObservedConfigurationChangeInvalidatesOpenReview() async throws {
        let fixture = StandingAuthorizationFixture()
        let stateStore = StandingStateStore()
        let useCase = fixture.useCase(
            provider: StandingSettingsProvider(settings: fixture.settings()), calendarStore: fixture.store(),
            stateStore: stateStore)
        let review = try await useCase.review()

        try await useCase.invalidateAuthorizationForObservedConfigurationChange()

        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("An observed selected-file change must invalidate an open standing-authorization review")
        } catch CalendarStandingAuthorizationError.reviewRequired {}
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "An invalidated open review must not persist standing authorization")
    }

    private static func testGrantRequiresFreshSuccessfulReviewAndExplicitConfirmation() async throws {
        let fixture = StandingAuthorizationFixture()
        let provider = StandingSettingsProvider(settings: fixture.settings())
        let store = fixture.store()
        let stateStore = StandingStateStore()
        let useCase = fixture.useCase(provider: provider, calendarStore: store, stateStore: stateStore)

        let review = try await useCase.review()

        try expect(
            review.summary == CalendarManualDryRunSummary(plannedDeletes: 0, plannedCreates: 1),
            "Standing authorization review should disclose only aggregate ordinary counts")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "A successful dry run alone must not grant standing authorization")
        try expect(await store.mutationCount() == 0, "Standing authorization review must not mutate calendars")

        guard case .granted = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Explicit confirmation of a fresh review should grant standing authorization")
        }

        let persisted = await stateStore.currentState()
        try expect(persisted.schedulingPreference == .enabled, "First grant should enable scheduled reconciliation")
        try expect(persisted.standingAuthorization != nil, "Confirmation should persist only the opaque binding")
        try expect(await store.listCalendarsCallCount() == 2, "Confirmation should repeat the complete dry run")
        try expect(await provider.callCount() == 2, "Review and confirmation should each load current settings")
        try expect(await store.mutationCount() == 0, "Granting standing authorization must not apply the reviewed plan")
    }

    private static func testChangedBindingRequiresFreshReviewBeforeGrant() async throws {
        let fixture = StandingAuthorizationFixture()
        let provider = StandingSettingsProvider(settings: fixture.settings())
        let store = fixture.store()
        let stateStore = StandingStateStore()
        let useCase = fixture.useCase(provider: provider, calendarStore: store, stateStore: stateStore)
        let review = try await useCase.review()
        await provider.replace(fixture.settings(prefix: "[CHANGED]"))

        let outcome = try await useCase.confirm(reviewID: review.id)

        guard case .reviewRequired(let replacement) = outcome else {
            throw TestFailure("A changed authorization binding should require a fresh aggregate review")
        }
        try expect(replacement.id != review.id, "The replacement review should require a new one-use confirmation")
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "A stale review must never persist authorization")
        guard case .granted = try await useCase.confirm(reviewID: replacement.id) else {
            throw TestFailure("The fresh replacement review should be grantable")
        }
    }

    private static func testConfigurationTopologyAndPolicyChangesInvalidateWithoutReactivation() async throws {
        let fixture = StandingAuthorizationFixture()
        let originalSettings = fixture.settings()
        let provider = StandingSettingsProvider(settings: originalSettings)
        let store = fixture.store()
        let stateStore = StandingStateStore()
        let useCase = fixture.useCase(provider: provider, calendarStore: store, stateStore: stateStore)
        try await grant(useCase)

        await provider.replace(fixture.settings(prefix: "[NEW]"))
        try expect(
            try await useCase.validateCurrentAuthorization() == .invalidated,
            "Mutation-relevant configuration changes should invalidate authorization")
        await provider.replace(originalSettings)
        try expect(
            try await useCase.validateCurrentAuthorization() == .notGranted,
            "Returning to an older configuration identity must not reactivate an invalidated grant")

        try await grant(useCase)
        await store.replaceCalendars(fixture.calendars(hubID: "replacement-hub", workID: "replacement-work"))
        try expect(
            try await useCase.validateCurrentAuthorization() == .invalidated,
            "Changed physical calendar identity should invalidate authorization")

        try await grant(useCase)
        let changedPolicyUseCase = fixture.useCase(
            provider: provider, calendarStore: store, stateStore: stateStore,
            policyVersion: CalendarReconciliationPolicyVersion(rawValue: "ordinary-policy-next"))
        try expect(
            try await changedPolicyUseCase.validateCurrentAuthorization() == .invalidated,
            "A reconciliation-policy version change should invalidate authorization")
    }

    private static func testRenewalInvalidatesObservedMismatchAndPreservesPause() async throws {
        let fixture = StandingAuthorizationFixture()
        let originalSettings = fixture.settings()
        let provider = StandingSettingsProvider(settings: originalSettings)
        let store = fixture.store()
        let stateStore = StandingStateStore()
        let useCase = fixture.useCase(provider: provider, calendarStore: store, stateStore: stateStore)
        try await grant(useCase)
        let grantedState = await stateStore.currentState()
        await stateStore.replace(
            CalendarAutomationPersistentState(
                schedulingPreference: .paused, standingAuthorization: grantedState.standingAuthorization,
                operationalStatus: grantedState.operationalStatus))
        await provider.replace(fixture.settings(prefix: "[RENEWED]"))

        let renewalReview = try await useCase.review()

        let invalidatedState = await stateStore.currentState()
        try expect(
            invalidatedState.standingAuthorization == nil,
            "Observing a changed binding during review should invalidate the old grant immediately")
        try expect(
            invalidatedState.schedulingPreference == .paused,
            "Standing-authorization invalidation should preserve an intentional scheduling pause")
        await provider.replace(originalSettings)
        try expect(
            try await useCase.validateCurrentAuthorization() == .notGranted,
            "Returning to the older identity after review-time invalidation must not reactivate it")
        await provider.replace(fixture.settings(prefix: "[RENEWED]"))
        guard case .granted = try await useCase.confirm(reviewID: renewalReview.id) else {
            throw TestFailure("The reviewed replacement binding should be grantable")
        }
        try expect(
            (await stateStore.currentState()).schedulingPreference == .paused,
            "Renewing standing authorization must not resume intentionally paused scheduling")
    }

    private static func testMigrationAndAccessFailuresCannotGrantAuthorization() async throws {
        let fixture = StandingAuthorizationFixture()
        let migrationProvider = StandingSettingsProvider(settings: fixture.settings(legacyMarkers: ["[OLD]"]))
        let migrationStore = fixture.store()
        let stateStore = StandingStateStore()
        let migrationUseCase = fixture.useCase(
            provider: migrationProvider, calendarStore: migrationStore, stateStore: stateStore)
        do {
            _ = try await migrationUseCase.review()
            throw TestFailure("Migration pending should prevent standing-authorization review")
        } catch let error as ReconcileCalendarsError {
            try expect(error == .migrationPending, "Standing authorization should preserve migration pending")
            try expect(
                error.description.contains("explicit legacy cleanup"),
                "Migration-pending authorization should direct the operator to explicit cleanup")
        }
        try expect(
            await migrationStore.listCalendarsCallCount() == 0,
            "Migration pending should block standing-authorization review before Calendar access")

        let deniedUseCase = fixture.useCase(
            provider: StandingSettingsProvider(settings: fixture.settings()), calendarStore: fixture.store(),
            stateStore: stateStore, authorization: StandingAuthorizationStatus(state: .denied))
        do {
            _ = try await deniedUseCase.review()
            throw TestFailure("Unavailable Calendar access should prevent standing-authorization review")
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) {
            try expect(
                issues == [.authorizationUnavailable(.denied)],
                "Standing authorization should preserve the shared non-prompting access gate")
        }
        try expect(
            (await stateStore.currentState()).standingAuthorization == nil,
            "Failed setup gates must never persist authorization")
        try expect(await migrationStore.mutationCount() == 0, "Failed setup gates must never mutate calendars")
    }

    private static func testUnavailableAccessSuspendsWithoutErasingMatchingAuthorization() async throws {
        let fixture = StandingAuthorizationFixture()
        let provider = StandingSettingsProvider(settings: fixture.settings())
        let store = fixture.store()
        let stateStore = StandingStateStore()
        try await grant(fixture.useCase(provider: provider, calendarStore: store, stateStore: stateStore))
        let deniedUseCase = fixture.useCase(
            provider: provider, calendarStore: store, stateStore: stateStore,
            authorization: StandingAuthorizationStatus(state: .denied))

        do {
            _ = try await deniedUseCase.validateCurrentAuthorization()
            throw TestFailure("Unavailable Calendar access should suspend validation")
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) {
            try expect(
                issues == [.authorizationUnavailable(.denied)],
                "Validation should preserve the shared non-prompting access failure")
        }

        try expect(
            (await stateStore.currentState()).standingAuthorization != nil,
            "A transient access gate must not erase a still-unchecked standing authorization")
    }

    private static func grant(_ useCase: CalendarStandingAuthorizationUseCase) async throws {
        let review = try await useCase.review()
        guard case .granted = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Expected standing authorization to be granted")
        }
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct StandingAuthorizationFixture {
    let now = Date(timeIntervalSince1970: 10_000)

    func settings(prefix: String = "[WORK]", legacyMarkers: [String] = []) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: "Test Source", calendarTitle: "Test Hub")),
            personalPrefix: "[PERSONAL]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Test Work", prefix: prefix,
                    calendar: CalendarSelector(sourceTitle: "Test Source", calendarTitle: "Test Work"))
            ], legacyMarkers: legacyMarkers)
    }

    func calendars(hubID: String = "test-hub", workID: String = "test-work") -> [RelayCalendar] {
        [
            RelayCalendar(id: hubID, title: "Test Hub", sourceTitle: "Test Source", isWritable: true),
            RelayCalendar(id: workID, title: "Test Work", sourceTitle: "Test Source", isWritable: true)
        ]
    }

    func store() -> StandingCalendarStore {
        let visibleCalendars = calendars()
        let work = visibleCalendars[1]
        return StandingCalendarStore(
            calendars: visibleCalendars,
            eventsByCalendarID: [
                work.id: [
                    CalendarEvent(
                        id: "source-event",
                        calendar: CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle),
                        title: "Example", start: now, end: now.addingTimeInterval(100), isAllDay: false,
                        availability: .busy, status: .confirmed)
                ]
            ])
    }

    func useCase(
        provider: any CalendarRelaySettingsProvider, calendarStore: any CalendarStorePort,
        stateStore: any CalendarAutomationStateStore, policyVersion: CalendarReconciliationPolicyVersion = .current,
        authorization: any CalendarAuthorizationStatusPort = StandingAuthorizationStatus(state: .fullAccess)
    ) -> CalendarStandingAuthorizationUseCase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return CalendarStandingAuthorizationUseCase(
            settingsProvider: provider, authorizationStatus: authorization, calendarStore: calendarStore,
            stateStore: stateStore, policyVersion: policyVersion, now: { now }, calendar: calendar)
    }
}

private actor StandingSettingsProvider: CalendarRelaySettingsProvider {
    private var settings: CalendarRelaySettings
    private var calls = 0

    init(settings: CalendarRelaySettings) { self.settings = settings }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        return LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: settings)
    }

    func replace(_ settings: CalendarRelaySettings) { self.settings = settings }
    func callCount() -> Int { calls }
}

private struct StandingAuthorizationStatus: CalendarAuthorizationStatusPort {
    let state: CalendarAuthorizationState

    func authorizationStatus() async -> CalendarAuthorizationState { state }
}

private actor StandingStateStore: CalendarAutomationStateStore {
    private var state = CalendarAutomationPersistentState.empty

    func loadState() async -> CalendarAutomationPersistentState { state }
    func saveState(_ state: CalendarAutomationPersistentState) async throws { self.state = state }
    func updateState(_ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState)
        async throws -> CalendarAutomationPersistentState
    {
        state = transform(state)
        return state
    }
    func currentState() -> CalendarAutomationPersistentState { state }
    func replace(_ state: CalendarAutomationPersistentState) { self.state = state }
}

private actor StandingCalendarStore: CalendarStorePort {
    private var calendars: [RelayCalendar]
    private let eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]
    private var listCalls = 0
    private var creates = 0
    private var deletes = 0

    init(calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
    }

    func listCalendars() async throws -> [RelayCalendar] {
        listCalls += 1
        return calendars
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { creates += 1 }
    func deleteEvent(_ event: CalendarEventIdentity) async throws { deletes += 1 }
    func replaceCalendars(_ calendars: [RelayCalendar]) { self.calendars = calendars }
    func listCalendarsCallCount() -> Int { listCalls }
    func mutationCount() -> Int { creates + deletes }
}
