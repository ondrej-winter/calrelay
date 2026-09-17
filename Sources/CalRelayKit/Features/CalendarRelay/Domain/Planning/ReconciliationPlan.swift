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
        let expectedKeys = Set(uniqueExpected.map(visibleKey(for:)))
        let activeManagedCounts = existing.reduce(into: [VisibleEventKey: Int]()) { counts, event in
            guard event.status != .cancelled, shouldDeleteStaleEvent(event) else { return }
            counts[VisibleEventKey(event: event), default: 0] += 1
        }

        let creates = uniqueExpected.filter { projection in
            activeManagedCounts[visibleKey(for: projection), default: 0] != 1
        }

        let deletes = existing.filter { event in
            guard shouldDeleteStaleEvent(event) else { return false }
            let key = VisibleEventKey(event: event)

            guard expectedKeys.contains(key) else { return true }
            guard event.status != .cancelled else { return true }
            return activeManagedCounts[key, default: 0] != 1
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
        guard let marker = MarkedEventTitle.marker(in: event.title) else { return false }
        return managedPrefixes.contains(marker)
    }
}
