import CalRelayKit
import Foundation

extension CalendarManualCleanupTests {
    static func runSnapshotTests() async throws {
        for change in [CleanupSnapshotChange.calendar, .event, .occurrence, .order] {
            let fixture = ManualCleanupFixture()
            let store = ChangingCleanupSnapshotStore(fixture: fixture, change: change)
            let useCase = fixture.useCase(
                provider: ManualApplySettingsProvider(settings: fixture.settings), store: store)
            let review = try await useCase.review()
            guard case .reviewRequired(let fresh) = try await useCase.confirm(reviewID: review.id) else {
                throw TestFailure("Same-count cleanup target/order changes must require new review")
            }
            try expect(fresh.rows.count == review.rows.count && fresh.id != review.id, "Replace token, not just counts")
            try expect(await store.deletions().isEmpty, "Changed ordered actions must never use old confirmation")
            guard case .applied(let count) = try await useCase.confirm(reviewID: fresh.id) else {
                throw TestFailure("Freshly reviewed cleanup plan should apply")
            }
            try expect(count == fresh.rows.count, "Every confirmed deletion is counted")
        }
        try await testRationaleChangeUsesFreshLookupData()
    }

    private static func testRationaleChangeUsesFreshLookupData() async throws {
        let fixture = ManualCleanupFixture()
        let store = ChangingCleanupSnapshotStore(fixture: fixture, change: .rationale)
        let useCase = fixture.useCase(provider: ManualApplySettingsProvider(settings: fixture.settings), store: store)
        let review = try await useCase.review()
        guard case .applied = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Diagnostic changes must not invalidate unchanged executable actions")
        }
        try expect(
            await store.deletions().first?.lookupStart == fixture.now.addingTimeInterval(-200),
            "Deletion must use fresh lookup data")
    }
}

private enum CleanupSnapshotChange: Sendable { case calendar, event, occurrence, order, rationale }

private actor ChangingCleanupSnapshotStore: CalendarStorePort {
    let fixture: ManualCleanupFixture
    let change: CleanupSnapshotChange
    private var snapshots = 0
    private var deleted: [CalendarEventIdentity] = []

    init(fixture: ManualCleanupFixture, change: CleanupSnapshotChange) {
        self.fixture = fixture
        self.change = change
    }

    func listCalendars() async throws -> [RelayCalendar] {
        snapshots += 1
        let hub = RelayCalendar(
            id: snapshots > 1 && change == .calendar ? "replacement-hub" : "test-hub", title: fixture.hub.title,
            sourceTitle: fixture.hub.sourceTitle, isWritable: true)
        return [hub, fixture.work]
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        guard calendar.id != fixture.work.id, deleted.isEmpty else { return [] }
        let changed = snapshots > 1
        let first = CalendarEvent(
            id: changed && change == .event ? "replacement-event" : "first", calendar: calendar, title: "[OLD] Example",
            start: fixture.now.addingTimeInterval(changed && change == .order ? 300 : 0),
            end: fixture.now.addingTimeInterval(changed && change == .order ? 400 : 100), isAllDay: false,
            availability: .busy, status: changed && change == .rationale ? .cancelled : .confirmed,
            occurrenceDate: fixture.now.addingTimeInterval(changed && change == .occurrence ? 1 : 0),
            occurrenceLookupStart: fixture.now.addingTimeInterval(changed ? -200 : -100),
            occurrenceLookupEnd: fixture.now.addingTimeInterval(500))
        guard change == .order else { return [first] }
        return [first, fixture.event(id: "second", start: fixture.now.addingTimeInterval(200))]
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws { deleted.append(event) }
    func createEvent(_ event: CalendarEventProjection) async throws { throw TestFailure("Cleanup must never create") }
    func deletions() -> [CalendarEventIdentity] { deleted }
}
