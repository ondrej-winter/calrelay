import Foundation

@main struct CalRelayKitTestRunner {
    private static let registeredFilters: Set<String> = [
        "CalendarAccessPreflightTests", "CalendarAccessPrivacyTests", "CalendarAppBundleMetadataTests",
        "CalendarAuthorizationTests", "CalendarAutomaticReconciliationTests", "CalendarAutomationCoordinationTests",
        "CalendarAutomationPersistenceTests", "CalendarCleanupAccessTests", "CalendarConfigurationIdentityTests",
        "CalendarConfigurationObservationTests", "CalendarConfigurationSchemaTests", "CalendarControlPanelStatusTests",
        "CalendarListCommandHandlerTests", "CalendarLoginLaunchPolicyTests", "CalendarManualApplyFreshSnapshotTests",
        "CalendarManualApplySafetyTests", "CalendarManualApplyTests", "CalendarManualCleanupFailureTests",
        "CalendarManualCleanupReviewTests", "CalendarManualCleanupSnapshotTests", "CalendarManualCleanupTests",
        "CalendarManualDryRunTests", "CalendarMutationExecutorTests", "CalendarNoPromptContractTests",
        "CalendarReviewedActionTests", "CalendarStandingAuthorizationTests", "CalRelayCLISmokeTests",
        "CalRelayContractTests", "ConfigCheckCommandHandlerTests", "EventKitExactEventOccurrenceResolverTests",
        "FileCalendarRelaySettingsProviderTests", "OrdinaryReconciliationCalendarCaptureTests",
        "OrdinaryReconciliationWindowTests", "ReconcileCommandHandlerTests",
        "RoutingSpecificationTests", "ConfigurationFileSelectionTests"
    ]

    static func main() async throws {
        let filters = Set(CommandLine.arguments.dropFirst())
        let unknownFilters = filters.subtracting(registeredFilters)
        guard unknownFilters.isEmpty else {
            throw TestFailure("Unknown test suite filter(s): \(unknownFilters.sorted().joined(separator: ", "))")
        }
        try await runConfigurationSuites(filters: filters)
        if filters.isEmpty || filters.contains("CalendarReviewedActionTests") {
            try CalendarReviewedActionTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarConfigurationObservationTests") {
            try await CalendarConfigurationObservationTests.runAll()
        }
        try await runAccessSuites(filters: filters)
        try await runAutomationSuites(filters: filters)
        if filters.isEmpty || filters.contains("CalendarManualCleanupTests") {
            try await CalendarManualCleanupTests.runAll()
        } else {
            if filters.contains("CalendarManualCleanupSnapshotTests") {
                try await CalendarManualCleanupTests.runSnapshotTests()
            }
            if filters.contains("CalendarManualCleanupFailureTests") {
                try await CalendarManualCleanupTests.runFailureTests()
            }
            if filters.contains("CalendarManualCleanupReviewTests") {
                try await CalendarManualCleanupTests.runReviewTests()
            }
        }
        if filters.isEmpty || filters.contains("CalendarManualApplyTests") {
            try await CalendarManualApplyTests.runAll()
        } else {
            if filters.contains("CalendarManualApplySafetyTests") {
                try await CalendarManualApplyTests.runSafetyTests()
            }
            if filters.contains("CalendarManualApplyFreshSnapshotTests") {
                try await CalendarManualApplyTests.runFreshSnapshotTests()
            }
        }
        try await runCommandSuites(filters: filters)
        try await runContractSuites(filters: filters)
        print("CalRelayKitTests passed")
    }

    private static func runConfigurationSuites(filters: Set<String>) async throws {
        if filters.isEmpty || filters.contains("ConfigurationFileSelectionTests") {
            try ConfigurationFileSelectionTests.runAll()
        }
        if filters.isEmpty || filters.contains("FileCalendarRelaySettingsProviderTests") {
            try await FileCalendarRelaySettingsProviderTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarConfigurationSchemaTests") {
            try CalendarConfigurationSchemaTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarConfigurationIdentityTests") {
            try CalendarConfigurationIdentityTests.runAll()
        }
        if filters.isEmpty || filters.contains("OrdinaryReconciliationWindowTests") {
            try OrdinaryReconciliationWindowTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAccessPrivacyTests") {
            try await CalendarAccessPrivacyTests.runAll()
        }
    }

    private static func runAccessSuites(filters: Set<String>) async throws {
        if filters.isEmpty || filters.contains("CalendarAppBundleMetadataTests") {
            try CalendarAppBundleMetadataTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarListCommandHandlerTests") {
            try await CalendarListCommandHandlerTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAuthorizationTests") {
            try await CalendarAuthorizationTests.runAll()
        }
        if filters.isEmpty || filters.contains("EventKitExactEventOccurrenceResolverTests") {
            try ExactEventOccurrenceResolverTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarNoPromptContractTests") {
            try await CalendarNoPromptContractTests.runAll()
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

    private static func runAutomationSuites(filters: Set<String>) async throws {
        if filters.isEmpty || filters.contains("CalendarAutomationPersistenceTests") {
            try await CalendarAutomationPersistenceTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarStandingAuthorizationTests") {
            try await CalendarStandingAuthorizationTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAutomaticReconciliationTests") {
            try await CalendarAutomaticReconciliationTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarAutomationCoordinationTests") {
            try await CalendarAutomationCoordinationTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalendarLoginLaunchPolicyTests") {
            try CalendarLoginLaunchPolicyTests.runAll()
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
        if filters.isEmpty || filters.contains("OrdinaryReconciliationCalendarCaptureTests") {
            try await OrdinaryReconciliationCalendarCaptureTests.runAll()
        }
        if filters.isEmpty || filters.contains("RoutingSpecificationTests") {
            try await RoutingSpecificationTests.runAll()
        }
        if filters.isEmpty || filters.contains("CalRelayContractTests") { try await CalRelayContractTests.runAll() }
        if filters.isEmpty || filters.contains("CalRelayCLISmokeTests") { try CalRelayCLISmokeTests.runAll() }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}
