import CalRelayKit
import Foundation

enum ExactEventOccurrenceResolverTests {
    static func runAll() throws {
        try testResolvesOnlyTheExactPlannedOccurrence()
        try testMissingExactOccurrenceThrowsEventNotFound()
        try testDuplicateExactCandidatesThrowEventAmbiguous()
    }

    private static func testResolvesOnlyTheExactPlannedOccurrence() throws {
        let fixture = ExactOccurrenceResolverFixture()
        let candidates = [
            fixture.candidate(occurrenceDate: fixture.neighboringOccurrenceDate),
            fixture.candidate(calendarID: "other-calendar"), fixture.candidate(id: "unrelated-event"),
            fixture.candidate(occurrenceDate: nil), fixture.candidate()
        ]

        let index = try EventKitExactEventOccurrenceResolver.resolveCandidateIndex(
            for: fixture.identity, in: candidates)

        try expect(index == 4, "ACCESS-AC-12: resolver should select only the exact planned occurrence")
    }

    private static func testMissingExactOccurrenceThrowsEventNotFound() throws {
        let fixture = ExactOccurrenceResolverFixture()
        let candidates = [
            fixture.candidate(occurrenceDate: fixture.neighboringOccurrenceDate),
            fixture.candidate(calendarID: "other-calendar"), fixture.candidate(id: "unrelated-event"),
            fixture.candidate(occurrenceDate: nil)
        ]

        do {
            let index = try EventKitExactEventOccurrenceResolver.resolveCandidateIndex(
                for: fixture.identity, in: candidates)
            throw TestFailure("Missing exact occurrence must not substitute candidate at index \(index)")
        } catch let error as EventKitCalendarStoreError {
            guard case .eventNotFound(let identity) = error else {
                throw TestFailure("Missing exact occurrence should throw eventNotFound")
            }
            try expect(
                identity == fixture.identity,
                "ACCESS-AC-12: eventNotFound should retain the exact planned occurrence identity")
        }
    }

    private static func testDuplicateExactCandidatesThrowEventAmbiguous() throws {
        let fixture = ExactOccurrenceResolverFixture()
        let candidates = [
            fixture.candidate(), fixture.candidate(occurrenceDate: fixture.neighboringOccurrenceDate),
            fixture.candidate()
        ]

        do {
            let index = try EventKitExactEventOccurrenceResolver.resolveCandidateIndex(
                for: fixture.identity, in: candidates)
            throw TestFailure("Ambiguous exact occurrence must not select candidate at index \(index)")
        } catch let error as EventKitCalendarStoreError {
            guard case .eventAmbiguous(let identity) = error else {
                throw TestFailure("Duplicate exact candidates should throw eventAmbiguous")
            }
            try expect(
                identity == fixture.identity,
                "ACCESS-AC-12: eventAmbiguous should retain the exact planned occurrence identity")
        }
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct ExactOccurrenceResolverFixture {
    let occurrenceDate = Date(timeIntervalSince1970: 10_000)
    let neighboringOccurrenceDate = Date(timeIntervalSince1970: 20_000)

    var identity: CalendarEventIdentity {
        CalendarEventIdentity(
            id: "recurring-event",
            calendar: CalendarIdentity(id: "planned-calendar", title: "Test Calendar", sourceTitle: "Test Source"),
            occurrenceDate: occurrenceDate, lookupStart: Date(timeIntervalSince1970: 1_000),
            lookupEnd: Date(timeIntervalSince1970: 30_000))
    }

    func candidate(
        id: String = "recurring-event", calendarID: String = "planned-calendar",
        occurrenceDate: Date? = Date(timeIntervalSince1970: 10_000)
    ) -> EventKitEventOccurrenceCandidate {
        EventKitEventOccurrenceCandidate(id: id, calendarID: calendarID, occurrenceDate: occurrenceDate)
    }
}
