import Foundation

public protocol CalendarStorePort: Sendable {
    func listCalendars() async throws -> [RelayCalendar]

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent]

    func createEvent(_ event: CalendarEventProjection) async throws

    func deleteEvent(_ event: CalendarEventIdentity) async throws
}
