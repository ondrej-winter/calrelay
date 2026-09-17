import Foundation

@main struct CalRelayKitTestRunner {
    static func main() async throws {
        let filters = Set(CommandLine.arguments.dropFirst())
        try runConfigurationSuites(filters: filters)
        try await runAccessSuites(filters: filters)
        try await runCommandSuites(filters: filters)
        try await runContractSuites(filters: filters)
        print("CalRelayKitTests passed")
    }

    private static func runConfigurationSuites(filters: Set<String>) throws {
        if filters.isEmpty || filters.contains("ConfigurationFileSelectionTests") {
            try ConfigurationFileSelectionTests.runAll()
        }
        if filters.isEmpty || filters.contains("OrdinaryReconciliationWindowTests") {
            try OrdinaryReconciliationWindowTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAccessPrivacyTests") { try CalendarAccessPrivacyTests.runAll() }
    }

    private static func runAccessSuites(filters: Set<String>) async throws {
        if filters.isEmpty || filters.contains("CalendarListCommandHandlerTests") {
            try await CalendarListCommandHandlerTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAuthorizationTests") {
            try await CalendarAuthorizationTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAccessPreflightTests") {
            try await CalendarAccessPreflightTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarCleanupAccessTests") {
            try await CalendarCleanupAccessTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarMutationExecutorTests") {
            try await CalendarMutationExecutorTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarControlPanelStatusTests") {
            try await CalendarControlPanelStatusTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarManualDryRunTests") {
            try await CalendarManualDryRunTests.runAll()
        }
    }

    private static func runCommandSuites(filters: Set<String>) async throws {
        if filters.isEmpty || filters.contains("ReconcileCommandHandlerTests") {
            try await ReconcileCommandHandlerTests.runAll()
        }
        if filters.isEmpty || filters.contains("ConfigCheckCommandHandlerTests") {
            try await ConfigCheckCommandHandlerTests.runAll()
        }
    }

    private static func runContractSuites(filters: Set<String>) async throws {
        if filters.isEmpty || filters.contains("CalRelayContractTests") { try await CalRelayContractTests.runAll() }
        if filters.isEmpty || filters.contains("CalRelayCLISmokeTests") { try CalRelayCLISmokeTests.runAll() }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}
