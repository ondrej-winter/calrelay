public struct OrdinaryReconciliationResult: Equatable, Sendable {
    public let plan: ReconciliationPlan
    public let actions: [CalendarMutationAction]

    public init(plan: ReconciliationPlan, actions: [CalendarMutationAction]) {
        self.plan = plan
        self.actions = actions
    }
}
