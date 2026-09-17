import CalRelayKit
import Foundation

enum CalendarMutationExecutorTests {
    static func runAll() async throws {
        try await testExecutorConfirmsOrderedActionsAfterSuccess()
        try await testExecutorStopsAtFirstFailureAndReportsPrivacySafeCounts()
        try await testExecutorTreatsEmptyPlanAsSuccess()
    }

    private static func testExecutorConfirmsOrderedActionsAfterSuccess() async throws {
        let store = MutationExecutorCalendarStore()
        let actions = orderedActions()
        let confirmations = MutationConfirmationRecorder()

        let result = try await CalendarMutationExecutor(calendarStore: store).execute(
            actions, onConfirmation: { confirmation in await confirmations.record(confirmation) })

        try expect(
            await store.operations() == actions.map(\.operationDescription),
            "Executor should preserve supplied action order")
        try expect(
            await confirmations.values() == actions.map(\.confirmation),
            "Confirmations should follow successful action order")
        try expect(result.confirmedActionCount == 4, "Executor should report all confirmed actions")
        try expect(result.confirmedCounts.count == 2, "Executor should report privacy-safe counts for both roles")
    }

    private static func testExecutorStopsAtFirstFailureAndReportsPrivacySafeCounts() async throws {
        let store = MutationExecutorCalendarStore(failOperationNumber: 3)
        let actions = orderedActions()
        let confirmations = MutationConfirmationRecorder()

        do {
            _ = try await CalendarMutationExecutor(calendarStore: store).execute(
                actions, onConfirmation: { confirmation in await confirmations.record(confirmation) })
        } catch let error as CalendarMutationExecutionError {
            guard case .partial(let partial) = error else { throw TestFailure("Expected partial mutation result") }

            try expect(
                await store.operations() == Array(actions.prefix(3)).map(\.operationDescription),
                "Executor should stop after the failed action")
            try expect(
                await confirmations.values() == Array(actions.prefix(2)).map(\.confirmation),
                "Only successful actions should be confirmed")
            try expect(partial.confirmedActionCount == 2, "Partial result should count confirmed actions")
            try expect(partial.failedRole == .hub, "Partial result may identify the configured role")
            try expect(partial.failureCategory == .createFailed, "Partial result should identify the action category")
            try expect(
                partial.confirmedCounts == [
                    CalendarRoleMutationCounts(role: .hub, confirmedDeletes: 1, confirmedCreates: 0),
                    CalendarRoleMutationCounts(
                        role: .work(name: "ACME", declarationIndex: 0), confirmedDeletes: 1, confirmedCreates: 0)
                ], "Partial result should contain counts without event details")
            return
        }

        throw TestFailure("Expected mutation execution failure")
    }

    private static func testExecutorTreatsEmptyPlanAsSuccess() async throws {
        let store = MutationExecutorCalendarStore()

        let result = try await CalendarMutationExecutor(calendarStore: store).execute([])

        try expect(result.confirmedActionCount == 0, "An empty plan should succeed without mutation")
        try expect((await store.operations()).isEmpty, "An empty plan should not call the store")
    }

    private static func orderedActions() -> [CalendarMutationAction] {
        let hub = calendar(id: "hub", title: "Hub", source: "iCloud")
        let work = calendar(id: "work", title: "ACME Work", source: "Google")
        return [
            .delete(role: .hub, event: event(id: "hub-delete", calendar: hub)),
            .delete(role: .work(name: "ACME", declarationIndex: 0), event: event(id: "work-delete", calendar: work)),
            .create(role: .hub, event: projection(calendar: hub, title: "[ACME] New")),
            .create(
                role: .work(name: "ACME", declarationIndex: 0), event: projection(calendar: work, title: "[ME] New"))
        ]
    }

    private static func calendar(id: String, title: String, source: String) -> CalendarIdentity {
        CalendarIdentity(id: id, title: title, sourceTitle: source)
    }

    private static func event(id: String, calendar: CalendarIdentity) -> CalendarEvent {
        CalendarEvent(
            id: id, calendar: calendar, title: "[OLD] Event", start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000), isAllDay: false, availability: .busy, status: .confirmed)
    }

    private static func projection(calendar: CalendarIdentity, title: String) -> CalendarEventProjection {
        CalendarEventProjection(
            destinationCalendar: calendar, title: title, start: Date(timeIntervalSince1970: 3_000),
            end: Date(timeIntervalSince1970: 4_000), isAllDay: false)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

extension CalendarMutationAction {
    fileprivate var operationDescription: String {
        switch self {
        case .delete(_, let event): "delete:\(event.calendar.id)"
        case .create(_, let event): "create:\(event.destinationCalendar.id)"
        }
    }
}

private struct MutationExecutorStoreFailure: Error {}

private actor MutationExecutorCalendarStore: CalendarStorePort {
    private let failOperationNumber: Int?
    private var operationValues: [String] = []

    init(failOperationNumber: Int? = nil) { self.failOperationNumber = failOperationNumber }

    func listCalendars() async throws -> [RelayCalendar] { [] }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] { [] }

    func createEvent(_ event: CalendarEventProjection) async throws {
        try record("create:\(event.destinationCalendar.id)")
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws { try record("delete:\(event.calendar.id)") }

    func operations() -> [String] { operationValues }

    private func record(_ operation: String) throws {
        operationValues.append(operation)
        if failOperationNumber == operationValues.count { throw MutationExecutorStoreFailure() }
    }
}

private actor MutationConfirmationRecorder {
    private var confirmations: [CalendarMutationConfirmation] = []

    func record(_ confirmation: CalendarMutationConfirmation) { confirmations.append(confirmation) }

    func values() -> [CalendarMutationConfirmation] { confirmations }
}
