import Foundation

public struct CalendarControlPanelStatusUseCase: Sendable {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.settingsProvider = settingsProvider
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
        self.now = now
        self.calendar = calendar
    }

    public func run() async throws -> CalendarControlPanelStatus {
        let loaded: LoadedCalendarRelaySettings
        do { loaded = try await settingsProvider.loadSettings() } catch let error as CalendarRelaySettingsProviderError
        {
            switch error {
            case .missing(let displayPath):
                return CalendarControlPanelStatus(
                    primaryState: .configurationMissing, configurationState: .missing(displayPath: displayPath),
                    authorizationState: nil, readinessState: .notChecked, isMigrationPending: false)
            case .invalid(let displayPath):
                return CalendarControlPanelStatus(
                    primaryState: .configurationInvalid, configurationState: .invalid(displayPath: displayPath),
                    authorizationState: nil, readinessState: .notChecked, isMigrationPending: false)
            }
        }

        let configurationState = CalendarControlPanelConfigurationState.valid(displayPath: loaded.displayPath)
        let migrationPending = !loaded.settings.legacyMarkers.isEmpty
        let window = OrdinaryReconciliationWindow.calculate(
            referenceDate: now(), calendar: calendar, syncWindowDays: loaded.settings.syncWindowDays)
        let result = try await CalendarAccessPreflightUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore
        ).run(settings: loaded.settings, window: window)

        switch result {
        case .ready:
            return CalendarControlPanelStatus(
                primaryState: migrationPending ? .migrationPending : .ready, configurationState: configurationState,
                authorizationState: .fullAccess, readinessState: .ready, isMigrationPending: migrationPending)
        case .failed(let issues):
            if issues.count == 1, case .authorizationUnavailable(let state) = issues[0] {
                return CalendarControlPanelStatus(
                    primaryState: .calendarAccessUnavailable(state), configurationState: configurationState,
                    authorizationState: state, readinessState: .notChecked, isMigrationPending: migrationPending)
            }
            return CalendarControlPanelStatus(
                primaryState: .topologyNotReady, configurationState: configurationState,
                authorizationState: .fullAccess, readinessState: .notReady(issues), isMigrationPending: migrationPending
            )
        }
    }
}
