import CalRelayKit
import Foundation

enum CalendarControlPanelStatusTests {
    static func runAll() async throws {
        try await testMissingConfigurationPrecedesAuthorizationAndCalendarAccess()
        try await testInvalidConfigurationPrecedesAuthorizationAndCalendarAccess()
        try await testUnavailableAuthorizationPrecedesTopologyWithoutPrompting()
        try await testTopologyFailurePrecedesMigrationPending()
        try await testMigrationPendingRequiresReadyTopology()
        try await testHealthyStatusRequiresReadyNonMigrationConfiguration()
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

    private static func testUnavailableAuthorizationPrecedesTopologyWithoutPrompting() async throws {
        let provider = FakeSettingsProvider(settings: settings())
        let authorization = CountingAuthorizationStatus(state: .writeOnly)
        let store = CommandHandlerCalendarStore(calendars: readyCalendars())

        let status = try await useCase(provider: provider, authorization: authorization, store: store).run()

        try expect(
            status.primaryState == .calendarAccessUnavailable(.writeOnly),
            "Write-only access should be the primary recovery state")
        try expect(
            status.configurationState == .valid(displayPath: "~/.config/calrelay/config.yaml"),
            "Configuration should remain visibly valid")
        try expect(status.readinessState == .notChecked, "Unavailable authorization should prevent topology reads")
        try expect(await authorization.callCount() == 1, "Status should inspect authorization without requesting")
        try expect(
            await store.listCalendarsCallCount() == 0,
            "Unavailable authorization should prevent EventKit inventory access")
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

    private static func useCase(
        provider: FakeSettingsProvider, authorization: CountingAuthorizationStatus, store: CommandHandlerCalendarStore
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

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
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
