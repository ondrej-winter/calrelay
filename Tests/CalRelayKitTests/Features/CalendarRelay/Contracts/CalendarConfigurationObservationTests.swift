import CalRelayKit
import Foundation

enum CalendarConfigurationObservationTests {
    static func runAll() async throws {
        try testIdleChangeRequestsImmediateRefresh()
        try testChangesDuringOperationCoalesceIntoOneFollowUpRefresh()
        try await testImmediateRecoveryInvalidatesPendingReviews()
        try await testObserverDetectsCreationBelowMissingDirectory()
        try await testObserverDetectsInPlaceEdit()
        try await testObserverDetectsAtomicReplacement()
        try await testObserverDetectsRemoval()
    }

    private static func testIdleChangeRequestsImmediateRefresh() throws {
        var coordinator = CalendarConfigurationChangeCoordinator()

        try expect(
            coordinator.configurationDidChange(isOperationInProgress: false),
            "An idle configuration change should request an immediate refresh")
        try expect(!coordinator.operationDidFinish(), "An immediate refresh should not leave a second refresh pending")
    }

    private static func testChangesDuringOperationCoalesceIntoOneFollowUpRefresh() throws {
        var coordinator = CalendarConfigurationChangeCoordinator()

        try expect(
            !coordinator.configurationDidChange(isOperationInProgress: true),
            "A configuration change must not interrupt an active operation")
        try expect(
            !coordinator.configurationDidChange(isOperationInProgress: true),
            "Repeated changes during one operation should remain deferred")
        try expect(
            coordinator.operationDidFinish(), "The completed operation should trigger one fresh follow-up refresh")
        try expect(
            !coordinator.operationDidFinish(), "Deferred configuration changes should coalesce into at most one refresh"
        )
    }

    private static func testImmediateRecoveryInvalidatesPendingReviews() async throws {
        var coordinator = CalendarConfigurationChangeCoordinator()
        let applyFixture = ManualApplyFixture()
        let manualApply = applyFixture.useCase(
            provider: ManualApplySettingsProvider(settings: applyFixture.settings), store: applyFixture.store())
        let applyReview = try await manualApply.review()
        let cleanupFixture = ManualCleanupFixture()
        let manualCleanup = cleanupFixture.useCase(
            provider: ManualApplySettingsProvider(settings: cleanupFixture.settings), store: cleanupFixture.store())
        let cleanupReview = try await manualCleanup.review()

        try expect(
            coordinator.configurationDidChange(isOperationInProgress: false),
            "An observed change with open reviews should start immediate recovery")
        await manualApply.cancelReview()
        await manualCleanup.cancelReview()

        do {
            _ = try await manualApply.confirm(reviewID: applyReview.id)
            throw TestFailure("Observed configuration recovery must invalidate the ordinary review")
        } catch CalendarManualApplyError.reviewRequired {}
        do {
            _ = try await manualCleanup.confirm(reviewID: cleanupReview.id)
            throw TestFailure("Observed configuration recovery must invalidate the cleanup review")
        } catch CalendarManualCleanupError.reviewRequired {}
    }

    private static func testObserverDetectsCreationBelowMissingDirectory() async throws {
        let fixture = try ObservationFixture(existingConfiguration: nil)
        defer { fixture.cleanup() }
        let recorder = ConfigurationObservationRecorder()
        let observer = ConfigurationFileObserver(selectedFile: fixture.selectedFile)
        observer.start { Task { await recorder.record() } }
        defer { observer.stop() }

        try FileManager.default.createDirectory(
            at: fixture.configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("first".utf8).write(to: fixture.configurationURL)

        try await recorder.waitForChange("Creating the selected configuration should invalidate app status")
    }

    private static func testObserverDetectsInPlaceEdit() async throws {
        let fixture = try ObservationFixture(existingConfiguration: "first")
        defer { fixture.cleanup() }
        let recorder = ConfigurationObservationRecorder()
        let observer = ConfigurationFileObserver(selectedFile: fixture.selectedFile)
        observer.start { Task { await recorder.record() } }
        defer { observer.stop() }

        try Data("second version".utf8).write(to: fixture.configurationURL)

        try await recorder.waitForChange("Editing the selected configuration should invalidate app status")
    }

    private static func testObserverDetectsAtomicReplacement() async throws {
        let fixture = try ObservationFixture(existingConfiguration: "first")
        defer { fixture.cleanup() }
        let recorder = ConfigurationObservationRecorder()
        let observer = ConfigurationFileObserver(selectedFile: fixture.selectedFile)
        observer.start { Task { await recorder.record() } }
        defer { observer.stop() }

        try Data("second".utf8).write(to: fixture.configurationURL, options: .atomic)

        try await recorder.waitForChange("Atomically replacing the selected configuration should invalidate app status")
    }

    private static func testObserverDetectsRemoval() async throws {
        let fixture = try ObservationFixture(existingConfiguration: "first")
        defer { fixture.cleanup() }
        let recorder = ConfigurationObservationRecorder()
        let observer = ConfigurationFileObserver(selectedFile: fixture.selectedFile)
        observer.start { Task { await recorder.record() } }
        defer { observer.stop() }

        try FileManager.default.removeItem(at: fixture.configurationURL)

        try await recorder.waitForChange("Removing the selected configuration should invalidate app status")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct ObservationFixture {
    let rootURL: URL
    let configurationURL: URL
    let selectedFile: SelectedConfigurationFile

    init(existingConfiguration: String?) throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        configurationURL = rootURL.appendingPathComponent("nested/config.yaml")
        if let existingConfiguration {
            try FileManager.default.createDirectory(
                at: configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(existingConfiguration.utf8).write(to: configurationURL)
        }
        selectedFile = SelectedConfigurationFile(
            path: configurationURL.path, displayPath: "test-configuration", source: .explicitOverride)
    }

    func cleanup() { try? FileManager.default.removeItem(at: rootURL) }
}

private actor ConfigurationObservationRecorder {
    private var changeCount = 0

    func record() { changeCount += 1 }

    func waitForChange(_ failureMessage: String) async throws {
        let clock = ContinuousClock()
        for _ in 0..<100 {
            if changeCount > 0 { return }
            try await clock.sleep(for: .milliseconds(20))
        }
        throw TestFailure(failureMessage)
    }
}
