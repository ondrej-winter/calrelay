import CalRelayKit
import Foundation

enum ConfigurationFileSelectionTests {
    static func runAll() throws {
        try testNoOverrideSelectsDefaultPathUnderInjectedHomeDirectory()
        try testAbsoluteOverrideUsesSuppliedPath()
        try testRelativeOverrideResolvesAgainstInjectedWorkingDirectory()
        try testExactTildeExpandsToInjectedHomeDirectory()
        try testLeadingTildeSlashExpandsAgainstInjectedHomeDirectory()
        try testUnsupportedExpansionFormsRemainLiteralRelativePaths()
        try testMissingDefaultConfigErrorIncludesCreationAndDocumentationGuidance()
        try testMissingUnsupportedExpansionRetainsExplicitOverrideGuidance()
    }

    private static func testNoOverrideSelectsDefaultPathUnderInjectedHomeDirectory() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: nil, homeDirectory: homeDirectory,
            fileExists: { path in path == "/Users/example/.config/calrelay/config.yaml" })

        try expect(
            selectedFile.path == "/Users/example/.config/calrelay/config.yaml",
            "Default path should use injected home directory")
        try expect(
            selectedFile.displayPath == "~/.config/calrelay/config.yaml", "Default display path should be home-relative"
        )
        try expect(selectedFile.source == .defaultPath, "Default path should report defaultPath source")
    }

    private static func testAbsoluteOverrideUsesSuppliedPath() throws {
        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: "/tmp/calrelay/config.yml",
            homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true),
            currentDirectory: URL(fileURLWithPath: "/workspace", isDirectory: true),
            fileExists: { path in path == "/tmp/calrelay/config.yml" })

        try expect(selectedFile.path == "/tmp/calrelay/config.yml", "Absolute override should be used as supplied")
        try expect(
            selectedFile.displayPath == "/tmp/calrelay/config.yml", "Absolute override display path should be preserved"
        )
        try expect(selectedFile.source == .explicitOverride, "Absolute override should report explicitOverride source")
    }

    private static func testRelativeOverrideResolvesAgainstInjectedWorkingDirectory() throws {
        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: "configs/calrelay.yml",
            homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true),
            currentDirectory: URL(fileURLWithPath: "/workspace/project", isDirectory: true),
            fileExists: { path in path == "/workspace/project/configs/calrelay.yml" })

        try expect(
            selectedFile.path == "/workspace/project/configs/calrelay.yml",
            "Relative override should resolve against injected working directory")
        try expect(
            selectedFile.displayPath == "configs/calrelay.yml", "Relative override display path should be preserved")
    }

    private static func testExactTildeExpandsToInjectedHomeDirectory() throws {
        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: "~", homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true),
            currentDirectory: URL(fileURLWithPath: "/workspace", isDirectory: true),
            fileExists: { path in path == "/Users/example" })

        try expect(selectedFile.path == "/Users/example", "Exact tilde should expand to injected home directory")
        try expect(selectedFile.displayPath == "~", "Exact tilde display path should be preserved")
    }

    private static func testLeadingTildeSlashExpandsAgainstInjectedHomeDirectory() throws {
        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: "~/configs/calrelay.yml",
            homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true),
            currentDirectory: URL(fileURLWithPath: "/workspace", isDirectory: true),
            fileExists: { path in path == "/Users/example/configs/calrelay.yml" })

        try expect(
            selectedFile.path == "/Users/example/configs/calrelay.yml",
            "Leading tilde slash should expand against injected home directory")
        try expect(
            selectedFile.displayPath == "~/configs/calrelay.yml", "Tilde override display path should be preserved")
    }

    private static func testUnsupportedExpansionFormsRemainLiteralRelativePaths() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let currentDirectory = URL(fileURLWithPath: "/workspace", isDirectory: true)
        let expectations = [
            ("~otheruser/config.yml", "/workspace/~otheruser/config.yml"),
            ("$HOME/config.yml", "/workspace/$HOME/config.yml"),
            ("configs/~archive/config.yml", "/workspace/configs/~archive/config.yml")
        ]

        for (overridePath, expectedPath) in expectations {
            let selectedFile = try ConfigurationFileSelection.select(
                overridePath: overridePath, homeDirectory: homeDirectory, currentDirectory: currentDirectory,
                fileExists: { path in path == expectedPath })

            try expect(
                selectedFile.path == expectedPath, "Unsupported expansion form should remain literal: \(overridePath)")
            try expect(
                selectedFile.displayPath == overridePath, "Unsupported expansion display path should be preserved")
        }
    }

    private static func testMissingDefaultConfigErrorIncludesCreationAndDocumentationGuidance() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        do {
            _ = try ConfigurationFileSelection.select(
                overridePath: nil, homeDirectory: homeDirectory, fileExists: { _ in false })
        } catch let error as MissingConfigurationFileError {
            try expect(
                error.description.contains("~/.config/calrelay/config.yaml"),
                "Default missing-config error should include display path")
            try expect(
                error.description.contains("Create one there"),
                "Default missing-config error should include creation guidance")
            try expect(
                error.description.contains("--config <path>"),
                "Default missing-config error should mention override flag")
            try expect(
                error.description.contains("docs/configuration.md"),
                "Default missing-config error should link configuration docs")
            return
        }

        throw TestFailure("Expected MissingConfigurationFileError")
    }

    private static func testMissingUnsupportedExpansionRetainsExplicitOverrideGuidance() throws {
        do {
            _ = try ConfigurationFileSelection.select(
                overridePath: "~otheruser/missing.yml",
                homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true),
                currentDirectory: URL(fileURLWithPath: "/workspace", isDirectory: true), fileExists: { _ in false })
        } catch let error as MissingConfigurationFileError {
            try expect(
                error.description.contains("~otheruser/missing.yml"),
                "Explicit missing-config error should include provided path")
            try expect(
                error.description.contains("Check the path or pass a different --config <path>."),
                "Explicit missing-config error should include override-specific guidance")
            try expect(
                !error.description.contains("Create one there"),
                "Explicit missing-config error should not include default creation guidance")
            try expect(
                !error.description.contains("docs/configuration.md"),
                "Explicit missing-config error should not include default docs guidance")
            return
        }

        throw TestFailure("Expected MissingConfigurationFileError")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
