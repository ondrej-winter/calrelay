import Foundation

/// Transient comparison keys for reviewed plans, never persisted or presented.
public enum CalendarExecutableActionIdentity: Equatable, Sendable {
    case delete(calendar: PhysicalCalendarReference, event: CalendarEventReference, occurrence: Date?)
    case create(calendar: PhysicalCalendarReference, title: String, start: Date, end: Date, isAllDay: Bool)
}

extension CalendarMutationAction {
    public var executableIdentity: CalendarExecutableActionIdentity {
        switch self {
        case .delete(_, let event):
            .delete(calendar: event.calendar.id, event: event.id, occurrence: event.occurrenceDate)
        case .create(_, let event):
            .create(
                calendar: event.destinationCalendar.id, title: event.title, start: event.start, end: event.end,
                isAllDay: event.isAllDay)
        }
    }
}
