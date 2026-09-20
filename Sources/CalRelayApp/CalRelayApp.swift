import CalRelayKit
import SwiftUI

@main struct CalRelayApp: App {
    @NSApplicationDelegateAdaptor(CalRelayAppDelegate.self) private var appDelegate
    private let viewModel: CalendarListViewModel

    init() {
        if let scenario = CalendarUITestScenario.current(arguments: CommandLine.arguments) {
            let viewModel = CalendarUITestComposition.makeViewModel(scenario: scenario)
            self.viewModel = viewModel
            appDelegate.configureUITestWindow(viewModel: viewModel)
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
            automationAttention: CalendarAutomationAttentionController(),
            launchContext: { (NSApp.delegate as? CalRelayAppDelegate)?.initialLaunchContext ?? .ordinary },
            resolveInitialLaunchPresentation: { presentation in
                (NSApp.delegate as? CalRelayAppDelegate)?.resolveInitialLaunchPresentation(presentation)
            })
        self.viewModel = viewModel
        appDelegate.shouldWarnBeforeQuit = { [weak viewModel] in viewModel?.isSchedulingEnabled == true }
    }

    var body: some Scene {
        Window("CalRelay", id: "main") { CalendarListView(viewModel: viewModel).frame(minWidth: 720, minHeight: 480) }
    }
}
