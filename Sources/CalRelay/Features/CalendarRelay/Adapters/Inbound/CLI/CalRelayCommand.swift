import ArgumentParser
import CalRelayAdapters
import CalRelayCore
import Foundation

struct CalRelayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calrelay",
        abstract: "Relay Apple Calendar availability blockers across configured calendars.",
        discussion: "Calendar listing and reconciliation commands are available, with EventKit-backed calendar access added in a later slice.",
        subcommands: [CalendarsCommand.self, ReconcileCommand.self]
    )
}

struct CalendarsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendars",
        abstract: "List visible calendars and their source/title selectors."
    )

    func run() throws {
        throw ValidationError("Calendar listing is not available until the EventKit adapter is configured.")
    }
}

struct ReconcileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reconcile",
        abstract: "Load configuration and plan calendar relay changes.",
        discussion: "Dry-run is the default. Pass --apply to request mutation after the EventKit adapter is wired."
    )

    @Option(name: .long, help: "Path to the CalRelay YAML configuration file.")
    var config: String

    @Flag(name: .long, help: "Apply planned changes. Without this flag, reconciliation is a dry-run.")
    var apply = false

    func run() throws {
        let yaml = try String(contentsOfFile: config, encoding: .utf8)
        _ = try YAMLCalendarRelaySettingsLoader.load(yaml)

        print(apply ? "Apply requested." : "Dry-run mode. No calendar mutations will be performed.")
        print(ReconciliationPlanFormatter.format(ReconciliationPlan(creates: [], deletes: [])))

        throw ValidationError("Calendar reconciliation is not available until the EventKit adapter is configured.")
    }
}