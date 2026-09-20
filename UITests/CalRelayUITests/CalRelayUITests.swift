import XCTest

@MainActor final class CalRelayUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testMissingConfigurationBlocksConfigurationDependentActions() {
        let app = launch(scenario: "missing-configuration")
        defer { app.terminate() }

        assertElement("primary-status", in: app, contains: "Configuration is missing")
        assertElement("configuration-status", in: app, contains: "Missing: ~/.config/calrelay/config.yaml")
        XCTAssertFalse(isEnabled("dry-run-sync", in: app))
        XCTAssertFalse(isEnabled("run-sync-now", in: app))
        XCTAssertFalse(isEnabled("review-scheduled-sync", in: app))
    }

    func testCalendarAccessRecoveryStateBlocksOrdinarySync() {
        let app = launch(scenario: "calendar-access-unavailable")
        defer { app.terminate() }

        assertElement("primary-status", in: app, contains: "Full Calendar access is unavailable")
        assertElement("calendar-access-status", in: app, contains: "denied or revoked")
        XCTAssertTrue(isEnabled("setup-calendar-access", in: app))
        XCTAssertFalse(isEnabled("dry-run-sync", in: app))
        XCTAssertFalse(isEnabled("run-sync-now", in: app))
    }

    func testReadyInventoryAndDryRunRemainPrivacySafe() {
        let app = launch(scenario: "ready")
        defer { app.terminate() }
        waitUntilEnabled(element("dry-run-sync", in: app))

        element("show-calendar-inventory", in: app).click()
        assertElement("operation-output", in: app, contains: "Visible calendars (2)")
        assertElement("operation-output", in: app, contains: "Test Account / Test Hub [writable]")
        assertElement("operation-output", in: app, doesNotContain: "ui-hub")

        element("dry-run-sync", in: app).click()
        assertElement("operation-output", in: app, contains: "Dry run completed. No calendar mutations were performed.")
        assertElement("operation-output", in: app, contains: "Planned creates: 1")
        assertElement("operation-output", in: app, doesNotContain: "Planning")
        assertElement("operation-output", in: app, doesNotContain: "ui-source-event")
    }

    func testManualSyncReviewCanBeCancelledWithoutMutation() {
        let app = launch(scenario: "ready")
        defer { app.terminate() }
        waitUntilEnabled(element("run-sync-now", in: app))

        element("run-sync-now", in: app).click()
        assertElement("manual-review-title", in: app, contains: "Review Sync Plan")
        assertElement("manual-review-creates", in: app, contains: "Planned creates: 1")
        XCTAssertFalse(isEnabled("dry-run-sync", in: app))

        element("manual-review-cancel", in: app).click()
        waitUntilMissing(element("manual-review-title", in: app))
        assertElement(
            "operation-output", in: app, contains: "Sync review cancelled. No calendar mutations were performed.")
    }

    func testMigrationCleanupReviewIsSeparateAndTransient() {
        let app = launch(scenario: "migration-pending")
        defer { app.terminate() }
        waitUntilEnabled(element("run-legacy-cleanup", in: app))

        XCTAssertFalse(isEnabled("dry-run-sync", in: app))
        XCTAssertFalse(isEnabled("run-sync-now", in: app))
        element("run-legacy-cleanup", in: app).click()

        assertElement("cleanup-review-title", in: app, contains: "Review Legacy Cleanup")
        assertElement("cleanup-review-output", in: app, contains: "Selected deletions: 1")
        assertElement("cleanup-review-output", in: app, contains: "Example")
        assertElement("cleanup-review-output", in: app, doesNotContain: "[RETIRED_TEST]")
        assertElement("cleanup-review-output", in: app, doesNotContain: "ui-legacy-event")

        element("cleanup-review-cancel", in: app).click()
        waitUntilMissing(element("cleanup-review-title", in: app))
        assertElement(
            "operation-output", in: app, contains: "Cleanup review closed. No calendar mutations were performed.")
    }

    func testScheduledSyncAuthorizationPauseAndResume() {
        let app = launch(scenario: "ready")
        defer { app.terminate() }
        waitUntilEnabled(element("review-scheduled-sync", in: app))

        element("review-scheduled-sync", in: app).click()
        assertElement("standing-authorization-review-title", in: app, contains: "Authorize Scheduled Sync")
        element("standing-authorization-review-confirm", in: app).click()

        waitUntilEnabled(element("pause-scheduled-sync", in: app))
        assertElement("operation-output", in: app, contains: "standing authorization granted")
        element("pause-scheduled-sync", in: app).click()

        waitUntilEnabled(element("resume-scheduled-sync", in: app))
        assertElement("operation-output", in: app, contains: "Scheduled sync paused")
        element("resume-scheduled-sync", in: app).click()

        waitUntilEnabled(element("pause-scheduled-sync", in: app))
        assertElement("operation-output", in: app, contains: "Scheduled sync resumed")
        assertElement("notification-status", in: app, contains: "Disabled in the isolated UI-test host")
    }

    private func launch(scenario: String) -> XCUIApplication {
        let hostExists = FileManager.default.fileExists(atPath: Self.testHostURL.path)
        XCTAssertTrue(hostExists)
        let app = XCUIApplication(url: Self.testHostURL)
        var launchCompleted = false
        defer { if !launchCompleted { app.terminate() } }
        app.launchArguments = ["--calrelay-ui-testing", "--calrelay-ui-test-scenario", scenario]
        app.launch()
        let isRunning = app.wait(for: .runningForeground, timeout: 10)
        XCTAssertTrue(isRunning)
        let primaryStatusExists = element("primary-status", in: app).waitForExistence(timeout: 10)
        XCTAssertTrue(primaryStatusExists)
        launchCompleted = true
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func isEnabled(_ identifier: String, in app: XCUIApplication) -> Bool {
        element(identifier, in: app).isEnabled
    }

    private func assertElement(
        _ identifier: String, in app: XCUIApplication, contains text: String, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = element(identifier, in: app)
        let exists = element.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Missing element \(identifier)", file: file, line: line)
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }

    private func assertElement(
        _ identifier: String, in app: XCUIApplication, doesNotContain text: String, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = element(identifier, in: app)
        let exists = element.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Missing element \(identifier)", file: file, line: line)
        let value = element.value as? String ?? ""
        let containsText = (element.label + " " + value).localizedCaseInsensitiveContains(text)
        XCTAssertFalse(containsText, file: file, line: line)
    }

    private func waitUntilEnabled(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let exists = element.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Missing element \(element)", file: file, line: line)
        let becameEnabled = element.wait(for: \.isEnabled, toEqual: true, timeout: 10)
        XCTAssertTrue(becameEnabled, file: file, line: line)
    }

    private func waitUntilMissing(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let disappeared = element.waitForNonExistence(timeout: 10)
        XCTAssertTrue(disappeared, file: file, line: line)
    }

    private static let testHostURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/CalRelayUITestHost.app")
        .resolvingSymlinksInPath()
}
