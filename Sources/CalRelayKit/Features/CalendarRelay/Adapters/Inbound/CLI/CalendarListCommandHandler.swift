public struct CalendarListCommandHandler: Sendable {
    private let inventory: CalendarInventoryUseCase

    public init(inventory: CalendarInventoryUseCase) { self.inventory = inventory }

    public func run() async throws -> String { CalendarListFormatter.formatForCLI(try await inventory.run()) }
}
