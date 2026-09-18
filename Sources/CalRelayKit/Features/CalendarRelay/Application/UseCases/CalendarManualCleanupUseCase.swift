import Foundation

/// Cleanup authorization is independent of ordinary manual or standing authorization.
public actor CalendarManualCleanupUseCase {
    private let settingsProvider: any CalendarRelaySettingsProvider
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort
    private let now: @Sendable () -> Date
    private let calendar: @Sendable () -> Calendar
    private var pending: PendingCleanupReview?
    private var isRunning = false
    private var confirmedDeletions = 0

    public init(settingsProvider: any CalendarRelaySettingsProvider, authorizationStatus: any CalendarAuthorizationStatusPort,
        calendarStore: any CalendarStorePort, now: @escaping @Sendable () -> Date = Date.init,
        calendar: @escaping @Sendable () -> Calendar = { .current }
    ) {
        self.settingsProvider = settingsProvider
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
        self.now = now
        self.calendar = calendar
    }

    public func review() async throws -> CalendarManualCleanupReview {
        guard !isRunning else { throw CalendarManualCleanupError.operationInProgress }
        isRunning = true
        pending = nil
        confirmedDeletions = 0
        defer { isRunning = false }
        let reference = now()
        let calendar = calendar()
        do {
            let settings = try await settingsProvider.loadSettings().settings
            let plan = try await cleanup(calendar: calendar).dryRun(settings: settings, now: reference)
            try Task.checkCancellation()
            return remember(plan, settings: settings, reference: reference, calendar: calendar)
        } catch { throw safeFailure(error) }
    }

    public func cancelReview() {
        guard !isRunning else { return }
        pending = nil
    }

    public func confirm(reviewID: UUID) async throws -> CalendarManualCleanupOutcome {
        guard !isRunning else { throw CalendarManualCleanupError.operationInProgress }
        guard let reviewed = pending, reviewed.review.id == reviewID else { throw CalendarManualCleanupError.reviewRequired }
        isRunning = true
        pending = nil
        confirmedDeletions = 0
        defer { isRunning = false }
        let reference = now()
        let calendar = calendar()
        do {
            let settings = try await settingsProvider.loadSettings().settings
            let result = try await cleanup(calendar: calendar).apply(settings: settings, now: reference,
                authorizePlan: { plan in
                    try await self.authorize(plan, reviewed: reviewed, settings: settings, reference: reference, calendar: calendar)
                }, onConfirmation: { _ in await self.recordDeletion() })
            return .applied(confirmedDeletions: result.confirmedDeletionCount)
        } catch let changed as CleanupReconfirmation {
            return .reviewRequired(changed.review)
        } catch { throw safeFailure(error) }
    }

    private func authorize(_ plan: CalendarCleanupPlan, reviewed: PendingCleanupReview, settings: CalendarRelaySettings,
        reference: Date, calendar: Calendar
    ) async throws {
        try Task.checkCancellation()
        guard reviewed.identities == identities(plan),
            reviewed.configuration == OrdinaryConfigurationMutationIdentity(settings),
            reviewed.review.window == LegacyCleanupWindow.calculate(referenceDate: reference, calendar: calendar)
        else { throw CleanupReconfirmation(review: remember(plan, settings: settings, reference: reference, calendar: calendar)) }
        let current = try await settingsProvider.loadSettings().settings
        try SettingsValidator.validate(current)
        guard !current.legacyMarkers.isEmpty,
            OrdinaryConfigurationMutationIdentity(current) == OrdinaryConfigurationMutationIdentity(settings)
        else { throw CalendarManualCleanupError.configurationChanged }
        try Task.checkCancellation()
    }

    private func cleanup(calendar: Calendar) -> CalendarCleanupUseCase {
        CalendarCleanupUseCase(authorizationStatus: authorizationStatus, calendarStore: calendarStore, calendar: calendar)
    }

    private func remember(_ plan: CalendarCleanupPlan, settings: CalendarRelaySettings, reference: Date, calendar: Calendar) -> CalendarManualCleanupReview {
        let review = CalendarManualCleanupReview(plan: plan, window: LegacyCleanupWindow.calculate(referenceDate: reference, calendar: calendar), calendar: calendar)
        pending = PendingCleanupReview(review: review, identities: identities(plan), configuration: OrdinaryConfigurationMutationIdentity(settings))
        return review
    }

    private func identities(_ plan: CalendarCleanupPlan) -> [CalendarExecutableActionIdentity] {
        plan.deletions.map { CalendarMutationAction.delete(role: $0.role, event: $0.event).executableIdentity }
    }

    private func recordDeletion() { confirmedDeletions += 1 }

    private func safeFailure(_ error: Error) -> CalendarManualCleanupError {
        if let error = error as? CalendarManualCleanupError { return error }
        let category: CalendarManualCleanupFailure
        if error is CalendarRelaySettingsProviderError || error is SettingsValidationError { category = .configurationUnavailable }
        else if error is CancellationError { category = .cancelled }
        else if let error = error as? CalendarCleanupError {
            switch error {
            case .invalidSettings: category = .configurationUnavailable
            case .legacyMarkersRequired: category = .legacyMarkersRequired
            case .preflightFailed(let issues):
                if let state = issues.compactMap({ issue -> CalendarAuthorizationState? in
                    if case .authorizationUnavailable(let state) = issue { return state }
                    return nil
                }).first { category = .authorizationUnavailable(state) } else { category = .preflightFailed }
            case .mutationFailed: category = .deletionFailed
            case .verificationFailed: category = .verificationReadFailed
            case .verificationFoundRemainingMatches(let count): category = .remainingMatches(count)
            }
        } else { category = .unexpected }
        return .failed(confirmedDeletions: confirmedDeletions, category: category)
    }
}

private struct PendingCleanupReview: Sendable {
    let review: CalendarManualCleanupReview
    let identities: [CalendarExecutableActionIdentity]
    let configuration: OrdinaryConfigurationMutationIdentity
}

private struct CleanupReconfirmation: Error {
    let review: CalendarManualCleanupReview
}