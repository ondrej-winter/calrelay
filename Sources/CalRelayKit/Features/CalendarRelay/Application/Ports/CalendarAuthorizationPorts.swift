public protocol CalendarAuthorizationStatusPort: Sendable {
    func authorizationStatus() async -> CalendarAuthorizationState
}

public protocol CalendarFullAccessRequestPort: Sendable { func requestFullAccess() async throws -> Bool }
