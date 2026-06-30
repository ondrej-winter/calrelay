import CalRelayCore
import Foundation

@main
struct CalRelayContractTests {
    static func main() throws {
        try testAcceptsValidSettings()
        try testRejectsMissingWorkCalendars()
        try testRejectsEmptyHubSelectorFields()
        try testRejectsEmptyWorkCalendarSelectorFields()
        try testRejectsEmptyWorkCalendarNameAndPrefix()
        try testRejectsNonPositiveSyncWindow()
        try testRejectsDuplicateWorkPrefixes()
        try testRejectsPersonalPrefixConflictingWithWorkPrefix()
        try testIncludesTimedBusyEvents()
        try testIncludesTimedTentativeEvents()
        try testSkipsAllDayEvents()
        try testSkipsDeclinedEvents()
        try testSkipsCancelledEvents()
        try testVisibleEventKeysRemainDistinctForAdjacentMeetings()
        try testProjectsIncludedWorkEventToHub()
        try testDoesNotProjectExcludedWorkEventToHub()
        try testProjectsPrefixedHubEventToOtherWorkCalendars()
        try testProjectsUnprefixedHubEventToAllWorkCalendarsWithPersonalPrefix()
        try testProjectsRemotePrefixedHubEventToLocalWorkCalendars()

        print("CalRelay contract tests passed")
    }

    private static func testAcceptsValidSettings() throws {
        try SettingsValidator.validate(validSettings())
    }

    private static func testRejectsMissingWorkCalendars() throws {
        let baseSettings = validSettings()
        let settings = CalendarRelaySettings(
            hubCalendar: baseSettings.hubCalendar,
            personalPrefix: baseSettings.personalPrefix,
            syncWindowDays: baseSettings.syncWindowDays,
            workCalendars: []
        )

        try expectValidationError(.missingWorkCalendars, for: settings)
    }

    private static func testRejectsEmptyHubSelectorFields() throws {
        try expectValidationError(
            .emptyHubCalendarSourceTitle,
            for: validSettings(hubCalendar: CalendarSelector(sourceTitle: "", calendarTitle: "Personal Work"))
        )

        try expectValidationError(
            .emptyHubCalendarTitle,
            for: validSettings(hubCalendar: CalendarSelector(sourceTitle: "iCloud", calendarTitle: ""))
        )
    }

    private static func testRejectsEmptyWorkCalendarSelectorFields() throws {
        try expectValidationError(
            .emptyWorkCalendarSourceTitle(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "", calendarTitle: "ACME Work")
                )
            ])
        )

        try expectValidationError(
            .emptyWorkCalendarTitle(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "")
                )
            ])
        )
    }

    private static func testRejectsEmptyWorkCalendarNameAndPrefix() throws {
        try expectValidationError(
            .emptyWorkCalendarName,
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "",
                    prefix: "[ACME]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
                )
            ])
        )

        try expectValidationError(
            .emptyWorkCalendarPrefix(name: "ACME"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
                )
            ])
        )
    }

    private static func testRejectsNonPositiveSyncWindow() throws {
        try expectValidationError(.nonPositiveSyncWindowDays, for: validSettings(syncWindowDays: 0))
        try expectValidationError(.nonPositiveSyncWindowDays, for: validSettings(syncWindowDays: -1))
    }

    private static func testRejectsDuplicateWorkPrefixes() throws {
        try expectValidationError(
            .duplicateWorkCalendarPrefix("[WORK]"),
            for: validSettings(workCalendars: [
                WorkCalendarSettings(
                    name: "ACME",
                    prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
                ),
                WorkCalendarSettings(
                    name: "BETA",
                    prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Exchange", calendarTitle: "BETA Work")
                )
            ])
        )
    }

    private static func testRejectsPersonalPrefixConflictingWithWorkPrefix() throws {
        try expectValidationError(
            .personalPrefixConflictsWithWorkPrefix("[ACME]"),
            for: validSettings(personalPrefix: "[ACME]")
        )
    }

    private static func testIncludesTimedBusyEvents() throws {
        let event = eventSnapshot(availability: .busy, status: .confirmed)

        try expect(EventInclusionPolicy.includes(event), "Timed busy events should be included")
    }

    private static func testIncludesTimedTentativeEvents() throws {
        let event = eventSnapshot(availability: .tentative, status: .tentative)

        try expect(EventInclusionPolicy.includes(event), "Timed tentative events should be included")
    }

    private static func testSkipsAllDayEvents() throws {
        let event = eventSnapshot(isAllDay: true, availability: .busy, status: .confirmed)

        try expect(!EventInclusionPolicy.includes(event), "All-day events should be skipped")
    }

    private static func testSkipsDeclinedEvents() throws {
        let event = eventSnapshot(availability: .busy, status: .declined)

        try expect(!EventInclusionPolicy.includes(event), "Declined events should be skipped")
    }

    private static func testSkipsCancelledEvents() throws {
        let event = eventSnapshot(availability: .busy, status: .cancelled)

        try expect(!EventInclusionPolicy.includes(event), "Cancelled events should be skipped")
    }

    private static func testVisibleEventKeysRemainDistinctForAdjacentMeetings() throws {
        let first = eventSnapshot(
            id: "event-1",
            title: "Planning",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let adjacent = eventSnapshot(
            id: "event-2",
            title: "Planning",
            start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_000)
        )

        try expect(
            VisibleEventKey(event: first) != VisibleEventKey(event: adjacent),
            "Repeated titles and adjacent meetings should remain distinct when start/end differ"
        )
    }

    private static func testProjectsIncludedWorkEventToHub() throws {
        let hubCalendar = CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud")
        let sourceEvent = eventSnapshot(
            id: "acme-1",
            calendar: CalendarReference(id: "acme-1", title: "ACME Work", sourceTitle: "Google"),
            title: "Client Planning",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000),
            isAllDay: false,
            availability: .busy,
            status: .confirmed
        )

        let projections = WorkToHubProjector.project(
            events: [sourceEvent],
            from: workCalendarSettings(),
            to: hubCalendar
        )

        try expect(projections.count == 1, "Expected one hub projection")
        try expect(projections[0].destinationCalendar == hubCalendar, "Projection should target hub calendar")
        try expect(projections[0].title == "[ACME] Client Planning", "Projection should prefix source title")
        try expect(projections[0].start == sourceEvent.start, "Projection should copy start")
        try expect(projections[0].end == sourceEvent.end, "Projection should copy end")
        try expect(projections[0].isAllDay == sourceEvent.isAllDay, "Projection should copy all-day flag")
    }

    private static func testDoesNotProjectExcludedWorkEventToHub() throws {
        let sourceEvent = eventSnapshot(isAllDay: true, availability: .busy, status: .confirmed)

        let projections = WorkToHubProjector.project(
            events: [sourceEvent],
            from: workCalendarSettings(),
            to: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud")
        )

        try expect(projections.isEmpty, "Excluded source events should not produce hub projections")
    }

    private static func testProjectsPrefixedHubEventToOtherWorkCalendars() throws {
        let hubEvent = eventSnapshot(
            calendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[ACME] Client Planning"
        )

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: workCalendarTargets(),
            personalPrefix: "[ME]"
        )

        try expect(projections.count == 2, "Expected prefixed hub event to project to non-source work calendars")
        try expect(!projections.contains { $0.destinationCalendar.title == "ACME Work" }, "Prefixed hub event should not route back to matching source calendar")
        try expect(projections.contains { $0.destinationCalendar.title == "BETA Work" && $0.title == "[ACME] Client Planning" }, "Prefixed hub event should route to BETA unchanged")
        try expect(projections.contains { $0.destinationCalendar.title == "CONTOSO Work" && $0.title == "[ACME] Client Planning" }, "Prefixed hub event should route to CONTOSO unchanged")
    }

    private static func testProjectsUnprefixedHubEventToAllWorkCalendarsWithPersonalPrefix() throws {
        let hubEvent = eventSnapshot(
            calendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "Dentist"
        )

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: workCalendarTargets(),
            personalPrefix: "[ME]"
        )

        try expect(projections.count == 3, "Expected unprefixed hub event to project to all work calendars")
        try expect(projections.allSatisfy { $0.title == "[ME] Dentist" }, "Unprefixed hub event should use personal prefix")
    }

    private static func testProjectsRemotePrefixedHubEventToLocalWorkCalendars() throws {
        let hubEvent = eventSnapshot(
            calendar: CalendarReference(id: "hub-1", title: "Personal Work", sourceTitle: "iCloud"),
            title: "[BETA] Sales Call"
        )

        let projections = HubToWorkProjector.project(
            hubEvents: [hubEvent],
            to: [workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work")],
            personalPrefix: "[ME]"
        )

        try expect(projections.count == 1, "Expected remote prefixed hub event to project to local work calendar")
        try expect(projections[0].destinationCalendar.title == "ACME Work", "Remote prefixed hub event should target locally configured work calendar")
        try expect(projections[0].title == "[BETA] Sales Call", "Remote prefixed hub event should preserve remote prefix")
    }

    private static func validSettings(
        hubCalendar: CalendarSelector = CalendarSelector(sourceTitle: "iCloud", calendarTitle: "Personal Work"),
        personalPrefix: String = "[ME]",
        syncWindowDays: Int = 60,
        workCalendars: [WorkCalendarSettings] = [
            WorkCalendarSettings(
                name: "ACME",
                prefix: "[ACME]",
                calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
            )
        ]
    ) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: hubCalendar,
            personalPrefix: personalPrefix,
            syncWindowDays: syncWindowDays,
            workCalendars: workCalendars
        )
    }

    private static func eventSnapshot(
        id: String = "event-1",
        calendar: CalendarReference = CalendarReference(id: "calendar-1", title: "ACME Work", sourceTitle: "Google"),
        title: String = "Client Planning",
        start: Date = Date(timeIntervalSince1970: 1_000),
        end: Date = Date(timeIntervalSince1970: 2_000),
        isAllDay: Bool = false,
        availability: EventAvailability = .busy,
        status: EventStatus = .confirmed
    ) -> EventSnapshot {
        EventSnapshot(
            id: id,
            calendar: calendar,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            availability: availability,
            status: status
        )
    }

    private static func workCalendarSettings() -> WorkCalendarSettings {
        WorkCalendarSettings(
            name: "ACME",
            prefix: "[ACME]",
            calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: "ACME Work")
        )
    }

    private static func workCalendarTargets() -> [WorkCalendarProjectionTarget] {
        [
            workCalendarTarget(name: "ACME", prefix: "[ACME]", calendarID: "acme-1", calendarTitle: "ACME Work"),
            workCalendarTarget(name: "BETA", prefix: "[BETA]", calendarID: "beta-1", calendarTitle: "BETA Work"),
            workCalendarTarget(name: "CONTOSO", prefix: "[CONTOSO]", calendarID: "contoso-1", calendarTitle: "CONTOSO Work")
        ]
    }

    private static func workCalendarTarget(
        name: String,
        prefix: String,
        calendarID: String,
        calendarTitle: String
    ) -> WorkCalendarProjectionTarget {
        WorkCalendarProjectionTarget(
            settings: WorkCalendarSettings(
                name: name,
                prefix: prefix,
                calendar: CalendarSelector(sourceTitle: "Google", calendarTitle: calendarTitle)
            ),
            calendar: CalendarReference(id: calendarID, title: calendarTitle, sourceTitle: "Google")
        )
    }

    private static func expectValidationError(
        _ expectedError: SettingsValidationError,
        for settings: CalendarRelaySettings
    ) throws {
        do {
            try SettingsValidator.validate(settings)
        } catch let error as SettingsValidationError {
            guard error == expectedError else {
                throw ContractTestFailure("Expected \(expectedError), got \(error)")
            }
            return
        } catch {
            throw ContractTestFailure("Expected SettingsValidationError, got \(error)")
        }

        throw ContractTestFailure("Expected validation error: \(expectedError)")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw ContractTestFailure(message)
        }
    }
}

private struct ContractTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}