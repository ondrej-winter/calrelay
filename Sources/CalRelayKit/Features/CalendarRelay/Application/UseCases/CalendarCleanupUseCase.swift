import Foundation

public enum CalendarCleanupError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidSettings(String)
    case legacyMarkersRequired
    case preflightFailed([CalendarAccessPreflightIssue])
    case mutationFailed(CalendarMutationPartialResult)
    case verificationFailed([CalendarAccessPreflightIssue])
    case verificationFoundRemainingMatches(count: Int)

    public var description: String {
        switch self {
        case .invalidSettings(let message): "Invalid cleanup configuration: \(message)"
        case .legacyMarkersRequired: "Legacy cleanup requires at least one configured legacy marker."
        case .preflightFailed(let issues):
            "Cleanup preflight failed:\n" + issues.map(\.description).joined(separator: "\n")
        case .mutationFailed(let partial):
            "Legacy cleanup was partially applied.\n" + CalendarMutationExecutionError.partial(partial).description
        case .verificationFailed(let issues):
            "Cleanup verification failed after confirmed deletions remained applied:\n"
                + issues.map(\.description).joined(separator: "\n")
        case .verificationFoundRemainingMatches(let count):
            "Cleanup verification found \(count) remaining matching event(s). Confirmed deletions remain applied; repeat cleanup after resolving the current state."
        }
    }
}

public struct CalendarCleanupApplyResult: Equatable, Sendable {
    public let plan: CalendarCleanupPlan
    public let confirmedDeletionCount: Int

    public init(plan: CalendarCleanupPlan, confirmedDeletionCount: Int) {
        self.plan = plan
        self.confirmedDeletionCount = confirmedDeletionCount
    }
}

public struct CalendarCleanupUseCase: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort
    private let calendar: Calendar

    public init(
        authorizationStatus: any CalendarAuthorizationStatusPort, calendarStore: any CalendarStorePort,
        calendar: Calendar = .current
    ) {
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
        self.calendar = calendar
    }

    public func dryRun(settings: CalendarRelaySettings, now: Date) async throws -> CalendarCleanupPlan {
        let snapshot = try await loadCleanupSnapshot(settings: settings, now: now, verification: false)
        return CalendarCleanupPlanner.plan(snapshot: snapshot, legacyMarkers: Set(settings.legacyMarkers))
    }

    public func apply(
        settings: CalendarRelaySettings, now: Date,
        onPlanReady: @escaping @Sendable (CalendarCleanupPlan) async -> Void = { _ in },
        authorizePlan: @escaping @Sendable (CalendarCleanupPlan) async throws -> Void = { _ in },
        onConfirmation: @escaping @Sendable (CalendarMutationConfirmation) async -> Void = { _ in }
    ) async throws -> CalendarCleanupApplyResult {
        let snapshot = try await loadCleanupSnapshot(settings: settings, now: now, verification: false)
        let markers = Set(settings.legacyMarkers)
        let plan = CalendarCleanupPlanner.plan(snapshot: snapshot, legacyMarkers: markers)
        await onPlanReady(plan)
        // App confirmation may veto this exact fresh plan. Do not replan after authorization.
        try await authorizePlan(plan)
        try Task.checkCancellation()
        let actions = plan.deletions.map { deletion in
            CalendarMutationAction.delete(role: deletion.role, event: deletion.event)
        }
        let mutationResult: CalendarMutationExecutionResult
        do {
            mutationResult = try await CalendarMutationExecutor(calendarStore: calendarStore).execute(
                actions, onConfirmation: onConfirmation)
        } catch let error as CalendarMutationExecutionError {
            switch error {
            case .partial(let partial): throw CalendarCleanupError.mutationFailed(partial)
            }
        }

        let verificationSnapshot = try await loadCleanupSnapshot(settings: settings, now: now, verification: true)
        let remainingCount = CalendarCleanupPlanner.matchingEventCount(
            snapshot: verificationSnapshot, legacyMarkers: markers)
        guard remainingCount == 0 else {
            throw CalendarCleanupError.verificationFoundRemainingMatches(count: remainingCount)
        }

        return CalendarCleanupApplyResult(plan: plan, confirmedDeletionCount: mutationResult.confirmedActionCount)
    }

    private func loadCleanupSnapshot(settings: CalendarRelaySettings, now: Date, verification: Bool) async throws
        -> CalendarAccessPreflightSnapshot
    {
        do { try SettingsValidator.validate(settings) } catch let error as SettingsValidationError {
            throw CalendarCleanupError.invalidSettings(error.description)
        }
        guard !settings.legacyMarkers.isEmpty else { throw CalendarCleanupError.legacyMarkersRequired }

        let window = LegacyCleanupWindow.calculate(referenceDate: now, calendar: calendar)
        let result = try await CalendarAccessPreflightUseCase(
            authorizationStatus: authorizationStatus, calendarStore: calendarStore
        ).run(settings: settings, window: window)
        switch result {
        case .ready(let snapshot): return snapshot
        case .failed(let issues):
            if verification { throw CalendarCleanupError.verificationFailed(issues) }
            throw CalendarCleanupError.preflightFailed(issues)
        }
    }
}
