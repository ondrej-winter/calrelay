import ArgumentParser
import CalRelayKit

struct CalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendars", abstract: "List visible calendars and their source/title selectors.")

    func run() async throws {
        let composition = CalendarCLIComposition.current()
        let inventory = CalendarInventoryUseCase(
            authorizationStatus: composition.authorizationStatus, calendarStore: composition.calendarStore)
        print(try await CalendarListCommandHandler(inventory: inventory).run())
    }
}
