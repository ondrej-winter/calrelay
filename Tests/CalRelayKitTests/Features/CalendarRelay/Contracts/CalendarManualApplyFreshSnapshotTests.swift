import CalRelayKit
import Foundation

extension CalendarManualApplyTests {
    static func runFreshSnapshotTests() async throws {
        for change in [ManualSnapshotChange.title, .physicalCalendar, .occurrence, .eventReference] {
            let fixture = ManualApplyFixture()
            let provider = ManualApplySettingsProvider(settings: fixture.settings)
            let store = ChangingManualSnapshotStore(fixture: fixture, change: change)
            let useCase = fixture.useCase(provider: provider, store: store)
            let review = try await useCase.review()
            guard case .reviewRequired(let fresh) = try await useCase.confirm(reviewID: review.id) else {
                throw TestFailure("Changed snapshot executable identity must require review")
            }
            try expect(fresh.summary == review.summary, "Snapshot changes can preserve aggregate counts")
            try expect(await store.mutationCount() == 0, "Changed snapshot must not mutate under old confirmation")
        }
        try await testRationaleOnlySnapshotChangeUsesFreshActions()
        try await testConfirmationPreflightFailureConsumesReview()
    }

    private static func testRationaleOnlySnapshotChangeUsesFreshActions() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = ChangingManualSnapshotStore(fixture: fixture, change: .rationale)
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        guard case .applied(let result) = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Rationale-only changes must not invalidate exact executable identity")
        }
        try expect(result.confirmedActionCount == 1, "Only the same exact stale occurrence should be deleted")
        try expect(
            await store.deletedLookupStart() == fixture.now.addingTimeInterval(-200),
            "Apply must use fresh occurrence lookup data, not retained snapshot data")
    }

    private static func testConfirmationPreflightFailureConsumesReview() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = ChangingManualSnapshotStore(fixture: fixture, change: .readOnly)
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Changed writability must fail fresh preflight")
        } catch ReconcileCalendarsError.accessPreflightFailed {}
        try expect(await store.mutationCount() == 0, "Failed topology must prevent all mutations")
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("A failed preflight must consume old authorization")
        } catch CalendarManualApplyError.reviewRequired {}
    }
}

private enum ManualSnapshotChange: Sendable {
    case title, physicalCalendar, occurrence, eventReference, rationale, readOnly
}

private actor ChangingManualSnapshotStore: CalendarStorePort {
    let fixture: ManualApplyFixture
    let change: ManualSnapshotChange
    private var reads = 0
    private var mutations = 0
    private var lookupStart: Date?

    init(fixture: ManualApplyFixture, change: ManualSnapshotChange) {
        self.fixture = fixture
        self.change = change
    }

    func listCalendars() async throws -> [RelayCalendar] {
        reads += 1
        let hub = RelayCalendar(
            id: reads > 1 && change == .physicalCalendar ? "replacement-hub" : "test-hub", title: fixture.hub.title,
            sourceTitle: fixture.hub.sourceTitle, isWritable: !(reads > 1 && change == .readOnly))
        return [hub, fixture.work]
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        let isDelete = change == .occurrence || change == .eventReference || change == .rationale
        guard isDelete ? calendar.id != fixture.work.id : calendar.id == fixture.work.id else { return [] }
        return [
            CalendarEvent(
                id: reads > 1 && change == .eventReference ? "replacement-event" : "test-event", calendar: calendar,
                title: isDelete ? "[WORK] Stale" : (reads > 1 && change == .title ? "Changed" : "Example"),
                start: fixture.now, end: fixture.now.addingTimeInterval(100), isAllDay: false, availability: .busy,
                status: reads > 1 && change == .rationale ? .cancelled : .confirmed,
                occurrenceDate: fixture.now.addingTimeInterval(reads > 1 && change == .occurrence ? 1 : 0),
                occurrenceLookupStart: fixture.now.addingTimeInterval(reads > 1 ? -200 : -100),
                occurrenceLookupEnd: fixture.now.addingTimeInterval(200))
        ]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { mutations += 1 }
    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        mutations += 1
        lookupStart = event.lookupStart
    }
    func mutationCount() -> Int { mutations }
    func deletedLookupStart() -> Date? { lookupStart }
}
