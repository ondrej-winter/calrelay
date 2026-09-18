import CalRelayKit
import Foundation

enum CalendarAutomationPersistenceTests {
    static func runAll() async throws {
        try testBindingIsSemanticVersionedAndOpaque()
        try await testPersistentStateRoundTripsWithoutDisclosingSensitiveInputs()
        try await testCorruptAndUnsupportedStateRecoversWithoutAuthorization()
    }

    private static func testBindingIsSemanticVersionedAndOpaque() throws {
        let settings = sensitiveSettings()
        let calendars = physicalCalendars()
        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: settings, resolvedCalendars: calendars, policyVersion: .current)
        let renamed = CalendarStandingAuthorizationBinding.derive(
            settings: settingsWithDiagnosticNamesChanged(settings), resolvedCalendars: calendars,
            policyVersion: .current)
        let reorderedLegacyMarkers = CalendarStandingAuthorizationBinding.derive(
            settings: settingsWithReorderedLegacyMarkers(settings), resolvedCalendars: calendars,
            policyVersion: .current)
        let reorderedWork = CalendarStandingAuthorizationBinding.derive(
            settings: settingsWithReorderedWorkCalendars(settings),
            resolvedCalendars: [calendars[0], calendars[2], calendars[1]], policyVersion: .current)
        let changedTopology = CalendarStandingAuthorizationBinding.derive(
            settings: settings,
            resolvedCalendars: [
                calendars[0], PhysicalCalendarReference(providerIdentifier: "replacement-work"), calendars[2]
            ], policyVersion: .current)
        let changedPolicy = CalendarStandingAuthorizationBinding.derive(
            settings: settings, resolvedCalendars: calendars,
            policyVersion: CalendarReconciliationPolicyVersion(rawValue: "ordinary-policy-next"))

        try expect(binding == renamed, "Diagnostic work-calendar names must not change authorization identity")
        try expect(binding == reorderedLegacyMarkers, "Legacy-marker set order must not change authorization identity")
        try expect(binding != reorderedWork, "Work-calendar declaration order must change authorization identity")
        try expect(binding != changedTopology, "Physical calendar continuity must change authorization identity")
        try expect(binding != changedPolicy, "Reconciliation policy changes must change authorization identity")
        try expect(
            binding.description == "<opaque-standing-authorization-binding>",
            "Opaque authorization identity must not expose its digest or inputs")
    }

    private static func testPersistentStateRoundTripsWithoutDisclosingSensitiveInputs() async throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: sensitiveSettings(), resolvedCalendars: physicalCalendars(), policyVersion: .current)
        let state = CalendarAutomationPersistentState(
            schedulingPreference: .enabled, standingAuthorization: binding,
            operationalStatus: CalendarAutomationOperationalStatus(
                lastAttemptAt: Date(timeIntervalSince1970: 1_000), latestOutcome: .partialMutation,
                confirmedCounts: CalendarAutomationMutationCounts(confirmedCreates: 2, confirmedDeletes: 3),
                retryState: .scheduled(attempt: 2, nextAttemptAt: Date(timeIntervalSince1970: 1_300)),
                freshness: CalendarAutomationFreshnessMetadata(
                    lastSuccessAt: Date(timeIntervalSince1970: 900),
                    nextNominalRunAt: Date(timeIntervalSince1970: 1_800))))
        let store = UserDefaultsCalendarAutomationStateStore(suiteName: fixture.suiteName, key: fixture.key)

        try await store.saveState(state)

        try expect(await store.loadState() == state, "Allowlisted automation state should round-trip")
        guard let data = fixture.defaults.data(forKey: fixture.key), let payload = String(data: data, encoding: .utf8)
        else { throw TestFailure("Expected encoded automation state") }
        for prohibited in prohibitedValues() {
            try expect(!payload.contains(prohibited), "Persisted state disclosed prohibited value: \(prohibited)")
        }
    }

    private static func testCorruptAndUnsupportedStateRecoversWithoutAuthorization() async throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let store = UserDefaultsCalendarAutomationStateStore(suiteName: fixture.suiteName, key: fixture.key)

        fixture.defaults.set(Data("not-json".utf8), forKey: fixture.key)
        try expect(await store.loadState() == .empty, "Corrupt state should recover to a safe empty state")
        try expect(fixture.defaults.object(forKey: fixture.key) == nil, "Corrupt state should be removed")

        try await store.saveState(.empty)
        guard let supportedData = fixture.defaults.data(forKey: fixture.key),
            let supportedPayload = String(data: supportedData, encoding: .utf8)
        else { throw TestFailure("Expected a supported persisted envelope") }
        fixture.defaults.set(
            Data(supportedPayload.replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":999"#).utf8),
            forKey: fixture.key)
        try expect(await store.loadState() == .empty, "Unsupported storage versions must not reactivate authorization")
        try expect(fixture.defaults.object(forKey: fixture.key) == nil, "Unsupported state should be removed")
    }

    private static func sensitiveSettings() -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: "Private Account", calendarTitle: "Secret Hub")),
            personalPrefix: "[HOME_SECRET]", syncWindowDays: 37,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Sensitive Employer", prefix: "[WORK_SECRET]",
                    calendar: CalendarSelector(sourceTitle: "Corporate Account", calendarTitle: "Private Work")),
                WorkCalendarSettings(
                    name: "Sensitive Client", prefix: "[CLIENT_SECRET]",
                    calendar: CalendarSelector(sourceTitle: "Client Account", calendarTitle: "Private Client"))
            ], legacyMarkers: ["[OLD_ONE]", "[OLD_TWO]"])
    }

    private static func settingsWithDiagnosticNamesChanged(_ settings: CalendarRelaySettings) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: settings.hubCalendar, personalPrefix: settings.personalPrefix,
            syncWindowDays: settings.syncWindowDays,
            workCalendars: settings.workCalendars.enumerated().map { index, work in
                WorkCalendarSettings(name: "Renamed \(index)", prefix: work.prefix, calendar: work.calendar)
            }, legacyMarkers: settings.legacyMarkers)
    }

    private static func settingsWithReorderedLegacyMarkers(_ settings: CalendarRelaySettings) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: settings.hubCalendar, personalPrefix: settings.personalPrefix,
            syncWindowDays: settings.syncWindowDays, workCalendars: settings.workCalendars,
            legacyMarkers: settings.legacyMarkers.reversed())
    }

    private static func settingsWithReorderedWorkCalendars(_ settings: CalendarRelaySettings) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: settings.hubCalendar, personalPrefix: settings.personalPrefix,
            syncWindowDays: settings.syncWindowDays, workCalendars: settings.workCalendars.reversed(),
            legacyMarkers: settings.legacyMarkers)
    }

    private static func physicalCalendars() -> [PhysicalCalendarReference] {
        [
            PhysicalCalendarReference(providerIdentifier: "eventkit-hub-secret-id"),
            PhysicalCalendarReference(providerIdentifier: "eventkit-work-secret-id"),
            PhysicalCalendarReference(providerIdentifier: "eventkit-client-secret-id")
        ]
    }

    private static func prohibitedValues() -> [String] {
        [
            "Private Account", "Secret Hub", "HOME_SECRET", "Sensitive Employer", "WORK_SECRET", "Corporate Account",
            "Private Work", "Sensitive Client", "CLIENT_SECRET", "Client Account", "Private Client", "OLD_ONE",
            "OLD_TWO", "eventkit-hub-secret-id", "eventkit-work-secret-id", "eventkit-client-secret-id"
        ]
    }

    private static func defaultsFixture() -> AutomationDefaultsFixture {
        let suiteName = "CalendarAutomationPersistenceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated defaults")
        }
        return AutomationDefaultsFixture(defaults: defaults, suiteName: suiteName, key: "automation-state")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct AutomationDefaultsFixture {
    let defaults: UserDefaults
    let suiteName: String
    let key: String
}
