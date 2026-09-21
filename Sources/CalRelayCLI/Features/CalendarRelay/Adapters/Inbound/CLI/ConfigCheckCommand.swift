import ArgumentParser
import CalRelayKit

struct ConfigCheckCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check", abstract: "Validate configuration and current calendar readiness.")

    @Option(name: .long, help: "Override path to the CalRelay YAML configuration file.") var config: String?

    func run() async throws {
        let composition = CalendarCLIComposition.current()
        print(
            try await ConfigCheckCommandHandler(
                authorizationStatus: composition.authorizationStatus, calendarStore: composition.calendarStore,
                now: composition.now, calendar: composition.calendar
            ).run(config: config))
    }
}
