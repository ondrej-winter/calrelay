import CalRelayCore
import Foundation

public enum EventExplanationFormatter {
    public static func format(_ explanations: [EventExplanation]) -> String {
        if explanations.isEmpty {
            return "No candidate events found in the sync window."
        }

        return explanations.map(formatExplanation).joined(separator: "\n")
    }

    private static func formatExplanation(_ explanation: EventExplanation) -> String {
        "- \(formatCalendar(explanation.calendar)): \(explanation.title) "
            + "[\(formatRange(start: explanation.start, end: explanation.end))] "
            + "allDay=\(explanation.isAllDay) availability=\(explanation.availability) "
            + "status=\(explanation.status) -> \(formatReason(explanation.reason))"
    }

    private static func formatReason(_ reason: EventInclusionReason) -> String {
        switch reason {
        case .included:
            "included"
        case .allDay:
            "excluded (all-day event)"
        case .cancelled:
            "excluded (cancelled)"
        case .declined:
            "excluded (declined)"
        case .unsupportedAvailability(let availability):
            "excluded (unsupported availability: \(availability))"
        }
    }

    private static func formatCalendar(_ calendar: CalendarReference) -> String {
        "\(calendar.sourceTitle) / \(calendar.title)"
    }

    private static func formatRange(start: Date, end: Date) -> String {
        "\(start.description) → \(end.description)"
    }
}
