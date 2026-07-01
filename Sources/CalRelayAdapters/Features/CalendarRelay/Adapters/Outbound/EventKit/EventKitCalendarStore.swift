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

    private static func mapStatus(_ event: EKEvent) -> EventStatus {
        if event.attendees?.contains(where: { $0.participantStatus == .declined }) == true {
            return .declined
        }

        switch event.status {
        case .confirmed:
            return .confirmed
        case .tentative:
            return .tentative
        case .canceled:
            return .cancelled
        case .none:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}