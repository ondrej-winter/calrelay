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

        let deleteCount = result.actions.count { action in
            if case .delete = action { return true }
            return false
        }
        let createCount = result.actions.count { action in
            if case .create = action { return true }
            return false
        }

        var lines = ["Deletes (\(deleteCount))", "Creates (\(createCount))", "Actions in execution order"]
        lines.append(contentsOf: result.actions.map(formatAction))
        return lines.joined(separator: "\n")
    }

    private static func formatAction(_ action: CalendarMutationAction) -> String {
        switch action {
        case .delete(_, let event): formatDelete(event)
        case .create(_, let event): formatCreate(event)
        }
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
