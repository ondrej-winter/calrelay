import Foundation

public enum CalendarAppLaunchContext: Equatable, Sendable {
    case ordinary
    case loginItem
}

public enum CalendarLoginLaunchPresentation: Equatable, Sendable {
    case showControlPanel
    case keepControlPanelHidden
}

public struct CalendarLoginLaunchPolicy: Sendable {
    private let attentionPolicy: CalendarAutomationAttentionPolicy

    public init(attentionPolicy: CalendarAutomationAttentionPolicy = CalendarAutomationAttentionPolicy()) {
        self.attentionPolicy = attentionPolicy
    }

    public func presentation(
        launchContext: CalendarAppLaunchContext, controlPanelState: CalendarControlPanelPrimaryState,
        automationState: CalendarAutomationPersistentState, launchAtLoginHealthy: Bool, now: Date
    ) -> CalendarLoginLaunchPresentation {
        guard launchContext == .loginItem else { return .showControlPanel }
        guard controlPanelState == .ready else { return .showControlPanel }
        guard automationState.standingAuthorization != nil else { return .showControlPanel }
        guard automationState.schedulingPreference == .enabled else { return .showControlPanel }
        guard launchAtLoginHealthy else { return .showControlPanel }
        return attentionPolicy.reason(
            schedulingPreference: automationState.schedulingPreference, hasStandingAuthorization: true,
            launchAtLoginHealthy: true, operationalStatus: automationState.operationalStatus, now: now) == nil
            ? .keepControlPanelHidden : .showControlPanel
    }
}
