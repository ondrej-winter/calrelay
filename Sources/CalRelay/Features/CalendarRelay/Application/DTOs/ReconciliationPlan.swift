import Foundation

struct ReconciliationPlan: Equatable, Sendable {
    let creates: [ProjectedEvent]
    let deletes: [EventSnapshot]
}

struct ProjectedEvent: Equatable, Sendable {
    let destinationCalendar: CalendarReference
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
}