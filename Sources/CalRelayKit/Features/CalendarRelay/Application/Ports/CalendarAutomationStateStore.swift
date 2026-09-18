public protocol CalendarAutomationStateStore: Sendable {
    func loadState() async -> CalendarAutomationPersistentState
    func saveState(_ state: CalendarAutomationPersistentState) async throws
}
