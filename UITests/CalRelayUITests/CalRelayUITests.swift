import AppKit
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

    func testReviewSheetsCanBeCancelledWithEscapeWithoutMutation() {
        let manualApp = launch(scenario: "ready")
        waitUntilEnabled(element("run-sync-now", in: manualApp))
        element("run-sync-now", in: manualApp).click()
        assertElement("manual-review-title", in: manualApp, contains: "Review Sync Plan")

        manualApp.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        waitUntilMissing(element("manual-review-title", in: manualApp))
        assertElement(
            "operation-output", in: manualApp, contains: "Sync review cancelled. No calendar mutations were performed.")
        manualApp.terminate()

        let cleanupApp = launch(scenario: "migration-pending")
        defer { cleanupApp.terminate() }
        waitUntilEnabled(element("run-legacy-cleanup", in: cleanupApp))
        element("run-legacy-cleanup", in: cleanupApp).click()
        assertElement("cleanup-review-title", in: cleanupApp, contains: "Review Legacy Cleanup")

        cleanupApp.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        waitUntilMissing(element("cleanup-review-title", in: cleanupApp))
        assertElement(
            "operation-output", in: cleanupApp, contains: "Cleanup review closed. No calendar mutations were performed."
        )
    }

    func testManualSyncReviewIsDisposedAfterCompletionAndFailure() {
        let successfulApp = launch(scenario: "ready")
        waitUntilEnabled(element("run-sync-now", in: successfulApp))
        element("run-sync-now", in: successfulApp).click()
        assertElement("manual-review-title", in: successfulApp, contains: "Review Sync Plan")
        element("manual-review-confirm", in: successfulApp).click()
        waitUntilMissing(element("manual-review-title", in: successfulApp))
        assertElement("operation-output", in: successfulApp, contains: "Sync completed")
        successfulApp.terminate()

        let failingApp = launch(scenario: "manual-apply-failure")
        defer { failingApp.terminate() }
        waitUntilEnabled(element("run-sync-now", in: failingApp))
        element("run-sync-now", in: failingApp).click()
        assertElement("manual-review-title", in: failingApp, contains: "Review Sync Plan")
        element("manual-review-confirm", in: failingApp).click()
        waitUntilMissing(element("manual-review-title", in: failingApp))
        assertElement("operation-output", in: failingApp, contains: "Sync partially applied")
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

    func testCleanupReviewIsDisposedAfterCompletionAndFailure() {
        let successfulApp = launch(scenario: "migration-pending")
        waitUntilEnabled(element("run-legacy-cleanup", in: successfulApp))
        element("run-legacy-cleanup", in: successfulApp).click()
        assertElement("cleanup-review-title", in: successfulApp, contains: "Review Legacy Cleanup")
        element("cleanup-review-confirm", in: successfulApp).click()
        waitUntilMissing(element("cleanup-review-title", in: successfulApp))
        assertElement("operation-output", in: successfulApp, contains: "Cleanup verified")
        successfulApp.terminate()

        let failingApp = launch(scenario: "cleanup-apply-failure")
        defer { failingApp.terminate() }
        waitUntilEnabled(element("run-legacy-cleanup", in: failingApp))
        element("run-legacy-cleanup", in: failingApp).click()
        assertElement("cleanup-review-title", in: failingApp, contains: "Review Legacy Cleanup")
        element("cleanup-review-confirm", in: failingApp).click()
        waitUntilMissing(element("cleanup-review-title", in: failingApp))
        assertElement("operation-output", in: failingApp, contains: "Cleanup unsuccessful")
    }

    func testTransientReviewsAreNotRestoredAfterRelaunch() {
        let manualApp = launch(scenario: "ready")
        waitUntilEnabled(element("run-sync-now", in: manualApp))
        element("run-sync-now", in: manualApp).click()
        assertElement("manual-review-title", in: manualApp, contains: "Review Sync Plan")
        manualApp.terminate()

        let relaunchedManualApp = launch(scenario: "ready")
        XCTAssertFalse(element("manual-review-title", in: relaunchedManualApp).waitForExistence(timeout: 1))
        waitUntilEnabled(element("run-sync-now", in: relaunchedManualApp))
        relaunchedManualApp.terminate()

        let cleanupApp = launch(scenario: "migration-pending")
        waitUntilEnabled(element("run-legacy-cleanup", in: cleanupApp))
        element("run-legacy-cleanup", in: cleanupApp).click()
        assertElement("cleanup-review-title", in: cleanupApp, contains: "Review Legacy Cleanup")
        cleanupApp.terminate()

        let relaunchedCleanupApp = launch(scenario: "migration-pending")
        defer { relaunchedCleanupApp.terminate() }
        XCTAssertFalse(element("cleanup-review-title", in: relaunchedCleanupApp).waitForExistence(timeout: 1))
        waitUntilEnabled(element("run-legacy-cleanup", in: relaunchedCleanupApp))
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
        assertElement("notification-status", in: app, contains: "Denied. Scheduling remains available")
        assertElement("automation-attention-status", in: app, contains: "within the last hour")
    }

    func testMenuStatusKeepsDisabledSchedulingVisibleWithPanelClosed() {
        let app = launch(scenario: "ready")
        defer { app.terminate() }
        assertElement("scheduling-status", in: app, contains: "Disabled")
        app.windows["calrelay-control-panel"].buttons[XCUIIdentifierCloseWindow].click()
        waitUntilMissing(app.windows["calrelay-control-panel"])
        let system = openStatusMenu(in: app)
        let title = "Disabled until scheduled sync is explicitly authorized."
        let local = app.menuItems[title]
        let status = local.waitForExistence(timeout: 2) ? local : system.menuItems[title]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
    }

    func testRuntimeAlertRoutingWorksWithControlPanelClosed() {
        for mode in ["available", "denied", "failed"] {
            let app = launch(scenario: "ready", notificationMode: mode)
            defer { app.terminate() }
            waitUntilEnabled(element("pause-scheduled-sync", in: app))
            let panel = app.windows["calrelay-control-panel"]
            panel.buttons[XCUIIdentifierCloseWindow].click()
            let item = statusItem(in: app)
            let submitted = mode == "denied" ? 0 : 1
            let opened = mode == "available" ? 0 : 1
            let expected = "Test submissions: \(submitted); recovery opens: \(opened)"
            expectation(for: NSPredicate(format: "label CONTAINS %@", expected), evaluatedWith: item)
            waitForExpectations(timeout: 10)
            if opened == 1 {
                XCTAssertTrue(panel.waitForExistence(timeout: 10))
                assertElement("primary-status", in: app, contains: "overdue")
            } else {
                XCTAssertFalse(panel.exists)
            }
        }
    }

    func testHealthyLoginStartsWithoutOpeningControlPanel() async throws {
        let app = XCUIApplication(url: Self.testHostURL)
        app.launchArguments = ["--calrelay-ui-testing", "--calrelay-ui-test-scenario", "healthy-login"]
        app.launch()
        defer { app.terminate() }
        XCTAssertNotEqual(app.state, .notRunning)
        XCTAssertFalse(app.windows["calrelay-control-panel"].exists)
        _ = try await NSWorkspace.shared.openApplication(at: Self.testHostURL, configuration: .init())
        assertElement("configuration-status", in: app, contains: "Valid:")
        assertElement("scheduling-status", in: app, contains: "Enabled")
    }

    func testMenuBarRecoversClosedPanelWithoutDuplicates() {
        let app = launch(scenario: "ready")
        defer { app.terminate() }
        let panel = app.windows["calrelay-control-panel"]
        panel.buttons[XCUIIdentifierCloseWindow].click()
        waitUntilMissing(panel)
        XCTAssertNotEqual(app.state, .notRunning)
        let system = openStatusMenu(in: app)
        let localOpen = app.menuItems["Open CalRelay"]
        let open = localOpen.waitForExistence(timeout: 2) ? localOpen : system.menuItems["Open CalRelay"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.click()
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        XCTAssertEqual(app.windows.matching(identifier: "calrelay-control-panel").count, 1)
        assertElement("configuration-status", in: app, contains: "Valid:")
    }

    private func statusItem(in app: XCUIApplication) -> XCUIElement {
        let system = XCUIApplication(bundleIdentifier: "com.apple.controlcenter")
        let localItem = app.descendants(matching: .any)["calrelay-status-item"]
        let item =
            localItem.waitForExistence(timeout: 2)
            ? localItem : system.descendants(matching: .any)["calrelay-status-item"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        return item
    }

    private func openStatusMenu(in app: XCUIApplication) -> XCUIApplication {
        statusItem(in: app).click()
        return XCUIApplication(bundleIdentifier: "com.apple.controlcenter")
    }

    private func launch(scenario: String, notificationMode: String? = nil) -> XCUIApplication {
        let hostExists = FileManager.default.fileExists(atPath: Self.testHostURL.path)
        XCTAssertTrue(hostExists)
        let app = XCUIApplication(url: Self.testHostURL)
        var launchCompleted = false
        defer { if !launchCompleted { app.terminate() } }
        app.launchArguments = ["--calrelay-ui-testing", "--calrelay-ui-test-scenario", scenario]
        if let notificationMode { app.launchArguments += ["--calrelay-ui-test-notifications", notificationMode] }
        app.launch()
        XCTAssertNotEqual(app.state, .notRunning)
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
