import CalRelayKit
import Foundation

enum ReconciliationConvergenceTests {
    static func runAll() async throws {
        try await testCompleteOrdinaryActionOrder()
        try await testHubFailureStopsEveryLaterAction()
        try await testDuplicateReplacementFailureAndFreshRepair()
        try await testProviderLagRepeatsConfirmedCreateAndLaterRepairsDuplicate()
        try await testFreshRunRepairsStaleProjection()
    }

    private static func testCompleteOrdinaryActionOrder() async throws {
        let fixture = ConvergenceFixture()
        let deleteEvents = fixture.orderedHubDeletes()
        let workDelete = fixture.event(id: "work-delete", calendar: fixture.workIdentity, title: "[REMOTE] Stale")
        let workSources = fixture.orderedWorkSources()
        let hubSources = fixture.orderedHubSources()
        let store = ConvergenceStore(
            calendars: fixture.calendars,
            events: [
                fixture.hub.id: Array(deleteEvents.reversed()) + Array(hubSources.reversed()),
                fixture.work.id: [workDelete] + Array(workSources.reversed()),
            ])

        let result = try await fixture.useCase(store: store).dryRunResult(settings: fixture.settings, now: fixture.now)
        let expectedHubCreates = workSources.map { fixture.projection(calendar: fixture.hubIdentity, title: "[A] \($0.title)", like: $0) }
        let expectedWorkCreates = hubSources.map {
            fixture.projection(calendar: fixture.workIdentity, title: "[PERSONAL] \($0.title)", like: $0)
        }
        let expected = deleteEvents.map { CalendarMutationAction.delete(role: .hub, event: $0) }
            + [.delete(role: .work(name: "A", declarationIndex: 0), event: workDelete)]
            + expectedHubCreates.map { .create(role: .hub, event: $0) }
            + expectedWorkCreates.map { .create(role: .work(name: "A", declarationIndex: 0), event: $0) }

        try expect(
            result.actions == expected,
            "Ordinary actions must preserve global phases and complete within-calendar ordering")
    }

    private static func testHubFailureStopsEveryLaterAction() async throws {
        let fixture = ConvergenceFixture()
        let firstHubDelete = fixture.orderedHubDeletes()[0]
        let store = ConvergenceStore(
            calendars: fixture.calendars,
            events: [
                fixture.hub.id: fixture.orderedHubDeletes() + fixture.orderedHubSources(),
                fixture.work.id: [fixture.event(id: "work-delete", calendar: fixture.workIdentity, title: "[REMOTE] Stale")]
                    + fixture.orderedWorkSources(),
            ], failMutationNumber: 1)

        do {
            _ = try await fixture.useCase(store: store).applyResult(settings: fixture.settings, now: fixture.now)
            throw TestFailure("The first hub delete should fail")
        } catch let error as CalendarMutationExecutionError {
            guard case .partial(let partial) = error else { throw TestFailure("Expected partial ordinary failure") }
            try expect(partial.confirmedActionCount == 0, "A failed first action confirms nothing")
            try expect(partial.failedRole == .hub, "The failed action must retain its hub role")
        }
        try expect(
            await store.mutationAttempts() == [.delete(firstHubDelete.identity)],
            "A hub-phase failure must prevent every later work delete and create")
    }

    private static func testDuplicateReplacementFailureAndFreshRepair() async throws {
        let fixture = ConvergenceFixture()
        let source = fixture.event(id: "source", calendar: fixture.workIdentity, title: "Planning")
        let first = fixture.event(id: "duplicate-a", calendar: fixture.hubIdentity, title: "[A] Planning")
        let second = fixture.event(id: "duplicate-b", calendar: fixture.hubIdentity, title: "[A] Planning")
        let store = ConvergenceStore(
            calendars: fixture.calendars,
            events: [fixture.hub.id: [first, second], fixture.work.id: [source]], failMutationNumber: 3)
        let useCase = fixture.useCase(store: store)

        do {
            _ = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)
            throw TestFailure("The replacement create should fail after both duplicate deletes")
        } catch let error as CalendarMutationExecutionError {
            guard case .partial(let partial) = error else { throw TestFailure("Expected partial duplicate replacement") }
            try expect(partial.confirmedActionCount == 2, "Both duplicate deletes must remain confirmed")
            try expect(partial.failureCategory == .createFailed, "The replacement create must be the failed action")
        }
        try expect(
            await store.visibleEvents(in: fixture.hub.id).isEmpty,
            "Replacement failure may leave the blocker temporarily missing")

        let repaired = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)
        try expect(repaired.plan.deletes.isEmpty && repaired.plan.creates.count == 1, "A fresh run must repair the missing blocker")
        let settled = try await useCase.dryRunResult(settings: fixture.settings, now: fixture.now)
        try expect(settled.actions.isEmpty, "The repaired visible snapshot must be idempotent")
    }

    private static func testProviderLagRepeatsConfirmedCreateAndLaterRepairsDuplicate() async throws {
        let fixture = ConvergenceFixture()
        let source = fixture.event(id: "source", calendar: fixture.workIdentity, title: "Planning")
        let store = ConvergenceStore(
            calendars: fixture.calendars, events: [fixture.work.id: [source]], makesCreatesVisibleImmediately: false)
        let useCase = fixture.useCase(store: store)

        let first = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)
        try expect(first.plan.creates.count == 1, "The first fresh snapshot should create the missing projection")
        try expect(await store.eventReadCount() == 2, "Ordinary apply must not perform a verification read")
        let repeated = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)
        try expect(repeated.actions == first.actions, "A lagging fresh snapshot may repeat the confirmed create")
        try expect(await store.eventReadCount() == 4, "Each apply must trust one fresh snapshot without verification")

        await store.publishPendingCreatesAndEnableVisibility()
        let repair = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)
        try expect(repair.plan.deletes.count == 2 && repair.plan.creates.count == 1, "Later reconciliation must repair provider-lag duplicates")
        let settled = try await useCase.dryRunResult(settings: fixture.settings, now: fixture.now)
        try expect(settled.actions.isEmpty, "Duplicate repair must converge to an empty fresh plan")
    }

    private static func testFreshRunRepairsStaleProjection() async throws {
        let fixture = ConvergenceFixture()
        let stale = fixture.event(id: "stale", calendar: fixture.hubIdentity, title: "[A] Stale")
        let store = ConvergenceStore(calendars: fixture.calendars, events: [fixture.hub.id: [stale]])
        let useCase = fixture.useCase(store: store)

        let repair = try await useCase.applyResult(settings: fixture.settings, now: fixture.now)
        try expect(repair.plan.deletes == [stale] && repair.plan.creates.isEmpty, "A fresh run must remove stale state")
        let settled = try await useCase.dryRunResult(settings: fixture.settings, now: fixture.now)
        try expect(settled.actions.isEmpty, "Stale-state repair must converge to an empty plan")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct ConvergenceFixture {
    let now = Date(timeIntervalSince1970: 10_000)
    let hub = RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true)
    let work = RelayCalendar(id: "work", title: "Work A", sourceTitle: "Provider A", isWritable: true)

    var calendars: [RelayCalendar] { [hub, work] }
    var hubIdentity: CalendarIdentity { CalendarIdentity(id: hub.id, title: hub.title, sourceTitle: hub.sourceTitle) }
    var workIdentity: CalendarIdentity { CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle) }
    var settings: CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL]", syncWindowDays: 10,
            workCalendars: [
                WorkCalendarSettings(
                    name: "A", prefix: "[A]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ])
    }

    func useCase(store: ConvergenceStore) -> ReconcileCalendarsUseCase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return ReconcileCalendarsUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: calendar)
    }

    func orderedHubDeletes() -> [CalendarEvent] {
        let earlyStart = event(
            id: "delete-early-start", calendar: hubIdentity, title: "[A] Later title",
            start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 9_000))
        let earlyEnd = event(
            id: "delete-early-end", calendar: hubIdentity, title: "[A] Later title",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 3_000))
        let uppercase = event(
            id: "delete-uppercase", calendar: hubIdentity, title: "[A] Alpha",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 4_000))
        let lowercase = event(
            id: "delete-lowercase", calendar: hubIdentity, title: "[A] alpha",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 4_000))
        let accented = event(
            id: "delete-accented", calendar: hubIdentity, title: "[A] Álpha",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 4_000))
        let earlierOccurrence = event(
            id: "delete-series", calendar: hubIdentity, title: "[A] Ωmega",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 4_000),
            occurrenceDate: Date(timeIntervalSince1970: 10_000))
        let laterOccurrence = event(
            id: "delete-series", calendar: hubIdentity, title: "[A] Ωmega",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 4_000),
            occurrenceDate: Date(timeIntervalSince1970: 20_000))
        let allDay = event(
            id: "delete-all-day", calendar: hubIdentity, title: "[A] Aardvark",
            start: Date(timeIntervalSince1970: 2_000), end: Date(timeIntervalSince1970: 4_000), isAllDay: true)
        return [earlyStart, earlyEnd, uppercase, lowercase, accented, earlierOccurrence, laterOccurrence, allDay]
    }

    func orderedWorkSources() -> [CalendarEvent] {
        orderedSources(calendar: workIdentity, idPrefix: "work-source")
    }

    func orderedHubSources() -> [CalendarEvent] {
        orderedSources(calendar: hubIdentity, idPrefix: "hub-source")
    }

    func event(
        id: String, calendar: CalendarIdentity, title: String,
        start: Date = Date(timeIntervalSince1970: 10_000),
        end: Date = Date(timeIntervalSince1970: 11_000), isAllDay: Bool = false,
        occurrenceDate: Date? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, calendar: calendar, title: title, start: start, end: end, isAllDay: isAllDay,
            availability: .busy, status: .confirmed, occurrenceDate: occurrenceDate)
    }

    func projection(calendar: CalendarIdentity, title: String, like event: CalendarEvent) -> CalendarEventProjection {
        CalendarEventProjection(
            destinationCalendar: calendar, title: title, start: event.start, end: event.end, isAllDay: event.isAllDay)
    }

    private func orderedSources(calendar: CalendarIdentity, idPrefix: String) -> [CalendarEvent] {
        [
            event(
                id: "\(idPrefix)-early-start", calendar: calendar, title: "Later title",
                start: Date(timeIntervalSince1970: 21_000), end: Date(timeIntervalSince1970: 29_000)),
            event(
                id: "\(idPrefix)-early-end", calendar: calendar, title: "Later title",
                start: Date(timeIntervalSince1970: 22_000), end: Date(timeIntervalSince1970: 23_000)),
            event(
                id: "\(idPrefix)-uppercase", calendar: calendar, title: "Alpha",
                start: Date(timeIntervalSince1970: 22_000), end: Date(timeIntervalSince1970: 24_000)),
            event(
                id: "\(idPrefix)-lowercase", calendar: calendar, title: "alpha",
                start: Date(timeIntervalSince1970: 22_000), end: Date(timeIntervalSince1970: 24_000)),
            event(
                id: "\(idPrefix)-accented", calendar: calendar, title: "Álpha",
                start: Date(timeIntervalSince1970: 22_000), end: Date(timeIntervalSince1970: 24_000)),
            event(
                id: "\(idPrefix)-all-day", calendar: calendar, title: "Aardvark",
                start: Date(timeIntervalSince1970: 22_000), end: Date(timeIntervalSince1970: 24_000), isAllDay: true),
        ]
    }
}

private enum ConvergenceMutationAttempt: Equatable {
    case delete(CalendarEventIdentity)
    case create(CalendarEventProjection)
}

private struct ConvergenceStoreFailure: Error {}

private actor ConvergenceStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private var events: [PhysicalCalendarReference: [CalendarEvent]]
    private let failMutationNumber: Int?
    private var makesCreatesVisibleImmediately: Bool
    private var pendingCreates: [CalendarEventProjection] = []
    private var attempts: [ConvergenceMutationAttempt] = []
    private var reads = 0
    private var createdEventSequence = 0

    init(
        calendars: [RelayCalendar], events: [PhysicalCalendarReference: [CalendarEvent]],
        failMutationNumber: Int? = nil, makesCreatesVisibleImmediately: Bool = true
    ) {
        self.calendars = calendars
        self.events = events
        self.failMutationNumber = failMutationNumber
        self.makesCreatesVisibleImmediately = makesCreatesVisibleImmediately
    }

    func listCalendars() async throws -> [RelayCalendar] { calendars }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        reads += 1
        return events[calendar.id, default: []]
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        attempts.append(.create(event))
        try failIfNeeded()
        if makesCreatesVisibleImmediately {
            publish(event)
        } else {
            pendingCreates.append(event)
        }
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        attempts.append(.delete(event))
        try failIfNeeded()
        events[event.calendar.id, default: []].removeAll { $0.identity == event }
    }

    func mutationAttempts() -> [ConvergenceMutationAttempt] { attempts }

    func visibleEvents(in calendar: PhysicalCalendarReference) -> [CalendarEvent] {
        events[calendar, default: []]
    }

    func eventReadCount() -> Int { reads }

    func publishPendingCreatesAndEnableVisibility() {
        makesCreatesVisibleImmediately = true
        let pending = pendingCreates
        pendingCreates.removeAll()
        for projection in pending { publish(projection) }
    }

    private func failIfNeeded() throws {
        if attempts.count == failMutationNumber { throw ConvergenceStoreFailure() }
    }

    private func publish(_ projection: CalendarEventProjection) {
        createdEventSequence += 1
        events[projection.destinationCalendar.id, default: []].append(
            CalendarEvent(
                id: "created-\(createdEventSequence)", calendar: projection.destinationCalendar,
                title: projection.title, start: projection.start, end: projection.end, isAllDay: projection.isAllDay,
                availability: .busy, status: .confirmed))
    }
}
