import Foundation

public struct EventKitEventOccurrenceCandidate: Equatable, Sendable {
    public let id: CalendarEventReference
    public let calendarID: PhysicalCalendarReference
    public let occurrenceDate: Date?

    public init(id: String, calendarID: String, occurrenceDate: Date?) {
        self.id = CalendarEventReference(providerIdentifier: id)
        self.calendarID = PhysicalCalendarReference(providerIdentifier: calendarID)
        self.occurrenceDate = occurrenceDate
    }
}

public enum EventKitExactEventOccurrenceResolver {
    public static func resolveCandidateIndex(
        for identity: CalendarEventIdentity, in candidates: [EventKitEventOccurrenceCandidate]
    ) throws -> Int {
        let matchingIndices = candidates.indices.filter { index in
            let candidate = candidates[index]
            return candidate.id == identity.id && candidate.calendarID == identity.calendar.id
                && candidate.occurrenceDate == identity.occurrenceDate
        }

        guard let matchingIndex = matchingIndices.first else {
            throw EventKitCalendarStoreError.eventNotFound(identity)
        }

        guard matchingIndices.count == 1 else { throw EventKitCalendarStoreError.eventAmbiguous(identity) }

        return matchingIndex
    }
}
