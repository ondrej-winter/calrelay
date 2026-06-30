import CalRelayCore
import Foundation

public enum CalendarListFormatter {
    public static func format(_ calendars: [CalendarSnapshot]) -> String {
        if calendars.isEmpty {
            return "No calendars found."
        }

        var lines: [String] = ["Calendars (\(calendars.count))"]
        lines.append(contentsOf: calendars.map(formatCalendar))
        return lines.joined(separator: "\n")
    }

    private static func formatCalendar(_ calendar: CalendarSnapshot) -> String {
        let writability = calendar.isWritable ? "writable" : "read-only"
        return "- \(calendar.sourceTitle) / \(calendar.title) [id: \(calendar.id), \(writability)]"
    }
}