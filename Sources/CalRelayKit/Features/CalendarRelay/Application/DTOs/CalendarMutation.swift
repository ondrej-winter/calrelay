public enum CalendarMutationAction: Equatable, Sendable {
    case delete(role: ConfiguredCalendarRole, event: CalendarEvent)
    case create(role: ConfiguredCalendarRole, event: CalendarEventProjection)

    public var role: ConfiguredCalendarRole {
        switch self {
        case .delete(let role, _), .create(let role, _): role
        }
    }

    public var confirmation: CalendarMutationConfirmation {
        switch self {
        case .delete(let role, _): CalendarMutationConfirmation(role: role, category: .delete)
        case .create(let role, _): CalendarMutationConfirmation(role: role, category: .create)
        }
    }

}

public enum CalendarMutationCategory: Equatable, Sendable {
    case delete
    case create
}

public struct CalendarMutationConfirmation: Equatable, Sendable {
    public let role: ConfiguredCalendarRole
    public let category: CalendarMutationCategory

    public init(role: ConfiguredCalendarRole, category: CalendarMutationCategory) {
        self.role = role
        self.category = category
    }
}

public struct CalendarRoleMutationCounts: Equatable, Sendable {
    public let role: ConfiguredCalendarRole
    public let confirmedDeletes: Int
    public let confirmedCreates: Int

    public init(role: ConfiguredCalendarRole, confirmedDeletes: Int, confirmedCreates: Int) {
        self.role = role
        self.confirmedDeletes = confirmedDeletes
        self.confirmedCreates = confirmedCreates
    }
}

public struct CalendarMutationExecutionResult: Equatable, Sendable {
    public let confirmedCounts: [CalendarRoleMutationCounts]

    public init(confirmedCounts: [CalendarRoleMutationCounts]) { self.confirmedCounts = confirmedCounts }

    public var confirmedActionCount: Int {
        confirmedCounts.reduce(0) { count, roleCounts in
            count + roleCounts.confirmedDeletes + roleCounts.confirmedCreates
        }
    }
}

public enum CalendarMutationFailureCategory: Equatable, Sendable {
    case deleteFailed
    case createFailed
}

public struct CalendarMutationPartialResult: Equatable, Sendable {
    public let confirmedCounts: [CalendarRoleMutationCounts]
    public let failedRole: ConfiguredCalendarRole
    public let failureCategory: CalendarMutationFailureCategory

    public init(
        confirmedCounts: [CalendarRoleMutationCounts], failedRole: ConfiguredCalendarRole,
        failureCategory: CalendarMutationFailureCategory
    ) {
        self.confirmedCounts = confirmedCounts
        self.failedRole = failedRole
        self.failureCategory = failureCategory
    }

    public var confirmedActionCount: Int {
        confirmedCounts.reduce(0) { count, roleCounts in
            count + roleCounts.confirmedDeletes + roleCounts.confirmedCreates
        }
    }
}

public enum CalendarMutationExecutionError: Error, Equatable, CustomStringConvertible, Sendable {
    case partial(CalendarMutationPartialResult)

    public var description: String {
        switch self {
        case .partial(let partial):
            var lines = ["Calendar mutations were partially applied."]
            lines.append(contentsOf: partial.confirmedCounts.map(formatCounts))
            lines.append("Stopped at \(partial.failedRole.description): \(partial.failureCategory.description).")
            lines.append("No rollback was attempted. Run a fresh reconciliation to recover.")
            return lines.joined(separator: "\n")
        }
    }

    private func formatCounts(_ counts: CalendarRoleMutationCounts) -> String {
        "\(counts.role.description): \(counts.confirmedDeletes) delete(s), \(counts.confirmedCreates) create(s) confirmed."
    }
}

extension CalendarMutationFailureCategory: CustomStringConvertible {
    public var description: String {
        switch self {
        case .deleteFailed: "delete failed"
        case .createFailed: "create failed"
        }
    }
}
