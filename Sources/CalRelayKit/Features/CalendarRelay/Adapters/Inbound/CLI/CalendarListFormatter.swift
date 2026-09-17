import Foundation

public enum CalendarListFormatter {
    public static func format(_ calendars: [RelayCalendar]) -> String { formatForCLI(calendars) }

    public static func formatForCLI(_ calendars: [RelayCalendar]) -> String {
        if calendars.isEmpty {
            return """
                No EventKit-visible calendars were found.
                Inventory discovery succeeded. This does not verify configuration or configured readiness.
                """
        }

        var lines: [String] = ["Calendars (\(calendars.count))"]
        lines.append(contentsOf: calendars.map(formatCLICalendar))
        lines.append("Inventory only; this does not verify configured readiness.")
        return lines.joined(separator: "\n")
    }

    public static func formatForApp(_ calendars: [RelayCalendar]) -> String {
        if calendars.isEmpty {
            return """
                No EventKit-visible calendars were found.
                Inventory discovery succeeded and is separate from configured readiness.
                """
        }

        var lines: [String] = ["Visible calendars (\(calendars.count))"]
        lines.append(contentsOf: calendars.map(formatAppCalendar))
        lines.append("Inventory is separate from configured readiness and configuration validity.")
        return lines.joined(separator: "\n")
    }

    private static func formatCLICalendar(_ calendar: RelayCalendar) -> String {
        let writability = calendar.isWritable ? "writable" : "read-only"
        return "- \(calendar.sourceTitle) / \(calendar.title) [id: \(calendar.id), \(writability)]"
    }

    private static func formatAppCalendar(_ calendar: RelayCalendar) -> String {
        let writability = calendar.isWritable ? "writable" : "read-only"
        return "- \(calendar.sourceTitle) / \(calendar.title) [\(writability)]"
    }
}
