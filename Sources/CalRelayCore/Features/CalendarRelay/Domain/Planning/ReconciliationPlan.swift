import Foundation

public struct ReconciliationPlan: Equatable, Sendable {
    public let creates: [CalendarEventProjection]
    public let deletes: [CalendarEvent]

    public init(creates: [CalendarEventProjection], deletes: [CalendarEvent]) {
        self.creates = creates
        self.deletes = deletes
    }
}
