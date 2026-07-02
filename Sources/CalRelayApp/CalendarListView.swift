import SwiftUI

struct CalendarListView: View {
    @StateObject var viewModel: CalendarListViewModel
    @AppStorage(AppSettingsKeys.showMenuBarItem) private var showMenuBarItem = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statusPanel
            menuBarPreference
            calendarListControls
            calendarOutput
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CalRelay")
                .font(.largeTitle)
            Text("Use this control panel to verify Calendar permission and EventKit-visible calendars for the app bundle.")
                .foregroundStyle(.secondary)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current app status")
                .font(.headline)
            Text("CalRelay.app is currently a normal Dock-visible macOS app. This window is the recovery surface for Calendar access and visible-calendar checks. Sync actions, background scheduling, and automatic reconciliation are not exposed here yet.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var menuBarPreference: some View {
        Toggle("Show CalRelay in the menu bar", isOn: $showMenuBarItem)
            .help("The menu bar item is UI-only and contains Open CalRelay and Quit actions.")
    }

    private var calendarListControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Loading…" : "List Calendars") {
                viewModel.listCalendars()
            }
            .disabled(viewModel.isLoading)

            Text("Listing calendars may trigger the macOS Calendar permission prompt for bundle identifier dev.owinter.CalRelay.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var calendarOutput: some View {
        ScrollView {
            Text(viewModel.output)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}