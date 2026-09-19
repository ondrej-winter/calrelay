public protocol CalendarAutomationStateStore: Sendable {
    func loadState() async -> CalendarAutomationPersistentState
    func saveState(_ state: CalendarAutomationPersistentState) async throws
    func updateState(
        _ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState
    ) async throws -> CalendarAutomationPersistentState
}
