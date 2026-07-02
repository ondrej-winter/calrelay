import CalRelayCommandSupport
import Foundation
import Testing

@Suite("Configuration file selection tests")
struct ConfigurationFileSelectionTests {
    @Test("No override selects canonical path under injected home directory")
    func noOverrideSelectsDefaultPath() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: nil,
            homeDirectory: homeDirectory,
            fileExists: { path in path == "/Users/example/.config/calrelay/config.yaml" }
        )

        #expect(selectedFile.path == "/Users/example/.config/calrelay/config.yaml")
        #expect(selectedFile.displayPath == "~/.config/calrelay/config.yaml")
        #expect(selectedFile.source == .defaultPath)
    }

    @Test("Explicit override selects provided path instead of default")
    func explicitOverrideSelectsProvidedPath() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let selectedFile = try ConfigurationFileSelection.select(
            overridePath: "./calrelay.yml",
            homeDirectory: homeDirectory,
            fileExists: { path in path == "./calrelay.yml" }
        )

        #expect(selectedFile.path == "./calrelay.yml")
        #expect(selectedFile.displayPath == "./calrelay.yml")
        #expect(selectedFile.source == .explicitOverride)
    }

    @Test("Missing default config error includes creation and documentation guidance")
    func missingDefaultConfigErrorIsActionable() throws {
        let homeDirectory = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        do {
            _ = try ConfigurationFileSelection.select(
                overridePath: nil,
                homeDirectory: homeDirectory,
                fileExists: { _ in false }
            )
        } catch let error as MissingConfigurationFileError {
            #expect(error.description.contains("~/.config/calrelay/config.yaml"))
            #expect(error.description.contains("Create one there"))
            #expect(error.description.contains("--config <path>"))
            #expect(error.description.contains("docs/configuration.md"))
            return
        }

        Issue.record("Expected MissingConfigurationFileError")
    }

    @Test("Missing explicit config error includes provided path without default creation guidance")
    func missingExplicitConfigErrorIsOverrideSpecific() throws {
        do {
            _ = try ConfigurationFileSelection.select(
                overridePath: "./missing.yml",
                fileExists: { _ in false }
            )
        } catch let error as MissingConfigurationFileError {
            #expect(error.description.contains("./missing.yml"))
            #expect(error.description.contains("Check the path or pass a different --config <path>."))
            #expect(!error.description.contains("Create one there"))
            #expect(!error.description.contains("docs/configuration.md"))
            return
        }

        Issue.record("Expected MissingConfigurationFileError")
    }
}