import CalRelayKit
import Foundation

enum RoutingSpecificationTests {
    static func runAll() async throws {
        try testRelayDirectionUsesExactMarkersAndMarkedHubAuthority()
        try await testStaleLocalHubProjectionIsExcludedFromLogicalHub()
        try await testTwoMachinesConvergeThroughSharedHubWithoutRemoteMarkerRegistry()
        try await testExternalMarkedHubEventRemainsAuthoritativeAndWorkDeletionStaysLocal()
        try await testIndependentWindowsLimitCrossMachineCoverageToTheirOverlap()
        try await testRetiredMarkerCanBeRepublishedAndRemovedByRepeatedCleanup()
    }

    private static func testRelayDirectionUsesExactMarkersAndMarkedHubAuthority() throws {
        let hub = identity(calendar(id: "hub", title: "Shared Hub", source: "iCloud"))
        let targets = [
            target(calendar: calendar(id: "work-a", title: "Work A", source: "Provider A"), marker: "[A]"),
            target(calendar: calendar(id: "work-acme", title: "Work ACME", source: "Provider ACME"), marker: "[ACME]"),
            target(calendar: calendar(id: "work-b", title: "Work B", source: "Provider B"), marker: "[B]")
        ]
        let interval = routingInterval()
        let localMarked = event(
            id: "local-a", calendar: hub, title: "[A] Planning", start: interval.start, end: interval.end,
            availability: .free, currentUserParticipantStatus: .declined)
        let exactCollision = event(
            id: "local-acme", calendar: hub, title: "[ACME] Review", start: interval.start, end: interval.end,
            availability: .tentative, currentUserParticipantStatus: .other)
        let remoteMarked = event(
            id: "remote", calendar: hub, title: "[EXTERNAL] Vendor Call", start: interval.start, end: interval.end,
            availability: .free)
        let cancelledRemote = event(
            id: "cancelled-remote", calendar: hub, title: "[EXTERNAL] Cancelled", start: interval.start,
            end: interval.end, status: .cancelled)
        let personal = event(id: "personal", calendar: hub, title: "Doctor", start: interval.start, end: interval.end)

        let localProjections = HubToWorkProjector.project(
            hubEvents: [localMarked], to: targets, personalPrefix: "[PERSONAL]")
        let collisionProjections = HubToWorkProjector.project(
            hubEvents: [exactCollision], to: targets, personalPrefix: "[PERSONAL]")
        let remoteProjections = HubToWorkProjector.project(
            hubEvents: [remoteMarked], to: targets, personalPrefix: "[PERSONAL]")
        let cancelledProjections = HubToWorkProjector.project(
            hubEvents: [cancelledRemote], to: targets, personalPrefix: "[PERSONAL]")
        let personalProjections = HubToWorkProjector.project(
            hubEvents: [personal], to: targets, personalPrefix: "[PERSONAL]")

        try expect(
            localProjections.map(\.destinationCalendar.id) == [targets[1].calendar.id, targets[2].calendar.id],
            "A local [A] blocker should skip only the exact [A] origin")
        try expect(
            localProjections.allSatisfy { $0.title == localMarked.title },
            "A locally marked blocker should route unchanged regardless of response or availability")
        try expect(
            collisionProjections.map(\.destinationCalendar.id) == [targets[0].calendar.id, targets[2].calendar.id],
            "[ACME] must not be classified as the raw-prefix marker [A]")
        try expect(
            remoteProjections.map(\.destinationCalendar.id) == targets.map(\.calendar.id),
            "A non-local valid marker should route to every configured work calendar")
        try expect(
            remoteProjections.allSatisfy { $0.title == remoteMarked.title },
            "A non-local valid marked hub event should retain its complete marked title")
        try expect(cancelledProjections.isEmpty, "A cancelled valid marked hub event should not route")
        try expect(
            personalProjections.map(\.title) == Array(repeating: "[PERSONAL] Doctor", count: targets.count),
            "An unmarked hub event should receive the personal marker in every work projection")
    }

    private static func testStaleLocalHubProjectionIsExcludedFromLogicalHub() async throws {
        let topology = routingTopology()
        let interval = routingInterval()
        let staleHubProjection = event(
            id: "stale-a", calendar: identity(topology.hub), title: "[A] Removed Source", start: interval.start,
            end: interval.end)
        let state = RoutingSharedCalendarState(events: [staleHubProjection])
        let store = RoutingMachineCalendarStore(
            visibleCalendars: [topology.hub, topology.workA, topology.workB], state: state)
        let settings = settings(
            hub: topology.hub, personalMarker: "[PERSONAL]", syncWindowDays: 10,
            workCalendars: [(topology.workA, "[A]"), (topology.workB, "[B]")])

        let plan = try await reconciliation(store: store, calendar: utcCalendar()).dryRun(
            settings: settings, now: referenceDate())

        try expect(
            plan.deletes.contains(staleHubProjection), "The stale locally owned hub projection should be deleted")
        try expect(
            !plan.creates.contains { projection in
                projection.destinationCalendar == identity(topology.workB)
                    && projection.title == staleHubProjection.title
            }, "A stale locally owned hub projection should not route for an extra cycle")
    }

    private static func testTwoMachinesConvergeThroughSharedHubWithoutRemoteMarkerRegistry() async throws {
        let topology = routingTopology()
        let interval = routingInterval()
        let source = event(
            id: "work-a-source", calendar: identity(topology.workA), title: "Client Planning", start: interval.start,
            end: interval.end)
        let state = RoutingSharedCalendarState(events: [source])
        let storeA = RoutingMachineCalendarStore(visibleCalendars: [topology.hub, topology.workA], state: state)
        let storeB = RoutingMachineCalendarStore(visibleCalendars: [topology.hub, topology.workB], state: state)
        let settingsA = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_A]", syncWindowDays: 10,
            workCalendars: [(topology.workA, "[A]")])
        let settingsB = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_B]", syncWindowDays: 10,
            workCalendars: [(topology.workB, "[B]")])
        let machineA = reconciliation(store: storeA, calendar: utcCalendar())
        let machineB = reconciliation(store: storeB, calendar: utcCalendar())

        let publisherPlan = try await machineA.apply(settings: settingsA, now: referenceDate())
        let receiverPlan = try await machineB.apply(settings: settingsB, now: referenceDate())

        try expect(
            publisherPlan.creates.contains { projection in
                projection.destinationCalendar == identity(topology.hub) && projection.title == "[A] Client Planning"
            }, "The publishing machine should create its marked hub projection")
        try expect(
            !publisherPlan.creates.contains { $0.destinationCalendar == identity(topology.workA) },
            "The publishing machine should not feed the marked blocker back to its origin work calendar")
        try expect(
            receiverPlan.creates.contains { projection in
                projection.destinationCalendar == identity(topology.workB) && projection.title == "[A] Client Planning"
            }, "The receiving machine should route the non-local marker without configuring [A]")

        let hubEvents = await state.events(in: topology.hub.id)
        let workAEvents = await state.events(in: topology.workA.id)
        let workBEvents = await state.events(in: topology.workB.id)
        try expect(
            hubEvents.map(\.title) == ["[A] Client Planning"],
            "The shared hub should contain one canonical blocker after publication")
        try expect(workAEvents == [source], "The origin work calendar should retain only its unmarked source")
        try expect(
            workBEvents.map(\.title) == ["[A] Client Planning"],
            "The second work calendar should receive the remote-style blocker")

        let settledA = try await machineA.dryRun(settings: settingsA, now: referenceDate())
        let settledB = try await machineB.dryRun(settings: settingsB, now: referenceDate())
        try expect(settledA.creates.isEmpty && settledA.deletes.isEmpty, "The publishing machine should converge")
        try expect(settledB.creates.isEmpty && settledB.deletes.isEmpty, "The receiving machine should converge")
    }

    private static func testExternalMarkedHubEventRemainsAuthoritativeAndWorkDeletionStaysLocal() async throws {
        let topology = routingTopology()
        let interval = routingInterval()
        let external = event(
            id: "external", calendar: identity(topology.hub), title: "[EXTERNAL] Vendor Call", start: interval.start,
            end: interval.end, availability: .free)
        let cancelledExternal = event(
            id: "cancelled-external", calendar: identity(topology.hub), title: "[EXTERNAL] Cancelled",
            start: interval.start.addingTimeInterval(3_600), end: interval.end.addingTimeInterval(3_600),
            status: .cancelled)
        let staleWorkBlocker = event(
            id: "stale-work", calendar: identity(topology.workB), title: "[ORPHAN] Stale",
            start: interval.start.addingTimeInterval(7_200), end: interval.end.addingTimeInterval(7_200))
        let state = RoutingSharedCalendarState(events: [external, cancelledExternal, staleWorkBlocker])
        let store = RoutingMachineCalendarStore(visibleCalendars: [topology.hub, topology.workB], state: state)
        let localSettings = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_B]", syncWindowDays: 10,
            workCalendars: [(topology.workB, "[B]")])
        let receiver = reconciliation(store: store, calendar: utcCalendar())

        let plan = try await receiver.apply(settings: localSettings, now: referenceDate())

        try expect(
            !plan.deletes.contains(external) && !plan.deletes.contains(cancelledExternal),
            "A receiving machine should preserve both active and cancelled non-local marked hub events")
        try expect(
            plan.creates.contains { $0.destinationCalendar == identity(topology.workB) && $0.title == external.title },
            "A manually authored non-local marked hub event should route as an authoritative blocker")
        try expect(
            !plan.creates.contains { $0.title == cancelledExternal.title },
            "A cancelled non-local marked hub event should remain excluded from routing")
        try expect(
            plan.deletes.contains(staleWorkBlocker),
            "The same machine should delete a stale valid-marker blocker from its configured work calendar")

        let settled = try await receiver.dryRun(settings: localSettings, now: referenceDate())
        try expect(settled.creates.isEmpty && settled.deletes.isEmpty, "The receiving machine should converge")
        let preservedHubEvents = await state.events(in: topology.hub.id)
        try expect(
            Set(preservedHubEvents.map(\.id)) == Set([external.id, cancelledExternal.id]),
            "The non-local marked hub events should remain authoritative while present")
    }

    private static func testIndependentWindowsLimitCrossMachineCoverageToTheirOverlap() async throws {
        let topology = routingTopology()
        let now = referenceDate()
        let publisherCalendar = utcCalendar()
        let receiverCalendar = try calendar(timeZoneIdentifier: "America/Los_Angeles")
        let publisherWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: now, calendar: publisherCalendar, syncWindowDays: 10)
        let receiverWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: now, calendar: receiverCalendar, syncWindowDays: 2)
        let overlapping = event(
            id: "overlapping", calendar: identity(topology.workA), title: "Overlap",
            start: receiverWindow.start.addingTimeInterval(-3_600), end: receiverWindow.start.addingTimeInterval(3_600))
        let touchingReceiverEnd = event(
            id: "publisher-only", calendar: identity(topology.workA), title: "Publisher Horizon",
            start: receiverWindow.end, end: receiverWindow.end.addingTimeInterval(3_600))
        let state = RoutingSharedCalendarState(events: [overlapping, touchingReceiverEnd])
        let storeA = RoutingMachineCalendarStore(visibleCalendars: [topology.hub, topology.workA], state: state)
        let storeB = RoutingMachineCalendarStore(visibleCalendars: [topology.hub, topology.workB], state: state)
        let settingsA = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_A]", syncWindowDays: 10,
            workCalendars: [(topology.workA, "[A]")])
        let settingsB = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_B]", syncWindowDays: 2,
            workCalendars: [(topology.workB, "[B]")])

        try expect(
            overlaps(overlapping, window: publisherWindow) && overlaps(overlapping, window: receiverWindow),
            "The representative overlap event should be inside both machine windows")
        try expect(
            overlaps(touchingReceiverEnd, window: publisherWindow)
                && !overlaps(touchingReceiverEnd, window: receiverWindow),
            "An exact touch at the receiving end boundary should remain publisher-only")

        _ = try await reconciliation(store: storeA, calendar: publisherCalendar).apply(settings: settingsA, now: now)
        let receiverPlan = try await reconciliation(store: storeB, calendar: receiverCalendar).dryRun(
            settings: settingsB, now: now)

        try expect(
            receiverPlan.creates.contains { $0.title == "[A] Overlap" },
            "A blocker inside both independently computed windows should route to the receiver")
        try expect(
            !receiverPlan.creates.contains { $0.title == "[A] Publisher Horizon" },
            "A publisher-only horizon must not establish receiver coverage")

        let shortPublisherWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: now, calendar: publisherCalendar, syncWindowDays: 1)
        let longReceiverCalendar = try calendar(timeZoneIdentifier: "Asia/Tokyo")
        let longReceiverWindow = OrdinaryReconciliationWindow.calculate(
            referenceDate: now, calendar: longReceiverCalendar, syncWindowDays: 10)
        let receiverOnly = event(
            id: "receiver-only", calendar: identity(topology.workA), title: "Receiver Horizon",
            start: shortPublisherWindow.end, end: shortPublisherWindow.end.addingTimeInterval(3_600))
        let receiverOnlyState = RoutingSharedCalendarState(events: [receiverOnly])
        let shortPublisherStore = RoutingMachineCalendarStore(
            visibleCalendars: [topology.hub, topology.workA], state: receiverOnlyState)
        let shortSettings = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_A]", syncWindowDays: 1,
            workCalendars: [(topology.workA, "[A]")])

        try expect(
            !overlaps(receiverOnly, window: shortPublisherWindow) && overlaps(receiverOnly, window: longReceiverWindow),
            "The receiver-only event should touch the publisher boundary but overlap the longer receiver window")
        let shortPublisherPlan = try await reconciliation(store: shortPublisherStore, calendar: publisherCalendar)
            .apply(settings: shortSettings, now: now)
        try expect(
            shortPublisherPlan.creates.isEmpty,
            "An event outside the publishing machine's window should never enter the shared hub")
        try expect(
            await receiverOnlyState.events(in: topology.hub.id).isEmpty,
            "A receiving machine cannot route a blocker that the publisher never exposed to the hub")
    }

    private static func testRetiredMarkerCanBeRepublishedAndRemovedByRepeatedCleanup() async throws {
        let topology = routingTopology()
        let now = referenceDate()
        let interval = routingInterval()
        let initialHubArtifact = event(
            id: "old-hub", calendar: identity(topology.hub), title: "[OLD] Hub Artifact", start: interval.start,
            end: interval.end)
        let initialWorkArtifact = event(
            id: "old-clean-work", calendar: identity(topology.workB), title: "[OLD] Work Artifact",
            start: interval.start.addingTimeInterval(3_600), end: interval.end.addingTimeInterval(3_600))
        let staleSource = event(
            id: "stale-source", calendar: identity(topology.workA), title: "Stale Publisher Source",
            start: interval.start.addingTimeInterval(7_200), end: interval.end.addingTimeInterval(7_200))
        let state = RoutingSharedCalendarState(events: [initialHubArtifact, initialWorkArtifact, staleSource])
        let cleanerStore = RoutingMachineCalendarStore(visibleCalendars: [topology.hub, topology.workB], state: state)
        let stalePublisherStore = RoutingMachineCalendarStore(
            visibleCalendars: [topology.hub, topology.workA], state: state)
        let cleanerSettings = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_CLEAN]", syncWindowDays: 10,
            workCalendars: [(topology.workB, "[CLEAN]")], legacyMarkers: ["[OLD]"])
        let stalePublisherSettings = settings(
            hub: topology.hub, personalMarker: "[PERSONAL_STALE]", syncWindowDays: 10,
            workCalendars: [(topology.workA, "[OLD]")])
        let cleanup = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: cleanerStore, calendar: utcCalendar()
        )

        let firstCleanup = try await cleanup.apply(settings: cleanerSettings, now: now)
        try expect(
            firstCleanup.confirmedDeletionCount == 2, "Initial cleanup should delete both locally visible artifacts")
        try expect(
            await state.events(in: topology.hub.id).isEmpty,
            "The first local cleanup should leave no visible retired marker in the shared hub")

        _ = try await reconciliation(store: stalePublisherStore, calendar: utcCalendar()).apply(
            settings: stalePublisherSettings, now: now)
        try expect(
            await state.events(in: topology.hub.id).contains { $0.title == "[OLD] Stale Publisher Source" },
            "A not-yet-migrated writer should be able to recreate the retired marker after cleanup")

        let secondCleanup = try await cleanup.apply(settings: cleanerSettings, now: now)
        try expect(
            secondCleanup.confirmedDeletionCount == 1, "Repeated cleanup should remove the recreated local artifact")
        try expect(
            await state.events(in: topology.hub.id).isEmpty,
            "Repeated cleanup should converge the cleaner's current visible topology")

        for output in [
            CalendarCleanupFormatter.formatVerifiedSuccess(firstCleanup),
            CalendarCleanupFormatter.formatVerifiedSuccess(secondCleanup)
        ] {
            try expect(
                output.contains("local and point-in-time") && output.contains("not proof of global or historical"),
                "Cleanup success should remain a bounded local claim")
        }
    }

    private static func reconciliation(store: any CalendarStorePort, calendar: Calendar) -> ReconcileCalendarsUseCase {
        ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: calendar)
    }

    private static func settings(
        hub: RelayCalendar, personalMarker: String, syncWindowDays: Int,
        workCalendars: [(calendar: RelayCalendar, marker: String)], legacyMarkers: [String] = []
    ) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: selector(hub)), personalPrefix: personalMarker,
            syncWindowDays: syncWindowDays,
            workCalendars: workCalendars.map { work in
                WorkCalendarSettings(name: work.calendar.title, prefix: work.marker, calendar: selector(work.calendar))
            }, legacyMarkers: legacyMarkers)
    }

    private static func target(calendar: RelayCalendar, marker: String) -> WorkCalendarProjectionTarget {
        WorkCalendarProjectionTarget(
            settings: WorkCalendarSettings(name: calendar.title, prefix: marker, calendar: selector(calendar)),
            calendar: identity(calendar))
    }

    private static func selector(_ calendar: RelayCalendar) -> CalendarSelector {
        CalendarSelector(sourceTitle: calendar.sourceTitle, calendarTitle: calendar.title)
    }

    private static func identity(_ calendar: RelayCalendar) -> CalendarIdentity {
        CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle)
    }

    private static func calendar(id: String, title: String, source: String) -> RelayCalendar {
        RelayCalendar(id: id, title: title, sourceTitle: source, isWritable: true)
    }

    private static func routingTopology() -> RoutingTopology {
        RoutingTopology(
            hub: calendar(id: "shared-hub", title: "Shared Hub", source: "iCloud"),
            workA: calendar(id: "work-a", title: "Work A", source: "Provider A"),
            workB: calendar(id: "work-b", title: "Work B", source: "Provider B"))
    }

    private static func event(
        id: String, calendar: CalendarIdentity, title: String, start: Date, end: Date,
        availability: EventAvailability = .busy, status: EventStatus = .confirmed,
        currentUserParticipantStatus: CurrentUserParticipantStatus? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, calendar: calendar, title: title, start: start, end: end, isAllDay: false,
            availability: availability, status: status, currentUserParticipantStatus: currentUserParticipantStatus)
    }

    private static func routingInterval() -> CalendarAccessWindow {
        CalendarAccessWindow(
            start: Date(timeIntervalSince1970: 1_789_459_200), end: Date(timeIntervalSince1970: 1_789_462_800))
    }

    private static func referenceDate() -> Date { Date(timeIntervalSince1970: 1_789_416_000) }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func calendar(timeZoneIdentifier: String) throws -> Calendar {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw TestFailure("Missing required time zone: \(timeZoneIdentifier)")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func overlaps(_ event: CalendarEvent, window: CalendarAccessWindow) -> Bool {
        event.start < window.end && event.end > window.start
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct RoutingTopology {
    let hub: RelayCalendar
    let workA: RelayCalendar
    let workB: RelayCalendar
}

private struct RoutingMachineCalendarStore: CalendarStorePort {
    let visibleCalendars: [RelayCalendar]
    let state: RoutingSharedCalendarState

    func listCalendars() async throws -> [RelayCalendar] { visibleCalendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        await state.events(in: calendar.id, from: start, to: end)
    }

    func createEvent(_ event: CalendarEventProjection) async throws { await state.create(event) }

    func deleteEvent(_ event: CalendarEventIdentity) async throws { await state.delete(event) }
}

private actor RoutingSharedCalendarState {
    private var eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]] = [:]
    private var createdEventNumber = 0

    init(events: [CalendarEvent]) {
        for event in events { eventsByCalendarID[event.calendar.id, default: []].append(event) }
    }

    func events(in calendarID: PhysicalCalendarReference) -> [CalendarEvent] {
        eventsByCalendarID[calendarID, default: []].sorted { $0.id < $1.id }
    }

    func events(in calendarID: PhysicalCalendarReference, from start: Date, to end: Date) -> [CalendarEvent] {
        events(in: calendarID).filter { $0.start < end && $0.end > start }
    }

    func create(_ projection: CalendarEventProjection) {
        createdEventNumber += 1
        eventsByCalendarID[projection.destinationCalendar.id, default: []].append(
            CalendarEvent(
                id: "routing-created-\(createdEventNumber)", calendar: projection.destinationCalendar,
                title: projection.title, start: projection.start, end: projection.end, isAllDay: projection.isAllDay,
                availability: .busy, status: .confirmed))
    }

    func delete(_ identity: CalendarEventIdentity) {
        eventsByCalendarID[identity.calendar.id, default: []].removeAll { $0.identity == identity }
    }
}
