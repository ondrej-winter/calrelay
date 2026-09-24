import CalRelayKit
import Foundation

enum CalendarAccessPrivacyTests {
    static func runAll() async throws {
        try await testReadinessAndAccessFailuresOmitProtectedIdentifiersAndEventDetails()
        try await testMutationFailureOmitsProtectedIdentifiersAndEventDetails()
        try testCleanupErrorsRemainAggregateAndActionable()
    }

    // ACCESS-AC-09: readiness and access failures omit protected runtime details.
    private static func testReadinessAndAccessFailuresOmitProtectedIdentifiersAndEventDetails() async throws {
        let fixture = PrivacyAccessFixture()

        for failure in PrivacyReadFailure.allCases {
            let store = PrivacyAccessCalendarStore(fixture: fixture, failure: failure)
            let result = try await CalendarAccessPreflightUseCase(
                authorizationStatus: PrivacyAuthorizationStatus(), calendarStore: store
            ).run(settings: fixture.settings, window: fixture.window)

            guard case .failed(let issues) = result else {
                throw TestFailure("ACCESS-AC-09: Expected a privacy-safe preflight failure")
            }
            let output = issues.map(\.description).joined(separator: "\n")

            switch failure {
            case .generic:
                try expect(
                    output.contains(fixture.workSelector.sourceTitle)
                        && output.contains(fixture.workSelector.calendarTitle),
                    "ACCESS-AC-09: Readiness diagnostics may identify the configured selector")
            case .authorization:
                try expect(
                    output.contains("Enable full access for CalRelay in System Settings"),
                    "ACCESS-AC-09: Authorization failures should retain safe recovery guidance")
            }
            for forbidden in fixture.protectedRuntimeValues {
                try expect(
                    !output.contains(forbidden),
                    "ACCESS-AC-09: Readiness or access failure disclosed protected data: \(forbidden)")
            }
            try expect((await store.createdEvents()).isEmpty, "Privacy probes must not create events")
            try expect((await store.deletedEvents()).isEmpty, "Privacy probes must not delete events")
        }
    }

    // ACCESS-AC-09: partial mutation diagnostics remain aggregate and privacy-safe.
    private static func testMutationFailureOmitsProtectedIdentifiersAndEventDetails() async throws {
        let fixture = PrivacyAccessFixture()
        let event = CalendarEvent(
            id: fixture.eventID,
            calendar: CalendarIdentity(
                id: fixture.workCalendar.id, title: fixture.workCalendar.title,
                sourceTitle: fixture.workCalendar.sourceTitle),
            title: fixture.eventTitle, start: fixture.window.start, end: fixture.window.start.addingTimeInterval(600),
            isAllDay: false, availability: .busy, status: .confirmed)
        let store = PrivacyMutationFailureStore()

        do {
            _ = try await CalendarMutationExecutor(calendarStore: store).execute([
                .delete(role: fixture.workRole, event: event)
            ])
        } catch let error as CalendarMutationExecutionError {
            let output = error.description
            try expect(
                output.contains(fixture.workRole.description),
                "ACCESS-AC-09: Partial diagnostics may identify the configured role")
            try expect(output.contains("delete failed"), "Partial diagnostics should identify the failure category")
            for forbidden in fixture.protectedRuntimeValues {
                try expect(
                    !output.contains(forbidden),
                    "ACCESS-AC-09: Mutation failure disclosed protected data: \(forbidden)")
            }
            return
        }

        throw TestFailure("Expected a mutation failure")
    }

    // ACCESS-AC-09: cleanup errors disclose only aggregate actionable information.
    private static func testCleanupErrorsRemainAggregateAndActionable() throws {
        let partial = CalendarMutationPartialResult(
            confirmedCounts: [CalendarRoleMutationCounts(role: .hub, confirmedDeletes: 1, confirmedCreates: 0)],
            failedRole: .hub, failureCategory: .deleteFailed)
        let descriptions = [
            CalendarCleanupError.legacyMarkersRequired.description,
            CalendarCleanupError.mutationFailed(partial).description,
            CalendarCleanupError.verificationFoundRemainingMatches(count: 3).description
        ]

        try expect(descriptions[0].contains("legacy marker"), "Cleanup should give actionable marker guidance")
        try expect(
            descriptions[1].contains("partially applied"), "Cleanup mutation failure should report partial application")
        try expect(descriptions[2].contains("3"), "Cleanup verification should report only a remaining-match count")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct PrivacyAccessFixture {
    let eventID = "EVENT_ID_SENTINEL_PRIVACY"
    let eventTitle = "EVENT_TITLE_SENTINEL_PRIVACY"
    let hubCalendarID = "CALENDAR_ID_SENTINEL_PRIVACY_HUB"
    let workCalendarID = "CALENDAR_ID_SENTINEL_PRIVACY_WORK"
    let hubCalendar = RelayCalendar(
        id: "CALENDAR_ID_SENTINEL_PRIVACY_HUB", title: "CALENDAR_TITLE_SENTINEL_PRIVACY_HUB",
        sourceTitle: "SOURCE_SELECTOR_SENTINEL_PRIVACY_HUB", isWritable: true)
    let workCalendar = RelayCalendar(
        id: "CALENDAR_ID_SENTINEL_PRIVACY_WORK", title: "CALENDAR_TITLE_SENTINEL_PRIVACY_WORK",
        sourceTitle: "SOURCE_SELECTOR_SENTINEL_PRIVACY_WORK", isWritable: true)
    let workRole = ConfiguredCalendarRole.work(name: "Allowed Privacy Role", declarationIndex: 0)
    let window = CalendarAccessWindow(
        start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 2_000))

    var workSelector: CalendarSelector {
        CalendarSelector(sourceTitle: workCalendar.sourceTitle, calendarTitle: workCalendar.title)
    }

    var settings: CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(
                    sourceTitle: hubCalendar.sourceTitle, calendarTitle: hubCalendar.title)),
            personalPrefix: "[CURRENT_MARKER_SENTINEL_PRIVACY]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Allowed Privacy Role", prefix: "[WORK_MARKER_SENTINEL_PRIVACY]",
                    calendar: workSelector)
            ], legacyMarkers: [])
    }

    var hubEvent: CalendarEvent {
        CalendarEvent(
            id: eventID,
            calendar: CalendarIdentity(
                id: hubCalendar.id, title: hubCalendar.title, sourceTitle: hubCalendar.sourceTitle),
            title: eventTitle, start: window.start, end: window.start.addingTimeInterval(600), isAllDay: false,
            availability: .busy, status: .confirmed)
    }

    var protectedRuntimeValues: [String] {
        [eventID, eventTitle, hubCalendarID, workCalendarID]
    }
}

private enum PrivacyReadFailure: CaseIterable {
    case generic
    case authorization
}

private struct PrivacyAuthorizationStatus: CalendarAuthorizationStatusPort {
    func authorizationStatus() async -> CalendarAuthorizationState { .fullAccess }
}

private struct PrivacyStoreFailure: Error {}

private actor PrivacyAccessCalendarStore: CalendarStorePort {
    private let fixture: PrivacyAccessFixture
    private let failure: PrivacyReadFailure
    private var creates: [CalendarEventProjection] = []
    private var deletes: [CalendarEventIdentity] = []

    init(fixture: PrivacyAccessFixture, failure: PrivacyReadFailure) {
        self.fixture = fixture
        self.failure = failure
    }

    func listCalendars() async throws -> [RelayCalendar] { [fixture.hubCalendar, fixture.workCalendar] }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        if calendar.id == fixture.workCalendar.id {
            switch failure {
            case .generic: throw PrivacyStoreFailure()
            case .authorization: throw CalendarAccessError.fullAccessRequired(.denied)
            }
        }
        return [fixture.hubEvent]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { creates.append(event) }
    func deleteEvent(_ event: CalendarEventIdentity) async throws { deletes.append(event) }
    func createdEvents() -> [CalendarEventProjection] { creates }
    func deletedEvents() -> [CalendarEventIdentity] { deletes }
}

private actor PrivacyMutationFailureStore: CalendarStorePort {
    func listCalendars() async throws -> [RelayCalendar] { [] }
    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] { [] }
    func createEvent(_ event: CalendarEventProjection) async throws { throw PrivacyStoreFailure() }
    func deleteEvent(_ event: CalendarEventIdentity) async throws { throw PrivacyStoreFailure() }
}
