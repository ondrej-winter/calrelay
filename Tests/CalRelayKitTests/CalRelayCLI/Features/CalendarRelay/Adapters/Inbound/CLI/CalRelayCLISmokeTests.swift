import Foundation

enum CalRelayCLISmokeTests {
    static func runAll() throws {
        try testRootHelpListsCalendarRelaySubcommands()
        try testCalendarsHelpDescribesCalendarListingCommand()
        try testReconcileHelpListsSupportedOptions()
    }

    private static func testRootHelpListsCalendarRelaySubcommands() throws {
        let output = try runCalRelayHelp(arguments: ["--help"])

        try expect(output.contains("calendars"), "Root help should list the calendars subcommand")
        try expect(output.contains("reconcile"), "Root help should list the reconcile subcommand")
        try expect(
            output.contains("Relay Apple Calendar availability blockers"),
            "Root help should describe the CalRelay CLI")
    }

    private static func testCalendarsHelpDescribesCalendarListingCommand() throws {
        let output = try runCalRelayHelp(arguments: ["calendars", "--help"])

        try expect(output.contains("List visible calendars"), "Calendars help should describe calendar listing")
    }

    private static func testReconcileHelpListsSupportedOptions() throws {
        let output = try runCalRelayHelp(arguments: ["reconcile", "--help"])

        try expect(output.contains("--config"), "Reconcile help should expose the config override option")
        try expect(output.contains("--apply"), "Reconcile help should expose apply mode")
        try expect(output.contains("--explain"), "Reconcile help should expose explain mode")
    }

    private static func runCalRelayHelp(arguments: [String]) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let builtCLI = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/debug/calrelay")

        if FileManager.default.isExecutableFile(atPath: builtCLI.path) {
            process.executableURL = builtCLI
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["swift", "run", "calrelay"] + arguments
        }

        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combinedOutput = output + errorOutput

        guard process.terminationStatus == 0 else {
            throw TestFailure("Expected calrelay \(arguments.joined(separator: " ")) to exit 0, got \(process.terminationStatus): \(combinedOutput)")
        }

        return combinedOutput
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}