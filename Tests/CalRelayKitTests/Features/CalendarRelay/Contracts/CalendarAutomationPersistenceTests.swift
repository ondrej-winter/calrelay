import CalRelayKit
import Foundation

enum CalendarAutomationPersistenceTests {
    static func runAll() async throws {
        try testBindingIsSemanticVersionedAndOpaque()
        try testRuntimeDescriptionsAndAttentionOutputRemainOpaque()
        try await testAutomaticOperationPersistsAndNotifiesWithoutSensitiveInputs()
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
        try expect(
            binding.debugDescription == binding.description,
            "Opaque authorization debug output must not expose its digest or inputs")
    }

    private static func testRuntimeDescriptionsAndAttentionOutputRemainOpaque() throws {
        let settings = sensitiveSettings()
        let calendars = physicalCalendars()
        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: settings, resolvedCalendars: calendars, policyVersion: .current)
        let identityOutputs = [
            binding.description, binding.debugDescription, calendars.map(\.description).joined(separator: "\n"),
            calendars.map(\.debugDescription).joined(separator: "\n")
        ]

        for output in identityOutputs {
            try expect(!output.contains("v1:"), "Runtime output must not display an opaque identity value")
            for prohibited in bindingProhibitedValues() {
                try expect(!output.contains(prohibited), "Runtime identity output disclosed prohibited value: \(prohibited)")
            }
        }

        for reason in [
            CalendarAutomationAttentionReason.schedulingPaused, .standingAuthorizationRequired, .launchAtLoginUnavailable,
            .configurationUnavailable, .migrationPending, .calendarAccessUnavailable, .topologyNotReady,
            .partialMutation, .transientFailure, .freshnessOverdue
        ] {
            let notification = CalendarAutomationAttentionNotification(reason: reason)
            try expect(notification.title == "CalRelay needs attention", "Attention title should remain generic")
            try expect(!notification.body.isEmpty, "Attention notification should retain actionable aggregate guidance")
        }
    }

    private static func testAutomaticOperationPersistsAndNotifiesWithoutSensitiveInputs() async throws {
        let fixture = try AutomationPrivacyOperationFixture()
        let defaultsFixture = defaultsFixture()
        defer {
            defaultsFixture.defaults.removePersistentDomain(forName: defaultsFixture.suiteName)
            try? FileManager.default.removeItem(at: fixture.configurationDirectory)
        }
        let store = UserDefaultsCalendarAutomationStateStore(
            suiteName: defaultsFixture.suiteName, key: defaultsFixture.key)
        let binding = CalendarStandingAuthorizationBinding.derive(
            settings: fixture.settings, resolvedCalendars: [fixture.hub.id, fixture.work.id], policyVersion: .current)
        try await store.saveState(
            CalendarAutomationPersistentState(
                schedulingPreference: .enabled, standingAuthorization: binding,
                operationalStatus: CalendarAutomationOperationalStatus(
                    lastAttemptAt: fixture.now.addingTimeInterval(-300), latestOutcome: .partialMutation,
                    confirmedCounts: .zero,
                    retryState: .scheduled(attempt: 3, nextAttemptAt: fixture.now),
                    freshness: CalendarAutomationFreshnessMetadata(lastSuccessAt: nil, nextNominalRunAt: nil))))
        let calendarStore = AutomationPrivacyFailureStore(fixture: fixture)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let useCase = CalendarAutomaticReconciliationUseCase(
            settingsProvider: FileCalendarRelaySettingsProvider(selectedFile: fixture.selectedConfigurationFile),
            authorizationStatus: TestCalendarAuthorizationStatus(), calendarStore: calendarStore, stateStore: store,
            configurationChanges: CalendarConfigurationChangeTracker(), now: { fixture.now }, calendar: calendar)

        let result = try await useCase.run(kind: .retry)
        let persisted = await store.loadState()

        try expect(result.outcome == .partialMutation, "The protected operation should reach aggregate partial outcome")
        try expect(result.confirmedCounts == .zero, "Failed first mutation should persist only aggregate zero counts")
        try expect(result.retryState == .none, "An exhausted retry should expose an attention-worthy aggregate state")
        try expect(await calendarStore.mutationAttemptCount() == 1, "The real operation should consume the protected event plan")
        try expect(
            persisted.operationalStatus.latestOutcome == .partialMutation
                && persisted.operationalStatus.confirmedCounts == .zero
                && persisted.operationalStatus.retryState == .none,
            "The real automatic operation should persist only its allowlisted aggregate outcome")
        let reason = CalendarAutomationAttentionPolicy().reason(
            schedulingPreference: persisted.schedulingPreference,
            hasStandingAuthorization: persisted.standingAuthorization != nil, launchAtLoginHealthy: true,
            operationalStatus: persisted.operationalStatus, now: fixture.now)
        try expect(reason == .partialMutation, "The persisted aggregate outcome should drive partial-mutation attention")
        let notification = CalendarAutomationAttentionNotification(reason: reason!)
        let runtimeOutputs = [
            String(reflecting: result), String(reflecting: persisted.operationalStatus), notification.title,
            notification.body
        ]
        for output in runtimeOutputs {
            for prohibited in fixture.protectedValues {
                try expect(!output.contains(prohibited), "Automatic output disclosed protected value: \(prohibited)")
            }
        }

        guard let data = defaultsFixture.defaults.data(forKey: defaultsFixture.key),
            let payload = String(data: data, encoding: .utf8)
        else { throw TestFailure("Expected encoded automation state") }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let storedState = root["state"] as? [String: Any],
            let storedBinding = storedState["standingAuthorization"] as? String
        else { throw TestFailure("Expected an opaque standing-authorization value") }
        let prefix = "v1:"
        let digest = storedBinding.dropFirst(prefix.count)
        try expect(
            storedBinding.hasPrefix(prefix) && digest.count == 64
                && digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
            "Persisted authorization must use only the versioned opaque digest representation")
        try expect(
            payload.contains("partialMutation") && payload.contains("confirmedCreates")
                && payload.contains("confirmedDeletes"),
            "Serialized state should retain the approved aggregate category and count fields")
        for prohibited in fixture.protectedValues {
            try expect(!payload.contains(prohibited), "Persisted state disclosed protected value: \(prohibited)")
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

    private static func bindingProhibitedValues() -> [String] {
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

private struct AutomationPrivacyOperationFixture: Sendable {
    let now = Date(timeIntervalSince1970: 10_000)
    let rawConfigurationFragment = "RAW_CONFIGURATION_FRAGMENT_SENTINEL_AUTOMATION"
    let eventID = "EVENT_ID_SENTINEL_AUTOMATION"
    let eventTitle = "EVENT_TITLE_SENTINEL_AUTOMATION"
    let hubCalendarID = "CALENDAR_ID_SENTINEL_AUTOMATION_HUB"
    let workCalendarID = "CALENDAR_ID_SENTINEL_AUTOMATION_WORK"
    let hub = RelayCalendar(
        id: "CALENDAR_ID_SENTINEL_AUTOMATION_HUB", title: "CALENDAR_TITLE_SENTINEL_AUTOMATION_HUB",
        sourceTitle: "SOURCE_SELECTOR_SENTINEL_AUTOMATION_HUB", isWritable: true)
    let work = RelayCalendar(
        id: "CALENDAR_ID_SENTINEL_AUTOMATION_WORK", title: "CALENDAR_TITLE_SENTINEL_AUTOMATION_WORK",
        sourceTitle: "SOURCE_SELECTOR_SENTINEL_AUTOMATION_WORK", isWritable: true)
    let configurationDirectory: URL
    let selectedConfigurationFile: SelectedConfigurationFile

    init() throws {
        configurationDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: configurationDirectory, withIntermediateDirectories: true)
        let file = configurationDirectory.appendingPathComponent("config.yaml")
        let rawConfigurationFragment = "RAW_CONFIGURATION_FRAGMENT_SENTINEL_AUTOMATION"
        let yaml = """
            # \(rawConfigurationFragment)
            hubCalendar:
              sourceTitle: "SOURCE_SELECTOR_SENTINEL_AUTOMATION_HUB"
              calendarTitle: "CALENDAR_TITLE_SENTINEL_AUTOMATION_HUB"
            personalPrefix: "[PERSONAL_MARKER_SENTINEL_AUTOMATION]"
            syncWindowDays: 1
            workCalendars:
              - name: "CONFIGURED_ROLE_SENTINEL_AUTOMATION"
                prefix: "[WORK_MARKER_SENTINEL_AUTOMATION]"
                calendar:
                  sourceTitle: "SOURCE_SELECTOR_SENTINEL_AUTOMATION_WORK"
                  calendarTitle: "CALENDAR_TITLE_SENTINEL_AUTOMATION_WORK"
            """
        try yaml.write(to: file, atomically: true, encoding: .utf8)
        selectedConfigurationFile = SelectedConfigurationFile(
            path: file.path, displayPath: file.path, source: .explicitOverride)
    }

    var settings: CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hub.sourceTitle, calendarTitle: hub.title)),
            personalPrefix: "[PERSONAL_MARKER_SENTINEL_AUTOMATION]", syncWindowDays: 1,
            workCalendars: [
                WorkCalendarSettings(
                    name: "CONFIGURED_ROLE_SENTINEL_AUTOMATION", prefix: "[WORK_MARKER_SENTINEL_AUTOMATION]",
                    calendar: CalendarSelector(sourceTitle: work.sourceTitle, calendarTitle: work.title))
            ], legacyMarkers: [])
    }

    var event: CalendarEvent {
        CalendarEvent(
            id: eventID, calendar: CalendarIdentity(id: work.id, title: work.title, sourceTitle: work.sourceTitle),
            title: eventTitle, start: now, end: now.addingTimeInterval(100), isAllDay: false, availability: .busy,
            status: .confirmed)
    }

    var protectedValues: [String] {
        [
            eventID, eventTitle, hubCalendarID, workCalendarID, hub.title, work.title, hub.sourceTitle, work.sourceTitle,
            "PERSONAL_MARKER_SENTINEL_AUTOMATION", "WORK_MARKER_SENTINEL_AUTOMATION",
            rawConfigurationFragment
        ]
    }
}

private struct AutomationPrivacyStoreFailure: Error {}

private actor AutomationPrivacyFailureStore: CalendarStorePort {
    private let fixture: AutomationPrivacyOperationFixture
    private var mutationAttempts = 0

    init(fixture: AutomationPrivacyOperationFixture) { self.fixture = fixture }

    func listCalendars() async throws -> [RelayCalendar] { [fixture.hub, fixture.work] }

    func events(in calendar: CalendarIdentity, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        calendar.id == fixture.work.id ? [fixture.event] : []
    }

    func createEvent(_ event: CalendarEventProjection) async throws {
        mutationAttempts += 1
        throw AutomationPrivacyStoreFailure()
    }

    func deleteEvent(_ event: CalendarEventIdentity) async throws {
        mutationAttempts += 1
        throw AutomationPrivacyStoreFailure()
    }

    func mutationAttemptCount() -> Int { mutationAttempts }
}
