import Foundation

enum CalRelayCLISmokeTests {
    static func runAll() throws {
        try testRootHelpListsCalendarRelaySubcommands()
        try testCalendarsHelpDescribesCalendarListingCommand()
        try testConfigCheckHelpDescribesReadinessCommand()
        try testReconcileHelpListsSupportedOptions()
        try testInvalidApplyExplainCombinationFailsBeforeConfigurationAccess()
        try testInvalidCleanupExplainCombinationFailsBeforeConfigurationAccess()
        try testExplanationFailureUsesStderrWithoutPartialOutput()
        try testEmptyInventoryUsesStdoutAndZeroStatus()
        try testReadyConfigCheckUsesStdoutAndZeroStatus()
        try testOrdinaryNoChangeApplyUsesStdoutAndZeroStatus()
        try testCleanupNoMatchDryRunAndApplyUseStdoutAndZeroStatus()
        try testInvalidConfigurationUsesStderrAndNonzeroStatus()
        try testMigrationPendingConfigCheckUsesStderrAndNonzeroStatus()
        try testMigrationPendingConfigCheckReportsPreflightFailures()
        try testMigrationPendingOrdinaryModesUseStderrAndNonzeroStatus()
        try testUnavailableCalendarAccessUsesPrivateStderrAndNonzeroStatus()
        try testExplanationAndDryRunUseTheSameOrderedActions()
        try testDirectOrdinaryApplyConfirmsEachSuccessfulAction()
        try testOrdinaryPartialFailureRetainsOnlyCompletedConfirmations()
        try testDirectCleanupApplyReviewsConfirmsAndVerifies()
        try testCleanupPartialFailureRetainsOnlyCompletedConfirmations()
    }

    private static func testRootHelpListsCalendarRelaySubcommands() throws {
        let result = try runCalRelay(arguments: ["--help"])

        try expect(result.status == 0, "Root help should exit successfully")
        try expect(result.stderr.isEmpty, "Successful root help should not write to stderr")
        try expect(result.stdout.contains("calendars"), "Root help should list the calendars subcommand")
        try expect(result.stdout.contains("config"), "Root help should list the config subcommand")
        try expect(result.stdout.contains("reconcile"), "Root help should list the reconcile subcommand")
        try expect(
            result.stdout.contains("Relay Apple Calendar availability blockers"),
            "Root help should describe the CalRelay CLI")
    }

    private static func testConfigCheckHelpDescribesReadinessCommand() throws {
        let result = try runCalRelay(arguments: ["config", "check", "--help"])

        try expect(result.status == 0, "Config check help should exit successfully")
        try expect(result.stderr.isEmpty, "Successful config check help should not write to stderr")
        try expect(
            result.stdout.contains("Validate configuration and current calendar readiness"),
            "Config check help should describe readiness")
        try expect(result.stdout.contains("--config"), "Config check help should expose the config override")
    }

    private static func testCalendarsHelpDescribesCalendarListingCommand() throws {
        let result = try runCalRelay(arguments: ["calendars", "--help"])

        try expect(result.status == 0, "Calendars help should exit successfully")
        try expect(result.stderr.isEmpty, "Successful calendars help should not write to stderr")
        try expect(result.stdout.contains("List visible calendars"), "Calendars help should describe calendar listing")
    }

    private static func testReconcileHelpListsSupportedOptions() throws {
        let result = try runCalRelay(arguments: ["reconcile", "--help"])
        let output = result.stdout

        try expect(result.status == 0, "Reconcile help should exit successfully")
        try expect(result.stderr.isEmpty, "Successful reconcile help should not write to stderr")
        try expect(output.contains("--config"), "Reconcile help should expose the config override option")
        try expect(output.contains("--apply"), "Reconcile help should expose apply mode")
        try expect(output.contains("--explain"), "Reconcile help should expose explain mode")
        try expect(
            output.contains("every input classification") && output.contains("planned action without mutation"),
            "Reconcile help should describe the complete explanation mode")
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

    private static func testExplanationFailureUsesStderrWithoutPartialOutput() throws {
        let missingPath = "/definitely/missing/private-calendar-config.yaml"
        let result = try runCalRelay(arguments: ["reconcile", "--explain", "--config", missingPath])

        try expect(result.status != 0, "Failed explanation should return nonzero")
        try expect(result.stdout.isEmpty, "Failed explanation should not emit partial success output")
        try expect(
            result.stderr.contains("No CalRelay configuration file found"), "Failure should be written to stderr")
        try expect(result.stderr.contains(missingPath), "Failure should identify the selected configuration path")
        try expect(!result.stderr.contains("Input events"), "Failure should not emit a partial input-event section")
        try expect(!result.stderr.contains("Planned actions"), "Failure should not emit a partial action section")
        try expect(!result.stderr.contains("event-id="), "Failure should not disclose EventKit event IDs")
        try expect(!result.stderr.contains("calendar-id="), "Failure should not disclose EventKit calendar IDs")
    }

    private static func testEmptyInventoryUsesStdoutAndZeroStatus() throws {
        let result = try runCalRelay(arguments: ["calendars"], scenario: "empty-inventory")

        try expect(result.status == 0, "Successful empty inventory should return zero")
        try expect(result.stderr.isEmpty, "Successful empty inventory should not write to stderr")
        try expect(
            result.stdout.contains("No EventKit-visible calendars"),
            "Successful empty inventory should write its result to stdout")
        try expect(
            result.stdout.contains("Inventory discovery succeeded"), "Empty inventory should remain an explicit success"
        )
    }

    private static func testReadyConfigCheckUsesStdoutAndZeroStatus() throws {
        let config = try writeConfig()
        let result = try runCalRelay(arguments: ["config", "check", "--config", config.path], scenario: "ready")

        try expect(result.status == 0, "Ready config check should return zero")
        try expect(result.stderr.isEmpty, "Ready config check should not write to stderr")
        try expect(result.stdout.contains(config.path), "Ready config check should report the selected path")
        try expect(
            result.stdout.contains("complete configured topology is currently ready"),
            "Ready config check should write readiness to stdout")
    }

    private static func testOrdinaryNoChangeApplyUsesStdoutAndZeroStatus() throws {
        let config = try writeConfig()
        let result = try runCalRelay(arguments: ["reconcile", "--apply", "--config", config.path], scenario: "ready")

        try expect(result.status == 0, "Ordinary no-change apply should return zero")
        try expect(result.stderr.isEmpty, "Ordinary no-change apply should not write to stderr")
        try expect(
            result.stdout.contains("No ordinary reconciliation changes were needed"),
            "Ordinary no-change apply should report successful no-change on stdout")
        try expect(
            result.stdout.contains("No changes planned"), "Ordinary no-change apply should include the empty plan")
        try expect(
            !result.stdout.contains("Confirmed create") && !result.stdout.contains("Confirmed delete"),
            "Ordinary no-change apply should not claim a mutation")
    }

    private static func testCleanupNoMatchDryRunAndApplyUseStdoutAndZeroStatus() throws {
        let config = try writeConfig(legacyMarkers: ["[OLD]"])
        let dryRun = try runCalRelay(
            arguments: ["reconcile", "--cleanup-legacy", "--config", config.path], scenario: "ready")
        let apply = try runCalRelay(
            arguments: ["reconcile", "--cleanup-legacy", "--apply", "--config", config.path], scenario: "ready")

        try expect(dryRun.status == 0, "Cleanup no-match dry-run should return zero")
        try expect(dryRun.stderr.isEmpty, "Cleanup no-match dry-run should not write to stderr")
        try expect(
            dryRun.stdout.contains("found no matching legacy-marker events in the loaded local snapshot"),
            "Cleanup no-match dry-run should report its local result on stdout")
        try expectTruthfulCleanupScope(dryRun.stdout)
        try expect(apply.status == 0, "Cleanup no-match apply should return zero")
        try expect(apply.stderr.isEmpty, "Cleanup no-match apply should not write to stderr")
        try expect(
            apply.stdout.contains("Fresh cleanup plan before mutation"),
            "Direct cleanup apply should print its fresh plan on stdout")
        try expect(
            apply.stdout.contains("post-mutation verification snapshot contained no matching legacy-marker events"),
            "Cleanup no-match apply should report verified local success on stdout")
        try expectTruthfulCleanupScope(apply.stdout)
    }

    private static func testInvalidConfigurationUsesStderrAndNonzeroStatus() throws {
        let config = try writeConfig(contents: "not: valid-for-calrelay\n")
        let result = try runCalRelay(arguments: ["config", "check", "--config", config.path], scenario: "ready")

        try expect(result.status != 0, "Invalid configuration should return nonzero")
        try expect(result.stdout.isEmpty, "Invalid configuration should not write a false success result to stdout")
        try expect(
            result.stderr.contains("Invalid configuration"),
            "Invalid configuration should write an actionable diagnostic to stderr")
        try expect(
            !result.stderr.contains("process-hub"), "Invalid configuration failure should omit fixture identifiers")
    }

    private static func testMigrationPendingConfigCheckUsesStderrAndNonzeroStatus() throws {
        let config = try writeConfig(legacyMarkers: ["[OLD]"])
        let result = try runCalRelay(arguments: ["config", "check", "--config", config.path], scenario: "ready")

        try expect(result.status != 0, "Migration-pending config check should return nonzero")
        try expect(result.stdout.isEmpty, "Migration-pending config check should not print readiness to stdout")
        try expect(
            result.stderr.contains(config.path), "Migration-pending config check should identify the selected path")
        try expect(
            result.stderr.contains("migration pending"), "Migration-pending config check should explain the gate")
        try expect(
            result.stderr.contains("Run explicit legacy cleanup")
                && result.stderr.contains("remove legacyMarkers manually"),
            "Migration-pending config check should provide cleanup and manual-edit guidance")
        try expect(
            !result.stderr.contains("complete configured topology is currently ready"),
            "Migration-pending config check should not print a readiness success statement")
    }

    private static func testMigrationPendingConfigCheckReportsPreflightFailures() throws {
        let config = try writeConfig(legacyMarkers: ["[OLD]"])
        let result = try runCalRelay(arguments: ["config", "check", "--config", config.path], scenario: "access-denied")

        try expect(result.status != 0, "Migration-pending config check with access failure should return nonzero")
        try expect(result.stdout.isEmpty, "Migration-pending access failure should not print success output")
        try expect(
            result.stderr.contains("migration pending") && result.stderr.contains("topology is not currently ready"),
            "Migration-pending config check should report both migration and preflight failure")
        try expect(
            result.stderr.contains("Enable full access for CalRelay in System Settings"),
            "Migration-pending config check should retain actionable preflight guidance")
        try expect(
            !result.stderr.contains("complete configured topology is currently ready"),
            "Migration-pending config check must never claim readiness")
    }

    private static func testMigrationPendingOrdinaryModesUseStderrAndNonzeroStatus() throws {
        let config = try writeConfig(legacyMarkers: ["[OLD]"])
        let originalYAML = try String(contentsOf: config, encoding: .utf8)
        let modes: [(name: String, arguments: [String])] = [
            ("dry run", ["reconcile", "--config", config.path]),
            ("apply", ["reconcile", "--apply", "--config", config.path]),
            ("explanation", ["reconcile", "--explain", "--config", config.path])
        ]

        for mode in modes {
            let result = try runCalRelay(arguments: mode.arguments, scenario: "ordinary-actions")

            try expect(result.status != 0, "Migration-pending ordinary " + mode.name + " should return nonzero")
            try expect(result.stdout.isEmpty, "Migration-pending ordinary " + mode.name + " should not print output")
            try expect(
                result.stderr.contains("blocked while legacyMarkers is nonempty")
                    && result.stderr.contains("explicit legacy cleanup"),
                "Migration-pending ordinary " + mode.name + " should direct the operator to cleanup")
            try expect(!result.stderr.contains("[OLD]"), "Migration failure should not disclose marker values")
            for forbidden in ["Dry-run mode", "Apply mode completed", "Input events", "Planned actions"] {
                try expect(
                    !result.stderr.contains(forbidden),
                    "Migration-pending ordinary " + mode.name + " must not claim successful ordinary work")
            }
            try expect(
                try String(contentsOf: config, encoding: .utf8) == originalYAML,
                "Migration-pending ordinary " + mode.name + " must not rewrite the selected YAML")
        }
    }

    private static func testUnavailableCalendarAccessUsesPrivateStderrAndNonzeroStatus() throws {
        let config = try writeConfig()
        let result = try runCalRelay(arguments: ["config", "check", "--config", config.path], scenario: "access-denied")

        try expect(result.status != 0, "Unavailable Calendar access should return nonzero")
        try expect(result.stdout.isEmpty, "Unavailable Calendar access should not write a success result to stdout")
        try expect(
            result.stderr.contains("Enable full access for CalRelay in System Settings"),
            "Unavailable Calendar access should provide actionable recovery guidance on stderr")
        for forbidden in ["process-hub", "process-work", "Personal Work", "ACME Work"] {
            try expect(!result.stderr.contains(forbidden), "Access failure should omit private detail: \(forbidden)")
        }
    }

    private static func testExplanationAndDryRunUseTheSameOrderedActions() throws {
        let config = try writeConfig()
        let dryRun = try runCalRelay(arguments: ["reconcile", "--config", config.path], scenario: "ordinary-actions")
        let explanation = try runCalRelay(
            arguments: ["reconcile", "--explain", "--config", config.path], scenario: "ordinary-actions")

        try expect(dryRun.status == 0, "Ordinary dry-run should return zero")
        try expect(dryRun.stderr.isEmpty, "Ordinary dry-run should not write to stderr")
        try expect(explanation.status == 0, "Successful explanation should return zero")
        try expect(explanation.stderr.isEmpty, "Successful explanation should not write to stderr")
        try expect(explanation.stdout.contains("Input events"), "Explanation should include every loaded input event")
        try expect(explanation.stdout.contains("Planned actions"), "Explanation should include planned actions")
        try expect(
            explanation.stdout.contains("event-id=process-work-source")
                && explanation.stdout.contains("calendar-id=process-work"),
            "Successful explanation may include correlation identifiers")
        try expectActionOrder(
            [
                "- delete iCloud / Personal Work: [ACME] Old Planning",
                "- create iCloud / Personal Work: [ACME] Client Planning",
                "- create Google / ACME Work: [ME] Personal appointment"
            ], in: dryRun.stdout, message: "Dry-run actions should follow execution order")
        try expectActionOrder(
            [
                "- delete Hub event-id=process-stale-hub", "- create Hub calendar-id=process-hub",
                "- create Work role ACME calendar-id=process-work: [ME] Personal appointment"
            ], in: explanation.stdout, message: "Explanation actions should match dry-run execution order")
    }

    private static func testDirectOrdinaryApplyConfirmsEachSuccessfulAction() throws {
        let config = try writeConfig()
        let result = try runCalRelay(
            arguments: ["reconcile", "--apply", "--config", config.path], scenario: "ordinary-actions")

        try expect(result.status == 0, "Direct ordinary apply should return zero after all confirmations")
        try expect(result.stderr.isEmpty, "Successful ordinary apply should not write to stderr")
        try expectActionOrder(
            [
                "Confirmed delete for Hub.", "Confirmed create for Hub.", "Confirmed create for Work role ACME.",
                "Apply mode completed successfully. All planned calendar mutations were confirmed."
            ], in: result.stdout, message: "Ordinary apply should confirm each action before reporting success")
        try expect(
            !result.stdout.contains("verified"), "Ordinary apply should not claim a post-apply verification read")
    }

    private static func testOrdinaryPartialFailureRetainsOnlyCompletedConfirmations() throws {
        let config = try writeConfig()
        let result = try runCalRelay(
            arguments: ["reconcile", "--apply", "--config", config.path], scenario: "ordinary-partial-failure")

        try expect(result.status != 0, "Partially applied ordinary reconciliation should return nonzero")
        try expect(
            result.stdout.contains("Confirmed delete for Hub."),
            "Ordinary partial failure should retain the completed deletion confirmation on stdout")
        try expect(
            !result.stdout.contains("Confirmed create") && !result.stdout.contains("Apply mode completed successfully"),
            "Ordinary partial failure should not confirm failed or later work or claim success")
        try expect(result.stderr.contains("partially applied"), "Ordinary partial failure should report partial state")
        try expect(
            result.stderr.contains("create failed"), "Ordinary partial failure should report its failure category")
        try expect(
            result.stderr.contains("No rollback was attempted") && result.stderr.contains("fresh reconciliation"),
            "Ordinary partial failure should provide no-rollback recovery guidance")
        for forbidden in [
            "process-stale-hub", "process-work-source", "process-personal-hub", "Old Planning", "Client Planning",
            "Personal appointment", "process-hub", "process-work"
        ] {
            try expect(
                !result.stderr.contains(forbidden), "Ordinary partial failure should omit private detail: \(forbidden)")
        }
    }

    private static func testDirectCleanupApplyReviewsConfirmsAndVerifies() throws {
        let config = try writeConfig(legacyMarkers: ["[OLD]"])
        let result = try runCalRelay(
            arguments: ["reconcile", "--cleanup-legacy", "--apply", "--config", config.path],
            scenario: "cleanup-success")

        try expect(result.status == 0, "Direct cleanup apply should return zero after verification")
        try expect(result.stderr.isEmpty, "Successful cleanup apply should not write to stderr")
        try expectActionOrder(
            [
                "Fresh cleanup plan before mutation", "- delete from Work role ACME: Cleanup Review",
                "Confirmed delete for Work role ACME.",
                "post-mutation verification snapshot contained no matching legacy-marker events"
            ], in: result.stdout, message: "Direct cleanup apply should review, confirm, then report verification")
        try expectTruthfulCleanupScope(result.stdout)
        try expect(!result.stdout.contains("[OLD]"), "Cleanup review should omit the configured legacy marker")
        try expect(!result.stdout.contains("process-cleanup"), "Cleanup output should omit EventKit identifiers")
    }

    private static func testCleanupPartialFailureRetainsOnlyCompletedConfirmations() throws {
        let config = try writeConfig(legacyMarkers: ["[OLD]"])
        let result = try runCalRelay(
            arguments: ["reconcile", "--cleanup-legacy", "--apply", "--config", config.path],
            scenario: "cleanup-partial-failure")

        try expect(result.status != 0, "Partially applied cleanup should return nonzero")
        try expect(
            result.stdout.contains("Fresh cleanup plan before mutation"),
            "Cleanup partial failure should retain its fresh review on stdout")
        try expect(
            occurrenceCount(of: "Confirmed delete", in: result.stdout) == 1
                && result.stdout.contains("Confirmed delete for Hub."),
            "Cleanup partial failure should retain only the completed deletion confirmation")
        try expect(
            !result.stdout.contains("Cleanup succeeded"), "Cleanup partial failure should not claim verified success")
        try expect(result.stderr.contains("partially applied"), "Cleanup partial failure should report partial state")
        try expect(
            result.stderr.contains("delete failed"), "Cleanup partial failure should report its failure category")
        try expect(
            result.stderr.contains("No rollback was attempted") && result.stderr.contains("fresh reconciliation"),
            "Cleanup partial failure should provide no-rollback recovery guidance")
        for forbidden in [
            "[OLD]", "process-cleanup-hub", "process-cleanup-work", "process-cleanup-later", "Hub Review",
            "Work Review", "Later Review", "process-hub", "process-work"
        ] {
            try expect(
                !result.stderr.contains(forbidden), "Cleanup partial failure should omit private detail: \(forbidden)")
        }
    }

    private static func writeConfig(legacyMarkers: [String] = []) throws -> URL {
        try writeConfig(contents: configYAML(legacyMarkers: legacyMarkers))
    }

    private static func writeConfig(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func configYAML(legacyMarkers: [String]) -> String {
        let legacySection =
            legacyMarkers.isEmpty
            ? "" : "\nlegacyMarkers:\n" + legacyMarkers.map { "  - \"\($0)\"" }.joined(separator: "\n")
        return """
            hubCalendar:
              sourceTitle: "iCloud"
              calendarTitle: "Personal Work"
            personalPrefix: "[ME]"
            syncWindowDays: 1
            workCalendars:
              - name: "ACME"
                prefix: "[ACME]"
                calendar:
                  sourceTitle: "Google"
                  calendarTitle: "ACME Work"
            \(legacySection)
            """
    }

    private static func runCalRelay(arguments: [String], scenario: String? = nil) throws -> CommandResult {
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
        if let scenario {
            process.environment = ProcessInfo.processInfo.environment.merging([
                "CALRELAY_PROCESS_TESTING": "1", "CALRELAY_PROCESS_TEST_SCENARIO": scenario
            ]) { _, processTestValue in processTestValue }
        }

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(status: process.terminationStatus, stdout: output, stderr: errorOutput)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }

    private static func expectActionOrder(_ values: [String], in output: String, message: String) throws {
        var searchStart = output.startIndex
        for value in values {
            guard let range = output.range(of: value, range: searchStart..<output.endIndex) else {
                throw TestFailure("\(message): missing or out of order: \(value)")
            }
            searchStart = range.upperBound
        }
    }

    private static func expectTruthfulCleanupScope(_ output: String) throws {
        try expect(
            output.localizedCaseInsensitiveContains("local")
                && output.localizedCaseInsensitiveContains("point-in-time"),
            "Cleanup process output should state its local point-in-time scope")
        for forbiddenClaim in [
            "all calendars", "entire history", "globally retired", "retired everywhere", "recurring series removed",
            "all recurring series retired", "removed calendars are covered", "covers removed calendars",
            "cannot be recreated", "will not be recreated"
        ] {
            try expect(
                !output.localizedCaseInsensitiveContains(forbiddenClaim),
                "Cleanup process output must not claim global, historical, recurring-series, or future-retirement scope"
            )
        }
    }

    private static func occurrenceCount(of value: String, in output: String) -> Int {
        output.components(separatedBy: value).count - 1
    }
}

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String { stdout + stderr }
}
