import Foundation
import Yams

public enum YAMLCalendarRelaySettingsError: Error, CustomStringConvertible, Sendable {
    case invalidConfiguration
    case invalidSettings(String)

    public var description: String {
        switch self {
        case .invalidConfiguration: "Invalid configuration. Check the YAML shape and required fields."
        case .invalidSettings(let message): "Invalid configuration: \(message)"
        }
    }
}

public enum YAMLCalendarRelaySettingsLoader {
    public static func load(_ yaml: String) throws -> CalendarRelaySettings {
        let decoder = YAMLDecoder()

        do {
            guard let root = try compose(yaml: yaml) else { throw YAMLCalendarRelaySettingsError.invalidConfiguration }
            try StrictCalendarRelayYAMLShape.validate(root)
        } catch is YAMLCalendarRelaySettingsError { throw YAMLCalendarRelaySettingsError.invalidConfiguration } catch {
            throw YAMLCalendarRelaySettingsError.invalidConfiguration
        }

        let rawSettings: RawCalendarRelaySettings
        do { rawSettings = try decoder.decode(RawCalendarRelaySettings.self, from: yaml) } catch {
            throw YAMLCalendarRelaySettingsError.invalidConfiguration
        }

        let settings = rawSettings.toSettings()

        do { try SettingsValidator.validate(settings) } catch let error as SettingsValidationError {
            throw YAMLCalendarRelaySettingsError.invalidSettings(error.description)
        } catch { throw YAMLCalendarRelaySettingsError.invalidConfiguration }

        return settings
    }
}

private enum StrictCalendarRelayYAMLShape {
    private static let rootKeys: Set<String> = [
        "hubCalendar", "personalPrefix", "syncWindowDays", "workCalendars", "legacyMarkers"
    ]
    private static let selectorKeys: Set<String> = ["sourceTitle", "calendarTitle"]
    private static let workCalendarKeys: Set<String> = ["name", "prefix", "calendar"]

    static func validate(_ root: Node) throws {
        let rootMapping = try mapping(root)
        try validateKeys(rootMapping, allowed: rootKeys)

        if let personalPrefix = rootMapping["personalPrefix"] { try validateString(personalPrefix) }

        if let syncWindowDays = rootMapping["syncWindowDays"], syncWindowDays.int == nil {
            throw YAMLCalendarRelaySettingsError.invalidConfiguration
        }

        if let hubCalendar = rootMapping["hubCalendar"] { try validateSelector(hubCalendar) }

        if let workCalendars = rootMapping["workCalendars"] {
            let sequence = try sequence(workCalendars)
            for workCalendar in sequence {
                let workMapping = try mapping(workCalendar)
                try validateKeys(workMapping, allowed: workCalendarKeys)
                if let name = workMapping["name"] { try validateString(name) }
                if let prefix = workMapping["prefix"] { try validateString(prefix) }
                if let calendar = workMapping["calendar"] { try validateSelector(calendar) }
            }
        }

        if let legacyMarkers = rootMapping["legacyMarkers"] {
            for marker in try sequence(legacyMarkers) { try validateString(marker) }
        }
    }

    private static func validateSelector(_ node: Node) throws {
        let selector = try mapping(node)
        try validateKeys(selector, allowed: selectorKeys)
        if let sourceTitle = selector["sourceTitle"] { try validateString(sourceTitle) }
        if let calendarTitle = selector["calendarTitle"] { try validateString(calendarTitle) }
    }

    private static func mapping(_ node: Node) throws -> Node.Mapping {
        guard let mapping = node.mapping else { throw YAMLCalendarRelaySettingsError.invalidConfiguration }
        return mapping
    }

    private static func sequence(_ node: Node) throws -> Node.Sequence {
        guard let sequence = node.sequence else { throw YAMLCalendarRelaySettingsError.invalidConfiguration }
        return sequence
    }

    private static func validateString(_ node: Node) throws {
        guard node.scalar != nil, node.tag == Tag(.str) else {
            throw YAMLCalendarRelaySettingsError.invalidConfiguration
        }
    }

    private static func validateKeys(_ mapping: Node.Mapping, allowed: Set<String>) throws {
        var seenKeys: Set<String> = []
        for pair in mapping {
            guard let key = pair.key.string, allowed.contains(key), seenKeys.insert(key).inserted else {
                throw YAMLCalendarRelaySettingsError.invalidConfiguration
            }
        }
    }
}

private struct RawCalendarRelaySettings: Decodable {
    let hubCalendar: RawCalendarSelector
    let personalPrefix: String
    let syncWindowDays: Int?
    let workCalendars: [RawWorkCalendarSettings]
    let legacyMarkers: [String]?

    func toSettings() -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(calendar: hubCalendar.toSelector()), personalPrefix: personalPrefix,
            syncWindowDays: syncWindowDays ?? 100, workCalendars: workCalendars.map { $0.toSettings() },
            legacyMarkers: legacyMarkers ?? [])
    }
}

private struct RawWorkCalendarSettings: Decodable {
    let name: String
    let prefix: String
    let calendar: RawCalendarSelector

    func toSettings() -> WorkCalendarSettings {
        WorkCalendarSettings(name: name, prefix: prefix, calendar: calendar.toSelector())
    }
}

private struct RawCalendarSelector: Decodable {
    let sourceTitle: String
    let calendarTitle: String

    func toSelector() -> CalendarSelector { CalendarSelector(sourceTitle: sourceTitle, calendarTitle: calendarTitle) }
}
