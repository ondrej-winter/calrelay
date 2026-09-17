import CalRelayKit
import Foundation

enum CalendarAuthorizationTests {
    static func runAll() async throws {
        try await testSetupRequestsOnlyWhenAuthorizationIsNotDetermined()
        try await testSetupDoesNotRequestForSettledAuthorizationStates()
        try await testInventoryRequiresFullAccessWithoutRequesting()
        try await testInventoryReturnsEmptySuccessfulInventory()
        try testOpaqueProviderReferencesPreserveIdentityWithoutStringExposure()
        try testExactOccurrenceSelectionUsesOriginalOccurrenceDate()
        try testExactOccurrenceSelectionRejectsAmbiguousCandidates()
    }

    private static func testSetupRequestsOnlyWhenAuthorizationIsNotDetermined() async throws {
        let authorization = FakeCalendarAuthorization(state: .notDetermined, stateAfterRequest: .fullAccess)
        let useCase = CalendarAccessSetupUseCase(authorizationStatus: authorization, fullAccessRequester: authorization)

        let result = try await useCase.run()

        try expect(
            result.authorizationState == .fullAccess, "Setup should report the authorization state after requesting")
        try expect(result.didRequestAccess, "Setup should report that it requested access")
        try expect(await authorization.requestCount() == 1, "Setup should request once when access is not determined")
    }

    private static func testSetupDoesNotRequestForSettledAuthorizationStates() async throws {
        for state in CalendarAuthorizationState.allCases where state != .notDetermined {
            let authorization = FakeCalendarAuthorization(state: state, stateAfterRequest: .fullAccess)
            let result = try await CalendarAccessSetupUseCase(
                authorizationStatus: authorization, fullAccessRequester: authorization
            ).run()

            try expect(result.authorizationState == state, "Setup should preserve the settled authorization state")
            try expect(!result.didRequestAccess, "Setup should not request for a settled authorization state")
            try expect(await authorization.requestCount() == 0, "Settled authorization should not trigger a request")
        }
    }

    private static func testInventoryRequiresFullAccessWithoutRequesting() async throws {
        let authorization = FakeCalendarAuthorization(state: .denied, stateAfterRequest: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: [calendar()])
        let useCase = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: store)

        do { _ = try await useCase.run() } catch let error as CalendarAccessError {
            try expect(
                error == .fullAccessRequired(.denied), "Inventory should report the unavailable authorization state")
            try expect(await authorization.requestCount() == 0, "Inventory must never request Calendar access")
            try expect(
                await store.listCalendarsCallCount() == 0, "Inventory should not query calendars without full access")
            return
        }

        throw TestFailure("Expected inventory to require pre-existing full access")
    }

    private static func testInventoryReturnsEmptySuccessfulInventory() async throws {
        let authorization = FakeCalendarAuthorization(state: .fullAccess, stateAfterRequest: .fullAccess)
        let store = CommandHandlerCalendarStore(calendars: [])

        let calendars = try await CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: store)
            .run()

        try expect(calendars.isEmpty, "An empty EventKit inventory should be a successful result")
        try expect(await store.listCalendarsCallCount() == 1, "Full-access inventory should query the store once")
    }

    private static func testOpaqueProviderReferencesPreserveIdentityWithoutStringExposure() throws {
        let firstCalendar = PhysicalCalendarReference(providerIdentifier: "calendar-1")
        let sameCalendar = PhysicalCalendarReference(providerIdentifier: "calendar-1")
        let otherCalendar = PhysicalCalendarReference(providerIdentifier: "calendar-2")
        let firstEvent = CalendarEventReference(providerIdentifier: "event-1")
        let sameEvent = CalendarEventReference(providerIdentifier: "event-1")

        try expect(
            firstCalendar == sameCalendar, "Equal provider calendar identifiers should produce equal opaque references")
        try expect(firstCalendar != otherCalendar, "Different physical calendars should remain distinct")
        try expect(firstEvent == sameEvent, "Equal provider event identifiers should produce equal opaque references")
        try expect(
            !String(describing: firstCalendar).contains("calendar-1"),
            "Physical calendar references should not expose provider identifiers through descriptions")
        try expect(
            !String(describing: firstEvent).contains("event-1"),
            "Event references should not expose provider identifiers through descriptions")
    }

    private static func testExactOccurrenceSelectionUsesOriginalOccurrenceDate() throws {
        let occurrenceDate = Date(timeIntervalSince1970: 10_000)
        let identity = CalendarEventIdentity(
            id: "series-1", calendar: calendarIdentity(), occurrenceDate: occurrenceDate,
            lookupStart: Date(timeIntervalSince1970: 1_000), lookupEnd: Date(timeIntervalSince1970: 100_000))
        let candidates = [
            EventKitEventOccurrenceCandidate(
                id: "series-1", calendarID: "calendar-1", occurrenceDate: Date(timeIntervalSince1970: 9_000)),
            EventKitEventOccurrenceCandidate(id: "series-1", calendarID: "calendar-1", occurrenceDate: occurrenceDate)
        ]

        let matches = EventKitExactEventOccurrenceSelector.matchingCandidateIndices(for: identity, in: candidates)

        try expect(matches == [1], "Detached occurrence lookup should use the stable original occurrence date")
    }

    private static func testExactOccurrenceSelectionRejectsAmbiguousCandidates() throws {
        let occurrenceDate = Date(timeIntervalSince1970: 10_000)
        let identity = CalendarEventIdentity(
            id: "series-1", calendar: calendarIdentity(), occurrenceDate: occurrenceDate,
            lookupStart: Date(timeIntervalSince1970: 1_000), lookupEnd: Date(timeIntervalSince1970: 100_000))
        let candidate = EventKitEventOccurrenceCandidate(
            id: "series-1", calendarID: "calendar-1", occurrenceDate: occurrenceDate)

        let matches = EventKitExactEventOccurrenceSelector.matchingCandidateIndices(
            for: identity, in: [candidate, candidate])

        try expect(matches.count == 2, "The adapter should be able to detect an ambiguous exact occurrence lookup")
    }

    private static func calendar() -> RelayCalendar {
        RelayCalendar(id: "calendar-1", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
    }

    private static func calendarIdentity() -> CalendarIdentity {
        CalendarIdentity(id: "calendar-1", title: "Personal Work", sourceTitle: "iCloud")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private actor FakeCalendarAuthorization: CalendarAuthorizationStatusPort, CalendarFullAccessRequestPort {
    private var state: CalendarAuthorizationState
    private let stateAfterRequest: CalendarAuthorizationState
    private var requests = 0

    init(state: CalendarAuthorizationState, stateAfterRequest: CalendarAuthorizationState) {
        self.state = state
        self.stateAfterRequest = stateAfterRequest
    }

    func authorizationStatus() async -> CalendarAuthorizationState { state }

    func requestFullAccess() async throws -> Bool {
        requests += 1
        state = stateAfterRequest
        return state == .fullAccess
    }

    func requestCount() -> Int { requests }
}
