import Foundation

public enum OrdinaryReconciliationWindow {
    public static func calculate(referenceDate: Date, calendar: Calendar, syncWindowDays: Int) -> CalendarAccessWindow {
        let currentDateStart = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -2, to: currentDateStart) ?? currentDateStart
        let end = calendar.date(byAdding: .day, value: syncWindowDays + 1, to: currentDateStart) ?? currentDateStart
        return CalendarAccessWindow(start: start, end: end)
    }
}
