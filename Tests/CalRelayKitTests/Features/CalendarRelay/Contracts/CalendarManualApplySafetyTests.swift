import CalRelayKit
import Foundation

extension CalendarManualApplyTests {
    static func runSafetyTests() async throws {
        try await testConfigurationChangesBeforeFirstMutationAbort()
        try await testEmptyPlanStillRequiresCurrentConfigurationReview()
        try await testCancelAndMigrationNeverMutate()
        try await testDiagnosticOnlyConfigurationChangeDoesNotInvalidate()
        try await testPartialFailureConsumesConfirmationAndOmitsDetails()
        try await testConcurrentConfirmationDoesNotOverlap()
    }

    private static func testConfigurationChangesBeforeFirstMutationAbort() async throws {
        let fixture = ManualApplyFixture()
        let changed = fixture.settingsWith(prefix: "[CHANGED]")
        for finalLoad in [
            Result.success(changed), .failure(CalendarRelaySettingsProviderError.invalid(displayPath: "test"))
        ] {
            let provider = ScriptedManualApplySettingsProvider(loads: [
                .success(fixture.settings), .success(fixture.settings), finalLoad
            ])
            let store = fixture.store()
            let useCase = fixture.useCase(provider: provider, store: store)
            let review = try await useCase.review()
            do {
                _ = try await useCase.confirm(reviewID: review.id)
                throw TestFailure("Changed or invalid configuration must prevent mutation")
            } catch CalendarManualApplyError.configurationChanged {} catch CalendarRelaySettingsProviderError.invalid {}
            try expect(await store.createdEvents().isEmpty, "Configuration race must prevent every mutation")
            do {
                _ = try await useCase.confirm(reviewID: review.id)
                throw TestFailure("Failed attempt must consume confirmation")
            } catch CalendarManualApplyError.reviewRequired {}
        }
    }

    private static func testEmptyPlanStillRequiresCurrentConfigurationReview() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = CommandHandlerCalendarStore(calendars: [fixture.hub, fixture.work])
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        await provider.replace(fixture.settingsWith(prefix: "[CHANGED]"))
        guard case .reviewRequired(let fresh) = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("A changed configuration mutation identity needs fresh review even for an empty plan")
        }
        guard case .applied(let result) = try await useCase.confirm(reviewID: fresh.id) else {
            throw TestFailure("A reviewed ready empty plan should succeed")
        }
        try expect(result.confirmedActionCount == 0, "Empty success must not mutate")
    }

    private static func testCancelAndMigrationNeverMutate() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        await useCase.cancelReview()
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Cancelled review must not authorize mutation")
        } catch CalendarManualApplyError.reviewRequired {}
        await provider.replace(fixture.settingsWith(prefix: "[WORK]", legacyMarkers: ["[RETIRED]"]))
        do {
            _ = try await useCase.review()
            throw TestFailure("Migration must block manual review")
        } catch ReconcileCalendarsError.migrationPending {}
        try expect(await store.listCalendarsCallCount() == 1, "Migration must fail before Calendar access")
        try expect(await store.createdEvents().isEmpty, "Cancel and migration must never mutate")
    }

    private static func testDiagnosticOnlyConfigurationChangeDoesNotInvalidate() async throws {
        let fixture = ManualApplyFixture()
        let provider = ScriptedManualApplySettingsProvider(loads: [
            .success(fixture.settings), .success(fixture.settingsWith(prefix: "[WORK]", name: "Renamed")),
            .success(fixture.settingsWith(prefix: "[WORK]", name: "Renamed again"))
        ])
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        guard case .applied = try await useCase.confirm(reviewID: review.id) else {
            throw TestFailure("Diagnostic-only role names must not invalidate mutation identity")
        }
    }

    private static func testPartialFailureConsumesConfirmationAndOmitsDetails() async throws {
        let fixture = ManualApplyFixture()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let store = PartialManualApplyStore(fixture: fixture)
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Second mutation should fail")
        } catch let error as CalendarMutationExecutionError {
            guard case .partial(let partial) = error else { throw TestFailure("Expected partial result") }
            try expect(partial.confirmedActionCount == 1, "Only confirmed deletion should be counted")
            let output = CalendarManualApplyFormatter.formatFailure(error)
            try expect(
                output.contains("No rollback") && output.contains("fresh plan"),
                "Partial result must explain safe manual recovery")
            for forbidden in ["test-hub", "test-source", "Test Hub", "[WORK]", "Example", "secret"] {
                try expect(!output.contains(forbidden), "Partial presentation must omit event and framework details")
            }
        }
        try expect(
            await store.operations() == ["delete", "create"], "Failure must stop later operations without rollback")
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Partial result must require a new manual review")
        } catch CalendarManualApplyError.reviewRequired {}
    }

    private static func testConcurrentConfirmationDoesNotOverlap() async throws {
        let fixture = ManualApplyFixture()
        let provider = PausingManualApplySettingsProvider(settings: fixture.settings)
        let store = fixture.store()
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        let first = Task { try await useCase.confirm(reviewID: review.id) }
        await provider.waitUntilPaused()
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Reentrant confirmation must not overlap")
        } catch CalendarManualApplyError.operationInProgress {}
        await provider.resume()
        _ = try await first.value
        try expect(await store.createdEvents().count == 1, "Overlapping triggers must not duplicate mutation")
    }
}

private actor ScriptedManualApplySettingsProvider: CalendarRelaySettingsProvider {
    private var loads: [Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>]
    init(loads: [Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>]) { self.loads = loads }
    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        guard !loads.isEmpty else { throw TestFailure("Unexpected settings read") }
        return LoadedCalendarRelaySettings(displayPath: "test", settings: try loads.removeFirst().get())
    }
}

private actor PausingManualApplySettingsProvider: CalendarRelaySettingsProvider {
    let settings: CalendarRelaySettings
    private var calls = 0
    private var paused: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    init(settings: CalendarRelaySettings) { self.settings = settings }
    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        calls += 1
        if calls == 2 {
            await withCheckedContinuation { continuation in
                paused = continuation
                observer?.resume()
                observer = nil
            }
        }
        return LoadedCalendarRelaySettings(displayPath: "test", settings: settings)
    }
    func waitUntilPaused() async {
        if paused != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func resume() {
        paused?.resume()
        paused = nil
    }
}

private actor PartialManualApplyStore: CalendarStorePort {
    let fixture: ManualApplyFixture
    private var recorded: [String] = []
    init(fixture: ManualApplyFixture) { self.fixture = fixture }
    func listCalendars() async throws -> [RelayCalendar] { [fixture.hub, fixture.work] }
    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        [
            CalendarEvent(
                id: "test-source", calendar: calendar,
                title: calendar.id == fixture.hub.id ? "[WORK] Stale" : "Example", start: fixture.now,
                end: fixture.now.addingTimeInterval(100), isAllDay: false, availability: .busy, status: .confirmed)
        ]
    }
    func deleteEvent(_ event: CalendarEventIdentity) async throws { recorded.append("delete") }
    func createEvent(_ event: CalendarEventProjection) async throws {
        recorded.append("create")
        throw TestFailure("secret framework error")
    }
    func operations() -> [String] { recorded }
}
