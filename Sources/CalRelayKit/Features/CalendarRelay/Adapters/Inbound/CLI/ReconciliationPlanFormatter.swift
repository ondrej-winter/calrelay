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

    public static func format(_ result: OrdinaryReconciliationResult) -> String {
        if result.actions.isEmpty { return "No changes planned." }

        let deletes = result.actions.compactMap { action -> CalendarEvent? in
            guard case .delete(_, let event) = action else { return nil }
            return event
        }
        let creates = result.actions.compactMap { action -> CalendarEventProjection? in
            guard case .create(_, let event) = action else { return nil }
            return event
        }

        var lines: [String] = ["Deletes (\(deletes.count))"]
        lines.append(contentsOf: deletes.map(formatDelete))
        lines.append("Creates (\(creates.count))")
        lines.append(contentsOf: creates.map(formatCreate))
        return lines.joined(separator: "\n")
    }

    private static func formatCreate(_ event: CalendarEventProjection) -> String {
        "- create \(formatCalendar(event.destinationCalendar)): \(event.title) [\(formatRange(start: event.start, end: event.end))]"
    }

    private static func formatDelete(_ event: CalendarEvent) -> String {
        "- delete \(formatCalendar(event.calendar)): \(event.title) [\(formatRange(start: event.start, end: event.end))]"
    }

    private static func formatCalendar(_ calendar: CalendarIdentity) -> String {
        "\(calendar.sourceTitle) / \(calendar.title)"
    }

    private static func formatRange(start: Date, end: Date) -> String { "\(start.description) → \(end.description)" }
}
