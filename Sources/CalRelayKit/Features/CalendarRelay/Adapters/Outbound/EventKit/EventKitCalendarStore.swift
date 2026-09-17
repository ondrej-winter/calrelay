@preconcurrency import EventKit
import Foundation

public enum EventKitCalendarStoreError: Error, CustomStringConvertible {
    case calendarNotFound(CalendarIdentity)
    case calendarReadOnly(CalendarIdentity)
    case eventNotFound(CalendarEventIdentity)
    case eventAmbiguous(CalendarEventIdentity)
    case eventCalendarMismatch(expected: CalendarIdentity)

    public var description: String {
        switch self {
        case .calendarNotFound(let calendar):
            "Calendar is no longer available: \(calendar.sourceTitle) / \(calendar.title)."
        case .calendarReadOnly(let calendar): "Calendar is read-only: \(calendar.sourceTitle) / \(calendar.title)."
        case .eventNotFound(let event):
            "Event is no longer available for deletion: \(event.calendar.sourceTitle) / \(event.calendar.title)."
        case .eventAmbiguous(let event):
            "The exact event occurrence could not be resolved uniquely: \(event.calendar.sourceTitle) / \(event.calendar.title)."
        case .eventCalendarMismatch(let expected):
            "Event selected for deletion no longer belongs to the expected calendar: \(expected.sourceTitle) / \(expected.title)."
        }
    }
}

public final class EventKitCalendarAuthorizationStatus: CalendarAuthorizationStatusPort, CalendarFullAccessRequestPort,
    @unchecked Sendable
{
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) { self.eventStore = eventStore }

    public func authorizationStatus() async -> CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .writeOnly: .writeOnly
        case .fullAccess: .fullAccess
        @unknown default: .unknown
        }
    }

    public func requestFullAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: granted) }
            }
        }
    }
}

public enum EventKitEventStatusValue: Equatable, Sendable {
    case confirmed
    case tentative
    case cancelled
    case unknown
}

public enum EventKitParticipantStatusValue: Equatable, Sendable {
    case accepted
    case declined
    case tentative
    case other
}

public enum EventKitEventStatusMapper {
    public static func mapStatus(
        currentUserParticipantStatus: EventKitParticipantStatusValue?, eventStatus: EventKitEventStatusValue
    ) -> EventStatus {
        switch currentUserParticipantStatus {
        case .declined: return .declined
        case .tentative: return .tentative
        case .accepted, .other, nil: break
        }

        switch eventStatus {
        case .confirmed: return .confirmed
        case .tentative: return .tentative
        case .cancelled: return .cancelled
        case .unknown: return .unknown
        }
    }
}

public final class EventKitCalendarStore: CalendarStorePort, @unchecked Sendable {
    private let eventStore: EKEventStore
    private let authorizationStatus: any CalendarAuthorizationStatusPort

    public init(authorizationStatus: any CalendarAuthorizationStatusPort, eventStore: EKEventStore = EKEventStore()) {
        self.authorizationStatus = authorizationStatus
        self.eventStore = eventStore
    }

    public func listCalendars() async throws -> [RelayCalendar] {
        try await requireFullAccess()

        return eventStore.calendars(for: .event).map { calendar in
            RelayCalendar(
                id: calendar.calendarIdentifier, title: calendar.title, sourceTitle: calendar.source.title,
                isWritable: calendar.allowsContentModifications)
        }
    }

    public func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        try await requireFullAccess()

        guard let eventKitCalendar = eventStore.calendar(withIdentifier: calendar.id.eventKitIdentifier) else {
            throw EventKitCalendarStoreError.calendarNotFound(calendar)
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [eventKitCalendar])

        return eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? event.calendarItemIdentifier, calendar: calendar, title: event.title ?? "",
                start: event.startDate, end: event.endDate, isAllDay: event.isAllDay,
                availability: Self.mapAvailability(event.availability), status: Self.mapStatus(event),
                occurrenceDate: event.occurrenceDate, occurrenceLookupStart: start, occurrenceLookupEnd: end)
        }
    }

    public func createEvent(_ event: CalendarEventProjection) async throws {
        try await requireFullAccess()

        let calendar = try writableEventKitCalendar(for: event.destinationCalendar)
        let eventKitEvent = EKEvent(eventStore: eventStore)
        eventKitEvent.calendar = calendar
        eventKitEvent.title = event.title
        eventKitEvent.startDate = event.start
        eventKitEvent.endDate = event.end
        eventKitEvent.isAllDay = event.isAllDay

        try eventStore.save(eventKitEvent, span: .thisEvent, commit: true)
    }

    public func deleteEvent(_ event: CalendarEventIdentity) async throws {
        try await requireFullAccess()

        _ = try writableEventKitCalendar(for: event.calendar)

        let eventKitEvent = try exactEvent(for: event)

        guard eventKitEvent.calendar.calendarIdentifier == event.calendar.id.eventKitIdentifier else {
            throw EventKitCalendarStoreError.eventCalendarMismatch(expected: event.calendar)
        }

        try eventStore.remove(eventKitEvent, span: .thisEvent, commit: true)
    }

    private func exactEvent(for event: CalendarEventIdentity) throws -> EKEvent {
        if event.occurrenceDate == nil {
            guard let eventKitEvent = eventStore.event(withIdentifier: event.id.eventKitIdentifier) else {
                throw EventKitCalendarStoreError.eventNotFound(event)
            }

            return eventKitEvent
        }

        guard let lookupStart = event.lookupStart, let lookupEnd = event.lookupEnd else {
            throw EventKitCalendarStoreError.eventNotFound(event)
        }

        guard let calendar = eventStore.calendar(withIdentifier: event.calendar.id.eventKitIdentifier) else {
            throw EventKitCalendarStoreError.calendarNotFound(event.calendar)
        }

        let predicate = eventStore.predicateForEvents(withStart: lookupStart, end: lookupEnd, calendars: [calendar])
        let candidates = eventStore.events(matching: predicate)
        let candidateValues = candidates.map { candidate in
            EventKitEventOccurrenceCandidate(
                id: candidate.eventIdentifier ?? candidate.calendarItemIdentifier,
                calendarID: candidate.calendar.calendarIdentifier, occurrenceDate: candidate.occurrenceDate)
        }
        let matchingIndices = EventKitExactEventOccurrenceSelector.matchingCandidateIndices(
            for: event, in: candidateValues)

        guard let matchingIndex = matchingIndices.first else { throw EventKitCalendarStoreError.eventNotFound(event) }

        guard matchingIndices.count == 1 else { throw EventKitCalendarStoreError.eventAmbiguous(event) }

        return candidates[matchingIndex]
    }

    private func writableEventKitCalendar(for calendar: CalendarIdentity) throws -> EKCalendar {
        guard let eventKitCalendar = eventStore.calendar(withIdentifier: calendar.id.eventKitIdentifier) else {
            throw EventKitCalendarStoreError.calendarNotFound(calendar)
        }

        guard eventKitCalendar.allowsContentModifications else {
            throw EventKitCalendarStoreError.calendarReadOnly(calendar)
        }

        return eventKitCalendar
    }

    private func requireFullAccess() async throws {
        let state = await authorizationStatus.authorizationStatus()
        guard state == .fullAccess else { throw CalendarAccessError.fullAccessRequired(state) }
    }

    private static func mapAvailability(_ availability: EKEventAvailability) -> EventAvailability {
        switch availability {
        case .busy: .busy
        case .tentative: .tentative
        case .free: .free
        case .unavailable: .unavailable
        case .notSupported: .notSupported
        @unknown default: .unknown
        }
    }

    /// Maps EventKit event status to `EventStatus`, prioritizing the current user's own attendee
    /// response when it excludes the event from sync. Other attendees declining or tentatively
    /// accepting a shared meeting must not exclude the event from sync for the calendar owner.
    private static func mapStatus(_ event: EKEvent) -> EventStatus {
        EventKitEventStatusMapper.mapStatus(
            currentUserParticipantStatus: event.attendees?.first(where: { $0.isCurrentUser }).map {
                mapParticipantStatus($0.participantStatus)
            }, eventStatus: mapEventStatus(event.status))
    }

    private static func mapEventStatus(_ status: EKEventStatus) -> EventKitEventStatusValue {
        switch status {
        case .confirmed: .confirmed
        case .tentative: .tentative
        case .canceled: .cancelled
        case .none: .unknown
        @unknown default: .unknown
        }
    }

    private static func mapParticipantStatus(_ status: EKParticipantStatus) -> EventKitParticipantStatusValue {
        switch status {
        case .accepted: .accepted
        case .declined: .declined
        case .tentative: .tentative
        case .unknown, .pending, .delegated, .completed, .inProcess: .other
        @unknown default: .other
        }
    }
}
