public struct CalendarAccessSetupUseCase: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let fullAccessRequester: any CalendarFullAccessRequestPort

    public init(
        authorizationStatus: any CalendarAuthorizationStatusPort, fullAccessRequester: any CalendarFullAccessRequestPort
    ) {
        self.authorizationStatus = authorizationStatus
        self.fullAccessRequester = fullAccessRequester
    }

    public func run() async throws -> CalendarAccessSetupResult {
        let initialState = await authorizationStatus.authorizationStatus()
        guard initialState == .notDetermined else {
            return CalendarAccessSetupResult(authorizationState: initialState, didRequestAccess: false)
        }

        _ = try await fullAccessRequester.requestFullAccess()
        return CalendarAccessSetupResult(
            authorizationState: await authorizationStatus.authorizationStatus(), didRequestAccess: true)
    }
}
