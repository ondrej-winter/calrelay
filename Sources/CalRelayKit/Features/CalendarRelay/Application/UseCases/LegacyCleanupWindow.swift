import Foundation

public enum LegacyCleanupWindow {
    public static func calculate(referenceDate: Date, calendar: Calendar) -> CalendarAccessWindow {
        let currentDateStart = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -2, to: currentDateStart) ?? currentDateStart
        let end = calendar.date(byAdding: .day, value: 366, to: currentDateStart) ?? currentDateStart
        return CalendarAccessWindow(start: start, end: end)
    }
}
