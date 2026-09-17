import Foundation

public struct FileCalendarRelaySettingsProvider: CalendarRelaySettingsProvider, Sendable {
    private let selectedFile: SelectedConfigurationFile

    public init(selectedFile: SelectedConfigurationFile = ConfigurationFileSelection.selectedFile(overridePath: nil)) {
        self.selectedFile = selectedFile
    }

    public func loadSettings() async throws -> LoadedCalendarRelaySettings {
        guard FileManager.default.fileExists(atPath: selectedFile.path) else {
            throw CalendarRelaySettingsProviderError.missing(displayPath: selectedFile.displayPath)
        }

        let yaml: String
        do { yaml = try String(contentsOfFile: selectedFile.path, encoding: .utf8) } catch {
            throw CalendarRelaySettingsProviderError.invalid(displayPath: selectedFile.displayPath)
        }

        let settings: CalendarRelaySettings
        do { settings = try YAMLCalendarRelaySettingsLoader.load(yaml) } catch {
            throw CalendarRelaySettingsProviderError.invalid(displayPath: selectedFile.displayPath)
        }

        return LoadedCalendarRelaySettings(displayPath: selectedFile.displayPath, settings: settings)
    }
}
