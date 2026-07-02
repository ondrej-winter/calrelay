import SwiftUI

@main
struct CalRelayApp: App {
    @AppStorage(AppSettingsKeys.showMenuBarItem) private var showMenuBarItem = true

    var body: some Scene {
        Window("CalRelay", id: "main") {
            CalendarListView(viewModel: CalendarListViewModel())
                .frame(minWidth: 720, minHeight: 480)
        }

        MenuBarExtra("CalRelay", systemImage: "calendar", isInserted: $showMenuBarItem) {
            MenuBarControl()
        }
    }
}