import ArgumentParser
import CalRelayKit

struct ReconcileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reconcile", abstract: "Load configuration and plan calendar relay changes.",
        discussion: "Dry-run is the default. Pass --apply to create/delete planned EventKit projections.")

    @Option(name: .long, help: "Override path to the CalRelay YAML configuration file.") var config: String?

    @Flag(name: .long, help: "Apply planned changes. Without this flag, reconciliation is a dry-run.") var apply = false

    @Flag(
        name: .long,
        help: "Explain inclusion/exclusion decisions for every candidate event instead of planning changes.")
    var explain = false

    func run() async throws {
        print(try await ReconcileCommandHandler().run(config: config, apply: apply, explain: explain))
    }
}