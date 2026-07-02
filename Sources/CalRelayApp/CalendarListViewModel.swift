import CalRelayAdapters
import SwiftUI

@MainActor final class CalendarListViewModel: ObservableObject {
    @Published var output = "Click \"List Calendars\" to request Calendar access and show visible calendars."
    @Published var isLoading = false

    func listCalendars() {
        isLoading = true
        output = "Requesting Calendar access…"

        Task {
            do {
                let calendars = try await EventKitCalendarStore().listCalendars()
                output = CalendarListFormatter.format(calendars)
            } catch { output = String(describing: error) }

            isLoading = false
        }
    }
}
