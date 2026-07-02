import Foundation

/// Diagnostic-only view of a candidate source event and why reconciliation did or did not
/// treat it as an availability blocker to relay.
///
/// This DTO exists purely for CLI troubleshooting (`calrelay reconcile --explain`). It must
/// never be used to drive reconciliation decisions; `ReconciliationPlan` remains the single
/// source of truth for planned mutations.
public struct EventExplanation: Equatable, Sendable {
    public let calendar: CalendarReference
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let availability: EventAvailability
    public let status: EventStatus
    public let reason: EventInclusionReason

    public init(
        calendar: CalendarReference,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        availability: EventAvailability,
        status: EventStatus,
        reason: EventInclusionReason
    ) {
        self.calendar = calendar
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.availability = availability
        self.status = status
        self.reason = reason
    }
}
