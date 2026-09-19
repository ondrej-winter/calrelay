public enum CalendarAppOperation: Equatable, Sendable {
    case statusRefresh
    case calendarAccessSetup
    case inventory
    case manualDryRun
    case manualApply
    case cleanup
    case standingAuthorization
    case automationSettings
    case automaticReconciliation
    case configurationRecovery
}

public enum CalendarAppOperationRequest: Equatable, Sendable {
    case start
    case coalesced
    case rejected
}

public struct CalendarAppOperationCoordinator: Sendable {
    public private(set) var activeOperation: CalendarAppOperation?
    private var hasPendingAutomaticReconciliation = false
    private var hasPendingConfigurationRecovery = false

    public init() {}

    public mutating func request(_ operation: CalendarAppOperation) -> CalendarAppOperationRequest {
        guard activeOperation != nil else {
            activeOperation = operation
            return .start
        }

        switch operation {
        case .automaticReconciliation:
            hasPendingAutomaticReconciliation = true
            return .coalesced
        case .configurationRecovery:
            hasPendingConfigurationRecovery = true
            return .coalesced
        default:
            return .rejected
        }
    }

    public mutating func finish() -> CalendarAppOperation? {
        if hasPendingConfigurationRecovery {
            hasPendingConfigurationRecovery = false
            activeOperation = .configurationRecovery
            return activeOperation
        }
        if hasPendingAutomaticReconciliation {
            hasPendingAutomaticReconciliation = false
            activeOperation = .automaticReconciliation
            return activeOperation
        }
        activeOperation = nil
        return nil
    }
}