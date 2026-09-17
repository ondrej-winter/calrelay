public protocol CalendarRelaySettingsProvider: Sendable {
    func loadSettings() async throws -> LoadedCalendarRelaySettings
}
