import CalRelayKit
import Foundation

// ACCESS-AC-01: every non-setup surface inspects authorization without requesting it.
enum CalendarNoPromptContractTests {
    static func runAll() async throws {
        try await testInventoryAndConfigCheckNeverRequestCalendarAccess()
        try await testCLIOrdinaryOperationsNeverRequestCalendarAccess()
        try await testManualAppOrdinaryOperationsNeverRequestCalendarAccess()
        try await testCleanupOperationsNeverRequestCalendarAccess()
        try await testStandingAuthorizationNeverRequestsCalendarAccess()
    }

    private static func testInventoryAndConfigCheckNeverRequestCalendarAccess() async throws {
        try await verify([.inventory, .configCheck])
    }

    private static func testCLIOrdinaryOperationsNeverRequestCalendarAccess() async throws {
        try await verify([.cliDryRun, .cliApply, .cliExplanation])
    }

    private static func testManualAppOrdinaryOperationsNeverRequestCalendarAccess() async throws {
        try await verify([.manualDryRun, .manualApplyReview, .manualApplyConfirmation])
    }

    private static func testCleanupOperationsNeverRequestCalendarAccess() async throws {
        try await verify([.cliCleanupDryRun, .cliCleanupApply, .appCleanupReview, .appCleanupConfirmation])
    }

    private static func testStandingAuthorizationNeverRequestsCalendarAccess() async throws {
        try await verify([.standingAuthorizationReview, .standingAuthorizationConfirmation])
    }

    private static func verify(_ operations: [NoPromptOperation]) async throws {
        for operation in operations {
            for state in CalendarAuthorizationState.allCases {
                let initialState = operation.requiresReviewPreparation ? CalendarAuthorizationState.fullAccess : state
                let fixture = NoPromptFixture()
                let authorization = RequestCapableCalendarAuthorization(state: initialState)
                let store = fixture.store()
                let context = NoPromptContext(
                    fixture: fixture, targetState: state, authorization: authorization, store: store)

                let unavailableState = try await operation.run(context)

                try expect(
                    unavailableState == (state == .fullAccess ? nil : state),
                    "\(operation) should report \(state) without requesting access")
                try expect(
                    await authorization.requestCount() == 0,
                    "\(operation) must never request Calendar access for \(state)")
                if state == .fullAccess {
                    try expect(
                        await store.listCalendarsCallCount() > 0,
                        "\(operation) should proceed through Calendar access when full access exists")
                } else {
                    try expect(
                        await store.mutationAttemptCount() == 0,
                        "\(operation) must not mutate when authorization is unavailable")
                }
            }
        }
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private enum NoPromptOperation: String, CustomStringConvertible {
    case inventory
    case configCheck
    case cliDryRun
    case cliApply
    case cliExplanation
    case manualDryRun
    case manualApplyReview
    case manualApplyConfirmation
    case cliCleanupDryRun
    case cliCleanupApply
    case appCleanupReview
    case appCleanupConfirmation
    case standingAuthorizationReview
    case standingAuthorizationConfirmation

    var description: String { rawValue }

    var requiresReviewPreparation: Bool {
        switch self {
        case .manualApplyConfirmation, .appCleanupConfirmation, .standingAuthorizationConfirmation: true
        default: false
        }
    }

    func run(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        switch self {
        case .inventory, .configCheck: try await runInspection(context)
        case .cliDryRun, .cliApply, .cliExplanation, .cliCleanupDryRun, .cliCleanupApply: try await runCLI(context)
        case .manualDryRun, .manualApplyReview, .manualApplyConfirmation: try await runManualOrdinary(context)
        case .appCleanupReview, .appCleanupConfirmation: try await runManualCleanup(context)
        case .standingAuthorizationReview, .standingAuthorizationConfirmation:
            try await runStandingAuthorization(context)
        }
    }

    private func runInspection(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        switch self {
        case .inventory: try await inventory(context)
        case .configCheck: try await configCheck(context)
        default: preconditionFailure("Unexpected inspection operation: \(self)")
        }
    }

    private func runCLI(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        switch self {
        case .cliDryRun: try await ordinaryCLI(context, apply: false, explain: false)
        case .cliApply: try await ordinaryCLI(context, apply: true, explain: false)
        case .cliExplanation: try await ordinaryCLI(context, apply: false, explain: true)
        case .cliCleanupDryRun: try await cleanupCLI(context, apply: false)
        case .cliCleanupApply: try await cleanupCLI(context, apply: true)
        default: preconditionFailure("Unexpected CLI operation: \(self)")
        }
    }

    private func runManualOrdinary(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        switch self {
        case .manualDryRun: try await manualDryRun(context)
        case .manualApplyReview: try await manualApplyReview(context)
        case .manualApplyConfirmation: try await manualApplyConfirmation(context)
        default: preconditionFailure("Unexpected manual ordinary operation: \(self)")
        }
    }

    private func runManualCleanup(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        switch self {
        case .appCleanupReview: try await appCleanupReview(context)
        case .appCleanupConfirmation: try await appCleanupConfirmation(context)
        default: preconditionFailure("Unexpected manual cleanup operation: \(self)")
        }
    }

    private func runStandingAuthorization(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        switch self {
        case .standingAuthorizationReview: try await standingAuthorizationReview(context)
        case .standingAuthorizationConfirmation: try await standingAuthorizationConfirmation(context)
        default: preconditionFailure("Unexpected standing-authorization operation: \(self)")
        }
    }

    private func inventory(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        do {
            _ = try await CalendarInventoryUseCase(
                authorizationStatus: context.authorization, calendarStore: context.store
            ).run()
            return nil
        } catch CalendarAccessError.fullAccessRequired(let state) { return state }
    }

    private func configCheck(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        let config = try context.fixture.writeConfig(legacyMarkers: [])
        do {
            _ = try await ConfigCheckCommandHandler(
                authorizationStatus: context.authorization, calendarStore: context.store, now: { context.fixture.now },
                calendar: context.fixture.calendar
            ).run(config: config.path)
            return nil
        } catch ConfigCheckCommandError.preflightFailed(_, let issues) { return authorizationState(in: issues) }
    }

    private func ordinaryCLI(_ context: NoPromptContext, apply: Bool, explain: Bool) async throws
        -> CalendarAuthorizationState?
    {
        let config = try context.fixture.writeConfig(legacyMarkers: [])
        do {
            _ = try await ReconcileCommandHandler(
                authorizationStatus: context.authorization, calendarStore: context.store, now: { context.fixture.now },
                calendar: context.fixture.calendar
            ).run(config: config.path, apply: apply, explain: explain, cleanupLegacy: false)
            return nil
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func manualDryRun(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        do {
            _ = try await context.fixture.manualDryRun(authorization: context.authorization, store: context.store).run()
            return nil
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func manualApplyReview(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        do {
            _ = try await context.fixture.manualApply(authorization: context.authorization, store: context.store)
                .review()
            return nil
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func manualApplyConfirmation(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        let useCase = context.fixture.manualApply(authorization: context.authorization, store: context.store)
        let review = try await useCase.review()
        await context.authorization.replace(context.targetState)
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            return nil
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func cleanupCLI(_ context: NoPromptContext, apply: Bool) async throws -> CalendarAuthorizationState? {
        let config = try context.fixture.writeConfig(legacyMarkers: ["[OLD]"])
        do {
            _ = try await ReconcileCommandHandler(
                authorizationStatus: context.authorization, calendarStore: context.store, now: { context.fixture.now },
                calendar: context.fixture.calendar
            ).run(config: config.path, apply: apply, explain: false, cleanupLegacy: true)
            return nil
        } catch CalendarCleanupError.preflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func appCleanupReview(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        do {
            _ = try await context.fixture.manualCleanup(authorization: context.authorization, store: context.store)
                .review()
            return nil
        } catch CalendarManualCleanupError.failed(confirmedDeletions: _, category: .authorizationUnavailable(let state))
        { return state }
    }

    private func appCleanupConfirmation(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        let useCase = context.fixture.manualCleanup(authorization: context.authorization, store: context.store)
        let review = try await useCase.review()
        await context.authorization.replace(context.targetState)
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            return nil
        } catch CalendarManualCleanupError.failed(confirmedDeletions: _, category: .authorizationUnavailable(let state))
        { return state }
    }

    private func standingAuthorizationReview(_ context: NoPromptContext) async throws -> CalendarAuthorizationState? {
        do {
            _ = try await context.fixture.standingAuthorization(
                authorization: context.authorization, store: context.store
            ).review()
            return nil
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func standingAuthorizationConfirmation(_ context: NoPromptContext) async throws
        -> CalendarAuthorizationState?
    {
        let useCase = context.fixture.standingAuthorization(authorization: context.authorization, store: context.store)
        let review = try await useCase.review()
        await context.authorization.replace(context.targetState)
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            return nil
        } catch ReconcileCalendarsError.accessPreflightFailed(let issues) { return authorizationState(in: issues) }
    }

    private func authorizationState(in issues: [CalendarAccessPreflightIssue]) -> CalendarAuthorizationState? {
        for case .authorizationUnavailable(let state) in issues { return state }
        return nil
    }
}

private struct NoPromptContext: Sendable {
    let fixture: NoPromptFixture
    let targetState: CalendarAuthorizationState
    let authorization: RequestCapableCalendarAuthorization
    let store: CommandHandlerCalendarStore
}

private struct NoPromptFixture: Sendable {
    let now = Date(timeIntervalSince1970: 10_000)
    let hub = RelayCalendar(id: "test-hub", title: "Test Hub", sourceTitle: "Test Source", isWritable: true)
    let work = RelayCalendar(id: "test-work", title: "Test Work", sourceTitle: "Test Source", isWritable: true)

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func store() -> CommandHandlerCalendarStore {
        CommandHandlerCalendarStore(
            calendars: [hub, work],
            eventsByCalendarID: [
                hub.id: [event(id: "legacy", calendar: hub, title: "[OLD] Retired")],
                work.id: [event(id: "source", calendar: work, title: "Example")]
            ])
    }

    func manualDryRun(authorization: any CalendarAuthorizationStatusPort, store: any CalendarStorePort)
        -> CalendarManualDryRunUseCase
    {
        CalendarManualDryRunUseCase(
            settingsProvider: NoPromptSettingsProvider(settings: settings()), authorizationStatus: authorization,
            calendarStore: store, now: { now }, calendar: calendar)
    }

    func manualApply(authorization: any CalendarAuthorizationStatusPort, store: any CalendarStorePort)
        -> CalendarManualApplyUseCase
    {
        CalendarManualApplyUseCase(
            settingsProvider: NoPromptSettingsProvider(settings: settings()), authorizationStatus: authorization,
            calendarStore: store, now: { now }, calendar: calendar)
    }

    func manualCleanup(authorization: any CalendarAuthorizationStatusPort, store: any CalendarStorePort)
        -> CalendarManualCleanupUseCase
    {
        CalendarManualCleanupUseCase(
            settingsProvider: NoPromptSettingsProvider(settings: settings(legacyMarkers: ["[OLD]"])),
            authorizationStatus: authorization, calendarStore: store, now: { now }, calendar: { calendar })
    }

    func standingAuthorization(authorization: any CalendarAuthorizationStatusPort, store: any CalendarStorePort)
        -> CalendarStandingAuthorizationUseCase
    {
        CalendarStandingAuthorizationUseCase(
            settingsProvider: NoPromptSettingsProvider(settings: settings()), authorizationStatus: authorization,
            calendarStore: store, stateStore: NoPromptAutomationStateStore(), now: { now }, calendar: calendar)
    }

    func writeConfig(legacyMarkers: [String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config.yaml")
        try configYAML(legacyMarkers: legacyMarkers).write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func settings(legacyMarkers: [String] = []) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Test Work", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: legacyMarkers)
    }

    private func event(id: String, calendar: RelayCalendar, title: String) -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendar: CalendarIdentity(id: calendar.id, title: calendar.title, sourceTitle: calendar.sourceTitle),
            title: title, start: now, end: now.addingTimeInterval(100), isAllDay: false, availability: .busy,
            status: .confirmed)
    }

    private func configYAML(legacyMarkers: [String]) -> String {
        let legacySection =
            legacyMarkers.isEmpty
            ? "" : "\nlegacyMarkers:\n" + legacyMarkers.map { "  - \"\($0)\"" }.joined(separator: "\n")
        return """
            hubCalendar:
              sourceTitle: "Test Source"
              calendarTitle: "Test Hub"
            personalPrefix: "[PERSONAL]"
            syncWindowDays: 1
            workCalendars:
              - name: "Test Work"
                prefix: "[WORK]"
                calendar:
                  sourceTitle: "Test Source"
                  calendarTitle: "Test Work"
            \(legacySection)
            """
    }
}

private actor RequestCapableCalendarAuthorization: CalendarAuthorizationStatusPort, CalendarFullAccessRequestPort {
    private var state: CalendarAuthorizationState
    private var requests = 0

    init(state: CalendarAuthorizationState) { self.state = state }

    func authorizationStatus() async -> CalendarAuthorizationState { state }

    func requestFullAccess() async throws -> Bool {
        requests += 1
        return state == .fullAccess
    }

    func replace(_ state: CalendarAuthorizationState) { self.state = state }
    func requestCount() -> Int { requests }
}

private actor NoPromptSettingsProvider: CalendarRelaySettingsProvider {
    private let settings: CalendarRelaySettings

    init(settings: CalendarRelaySettings) { self.settings = settings }

    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        LoadedCalendarRelaySettings(displayPath: "test-configuration", settings: settings)
    }
}

private actor NoPromptAutomationStateStore: CalendarAutomationStateStore {
    private var state = CalendarAutomationPersistentState.empty

    func loadState() async -> CalendarAutomationPersistentState { state }
    func saveState(_ state: CalendarAutomationPersistentState) async throws { self.state = state }
    func updateState(_ transform: @Sendable (CalendarAutomationPersistentState) -> CalendarAutomationPersistentState)
        async throws -> CalendarAutomationPersistentState
    {
        state = transform(state)
        return state
    }
}
