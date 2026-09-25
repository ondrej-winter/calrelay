import CalRelayKit
import Foundation

// swiftlint:disable:next type_name
enum OrdinaryReconciliationCalendarCaptureTests {
    static func runAll() async throws {
        try await testLaterRunUsesFreshCalendarAndOneReadPerRun()
        try await testApplyUsesOneCapturedCalendarThroughMutation()
        try await testExplanationReportsTheCapturedReadWindow()
    }

    private static func testLaterRunUsesFreshCalendarAndOneReadPerRun() async throws {
        let fixture = fixture()
        let store = fixture.store()
        let firstCalendar = testCalendar(secondsFromGMT: 0)
        let secondCalendar = testCalendar(secondsFromGMT: -10 * 60 * 60)
        let provider = TestCalendarProvider(firstCalendar)
        let useCase = ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            calendarProvider: { provider.value() })

        _ = try await useCase.dryRunResult(settings: fixture.settings, now: fixture.now)
        provider.replace(secondCalendar)
        _ = try await useCase.dryRunResult(settings: fixture.settings, now: fixture.now)

        let firstWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: firstCalendar, syncWindowDays: fixture.settings.syncWindowDays)
        let secondWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: secondCalendar, syncWindowDays: fixture.settings.syncWindowDays)
        try expect(provider.readCount() == 2, "Each dry run should read the calendar provider exactly once")
        try expect(
            await store.eventRequestWindows() == [firstWindow, firstWindow, secondWindow, secondWindow],
            "Later dry runs on one reconciler should use a fresh calendar consistently for every event read")
    }

    private static func testApplyUsesOneCapturedCalendarThroughMutation() async throws {
        let fixture = fixture()
        let store = fixture.store()
        let runCalendar = testCalendar(secondsFromGMT: -10 * 60 * 60)
        let provider = TestCalendarProvider(runCalendar)
        let useCase = ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            calendarProvider: { provider.value() })

        let result = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)

        let expectedWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: runCalendar, syncWindowDays: fixture.settings.syncWindowDays)
        try expect(provider.readCount() == 1, "Apply should not read the calendar provider after planning")
        try expect(
            await store.eventRequestWindows() == [expectedWindow, expectedWindow],
            "Apply should use one captured window for its complete snapshot")
        try expect(result.actions.count == 1, "The fixture should produce one executable action")
        try expect((await store.createdEvents()).count == 1, "Apply should execute the action produced from that window")
    }

    private static func testExplanationReportsTheCapturedReadWindow() async throws {
        let fixture = fixture()
        let store = fixture.store()
        let runCalendar = testCalendar(secondsFromGMT: -10 * 60 * 60)
        let provider = TestCalendarProvider(runCalendar)
        let useCase = ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store,
            calendarProvider: { provider.value() })

        let explanation = try await useCase.explain(settings: fixture.settings, now: fixture.now)

        let expectedWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: fixture.now, calendar: runCalendar, syncWindowDays: fixture.settings.syncWindowDays)
        try expect(provider.readCount() == 1, "Explanation should read the calendar provider exactly once")
        try expect(explanation.window == expectedWindow, "Explanation should report the captured effective window")
        try expect(
            await store.eventRequestWindows() == [expectedWindow, expectedWindow],
            "Explanation and input reads should share one captured window")
    }

    private static func fixture() -> CalendarCaptureFixture {
        let now = Date(timeIntervalSince1970: 10_000)
        let hub = RelayCalendar(id: "capture-hub", title: "Test Hub", sourceTitle: "Test Source", isWritable: true)
        let work = RelayCalendar(id: "capture-work", title: "Test Work", sourceTitle: "Test Source", isWritable: true)
        let settings = CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Test Work", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: [])
        let source = CalendarEvent(
            id: "capture-source",
            calendar: CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle),
            title: "Example", start: now, end: now.addingTimeInterval(100), isAllDay: false,
            availability: .busy, status: .confirmed)
        return CalendarCaptureFixture(now: now, settings: settings, hub: hub, work: work, source: source)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct CalendarCaptureFixture {
    let now: Date
    let settings: CalendarRelaySettings
    let hub: RelayCalendar
    let work: RelayCalendar
    let source: CalendarEvent

    func store() -> CommandHandlerCalendarStore {
        CommandHandlerCalendarStore(calendars: [hub, work], eventsByCalendarID: [work.id: [source]])
    }
}

final class TestCalendarProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var calendar: Calendar
    private var reads = 0

    init(_ calendar: Calendar) { self.calendar = calendar }

    func value() -> Calendar {
        lock.lock()
        defer { lock.unlock() }
        reads += 1
        return calendar
    }

    func replace(_ calendar: Calendar) {
        lock.lock()
        defer { lock.unlock() }
        self.calendar = calendar
    }

    func readCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return reads
    }
}

func testCalendar(secondsFromGMT: Int) -> Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)!
    return value
}
