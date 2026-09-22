import CalRelayKit
import Foundation

enum CalendarCleanupAccessTests {
    static func runAll() async throws {
        try testSettingsDefaultLegacyMarkersAndForwardWindow()
        try testSettingsParseLegacyMarkers()
        try testSettingsRejectInvalidAndCollidingMarkers()
        try testCleanupWindowUsesWholeLocalDatesAcrossSpringForward()
        try testCleanupWindowUsesWholeLocalDatesAcrossFallBack()
        try await testCleanupRequiresLegacyMarkersBeforeAccess()
        try await testAuthorizationGateCanVetoFreshPlan()
        try await testCleanupRangeUsesPositiveOverlapAndRetainsCompleteIntervals()
        try await testCleanupDryRunSelectsOnlyExactLegacyMarkersInTopologyOrder()
        try await testCleanupApplyVerifiesCompleteRangeAfterDeletes()
        try await testCleanupApplyFailsWhenVerificationFindsRemainingMatchWithoutRollback()
        try await testCleanupApplyFailsWhenVerificationReadFailsWithoutRollback()
    }

    private static func testAuthorizationGateCanVetoFreshPlan() async throws {
        let store = CleanupCalendarStore(calendars: readyCalendars(), eventsByCalendarID: [:])
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())
        do {
            _ = try await useCase.apply(
                settings: settings(legacyMarkers: ["[OLD]"]), now: referenceDate(),
                authorizePlan: { _ in throw CleanupStoreFailure() })
            throw TestFailure("Authorization must be able to veto even an empty fresh plan")
        } catch is CleanupStoreFailure {}
        try expect(await store.mutationCount() == 0, "Rejected authorization must prevent every mutation")
        try expect(
            await store.listCalendarsCallCount() == 1, "Gate runs after fresh complete preflight, before verification")
    }

    private static func testSettingsDefaultLegacyMarkersAndForwardWindow() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(settingsYAML())

        try expect(settings.syncWindowDays == 100, "Omitted syncWindowDays should default to 100")
        try expect(settings.legacyMarkers.isEmpty, "Omitted legacyMarkers should default to an empty list")
    }

    private static func testSettingsParseLegacyMarkers() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(settingsYAML(legacyMarkers: ["[OLD]", "[RETIRED_2]"]))

        try expect(
            settings.legacyMarkers == ["[OLD]", "[RETIRED_2]"], "Legacy markers should preserve declaration order")
    }

    private static func testSettingsRejectInvalidAndCollidingMarkers() throws {
        try expectSettingsError(.invalidMarker("OLD"), yaml: settingsYAML(legacyMarkers: ["OLD"]))
        try expectSettingsError(.duplicateMarker("[ACME]"), yaml: settingsYAML(legacyMarkers: ["[ACME]"]))
        try expectSettingsError(.syncWindowDaysOutOfRange, yaml: settingsYAML(syncWindowDays: 366))
    }

    private static func testCleanupWindowUsesWholeLocalDatesAcrossSpringForward() throws {
        let timeZone = try requireTimeZone("America/New_York")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 3, day: 8, hour: 12))

        let window = LegacyCleanupWindow.calculate(referenceDate: reference, calendar: calendar)
        let expectedStart = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 3, day: 6, hour: 0))
        let expectedEnd = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2027, month: 3, day: 9, hour: 0))

        try expect(
            window == CalendarAccessWindow(start: expectedStart, end: expectedEnd),
            "Cleanup should use D - 2 through D + 365 local dates across spring-forward")
    }

    private static func testCleanupWindowUsesWholeLocalDatesAcrossFallBack() throws {
        let timeZone = try requireTimeZone("America/New_York")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 11, day: 1, hour: 12))

        let window = LegacyCleanupWindow.calculate(referenceDate: reference, calendar: calendar)
        let expectedStart = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2026, month: 10, day: 30, hour: 0))
        let expectedEnd = try requireDate(
            DateComponents(calendar: calendar, timeZone: timeZone, year: 2027, month: 11, day: 2, hour: 0))

        try expect(
            window == CalendarAccessWindow(start: expectedStart, end: expectedEnd),
            "Cleanup should use D - 2 through D + 365 local dates across fall-back")
    }

    private static func testCleanupRequiresLegacyMarkersBeforeAccess() async throws {
        let store = CleanupCalendarStore(calendars: readyCalendars(), eventsByCalendarID: [:])
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())

        do { _ = try await useCase.dryRun(settings: settings(legacyMarkers: []), now: referenceDate()) } catch let error
            as CalendarCleanupError
        {
            try expect(error == .legacyMarkersRequired, "Cleanup should require at least one legacy marker")
            try expect(await store.listCalendarsCallCount() == 0, "Missing markers should fail before EventKit access")
            return
        }

        throw TestFailure("Expected cleanup to reject an empty legacy marker list")
    }

    private static func testCleanupRangeUsesPositiveOverlapAndRetainsCompleteIntervals() async throws {
        let calendars = readyCalendars()
        let reference = referenceDate()
        let window = LegacyCleanupWindow.calculate(referenceDate: reference, calendar: utcCalendar())
        let start = window.start.timeIntervalSince1970
        let end = window.end.timeIntervalSince1970
        let overlappingStart = event(
            id: "overlapping-start", calendar: calendars[0], title: "[OLD] Overlapping start", start: start - 100,
            end: start + 100)
        let overlappingEnd = event(
            id: "overlapping-end", calendar: calendars[0], title: "[OLD] Overlapping end", start: end - 100,
            end: end + 100)
        let store = CleanupCalendarStore(
            calendars: calendars,
            eventsByCalendarID: [
                calendars[0].id: [
                    event(
                        id: "touching-start", calendar: calendars[0], title: "[OLD] Touching start", start: start - 100,
                        end: start), overlappingStart, overlappingEnd,
                    event(
                        id: "touching-end", calendar: calendars[0], title: "[OLD] Touching end", start: end,
                        end: end + 100)
                ]
            ], filterEventsToRequestedWindow: true)
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())

        let plan = try await useCase.dryRun(settings: settings(legacyMarkers: ["[OLD]"]), now: reference)

        try expect(
            plan.deletions.map(\.event.id) == [overlappingStart.id, overlappingEnd.id],
            "Cleanup should exclude exact boundary touches and include only positive overlaps")
        try expect(
            plan.deletions.map(\.event) == [overlappingStart, overlappingEnd],
            "Cleanup should retain complete returned intervals instead of clipping them to the range")
        try expect(
            await store.eventRequestWindows() == [window, window],
            "Every configured role should use the same captured cleanup range")
    }

    private static func testCleanupDryRunSelectsOnlyExactLegacyMarkersInTopologyOrder() async throws {
        let calendars = [
            RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true),
            RelayCalendar(id: "acme", title: "ACME Work", sourceTitle: "Google", isWritable: true),
            RelayCalendar(id: "beta", title: "Beta Work", sourceTitle: "Microsoft", isWritable: true),
            RelayCalendar(id: "unconfigured", title: "Archive", sourceTitle: "Other", isWritable: true)
        ]
        let hubEvents = [
            event(id: "hub-old", calendar: calendars[0], title: "[OLD] Hub blocker", start: 4_000),
            event(id: "hub-personal", calendar: calendars[0], title: "[ME] Current personal", start: 2_000),
            event(id: "hub-current", calendar: calendars[0], title: "[ACME] Current work", start: 2_100),
            event(id: "hub-double-space", calendar: calendars[0], title: "[OLD]  Double space", start: 1_000),
            event(id: "hub-tab", calendar: calendars[0], title: "[OLD]\tTab separator", start: 1_100),
            event(id: "hub-newline", calendar: calendars[0], title: "[OLD]\nNewline separator", start: 1_200)
        ]
        let acmeEvents = [
            event(id: "acme-old", calendar: calendars[1], title: "[OLD] ACME legacy", start: 5_000),
            event(id: "acme-prefix", calendar: calendars[1], title: "[OLDISH] Raw starts-with", start: 3_000),
            event(id: "acme-no-space", calendar: calendars[1], title: "[OLD]No separator", start: 3_100),
            event(id: "acme-open-bracket", calendar: calendars[1], title: "[OLD Missing bracket", start: 3_200),
            event(id: "acme-close-bracket", calendar: calendars[1], title: "OLD] Missing bracket", start: 3_300),
            event(id: "acme-nested-bracket", calendar: calendars[1], title: "[[OLD]] Nested bracket", start: 3_400)
        ]
        let betaEvents = [
            event(id: "beta-old", calendar: calendars[2], title: "[OLD] Beta legacy", start: 6_000),
            event(id: "beta-current", calendar: calendars[2], title: "[BETA] Current work", start: 4_100),
            event(id: "beta-case", calendar: calendars[2], title: "[old] Case mismatch", start: 4_200),
            event(id: "beta-marker-only", calendar: calendars[2], title: "[OLD]", start: 4_300),
            event(id: "beta-empty-title", calendar: calendars[2], title: "[OLD] ", start: 4_400),
            event(id: "beta-unmarked", calendar: calendars[2], title: "Unmarked", start: 4_500)
        ]
        let store = CleanupCalendarStore(
            calendars: calendars,
            eventsByCalendarID: [
                calendars[0].id: hubEvents, calendars[1].id: acmeEvents, calendars[2].id: betaEvents,
                calendars[3].id: [
                    event(id: "unconfigured-old", calendar: calendars[3], title: "[OLD] Outside topology", start: 500)
                ]
            ])
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())

        let plan = try await useCase.dryRun(settings: multiRoleSettings(), now: referenceDate())

        try expect(
            plan.deletions.map(\.event.id) == [
                CalendarEventReference(providerIdentifier: "hub-old"),
                CalendarEventReference(providerIdentifier: "acme-old"),
                CalendarEventReference(providerIdentifier: "beta-old")
            ], "Cleanup should select only exact legacy markers in complete topology order")
        try expect(
            plan.deletions.map(\.role) == [
                .hub, .work(name: "ACME", declarationIndex: 0), .work(name: "Beta", declarationIndex: 1)
            ], "Cleanup should retain configured roles for review and execution")
        try expect(
            await store.eventRequestCalendarIDs() == [calendars[0].id, calendars[1].id, calendars[2].id],
            "Cleanup should read the hub and every configured work role without reading an unconfigured calendar")
        try expect(await store.mutationCount() == 0, "Cleanup dry-run must not mutate")
    }

    private static func testCleanupApplyVerifiesCompleteRangeAfterDeletes() async throws {
        let calendars = readyCalendars()
        let store = CleanupCalendarStore(
            calendars: calendars,
            eventsByCalendarID: [
                calendars[0].id: [event(id: "hub-old", calendar: calendars[0], title: "[OLD] Hub", start: 2_000)],
                calendars[1].id: [event(id: "work-old", calendar: calendars[1], title: "[OLD] Work", start: 3_000)]
            ])
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())

        let result = try await useCase.apply(settings: settings(legacyMarkers: ["[OLD]"]), now: referenceDate())
        let expectedWindow = LegacyCleanupWindow.calculate(referenceDate: referenceDate(), calendar: utcCalendar())

        try expect(result.confirmedDeletionCount == 2, "Cleanup should confirm every planned deletion")
        try expect(
            await store.deletedEventIDs() == [
                CalendarEventReference(providerIdentifier: "hub-old"),
                CalendarEventReference(providerIdentifier: "work-old")
            ], "Cleanup should execute in topology order")
        try expect(
            await store.eventRequestCalendarIDs() == [
                PhysicalCalendarReference(providerIdentifier: "hub"),
                PhysicalCalendarReference(providerIdentifier: "work"),
                PhysicalCalendarReference(providerIdentifier: "hub"),
                PhysicalCalendarReference(providerIdentifier: "work")
            ], "Cleanup apply should perform a complete ordered verification read")
        try expect(
            await store.eventRequestWindows() == [expectedWindow, expectedWindow, expectedWindow, expectedWindow],
            "Cleanup verification should reread the same complete cleanup range")
        try expect(
            await store.operations() == [
                .read(calendar: calendars[0].id, window: expectedWindow),
                .read(calendar: calendars[1].id, window: expectedWindow),
                .delete(CalendarEventReference(providerIdentifier: "hub-old")),
                .delete(CalendarEventReference(providerIdentifier: "work-old")),
                .read(calendar: calendars[0].id, window: expectedWindow),
                .read(calendar: calendars[1].id, window: expectedWindow)
            ], "Cleanup should verify the full topology only after every planned deletion succeeds")
    }

    private static func testCleanupApplyFailsWhenVerificationFindsRemainingMatchWithoutRollback() async throws {
        let calendars = readyCalendars()
        let store = CleanupCalendarStore(
            calendars: calendars,
            eventsByCalendarID: [
                calendars[0].id: [event(id: "hub-old", calendar: calendars[0], title: "[OLD] Hub", start: 2_000)]
            ], retainDeletedEvents: true)
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())

        do { _ = try await useCase.apply(settings: settings(legacyMarkers: ["[OLD]"]), now: referenceDate()) } catch let
            error as CalendarCleanupError
        {
            try expect(
                error == .verificationFoundRemainingMatches(count: 1),
                "Remaining exact matches should fail verification")
            try expect(
                await store.deletedEventIDs() == [CalendarEventReference(providerIdentifier: "hub-old")],
                "Confirmed deletion should not be rolled back")
            try expect(
                await store.eventRequestCalendarIDs() == [
                    calendars[0].id, calendars[1].id, calendars[0].id, calendars[1].id
                ], "Remaining-match verification should reread the complete topology")
            return
        }

        throw TestFailure("Expected cleanup verification to reject a remaining match")
    }

    private static func testCleanupApplyFailsWhenVerificationReadFailsWithoutRollback() async throws {
        let calendars = readyCalendars()
        let store = CleanupCalendarStore(
            calendars: calendars,
            eventsByCalendarID: [
                calendars[0].id: [event(id: "hub-old", calendar: calendars[0], title: "[OLD] Hub", start: 2_000)]
            ], failEventRequestNumbers: [3])
        let useCase = CalendarCleanupUseCase(
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: store, calendar: utcCalendar())

        do { _ = try await useCase.apply(settings: settings(legacyMarkers: ["[OLD]"]), now: referenceDate()) } catch let
            error as CalendarCleanupError
        {
            guard case .verificationFailed(let issues) = error else {
                throw TestFailure("Expected verification read failure, got \(error)")
            }
            try expect(
                issues.contains(
                    .eventReadFailed(
                        role: .hub, selector: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Hub"))),
                "Verification should report the failed role")
            try expect(
                await store.deletedEventIDs() == [CalendarEventReference(providerIdentifier: "hub-old")],
                "Verification failure should not roll back deletion")
            try expect(
                await store.eventRequestCalendarIDs() == [
                    calendars[0].id, calendars[1].id, calendars[0].id, calendars[1].id
                ], "Verification should continue through every safely readable role after one read fails")
            return
        }

        throw TestFailure("Expected cleanup verification read failure")
    }

    private static func settings(legacyMarkers: [String]) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Hub")),
            personalPrefix: "[ME]", syncWindowDays: 100,
            workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work"))
            ], legacyMarkers: legacyMarkers)
    }

    private static func multiRoleSettings() -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Hub")),
            personalPrefix: "[ME]", syncWindowDays: 100,
            workCalendars: [
                WorkCalendarSettings(
                    name: "ACME", prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")),
                WorkCalendarSettings(
                    name: "Beta", prefix: "[BETA]",
                    calendar: CalendarSelector(sourceTitle: "Microsoft", calendarTitle: "Beta Work"))
            ], legacyMarkers: ["[OLD]"])
    }

    private static func readyCalendars() -> [RelayCalendar] {
        [
            RelayCalendar(id: "hub", title: "Hub", sourceTitle: "iCloud", isWritable: true),
            RelayCalendar(id: "work", title: "ACME Work", sourceTitle: "Google", isWritable: true)
        ]
    }

    private static func event(
        id: String, calendar: RelayCalendar, title: String, start: TimeInterval, end: TimeInterval? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendar: CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle),
            title: title, start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end ?? start + 1_000), isAllDay: false, availability: .busy,
            status: .confirmed)
    }

    private static func settingsYAML(syncWindowDays: Int? = nil, legacyMarkers: [String]? = nil) -> String {
        let syncWindowLine = syncWindowDays.map { "syncWindowDays: \($0)\n" } ?? ""
        let legacyLine =
            legacyMarkers.map { markers in
                "legacyMarkers:\n" + markers.map { "  - \"\($0)\"" }.joined(separator: "\n") + "\n"
            } ?? ""
        return """
            hubCalendar:
              sourceTitle: "iCloud"
              calendarTitle: "Hub"
            personalPrefix: "[ME]"
            \(syncWindowLine)workCalendars:
              - name: "ACME"
                prefix: "[ACME]"
                calendar:
                  sourceTitle: "Google"
                  calendarTitle: "ACME Work"
            \(legacyLine)
            """
    }

    private static func expectSettingsError(_ expected: SettingsValidationError, yaml: String) throws {
        do { _ = try YAMLCalendarRelaySettingsLoader.load(yaml) } catch let error as YAMLCalendarRelaySettingsError {
            try expect(error.description.contains(expected.description), "Expected settings error \(expected)")
            return
        }
        throw TestFailure("Expected invalid settings")
    }

    private static func referenceDate() -> Date { Date(timeIntervalSince1970: 1_800_000_000) }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func requireTimeZone(_ identifier: String) throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw TestFailure("Missing required time zone: \(identifier)")
        }
        return timeZone
    }

    private static func requireDate(_ components: DateComponents) throws -> Date {
        guard let date = components.date else { throw TestFailure("Could not construct test date") }
        return date
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct CleanupStoreFailure: Error {}

private enum CleanupStoreOperation: Equatable {
    case read(calendar: PhysicalCalendarReference, window: CalendarAccessWindow)
    case delete(CalendarEventReference)
}

private actor CleanupCalendarStore: CalendarStorePort {
    private let calendars: [RelayCalendar]
    private var eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]]
    private let retainDeletedEvents: Bool
    private let failEventRequestNumbers: Set<Int>
    private let filterEventsToRequestedWindow: Bool
    private var listCalls = 0
    private var eventRequestCount = 0
    private var eventRequestCalendarIDsValue: [PhysicalCalendarReference] = []
    private var eventRequestWindowsValue: [CalendarAccessWindow] = []
    private var deletedIDs: [CalendarEventReference] = []
    private var creates = 0
    private var operationsValue: [CleanupStoreOperation] = []

    init(
        calendars: [RelayCalendar], eventsByCalendarID: [PhysicalCalendarReference: [CalendarEvent]],
        retainDeletedEvents: Bool = false, failEventRequestNumbers: Set<Int> = [],
        filterEventsToRequestedWindow: Bool = false
    ) {
        self.calendars = calendars
        self.eventsByCalendarID = eventsByCalendarID
        self.retainDeletedEvents = retainDeletedEvents
        self.failEventRequestNumbers = failEventRequestNumbers
        self.filterEventsToRequestedWindow = filterEventsToRequestedWindow
    }

    func listCalendars() async throws -> [RelayCalendar] {
        listCalls += 1
        return calendars
    }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        eventRequestCount += 1
        eventRequestCalendarIDsValue.append(calendar.id)
        let window = CalendarAccessWindow(start: start, end: end)
        eventRequestWindowsValue.append(window)
        operationsValue.append(.read(calendar: calendar.id, window: window))
        if failEventRequestNumbers.contains(eventRequestCount) { throw CleanupStoreFailure() }
        let events = eventsByCalendarID[calendar.id, default: []]
        guard filterEventsToRequestedWindow else { return events }
        return events.filter { $0.start < end && $0.end > start }
    }

    func createEvent(_ event: CalendarEventProjection) async throws { creates += 1 }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        deletedIDs.append(event.id)
        operationsValue.append(.delete(event.id))
        guard !retainDeletedEvents else { return }
        eventsByCalendarID[event.calendar.id, default: []].removeAll { candidate in candidate.identity == event }
    }

    func listCalendarsCallCount() -> Int { listCalls }

    func eventRequestCalendarIDs() -> [PhysicalCalendarReference] { eventRequestCalendarIDsValue }

    func eventRequestWindows() -> [CalendarAccessWindow] { eventRequestWindowsValue }

    func deletedEventIDs() -> [CalendarEventReference] { deletedIDs }

    func mutationCount() -> Int { creates + deletedIDs.count }

    func operations() -> [CleanupStoreOperation] { operationsValue }
}
