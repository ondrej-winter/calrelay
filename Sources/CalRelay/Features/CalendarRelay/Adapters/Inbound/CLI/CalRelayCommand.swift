import ArgumentParser
import CalRelayAdapters
import CalRelayCommandSupport
import CalRelayCore
import Foundation

@main
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct CalRelayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calrelay",
        abstract: "Relay Apple Calendar availability blockers across configured calendars.",
        discussion: "Calendar listing and reconciliation commands use EventKit-backed Apple Calendar access.",
        subcommands: [CalendarsCommand.self, ReconcileCommand.self]
    )
}

struct CalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendars",
        abstract: "List visible calendars and their source/title selectors."
    )

    func run() async throws {
        let calendars = try await EventKitCalendarStore().listCalendars()
        print(CalendarListFormatter.format(calendars))
    }
}

struct ReconcileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reconcile",
        abstract: "Load configuration and plan calendar relay changes.",
        discussion: "Dry-run is the default. Pass --apply to create/delete planned EventKit projections."
    )

    @Option(name: .long, help: "Override path to the CalRelay YAML configuration file.")
    var config: String?

    @Flag(name: .long, help: "Apply planned changes. Without this flag, reconciliation is a dry-run.")
    var apply = false

    @Flag(name: .long, help: "Explain inclusion/exclusion decisions for every candidate event instead of planning changes.")
    var explain = false

    func run() async throws {
        let selectedFile = try ConfigurationFileSelection.select(overridePath: config)
        let yaml = try String(contentsOfFile: selectedFile.path, encoding: .utf8)
        let settings = try YAMLCalendarRelaySettingsLoader.load(yaml)
        let useCase = ReconcileCalendarsUseCase(calendarStore: EventKitCalendarStore())

        let now = Date()

        if explain {
            let explanations = try await useCase.explain(settings: settings, now: now)
            print(EventExplanationFormatter.format(explanations))
            return
        }

        let plan = try await (apply ? useCase.apply(settings: settings, now: now) : useCase.dryRun(settings: settings, now: now))
        print(apply ? "Apply mode. Planned calendar mutations were performed." : "Dry-run mode. No calendar mutations were performed.")
        print(ReconciliationPlanFormatter.format(plan))
    }
}
