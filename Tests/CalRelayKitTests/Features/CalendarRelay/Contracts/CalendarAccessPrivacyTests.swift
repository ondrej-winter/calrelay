import CalRelayKit

enum CalendarAccessPrivacyTests {
    static func runAll() throws {
        try testPartialMutationErrorOmitsEventAndCalendarDetails()
        try testCleanupErrorsUsePrivacySafeDescriptions()
    }

    private static func testPartialMutationErrorOmitsEventAndCalendarDetails() throws {
        let partial = CalendarMutationPartialResult(
            confirmedCounts: [
                CalendarRoleMutationCounts(
                    role: .work(name: "ACME", declarationIndex: 0), confirmedDeletes: 2, confirmedCreates: 1)
            ], failedRole: .work(name: "BETA", declarationIndex: 1), failureCategory: .createFailed)
        let description = CalendarMutationExecutionError.partial(partial).description

        try expect(description.contains("Work role ACME"), "Partial diagnostics may identify configured roles")
        try expect(
            description.contains("2 delete"), "Partial diagnostics should report confirmed categories and counts")
        try expect(description.contains("Work role BETA"), "Partial diagnostics should identify the failed role")
        try expect(description.contains("create failed"), "Partial diagnostics should identify the failure category")
        try expect(!description.contains("event-123"), "Partial diagnostics must omit event IDs")
        try expect(!description.contains("calendar-456"), "Partial diagnostics must omit calendar IDs")
        try expect(!description.contains("Private Planning"), "Partial diagnostics must omit event titles")
    }

    private static func testCleanupErrorsUsePrivacySafeDescriptions() throws {
        let partial = CalendarMutationPartialResult(
            confirmedCounts: [CalendarRoleMutationCounts(role: .hub, confirmedDeletes: 1, confirmedCreates: 0)],
            failedRole: .hub, failureCategory: .deleteFailed)

        let descriptions = [
            CalendarCleanupError.legacyMarkersRequired.description,
            CalendarCleanupError.mutationFailed(partial).description,
            CalendarCleanupError.verificationFoundRemainingMatches(count: 3).description
        ]

        try expect(descriptions[0].contains("legacy marker"), "Cleanup should give actionable marker guidance")
        try expect(
            descriptions[1].contains("partially applied"), "Cleanup mutation failure should report partial application")
        try expect(descriptions[2].contains("3"), "Cleanup verification should report a remaining-match count")
        try expect(!descriptions.joined().contains("[OLD]"), "Cleanup failures must omit marker values")
        try expect(!descriptions.joined().contains("Private Planning"), "Cleanup failures must omit event titles")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
