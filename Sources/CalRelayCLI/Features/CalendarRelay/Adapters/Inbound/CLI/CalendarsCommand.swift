import ArgumentParser
import CalRelayKit

struct CalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendars", abstract: "List visible calendars and their source/title selectors.")

    func run() async throws {
        let authorization = EventKitCalendarAuthorizationStatus()
        let calendarStore = EventKitCalendarStore(authorizationStatus: authorization)
        let inventory = CalendarInventoryUseCase(authorizationStatus: authorization, calendarStore: calendarStore)
        print(try await CalendarListCommandHandler(inventory: inventory).run())
    }
}
