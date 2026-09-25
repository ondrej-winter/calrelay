import CalRelayKit
import Foundation

enum CalendarManualApplyTests {
    static func runAll() async throws {
        try await testReviewRequiresOneUseConfirmationAndFreshPreflight()
        try await testRetainedUseCaseReadsFreshCalendarForEachReview()
        try await testChangedPlanRequiresReviewEvenWithSameCounts()
        try await runSafetyTests()
        try await runFreshSnapshotTests()
    }

    private static func testReviewRequiresOneUseConfirmationAndFreshPreflight() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        try expect(review.summary.plannedCreates == 1, "Review should expose aggregate counts")
        try expect(await store.createdEvents().isEmpty, "Review must not mutate")
        let outcome = try await useCase.confirm(reviewID: review.id)
        guard case .applied(let result) = outcome else { throw TestFailure("Unchanged plan should apply") }
        try expect(result.confirmedActionCount == 1, "Every action must be confirmed")
        try expect(await store.listCalendarsCallCount() == 2, "Confirmation must repeat preflight")
        try expect(await store.eventRequestCalendarIDs().count == 4, "Ordinary apply must not verify after mutation")
        try expect(await provider.callCount() == 3, "Review, replan, and pre-mutation file check must load afresh")
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Review must be consumed after apply")
        } catch CalendarManualApplyError.reviewRequired {}
    }

    private static func testRetainedUseCaseReadsFreshCalendarForEachReview() async throws {
        let fixture = ManualApplyFixture()
        let store = fixture.store()
        let firstCalendar = testCalendar(secondsFromGMT: 0)
        let secondCalendar = testCalendar(secondsFromGMT: -10 * 60 * 60)
        let calendarProvider = TestCalendarProvider(firstCalendar)
        let useCase = CalendarManualApplyUseCase(
            settingsProvider: ManualApplySettingsProvider(settings: fixture.settings),
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, now: { fixture.now },
            calendarProvider: { calendarProvider.value() })

        _ = try await useCase.review()
        calendarProvider.replace(secondCalendar)
        _ = try await useCase.review()

        let firstWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: firstCalendar, syncWindowDays: fixture.settings.syncWindowDays)
        let secondWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: secondCalendar, syncWindowDays: fixture.settings.syncWindowDays)
        try expect(calendarProvider.readCount() == 2, "Each manual review should sample a fresh calendar once")
        try expect(
            await store.eventRequestWindows() == [firstWindow, firstWindow, secondWindow, secondWindow],
            "A retained manual-apply use case should forward the fresh calendar into each review")
    }

    private static func testChangedPlanRequiresReviewEvenWithSameCounts() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        await provider.replace(fixture.settingsWith(prefix: "[CHANGED]"))
        let outcome = try await useCase.confirm(reviewID: review.id)
        guard case .reviewRequired(let replacement) = outcome else {
            throw TestFailure("Changed plan must require review")
        }
        try expect(replacement.summary == review.summary, "Same-count changes still invalidate confirmation")
        try expect(replacement.id != review.id, "Fresh review needs a different confirmation token")
        try expect(await store.createdEvents().isEmpty, "Changed plan must not mutate")
        guard case .applied = try await useCase.confirm(reviewID: replacement.id) else {
            throw TestFailure("Fresh review should authorize its matching plan")
        }
    }

    static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

struct ManualApplyFixture {
    let now = Date(timeIntervalSince1970: 10_000)
    let hub = RelayCalendar(id: "test-hub", title: "Test Hub", sourceTitle: "Test Source", isWritable: true)
    let work = RelayCalendar(id: "test-work", title: "Test Work", sourceTitle: "Test Source", isWritable: true)

    var settings: CalendarRelaySettings { settingsWith(prefix: "[WORK]") }

    func settingsWith(prefix: String, name: String = "Test Work", legacyMarkers: [String] = []) -> CalendarRelaySettings
    {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: name, prefix: prefix,
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: legacyMarkers)
    }

    func store() -> CommandHandlerCalendarStore {
        CommandHandlerCalendarStore(
            calendars: [hub, work],
            eventsByCalendarID: [
                work.id: [
                    CalendarEvent(
                        id: "test-source",
                        calendar: CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle),
                        title: "Example", start: now, end: now.addingTimeInterval(100), isAllDay: false,
                        availability: .busy, status: .confirmed)
                ]
            ])
    }

    func useCase(provider: any CalendarRelaySettingsProvider, store: any CalendarStorePort)
        -> CalendarManualApplyUseCase
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return CalendarManualApplyUseCase(
            settingsProvider: provider, authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            now: { now }, calendar: calendar)
    }
}

actor ManualApplySettingsProvider: CalendarRelaySettingsProvider {
    private var settings: CalendarRelaySettings
    private var calls = 0

    init(settings: CalendarRelaySettings) { self.settings = settings }
    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        return LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: settings)
    }
    func replace(_ settings: CalendarRelaySettings) { self.settings = settings }
    func callCount() -> Int { calls }
}
