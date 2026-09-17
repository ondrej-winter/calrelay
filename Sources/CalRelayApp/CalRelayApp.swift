import CalRelayKit
import SwiftUI

@main struct CalRelayApp: App {
    private let viewModel: CalendarListViewModel

    init() {
        let authorization = EventKitCalendarAuthorizationStatus()
        let calendarStore = EventKitCalendarStore(authorizationStatus: authorization)
        let inventory = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: calendarStore)
        let setup = CalendarAccessSetupUseCase(authorizationStatus: authorization, fullAccessRequester: authorization)
        let status = CalendarControlPanelStatusUseCase(
            settingsProvider: FileCalendarRelaySettingsProvider(), authorizationStatus: authorization,
            calendarStore: calendarStore)
        viewModel = CalendarListViewModel(inventory: inventory, setup: setup, status: status)
    }

    var body: some Scene {
        Window("CalRelay", id: "main") { CalendarListView(viewModel: viewModel).frame(minWidth: 720, minHeight: 480) }
    }
}
