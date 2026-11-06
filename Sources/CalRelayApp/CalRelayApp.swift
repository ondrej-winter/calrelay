import CalRelayKit
import SwiftUI

@main struct CalRelayApp: App {
    @NSApplicationDelegateAdaptor(CalRelayAppDelegate.self) private var appDelegate

    init() {
        let delegate = appDelegate
        if let scenario = CalendarUITestScenario.current(arguments: CommandLine.arguments) {
            let viewModel = CalendarUITestComposition.makeViewModel(scenario: scenario, appDelegate: delegate)
            delegate.configure(viewModel: viewModel)
            return
        }

        let authorization = EventKitCalendarAuthorizationStatus()
        let calendarStore = EventKitCalendarStore(authorizationStatus: authorization)
        let selectedFile = ConfigurationFileSelection.selectedFile(overridePath: nil)
        let settingsProvider = FileCalendarRelaySettingsProvider(selectedFile: selectedFile)
        let configurationObserver = ConfigurationFileObserver(selectedFile: selectedFile)
        let automationStateStore = UserDefaultsCalendarAutomationStateStore()
        let configurationChanges = CalendarConfigurationChangeTracker()
        let inventory = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: calendarStore)
        let setup = CalendarAccessSetupUseCase(authorizationStatus: authorization, fullAccessRequester: authorization)
        let status = CalendarControlPanelStatusUseCase(
            settingsProvider: settingsProvider, authorizationStatus: authorization, calendarStore: calendarStore)
        let manualDryRun = CalendarManualDryRunUseCase(
            settingsProvider: settingsProvider, authorizationStatus: authorization, calendarStore: calendarStore)
        let manualApply = CalendarManualApplyUseCase(
            settingsProvider: settingsProvider, authorizationStatus: authorization, calendarStore: calendarStore)
        let manualCleanup = CalendarManualCleanupUseCase(
            settingsProvider: settingsProvider, authorizationStatus: authorization, calendarStore: calendarStore)
        let standingAuthorization = CalendarStandingAuthorizationUseCase(
            settingsProvider: settingsProvider, authorizationStatus: authorization, calendarStore: calendarStore,
            stateStore: automationStateStore, configurationChanges: configurationChanges)
        let automaticReconciliation = CalendarAutomaticReconciliationUseCase(
            settingsProvider: settingsProvider, authorizationStatus: authorization, calendarStore: calendarStore,
            stateStore: automationStateStore, configurationChanges: configurationChanges)
        let automationState = CalendarAutomationStateUseCase(stateStore: automationStateStore)
        let viewModel = CalendarListViewModel(
            inventory: inventory, setup: setup, status: status, manualDryRun: manualDryRun, manualApply: manualApply,
            manualCleanup: manualCleanup, standingAuthorization: standingAuthorization,
            automaticReconciliation: automaticReconciliation, automationState: automationState,
            configurationObserver: configurationObserver, automationTriggers: CalendarAutomationTriggerSource(),
            launchAtLogin: CalendarLaunchAtLoginController(),
            automationAttention: CalendarAutomationAttentionController(
                delivery: CalendarUserNotificationDelivery(showControlPanel: { [weak delegate] in
                    delegate?.openControlPanel()
                }), runtimeAlertsEnabled: { [weak delegate] in delegate?.runtimeAlertsEnabled == true }),
            launchContext: { [weak delegate] in delegate?.initialLaunchContext ?? .ordinary },
            resolveInitialLaunchPresentation: { [weak delegate] presentation in
                delegate?.resolveInitialLaunchPresentation(presentation)
            })
        delegate.configure(viewModel: viewModel)
    }

    var body: some Scene { Settings { EmptyView() } }
}
