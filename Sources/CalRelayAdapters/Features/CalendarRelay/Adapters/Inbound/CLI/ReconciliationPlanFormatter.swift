import CalRelayCore
import Foundation

public enum ReconciliationPlanFormatter {
    public static func format(_ plan: ReconciliationPlan) -> String {
        if plan.creates.isEmpty && plan.deletes.isEmpty { return "No changes planned." }

        var lines: [String] = []
        lines.append("Creates (\(plan.creates.count))")
        lines.append(contentsOf: plan.creates.map(formatCreate))
        lines.append("Deletes (\(plan.deletes.count))")
        lines.append(contentsOf: plan.deletes.map(formatDelete))

        return lines.joined(separator: "\n")
    }

    private static func formatCreate(_ event: ProjectedEvent) -> String {
        "- create \(formatCalendar(event.destinationCalendar)): \(event.title) [\(formatRange(start: event.start, end: event.end))]"
    }

    private static func formatDelete(_ event: EventSnapshot) -> String {
        "- delete \(formatCalendar(event.calendar)): \(event.title) [\(formatRange(start: event.start, end: event.end))]"
    }

    private static func formatCalendar(_ calendar: CalendarReference) -> String {
        "\(calendar.sourceTitle) / \(calendar.title)"
    }

    private static func formatRange(start: Date, end: Date) -> String { "\(start.description) → \(end.description)" }
}
