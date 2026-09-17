public struct CalendarInventoryUseCase: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort

    public init(authorizationStatus: any CalendarAuthorizationStatusPort, calendarStore: any CalendarStorePort) {
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
    }

    public func run() async throws -> [RelayCalendar] {
        let state = await authorizationStatus.authorizationStatus()
        guard state == .fullAccess else { throw CalendarAccessError.fullAccessRequired(state) }

        return try await calendarStore.listCalendars()
    }
}
