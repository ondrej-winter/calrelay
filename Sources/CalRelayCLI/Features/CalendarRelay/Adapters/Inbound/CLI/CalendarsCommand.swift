import ArgumentParser
import CalRelayKit

struct CalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendars", abstract: "List visible calendars and their source/title selectors.")

    func run() async throws {
        print(try await CalendarListCommandHandler().run())
    }
}