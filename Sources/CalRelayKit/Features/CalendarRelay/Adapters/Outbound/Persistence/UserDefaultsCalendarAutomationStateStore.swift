import Foundation

public actor UserDefaultsCalendarAutomationStateStore: CalendarAutomationStateStore {
    public static let defaultKey = "calendarAutomationState"

    private let defaults: UserDefaults
    private let key: String

    public init(suiteName: String? = nil, key: String = defaultKey) {
        if let suiteName, let suiteDefaults = UserDefaults(suiteName: suiteName) {
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }
        self.key = key
    }

    public func loadState() async -> CalendarAutomationPersistentState {
        loadCurrentState()
    }

    public func saveState(_ state: CalendarAutomationPersistentState) async throws { try saveCurrentState(state) }

    public func updateState(
        _ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState
    ) async throws -> CalendarAutomationPersistentState {
        let updated = transform(loadCurrentState())
        try saveCurrentState(updated)
        return updated
    }

    private func loadCurrentState() -> CalendarAutomationPersistentState {
        guard let data = defaults.data(forKey: key) else { return .empty }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let envelope = try decoder.decode(StoredEnvelope.self, from: data)
            guard envelope.schemaVersion == StoredEnvelope.currentVersion, let state = envelope.state.applicationState
            else { return recoverFromInvalidState() }
            return state
        } catch { return recoverFromInvalidState() }
    }

    private func saveCurrentState(_ state: CalendarAutomationPersistentState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        defaults.set(try encoder.encode(StoredEnvelope(state: StoredState(state))), forKey: key)
    }

    private func recoverFromInvalidState() -> CalendarAutomationPersistentState {
        defaults.removeObject(forKey: key)
        return .empty
    }
}

private struct StoredEnvelope: Codable {
    static let currentVersion = 1

    let schemaVersion: Int
    let state: StoredState

    init(state: StoredState) {
        schemaVersion = Self.currentVersion
        self.state = state
    }
}

private struct StoredState: Codable {
    let schedulingPreference: String
    let standingAuthorization: String?
    let operationalStatus: StoredOperationalStatus

    init(_ state: CalendarAutomationPersistentState) {
        schedulingPreference = state.schedulingPreference.storageValue
        standingAuthorization = state.standingAuthorization?.persistenceValue
        operationalStatus = StoredOperationalStatus(state.operationalStatus)
    }

    var applicationState: CalendarAutomationPersistentState? {
        guard let schedulingPreference = CalendarSchedulingPreference(storageValue: schedulingPreference) else {
            return nil
        }
        let authorization: CalendarStandingAuthorizationBinding?
        if let standingAuthorization {
            guard let decoded = CalendarStandingAuthorizationBinding(persistedRepresentation: standingAuthorization)
            else { return nil }
            authorization = decoded
        } else {
            authorization = nil
        }
        guard let operationalStatus = operationalStatus.applicationStatus else { return nil }
        return CalendarAutomationPersistentState(
            schedulingPreference: schedulingPreference, standingAuthorization: authorization,
            operationalStatus: operationalStatus)
    }
}

private struct StoredOperationalStatus: Codable {
    let lastAttemptAt: Date?
    let latestOutcome: String?
    let confirmedCreates: Int
    let confirmedDeletes: Int
    let retry: StoredRetryState
    let lastSuccessAt: Date?
    let nextNominalRunAt: Date?

    init(_ status: CalendarAutomationOperationalStatus) {
        lastAttemptAt = status.lastAttemptAt
        latestOutcome = status.latestOutcome?.storageValue
        confirmedCreates = status.confirmedCounts.confirmedCreates
        confirmedDeletes = status.confirmedCounts.confirmedDeletes
        retry = StoredRetryState(status.retryState)
        lastSuccessAt = status.freshness.lastSuccessAt
        nextNominalRunAt = status.freshness.nextNominalRunAt
    }

    var applicationStatus: CalendarAutomationOperationalStatus? {
        guard confirmedCreates >= 0, confirmedDeletes >= 0 else { return nil }
        let outcome: CalendarAutomationOutcomeCategory?
        if let latestOutcome {
            guard let decoded = CalendarAutomationOutcomeCategory(storageValue: latestOutcome) else { return nil }
            outcome = decoded
        } else {
            outcome = nil
        }
        guard let retryState = retry.applicationState else { return nil }
        return CalendarAutomationOperationalStatus(
            lastAttemptAt: lastAttemptAt, latestOutcome: outcome,
            confirmedCounts: CalendarAutomationMutationCounts(
                confirmedCreates: confirmedCreates, confirmedDeletes: confirmedDeletes), retryState: retryState,
            freshness: CalendarAutomationFreshnessMetadata(
                lastSuccessAt: lastSuccessAt, nextNominalRunAt: nextNominalRunAt))
    }
}

private struct StoredRetryState: Codable {
    let kind: String
    let attempt: Int?
    let nextAttemptAt: Date?

    init(_ state: CalendarAutomationRetryState) {
        switch state {
        case .none:
            kind = "none"
            attempt = nil
            nextAttemptAt = nil
        case .scheduled(let attemptValue, let date):
            kind = "scheduled"
            attempt = attemptValue
            nextAttemptAt = date
        }
    }

    var applicationState: CalendarAutomationRetryState? {
        switch kind {
        case "none":
            guard attempt == nil, nextAttemptAt == nil else { return nil }
            return CalendarAutomationRetryState.none
        case "scheduled":
            guard let attempt, attempt > 0, let nextAttemptAt else { return nil }
            return .scheduled(attempt: attempt, nextAttemptAt: nextAttemptAt)
        default: return nil
        }
    }
}

extension CalendarSchedulingPreference {
    fileprivate var storageValue: String {
        switch self {
        case .disabled: "disabled"
        case .enabled: "enabled"
        case .paused: "paused"
        }
    }

    fileprivate init?(storageValue: String) {
        switch storageValue {
        case "disabled": self = .disabled
        case "enabled": self = .enabled
        case "paused": self = .paused
        default: return nil
        }
    }
}

extension CalendarAutomationOutcomeCategory {
    fileprivate var storageValue: String {
        switch self {
        case .noChanges: "noChanges"
        case .applied: "applied"
        case .partialMutation: "partialMutation"
        case .configurationUnavailable: "configurationUnavailable"
        case .migrationPending: "migrationPending"
        case .calendarAccessUnavailable: "calendarAccessUnavailable"
        case .topologyNotReady: "topologyNotReady"
        case .standingAuthorizationRequired: "standingAuthorizationRequired"
        case .transientFailure: "transientFailure"
        }
    }

    fileprivate init?(storageValue: String) {
        switch storageValue {
        case "noChanges": self = .noChanges
        case "applied": self = .applied
        case "partialMutation": self = .partialMutation
        case "configurationUnavailable": self = .configurationUnavailable
        case "migrationPending": self = .migrationPending
        case "calendarAccessUnavailable": self = .calendarAccessUnavailable
        case "topologyNotReady": self = .topologyNotReady
        case "standingAuthorizationRequired": self = .standingAuthorizationRequired
        case "transientFailure": self = .transientFailure
        default: return nil
        }
    }
}
