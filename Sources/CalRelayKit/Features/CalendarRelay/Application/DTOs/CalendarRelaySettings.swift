import Foundation

public struct CalendarRelaySettings: Equatable, Sendable {
    public let hubCalendar: HubCalendarSettings
    public let personalPrefix: String
    public let syncWindowDays: Int
    public let workCalendars: [WorkCalendarSettings]
    public let legacyMarkers: [String]

    public init(
        hubCalendar: HubCalendarSettings, personalPrefix: String, syncWindowDays: Int,
        workCalendars: [WorkCalendarSettings], legacyMarkers: [String] = []
    ) {
        self.hubCalendar = hubCalendar
        self.personalPrefix = personalPrefix
        self.syncWindowDays = syncWindowDays
        self.workCalendars = workCalendars
        self.legacyMarkers = legacyMarkers
    }
}

public struct HubCalendarSettings: Equatable, Sendable {
    public let calendar: CalendarSelector

    public init(calendar: CalendarSelector) { self.calendar = calendar }
}

public struct WorkCalendarSettings: Equatable, Sendable {
    public let name: String
    public let prefix: String
    public let calendar: CalendarSelector

    public init(name: String, prefix: String, calendar: CalendarSelector) {
        self.name = name
        self.prefix = prefix
        self.calendar = calendar
    }
}

public enum SettingsValidationError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyHubCalendarSourceTitle
    case emptyHubCalendarTitle
    case missingWorkCalendars
    case emptyWorkCalendarName
    case emptyWorkCalendarPrefix(name: String)
    case emptyWorkCalendarSourceTitle(name: String)
    case emptyWorkCalendarTitle(name: String)
    case nonPositiveSyncWindowDays
    case syncWindowDaysOutOfRange
    case invalidMarker(String)
    case duplicateMarker(String)
    case duplicateCalendarSelector(CalendarSelector, roles: [ConfiguredCalendarRole])
    case duplicateWorkCalendarPrefix(String)
    case personalPrefixConflictsWithWorkPrefix(String)

    public var description: String {
        switch self {
        case .emptyHubCalendarSourceTitle: "Hub calendar source title must not be empty."
        case .emptyHubCalendarTitle: "Hub calendar title must not be empty."
        case .missingWorkCalendars: "At least one work calendar must be configured."
        case .emptyWorkCalendarName: "Work calendar name must not be empty."
        case .emptyWorkCalendarPrefix: "Work calendar prefix must not be empty."
        case .emptyWorkCalendarSourceTitle: "Work calendar source title must not be empty."
        case .emptyWorkCalendarTitle: "Work calendar title must not be empty."
        case .nonPositiveSyncWindowDays: "Sync window days must be greater than zero."
        case .syncWindowDaysOutOfRange: "Sync window days must be from 1 through 365."
        case .invalidMarker: "Invalid marker. Markers must match \\[[A-Za-z0-9_-]+\\]."
        case .duplicateMarker: "Markers must be pairwise distinct."
        case .duplicateCalendarSelector(_, let roles):
            "Calendar selector is used by multiple roles (\(roles.map(\.configurationDescription).joined(separator: ", ")))."
        case .duplicateWorkCalendarPrefix: "Markers must be pairwise distinct. Work calendar prefix must be unique."
        case .personalPrefixConflictsWithWorkPrefix:
            "Markers must be pairwise distinct. Personal prefix must not match a work calendar prefix."
        }
    }
}

extension ConfiguredCalendarRole {
    fileprivate var configurationDescription: String {
        switch self {
        case .hub: "Hub"
        case .work(_, let declarationIndex): "Work role at declaration index \(declarationIndex)"
        }
    }
}

public enum SettingsValidator {
    public static func validate(_ settings: CalendarRelaySettings) throws {
        try validateHubCalendar(settings.hubCalendar)
        try validateSyncWindow(settings.syncWindowDays)
        try validatePersonalMarker(settings.personalPrefix)
        try validateWorkCalendars(settings)
        try validateCalendarSelectors(settings)
        try validateLegacyMarkers(settings)
    }

    private static func validateWorkCalendars(_ settings: CalendarRelaySettings) throws {
        guard !settings.workCalendars.isEmpty else { throw SettingsValidationError.missingWorkCalendars }
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

    private static func validateCalendarSelectors(_ settings: CalendarRelaySettings) throws {
        var rolesBySelector: [CalendarSelectorKey: [ConfiguredCalendarRole]] = [
            CalendarSelectorKey(settings.hubCalendar.calendar): [.hub]
        ]
        for (index, workCalendar) in settings.workCalendars.enumerated() {
            let selectorKey = CalendarSelectorKey(workCalendar.calendar)
            rolesBySelector[selectorKey, default: []].append(.work(name: workCalendar.name, declarationIndex: index))
        }
        for (selectorKey, roles) in rolesBySelector where roles.count > 1 {
            throw SettingsValidationError.duplicateCalendarSelector(selectorKey.selector, roles: roles)
        }
    }

    private static func validateLegacyMarkers(_ settings: CalendarRelaySettings) throws {
        var seenMarkers = Set(settings.workCalendars.map(\.prefix) + [settings.personalPrefix])
        for marker in settings.legacyMarkers {
            guard MarkerSyntax.isValid(marker) else { throw SettingsValidationError.invalidMarker(marker) }
            guard seenMarkers.insert(marker).inserted else { throw SettingsValidationError.duplicateMarker(marker) }
        }
    }

    private static func validateSyncWindow(_ syncWindowDays: Int) throws {
        guard syncWindowDays > 0 else { throw SettingsValidationError.nonPositiveSyncWindowDays }
        guard syncWindowDays <= 365 else { throw SettingsValidationError.syncWindowDaysOutOfRange }
    }

    private static func validatePersonalMarker(_ personalMarker: String) throws {
        guard MarkerSyntax.isValid(personalMarker) else { throw SettingsValidationError.invalidMarker(personalMarker) }
    }

    private static func validateHubCalendar(_ hubCalendar: HubCalendarSettings) throws {
        guard !hubCalendar.calendar.sourceTitle.isEmpty else {
            throw SettingsValidationError.emptyHubCalendarSourceTitle
        }

        guard !hubCalendar.calendar.calendarTitle.isEmpty else { throw SettingsValidationError.emptyHubCalendarTitle }
    }

    private static func validate(_ workCalendar: WorkCalendarSettings) throws {
        guard !workCalendar.name.isEmpty else { throw SettingsValidationError.emptyWorkCalendarName }

        guard !workCalendar.prefix.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarPrefix(name: workCalendar.name)
        }
        guard MarkerSyntax.isValid(workCalendar.prefix) else {
            throw SettingsValidationError.invalidMarker(workCalendar.prefix)
        }

        guard !workCalendar.calendar.sourceTitle.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarSourceTitle(name: workCalendar.name)
        }

        guard !workCalendar.calendar.calendarTitle.isEmpty else {
            throw SettingsValidationError.emptyWorkCalendarTitle(name: workCalendar.name)
        }
    }
}

private struct CalendarSelectorKey: Hashable {
    let sourceTitle: String
    let calendarTitle: String

    init(_ selector: CalendarSelector) {
        sourceTitle = selector.sourceTitle
        calendarTitle = selector.calendarTitle
    }

    var selector: CalendarSelector { CalendarSelector(sourceTitle: sourceTitle, calendarTitle: calendarTitle) }
}
