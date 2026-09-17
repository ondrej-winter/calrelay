import ArgumentParser
import CalRelayKit

struct ReconcileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reconcile", abstract: "Load configuration and plan calendar relay changes.",
        discussion: "Dry-run is the default. Pass --apply to create/delete planned EventKit projections.")

    @Option(name: .long, help: "Override path to the CalRelay YAML configuration file.") var config: String?

    @Flag(name: .long, help: "Apply planned changes. Without this flag, reconciliation is a dry-run.") var apply = false

    @Flag(name: .long, help: "Explain every input classification and ordered planned action without mutation.")
    var explain = false

    @Flag(name: .long, help: "Run the explicit legacy-marker cleanup workflow instead of ordinary reconciliation.")
    var cleanupLegacy = false

    mutating func validate() throws {
        if apply && explain { throw ValidationError("--apply and --explain cannot be used together.") }
        if cleanupLegacy && explain { throw ValidationError("--cleanup-legacy and --explain cannot be used together.") }
    }

    func run() async throws {
        let authorization = EventKitCalendarAuthorizationStatus()
        let calendarStore = EventKitCalendarStore(authorizationStatus: authorization)
        let result = try await ReconcileCommandHandler(authorizationStatus: authorization, calendarStore: calendarStore)
            .run(
                config: config, apply: apply, explain: explain, cleanupLegacy: cleanupLegacy,
                onOutput: { line in print(line) })
        print(result)
    }
}
