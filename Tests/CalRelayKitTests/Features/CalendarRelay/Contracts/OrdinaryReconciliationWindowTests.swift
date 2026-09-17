import CalRelayKit
import Foundation

enum OrdinaryReconciliationWindowTests {
    static func runAll() throws {
        try testWindowUsesWholeLocalDatesAcrossDaylightSavingTransition()
        try testWindowIncludesCurrentDateAndConfiguredFollowingDates()
    }

    private static func testWindowUsesWholeLocalDatesAcrossDaylightSavingTransition() throws {
        let timeZone = try requireTimeZone("America/New_York")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 3, day: 8, hour: 12))

        let window = OrdinaryReconciliationWindow.calculate(
            referenceDate: reference, calendar: calendar, syncWindowDays: 1)

        let expectedStart = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 3, day: 6, hour: 0))
        let expectedEnd = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 3, day: 10, hour: 0))

        try expect(window.start == expectedStart, "Window should begin at the start of local date D - 2")
        try expect(window.end == expectedEnd, "Window should end at the start of local date D + horizon + 1")
        try expect(
            window.end.timeIntervalSince(window.start) == 95 * 60 * 60,
            "DST transition should produce local-date boundaries rather than four elapsed 24-hour days")
    }

    private static func testWindowIncludesCurrentDateAndConfiguredFollowingDates() throws {
        let timeZone = try requireTimeZone("UTC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 9, day: 15, hour: 18, minute: 30))

        let window = OrdinaryReconciliationWindow.calculate(
            referenceDate: reference, calendar: calendar, syncWindowDays: 10)

        let expectedStart = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 9, day: 13, hour: 0))
        let expectedEnd = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 9, day: 26, hour: 0))

        try expect(
            window == CalendarAccessWindow(start: expectedStart, end: expectedEnd),
            "Window should include D and ten following local dates")
    }

    private static func requireTimeZone(_ identifier: String) throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw TestFailure("Missing required time zone: \(identifier)")
        }
        return timeZone
    }

    private static func requireDate(_ components: DateComponents) throws -> Date {
        guard let date = components.date else { throw TestFailure("Could not construct test date") }
        return date
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
