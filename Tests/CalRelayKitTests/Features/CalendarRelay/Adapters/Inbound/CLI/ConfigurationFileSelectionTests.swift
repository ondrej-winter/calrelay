import Foundation
import CalRelayKit

enum ConfigurationFileSelectionTests {
    static func runAll() throws {
        try testNoOverrideSelectsDefaultPathUnderInjectedHomeDirectory()
        try testExplicitOverrideSelectsProvidedPathInsteadOfDefault()
        try testMissingDefaultConfigErrorIncludesCreationAndDocumentationGuidance()
        try testMissingExplicitConfigErrorIncludesProvidedPathWithoutDefaultCreationGuidance()
    }

    private static func testNoOverrideSelectsDefaultPathUnderInjectedHomeDirectory() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: nil, homeDirectory: homeDirectory,
            fileExists: { path in path == "/Users/example/.config/calrelay/config.yaml" })

        try expect(selectedFile.path == "/Users/example/.config/calrelay/config.yaml", "Default path should use injected home directory")
        try expect(selectedFile.displayPath == "~/.config/calrelay/config.yaml", "Default display path should be home-relative")
        try expect(selectedFile.source == .defaultPath, "Default path should report defaultPath source")
    }

    private static func testExplicitOverrideSelectsProvidedPathInsteadOfDefault() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: "./calrelay.yml", homeDirectory: homeDirectory,
            fileExists: { path in path == "./calrelay.yml" })

        try expect(selectedFile.path == "./calrelay.yml", "Explicit override should preserve path")
        try expect(selectedFile.displayPath == "./calrelay.yml", "Explicit override display path should preserve path")
        try expect(selectedFile.source == .explicitOverride, "Explicit override should report explicitOverride source")
    }

    private static func testMissingDefaultConfigErrorIncludesCreationAndDocumentationGuidance() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        do {
            _ = try ConfigurationFileSelection.select(
                overridePath: nil, homeDirectory: homeDirectory, fileExists: { _ in false })
        } catch let error as MissingConfigurationFileError {
            try expect(error.description.contains("~/.config/calrelay/config.yaml"), "Default missing-config error should include display path")
            try expect(error.description.contains("Create one there"), "Default missing-config error should include creation guidance")
            try expect(error.description.contains("--config <path>"), "Default missing-config error should mention override flag")
            try expect(error.description.contains("docs/configuration.md"), "Default missing-config error should link configuration docs")
            return
        }

        throw TestFailure("Expected MissingConfigurationFileError")
    }

    private static func testMissingExplicitConfigErrorIncludesProvidedPathWithoutDefaultCreationGuidance() throws {
        do {
            _ = try ConfigurationFileSelection.select(overridePath: "./missing.yml", fileExists: { _ in false })
        } catch let error as MissingConfigurationFileError {
            try expect(error.description.contains("./missing.yml"), "Explicit missing-config error should include provided path")
            try expect(error.description.contains("Check the path or pass a different --config <path>."), "Explicit missing-config error should include override-specific guidance")
            try expect(!error.description.contains("Create one there"), "Explicit missing-config error should not include default creation guidance")
            try expect(!error.description.contains("docs/configuration.md"), "Explicit missing-config error should not include default docs guidance")
            return
        }

        throw TestFailure("Expected MissingConfigurationFileError")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
