import CalRelayKit
import Foundation

enum CalendarAutomationCoordinationTests {
    static func runAll() async throws {
        try testAutomaticTriggersCoalesceBehindActiveWork()
        try testConfigurationRecoveryPrecedesCoalescedAutomaticWork()
        try testManualWorkCannotOverlapActiveWork()
        try testFixedCadenceAndFreshnessPolicy()
        try testTransientRetriesAreFiniteAndBounded()
        try testAttentionPolicyDistinguishesActionableRetryAndOverdueState()
        try testNotificationContentIsFixedAndPrivacySafe()
        try await testStateUpdatesPreserveAuthorizationAndOperationHistory()
    }

    private static func testAutomaticTriggersCoalesceBehindActiveWork() throws {
        var coordinator = CalendarAppOperationCoordinator()

        try expect(
            coordinator.request(.manualApply) == .start,
            "Manual ordinary work should start when the app coordinator is idle")
        try expect(
            coordinator.request(.automaticReconciliation) == .coalesced,
            "An automatic trigger during active work should coalesce")
        try expect(
            coordinator.request(.automaticReconciliation) == .coalesced,
            "Repeated automatic triggers should remain one follow-up")
        try expect(
            coordinator.finish() == .automaticReconciliation,
            "Finishing active work should start one fresh automatic follow-up")
        try expect(coordinator.finish() == nil, "The coalesced automatic follow-up should run only once")
    }

    private static func testConfigurationRecoveryPrecedesCoalescedAutomaticWork() throws {
        var coordinator = CalendarAppOperationCoordinator()

        _ = coordinator.request(.automaticReconciliation)
        try expect(
            coordinator.request(.configurationRecovery) == .coalesced,
            "A selected-file change must not interrupt an active automatic attempt")
        try expect(
            coordinator.request(.automaticReconciliation) == .coalesced,
            "A later trigger should remain pending behind configuration recovery")
        try expect(
            coordinator.finish() == .configurationRecovery,
            "Configuration recovery should run before later automatic work")
        try expect(
            coordinator.finish() == .automaticReconciliation,
            "One later automatic trigger should run after recovery")
        try expect(coordinator.finish() == nil, "Recovery and automatic follow-up should both drain")
    }

    private static func testManualWorkCannotOverlapActiveWork() throws {
        var coordinator = CalendarAppOperationCoordinator()

        _ = coordinator.request(.cleanup)

        try expect(
            coordinator.request(.manualDryRun) == .rejected,
            "A second manual workflow must not overlap cleanup")
        try expect(coordinator.activeOperation == .cleanup, "Rejected work must not replace the active operation")
    }

    private static func testFixedCadenceAndFreshnessPolicy() throws {
        let policy = CalendarAutomationSchedulingPolicy()
        let start = Date(timeIntervalSince1970: 1_000)

        try expect(
            policy.nextNominalRun(after: start) == start.addingTimeInterval(15 * 60),
            "Automatic cadence should be fixed at 15 minutes")
        try expect(
            policy.nextNominalRun(after: start, previousNominalRun: start.addingTimeInterval(15 * 60))
                == start.addingTimeInterval(30 * 60),
            "Advancing a nominal timer should preserve the fixed cadence")
        try expect(
            !policy.isFreshnessOverdue(
                schedulingPreference: .enabled, lastSuccessAt: start, now: start.addingTimeInterval(60 * 60)),
            "Freshness should not be overdue at exactly 60 minutes")
        try expect(
            policy.isFreshnessOverdue(
                schedulingPreference: .enabled, lastSuccessAt: start,
                now: start.addingTimeInterval((60 * 60) + 1)),
            "Freshness should be overdue after 60 minutes")
        try expect(
            !policy.isFreshnessOverdue(schedulingPreference: .paused, lastSuccessAt: nil, now: start),
            "Paused scheduling should remain degraded as paused rather than overdue")
    }

    private static func testTransientRetriesAreFiniteAndBounded() throws {
        let policy = CalendarAutomationSchedulingPolicy()
        let now = Date(timeIntervalSince1970: 5_000)

        let first = policy.nextRetry(after: .transientFailure, previousRetry: .none, now: now)
        let second = policy.nextRetry(after: .transientFailure, previousRetry: first, now: now)
        let third = policy.nextRetry(after: .partialMutation, previousRetry: second, now: now)
        let exhausted = policy.nextRetry(after: .transientFailure, previousRetry: third, now: now)

        try expect(first == .scheduled(attempt: 1, nextAttemptAt: now.addingTimeInterval(60)), "Retry one")
        try expect(second == .scheduled(attempt: 2, nextAttemptAt: now.addingTimeInterval(5 * 60)), "Retry two")
        try expect(third == .scheduled(attempt: 3, nextAttemptAt: now.addingTimeInterval(15 * 60)), "Retry three")
        try expect(exhausted == .none, "Retry series should stop after three bounded attempts")
        try expect(
            policy.nextRetry(after: .calendarAccessUnavailable, previousRetry: .none, now: now) == .none,
            "Failures requiring user action should not enter an aggressive retry loop")
    }

    private static func testAttentionPolicyDistinguishesActionableRetryAndOverdueState() throws {
        let policy = CalendarAutomationAttentionPolicy()
        let now = Date(timeIntervalSince1970: 10_000)

        try expect(
            policy.reason(
                schedulingPreference: .enabled, hasStandingAuthorization: false,
                launchAtLoginHealthy: true, operationalStatus: .empty, now: now)
                == .standingAuthorizationRequired,
            "Missing authorization should require attention")
        let retrying = CalendarAutomationOperationalStatus(
            lastAttemptAt: now, latestOutcome: .transientFailure, confirmedCounts: .zero,
            retryState: .scheduled(attempt: 1, nextAttemptAt: now.addingTimeInterval(60)),
            freshness: CalendarAutomationFreshnessMetadata(lastSuccessAt: now, nextNominalRunAt: nil))
        try expect(
            policy.reason(
                schedulingPreference: .enabled, hasStandingAuthorization: true,
                launchAtLoginHealthy: true, operationalStatus: retrying, now: now) == nil,
            "An active bounded retry should not be mislabeled as requiring user action")
        let exhausted = CalendarAutomationOperationalStatus(
            lastAttemptAt: now, latestOutcome: .partialMutation,
            confirmedCounts: CalendarAutomationMutationCounts(confirmedCreates: 0, confirmedDeletes: 1),
            retryState: .none,
            freshness: CalendarAutomationFreshnessMetadata(lastSuccessAt: now, nextNominalRunAt: nil))
        try expect(
            policy.reason(
                schedulingPreference: .enabled, hasStandingAuthorization: true,
                launchAtLoginHealthy: true, operationalStatus: exhausted, now: now) == .partialMutation,
            "An exhausted partial mutation should require attention")
        let overdue = CalendarAutomationOperationalStatus(
            lastAttemptAt: now, latestOutcome: .applied, confirmedCounts: .zero, retryState: .none,
            freshness: CalendarAutomationFreshnessMetadata(
                lastSuccessAt: now.addingTimeInterval(-(60 * 60) - 1), nextNominalRunAt: nil))
        try expect(
            policy.reason(
                schedulingPreference: .enabled, hasStandingAuthorization: true,
                launchAtLoginHealthy: true, operationalStatus: overdue, now: now) == .freshnessOverdue,
            "Successful history should still require attention once freshness is overdue")
        try expect(
            policy.reason(
                schedulingPreference: .enabled, hasStandingAuthorization: true,
                launchAtLoginHealthy: false, operationalStatus: overdue, now: now) == .launchAtLoginUnavailable,
            "Launch-at-login recovery should precede freshness")
    }

    private static func testNotificationContentIsFixedAndPrivacySafe() throws {
        let expectations: [(CalendarAutomationAttentionReason, String)] = [
            (.schedulingPaused, "Scheduled sync is paused."),
            (.standingAuthorizationRequired, "Review a fresh dry run and renew scheduled sync authorization."),
            (.launchAtLoginUnavailable, "Enable or approve CalRelay in Login Items."),
            (.configurationUnavailable, "Restore or fix the canonical configuration file."),
            (.migrationPending, "Complete explicit legacy cleanup before scheduled sync can resume."),
            (.calendarAccessUnavailable, "Restore full Calendar access in the CalRelay control panel."),
            (.topologyNotReady, "Resolve the configured calendar readiness issue."),
            (.partialMutation, "A scheduled run partially applied and bounded retries are exhausted."),
            (.transientFailure, "Scheduled sync retries are exhausted after a transient failure."),
            (.freshnessOverdue, "No successful ordinary reconciliation has completed within the last hour.")
        ]

        for (reason, expectedBody) in expectations {
            let content = CalendarAutomationAttentionNotification(reason: reason)
            try expect(content.title == "CalRelay needs attention", "Notification title should be fixed safe copy")
            try expect(content.body == expectedBody, "Notification body should depend only on the safe reason category")
        }
    }

    private static func testStateUpdatesPreserveAuthorizationAndOperationHistory() async throws {
        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: CalendarRelaySettings(
                hubCalendar: HubCalendarSettings(
                    calendar: CalendarSelector(sourceTitle: "Account", calendarTitle: "Hub")),
                personalPrefix: "[ME]", syncWindowDays: 1, workCalendars: [], legacyMarkers: []),
            resolvedCalendars: [PhysicalCalendarReference(providerIdentifier: "hub")], policyVersion: .current)
        let status = CalendarAutomationOperationalStatus(
            lastAttemptAt: Date(timeIntervalSince1970: 100), latestOutcome: .applied,
            confirmedCounts: CalendarAutomationMutationCounts(confirmedCreates: 2, confirmedDeletes: 1),
            retryState: .none,
            freshness: CalendarAutomationFreshnessMetadata(
                lastSuccessAt: Date(timeIntervalSince1970: 100), nextNominalRunAt: nil))
        let store = CoordinationStateStore(
            state: CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: binding, operationalStatus: status))
        let useCase = CalendarAutomationStateUseCase(stateStore: store)
        let nextRun = Date(timeIntervalSince1970: 1_000)

        try await useCase.setSchedulingPreference(.paused)
        try await useCase.setNextNominalRunAt(nextRun)

        let persisted = await useCase.loadState()
        try expect(persisted.schedulingPreference == .paused, "Pause should persist")
        try expect(persisted.standingAuthorization == binding, "Pause must preserve standing authorization")
        try expect(persisted.operationalStatus.latestOutcome == .applied, "Pause must preserve operation history")
        try expect(
            persisted.operationalStatus.freshness.nextNominalRunAt == nextRun,
            "Nominal timer metadata should update independently")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private actor CoordinationStateStore: CalendarAutomationStateStore {
    private var state: CalendarAutomationPersistentState

    init(state: CalendarAutomationPersistentState) { self.state = state }

    func loadState() async -> CalendarAutomationPersistentState { state }
    func saveState(_ state: CalendarAutomationPersistentState) async throws { self.state = state }
    func updateState(
        _ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState
    ) async throws -> CalendarAutomationPersistentState {
        state = transform(state)
        return state
    }
}