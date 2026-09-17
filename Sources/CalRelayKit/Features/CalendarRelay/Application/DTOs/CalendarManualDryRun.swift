public struct CalendarManualDryRunSummary: Equatable, Sendable {
    public let plannedDeletes: Int
    public let plannedCreates: Int

    public init(plannedDeletes: Int, plannedCreates: Int) {
        self.plannedDeletes = plannedDeletes
        self.plannedCreates = plannedCreates
    }
}
