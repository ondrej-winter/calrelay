import Foundation

public enum ReconcileCommandError: Error, Equatable, CustomStringConvertible, Sendable {
    case migrationPending

    public var description: String {
        switch self {
        case .migrationPending:
            "Ordinary reconciliation is blocked while legacyMarkers is nonempty. Run explicit legacy cleanup first."
        }
    }
}

public struct ReconcileCommandHandler: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        authorizationStatus: any CalendarAuthorizationStatusPort, calendarStore: any CalendarStorePort,
        now: @escaping @Sendable () -> Date = Date.init, calendar: Calendar = .current
    ) {
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
        self.now = now
        self.calendar = calendar
    }

    public func run(
        config: String?, apply: Bool, explain: Bool, cleanupLegacy: Bool,
        onOutput: @escaping @Sendable (String) async -> Void = { _ in }
    ) async throws -> String {
        let selectedFile = try ConfigurationFileSelection.select(overridePath: config)
        let yaml = try String(contentsOfFile: selectedFile.path, encoding: .utf8)
        let settings = try YAMLCalendarRelaySettingsLoader.load(yaml)
        let currentDate = now()

        if cleanupLegacy {
            let cleanupWindow = LegacyCleanupWindow.calculate(referenceDate: currentDate, calendar: calendar)
            let cleanup = CalendarCleanupUseCase(
                authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)
            if apply {
                let result = try await cleanup.apply(
                    settings: settings, now: currentDate,
                    onPlanReady: { plan in
                        await onOutput(CalendarCleanupFormatter.formatFreshApplyPlan(plan, window: cleanupWindow))
                    },
                    onConfirmation: { confirmation in
                        await onOutput(CalendarMutationConfirmationFormatter.format(confirmation))
                    })
                return CalendarCleanupFormatter.formatVerifiedSuccess(result)
            }

            let plan = try await cleanup.dryRun(settings: settings, now: currentDate)
            return CalendarCleanupFormatter.formatDryRun(plan, window: cleanupWindow)
        }

        guard settings.legacyMarkers.isEmpty else { throw ReconcileCommandError.migrationPending }
        let useCase = ReconcileCalendarsUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)

        if explain {
            let explanation = try await useCase.explain(settings: settings, now: currentDate)
            return EventExplanationFormatter.format(explanation)
        }

        let result: OrdinaryReconciliationResult
        if apply {
            result = try await useCase.applyResult(
                settings: settings, now: currentDate,
                onConfirmation: { confirmation in
                    await onOutput(CalendarMutationConfirmationFormatter.format(confirmation))
                })
        } else {
            result = try await useCase.dryRunResult(settings: settings, now: currentDate)
        }
        let modeMessage =
            apply
            ? "Apply mode. Planned calendar mutations were performed."
            : "Dry-run mode. No calendar mutations were performed."

        return [modeMessage, ReconciliationPlanFormatter.format(result)].joined(separator: "\n")
    }
}
