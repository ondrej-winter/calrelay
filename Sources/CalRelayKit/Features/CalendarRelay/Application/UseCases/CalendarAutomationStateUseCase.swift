import Foundation

public actor CalendarAutomationStateUseCase {
    private let stateStore: any CalendarAutomationStateStore

    public init(stateStore: any CalendarAutomationStateStore) { self.stateStore = stateStore }

    public func loadState() async -> CalendarAutomationPersistentState { await stateStore.loadState() }

    public func setSchedulingPreference(_ preference: CalendarSchedulingPreference) async throws {
        _ = try await stateStore.updateState { current in
            CalendarAutomationPersistentState(
                schedulingPreference: preference, standingAuthorization: current.standingAuthorization,
                operationalStatus: current.operationalStatus)
        }
    }

    public func setNextNominalRunAt(_ date: Date?) async throws {
        _ = try await stateStore.updateState { current in
            let previous = current.operationalStatus
            let status = CalendarAutomationOperationalStatus(
                lastAttemptAt: previous.lastAttemptAt, latestOutcome: previous.latestOutcome,
                confirmedCounts: previous.confirmedCounts, retryState: previous.retryState,
                freshness: CalendarAutomationFreshnessMetadata(
                    lastSuccessAt: previous.freshness.lastSuccessAt, nextNominalRunAt: date))
            return CalendarAutomationPersistentState(
                schedulingPreference: current.schedulingPreference,
                standingAuthorization: current.standingAuthorization, operationalStatus: status)
        }
    }
}