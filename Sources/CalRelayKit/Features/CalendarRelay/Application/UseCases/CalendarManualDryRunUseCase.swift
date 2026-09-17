import Foundation

public struct CalendarManualDryRunUseCase: Sendable {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let reconciliation: ReconcileCalendarsUseCase
    private let now: @Sendable () -> Date

    public init(
        settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.settingsProvider = settingsProvider
        reconciliation = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)
        self.now = now
    }

    public func run() async throws -> CalendarManualDryRunSummary {
        let loaded = try await settingsProvider.loadSettings()
        let result = try await reconciliation.dryRunResult(settings: loaded.settings, now: now())
        return CalendarManualDryRunSummary(
            plannedDeletes: result.plan.deletes.count, plannedCreates: result.plan.creates.count)
    }
}
