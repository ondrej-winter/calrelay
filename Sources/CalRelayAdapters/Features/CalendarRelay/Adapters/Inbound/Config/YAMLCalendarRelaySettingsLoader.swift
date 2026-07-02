import CalRelayCore
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

private struct RawCalendarRelaySettings: Decodable {
    let hubCalendar: RawCalendarSelector
    let personalPrefix: String
    let syncWindowDays: Int?
    let workCalendars: [RawWorkCalendarSettings]

    func toSettings() -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: hubCalendar.toSelector(), personalPrefix: personalPrefix, syncWindowDays: syncWindowDays ?? 60,
            workCalendars: workCalendars.map { $0.toSettings() })
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
