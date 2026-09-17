import ArgumentParser
import CalRelayKit

struct ConfigCheckCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check", abstract: "Validate configuration and current calendar readiness.")

    @Option(name: .long, help: "Override path to the CalRelay YAML configuration file.") var config: String?

    func run() async throws {
        let authorization = EventKitCalendarAuthorizationStatus()
        let calendarStore = EventKitCalendarStore(authorizationStatus: authorization)
        print(
            try await ConfigCheckCommandHandler(authorizationStatus: authorization, calendarStore: calendarStore).run(
                config: config))
    }
}
