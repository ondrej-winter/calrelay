import Foundation

public enum SettingsValidationError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyHubCalendarSourceTitle
    case emptyHubCalendarTitle
    case missingWorkCalendars
    case emptyWorkCalendarName
    case emptyWorkCalendarPrefix(name: String)
    case emptyWorkCalendarSourceTitle(name: String)
    case emptyWorkCalendarTitle(name: String)
    case nonPositiveSyncWindowDays
    case duplicateWorkCalendarPrefix(String)
    case personalPrefixConflictsWithWorkPrefix(String)

    public var description: String {
        switch self {
        case .emptyHubCalendarSourceTitle:
            "Hub calendar source title must not be empty."
        case .emptyHubCalendarTitle:
            "Hub calendar title must not be empty."
        case .missingWorkCalendars:
            "At least one work calendar must be configured."
        case .emptyWorkCalendarName:
            "Work calendar name must not be empty."
        case .emptyWorkCalendarPrefix(let name):
            "Work calendar prefix must not be empty for \(name)."
        case .emptyWorkCalendarSourceTitle(let name):
            "Work calendar source title must not be empty for \(name)."
        case .emptyWorkCalendarTitle(let name):
            "Work calendar title must not be empty for \(name)."
        case .nonPositiveSyncWindowDays:
            "Sync window days must be greater than zero."
        case .duplicateWorkCalendarPrefix(let prefix):
            "Work calendar prefix must be unique: \(prefix)."
        case .personalPrefixConflictsWithWorkPrefix(let prefix):
            "Personal prefix must not match a work calendar prefix: \(prefix)."
        }
    }
}

public enum SettingsValidator {
    public static func validate(_ settings: CalendarRelaySettings) throws {
        try validateHubCalendar(settings.hubCalendar)

        guard settings.syncWindowDays > 0 else {
            throw SettingsValidationError.nonPositiveSyncWindowDays
        }

        guard !settings.workCalendars.isEmpty else {
            throw SettingsValidationError.missingWorkCalendars
        }

        var seenPrefixes: Set<String> = []

        for workCalendar in settings.workCalendars {
            try validate(workCalendar)

            guard seenPrefixes.insert(workCalendar.prefix).inserted else {
                throw SettingsValidationError.duplicateWorkCalendarPrefix(workCalendar.prefix)
            }

            guard settings.personalPrefix != workCalendar.prefix else {
                throw SettingsValidationError.personalPrefixConflictsWithWorkPrefix(workCalendar.prefix)
            }
        }
    }

    private static func validateHubCalendar(_ selector: CalendarSelector) throws {
        guard !selector.sourceTitle.isEmpty else {
            throw SettingsValidationError.emptyHubCalendarSourceTitle
        }

        guard !selector.calendarTitle.isEmpty else {
            throw SettingsValidationError.emptyHubCalendarTitle
        }
    }

    private static func validate(_ workCalendar: WorkCalendarSettings) throws {
        guard !workCalendar.name.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarName
        }

        guard !workCalendar.prefix.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarPrefix(name: workCalendar.name)
        }

        guard !workCalendar.calendar.sourceTitle.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarSourceTitle(name: workCalendar.name)
        }

        guard !workCalendar.calendar.calendarTitle.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarTitle(name: workCalendar.name)
        }
    }
}