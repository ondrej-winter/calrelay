import ArgumentParser

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config", abstract: "Inspect CalRelay configuration status.",
        subcommands: [ConfigCheckCommand.self])
}
