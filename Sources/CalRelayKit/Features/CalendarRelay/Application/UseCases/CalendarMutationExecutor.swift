public struct CalendarMutationExecutor: Sendable {
    private let calendarStore: any CalendarStorePort

    public init(calendarStore: any CalendarStorePort) { self.calendarStore = calendarStore }

    public func execute(
        _ actions: [CalendarMutationAction],
        onConfirmation: @escaping @Sendable (CalendarMutationConfirmation) async -> Void = { _ in }
    ) async throws -> CalendarMutationExecutionResult {
        var accumulator = MutationCountAccumulator()

        for action in actions {
            try Task.checkCancellation()
            do {
                switch action {
                case .delete(_, let event): try await calendarStore.deleteEvent(event.identity)
                case .create(_, let event): try await calendarStore.createEvent(event)
                }
            } catch is CancellationError { throw CancellationError() } catch {
                let category: CalendarMutationFailureCategory
                switch action {
                case .delete: category = .deleteFailed
                case .create: category = .createFailed
                }
                throw CalendarMutationExecutionError.partial(
                    CalendarMutationPartialResult(
                        confirmedCounts: accumulator.values, failedRole: action.role, failureCategory: category))
            }

            accumulator.record(action.confirmation)
            await onConfirmation(action.confirmation)
        }

        return CalendarMutationExecutionResult(confirmedCounts: accumulator.values)
    }
}

private struct MutationCountAccumulator {
    private var roleOrder: [ConfiguredCalendarRole] = []
    private var countsByRole: [ConfiguredCalendarRole: (deletes: Int, creates: Int)] = [:]

    var values: [CalendarRoleMutationCounts] {
        roleOrder.map { role in
            let counts = countsByRole[role, default: (0, 0)]
            return CalendarRoleMutationCounts(
                role: role, confirmedDeletes: counts.deletes, confirmedCreates: counts.creates)
        }
    }

    mutating func record(_ confirmation: CalendarMutationConfirmation) {
        if countsByRole[confirmation.role] == nil { roleOrder.append(confirmation.role) }
        var counts = countsByRole[confirmation.role, default: (0, 0)]
        switch confirmation.category {
        case .delete: counts.deletes += 1
        case .create: counts.creates += 1
        }
        countsByRole[confirmation.role] = counts
    }
}
