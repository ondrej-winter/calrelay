import CalRelayKit
import Foundation

enum CalendarUITestScenario: String {
    case missingConfiguration = "missing-configuration"
    case calendarAccessUnavailable = "calendar-access-unavailable"
    case ready
    case migrationPending = "migration-pending"

    static func current(arguments: [String]) -> CalendarUITestScenario? {
        guard arguments.contains("--calrelay-ui-testing") else { return nil }
        guard let optionIndex = arguments.firstIndex(of: "--calrelay-ui-test-scenario"),
            arguments.indices.contains(optionIndex + 1),
            let scenario = CalendarUITestScenario(rawValue: arguments[optionIndex + 1])
        else { return .missingConfiguration }
        return scenario
    }
}

@MainActor enum CalendarUITestComposition {
    static func makeViewModel(scenario: CalendarUITestScenario) -> CalendarListViewModel {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = CalendarUITestFixture(scenario: scenario, now: now)
        let configurationChanges = CalendarConfigurationChangeTracker()
        let inventory = CalendarInventoryUseCase(
            authorizationStatus: fixture.authorization, calendarStore: fixture.calendarStore)
        let setup = CalendarAccessSetupUseCase(
            authorizationStatus: fixture.authorization, fullAccessRequester: fixture.authorization)
        let status = CalendarControlPanelStatusUseCase(
            settingsProvider: fixture.settingsProvider, authorizationStatus: fixture.authorization,
            calendarStore: fixture.calendarStore, now: { now }, calendar: fixture.calendar)
        let manualDryRun = CalendarManualDryRunUseCase(
            settingsProvider: fixture.settingsProvider, authorizationStatus: fixture.authorization,
            calendarStore: fixture.calendarStore, now: { now }, calendar: fixture.calendar)
        let manualApply = CalendarManualApplyUseCase(
            settingsProvider: fixture.settingsProvider, authorizationStatus: fixture.authorization,
            calendarStore: fixture.calendarStore, now: { now }, calendar: fixture.calendar)
        let manualCleanup = CalendarManualCleanupUseCase(
            settingsProvider: fixture.settingsProvider, authorizationStatus: fixture.authorization,
            calendarStore: fixture.calendarStore, now: { now }, calendar: { fixture.calendar })
        let standingAuthorization = CalendarStandingAuthorizationUseCase(
            settingsProvider: fixture.settingsProvider, authorizationStatus: fixture.authorization,
            calendarStore: fixture.calendarStore, stateStore: fixture.automationStateStore,
            configurationChanges: configurationChanges, now: { now }, calendar: fixture.calendar)
        let automaticReconciliation = CalendarAutomaticReconciliationUseCase(
            settingsProvider: fixture.settingsProvider, authorizationStatus: fixture.authorization,
            calendarStore: fixture.calendarStore, stateStore: fixture.automationStateStore,
            configurationChanges: configurationChanges, now: { now }, calendar: fixture.calendar)
        let selectedFile = SelectedConfigurationFile(
            path: "/dev/null", displayPath: "~/.config/calrelay/config.yaml", source: .defaultPath)

        return CalendarListViewModel(
            inventory: inventory, setup: setup, status: status, manualDryRun: manualDryRun, manualApply: manualApply,
            manualCleanup: manualCleanup, standingAuthorization: standingAuthorization,
            automaticReconciliation: automaticReconciliation,
            automationState: CalendarAutomationStateUseCase(stateStore: fixture.automationStateStore),
            configurationObserver: ConfigurationFileObserver(selectedFile: selectedFile, isEnabled: false),
            automationTriggers: CalendarAutomationTriggerSource(isEnabled: false),
            launchAtLogin: CalendarLaunchAtLoginController(isEnabled: false),
            automationAttention: CalendarAutomationAttentionController(isEnabled: false), launchContext: { .ordinary },
            resolveInitialLaunchPresentation: { _ in }, automaticAttemptsEnabled: false)
    }
}

private struct CalendarUITestFixture {
    let settingsProvider: CalendarUITestSettingsProvider
    let authorization: CalendarUITestAuthorization
    let calendarStore: CalendarUITestCalendarStore
    let automationStateStore = CalendarUITestAutomationStateStore()
    let calendar: Calendar

    init(scenario: CalendarUITestScenario, now: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar

        let hub = RelayCalendar(id: "ui-hub", title: "Test Hub", sourceTitle: "Test Account", isWritable: true)
        let work = RelayCalendar(id: "ui-work", title: "Test Work", sourceTitle: "Test Account", isWritable: true)
        let legacyMarkers = scenario == .migrationPending ? ["[RETIRED_TEST]"] : []
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL]", syncWindowDays: 30,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Test role", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: legacyMarkers)

        switch scenario {
        case .missingConfiguration:
            settingsProvider = CalendarUITestSettingsProvider(
                result: .failure(.missing(displayPath: "~/.config/calrelay/config.yaml")))
            authorization = CalendarUITestAuthorization(state: .fullAccess)
            calendarStore = CalendarUITestCalendarStore(calendars: [hub, work], events: [:])
        case .calendarAccessUnavailable:
            settingsProvider = CalendarUITestSettingsProvider(
                result: .success(
                    LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings)))
            authorization = CalendarUITestAuthorization(state: .denied)
            calendarStore = CalendarUITestCalendarStore(calendars: [hub, work], events: [:])
        case .ready:
            settingsProvider = CalendarUITestSettingsProvider(
                result: .success(
                    LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings)))
            authorization = CalendarUITestAuthorization(state: .fullAccess)
            calendarStore = CalendarUITestCalendarStore(
                calendars: [hub, work], events: [work.id: [Self.sourceEvent(calendar: work, now: now)]])
        case .migrationPending:
            settingsProvider = CalendarUITestSettingsProvider(
                result: .success(
                    LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings)))
            authorization = CalendarUITestAuthorization(state: .fullAccess)
            calendarStore = CalendarUITestCalendarStore(
                calendars: [hub, work], events: [hub.id: [Self.legacyEvent(calendar: hub, now: now)]])
        }
    }

    private static func sourceEvent(calendar: RelayCalendar, now: Date) -> CalendarEvent {
        CalendarEvent(
            id: "ui-source-event",
            calendar: CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle),
            title: "Planning", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(7_200),
            isAllDay: false, availability: .busy, status: .confirmed)
    }

    private static func legacyEvent(calendar: RelayCalendar, now: Date) -> CalendarEvent {
        CalendarEvent(
            id: "ui-legacy-event",
            calendar: CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle),
            title: "[RETIRED_TEST] Example", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(7_200),
            isAllDay: false, availability: .busy, status: .confirmed)
    }
}

private actor CalendarUITestSettingsProvider: CalendarRelaySettingsProvider {
    private let result: Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>

    init(result: Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>) { self.result = result }

    func loadSettings() async throws -> LoadedCalendarRelaySettings { try result.get() }
}

private actor CalendarUITestAuthorization: CalendarAuthorizationStatusPort, CalendarFullAccessRequestPort {
    private var state: CalendarAuthorizationState

    init(state: CalendarAuthorizationState) { self.state = state }

    func authorizationStatus() async -> CalendarAuthorizationState { state }

    func requestFullAccess() async throws -> Bool {
        guard state == .notDetermined else { return state == .fullAccess }
        state = .fullAccess
        return true
    }
}

private actor CalendarUITestCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private var events: [PhysicalCalendarReference: [CalendarEvent]]

    init(calendars: [RelayCalendar], events: [PhysicalCalendarReference: [CalendarEvent]]) {
        self.calendars = calendars
        self.events = events
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        events[calendar.id, default: []].filter { $0.start < end && $0.end > start }
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        let id = "ui-created-\(events.values.reduce(0) { $0 + $1.count })"
        events[event.destinationCalendar.id, default: []].append(
            CalendarEvent(
                id: id, calendar: event.destinationCalendar, title: event.title, start: event.start, end: event.end,
                isAllDay: event.isAllDay, availability: .busy, status: .confirmed))
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        events[event.calendar.id, default: []].removeAll { $0.identity == event }
    }
}

private actor CalendarUITestAutomationStateStore: CalendarAutomationStateStore {
    private var state = CalendarAutomationPersistentState.empty

    func loadState() async -> CalendarAutomationPersistentState { state }

    func saveState(_ state: CalendarAutomationPersistentState) async throws { self.state = state }

    func updateState(_ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState)
        async throws -> CalendarAutomationPersistentState
    {
        state = transform(state)
        return state
    }
}
