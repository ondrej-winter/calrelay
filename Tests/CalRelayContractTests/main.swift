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
}

private struct ContractTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}