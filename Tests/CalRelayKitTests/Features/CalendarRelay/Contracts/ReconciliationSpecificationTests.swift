import CalRelayKit
import Foundation

enum ReconciliationSpecificationTests {
    static func runAll() async throws {
        try testVisibleMatchingUsesOnlyVisibleFields()
        try testRenameCancellationAndDuplicateReplacement()
        try await testLogicalHubExcludesStaleLocalAndCancelledRemoteMarkers()
        try await testExplanationUsesSharedActionsAndRetainsAllCausalIdentities()
        try await testExactDuplicatesRemainDiagnosticWithoutChangingSelection()
    }

    private static func testVisibleMatchingUsesOnlyVisibleFields() throws {
        let calendar = identity(id: "hub", title: "Hub", source: "iCloud")
        let expected = projection(calendar: calendar, title: "[ACME] Planning")
        let matching = event(id: "provider-event-a", calendar: calendar, title: expected.title)
        let sameVisibleFields = event(id: "provider-event-b", calendar: calendar, title: expected.title)

        for existing in [matching, sameVisibleFields] {
            let plan = ReconciliationPlanner.plan(
                expected: [expected], existing: [existing], managedPrefixes: ["[ACME]"])
            try expect(plan.creates.isEmpty && plan.deletes.isEmpty, "Provider event identity must not affect matching")
        }

        let visibleChanges = [
            event(id: "calendar", calendar: identity(id: "other", title: "Hub", source: "iCloud"), title: expected.title),
            event(id: "title", calendar: calendar, title: "[ACME] planning"),
            event(id: "start", calendar: calendar, title: expected.title, start: expected.start.addingTimeInterval(1)),
            event(id: "end", calendar: calendar, title: expected.title, end: expected.end.addingTimeInterval(1)),
            event(id: "all-day", calendar: calendar, title: expected.title, isAllDay: true),
        ]
        for changed in visibleChanges {
            let plan = ReconciliationPlanner.plan(
                expected: [expected], existing: [changed], managedPrefixes: ["[ACME]"])
            try expect(plan.creates == [expected], "Every changed visible field must require the expected projection")
            try expect(plan.deletes == [changed], "Every changed managed projection must become stale")
        }
    }

    private static func testRenameCancellationAndDuplicateReplacement() throws {
        let calendar = identity(id: "hub", title: "Hub", source: "iCloud")
        let old = event(id: "old", calendar: calendar, title: "[ACME] Old")
        let renamed = projection(calendar: calendar, title: "[ACME] New")
        let renamePlan = ReconciliationPlanner.plan(
            expected: [renamed], existing: [old], managedPrefixes: ["[ACME]"])
        try expect(renamePlan == ReconciliationPlan(creates: [renamed], deletes: [old]), "Rename is delete plus create")

        let cancelled = event(id: "cancelled", calendar: calendar, title: renamed.title, status: .cancelled)
        let cancelledPlan = ReconciliationPlanner.plan(
            expected: [renamed], existing: [cancelled], managedPrefixes: ["[ACME]"])
        try expect(
            cancelledPlan == ReconciliationPlan(creates: [renamed], deletes: [cancelled]),
            "A cancelled managed match must be deleted and replaced")

        let first = event(id: "duplicate-a", calendar: calendar, title: renamed.title)
        let second = event(id: "duplicate-b", calendar: calendar, title: renamed.title)
        let duplicatePlan = ReconciliationPlanner.plan(
            expected: [renamed], existing: [first, second], managedPrefixes: ["[ACME]"])
        try expect(duplicatePlan.creates == [renamed], "Duplicate matches need one canonical replacement")
        try expect(duplicatePlan.deletes == [first, second], "Every managed duplicate must be deleted")
    }

    private static func testLogicalHubExcludesStaleLocalAndCancelledRemoteMarkers() async throws {
        let topology = topologyWithTwoWorkCalendars()
        let staleHub = event(id: "stale-hub", calendar: topology.hubIdentity, title: "[A] Stale")
        let cancelledRemote = event(
            id: "cancelled-remote", calendar: topology.hubIdentity, title: "[REMOTE] Cancelled", status: .cancelled)
        let staleWork = event(id: "stale-work", calendar: topology.workBIdentity, title: staleHub.title)
        let cancelledWorkA = event(id: "cancelled-work-a", calendar: topology.workAIdentity, title: cancelledRemote.title)
        let cancelledWorkB = event(id: "cancelled-work-b", calendar: topology.workBIdentity, title: cancelledRemote.title)
        let store = ReconciliationSpecificationStore(
            calendars: topology.calendars,
            eventsByCalendar: [
                topology.hub.id: [staleHub, cancelledRemote],
                topology.workA.id: [cancelledWorkA],
                topology.workB.id: [staleWork, cancelledWorkB],
            ])

        let result = try await useCase(store: store).dryRunResult(settings: topology.settings, now: referenceDate())
        let deleted = result.actions.compactMap { action -> CalendarEvent? in
            guard case .delete(_, let event) = action else { return nil }
            return event
        }
        let created = result.actions.compactMap { action -> CalendarEventProjection? in
            guard case .create(_, let event) = action else { return nil }
            return event
        }

        try expect(deleted.contains(staleHub), "The stale locally owned hub projection must be deleted")
        try expect(!deleted.contains(cancelledRemote), "A cancelled non-local marked hub event must be preserved")
        try expect(
            Set(deleted.map(\.id)) == Set([staleHub.id, staleWork.id, cancelledWorkA.id, cancelledWorkB.id]),
            "Stale local and cancelled-remote work blockers must be removed in the same computation")
        try expect(
            !created.contains { $0.title == staleHub.title || $0.title == cancelledRemote.title },
            "Neither removed logical-hub input may produce a work blocker")
    }

    private static func testExplanationUsesSharedActionsAndRetainsAllCausalIdentities() async throws {
        let topology = topologyWithOneWorkCalendar()
        let first = event(id: "source-a", calendar: topology.workIdentity, title: "Planning")
        let second = event(id: "source-b", calendar: topology.workIdentity, title: "Planning")
        let store = ReconciliationSpecificationStore(
            calendars: topology.calendars, eventsByCalendar: [topology.work.id: [first, second]])
        let useCase = useCase(store: store)

        let result = try await useCase.dryRunResult(settings: topology.settings, now: referenceDate())
        let explanation = try await useCase.explain(settings: topology.settings, now: referenceDate())

        try expect(explanation.actions.map(\.action) == result.actions, "Explanation must annotate the shared ordered plan")
        try expect(
            explanation.candidates.map(\.event.identity) == [first.identity, second.identity],
            "Explanation must classify every loaded input event")
        try expect(
            explanation.candidates.allSatisfy {
                $0.eligibility == .noCurrentUserAttendeeIncluded(.busy)
                    && $0.routing == .workToHubSource
                    && $0.expectation == .noMatchingExpectation
                    && $0.disposition == .preservedUnmanagedOrNonLocal
            }, "Every input must receive eligibility, routing, expectation, and disposition classifications")
        guard let create = explanation.actions.first(where: { action in
            if case .create(.hub, _) = action.action { return true }
            return false
        }) else { throw TestFailure("Expected one explained hub create") }
        try expect(
            create.causalEvents == [first.identity, second.identity],
            "Set-semantic expectation must retain every causal source occurrence")
    }

    private static func testExactDuplicatesRemainDiagnosticWithoutChangingSelection() async throws {
        let topology = topologyWithOneWorkCalendar()
        let source = event(id: "source", calendar: topology.workIdentity, title: "Planning")
        let expectedTitle = "[A] Planning"
        let laterID = event(id: "z-event", calendar: topology.hubIdentity, title: expectedTitle)
        let earlierID = event(id: "a-event", calendar: topology.hubIdentity, title: expectedTitle)
        let store = ReconciliationSpecificationStore(
            calendars: topology.calendars,
            eventsByCalendar: [topology.hub.id: [laterID, earlierID], topology.work.id: [source]])
        let useCase = useCase(store: store)

        let result = try await useCase.dryRunResult(settings: topology.settings, now: referenceDate())
        let explanation = try await useCase.explain(settings: topology.settings, now: referenceDate())
        let deleted = result.actions.compactMap { action -> CalendarEvent? in
            guard case .delete(_, let event) = action else { return nil }
            return event
        }
        let created = result.actions.compactMap { action -> CalendarEventProjection? in
            guard case .create(_, let event) = action else { return nil }
            return event
        }

        try expect(deleted.map(\.id) == [earlierID.id, laterID.id], "Exact identity may only total-order tied selected deletes")
        try expect(deleted.count == 2 && created.count == 1, "Exact IDs must not choose a duplicate survivor")
        try expect(
            Set(explanation.candidates.filter { $0.event.title == expectedTitle }.map(\.event.id))
                == Set([earlierID.id, laterID.id]),
            "Explanation must keep exact visible duplicates distinguishable by diagnostic event ID")
        try expect(
            explanation.candidates.filter { $0.event.title == expectedTitle }.allSatisfy {
                $0.disposition == .selectedDuplicateSetDeletion
            }, "Every exact managed duplicate must retain the replace-all disposition")
    }

    private static func topologyWithOneWorkCalendar() -> OneWorkTopology {
        let hub = RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true)
        let work = RelayCalendar(id: "work-a", title: "Work A", sourceTitle: "Provider A", isWritable: true)
        return OneWorkTopology(
            hub: hub, work: work,
            settings: CalendarRelaySettings(
                hubCalendar: HubCalendarSettings(
                    calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
                personalPrefix: "[PERSONAL]", syncWindowDays: 10,
                workCalendars: [
                    WorkCalendarSettings(
                        name: "A", prefix: "[A]",
                        calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
                ]))
    }

    private static func topologyWithTwoWorkCalendars() -> TwoWorkTopology {
        let hub = RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true)
        let workA = RelayCalendar(id: "work-a", title: "Work A", sourceTitle: "Provider A", isWritable: true)
        let workB = RelayCalendar(id: "work-b", title: "Work B", sourceTitle: "Provider B", isWritable: true)
        return TwoWorkTopology(
            hub: hub, workA: workA, workB: workB,
            settings: CalendarRelaySettings(
                hubCalendar: HubCalendarSettings(
                    calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
                personalPrefix: "[PERSONAL]", syncWindowDays: 10,
                workCalendars: [
                    WorkCalendarSettings(
                        name: "A", prefix: "[A]",
                        calendar: CalendarSelector(sourceTitle: workA.sourceTitle, calendarTitle: workA.title)),
                    WorkCalendarSettings(
                        name: "B", prefix: "[B]",
                        calendar: CalendarSelector(sourceTitle: workB.sourceTitle, calendarTitle: workB.title)),
                ]))
    }

    private static func useCase(store: ReconciliationSpecificationStore) -> ReconcileCalendarsUseCase {
        ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())
    }

    private static func identity(id: String, title: String, source: String) -> CalendarIdentity {
        CalendarIdentity(id: id, title: title, sourceTitle: source)
    }

    private static func event(
        id: String, calendar: CalendarIdentity, title: String,
        start: Date = Date(timeIntervalSince1970: 10_000),
        end: Date = Date(timeIntervalSince1970: 11_000), isAllDay: Bool = false,
        status: EventStatus = .confirmed
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, calendar: calendar, title: title, start: start, end: end, isAllDay: isAllDay,
            availability: .busy, status: status)
    }

    private static func projection(
        calendar: CalendarIdentity, title: String,
        start: Date = Date(timeIntervalSince1970: 10_000),
        end: Date = Date(timeIntervalSince1970: 11_000), isAllDay: Bool = false
    ) -> CalendarEventProjection {
        CalendarEventProjection(
            destinationCalendar: calendar, title: title, start: start, end: end, isAllDay: isAllDay)
    }

    private static func referenceDate() -> Date { Date(timeIntervalSince1970: 10_000) }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct OneWorkTopology {
    let hub: RelayCalendar
    let work: RelayCalendar
    let settings: CalendarRelaySettings

    var calendars: [RelayCalendar] { [hub, work] }
    var hubIdentity: CalendarIdentity { CalendarIdentity(id: hub.id, title: hub.title, sourceTitle: hub.sourceTitle) }
    var workIdentity: CalendarIdentity {
        CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle)
    }
}

private struct TwoWorkTopology {
    let hub: RelayCalendar
    let workA: RelayCalendar
    let workB: RelayCalendar
    let settings: CalendarRelaySettings

    var calendars: [RelayCalendar] { [hub, workA, workB] }
    var hubIdentity: CalendarIdentity { CalendarIdentity(id: hub.id, title: hub.title, sourceTitle: hub.sourceTitle) }
    var workAIdentity: CalendarIdentity {
        CalendarIdentity(id: workA.id, title: workA.title, sourceTitle: workA.sourceTitle)
    }
    var workBIdentity: CalendarIdentity {
        CalendarIdentity(id: workB.id, title: workB.title, sourceTitle: workB.sourceTitle)
    }
}

private actor ReconciliationSpecificationStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private let eventsByCalendar: [PhysicalCalendarReference: [CalendarEvent]]

    init(calendars: [RelayCalendar], eventsByCalendar: [PhysicalCalendarReference: [CalendarEvent]]) {
        self.calendars = calendars
        self.eventsByCalendar = eventsByCalendar
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventsByCalendar[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        throw TestFailure("Reconciliation specification dry-run must not create")
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        throw TestFailure("Reconciliation specification dry-run must not delete")
    }
}
