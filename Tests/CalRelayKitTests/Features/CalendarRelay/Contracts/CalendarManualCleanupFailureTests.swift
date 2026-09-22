import CalRelayKit
import Foundation

extension CalendarManualCleanupTests {
    static func runFailureTests() async throws {
        try await testFailuresPreserveConfirmedCounts()
        try await testConfigurationRaceVetoesAllDeletion()
        try await testCancelMissingMarkersAndDeniedAccess()
    }

    private static func testFailuresPreserveConfirmedCounts() async throws {
        let fixture = ManualCleanupFixture()
        for scenario in CleanupFailureScenario.allCases {
            let store = FailingManualCleanupStore(fixture: fixture, scenario: scenario)
            let useCase = fixture.useCase(
                provider: ManualApplySettingsProvider(settings: fixture.settings), store: store)
            let review = try await useCase.review()
            do {
                _ = try await useCase.confirm(reviewID: review.id)
                throw TestFailure("Cleanup failure must not be reported as success")
            } catch let error as CalendarManualCleanupError {
                try expect(
                    error == scenario.expectedError, "Cleanup must retain confirmed counts and safe failure category")
                let output = CalendarManualCleanupFormatter.formatFailure(error)
                try expect(
                    output.contains("no rollback") && output.contains("fresh cleanup plan"),
                    "Report explicit manual recovery")
                for forbidden in ["secret", "Example", "Test Source", "Test Hub", "test-hub", "test-legacy", "[OLD]"] {
                    try expect(
                        !output.contains(forbidden),
                        "Failure presentation must not leak review, selector or framework content")
                }
            }
            try expect(
                await store.attemptedDeletes() == scenario.attempts,
                "Never retry, verify or continue after mutation failure")
            do {
                _ = try await useCase.confirm(reviewID: review.id)
                throw TestFailure("Failure must consume confirmation")
            } catch CalendarManualCleanupError.reviewRequired {}
        }
    }

    private static func testConfigurationRaceVetoesAllDeletion() async throws {
        let fixture = ManualCleanupFixture()
        for last in [
            Result.success(fixture.settings(markers: ["[OTHER]"])), .success(fixture.settings(markers: [])),
            .failure(CalendarRelaySettingsProviderError.missing(displayPath: "secret")),
            .failure(.invalid(displayPath: "secret"))
        ] {
            let provider = CleanupSequenceSettingsProvider(loads: [
                .success(fixture.settings), .success(fixture.settings), last
            ])
            let store = fixture.store()
            let useCase = fixture.useCase(provider: provider, store: store)
            let review = try await useCase.review()
            do {
                _ = try await useCase.confirm(reviewID: review.id)
                throw TestFailure("Configuration change after snapshot must prevent deletion")
            } catch CalendarManualCleanupError.configurationChanged {} catch CalendarManualCleanupError.failed(
                confirmedDeletions: 0, category: .configurationUnavailable)
            {}
            try expect(await store.deletedEvents().isEmpty, "Never mutate with stale or invalid configuration")
            do {
                _ = try await useCase.confirm(reviewID: review.id)
                throw TestFailure("A configuration-race failure must consume cleanup confirmation")
            } catch CalendarManualCleanupError.reviewRequired {}
        }
    }

    private static func testCancelMissingMarkersAndDeniedAccess() async throws {
        let fixture = ManualCleanupFixture()
        let store = fixture.store()
        let provider = ManualApplySettingsProvider(settings: fixture.settings)
        let useCase = fixture.useCase(provider: provider, store: store)
        let review = try await useCase.review()
        await useCase.cancelReview()
        do {
            _ = try await useCase.confirm(reviewID: review.id)
            throw TestFailure("Cancelled review cannot authorize cleanup")
        } catch CalendarManualCleanupError.reviewRequired {}
        await provider.replace(fixture.settings(markers: []))
        do {
            _ = try await useCase.review()
            throw TestFailure("Cleanup requires migration tombstones")
        } catch CalendarManualCleanupError.failed(confirmedDeletions: 0, category: .legacyMarkersRequired) {}
        await provider.replace(fixture.settings)
        let denied = CalendarManualCleanupUseCase(
            settingsProvider: provider, authorizationStatus: TestCalendarAuthorizationStatus(state: .denied),
            calendarStore: store)
        do {
            _ = try await denied.review()
            throw TestFailure("Denied access must block cleanup")
        } catch CalendarManualCleanupError.failed(confirmedDeletions: 0, category: .authorizationUnavailable(.denied)) {
        }
        try expect(
            await store.listCalendarsCallCount() == 1,
            "Invalid configuration and denied access must fail before inventory")
        try expect(await store.deletedEvents().isEmpty, "Cancelled or unauthorized operations must not mutate")
    }
}

private enum CleanupFailureScenario: CaseIterable, Sendable {
    case preflight, secondDelete, cancellation, verificationRead, remaining

    var attempts: Int {
        switch self {
        case .preflight: 0
        case .secondDelete, .cancellation: 2
        case .verificationRead, .remaining: 3
        }
    }

    var expectedError: CalendarManualCleanupError {
        switch self {
        case .preflight: .failed(confirmedDeletions: 0, category: .preflightFailed)
        case .secondDelete: .failed(confirmedDeletions: 1, category: .deletionFailed)
        case .cancellation: .failed(confirmedDeletions: 1, category: .cancelled)
        case .verificationRead: .failed(confirmedDeletions: 3, category: .verificationReadFailed)
        case .remaining: .failed(confirmedDeletions: 3, category: .remainingMatches(3))
        }
    }
}

private actor FailingManualCleanupStore: CalendarStorePort {
    let fixture: ManualCleanupFixture
    let scenario: CleanupFailureScenario
    private var snapshots = 0
    private var attempts = 0
    init(fixture: ManualCleanupFixture, scenario: CleanupFailureScenario) {
        self.fixture = fixture
        self.scenario = scenario
    }
    func listCalendars() async throws -> [RelayCalendar] {
        snapshots += 1
        return [fixture.hub, fixture.work]
    }
    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        if calendar.id == fixture.work.id,
            (snapshots == 2 && scenario == .preflight) || (snapshots == 3 && scenario == .verificationRead)
        {
            throw TestFailure("secret read error")
        }
        guard calendar.id == fixture.hub.id else { return [] }
        return (0..<3).map {
            fixture.event(id: "test-legacy-\($0)", start: fixture.now.addingTimeInterval(Double($0) * 200))
        }
    }
    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        attempts += 1
        if attempts == 2, scenario == .secondDelete { throw TestFailure("secret delete error") }
        if attempts == 2, scenario == .cancellation { throw CancellationError() }
    }
    func createEvent(_ event: CalendarEventProjection) async throws { throw TestFailure("Cleanup must not create") }
    func attemptedDeletes() -> Int { attempts }
}

actor CleanupSequenceSettingsProvider: CalendarRelaySettingsProvider {
    private var loads: [Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>]
    init(loads: [Result<CalendarRelaySettings, CalendarRelaySettingsProviderError>]) { self.loads = loads }
    func loadSettings() async throws -> LoadedCalendarRelaySettings {
        guard !loads.isEmpty else { throw TestFailure("Unexpected settings read") }
        return LoadedCalendarRelaySettings(displayPath: "test", settings: try loads.removeFirst().get())
    }
}
