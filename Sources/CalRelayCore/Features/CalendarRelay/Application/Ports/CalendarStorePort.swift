import Foundation

public protocol CalendarStorePort: Sendable {
    func listCalendars() async throws -> [CalendarSnapshot]

    func events(in calendar: CalendarReference, from start: Date, to end: Date) async throws -> [EventSnapshot]

    func createEvent(_ event: ProjectedEvent) async throws

    func deleteEvent(_ event: EventSnapshot) async throws
}
