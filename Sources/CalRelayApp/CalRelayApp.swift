import CalRelayKit
import SwiftUI

@main struct CalRelayApp: App {
    private let viewModel: CalendarListViewModel

    init() {
        let authorization = EventKitCalendarAuthorizationStatus()
        let calendarStore = EventKitCalendarStore(authorizationStatus: authorization)
        let selectedFile = ConfigurationFileSelection.selectedFile(overridePath: nil)
        let settingsProvider = FileCalendarRelaySettingsProvider(selectedFile: selectedFile)
        let configurationObserver = ConfigurationFileObserver(selectedFile: selectedFile)
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
        viewModel = CalendarListViewModel(
            inventory: inventory, setup: setup, status: status, manualDryRun: manualDryRun, manualApply: manualApply,
            manualCleanup: manualCleanup, configurationObserver: configurationObserver)
    }

    var body: some Scene {
        Window("CalRelay", id: "main") { CalendarListView(viewModel: viewModel).frame(minWidth: 720, minHeight: 480) }
    }
}
