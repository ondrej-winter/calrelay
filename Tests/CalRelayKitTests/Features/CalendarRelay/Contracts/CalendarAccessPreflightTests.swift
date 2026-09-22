import CalRelayKit
import Foundation

enum CalendarAccessPreflightTests {
    static func runAll() async throws {
        try await testPreflightRejectsUnavailableAuthorizationBeforeStoreAccess()
        try await testPreflightAggregatesTopologyFailuresAndReadsResolvableRolesInOrder()
        try await testPreflightDoesNotUseProviderIdentifierAsSelectorFallback()
        try await testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation()
        try await testPreflightReportsAuthorizationLossDuringInventory()
    }

    private static func testPreflightRejectsUnavailableAuthorizationBeforeStoreAccess() async throws {
        let authorization = PreflightAuthorizationStatus(state: .writeOnly)
        let store = PreflightCalendarStore(calendars: readyCalendars())
        let useCase = CalendarAccessPreflightUseCase(authorizationStatus: authorization, calendarStore: store)

        let result = try await useCase.run(settings: settings(), window: window())

        try expect(
            result == .failed([.authorizationUnavailable(.writeOnly)]),
            "Preflight should reject write-only authorization")
        try expect(
            await store.listCalendarsCallCount() == 0, "Unavailable authorization should prevent inventory access")
        try expect(
            (await store.eventRequestCalendarIDs()).isEmpty, "Unavailable authorization should prevent event reads")
    }

    private static func testPreflightAggregatesTopologyFailuresAndReadsResolvableRolesInOrder() async throws {
        let sharedHub = RelayCalendar(id: "shared", title: "Hub", sourceTitle: "iCloud", isWritable: false)
        let sharedWork = RelayCalendar(id: "shared", title: "ACME Work", sourceTitle: "Google", isWritable: false)
        let ambiguousOne = RelayCalendar(
            id: "ambiguous-1", title: "Beta Work", sourceTitle: "Exchange", isWritable: true)
        let ambiguousTwo = RelayCalendar(
            id: "ambiguous-2", title: "Beta Work", sourceTitle: "Exchange", isWritable: false)
        let broken = RelayCalendar(id: "broken", title: "Gamma Work", sourceTitle: "CalDAV", isWritable: true)
        let ready = RelayCalendar(id: "ready", title: "Delta Work", sourceTitle: "Local", isWritable: true)
        let store = PreflightCalendarStore(
            calendars: [sharedHub, sharedWork, ambiguousOne, ambiguousTwo, broken, ready],
            readFailureCalendarIDs: [PhysicalCalendarReference(providerIdentifier: "broken")])
        let useCase = CalendarAccessPreflightUseCase(
            authorizationStatus: PreflightAuthorizationStatus(state: .fullAccess), calendarStore: store)

        let result = try await useCase.run(settings: failingSettings(), window: window())

        guard case .failed(let issues) = result else { throw TestFailure("Expected aggregate preflight failure") }

        try expect(
            issues.contains(
                .calendarMissing(
                    role: .work(name: "Missing", declarationIndex: 1), selector: selector("Missing", "Absent"))),
            "Preflight should report a missing role")
        try expect(
            issues.contains(
                .calendarAmbiguous(
                    role: .work(name: "Beta", declarationIndex: 2), selector: selector("Exchange", "Beta Work"))),
            "Preflight should report an ambiguous role")
        try expect(
            issues.contains(.physicalCalendarCollision(roles: [.hub, .work(name: "ACME", declarationIndex: 0)])),
            "Preflight should report roles resolving to the same physical calendar")
        try expect(
            issues.contains(.calendarReadOnly(role: .hub, selector: selector("iCloud", "Hub"))),
            "Preflight should report a read-only hub")
        try expect(
            issues.contains(
                .calendarReadOnly(
                    role: .work(name: "ACME", declarationIndex: 0), selector: selector("Google", "ACME Work"))),
            "Preflight should report a read-only work calendar")
        try expect(
            issues.contains(
                .eventReadFailed(
                    role: .work(name: "Gamma", declarationIndex: 3), selector: selector("CalDAV", "Gamma Work"))),
            "Preflight should report a role read failure")
        try expect(
            await store.eventRequestCalendarIDs() == [
                PhysicalCalendarReference(providerIdentifier: "shared"),
                PhysicalCalendarReference(providerIdentifier: "shared"),
                PhysicalCalendarReference(providerIdentifier: "broken"),
                PhysicalCalendarReference(providerIdentifier: "ready")
            ], "Preflight should read every uniquely resolved role hub-first and then in declaration order")
        try expect(await store.mutationCount() == 0, "Preflight must never mutate as a capability probe")
    }

    private static func testPreflightDoesNotUseProviderIdentifierAsSelectorFallback() async throws {
        let calendars = [
            RelayCalendar(id: "Hub", title: "Renamed Hub", sourceTitle: "Other", isWritable: true),
            RelayCalendar(id: "ACME Work", title: "Renamed Work", sourceTitle: "Other", isWritable: true)
        ]
        let store = PreflightCalendarStore(calendars: calendars)
        let useCase = CalendarAccessPreflightUseCase(
            authorizationStatus: PreflightAuthorizationStatus(state: .fullAccess), calendarStore: store)

        let result = try await useCase.run(settings: settings(), window: window())

        let expected: [CalendarAccessPreflightIssue] = [
            .calendarMissing(role: .hub, selector: selector("iCloud", "Hub")),
            .calendarMissing(role: .work(name: "ACME", declarationIndex: 0), selector: selector("Google", "ACME Work"))
        ]
        try expect(result == .failed(expected), "Provider identifiers must not act as selector fallbacks")
        try expect(
            (await store.eventRequestCalendarIDs()).isEmpty,
            "Roles missing by exact source/title matching should not be read through provider identifiers")
        try expect(await store.mutationCount() == 0, "Selector resolution failure must remain non-mutating")
    }

    private static func testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation() async throws {
        let calendars = readyCalendars()
        let event = CalendarEvent(
            id: "event-1", calendar: identity(calendars[1]), title: "Planning",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 3_000), isAllDay: false,
            availability: .busy, status: .confirmed)
        let store = PreflightCalendarStore(calendars: calendars, eventsByCalendarID: [calendars[1].id: [event]])
        let useCase = CalendarAccessPreflightUseCase(
            authorizationStatus: PreflightAuthorizationStatus(state: .fullAccess), calendarStore: store)

        let result = try await useCase.run(settings: settings(), window: window())

        guard case .ready(let snapshot) = result else { throw TestFailure("Expected ready preflight snapshot") }

        try expect(
            snapshot.calendars.map(\.role) == [.hub, .work(name: "ACME", declarationIndex: 0)],
            "Ready snapshot should preserve configured role order")
        try expect(snapshot.calendars[0].events.isEmpty, "Ready snapshot should contain the hub events")
        try expect(snapshot.calendars[1].events == [event], "Ready snapshot should contain work-calendar events")
        try expect(
            await store.eventRequestCalendarIDs() == [
                PhysicalCalendarReference(providerIdentifier: "hub"),
                PhysicalCalendarReference(providerIdentifier: "work")
            ], "Ready reads should be hub-first")
        try expect(
            await store.eventRequestWindows() == [window(), window()],
            "Every role should use the same captured access window")
        try expect(await store.mutationCount() == 0, "Successful preflight should remain non-mutating")
    }

    private static func testPreflightReportsAuthorizationLossDuringInventory() async throws {
        let authorization = PreflightAuthorizationStatus(state: .fullAccess)
        let store = AuthorizationFailureCalendarStore(state: .denied)
        let useCase = CalendarAccessPreflightUseCase(authorizationStatus: authorization, calendarStore: store)

        let result = try await useCase.run(settings: settings(), window: window())

        try expect(
            result == .failed([.authorizationUnavailable(.denied)]),
            "Preflight should preserve actionable authorization loss")
    }

    private static func settings() -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: selector("iCloud", "Hub")), personalPrefix: "[ME]",
            syncWindowDays: 100,
            workCalendars: [
                WorkCalendarSettings(name: "ACME", prefix: "[ACME]", calendar: selector("Google", "ACME Work"))
            ])
    }

    private static func failingSettings() -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: selector("iCloud", "Hub")), personalPrefix: "[ME]",
            syncWindowDays: 100,
            workCalendars: [
                WorkCalendarSettings(name: "ACME", prefix: "[ACME]", calendar: selector("Google", "ACME Work")),
                WorkCalendarSettings(name: "Missing", prefix: "[MISSING]", calendar: selector("Missing", "Absent")),
                WorkCalendarSettings(name: "Beta", prefix: "[BETA]", calendar: selector("Exchange", "Beta Work")),
                WorkCalendarSettings(name: "Gamma", prefix: "[GAMMA]", calendar: selector("CalDAV", "Gamma Work")),
                WorkCalendarSettings(name: "Delta", prefix: "[DELTA]", calendar: selector("Local", "Delta Work"))
            ])
    }

    private static func readyCalendars() -> [RelayCalendar] {
        [
            RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true),
            RelayCalendar(id: "work", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        ]
    }

    private static func selector(_ sourceTitle: String, _ calendarTitle: String) -> CalendarSelector {
        CalendarSelector(sourceTitle: sourceTitle, calendarTitle: calendarTitle)
    }

    private static func identity(_ calendar: RelayCalendar) -> CalendarIdentity {
        CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle)
    }

    private static func window() -> CalendarAccessWindow {
        CalendarAccessWindow(start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 100_000))
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct PreflightAuthorizationStatus: CalendarAuthorizationStatusPort {
    let state: CalendarAuthorizationState

    func authorizationStatus() async -> CalendarAuthorizationState { state }
}

private struct PreflightStoreFailure: Error {}

private struct AuthorizationFailureCalendarStore: CalendarStorePort {
    let state: CalendarAuthorizationState

    func listCalendars() async throws -> [RelayCalendar] { throw CalendarAccessError.fullAccessRequired(state) }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] { [] }

    func createEvent(_ event: CalendarEventProjection) async throws {}

    func deleteEvent(_ event: CalendarEventIdentity) async throws {}
}

private actor PreflightCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]
    private let readFailureCalendarIDs: Set<PhysicalCalendarReference>
    private var listCalls = 0
    private var eventRequests: [(calendarID: PhysicalCalendarReference, window: CalendarAccessWindow)] = []
    private var creates = 0
    private var deletes = 0

    init(
        calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]] = [:],
        readFailureCalendarIDs: Set<PhysicalCalendarReference> = []
    ) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
        self.readFailureCalendarIDs = readFailureCalendarIDs
    }

    func listCalendars() async throws -> [RelayCalendar] {
        listCalls += 1
        return calendars
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventRequests.append((calendar.id, CalendarAccessWindow(start: start, end: end)))
        if readFailureCalendarIDs.contains(calendar.id) { throw PreflightStoreFailure() }
        return eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { creates += 1 }

    func deleteEvent(_ event: CalendarEventIdentity) async throws { deletes += 1 }

    func listCalendarsCallCount() -> Int { listCalls }

    func eventRequestCalendarIDs() -> [PhysicalCalendarReference] { eventRequests.map(\.calendarID) }

    func eventRequestWindows() -> [CalendarAccessWindow] { eventRequests.map(\.window) }

    func mutationCount() -> Int { creates + deletes }
}
