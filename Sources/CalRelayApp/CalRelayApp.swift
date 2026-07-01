import CalRelayAdapters
import SwiftUI

@main
struct CalRelayApp: App {
    var body: some Scene {
        Window("CalRelay", id: "main") {
            CalendarListView(viewModel: CalendarListViewModel())
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}

@MainActor
private final class CalendarListViewModel: ObservableObject {
    @Published var output = "Click \"List Calendars\" to request Calendar access and show visible calendars."
    @Published var isLoading = false

    func listCalendars() {
        isLoading = true
        output = "Requesting Calendar access…"

        Task {
            do {
                let calendars = try await EventKitCalendarStore().listCalendars()
                output = CalendarListFormatter.format(calendars)
            } catch {
                output = String(describing: error)
            }

            isLoading = false
        }
    }
}

private struct CalendarListView: View {
    @StateObject var viewModel: CalendarListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CalRelay")
                    .font(.largeTitle)
                Text("List EventKit-visible calendars using the app's own macOS Calendar permission identity.")
                    .foregroundStyle(.secondary)
            }

            Button(viewModel.isLoading ? "Loading…" : "List Calendars") {
                viewModel.listCalendars()
            }
            .disabled(viewModel.isLoading)

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
        .padding()
    }
}