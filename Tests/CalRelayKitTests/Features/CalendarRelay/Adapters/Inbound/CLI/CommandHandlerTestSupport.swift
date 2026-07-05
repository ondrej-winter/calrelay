import CalRelayKit
import Foundation

actor CommandHandlerCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let eventsByCalendarID: [String: [CalendarEvent]]
    private var recordedCreates: [CalendarEventProjection] = []
    private var recordedDeletes: [CalendarEventIdentity] = []

    init(calendars: [RelayCalendar], eventsByCalendarID: [String: [CalendarEvent]] = [:]) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { recordedCreates.append(event) }

    func deleteEvent(_ event: CalendarEventIdentity) async throws { recordedDeletes.append(event) }

    func createdEvents() -> [CalendarEventProjection] { recordedCreates }

    func deletedEvents() -> [CalendarEventIdentity] { recordedDeletes }
}