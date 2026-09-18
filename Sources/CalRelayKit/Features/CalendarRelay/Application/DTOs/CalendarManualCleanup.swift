import Foundation

/// Review content is transient, never persisted or logged. No provider identities leave the use case.
public struct CalendarManualCleanupReview: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let window: CalendarAccessWindow
    public let calendar: Calendar
    public let rows: [CalendarCleanupReviewRow]

    init(plan: CalendarCleanupPlan, window: CalendarAccessWindow, calendar: Calendar) {
        id = UUID()
        self.window = window
        self.calendar = calendar
        rows = plan.deletions.map { deletion in
            let event = deletion.event
            let marker = MarkedEventTitle.marker(in: event.title)
            let title = marker.map { String(event.title.dropFirst($0.count + 1)) } ?? event.title
            return CalendarCleanupReviewRow(title: title, role: deletion.role, start: event.start, end: event.end, isAllDay: event.isAllDay)
        }
    }
}

public struct CalendarCleanupReviewRow: Equatable, Sendable {
    public let title: String
    public let role: ConfiguredCalendarRole
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
}

public enum CalendarManualCleanupOutcome: Equatable, Sendable {
    case reviewRequired(CalendarManualCleanupReview)
    case applied(confirmedDeletions: Int)
}

public enum CalendarManualCleanupError: Error, Equatable, Sendable {
    case operationInProgress
    case reviewRequired
    case configurationChanged
    case failed(confirmedDeletions: Int, category: CalendarManualCleanupFailure)
}

public enum CalendarManualCleanupFailure: Equatable, Sendable {
    case configurationUnavailable
    case legacyMarkersRequired
    case authorizationUnavailable(CalendarAuthorizationState)
    case preflightFailed
    case deletionFailed
    case verificationReadFailed
    case remainingMatches(Int)
    case cancelled
    case unexpected
}