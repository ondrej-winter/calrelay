import CalRelayKit
import Foundation

enum CalendarLoginLaunchPolicyTests {
    private struct RecoveryCase {
        let controlPanelState: CalendarControlPanelPrimaryState
        let automationState: CalendarAutomationPersistentState
        let launchAtLoginHealthy: Bool
    }

    static func runAll() throws {
        try testOrdinaryLaunchAlwaysShowsControlPanel()
        try testHealthyAndActivelyRetryingLoginLaunchesStayHidden()
        try testDependencyOrderedRecoveryStatesShowControlPanel()
        try testActionableOperationOutcomesShowControlPanel()
        try testExhaustedFailureAndOverdueFreshnessShowControlPanel()
    }

    private static func testOrdinaryLaunchAlwaysShowsControlPanel() throws {
        let presentation = CalendarLoginLaunchPolicy().presentation(
            launchContext: .ordinary, controlPanelState: .ready, automationState: authorizedState(),
            launchAtLoginHealthy: true, now: now)

        try expect(
            presentation == .showControlPanel, "Ordinary Dock or Finder launches must keep the control panel visible")
    }

    private static func testHealthyAndActivelyRetryingLoginLaunchesStayHidden() throws {
        let policy = CalendarLoginLaunchPolicy()
        let healthy = policy.presentation(
            launchContext: .loginItem, controlPanelState: .ready, automationState: authorizedState(),
            launchAtLoginHealthy: true, now: now)
        let retrying = policy.presentation(
            launchContext: .loginItem, controlPanelState: .ready,
            automationState: authorizedState(
                status: status(
                    outcome: .transientFailure,
                    retryState: .scheduled(attempt: 1, nextAttemptAt: now.addingTimeInterval(60)))),
            launchAtLoginHealthy: true, now: now)
        let partialRetry = policy.presentation(
            launchContext: .loginItem, controlPanelState: .ready,
            automationState: authorizedState(
                status: status(
                    outcome: .partialMutation,
                    retryState: .scheduled(attempt: 2, nextAttemptAt: now.addingTimeInterval(5 * 60)))),
            launchAtLoginHealthy: true, now: now)

        try expect(healthy == .keepControlPanelHidden, "A healthy login launch should remain unobtrusive")
        try expect(
            retrying == .keepControlPanelHidden,
            "A bounded retry with otherwise fresh state should not demand immediate user action")
        try expect(
            partialRetry == .keepControlPanelHidden,
            "A bounded partial-mutation retry with otherwise fresh state should remain unobtrusive")
    }

    private static func testDependencyOrderedRecoveryStatesShowControlPanel() throws {
        let policy = CalendarLoginLaunchPolicy()
        let cases = [
            RecoveryCase(
                controlPanelState: .configurationMissing, automationState: authorizedState(), launchAtLoginHealthy: true
            ),
            RecoveryCase(
                controlPanelState: .configurationInvalid, automationState: authorizedState(), launchAtLoginHealthy: true
            ),
            RecoveryCase(
                controlPanelState: .calendarAccessUnavailable(.denied), automationState: authorizedState(),
                launchAtLoginHealthy: true),
            RecoveryCase(
                controlPanelState: .topologyNotReady, automationState: authorizedState(), launchAtLoginHealthy: true),
            RecoveryCase(
                controlPanelState: .migrationPending, automationState: authorizedState(), launchAtLoginHealthy: true),
            RecoveryCase(
                controlPanelState: .ready, automationState: state(standingAuthorization: nil),
                launchAtLoginHealthy: true),
            RecoveryCase(controlPanelState: .ready, automationState: authorizedState(), launchAtLoginHealthy: false),
            RecoveryCase(
                controlPanelState: .ready, automationState: state(schedulingPreference: .disabled),
                launchAtLoginHealthy: true),
            RecoveryCase(
                controlPanelState: .ready, automationState: state(schedulingPreference: .paused),
                launchAtLoginHealthy: true)
        ]

        for recoveryCase in cases {
            let presentation = policy.presentation(
                launchContext: .loginItem, controlPanelState: recoveryCase.controlPanelState,
                automationState: recoveryCase.automationState, launchAtLoginHealthy: recoveryCase.launchAtLoginHealthy,
                now: now)
            try expect(
                presentation == .showControlPanel,
                "A login launch with setup or recovery work should show the control panel")
        }
    }

    private static func testActionableOperationOutcomesShowControlPanel() throws {
        let policy = CalendarLoginLaunchPolicy()
        let outcomes: [CalendarAutomationOutcomeCategory] = [
            .configurationUnavailable, .migrationPending, .calendarAccessUnavailable, .topologyNotReady,
            .standingAuthorizationRequired
        ]

        for outcome in outcomes {
            let presentation = policy.presentation(
                launchContext: .loginItem, controlPanelState: .ready,
                automationState: authorizedState(status: status(outcome: outcome)), launchAtLoginHealthy: true, now: now
            )
            try expect(
                presentation == .showControlPanel,
                "A persisted actionable automatic outcome should open login-launch recovery")
        }
    }

    private static func testExhaustedFailureAndOverdueFreshnessShowControlPanel() throws {
        let policy = CalendarLoginLaunchPolicy()
        let exhaustedPartial = policy.presentation(
            launchContext: .loginItem, controlPanelState: .ready,
            automationState: authorizedState(status: status(outcome: .partialMutation)), launchAtLoginHealthy: true,
            now: now)
        let exhaustedTransient = policy.presentation(
            launchContext: .loginItem, controlPanelState: .ready,
            automationState: authorizedState(status: status(outcome: .transientFailure)), launchAtLoginHealthy: true,
            now: now)
        let overdue = policy.presentation(
            launchContext: .loginItem, controlPanelState: .ready,
            automationState: authorizedState(status: status(lastSuccessAt: now.addingTimeInterval(-(60 * 60) - 1))),
            launchAtLoginHealthy: true, now: now)

        try expect(exhaustedPartial == .showControlPanel, "An exhausted partial failure should open recovery")
        try expect(exhaustedTransient == .showControlPanel, "An exhausted transient failure should open recovery")
        try expect(overdue == .showControlPanel, "Overdue freshness should open recovery")
    }

    private static let now = Date(timeIntervalSince1970: 10_000)

    private static func authorizedState(status: CalendarAutomationOperationalStatus = status())
        -> CalendarAutomationPersistentState
    { state(standingAuthorization: authorizationBinding(), status: status) }

    private static func state(
        schedulingPreference: CalendarSchedulingPreference = .enabled,
        standingAuthorization: CalendarStandingAuthorizationBinding? = authorizationBinding(),
        status: CalendarAutomationOperationalStatus = status()
    ) -> CalendarAutomationPersistentState {
        CalendarAutomationPersistentState(
            schedulingPreference: schedulingPreference, standingAuthorization: standingAuthorization,
            operationalStatus: status)
    }

    private static func status(
        outcome: CalendarAutomationOutcomeCategory = .applied, retryState: CalendarAutomationRetryState = .none,
        lastSuccessAt: Date? = now.addingTimeInterval(-30 * 60)
    ) -> CalendarAutomationOperationalStatus {
        CalendarAutomationOperationalStatus(
            lastAttemptAt: now.addingTimeInterval(-5 * 60), latestOutcome: outcome, confirmedCounts: .zero,
            retryState: retryState,
            freshness: CalendarAutomationFreshnessMetadata(
                lastSuccessAt: lastSuccessAt, nextNominalRunAt: now.addingTimeInterval(10 * 60)))
    }

    private static func authorizationBinding() -> CalendarStandingAuthorizationBinding {
        CalendarStandingAuthorizationBinding.derive(
            settings: CalendarRelaySettings(
                hubCalendar: HubCalendarSettings(
                    calendar: CalendarSelector(sourceTitle: "Test Source", calendarTitle: "Test Hub")),
                personalPrefix: "[ME]", syncWindowDays: 1, workCalendars: [], legacyMarkers: []),
            resolvedCalendars: [PhysicalCalendarReference(providerIdentifier: "test-hub")], policyVersion: .current)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
