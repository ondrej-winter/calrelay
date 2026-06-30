import CalRelayCore
@preconcurrency import EventKit
import Foundation

enum EventKitCalendarStoreError: Error, CustomStringConvertible {
    case accessDenied
    case accessRestricted
    case writeOnlyAccess
    case accessNotGranted

    var description: String {
        switch self {
        case .accessDenied:
            "Calendar access was denied. Enable full calendar access for calrelay in System Settings."
        case .accessRestricted:
            "Calendar access is restricted on this Mac."
        case .writeOnlyAccess:
            "Calendar access is write-only. calrelay needs full access to list and reconcile calendars."
        case .accessNotGranted:
            "Full calendar access was not granted."
        }
    }
}

final class EventKitCalendarStore: CalendarStorePort, @unchecked Sendable {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func listCalendars() async throws -> [CalendarSnapshot] {
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

    func events(
        in calendar: CalendarReference,
        from start: Date,
        to end: Date
    ) async throws -> [EventSnapshot] {
        throw CalendarStoreOperationUnavailableError(operation: "Event reading")
    }

    func createEvent(_ event: ProjectedEvent) async throws {
        throw CalendarStoreOperationUnavailableError(operation: "Event creation")
    }

    func deleteEvent(_ event: EventSnapshot) async throws {
        throw CalendarStoreOperationUnavailableError(operation: "Event deletion")
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
}

private struct CalendarStoreOperationUnavailableError: Error, CustomStringConvertible {
    let operation: String

    var description: String {
        "\(operation) is not available until the EventKit event adapter is implemented."
    }
}