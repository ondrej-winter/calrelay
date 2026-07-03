import Foundation

public enum EventExplanationFormatter {
    public static func format(_ explanation: ReconciliationExplanation) -> String {
        if explanation.candidates.isEmpty { return "No candidate events found in the sync window." }

        return explanation.candidates.map(formatCandidate).joined(separator: "\n")
    }

    private static func formatCandidate(_ candidate: CandidateEventExplanation) -> String {
        let event = candidate.event

        return "- \(formatCalendar(event.calendar)): \(event.title) "
            + "[\(formatRange(start: event.start, end: event.end))] "
            + "allDay=\(event.isAllDay) availability=\(event.availability) "
            + "status=\(event.status) -> \(formatReason(candidate.inclusion))"
    }

    private static func formatReason(_ reason: EventInclusionReason) -> String {
        switch reason {
        case .included: "included"
        case .allDay: "excluded (all-day event)"
        case .cancelled: "excluded (cancelled)"
        case .declined: "excluded (declined)"
        case .tentative: "excluded (tentative)"
        case .unsupportedAvailability(let availability): "excluded (unsupported availability: \(availability))"
        }
    }

    private static func formatCalendar(_ calendar: CalendarIdentity) -> String {
        "\(calendar.sourceTitle) / \(calendar.title)"
    }

    private static func formatRange(start: Date, end: Date) -> String { "\(start.description) → \(end.description)" }
}
