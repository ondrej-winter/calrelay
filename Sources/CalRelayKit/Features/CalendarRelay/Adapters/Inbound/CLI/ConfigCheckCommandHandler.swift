import Foundation

public enum ConfigCheckCommandError: Error, Equatable, CustomStringConvertible, Sendable {
    case preflightFailed(selectedPath: String, issues: [CalendarAccessPreflightIssue])
    case migrationPending(selectedPath: String)
    case migrationPendingWithPreflightFailures(selectedPath: String, issues: [CalendarAccessPreflightIssue])

    public var description: String {
        switch self {
        case .preflightFailed(let selectedPath, let issues):
            "Configuration at \(selectedPath) is not currently ready:\n"
                + issues.map(\.description).joined(separator: "\n")
        case .migrationPending(let selectedPath):
            "Configuration at \(selectedPath) is migration pending. Run explicit legacy cleanup, then remove legacyMarkers manually when migration is complete."
        case .migrationPendingWithPreflightFailures(let selectedPath, let issues):
            "Configuration at \(selectedPath) is migration pending and its topology is not currently ready:\n"
                + issues.map(\.description).joined(separator: "\n")
        }
    }
}

public struct ConfigCheckCommandHandler: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        authorizationStatus: any CalendarAuthorizationStatusPort, calendarStore: any CalendarStorePort,
        now: @escaping @Sendable () -> Date = Date.init, calendar: Calendar = .current
    ) {
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
        self.now = now
        self.calendar = calendar
    }

    public func run(config: String?) async throws -> String {
        let selectedFile = try ConfigurationFileSelection.select(overridePath: config)
        let yaml = try String(contentsOfFile: selectedFile.path, encoding: .utf8)
        let settings = try YAMLCalendarRelaySettingsLoader.load(yaml)
        let window = OrdinaryReconciliationWindow.calculate(
            referenceDate: now(), calendar: calendar, syncWindowDays: settings.syncWindowDays)
        let result = try await CalendarAccessPreflightUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore
        ).run(settings: settings, window: window)

        switch result {
        case .ready:
            if !settings.legacyMarkers.isEmpty {
                throw ConfigCheckCommandError.migrationPending(selectedPath: selectedFile.displayPath)
            }
        case .failed(let issues):
            if !settings.legacyMarkers.isEmpty {
                throw ConfigCheckCommandError.migrationPendingWithPreflightFailures(
                    selectedPath: selectedFile.displayPath, issues: issues)
            }
            throw ConfigCheckCommandError.preflightFailed(selectedPath: selectedFile.displayPath, issues: issues)
        }

        return """
            Configuration: \(selectedFile.displayPath)
            The complete configured topology is currently ready.
            """
    }
}
