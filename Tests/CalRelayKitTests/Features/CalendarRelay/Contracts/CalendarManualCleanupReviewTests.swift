import CalRelayKit
import Foundation

extension CalendarManualCleanupTests {
    static func runReviewTests() async throws {
        try await testReviewPrivacyAndExecutionOrder()
        try await testEmptyPlanStillVerifiesAndSemanticSettingsMatch()
        try await testConcurrentConfirmationAndReviewAreRejected()
    }

    private static func testReviewPrivacyAndExecutionOrder() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar
        }()
        let hub = RelayCalendar(
            id: "CALENDAR_ID_SENTINEL_CLEANUP_HUB", title: "CALENDAR_TITLE_SENTINEL_CLEANUP_HUB",
            sourceTitle: "SOURCE_SELECTOR_SENTINEL_CLEANUP_HUB", isWritable: true)
        let work = RelayCalendar(
            id: "CALENDAR_ID_SENTINEL_CLEANUP_WORK", title: "CALENDAR_TITLE_SENTINEL_CLEANUP_WORK",
            sourceTitle: "SOURCE_SELECTOR_SENTINEL_CLEANUP_WORK", isWritable: true)
        let legacyMarker = "[LEGACY_MARKER_SENTINEL_CLEANUP]"
        let currentMarker = "[CURRENT_MARKER_SENTINEL_CLEANUP]"
        let roleName = "Approved Cleanup Role"
        let hubIdentity = CalendarIdentity(id: hub.id, title: hub.title, sourceTitle: hub.sourceTitle)
        let workIdentity = CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle)
        let timedTitle = "EVENT_TITLE_SENTINEL_CLEANUP_TIMED"
        let laterTitle = "EVENT_TITLE_SENTINEL_CLEANUP_LATER"
        let allDayTitle = "EVENT_TITLE_SENTINEL_CLEANUP_ALL_DAY"
        let allDayStart = calendar.startOfDay(for: now)
        let eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]] = [
            hub.id: [
                CalendarEvent(
                    id: "EVENT_ID_SENTINEL_CLEANUP_LATER", calendar: hubIdentity,
                    title: "\(legacyMarker) \(laterTitle)", start: now.addingTimeInterval(200),
                    end: now.addingTimeInterval(300), isAllDay: false, availability: .busy, status: .confirmed),
                CalendarEvent(
                    id: "EVENT_ID_SENTINEL_CLEANUP_TIMED", calendar: hubIdentity,
                    title: "\(legacyMarker) \(timedTitle)", start: now, end: now.addingTimeInterval(100),
                    isAllDay: false, availability: .busy, status: .confirmed)
            ],
            work.id: [
                CalendarEvent(
                    id: "EVENT_ID_SENTINEL_CLEANUP_ALL_DAY", calendar: workIdentity,
                    title: "\(legacyMarker) \(allDayTitle)", start: allDayStart,
                    end: allDayStart.addingTimeInterval(86_400), isAllDay: true, availability: .busy,
                    status: .confirmed)
            ]
        ]
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL_MARKER_SENTINEL_CLEANUP]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: roleName, prefix: currentMarker,
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: [legacyMarker])
        let store = CommandHandlerCalendarStore(
            calendars: [hub, work], eventsByCalendarID: eventsByCalendarID)
        let useCase = CalendarManualCleanupUseCase(
            settingsProvider: ManualApplySettingsProvider(settings: settings),
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { now },
            calendar: { calendar })

        let review = try await useCase.review()

        try expect(
            review.rows.map(\.title) == [timedTitle, laterTitle, allDayTitle],
            "Review rows must be in hub-first execution order")
        try expect(
            review.window == LegacyCleanupWindow.calculate(referenceDate: now, calendar: calendar),
            "Review must disclose the complete captured cleanup range")
        let output = CalendarManualCleanupFormatter.formatReview(review)
        for approved in [timedTitle, laterTitle, allDayTitle, roleName, "time range", "all-day dates; end exclusive"] {
            try expect(output.contains(approved), "Cleanup review should include approved detail: \(approved)")
        }
        try expect(output.contains("Selected deletions: 3"), "Cleanup review should include the selected count")
        let prohibited = [
            "EVENT_ID_SENTINEL_CLEANUP_TIMED", "EVENT_ID_SENTINEL_CLEANUP_LATER",
            "EVENT_ID_SENTINEL_CLEANUP_ALL_DAY", "CALENDAR_ID_SENTINEL_CLEANUP_HUB",
            "CALENDAR_ID_SENTINEL_CLEANUP_WORK", hub.title, work.title, hub.sourceTitle, work.sourceTitle,
            legacyMarker, currentMarker, "PERSONAL_MARKER_SENTINEL_CLEANUP"
        ]
        for forbidden in prohibited {
            try expect(!output.contains(forbidden), "Cleanup review must omit prohibited detail: \(forbidden)")
        }

        let success = CalendarManualCleanupFormatter.formatSuccess(confirmedDeletions: 3)
        try expectCleanupCompletionPrivacy(
            success, prohibited: prohibited + [timedTitle, laterTitle, allDayTitle, roleName])
        try expect((await store.deletedEvents()).isEmpty, "Cleanup review must remain non-mutating")
    }

    private static func expectCleanupCompletionPrivacy(_ output: String, prohibited: [String]) throws {
        try expect(
            output.contains("complete local range") && output.contains("point-in-time")
                && output.contains("Remove legacyMarkers manually"),
            "Verified cleanup must state its bounded local point-in-time result without automatic YAML editing")
        for forbidden in prohibited {
            try expect(!output.contains(forbidden), "Cleanup completion must omit transient detail: \(forbidden)")
        }
        for forbiddenClaim in [
            "all calendars", "entire history", "globally retired", "retired everywhere", "recurring series removed",
            "all recurring series retired", "removed calendars are covered", "covers removed calendars",
            "cannot be recreated", "will not be recreated"
        ] {
            try expect(
                !output.localizedCaseInsensitiveContains(forbiddenClaim),
                "Verified app cleanup must not claim global, historical, recurring-series, or future-retirement scope")
        }
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
