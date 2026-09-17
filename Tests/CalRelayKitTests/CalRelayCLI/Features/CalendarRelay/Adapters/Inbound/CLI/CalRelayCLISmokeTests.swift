import Foundation

enum CalRelayCLISmokeTests {
    static func runAll() throws {
        try testRootHelpListsCalendarRelaySubcommands()
        try testCalendarsHelpDescribesCalendarListingCommand()
        try testConfigCheckHelpDescribesReadinessCommand()
        try testReconcileHelpListsSupportedOptions()
        try testInvalidApplyExplainCombinationFailsBeforeConfigurationAccess()
        try testInvalidCleanupExplainCombinationFailsBeforeConfigurationAccess()
    }

    private static func testRootHelpListsCalendarRelaySubcommands() throws {
        let output = try runCalRelayHelp(arguments: ["--help"])

        try expect(output.contains("calendars"), "Root help should list the calendars subcommand")
        try expect(output.contains("config"), "Root help should list the config subcommand")
        try expect(output.contains("reconcile"), "Root help should list the reconcile subcommand")
        try expect(
            output.contains("Relay Apple Calendar availability blockers"), "Root help should describe the CalRelay CLI")
    }

    private static func testConfigCheckHelpDescribesReadinessCommand() throws {
        let result = try runCalRelay(arguments: ["config", "check", "--help"])

        try expect(result.status == 0, "Config check help should exit successfully")
        try expect(
            result.combinedOutput.contains("Validate configuration and current calendar readiness"),
            "Config check help should describe readiness")
        try expect(result.combinedOutput.contains("--config"), "Config check help should expose the config override")
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
        try expect(output.contains("--cleanup-legacy"), "Reconcile help should expose cleanup mode")
    }

    private static func testInvalidApplyExplainCombinationFailsBeforeConfigurationAccess() throws {
        let result = try runCalRelay(arguments: [
            "reconcile", "--apply", "--explain", "--config", "/definitely/missing/config.yaml"
        ])

        try expect(result.status != 0, "Invalid mode combination should return nonzero")
        try expect(
            result.stderr.contains("--apply and --explain cannot be used together"),
            "Invalid combination should be written to stderr")
        try expect(
            !result.combinedOutput.contains("No CalRelay configuration file found"),
            "Validation should fail before configuration access")
    }

    private static func testInvalidCleanupExplainCombinationFailsBeforeConfigurationAccess() throws {
        let result = try runCalRelay(arguments: [
            "reconcile", "--cleanup-legacy", "--explain", "--config", "/definitely/missing/config.yaml"
        ])

        try expect(result.status != 0, "Invalid cleanup/explain combination should return nonzero")
        try expect(
            result.stderr.contains("--cleanup-legacy and --explain cannot be used together"),
            "Invalid cleanup combination should be written to stderr")
        try expect(
            !result.combinedOutput.contains("No CalRelay configuration file found"),
            "Validation should fail before configuration access")
    }

    private static func runCalRelayHelp(arguments: [String]) throws -> String {
        let result = try runCalRelay(arguments: arguments)
        guard result.status == 0 else {
            throw TestFailure(
                "Expected calrelay \(arguments.joined(separator: " ")) to exit 0, got \(result.status): \(result.combinedOutput)"
            )
        }
        return result.combinedOutput
    }

    private static func runCalRelay(arguments: [String]) throws -> CommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let builtCLI = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(
            ".build/debug/calrelay")

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
        return CommandResult(status: process.terminationStatus, stdout: output, stderr: errorOutput)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String { stdout + stderr }
}
