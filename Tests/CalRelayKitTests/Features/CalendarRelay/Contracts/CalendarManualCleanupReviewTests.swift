import CalRelayKit
import Foundation

extension CalendarManualCleanupTests {
    static func runReviewTests() async throws {
        try await testReviewPrivacyAndExecutionOrder()
        try await testEmptyPlanStillVerifiesAndSemanticSettingsMatch()
        try await testConcurrentConfirmationAndReviewAreRejected()
    }

    private static func testReviewPrivacyAndExecutionOrder() async throws {
        let fixture = ManualCleanupFixture()
        let allDay = CalendarEvent(
            id: "all-day-id",
            calendar: CalendarIdentity(
                id: fixture.work.id, title: fixture.work.title, sourceTitle: fixture.work.sourceTitle),
            title: "[OLD] All day example", start: fixture.calendar.startOfDay(for: fixture.now),
            end: fixture.calendar.startOfDay(for: fixture.now).addingTimeInterval(86_400), isAllDay: true,
            availability: .busy, status: .confirmed)
        let store = CommandHandlerCalendarStore(
            calendars: [fixture.hub, fixture.work],
            eventsByCalendarID: [
                fixture.hub.id: [
                    fixture.event(id: "later", title: "[OLD] Later", start: fixture.now.addingTimeInterval(200)),
                    fixture.event()
                ], fixture.work.id: [allDay]
            ])
        let settings = fixture.base.settingsWith(prefix: "[WORK]", name: "Work role", legacyMarkers: ["[OLD]"])
        let useCase = fixture.useCase(provider: ManualApplySettingsProvider(settings: settings), store: store)
        let review = try await useCase.review()
        try expect(
            review.rows.map(\.title) == ["Example", "Later", "All day example"],
            "Review rows must be in hub-first execution order")
        try expect(
            review.window == LegacyCleanupWindow.calculate(referenceDate: fixture.now, calendar: fixture.calendar),
            "Review must disclose the complete captured cleanup range")
        let output = CalendarManualCleanupFormatter.formatReview(review)
        try expect(
            output.contains("Selected deletions: 3") && output.contains("Work role")
                && output.contains("all-day dates; end exclusive"),
            "Review includes count, configured roles and explicit all-day interval semantics")
        for forbidden in [
            "test-legacy", "all-day-id", "test-hub", "test-work", "Test Hub", "Test Work", "Test Source", "[OLD]",
            "[WORK]"
        ] { try expect(!output.contains(forbidden), "Review must omit IDs, calendar names, selectors and markers") }
        let success = CalendarManualCleanupFormatter.formatSuccess(confirmedDeletions: 3)
        try expect(
            success.contains("point-in-time") && success.contains("Remove legacyMarkers manually"),
            "Verified cleanup must not claim global retirement or automatic YAML editing")
        try expect(
            !success.contains("Example") && !success.contains("Work role"), "Completion retains no review details")
    }

    private static func testEmptyPlanStillVerifiesAndSemanticSettingsMatch() async throws {
        let fixture = ManualCleanupFixture()
        let first = fixture.settings(markers: ["[OLD]", "[OTHER]"])
        let renamed = fixture.base.settingsWith(
            prefix: "[WORK]", name: "Renamed role", legacyMarkers: ["[OTHER]", "[OLD]"])
        let provider = CleanupSequenceSettingsProvider(loads: [.success(first), .success(renamed), .success(first)])
        let store = CommandHandlerCalendarStore(calendars: [fixture.hub, fixture.work])
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        guard case .applied(confirmedDeletions: 0) = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Role-name and marker-set order changes must not invalidate semantic confirmation")
        }
        try expect(
            await store.eventRequestCalendarIDs().count == 6, "Even an empty cleanup requires full-range verification")
        try expect(await store.deletedEvents().isEmpty, "Empty cleanup performs no deletion")
    }

    private static func testConcurrentConfirmationAndReviewAreRejected() async throws {
        let fixture = ManualCleanupFixture()
        let provider = PausingCleanupSettingsProvider(settings: fixture.settings)
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        let first = Task { try await useCase.confirm(reviewID: review.id) }
        await provider.waitUntilPaused()
        var confirmBlocked = false
        var reviewBlocked = false
        do { _ = try await useCase.confirm(reviewID: review.id) } catch CalendarManualCleanupError.operationInProgress {
            confirmBlocked = true
        }
        do { _ = try await useCase.review() } catch CalendarManualCleanupError.operationInProgress {
            reviewBlocked = true
        }
        await provider.resume()
        _ = try await first.value
        try expect(confirmBlocked && reviewBlocked, "Actor reentrancy must not permit overlapping review or mutation")
        try expect(await store.deletedEvents().count == 1, "Concurrent triggers must not duplicate deletion")
    }
}

private actor PausingCleanupSettingsProvider: CalendarRelaySettingsProvider {
    let settings: CalendarRelaySettings
    private var calls = 0
    private var paused: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    init(settings: CalendarRelaySettings) { self.settings = settings }
    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        if calls == 2 {
            await withCheckedContinuation { continuation in
                paused = continuation
                observer?.resume()
                observer = nil
            }
        }
        return LoadedCalendarRelaySettings(displayPath: "test", settings: settings)
    }
    func waitUntilPaused() async {
        if paused != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func resume() {
        paused?.resume()
        paused = nil
    }
}
