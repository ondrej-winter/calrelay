import CalRelayKit
import Foundation

struct TestCalendarAuthorizationStatus: CalendarAuthorizationStatusPort {
    let state: CalendarAuthorizationState

    init(state: CalendarAuthorizationState = .fullAccess) { self.state = state }

    func authorizationStatus() async -> CalendarAuthorizationState { state }
}

actor CommandHandlerCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private var eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]
    private var recordedCreates: [CalendarEventProjection] = []
    private var recordedDeletes: [CalendarEventIdentity] = []
    private var listCalendarsCalls = 0
    private var recordedEventRequests: [PhysicalCalendarReference] = []

    init(calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]] = [:]) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
    }

    func listCalendars() async throws -> [RelayCalendar] {
        listCalendarsCalls += 1
        return calendars
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        recordedEventRequests.append(calendar.id)
        return eventsByCalendarID[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws { recordedCreates.append(event) }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        recordedDeletes.append(event)
        eventsByCalendarID[event.calendar.id, default: []].removeAll { $0.identity == event }
    }

    func createdEvents() -> [CalendarEventProjection] { recordedCreates }

    func deletedEvents() -> [CalendarEventIdentity] { recordedDeletes }

    func listCalendarsCallCount() -> Int { listCalendarsCalls }

    func eventRequestCalendarIDs() -> [PhysicalCalendarReference] { recordedEventRequests }
}
