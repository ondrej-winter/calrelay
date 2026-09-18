public struct CalendarConfigurationChangeCoordinator: Sendable {
    private var hasDeferredRefresh = false

    public init() {}

    public mutating func configurationDidChange(isOperationInProgress: Bool) -> Bool {
        guard isOperationInProgress else {
            hasDeferredRefresh = false
            return true
        }

        hasDeferredRefresh = true
        return false
    }

    public mutating func operationDidFinish() -> Bool {
        defer { hasDeferredRefresh = false }
        return hasDeferredRefresh
    }
}
