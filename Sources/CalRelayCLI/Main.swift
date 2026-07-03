import ArgumentParser

@main @available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct CalRelayCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calrelay",
        abstract: "Relay Apple Calendar availability blockers across configured calendars.",
        discussion: "Calendar listing and reconciliation commands use EventKit-backed Apple Calendar access.",
        subcommands: [CalendarsCommand.self, ReconcileCommand.self])
}