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
    public static func plan(
        expected: [CalendarEventProjection], existing: [CalendarEvent], managedPrefixes: Set<String>
    ) -> ReconciliationPlan {
        plan(expected: expected, existing: existing) { event in isManaged(event, by: managedPrefixes) }
    }

    public static func plan(
        expected: [CalendarEventProjection], existing: [CalendarEvent], shouldDeleteStaleEvent: (CalendarEvent) -> Bool
    ) -> ReconciliationPlan {
        let uniqueExpected = uniqueProjections(from: expected)
        let existingKeys = Set(existing.map(VisibleEventKey.init(event:)))
        let expectedKeys = Set(uniqueExpected.map(visibleKey(for:)))

        let creates = uniqueExpected.filter { projection in !existingKeys.contains(visibleKey(for: projection)) }

        var retainedKeys = Set<VisibleEventKey>()
        let deletes = existing.filter { event in
            let key = VisibleEventKey(event: event)

            guard expectedKeys.contains(key) else { return shouldDeleteStaleEvent(event) }

            guard retainedKeys.insert(key).inserted else { return shouldDeleteStaleEvent(event) }

            return false
        }

        return ReconciliationPlan(creates: creates, deletes: deletes)
    }

    private static func uniqueProjections(from projections: [CalendarEventProjection]) -> [CalendarEventProjection] {
        var seenKeys = Set<VisibleEventKey>()

        return projections.filter { projection in seenKeys.insert(visibleKey(for: projection)).inserted }
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
