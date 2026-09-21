import CalRelayKit

enum CalendarConfigurationSchemaTests {
    static func runAll() throws {
        try testParsesNormativeSchemaAndPreservesDeclarationOrder()
        try testAppliesOptionalDefaults()
        try testAcceptsEquivalentYAMLRepresentations()
        try testRejectsInvalidStructuresWithoutDisclosure()
        try testRejectsMissingFieldsAndEmptyWorkCalendars()
        try testRejectsUnknownKeysAtEveryMappingLevel()
        try testRejectsDuplicateKeysAtEveryMappingLevel()
        try testAcceptsCompleteMarkerGrammarCaseSensitively()
        try testRejectsMalformedMarkersWithoutDisclosure()
        try testRejectsEveryMarkerCollisionRelationshipWithoutDisclosure()
        try testAcceptsSyncWindowBoundaries()
        try testRejectsInvalidSyncWindowValuesAndTypes()
        try testRejectsHubWorkSelectorCollisionWithRoleIndexes()
        try testRejectsWorkWorkSelectorCollisionWithRoleIndexes()
        try testAcceptsStructurallyDistinctSelectors()
    }

    private static func testParsesNormativeSchemaAndPreservesDeclarationOrder() throws {
        let yaml = makeYAML(
            syncWindowDays: "45",
            workCalendars: [
                WorkYAML("First Work Role", "[FIRST]", "First Work Source", "First Work"),
                WorkYAML("Second Work Role", "[SECOND]", "Second Work Source", "Second Work")
            ], legacyMarkers: ["[OLD_FIRST]", "[OLD_SECOND]"])

        let settings = try YAMLCalendarRelaySettingsLoader.load(yaml)

        try expect(
            settings
                == CalendarRelaySettings(
                    hubCalendar: HubCalendarSettings(
                        calendar: CalendarSelector(sourceTitle: "Test Hub Source", calendarTitle: "Test Hub")),
                    personalPrefix: "[ME]", syncWindowDays: 45,
                    workCalendars: [
                        WorkCalendarSettings(
                            name: "First Work Role", prefix: "[FIRST]",
                            calendar: CalendarSelector(sourceTitle: "First Work Source", calendarTitle: "First Work")),
                        WorkCalendarSettings(
                            name: "Second Work Role", prefix: "[SECOND]",
                            calendar: CalendarSelector(sourceTitle: "Second Work Source", calendarTitle: "Second Work"))
                    ], legacyMarkers: ["[OLD_FIRST]", "[OLD_SECOND]"]),
            "Normative YAML should decode exactly and preserve declaration order")
    }

    private static func testAppliesOptionalDefaults() throws {
        let settings = try YAMLCalendarRelaySettingsLoader.load(makeYAML())

        try expect(settings.syncWindowDays == 100, "Omitted syncWindowDays should default to 100")
        try expect(settings.legacyMarkers.isEmpty, "Omitted legacyMarkers should default to an empty sequence")
    }

    private static func testAcceptsEquivalentYAMLRepresentations() throws {
        let yaml = """
            # Mapping order, comments, quoting, and flow syntax are representation-only.
            workCalendars: [{calendar: {calendarTitle: Test Work, sourceTitle: 'Test Work Source'}, prefix: '[WORK]', name: Test Work Role}]
            legacyMarkers: ['[OLD]']
            syncWindowDays: 100
            personalPrefix: '[ME]'
            hubCalendar: {calendarTitle: Test Hub, sourceTitle: Test Hub Source}
            """

        let settings = try YAMLCalendarRelaySettingsLoader.load(yaml)

        try expect(
            settings == expectedSettings(legacyMarkers: ["[OLD]"]),
            "Supported equivalent YAML representations should decode to the same settings")
    }

    private static func testRejectsInvalidStructuresWithoutDisclosure() throws {
        let base = makeYAML()
        let cases: [(String, String)] = [
            ("empty document", ""), ("non-mapping root", "[PRIVATE_ROOT_VALUE]"),
            ("malformed YAML", "hubCalendar: [PRIVATE_MALFORMED"),
            (
                "wrong hub type",
                base.replacingOccurrences(
                    of: "hubCalendar:\n  sourceTitle: 'Test Hub Source'\n  calendarTitle: 'Test Hub'",
                    with: "hubCalendar: PRIVATE_WRONG_HUB")
            ),
            (
                "wrong personal marker type",
                base.replacingOccurrences(of: "personalPrefix: '[ME]'", with: "personalPrefix: 123")
            ),
            (
                "wrong hub source type",
                base.replacingOccurrences(of: "  sourceTitle: 'Test Hub Source'", with: "  sourceTitle: 123")
            ),
            (
                "wrong hub title type",
                base.replacingOccurrences(of: "  calendarTitle: 'Test Hub'", with: "  calendarTitle: true")
            ),
            (
                "wrong work collection type",
                base.replacingOccurrences(of: workBlock, with: "workCalendars: PRIVATE_WRONG_WORK_LIST")
            ),
            (
                "wrong work entry type",
                base.replacingOccurrences(of: workBlock, with: "workCalendars:\n  - PRIVATE_WRONG_WORK_ENTRY")
            ),
            (
                "wrong work selector type",
                base.replacingOccurrences(
                    of: "    calendar:\n      sourceTitle: 'Test Work Source'\n      calendarTitle: 'Test Work'",
                    with: "    calendar: PRIVATE_WRONG_SELECTOR")
            ),
            (
                "wrong work name type",
                base.replacingOccurrences(of: "  - name: 'Test Work Role'", with: "  - name: 123")
            ),
            (
                "wrong work marker type",
                base.replacingOccurrences(of: "    prefix: '[WORK]'", with: "    prefix: false")
            ),
            (
                "wrong work source type",
                base.replacingOccurrences(of: "      sourceTitle: 'Test Work Source'", with: "      sourceTitle: 123")
            ),
            (
                "wrong work title type",
                base.replacingOccurrences(of: "      calendarTitle: 'Test Work'", with: "      calendarTitle: true")
            ), ("wrong legacy collection type", base + "\nlegacyMarkers: PRIVATE_WRONG_LEGACY_LIST"),
            ("wrong legacy marker type", base + "\nlegacyMarkers:\n  - 123"),
            ("explicit null legacy markers", base + "\nlegacyMarkers: null")
        ]

        for (name, invalidYAML) in cases { try expectInvalidConfiguration(invalidYAML, context: name) }
    }

    private static func testRejectsMissingFieldsAndEmptyWorkCalendars() throws {
        let base = makeYAML()
        let cases: [(String, String)] = [
            (
                "missing hub selector",
                base.replacingOccurrences(
                    of: "hubCalendar:\n  sourceTitle: 'Test Hub Source'\n  calendarTitle: 'Test Hub'\n", with: "")
            ), ("missing personal marker", base.replacingOccurrences(of: "personalPrefix: '[ME]'\n", with: "")),
            ("missing work calendars", base.replacingOccurrences(of: workBlock, with: "")),
            ("missing hub source", base.replacingOccurrences(of: "  sourceTitle: 'Test Hub Source'\n", with: "")),
            ("missing hub title", base.replacingOccurrences(of: "  calendarTitle: 'Test Hub'\n", with: "")),
            ("missing work name", base.replacingOccurrences(of: "  - name: 'Test Work Role'\n", with: "  -\n")),
            ("missing work marker", base.replacingOccurrences(of: "    prefix: '[WORK]'\n", with: "")),
            (
                "missing work selector",
                base.replacingOccurrences(
                    of: "    calendar:\n      sourceTitle: 'Test Work Source'\n      calendarTitle: 'Test Work'",
                    with: "")
            ),
            ("missing work source", base.replacingOccurrences(of: "      sourceTitle: 'Test Work Source'\n", with: "")),
            ("missing work title", base.replacingOccurrences(of: "      calendarTitle: 'Test Work'", with: ""))
        ]

        for (name, invalidYAML) in cases { try expectInvalidConfiguration(invalidYAML, context: name) }
        try expectInvalidSettings(
            base.replacingOccurrences(of: workBlock, with: "workCalendars: []"),
            containing: ["At least one work calendar"], context: "empty work calendar list")
    }

    private static func testRejectsUnknownKeysAtEveryMappingLevel() throws {
        let base = makeYAML()
        let cases: [(String, String)] = [
            ("root", base + "\nprivateRootKey: PRIVATE_ROOT_VALUE"),
            (
                "hub selector",
                base.replacingOccurrences(
                    of: "  calendarTitle: 'Test Hub'",
                    with: "  calendarTitle: 'Test Hub'\n  privateHubKey: PRIVATE_HUB_VALUE")
            ),
            (
                "work entry",
                base.replacingOccurrences(
                    of: "    prefix: '[WORK]'", with: "    prefix: '[WORK]'\n    privateWorkKey: PRIVATE_WORK_VALUE")
            ),
            (
                "work selector",
                base.replacingOccurrences(
                    of: "      calendarTitle: 'Test Work'",
                    with: "      calendarTitle: 'Test Work'\n      privateSelectorKey: PRIVATE_SELECTOR_VALUE")
            )
        ]

        for (level, invalidYAML) in cases {
            try expectInvalidConfiguration(invalidYAML, context: "unknown key at \(level) level")
        }
    }

    private static func testRejectsDuplicateKeysAtEveryMappingLevel() throws {
        let base = makeYAML()
        let cases: [(String, String)] = [
            ("root", base + "\npersonalPrefix: '[PRIVATE_ROOT_DUPLICATE]'"),
            (
                "hub selector",
                base.replacingOccurrences(
                    of: "  calendarTitle: 'Test Hub'",
                    with: "  calendarTitle: 'Test Hub'\n  sourceTitle: PRIVATE_HUB_DUPLICATE")
            ),
            (
                "work entry",
                base.replacingOccurrences(
                    of: "    prefix: '[WORK]'", with: "    prefix: '[WORK]'\n    name: PRIVATE_WORK_DUPLICATE")
            ),
            (
                "work selector",
                base.replacingOccurrences(
                    of: "      calendarTitle: 'Test Work'",
                    with: "      calendarTitle: 'Test Work'\n      sourceTitle: PRIVATE_SELECTOR_DUPLICATE")
            )
        ]

        for (level, invalidYAML) in cases {
            try expectInvalidConfiguration(invalidYAML, context: "duplicate key at \(level) level")
        }
    }

    private static func testAcceptsCompleteMarkerGrammarCaseSensitively() throws {
        for marker in ["[A]", "[abc]", "[A0_z-9]"] {
            let settings = try YAMLCalendarRelaySettingsLoader.load(makeYAML(personalPrefix: marker))
            try expect(settings.personalPrefix == marker, "Valid marker \(marker) should be accepted")
        }

        let settings = try YAMLCalendarRelaySettingsLoader.load(
            makeYAML(
                personalPrefix: "[ACME]",
                workCalendars: [WorkYAML("Test Work Role", "[acme]", "Test Work Source", "Test Work")]))
        try expect(
            settings.personalPrefix == "[ACME]" && settings.workCalendars[0].prefix == "[acme]",
            "Marker identity should be case-sensitive")
    }

    private static func testRejectsMalformedMarkersWithoutDisclosure() throws {
        let invalidMarkers = [
            "", "PRIVATE_MARKER", "[PRIVATE_MARKER", "PRIVATE_MARKER]", "x[PRIVATE_MARKER]", "[PRIVATE_MARKER]x",
            "[PRIVATE MARKER]", "[PRIVATE.MARKER]", "[PRIVATE][MARKER]", "[]", "[PRIVÅTE]"
        ]

        for marker in invalidMarkers {
            try expectInvalidSettings(
                makeYAML(personalPrefix: marker), containing: ["Invalid marker"],
                excluding: marker.isEmpty ? [] : [marker], context: "malformed marker \(String(reflecting: marker))")
        }
    }

    private static func testRejectsEveryMarkerCollisionRelationshipWithoutDisclosure() throws {
        let marker = "[PRIVATE_COLLISION]"
        let cases: [(String, String)] = [
            (
                "personal/work",
                makeYAML(
                    personalPrefix: marker,
                    workCalendars: [WorkYAML("Test Work Role", marker, "Test Work Source", "Test Work")])
            ),
            (
                "work/work",
                makeYAML(workCalendars: [
                    WorkYAML("First Work Role", marker, "First Work Source", "First Work"),
                    WorkYAML("Second Work Role", marker, "Second Work Source", "Second Work")
                ])
            ), ("personal/legacy", makeYAML(personalPrefix: marker, legacyMarkers: [marker])),
            (
                "work/legacy",
                makeYAML(
                    workCalendars: [WorkYAML("Test Work Role", marker, "Test Work Source", "Test Work")],
                    legacyMarkers: [marker])
            ), ("legacy/legacy", makeYAML(legacyMarkers: [marker, marker]))
        ]

        for (relationship, invalidYAML) in cases {
            try expectInvalidSettings(
                invalidYAML, containing: ["distinct"], excluding: [marker], context: "\(relationship) marker collision")
        }
    }

    private static func testAcceptsSyncWindowBoundaries() throws {
        for value in [1, 365] {
            let settings = try YAMLCalendarRelaySettingsLoader.load(makeYAML(syncWindowDays: String(value)))
            try expect(settings.syncWindowDays == value, "syncWindowDays \(value) should be accepted")
        }
    }

    private static func testRejectsInvalidSyncWindowValuesAndTypes() throws {
        for value in ["0", "-1", "366"] {
            try expectInvalidSettings(
                makeYAML(syncWindowDays: value), containing: ["Sync window days"],
                context: "out-of-range syncWindowDays \(value)")
        }
        for value in ["1.5", "'1'", "true", "null"] {
            try expectInvalidConfiguration(
                makeYAML(syncWindowDays: value), context: "wrong-type syncWindowDays \(value)")
        }
    }

    private static func testRejectsHubWorkSelectorCollisionWithRoleIndexes() throws {
        let yaml = makeYAML(
            workCalendars: [WorkYAML("PRIVATE_ROLE_NAME", "[WORK]", "PRIVATE_SOURCE", "PRIVATE_CALENDAR")],
            hubSourceTitle: "PRIVATE_SOURCE", hubCalendarTitle: "PRIVATE_CALENDAR")

        try expectInvalidSettings(
            yaml, containing: ["Hub", "Work role at declaration index 0"],
            excluding: ["PRIVATE_ROLE_NAME", "PRIVATE_SOURCE", "PRIVATE_CALENDAR"],
            context: "hub/work selector collision")
    }

    private static func testRejectsWorkWorkSelectorCollisionWithRoleIndexes() throws {
        let yaml = makeYAML(workCalendars: [
            WorkYAML("PRIVATE_FIRST_ROLE", "[FIRST]", "PRIVATE_SOURCE", "PRIVATE_CALENDAR"),
            WorkYAML("PRIVATE_SECOND_ROLE", "[SECOND]", "PRIVATE_SOURCE", "PRIVATE_CALENDAR")
        ])

        try expectInvalidSettings(
            yaml, containing: ["Work role at declaration index 0", "Work role at declaration index 1"],
            excluding: ["PRIVATE_FIRST_ROLE", "PRIVATE_SECOND_ROLE", "PRIVATE_SOURCE", "PRIVATE_CALENDAR"],
            context: "work/work selector collision")
    }

    private static func testAcceptsStructurallyDistinctSelectors() throws {
        _ = try YAMLCalendarRelaySettingsLoader.load(makeYAML())
        _ = try YAMLCalendarRelaySettingsLoader.load(
            makeYAML(workCalendars: [WorkYAML("Test Work Role", "[WORK]", "test hub source", "test hub")]))
    }

    private static let workBlock = """
        workCalendars:
          - name: 'Test Work Role'
            prefix: '[WORK]'
            calendar:
              sourceTitle: 'Test Work Source'
              calendarTitle: 'Test Work'
        """

    private static func makeYAML(
        personalPrefix: String = "[ME]", syncWindowDays: String? = nil,
        workCalendars: [WorkYAML] = [WorkYAML("Test Work Role", "[WORK]", "Test Work Source", "Test Work")],
        legacyMarkers: [String]? = nil, hubSourceTitle: String = "Test Hub Source",
        hubCalendarTitle: String = "Test Hub"
    ) -> String {
        var lines = [
            "hubCalendar:", "  sourceTitle: \(quote(hubSourceTitle))", "  calendarTitle: \(quote(hubCalendarTitle))",
            "personalPrefix: \(quote(personalPrefix))"
        ]
        if let syncWindowDays { lines.append("syncWindowDays: \(syncWindowDays)") }
        lines.append("workCalendars:")
        for workCalendar in workCalendars {
            lines.append(contentsOf: [
                "  - name: \(quote(workCalendar.name))", "    prefix: \(quote(workCalendar.prefix))", "    calendar:",
                "      sourceTitle: \(quote(workCalendar.sourceTitle))",
                "      calendarTitle: \(quote(workCalendar.calendarTitle))"
            ])
        }
        if let legacyMarkers {
            if legacyMarkers.isEmpty {
                lines.append("legacyMarkers: []")
            } else {
                lines.append("legacyMarkers:")
                lines.append(contentsOf: legacyMarkers.map { "  - \(quote($0))" })
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func expectedSettings(legacyMarkers: [String]) -> CalendarRelaySettings {
        CalendarRelaySettings(
            hubCalendar: HubCalendarSettings(
                calendar: CalendarSelector(sourceTitle: "Test Hub Source", calendarTitle: "Test Hub")),
            personalPrefix: "[ME]", syncWindowDays: 100,
            workCalendars: [
                WorkCalendarSettings(
                    name: "Test Work Role", prefix: "[WORK]",
                    calendar: CalendarSelector(sourceTitle: "Test Work Source", calendarTitle: "Test Work"))
            ], legacyMarkers: legacyMarkers)
    }

    private static func expectInvalidConfiguration(_ yaml: String, context: String) throws {
        do { _ = try YAMLCalendarRelaySettingsLoader.load(yaml) } catch let error as YAMLCalendarRelaySettingsError {
            guard case .invalidConfiguration = error else {
                throw TestFailure("\(context) should be a structural failure, got: \(error)")
            }
            try expectNoPrivateFixtureDisclosure(error.description, context: context)
            return
        } catch { throw TestFailure("\(context) should throw YAMLCalendarRelaySettingsError, got: \(error)") }
        throw TestFailure("\(context) should fail structural validation")
    }

    private static func expectInvalidSettings(
        _ yaml: String, containing expectedText: [String], excluding prohibitedText: [String] = [], context: String
    ) throws {
        do { _ = try YAMLCalendarRelaySettingsLoader.load(yaml) } catch let error as YAMLCalendarRelaySettingsError {
            guard case .invalidSettings = error else {
                throw TestFailure("\(context) should be a settings failure, got: \(error)")
            }
            for expected in expectedText {
                try expect(
                    error.description.contains(expected),
                    "\(context) should identify \(expected), got: \(error.description)")
            }
            for prohibited in prohibitedText where !prohibited.isEmpty {
                try expect(
                    !error.description.contains(prohibited),
                    "\(context) should not reveal \(prohibited), got: \(error.description)")
            }
            try expectNoPrivateFixtureDisclosure(error.description, context: context)
            return
        } catch { throw TestFailure("\(context) should throw YAMLCalendarRelaySettingsError, got: \(error)") }
        throw TestFailure("\(context) should fail settings validation")
    }

    private static func expectNoPrivateFixtureDisclosure(_ description: String, context: String) throws {
        try expect(
            !description.contains("PRIVATE_"),
            "\(context) should not reveal private synthetic values, got: \(description)")
    }

    private static func quote(_ value: String) -> String { "'\(value.replacingOccurrences(of: "'", with: "''"))'" }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct WorkYAML {
    let name: String
    let prefix: String
    let sourceTitle: String
    let calendarTitle: String

    init(_ name: String, _ prefix: String, _ sourceTitle: String, _ calendarTitle: String) {
        self.name = name
        self.prefix = prefix
        self.sourceTitle = sourceTitle
        self.calendarTitle = calendarTitle
    }
}
