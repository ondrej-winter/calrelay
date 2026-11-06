import AppKit
import CalRelayKit
import Combine
import Foundation

enum CalendarUITestScenario: String {
    case missingConfiguration = "missing-configuration"
    case calendarAccessUnavailable = "calendar-access-unavailable"
    case ready
    case healthyLogin = "healthy-login"
    case manualApplyFailure = "manual-apply-failure"
    case migrationPending = "migration-pending"
    case cleanupApplyFailure = "cleanup-apply-failure"

    static func current(arguments: [String]) -> CalendarUITestScenario? {
        guard
            arguments.contains("--calrelay-ui-testing")
                || Bundle.main.bundleIdentifier == "dev.owinter.CalRelay.UITestHost"
        else { return nil }
        guard let optionIndex = arguments.firstIndex(of: "--calrelay-ui-test-scenario"),
            arguments.indices.contains(optionIndex + 1),
            let scenario = CalendarUITestScenario(rawValue: arguments[optionIndex + 1])
        else { return .missingConfiguration }
        return scenario
    }
}

enum CalendarUITestNotificationMode: String {
    case available
    case denied
    case failed

    static func current() -> Self? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--calrelay-ui-test-notifications"),
            arguments.indices.contains(index + 1)
        else { return nil }
        return Self(rawValue: arguments[index + 1])
    }
}

@MainActor enum CalendarUITestComposition {
    // One isolated host process owns one in-memory fixture; this never touches production settings.
    private static var mutateConfigurationForUITest: (() async -> Void)?

    static func makeViewModel(scenario: CalendarUITestScenario, appDelegate: CalRelayAppDelegate)
        -> CalendarListViewModel
    {
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

        let notificationDelivery = CalendarUITestNotificationDelivery(showControlPanel: { [weak appDelegate] in
            appDelegate?.openControlPanel()
        })
        let viewModel = CalendarListViewModel(
            inventory: inventory, setup: setup, status: status, manualDryRun: manualDryRun, manualApply: manualApply,
            manualCleanup: manualCleanup, standingAuthorization: standingAuthorization,
            automaticReconciliation: automaticReconciliation,
            automationState: CalendarAutomationStateUseCase(stateStore: fixture.automationStateStore),
            configurationObserver: ConfigurationFileObserver(selectedFile: selectedFile, isEnabled: false),
            automationTriggers: CalendarAutomationTriggerSource(isEnabled: false, now: { now }),
            launchAtLogin: CalendarLaunchAtLoginController(isEnabled: false),
            automationAttention: CalendarAutomationAttentionController(
                delivery: notificationDelivery,
                runtimeAlertsEnabled: { [weak appDelegate] in appDelegate?.runtimeAlertsEnabled == true }),
            launchContext: { [weak appDelegate] in appDelegate?.initialLaunchContext ?? .ordinary },
            resolveInitialLaunchPresentation: { [weak appDelegate] presentation in
                appDelegate?.resolveInitialLaunchPresentation(presentation)
            }, now: { now }, automaticAttemptsEnabled: false)
        notificationDelivery.didChange = { [weak viewModel] summary in viewModel?.notificationSummary = summary }
        notificationDelivery.trackAutomaticOperations(viewModel)
        let settingsProvider = fixture.settingsProvider
        mutateConfigurationForUITest = { [weak viewModel] in
            await settingsProvider.changeSyncWindowForUITest()
            viewModel?.configurationDidChange()
        }
        return viewModel
    }

    static func handleWindowClosure(viewModel: CalendarListViewModel) {
        guard CalendarUITestScenario.current(arguments: CommandLine.arguments) != nil else { return }
        let simulateWake = CommandLine.arguments.contains("--calrelay-ui-test-wake-after-close")
        let simulateConfigurationChange = CommandLine.arguments.contains(
            "--calrelay-ui-test-configuration-change-after-close")
        guard simulateWake || simulateConfigurationChange || CalendarUITestNotificationMode.current() != nil else {
            return
        }
        Task { @MainActor [weak viewModel] in
            guard let viewModel else { return }
            if simulateConfigurationChange {
                await mutateConfigurationForUITest?()
                return
            }
            if simulateWake {
                viewModel.automationTriggers.deliverTestTrigger(.wake)
                return
            }
            viewModel.primaryStatus = "Scheduled sync freshness is overdue."
            viewModel.automationAttentionReason = .freshnessOverdue
            viewModel.automationAttention.update(reason: .freshnessOverdue)
        }
    }
}

private struct CalendarUITestFixture {
    let settingsProvider: CalendarUITestSettingsProvider
    let authorization: CalendarUITestAuthorization
    let calendarStore: CalendarUITestCalendarStore
    let automationStateStore: CalendarUITestAutomationStateStore
    let calendar: Calendar

    init(scenario: CalendarUITestScenario, now: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar

        let hub = RelayCalendar(id: "ui-hub", title: "Test Hub", sourceTitle: "Test Account", isWritable: true)
        let work = RelayCalendar(id: "ui-work", title: "Test Work", sourceTitle: "Test Account", isWritable: true)
        let legacyMarkers = scenario == .migrationPending || scenario == .cleanupApplyFailure ? ["[RETIRED_TEST]"] : []
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL]", syncWindowDays: 30,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Test role", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: legacyMarkers)

        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: settings, resolvedCalendars: [hub.id, work.id], policyVersion: .current)
        let state = CalendarAutomationPersistentState(
            schedulingPreference: .enabled, standingAuthorization: binding,
            operationalStatus: CalendarAutomationOperationalStatus(
                lastAttemptAt: now, latestOutcome: .noChanges, confirmedCounts: .zero, retryState: .none,
                freshness: CalendarAutomationFreshnessMetadata(lastSuccessAt: now, nextNominalRunAt: nil)))
        automationStateStore = CalendarUITestAutomationStateStore(
            state: scenario == .healthyLogin || CalendarUITestNotificationMode.current() != nil ? state : .empty)

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
        case .ready, .manualApplyFailure, .healthyLogin:
            settingsProvider = CalendarUITestSettingsProvider(
                result: .success(
                    LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings)))
            authorization = CalendarUITestAuthorization(state: .fullAccess)
            calendarStore = CalendarUITestCalendarStore(
                calendars: [hub, work], events: [work.id: [Self.sourceEvent(calendar: work, now: now)]],
                failsCreate: scenario == .manualApplyFailure)
        case .migrationPending, .cleanupApplyFailure:
            settingsProvider = CalendarUITestSettingsProvider(
                result: .success(
                    LoadedCalendarRelaySettings(displayPath: "~/.config/calrelay/config.yaml", settings: settings)))
            authorization = CalendarUITestAuthorization(state: .fullAccess)
            calendarStore = CalendarUITestCalendarStore(
                calendars: [hub, work], events: [hub.id: [Self.legacyEvent(calendar: hub, now: now)]],
                failsDelete: scenario == .cleanupApplyFailure)
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
    private var result: Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>

    init(result: Result<LoadedCalendarRelaySettings, CalendarRelaySettingsProviderError>) { self.result = result }

    func changeSyncWindowForUITest() {
        guard case .success(let loaded) = result else { return }
        let current = loaded.settings
        let changed = CalendarRelaySettings(
            hubCalendar: current.hubCalendar, personalPrefix: current.personalPrefix, syncWindowDays: 31,
            workCalendars: current.workCalendars, legacyMarkers: current.legacyMarkers)
        result = .success(LoadedCalendarRelaySettings(displayPath: loaded.displayPath, settings: changed))
    }

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
    private let failsCreate: Bool
    private let failsDelete: Bool

    init(
        calendars: [RelayCalendar], events: [PhysicalCalendarReference: [CalendarEvent]], failsCreate: Bool = false,
        failsDelete: Bool = false
    ) {
        self.calendars = calendars
        self.events = events
        self.failsCreate = failsCreate
        self.failsDelete = failsDelete
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        events[calendar.id, default: []].filter { $0.start < end && $0.end > start }
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        if failsCreate { throw CalendarUITestStoreFailure() }
        let id = "ui-created-\(events.values.reduce(0) { $0 + $1.count })"
        events[event.destinationCalendar.id, default: []].append(
            CalendarEvent(
                id: id, calendar: event.destinationCalendar, title: event.title, start: event.start, end: event.end,
                isAllDay: event.isAllDay, availability: .busy, status: .confirmed))
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        if failsDelete { throw CalendarUITestStoreFailure() }
        events[event.calendar.id, default: []].removeAll { $0.identity == event }
    }
}

private struct CalendarUITestStoreFailure: Error {}

@MainActor private final class CalendarUITestNotificationDelivery: CalendarAutomationNotificationDelivering {
    var didChange: ((String) -> Void)?
    private let mode = CalendarUITestNotificationMode.current()
    private var submissions = 0
    private var recoveryOpens = 0
    private let showControlPanel: () -> Void
    private var operationObservation: AnyCancellable?

    init(showControlPanel: @escaping () -> Void) { self.showControlPanel = showControlPanel }

    func trackAutomaticOperations(_ viewModel: CalendarListViewModel) {
        guard CommandLine.arguments.contains("--calrelay-ui-test-wake-after-close") else { return }
        operationObservation = viewModel.$automaticOperationSummary.sink { [weak self] summary in
            Task { @MainActor in self?.didChange?("Test automatic result: \(summary)") }
        }
    }

    func requestAuthorization() async {}
    func authorizationSummary() async -> String { summary }
    func notificationsAvailable() async -> Bool { mode == .available || mode == .failed }
    func submitNotification(_ notification: CalendarAutomationAttentionNotification) async -> Bool {
        submissions += 1
        didChange?(summary)
        return mode == .available
    }
    func clearNotification() async {}
    func openControlPanel() async {
        recoveryOpens += 1
        didChange?(summary)
        showControlPanel()
    }

    private var summary: String {
        guard mode != nil else { return "Denied. Scheduling remains available; actionable recovery opens in CalRelay." }
        return "Test submissions: \(submissions); recovery opens: \(recoveryOpens)"
    }
}

private actor CalendarUITestAutomationStateStore: CalendarAutomationStateStore {
    private var state: CalendarAutomationPersistentState

    init(state: CalendarAutomationPersistentState = .empty) { self.state = state }

    func loadState() async -> CalendarAutomationPersistentState { state }

    func saveState(_ state: CalendarAutomationPersistentState) async throws { self.state = state }

    func updateState(_ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState)
        async throws -> CalendarAutomationPersistentState
    {
        state = transform(state)
        return state
    }
}
