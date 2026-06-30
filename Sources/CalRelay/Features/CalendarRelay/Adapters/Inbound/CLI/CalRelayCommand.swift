import ArgumentParser

struct CalRelayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calrelay",
        abstract: "Relay Apple Calendar availability blockers across configured calendars.",
        discussion: "This first implementation slice provides the CLI foundation only. Calendar listing and reconciliation will be added in later slices."
    )
}