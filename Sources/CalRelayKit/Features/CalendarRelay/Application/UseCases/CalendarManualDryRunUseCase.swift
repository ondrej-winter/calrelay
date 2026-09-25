import Foundation

public struct CalendarManualDryRunUseCase: Sendable {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let reconciliation: ReconcileCalendarsUseCase
    private let now: @Sendable () -> Date

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendarProvider: @escaping @Sendable () -> Calendar = { .current }
    ) {
        self.settingsProvider = settingsProvider
        reconciliation = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore,
            calendarProvider: calendarProvider)
        self.now = now
    }

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar
    ) {
        self.init(
            settingsProvider: settingsProvider, authorizationStatus: authorizationStatus, calendarStore: calendarStore,
            now: now, calendarProvider: { calendar })
    }

    public func run() async throws -> CalendarManualDryRunSummary {
        let loaded = try await settingsProvider.loadSettings()
        let result = try await reconciliation.dryRunResult(settings: loaded.settings, now: now())
        return CalendarManualDryRunSummary(
            plannedDeletes: result.plan.deletes.count, plannedCreates: result.plan.creates.count)
    }
}
