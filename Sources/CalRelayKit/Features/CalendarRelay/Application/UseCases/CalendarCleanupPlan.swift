public struct CalendarCleanupDeletion: Equatable, Sendable {
    public let role: ConfiguredCalendarRole
    public let event: CalendarEvent

    public init(role: ConfiguredCalendarRole, event: CalendarEvent) {
        self.role = role
        self.event = event
    }
}

public struct CalendarCleanupPlan: Equatable, Sendable {
    public let deletions: [CalendarCleanupDeletion]

    public init(deletions: [CalendarCleanupDeletion]) { self.deletions = deletions }
}

public enum CalendarCleanupPlanner {
    public static func plan(snapshot: CalendarAccessPreflightSnapshot, legacyMarkers: Set<String>)
        -> CalendarCleanupPlan
    {
        let deletions = snapshot.calendars.flatMap { calendarSnapshot in
            calendarSnapshot.events.filter { event in
                guard let marker = MarkedEventTitle.marker(in: event.title) else { return false }
                return legacyMarkers.contains(marker)
            }.sorted(by: eventOrder).map { event in CalendarCleanupDeletion(role: calendarSnapshot.role, event: event) }
        }
        return CalendarCleanupPlan(deletions: deletions)
    }

    public static func matchingEventCount(snapshot: CalendarAccessPreflightSnapshot, legacyMarkers: Set<String>) -> Int
    {
        snapshot.calendars.reduce(into: 0) { count, calendarSnapshot in
            count +=
                calendarSnapshot.events.filter { event in
                    guard let marker = MarkedEventTitle.marker(in: event.title) else { return false }
                    return legacyMarkers.contains(marker)
                }.count
        }
    }

    private static func eventOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.end != rhs.end { return lhs.end < rhs.end }
        if lhs.isAllDay != rhs.isAllDay { return !lhs.isAllDay }
        if lhs.title != rhs.title {
            return lhs.title.unicodeScalars.lexicographicallyPrecedes(rhs.title.unicodeScalars) { left, right in
                left.value < right.value
            }
        }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        return (lhs.occurrenceDate ?? lhs.start) < (rhs.occurrenceDate ?? rhs.start)
    }
}
