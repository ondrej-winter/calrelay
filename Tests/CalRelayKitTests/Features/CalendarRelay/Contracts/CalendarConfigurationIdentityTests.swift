import CalRelayKit

enum CalendarConfigurationIdentityTests {
    static func runAll() throws {
        try testEquivalentYAMLAndDiagnosticNamesDeriveSameBinding()
        try testEveryMutationRelevantConfigurationChangeDerivesDifferentBinding()
        try testResolvedTopologyOrderAndContinuityDeriveDifferentBindings()
        try testPolicyVersionIsExplicitAndPresentationChangesRemainEquivalent()
    }

    private static func testEquivalentYAMLAndDiagnosticNamesDeriveSameBinding() throws {
        let canonicalYAML = """
            hubCalendar:
              sourceTitle: 'Private Account'
              calendarTitle: 'Secret Hub'
            personalPrefix: '[HOME_SECRET]'
            syncWindowDays: 100
            workCalendars:
              - name: 'Sensitive Employer'
                prefix: '[WORK_SECRET]'
                calendar:
                  sourceTitle: 'Corporate Account'
                  calendarTitle: 'Private Work'
              - name: 'Sensitive Client'
                prefix: '[CLIENT_SECRET]'
                calendar:
                  sourceTitle: 'Client Account'
                  calendarTitle: 'Private Client'
            legacyMarkers:
              - '[OLD_ONE]'
              - '[OLD_TWO]'
            """
        let equivalentYAML = """
            # Comments, key order, scalar style, omitted defaults, and diagnostic names are not mutation semantics.
            legacyMarkers: ["[OLD_TWO]", '[OLD_ONE]']
            workCalendars:
              - {calendar: {calendarTitle: Private Work, sourceTitle: Corporate Account}, name: Renamed Employer, prefix: '[WORK_SECRET]'}
              - prefix: '[CLIENT_SECRET]'
                name: Renamed Client
                calendar: {sourceTitle: Client Account, calendarTitle: Private Client}
            personalPrefix: "[HOME_SECRET]"
            hubCalendar: {calendarTitle: Secret Hub, sourceTitle: Private Account}
            """
        let canonical = try YAMLCalendarRelaySettingsLoader.load(canonicalYAML)
        let equivalent = try YAMLCalendarRelaySettingsLoader.load(equivalentYAML)

        try expect(
            binding(settings: canonical) == binding(settings: equivalent),
            "Representation-only YAML, explicit defaults, diagnostic names, and legacy-marker order must not change identity"
        )
    }

    private static func testEveryMutationRelevantConfigurationChangeDerivesDifferentBinding() throws {
        let original = settings()
        let originalBinding = binding(settings: original)
        let originalWork = original.workCalendars
        let changes = [
            IdentityChange(name: "hub source", settings: settings(hubSource: "Replacement Private Account")),
            IdentityChange(name: "hub title", settings: settings(hubTitle: "Replacement Secret Hub")),
            IdentityChange(name: "personal marker", settings: settings(personalMarker: "[HOME_NEXT]")),
            IdentityChange(name: "effective window", settings: settings(syncWindowDays: 101)),
            IdentityChange(
                name: "work source",
                settings: settings(workCalendars: [
                    work(
                        name: originalWork[0].name, marker: originalWork[0].prefix,
                        source: "Replacement Corporate Account", title: originalWork[0].calendar.calendarTitle),
                    originalWork[1]
                ])),
            IdentityChange(
                name: "work title",
                settings: settings(workCalendars: [
                    work(
                        name: originalWork[0].name, marker: originalWork[0].prefix,
                        source: originalWork[0].calendar.sourceTitle, title: "Replacement Private Work"),
                    originalWork[1]
                ])),
            IdentityChange(
                name: "work marker",
                settings: settings(workCalendars: [
                    work(
                        name: originalWork[0].name, marker: "[WORK_NEXT]", source: originalWork[0].calendar.sourceTitle,
                        title: originalWork[0].calendar.calendarTitle), originalWork[1]
                ])),
            IdentityChange(
                name: "work declaration order", settings: settings(workCalendars: Array(originalWork.reversed()))),
            IdentityChange(
                name: "work role addition",
                settings: settings(
                    workCalendars: originalWork + [
                        work(
                            name: "Sensitive Partner", marker: "[PARTNER_SECRET]", source: "Partner Account",
                            title: "Private Partner")
                    ])),
            IdentityChange(name: "work role removal", settings: settings(workCalendars: [originalWork[0]])),
            IdentityChange(
                name: "legacy marker addition",
                settings: settings(legacyMarkers: ["[OLD_ONE]", "[OLD_TWO]", "[OLD_THREE]"])),
            IdentityChange(name: "legacy marker removal", settings: settings(legacyMarkers: ["[OLD_ONE]"]))
        ]

        for change in changes {
            try SettingsValidator.validate(change.settings)
            try expect(
                binding(settings: change.settings) != originalBinding,
                "A mutation-relevant \(change.name) change must derive a different authorization binding")
        }
    }

    private static func testResolvedTopologyOrderAndContinuityDeriveDifferentBindings() throws {
        let originalSettings = settings()
        let originalTopology = topology()
        let originalBinding = binding(settings: originalSettings, topology: originalTopology)
        let topologyChanges = [
            TopologyChange(
                name: "hub physical identity",
                topology: [physical("replacement-hub"), originalTopology[1], originalTopology[2]]),
            TopologyChange(
                name: "work physical identity",
                topology: [originalTopology[0], physical("replacement-work"), originalTopology[2]]),
            TopologyChange(
                name: "role-to-calendar mapping and role order",
                topology: [originalTopology[0], originalTopology[2], originalTopology[1]]),
            TopologyChange(
                name: "unprovable provider continuity",
                topology: [originalTopology[0], physical("recreated-work"), originalTopology[2]]),
            TopologyChange(name: "removed role", topology: [originalTopology[0], originalTopology[1]]),
            TopologyChange(name: "added role", topology: originalTopology + [physical("additional-role")])
        ]

        for change in topologyChanges {
            try expect(
                binding(settings: originalSettings, topology: change.topology) != originalBinding,
                "A changed \(change.name) must derive a different authorization binding")
        }

        for reference in originalTopology {
            try expect(
                reference.description == "<opaque-physical-calendar-reference>",
                "Physical calendar identity must remain opaque in visible descriptions")
            try expect(
                reference.debugDescription == reference.description,
                "Physical calendar identity must remain opaque in debug descriptions")
        }
    }

    private static func testPolicyVersionIsExplicitAndPresentationChangesRemainEquivalent() throws {
        let originalSettings = settings()
        let renamedWork = originalSettings.workCalendars.enumerated().map { index, entry in
            work(
                name: "Presentation Name \(index)", marker: entry.prefix, source: entry.calendar.sourceTitle,
                title: entry.calendar.calendarTitle)
        }
        let presentationOnlySettings = settings(workCalendars: renamedWork)
        let original = binding(settings: originalSettings)

        try expect(
            CalendarReconciliationPolicyVersion.current.rawValue == "ordinary-reconciliation-policy-v2",
            "Review this policy checkpoint whenever ordinary executable actions, exact targets, or order change")
        try expect(
            binding(settings: presentationOnlySettings) == original,
            "Presentation-only diagnostic names must not require a policy or authorization change")
        try expect(
            binding(
                settings: originalSettings,
                policyVersion: CalendarReconciliationPolicyVersion(rawValue: "ordinary-reconciliation-policy-v1"))
                != original, "A product-controlled reconciliation-policy version change must derive a different binding"
        )
    }

    private static func binding(
        settings: CalendarRelaySettings, topology: [PhysicalCalendarReference] = topology(),
        policyVersion: CalendarReconciliationPolicyVersion = .current
    ) -> CalendarStandingAuthorizationBinding {
        CalendarStandingAuthorizationBinding.derive(
            settings: settings, resolvedCalendars: topology, policyVersion: policyVersion)
    }

    private static func settings(
        hubSource: String = "Private Account", hubTitle: String = "Secret Hub",
        personalMarker: String = "[HOME_SECRET]", syncWindowDays: Int = 100,
        workCalendars: [WorkCalendarSettings]? = nil, legacyMarkers: [String] = ["[OLD_ONE]", "[OLD_TWO]"]
    ) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: hubSource, calendarTitle: hubTitle)),
            personalPrefix: personalMarker, syncWindowDays: syncWindowDays,
            workCalendars: workCalendars ?? defaultWorkCalendars(), legacyMarkers: legacyMarkers)
    }

    private static func defaultWorkCalendars() -> [WorkCalendarSettings] {
        [
            work(
                name: "Sensitive Employer", marker: "[WORK_SECRET]", source: "Corporate Account", title: "Private Work"),
            work(name: "Sensitive Client", marker: "[CLIENT_SECRET]", source: "Client Account", title: "Private Client")
        ]
    }

    private static func work(name: String, marker: String, source: String, title: String) -> WorkCalendarSettings {
        WorkCalendarSettings(
            name: name, prefix: marker, calendar: CalendarSelector(sourceTitle: source, calendarTitle: title))
    }

    private static func topology() -> [PhysicalCalendarReference] {
        [physical("eventkit-hub-secret-id"), physical("eventkit-work-secret-id"), physical("eventkit-client-secret-id")]
    }

    private static func physical(_ providerIdentifier: String) -> PhysicalCalendarReference {
        PhysicalCalendarReference(providerIdentifier: providerIdentifier)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct IdentityChange {
    let name: String
    let settings: CalendarRelaySettings
}

private struct TopologyChange {
    let name: String
    let topology: [PhysicalCalendarReference]
}
