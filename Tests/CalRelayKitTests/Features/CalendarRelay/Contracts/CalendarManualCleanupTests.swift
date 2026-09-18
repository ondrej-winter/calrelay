import CalRelayKit
import Foundation

enum CalendarManualCleanupTests {
    static func runAll() async throws {
        try await testReviewApplyAndOneUseConfirmation()
        try await testChangedConfigurationRequiresFreshReview()
        try await runSnapshotTests()
        try await runFailureTests()
        try await runReviewTests()
    }

    private static func testReviewApplyAndOneUseConfirmation() async throws {
        let fixture = ManualCleanupFixture()
        let store = fixture.store()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        try expect(
            review.rows.count == 1 && review.rows[0].title == "Example",
            "Review must strip the marker and show each deletion")
        try expect(await store.deletedEvents().isEmpty, "Review never mutates")
        guard case .applied(let count) = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Matching plan should apply and verify")
        }
        try expect(count == 1, "Report confirmed deletes")
        try expect(
            await store.eventRequestCalendarIDs() == [
                fixture.hub.id, fixture.work.id, fixture.hub.id, fixture.work.id, fixture.hub.id, fixture.work.id
            ], "Review, confirm and verification read the whole topology in order")
        try expect(await provider.callCount() == 3, "Reload before planning and immediately before deletion")
        try expect(await store.createdEvents().isEmpty, "Cleanup cannot create events")
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Consumed confirmation cannot be reused")
        } catch CalendarManualCleanupError.reviewRequired {}
    }

    private static func testChangedConfigurationRequiresFreshReview() async throws {
        let fixture = ManualCleanupFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let first = try await useCase.review()
        await provider.replace(fixture.settings(markers: ["[OLD]", "[OTHER]"]))
        guard case .reviewRequired(let fresh) = try await useCase.confirm(reviewID: first.id) else {
            throw TestFailure("Changed configuration requires fresh review with equal counts")
        }
        try expect(
            fresh.id != first.id && fresh.rows == first.rows,
            "Replace the confirmation token even when review rows match")
        try expect(await store.deletedEvents().isEmpty, "No deletion before fresh confirmation")
        guard case .applied = try await useCase.confirm(reviewID: fresh.id) else {
            throw TestFailure("Fresh confirmation should succeed")
        }
    }

    static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

struct ManualCleanupFixture {
    let base = ManualApplyFixture()
    var hub: RelayCalendar { base.hub }
    var work: RelayCalendar { base.work }
    var now: Date { base.now }
    var settings: CalendarRelaySettings { settings(markers: ["[OLD]"]) }
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    func settings(markers: [String]) -> CalendarRelaySettings {
        base.settingsWith(prefix: "[WORK]", legacyMarkers: markers)
    }
    func event(
        id: String = "test-legacy", calendar: RelayCalendar? = nil, title: String = "[OLD] Example", start: Date? = nil,
        occurrence: Date? = nil
    ) -> CalendarEvent {
        let target = calendar ?? hub
        return CalendarEvent(
            id: id, calendar: CalendarIdentity(id: target.id, title: target.title, sourceTitle: target.sourceTitle),
            title: title, start: start ?? now, end: (start ?? now).addingTimeInterval(100), isAllDay: false,
            availability: .busy, status: .confirmed, occurrenceDate: occurrence)
    }
    func store() -> CommandHandlerCalendarStore {
        CommandHandlerCalendarStore(calendars: [hub, work], eventsByCalendarID: [hub.id: [event()]])
    }
    func useCase(provider: any CalendarRelaySettingsProvider, store: any CalendarStorePort)
        -> CalendarManualCleanupUseCase
    {
        CalendarManualCleanupUseCase(
            settingsProvider: provider, authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            now: { now }, calendar: { calendar })
    }
}
