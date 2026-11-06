import CalRelayKit

// APP-AC-18: problem visibility must not depend on the menu bar or notification permission.
enum CalendarAutomationAlertTests {
    static func runAll() async throws {
        try await testAvailableNotificationDoesNotOpenPanel()
        try await testUnavailableAndFailedNotificationsOpenPanel()
        try await testUnchangedProblemsCoalesceAndRecoveryAllowsNewAlert()
        try await testStartupAndPauseDoNotProduceRuntimeInterruptions()
        try await testDelayedAvailabilityCannotReopenRecoveredProblem()
        try await testLateQueuedUpdatesCannotReviveOldProblems()
    }

    private static func testAvailableNotificationDoesNotOpenPanel() async throws {
        let port = AlertPort(available: true)
        let alerts = CalendarAutomationAlertUseCase(port: port)
        await alerts.update(reason: .freshnessOverdue)
        let result = await port.result()
        try expect(
            result.notifications == [CalendarAutomationAttentionNotification(reason: .freshnessOverdue)],
            "Use fixed safe notification content")
        try expect(result.opens == 0, "A submitted notification must not also open the panel")
    }

    private static func testUnavailableAndFailedNotificationsOpenPanel() async throws {
        for available in [false, true] {
            let port = AlertPort(available: available, succeeds: false)
            let alerts = CalendarAutomationAlertUseCase(port: port)
            await alerts.update(reason: .calendarAccessUnavailable)
            let result = await port.result()
            try expect(result.opens == 1, "Unavailable alerts and failed submission must open recovery")
            try expect(result.notifications.count == (available ? 1 : 0), "Do not submit when alerts are unavailable")
        }
    }

    private static func testUnchangedProblemsCoalesceAndRecoveryAllowsNewAlert() async throws {
        let port = AlertPort(available: false)
        let alerts = CalendarAutomationAlertUseCase(port: port)
        await alerts.update(reason: .topologyNotReady)
        await alerts.update(reason: .topologyNotReady)
        try expect(await port.result().opens == 1, "Repeated unchanged status must not steal focus")
        await alerts.update(reason: nil)
        await alerts.update(reason: .topologyNotReady)
        let result = await port.result()
        try expect(result.opens == 2 && result.clears == 1, "Recovery clears the old alert and permits recurrence")
    }

    private static func testStartupAndPauseDoNotProduceRuntimeInterruptions() async throws {
        let port = AlertPort(available: false)
        let alerts = CalendarAutomationAlertUseCase(port: port)
        await alerts.update(reason: .standingAuthorizationRequired, runtimeAlertsEnabled: false)
        await alerts.update(reason: .standingAuthorizationRequired)
        await alerts.update(reason: .schedulingPaused)
        let result = await port.result()
        try expect(
            result.opens == 0 && result.notifications.isEmpty,
            "Startup recovery and deliberate pause use their own presentation rules")
    }

    private static func testDelayedAvailabilityCannotReopenRecoveredProblem() async throws {
        let port = AlertPort(available: true, suspendFirstAvailability: true)
        let alerts = CalendarAutomationAlertUseCase(port: port)
        let pending = Task { await alerts.update(reason: .freshnessOverdue) }
        await port.waitForAvailabilityRequest()
        await alerts.update(reason: nil)
        await port.resumeAvailability()
        await pending.value
        let result = await port.result()
        try expect(
            result.opens == 0 && result.notifications.isEmpty, "Obsolete asynchronous work must not revive recovery")
    }

    private static func testLateQueuedUpdatesCannotReviveOldProblems() async throws {
        let port = AlertPort(available: false)
        let alerts = CalendarAutomationAlertUseCase(port: port)
        await alerts.update(reason: nil, sequence: 2)
        await alerts.update(reason: .freshnessOverdue, sequence: 1)
        try expect(await port.result().opens == 0, "Late queued UI tasks must not revive an older problem")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private actor AlertPort: CalendarAutomationAlertPort {
    private let available: Bool
    private let succeeds: Bool
    private var notifications: [CalendarAutomationAttentionNotification] = []
    private var opens = 0
    private var clears = 0
    private var suspendFirstAvailability: Bool
    private var availabilityContinuation: CheckedContinuation<Bool, Never>?
    private var requestObserver: CheckedContinuation<Void, Never>?

    init(available: Bool, succeeds: Bool = true, suspendFirstAvailability: Bool = false) {
        self.available = available
        self.succeeds = succeeds
        self.suspendFirstAvailability = suspendFirstAvailability
    }

    func notificationsAvailable() async -> Bool {
        guard suspendFirstAvailability else { return available }
        suspendFirstAvailability = false
        return await withCheckedContinuation { continuation in
            availabilityContinuation = continuation
            requestObserver?.resume()
            requestObserver = nil
        }
    }
    func waitForAvailabilityRequest() async {
        guard availabilityContinuation == nil else { return }
        await withCheckedContinuation { requestObserver = $0 }
    }
    func resumeAvailability() {
        availabilityContinuation?.resume(returning: available)
        availabilityContinuation = nil
    }
    func submitNotification(_ notification: CalendarAutomationAttentionNotification) async -> Bool {
        notifications.append(notification)
        return succeeds
    }
    func clearNotification() async { clears += 1 }
    func openControlPanel() async { opens += 1 }
    func result() -> AlertResult { AlertResult(notifications: notifications, opens: opens, clears: clears) }
}

private struct AlertResult: Sendable {
    let notifications: [CalendarAutomationAttentionNotification]
    let opens: Int
    let clears: Int
}
