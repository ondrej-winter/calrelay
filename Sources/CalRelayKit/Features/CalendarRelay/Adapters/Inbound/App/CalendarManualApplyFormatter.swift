public enum CalendarManualApplyFormatter {
    public static func format(_ result: CalendarMutationExecutionResult) -> String {
        let deletes = result.confirmedCounts.reduce(0) { $0 + $1.confirmedDeletes }
        let creates = result.confirmedCounts.reduce(0) { $0 + $1.confirmedCreates }
        return "Sync completed. Confirmed deletes: \(deletes). Confirmed creates: \(creates)."
    }

    public static func formatFailure(_ error: Error) -> String {
        if let error = error as? CalendarMutationExecutionError, case .partial(let partial) = error {
            let deletes = partial.confirmedCounts.reduce(0) { $0 + $1.confirmedDeletes }
            let creates = partial.confirmedCounts.reduce(0) { $0 + $1.confirmedCreates }
            return "Sync partially applied. Confirmed deletes: \(deletes). Confirmed creates: \(creates). "
                + "Stopped: \(partial.failureCategory.description). No rollback was attempted. Review and confirm a fresh plan to recover."
        }
        if let error = error as? CalendarManualApplyError {
            switch error {
            case .configurationChanged:
                return
                    "Configuration changed before mutation. No mutations were performed. Refresh status and review a fresh plan."
            case .reviewRequired: return "This confirmation is no longer valid. Review and confirm a fresh plan."
            case .operationInProgress: return "An operation is already in progress. Wait for it to finish."
            }
        }
        if let error = error as? CalendarRelaySettingsProviderError {
            switch error {
            case .missing: return "The canonical configuration is missing. Restore it and review a fresh plan."
            case .invalid: return "The canonical configuration is invalid. Fix it and review a fresh plan."
            }
        }
        if let error = error as? ReconcileCalendarsError { return error.description }
        if let error = error as? CalendarAccessError { return error.description }
        return "Sync could not be completed. Refresh status and review a fresh plan before trying again."
    }
}
