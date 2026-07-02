import CalRelayCore
@preconcurrency import EventKit
import Foundation

public enum EventKitCalendarStoreError: Error, CustomStringConvertible {
    case accessDenied
    case accessRestricted
    case writeOnlyAccess
    case accessNotGranted
    case calendarNotFound(CalendarReference)
    case calendarReadOnly(CalendarReference)
    case eventNotFound(EventSnapshot)
    case eventCalendarMismatch(expected: CalendarReference)

    public var description: String {
        switch self {
        case .accessDenied:
            "Calendar access was denied. Enable full calendar access for CalRelay in System Settings."
        case .accessRestricted:
            "Calendar access is restricted on this Mac."
        case .writeOnlyAccess:
            "Calendar access is write-only. CalRelay needs full access to list and reconcile calendars."
        case .accessNotGranted:
            "Full calendar access was not granted."
        case .calendarNotFound(let calendar):
            "Calendar is no longer available: \(calendar.sourceTitle) / \(calendar.title)."
        case .calendarReadOnly(let calendar):
            "Calendar is read-only: \(calendar.sourceTitle) / \(calendar.title)."
        case .eventNotFound(let event):
            "Event is no longer available for deletion: \(event.calendar.sourceTitle) / \(event.calendar.title)."
        case .eventCalendarMismatch(let expected):
            "Event selected for deletion no longer belongs to the expected calendar: \(expected.sourceTitle) / \(expected.title)."
        }
    }
}

enum EventKitEventStatusSnapshot: Equatable, Sendable {
    case confirmed
    case tentative
    case cancelled
    case unknown
}

enum EventKitParticipantStatusSnapshot: Equatable, Sendable {
    case accepted
    case declined
    case tentative
    case other
}

enum EventKitEventStatusMapper {
    static func mapStatus(
        currentUserParticipantStatus: EventKitParticipantStatusSnapshot?,
        eventStatus: EventKitEventStatusSnapshot
    ) -> EventStatus {
        switch currentUserParticipantStatus {
        case .declined:
            return .declined
        case .tentative:
            return .tentative
        case .accepted, .other, nil:
            break
        }

        switch eventStatus {
        case .confirmed:
            return .confirmed
        case .tentative:
            return .tentative
        case .cancelled:
            return .cancelled
        case .unknown:
            return .unknown
        }
    }
}

public final class EventKitCalendarStore: CalendarStorePort, @unchecked Sendable {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func listCalendars() async throws -> [CalendarSnapshot] {
        try await requestFullCalendarAccessIfNeeded()

        return eventStore.calendars(for: .event).map { calendar in
            CalendarSnapshot(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                sourceTitle: calendar.source.title,
                isWritable: calendar.allowsContentModifications
            )
        }
    }

    public func events(
        in calendar: CalendarReference,
        from start: Date,
        to end: Date
    ) async throws -> [EventSnapshot] {
        try await requestFullCalendarAccessIfNeeded()

        guard let eventKitCalendar = eventStore.calendar(withIdentifier: calendar.id) else {
            throw EventKitCalendarStoreError.calendarNotFound(calendar)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: [eventKitCalendar]
        )

        return eventStore.events(matching: predicate).map { event in
            EventSnapshot(
                id: event.eventIdentifier ?? event.calendarItemIdentifier,
                calendar: calendar,
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                availability: Self.mapAvailability(event.availability),
                status: Self.mapStatus(event)
            )
        }
    }

    public func createEvent(_ event: ProjectedEvent) async throws {
        try await requestFullCalendarAccessIfNeeded()

        let calendar = try writableEventKitCalendar(for: event.destinationCalendar)
        let eventKitEvent = EKEvent(eventStore: eventStore)
        eventKitEvent.calendar = calendar
        eventKitEvent.title = event.title
        eventKitEvent.startDate = event.start
        eventKitEvent.endDate = event.end
        eventKitEvent.isAllDay = event.isAllDay

        try eventStore.save(eventKitEvent, span: .thisEvent, commit: true)
    }

    public func deleteEvent(_ event: EventSnapshot) async throws {
        try await requestFullCalendarAccessIfNeeded()

        _ = try writableEventKitCalendar(for: event.calendar)

        guard let eventKitEvent = eventStore.event(withIdentifier: event.id) else {
            throw EventKitCalendarStoreError.eventNotFound(event)
        }

        guard eventKitEvent.calendar.calendarIdentifier == event.calendar.id else {
            throw EventKitCalendarStoreError.eventCalendarMismatch(expected: event.calendar)
        }

        try eventStore.remove(eventKitEvent, span: .thisEvent, commit: true)
    }

    private func writableEventKitCalendar(for calendar: CalendarReference) throws -> EKCalendar {
        guard let eventKitCalendar = eventStore.calendar(withIdentifier: calendar.id) else {
            throw EventKitCalendarStoreError.calendarNotFound(calendar)
        }

        guard eventKitCalendar.allowsContentModifications else {
            throw EventKitCalendarStoreError.calendarReadOnly(calendar)
        }

        return eventKitCalendar
    }

    private func requestFullCalendarAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return
        case .notDetermined:
            let granted = try await requestFullAccessToEvents()
            guard granted else {
                throw EventKitCalendarStoreError.accessNotGranted
            }
        case .denied:
            throw EventKitCalendarStoreError.accessDenied
        case .restricted:
            throw EventKitCalendarStoreError.accessRestricted
        case .writeOnly:
            throw EventKitCalendarStoreError.writeOnlyAccess
        @unknown default:
            throw EventKitCalendarStoreError.accessNotGranted
        }
    }

    private func requestFullAccessToEvents() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private static func mapAvailability(_ availability: EKEventAvailability) -> EventAvailability {
        switch availability {
        case .busy:
            .busy
        case .tentative:
            .tentative
        case .free:
            .free
        case .unavailable:
            .unavailable
        case .notSupported:
            .notSupported
        @unknown default:
            .unknown
        }
    }

    /// Maps EventKit event status to `EventStatus`, prioritizing the current user's own attendee
    /// response when it excludes the event from sync. Other attendees declining or tentatively
    /// accepting a shared meeting must not exclude the event from sync for the calendar owner.
    private static func mapStatus(_ event: EKEvent) -> EventStatus {
        EventKitEventStatusMapper.mapStatus(
            currentUserParticipantStatus: event.attendees?
                .first(where: { $0.isCurrentUser })
                .map { mapParticipantStatus($0.participantStatus) },
            eventStatus: mapEventStatus(event.status)
        )
    }

    private static func mapEventStatus(_ status: EKEventStatus) -> EventKitEventStatusSnapshot {
        switch status {
        case .confirmed:
            .confirmed
        case .tentative:
            .tentative
        case .canceled:
            .cancelled
        case .none:
            .unknown
        @unknown default:
            .unknown
        }
    }

    private static func mapParticipantStatus(_ status: EKParticipantStatus) -> EventKitParticipantStatusSnapshot {
        switch status {
        case .accepted:
            .accepted
        case .declined:
            .declined
        case .tentative:
            .tentative
        case .unknown, .pending, .delegated, .completed, .inProcess:
            .other
        @unknown default:
            .other
        }
    }
}
