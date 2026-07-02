import Foundation

public enum ReconciliationPlanner {
    public static func plan(
        expected: [ProjectedEvent],
        existing: [EventSnapshot],
        managedPrefixes: Set<String>
    ) -> ReconciliationPlan {
        plan(expected: expected, existing: existing) { event in
            isManaged(event, by: managedPrefixes)
        }
    }

    public static func plan(
        expected: [ProjectedEvent],
        existing: [EventSnapshot],
        shouldDeleteStaleEvent: (EventSnapshot) -> Bool
    ) -> ReconciliationPlan {
        let existingKeys = Set(existing.map(VisibleEventKey.init(event:)))
        let expectedKeys = Set(expected.map(visibleKey(for:)))

        let creates = expected.filter { projection in
            !existingKeys.contains(visibleKey(for: projection))
        }

        let deletes = existing.filter { event in
            !expectedKeys.contains(VisibleEventKey(event: event)) && shouldDeleteStaleEvent(event)
        }

        return ReconciliationPlan(creates: creates, deletes: deletes)
    }

    private static func visibleKey(for projection: ProjectedEvent) -> VisibleEventKey {
        VisibleEventKey(
            calendar: projection.destinationCalendar,
            title: projection.title,
            start: projection.start,
            end: projection.end,
            isAllDay: projection.isAllDay
        )
    }

    private static func isManaged(_ event: EventSnapshot, by managedPrefixes: Set<String>) -> Bool {
        managedPrefixes.contains { prefix in
            event.title.hasPrefix(prefix)
        }
    }
}