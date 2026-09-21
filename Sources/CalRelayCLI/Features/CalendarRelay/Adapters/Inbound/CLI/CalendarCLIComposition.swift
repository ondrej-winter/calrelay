import CalRelayKit
import Foundation

struct CalendarCLIComposition: Sendable {
    let authorizationStatus: any CalendarAuthorizationStatusPort
    let calendarStore: any CalendarStorePort
    let now: @Sendable () -> Date
    let calendar: Calendar

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        #if CALRELAY_CLI_PROCESS_TESTING
            if environment["CALRELAY_PROCESS_TESTING"] == "1" {
                return processTestComposition(scenario: environment["CALRELAY_PROCESS_TEST_SCENARIO"])
            }
        #endif

        let authorization = EventKitCalendarAuthorizationStatus()
        return Self(
            authorizationStatus: authorization,
            calendarStore: EventKitCalendarStore(authorizationStatus: authorization), now: Date.init, calendar: .current
        )
    }
}

#if CALRELAY_CLI_PROCESS_TESTING
    extension CalendarCLIComposition {
        fileprivate static func processTestComposition(scenario: String?) -> Self {
            let fixture = CalendarCLIProcessTestFixture(scenario: scenario)
            let authorization = CalendarCLIProcessTestAuthorization(state: fixture.authorizationState)
            return Self(
                authorizationStatus: authorization,
                calendarStore: CalendarCLIProcessTestStore(
                    calendars: fixture.calendars, events: fixture.events, failMutationNumber: fixture.failMutationNumber
                ), now: { Date(timeIntervalSince1970: 10_000) }, calendar: processTestCalendar())
        }

        private static func processTestCalendar() -> Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar
        }
    }

    private struct CalendarCLIProcessTestAuthorization: CalendarAuthorizationStatusPort {
        let state: CalendarAuthorizationState

        func authorizationStatus() async -> CalendarAuthorizationState { state }
    }

    private struct CalendarCLIProcessTestFixture {
        let authorizationState: CalendarAuthorizationState
        let calendars: [RelayCalendar]
        let events: [PhysicalCalendarReference: [CalendarEvent]]
        let failMutationNumber: Int?

        init(scenario: String?) {
            let hub = RelayCalendar(id: "process-hub", title: "Personal Work", sourceTitle: "iCloud", isWritable: true)
            let work = RelayCalendar(id: "process-work", title: "ACME Work", sourceTitle: "Google", isWritable: true)

            switch scenario {
            case "empty-inventory":
                authorizationState = .fullAccess
                calendars = []
                events = [:]
                failMutationNumber = nil
            case "ready":
                authorizationState = .fullAccess
                calendars = [hub, work]
                events = [:]
                failMutationNumber = nil
            case "ordinary-actions", "ordinary-partial-failure":
                authorizationState = .fullAccess
                calendars = [hub, work]
                events = Self.ordinaryActionEvents(hub: hub, work: work)
                failMutationNumber = scenario == "ordinary-partial-failure" ? 2 : nil
            case "cleanup-success":
                authorizationState = .fullAccess
                calendars = [hub, work]
                events = Self.cleanupSuccessEvents(work: work)
                failMutationNumber = nil
            case "cleanup-partial-failure":
                authorizationState = .fullAccess
                calendars = [hub, work]
                events = Self.cleanupPartialFailureEvents(hub: hub, work: work)
                failMutationNumber = 2
            default:
                authorizationState = .denied
                calendars = []
                events = [:]
                failMutationNumber = nil
            }
        }

        private static func ordinaryActionEvents(hub: RelayCalendar, work: RelayCalendar) -> [PhysicalCalendarReference:
            [CalendarEvent]]
        {
            let hubIdentity = identity(for: hub)
            let workIdentity = identity(for: work)
            let start = Date(timeIntervalSince1970: 11_000)
            let end = Date(timeIntervalSince1970: 12_000)
            return [
                hub.id: [
                    CalendarEvent(
                        id: "process-stale-hub", calendar: hubIdentity, title: "[ACME] Old Planning", start: start,
                        end: end, isAllDay: false, availability: .busy, status: .confirmed),
                    CalendarEvent(
                        id: "process-personal-hub", calendar: hubIdentity, title: "Personal appointment",
                        start: Date(timeIntervalSince1970: 15_000), end: Date(timeIntervalSince1970: 16_000),
                        isAllDay: false, availability: .busy, status: .confirmed)
                ],
                work.id: [
                    CalendarEvent(
                        id: "process-work-source", calendar: workIdentity, title: "Client Planning", start: start,
                        end: end, isAllDay: false, availability: .busy, status: .confirmed)
                ]
            ]
        }

        private static func cleanupSuccessEvents(work: RelayCalendar) -> [PhysicalCalendarReference: [CalendarEvent]] {
            [
                work.id: [
                    CalendarEvent(
                        id: "process-cleanup", calendar: identity(for: work), title: "[OLD] Cleanup Review",
                        start: Date(timeIntervalSince1970: 11_000), end: Date(timeIntervalSince1970: 12_000),
                        isAllDay: false, availability: .busy, status: .confirmed)
                ]
            ]
        }

        private static func cleanupPartialFailureEvents(hub: RelayCalendar, work: RelayCalendar)
            -> [PhysicalCalendarReference: [CalendarEvent]]
        {
            [
                hub.id: [
                    CalendarEvent(
                        id: "process-cleanup-hub", calendar: identity(for: hub), title: "[OLD] Hub Review",
                        start: Date(timeIntervalSince1970: 10_100), end: Date(timeIntervalSince1970: 10_200),
                        isAllDay: false, availability: .busy, status: .confirmed)
                ],
                work.id: [
                    CalendarEvent(
                        id: "process-cleanup-later", calendar: identity(for: work), title: "[OLD] Later Review",
                        start: Date(timeIntervalSince1970: 10_500), end: Date(timeIntervalSince1970: 10_600),
                        isAllDay: false, availability: .busy, status: .confirmed),
                    CalendarEvent(
                        id: "process-cleanup-work", calendar: identity(for: work), title: "[OLD] Work Review",
                        start: Date(timeIntervalSince1970: 10_300), end: Date(timeIntervalSince1970: 10_400),
                        isAllDay: false, availability: .busy, status: .confirmed)
                ]
            ]
        }

        private static func identity(for calendar: RelayCalendar) -> CalendarIdentity {
            CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle)
        }
    }

    private actor CalendarCLIProcessTestStore: CalendarStorePort {
        private let calendars: [RelayCalendar]
        private var events: [PhysicalCalendarReference: [CalendarEvent]]
        private let failMutationNumber: Int?
        private var mutationAttempts = 0

        init(calendars: [RelayCalendar], events: [PhysicalCalendarReference: [CalendarEvent]], failMutationNumber: Int?)
        {
            self.calendars = calendars
            self.events = events
            self.failMutationNumber = failMutationNumber
        }

        func listCalendars() async throws -> [RelayCalendar] { calendars }

        func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
            events[calendar.id, default: []].filter { $0.start < end && $0.end > start }
        }

        func createEvent(_ event: CalendarEventProjection) async throws {
            try recordMutationAttempt()
            events[event.destinationCalendar.id, default: []].append(
                CalendarEvent(
                    id: "process-created-\(mutationAttempts)", calendar: event.destinationCalendar, title: event.title,
                    start: event.start, end: event.end, isAllDay: event.isAllDay, availability: .busy,
                    status: .confirmed))
        }

        func deleteEvent(_ event: CalendarEventIdentity) async throws {
            try recordMutationAttempt()
            events[event.calendar.id, default: []].removeAll { $0.identity == event }
        }

        private func recordMutationAttempt() throws {
            mutationAttempts += 1
            if mutationAttempts == failMutationNumber { throw CalendarCLIProcessTestStoreFailure() }
        }
    }

    private struct CalendarCLIProcessTestStoreFailure: Error {}
#endif
