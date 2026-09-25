public struct OrdinaryReconciliationResult: Equatable, Sendable {
    public let actions: [CalendarMutationAction]

    public var plan: ReconciliationPlan {
        ReconciliationPlan(
            creates: actions.compactMap { action in
                guard case .create(_, let event) = action else { return nil }
                return event
            },
            deletes: actions.compactMap { action in
                guard case .delete(_, let event) = action else { return nil }
                return event
            })
    }

    public init(actions: [CalendarMutationAction]) { self.actions = actions }

    @available(*, deprecated, message: "The compatibility plan is derived from actions; use init(actions:) instead.")
    public init(plan _: ReconciliationPlan, actions: [CalendarMutationAction]) { self.actions = actions }
}
