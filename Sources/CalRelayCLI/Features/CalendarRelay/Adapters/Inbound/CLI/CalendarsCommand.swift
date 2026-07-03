import ArgumentParser
import CalRelayKit

struct CalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendars", abstract: "List visible calendars and their source/title selectors.")

    func run() async throws {
        let calendars = try await EventKitCalendarStore().listCalendars()
        print(CalendarListFormatter.format(calendars))
    }
}