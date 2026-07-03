import Foundation

public struct ReconciliationPlan: Equatable, Sendable {
    public let creates: [CalendarEventProjection]
    public let deletes: [CalendarEvent]

    public init(creates: [CalendarEventProjection], deletes: [CalendarEvent]) {
        self.creates = creates
        self.deletes = deletes
    }
}

public enum ReconciliationPlanner {
    public static func plan(expected: [CalendarEventProjection], existing: [CalendarEvent], managedPrefixes: Set<String>)
        -> ReconciliationPlan
    { plan(expected: expected, existing: existing) { event in isManaged(event, by: managedPrefixes) } }

    public static func plan(
        expected: [CalendarEventProjection], existing: [CalendarEvent], shouldDeleteStaleEvent: (CalendarEvent) -> Bool
    ) -> ReconciliationPlan {
        let existingKeys = Set(existing.map(VisibleEventKey.init(event:)))
        let expectedKeys = Set(expected.map(visibleKey(for:)))

        let creates = expected.filter { projection in !existingKeys.contains(visibleKey(for: projection)) }

        let deletes = existing.filter { event in
            !expectedKeys.contains(VisibleEventKey(event: event)) && shouldDeleteStaleEvent(event)
        }

        return ReconciliationPlan(creates: creates, deletes: deletes)
    }

    private static func visibleKey(for projection: CalendarEventProjection) -> VisibleEventKey {
        VisibleEventKey(
            calendar: projection.destinationCalendar, title: projection.title, start: projection.start,
            end: projection.end, isAllDay: projection.isAllDay)
    }

    private static func isManaged(_ event: CalendarEvent, by managedPrefixes: Set<String>) -> Bool {
        managedPrefixes.contains { prefix in event.title.hasPrefix(prefix) }
    }
}
