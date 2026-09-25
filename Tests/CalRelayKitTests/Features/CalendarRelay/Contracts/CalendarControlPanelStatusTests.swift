import CalRelayKit
import Foundation

enum CalendarControlPanelStatusTests {
    static func runAll() async throws {
        try await testMissingConfigurationPrecedesAuthorizationAndCalendarAccess()
        try await testInvalidConfigurationPrecedesAuthorizationAndCalendarAccess()
        try await testEveryStatusRunLoadsCurrentSettingsWithoutFallback()
        try await testUnavailableAuthorizationPrecedesTopologyWithoutPrompting()
        try await testTopologyFailurePrecedesMigrationPending()
        try await testMigrationPendingRequiresReadyTopology()
        try await testHealthyStatusRequiresReadyNonMigrationConfiguration()
        try testComposedPrimaryStateUsesCompleteDependencyOrder()
        try testPartialOperationHistoryDoesNotHideEarlierPrerequisites()
        try testSchedulingRecoveryStatesRemainDistinct()
        try testExhaustedAutomaticFailuresRemainActionable()
    }

    private static func testMissingConfigurationPrecedesAuthorizationAndCalendarAccess() async throws {
        let provider = FakeSettingsProvider(error: .missing(displayPath: "~/.config/calrelay/config.yaml"))
        let authorization = CountingAuthorizationStatus(state: .denied)
        let store = CommandHandlerCalendarStore(calendars: readyCalendars())

        let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

        try expect(status.primaryState == .configurationMissing, "Missing configuration should be the primary state")
        try expect(
            status.configurationState == .missing(displayPath: "~/.config/calrelay/config.yaml"),
            "Status should identify the canonical missing path")
        try expect(
            status.authorizationState == nil, "Authorization should not be inspected before configuration is valid")
        try expect(await authorization.callCount() == 0, "Missing configuration should prevent authorization access")
        try expect(await store.listCalendarsCallCount() == 0, "Missing configuration should prevent EventKit access")
    }

    private static func testInvalidConfigurationPrecedesAuthorizationAndCalendarAccess() async throws {
        let provider = FakeSettingsProvider(error: .invalid(displayPath: "~/.config/calrelay/config.yaml"))
        let authorization = CountingAuthorizationStatus(state: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: readyCalendars())

        let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

        try expect(status.primaryState == .configurationInvalid, "Invalid configuration should be the primary state")
        try expect(status.readinessState == .notChecked, "Invalid configuration should prevent readiness checks")
        try expect(await authorization.callCount() == 0, "Invalid configuration should prevent authorization access")
        try expect(await store.listCalendarsCallCount() == 0, "Invalid configuration should prevent EventKit access")
    }

    private static func testEveryStatusRunLoadsCurrentSettingsWithoutFallback() async throws {
        let displayPath = "~/.config/calrelay/config.yaml"
        let provider = ScriptedStatusSettingsProvider(results: [
            .success(LoadedCalendarRelaySettings(displayPath: displayPath, settings: settings())),
            .failure(.missing(displayPath: displayPath)),
            .failure(.invalid(displayPath: displayPath))
        ])
        let authorization = CountingAuthorizationStatus(state: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: readyCalendars())
        let useCase = useCase(provider: provider, authorization: authorization, store: store)

        let ready = try await useCase.run()
        let missing = try await useCase.run()
        let invalid = try await useCase.run()

        try expect(ready.primaryState == .ready, "The first status run should use the initial valid file")
        try expect(
            missing.primaryState == .configurationMissing,
            "A later missing file must replace, not fall back to, the earlier valid status")
        try expect(
            invalid.primaryState == .configurationInvalid,
            "A later invalid file must replace, not fall back to, the earlier valid status")
        try expect(await provider.callCount() == 3, "Every status run should load the selected file afresh")
        try expect(
            await store.listCalendarsCallCount() == 1,
            "Missing and invalid follow-up status runs must stop before Calendar access")
    }

    private static func testUnavailableAuthorizationPrecedesTopologyWithoutPrompting() async throws {
        for state in CalendarAuthorizationState.allCases where state != .fullAccess {
            let provider = FakeSettingsProvider(settings: settings())
            let authorization = CountingAuthorizationStatus(state: state)
            let store = CommandHandlerCalendarStore(calendars: readyCalendars())

            let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

            try expect(
                status.primaryState == .calendarAccessUnavailable(state),
                "\(state) should be the primary recovery state")
            try expect(
                status.configurationState == .valid(displayPath: "~/.config/calrelay/config.yaml"),
                "Configuration should remain visibly valid")
            try expect(status.readinessState == .notChecked, "Unavailable authorization should prevent topology reads")
            try expect(await authorization.callCount() == 1, "Status should inspect authorization without requesting")
            try expect(
                await store.listCalendarsCallCount() == 0,
                "Unavailable authorization should prevent EventKit inventory access")
        }
    }

    private static func testTopologyFailurePrecedesMigrationPending() async throws {
        let provider = FakeSettingsProvider(settings: settings(legacyMarkers: ["[OLD]"]))
        let authorization = CountingAuthorizationStatus(state: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: [readyCalendars()[0]])

        let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

        try expect(status.primaryState == .topologyNotReady, "Topology failure should precede migration pending")
        guard case .notReady(let issues) = status.readinessState else {
            throw TestFailure("Expected topology readiness failure")
        }
        try expect(
            issues.contains(
                .calendarMissing(
                    role: .work(name: "ACME", declarationIndex: 0),
                    selector: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))),
            "Status should preserve aggregate topology issues")
        try expect(status.isMigrationPending, "Migration state should remain visible as a secondary issue")
    }

    private static func testMigrationPendingRequiresReadyTopology() async throws {
        let provider = FakeSettingsProvider(settings: settings(legacyMarkers: ["[OLD]"]))
        let authorization = CountingAuthorizationStatus(state: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: readyCalendars())

        let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

        try expect(
            status.primaryState == .migrationPending, "Ready topology with tombstones should report migration pending")
        try expect(status.readinessState == .ready, "Migration pending should retain successful configured readiness")
        try expect(status.isMigrationPending, "Migration pending should be explicit")
    }

    private static func testHealthyStatusRequiresReadyNonMigrationConfiguration() async throws {
        let provider = FakeSettingsProvider(settings: settings())
        let authorization = CountingAuthorizationStatus(state: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: readyCalendars())

        let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

        try expect(
            status.primaryState == .ready, "Valid configuration, full access, and ready topology should be healthy")
        try expect(status.readinessState == .ready, "Healthy status should report configured readiness")
        try expect(!status.isMigrationPending, "Healthy status should not report migration pending")
    }

    private static func testComposedPrimaryStateUsesCompleteDependencyOrder() throws {
        let policy = CalendarControlPanelPresentationPolicy()
        let authorized = automationState(
            preference: .enabled, authorized: true, outcome: .partialMutation,
            retryState: .none, lastSuccessAt: now.addingTimeInterval(-2 * CalendarAutomationSchedulingPolicy.freshnessInterval))
        let cases = [
            ControlPanelPresentationCase(.configurationMissing, .valid, authorized, false, .configurationMissing),
            ControlPanelPresentationCase(.configurationInvalid, .valid, authorized, false, .configurationInvalid),
            ControlPanelPresentationCase(
                .calendarAccessUnavailable(.denied), .valid, authorized, false, .calendarAccessUnavailable(.denied)
            ),
            ControlPanelPresentationCase(.topologyNotReady, .valid, authorized, false, .topologyNotReady),
            ControlPanelPresentationCase(.migrationPending, .valid, authorized, false, .migrationPending),
            ControlPanelPresentationCase(
                .ready, .notGranted, automationState(preference: .enabled, authorized: false), false,
                .standingAuthorizationRequired),
            ControlPanelPresentationCase(.ready, .invalidated, authorized, false, .standingAuthorizationRequired),
            ControlPanelPresentationCase(.ready, .valid, authorized, false, .launchAtLoginUnavailable),
            ControlPanelPresentationCase(
                .ready, .valid,
                automationState(preference: .paused, authorized: true, outcome: .partialMutation), false,
                .launchAtLoginUnavailable),
            ControlPanelPresentationCase(
                .ready, .valid,
                automationState(preference: .paused, authorized: true, outcome: .partialMutation), true,
                .schedulingPaused),
            ControlPanelPresentationCase(
                .ready, .valid,
                automationState(
                    preference: .enabled, authorized: true, outcome: .transientFailure,
                    retryState: .scheduled(attempt: 2, nextAttemptAt: now.addingTimeInterval(60))), true,
                .retryPending(attempt: 2)),
            ControlPanelPresentationCase(
                .ready, .valid,
                automationState(
                    preference: .enabled, authorized: true, outcome: .applied,
                    lastSuccessAt: now.addingTimeInterval(-CalendarAutomationSchedulingPolicy.freshnessInterval - 1)),
                true, .freshnessOverdue),
            ControlPanelPresentationCase(
                .ready, .valid, automationState(preference: .enabled, authorized: true), true, .healthy)
        ]

        for testCase in cases {
            let actual = policy.primaryState(
                controlPanelState: testCase.controlPanelState,
                standingAuthorizationValidation: testCase.authorizationValidation,
                automationState: testCase.automationState,
                launchAtLoginHealthy: testCase.launchAtLoginHealthy, now: now)
            try expect(
                actual == testCase.expected,
                "The composed primary state should follow the complete dependency order")
        }
    }

    private static func testPartialOperationHistoryDoesNotHideEarlierPrerequisites() throws {
        let partialState = automationState(
            preference: .enabled, authorized: true, outcome: .partialMutation, retryState: .none,
            lastSuccessAt: now.addingTimeInterval(-2 * CalendarAutomationSchedulingPolicy.freshnessInterval))

        let primary = CalendarControlPanelPresentationPolicy().primaryState(
            controlPanelState: .calendarAccessUnavailable(.writeOnly), standingAuthorizationValidation: .valid,
            automationState: partialState,
            launchAtLoginHealthy: false, now: now)

        try expect(
            primary == .calendarAccessUnavailable(.writeOnly),
            "A partial prior result must not hide an earlier recoverable prerequisite")
        try expect(
            partialState.operationalStatus.latestOutcome == .partialMutation,
            "Selecting an earlier primary prerequisite must preserve the separate operation history")
    }

    private static func testSchedulingRecoveryStatesRemainDistinct() throws {
        let policy = CalendarControlPanelPresentationPolicy()
        let disabled = policy.primaryState(
            controlPanelState: .ready, standingAuthorizationValidation: .valid,
            automationState: automationState(preference: .disabled, authorized: true),
            launchAtLoginHealthy: true, now: now)
        let paused = policy.primaryState(
            controlPanelState: .ready, standingAuthorizationValidation: .valid,
            automationState: automationState(preference: .paused, authorized: true),
            launchAtLoginHealthy: true, now: now)
        let retrying = policy.primaryState(
            controlPanelState: .ready, standingAuthorizationValidation: .valid,
            automationState: automationState(
                preference: .enabled, authorized: true, outcome: .partialMutation,
                retryState: .scheduled(attempt: 1, nextAttemptAt: now.addingTimeInterval(60))),
            launchAtLoginHealthy: true, now: now)

        try expect(disabled == .schedulingDisabled, "Disabled scheduling should remain distinct from healthy state")
        try expect(paused == .schedulingPaused, "Paused scheduling should remain an intentional degraded state")
        try expect(retrying == .retryPending(attempt: 1), "A bounded retry should remain distinct from overdue state")
    }

    private static func testExhaustedAutomaticFailuresRemainActionable() throws {
        let policy = CalendarControlPanelPresentationPolicy()
        for (outcome, expected) in [
            (CalendarAutomationOutcomeCategory.partialMutation, CalendarControlPanelPresentationState.partialMutation),
            (.transientFailure, .transientFailure)
        ] {
            let state = automationState(
                preference: .enabled, authorized: true, outcome: outcome, retryState: .none,
                lastSuccessAt: now.addingTimeInterval(-30 * 60))

            let primary = policy.primaryState(
                controlPanelState: .ready, standingAuthorizationValidation: .valid,
                automationState: state, launchAtLoginHealthy: true, now: now)

            try expect(primary == expected, "An exhausted automatic failure must not be presented as healthy")
        }
    }

    private static func useCase(
        provider: any CalendarRelaySettingsProvider, authorization: CountingAuthorizationStatus,
        store: CommandHandlerCalendarStore
    ) -> CalendarControlPanelStatusUseCase {
        CalendarControlPanelStatusUseCase(
            settingsProvider: provider, authorizationStatus: authorization, calendarStore: store,
            now: { Date(timeIntervalSince1970: 10_000) }, calendar: utcCalendar())
    }

    private static func settings(legacyMarkers: [String] = []) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Personal Work")),
            personalPrefix: "[ME]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
            ], legacyMarkers: legacyMarkers)
    }

    private static func readyCalendars() -> [RelayCalendar] {
        [
            RelayCalendar(id: "hub", title: "Personal Work", sourceTitle: "iCloud", isWritable: true),
            RelayCalendar(id: "work", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        ]
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static let now = Date(timeIntervalSince1970: 10_000)

    private static func automationState(
        preference: CalendarSchedulingPreference, authorized: Bool,
        outcome: CalendarAutomationOutcomeCategory = .applied,
        retryState: CalendarAutomationRetryState = .none,
        lastSuccessAt: Date? = now.addingTimeInterval(-30 * 60)
    ) -> CalendarAutomationPersistentState {
        CalendarAutomationPersistentState(
            schedulingPreference: preference,
            standingAuthorization: authorized ? authorizationBinding() : nil,
            operationalStatus: CalendarAutomationOperationalStatus(
                lastAttemptAt: now.addingTimeInterval(-5 * 60), latestOutcome: outcome,
                confirmedCounts: .zero, retryState: retryState,
                freshness: CalendarAutomationFreshnessMetadata(
                    lastSuccessAt: lastSuccessAt, nextNominalRunAt: now.addingTimeInterval(10 * 60))))
    }

    private static func authorizationBinding() -> CalendarStandingAuthorizationBinding {
        CalendarStandingAuthorizationBinding.derive(
            settings: settings(),
            resolvedCalendars: [
                PhysicalCalendarReference(providerIdentifier: "hub"),
                PhysicalCalendarReference(providerIdentifier: "work")
            ], policyVersion: .current)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct ControlPanelPresentationCase {
    let controlPanelState: CalendarControlPanelPrimaryState
    let authorizationValidation: CalendarStandingAuthorizationValidation
    let automationState: CalendarAutomationPersistentState
    let launchAtLoginHealthy: Bool
    let expected: CalendarControlPanelPresentationState

    init(
        _ controlPanelState: CalendarControlPanelPrimaryState,
        _ authorizationValidation: CalendarStandingAuthorizationValidation,
        _ automationState: CalendarAutomationPersistentState,
        _ launchAtLoginHealthy: Bool,
        _ expected: CalendarControlPanelPresentationState
    ) {
        self.controlPanelState = controlPanelState
        self.authorizationValidation = authorizationValidation
        self.automationState = automationState
        self.launchAtLoginHealthy = launchAtLoginHealthy
        self.expected = expected
    }
}

private actor ScriptedStatusSettingsProvider: CalendarRelaySettingsProvider {
    private var results: [Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>]
    private var calls = 0

    init(results: [Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>]) {
        self.results = results
    }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        guard !results.isEmpty else { throw TestFailure("Unexpected status settings read") }
        return try results.removeFirst().get()
    }

    func callCount() -> Int { calls }
}

private actor FakeSettingsProvider: CalendarRelaySettingsProvider {
    private let result: Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>

    init(settings: CalendarRelaySettings) {
        result = .success(
            LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings))
    }

    init(error: CalendarRelaySettingsProviderError) { result = .failure(error) }

    func loadSettings() async throws -> LoadedCalendarRelaySettings { try result.get() }
}

private actor CountingAuthorizationStatus: CalendarAuthorizationStatusPort {
    private let state: CalendarAuthorizationState
    private var calls = 0

    init(state: CalendarAuthorizationState) { self.state = state }

    func authorizationStatus() async -> CalendarAuthorizationState {
        calls += 1
        return state
    }

    func callCount() -> Int { calls }
}
