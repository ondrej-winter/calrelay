public struct LoadedCalendarRelaySettings: Equatable, Sendable {
    public let displayPath: String
    public let settings: CalendarRelaySettings

    public init(displayPath: String, settings: CalendarRelaySettings) {
        self.displayPath = displayPath
        self.settings = settings
    }
}

public enum CalendarRelaySettingsProviderError: Error, Equatable, Sendable {
    case missing(displayPath: String)
    case invalid(displayPath: String)
}

public enum CalendarControlPanelConfigurationState: Equatable, Sendable {
    case missing(displayPath: String)
    case invalid(displayPath: String)
    case valid(displayPath: String)
}

public enum CalendarControlPanelReadinessState: Equatable, Sendable {
    case notChecked
    case ready
    case notReady([CalendarAccessPreflightIssue])
}

public enum CalendarControlPanelPrimaryState: Equatable, Sendable {
    case configurationMissing
    case configurationInvalid
    case calendarAccessUnavailable(CalendarAuthorizationState)
    case topologyNotReady
    case migrationPending
    case ready
}

public struct CalendarControlPanelStatus: Equatable, Sendable {
    public let primaryState: CalendarControlPanelPrimaryState
    public let configurationState: CalendarControlPanelConfigurationState
    public let authorizationState: CalendarAuthorizationState?
    public let readinessState: CalendarControlPanelReadinessState
    public let isMigrationPending: Bool

    public init(
        primaryState: CalendarControlPanelPrimaryState, configurationState: CalendarControlPanelConfigurationState,
        authorizationState: CalendarAuthorizationState?, readinessState: CalendarControlPanelReadinessState,
        isMigrationPending: Bool
    ) {
        self.primaryState = primaryState
        self.configurationState = configurationState
        self.authorizationState = authorizationState
        self.readinessState = readinessState
        self.isMigrationPending = isMigrationPending
    }
}
