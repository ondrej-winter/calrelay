import CalRelayKit
import Foundation

enum CalendarReviewedActionTests {
    static func runAll() throws {
        let calendar = CalendarIdentity(id: "test-hub", title: "Test Hub", sourceTitle: "Test Source")
        let changedCalendar = CalendarIdentity(id: "replacement", title: "Test Hub", sourceTitle: "Test Source")
        let first = event(calendar: calendar)
        let changedFields = event(calendar: calendar, title: "Changed explanation", status: .cancelled)
        let delete = CalendarMutationAction.delete(role: .hub, event: first)
        let diagnosticChange = CalendarMutationAction.delete(
            role: .work(name: "Renamed diagnostic role", declarationIndex: 0), event: changedFields)
        try expect(
            delete.executableIdentity == diagnosticChange.executableIdentity,
            "Delete review compares exact targets, not diagnostics or fetched fields")
        try expect(
            delete.executableIdentity
                != CalendarMutationAction.delete(role: .hub, event: event(calendar: changedCalendar)).executableIdentity,
            "Physical calendar replacement must invalidate review")
        try expect(
            delete.executableIdentity
                != CalendarMutationAction.delete(role: .hub, event: event(calendar: calendar, occurrence: 2))
                .executableIdentity, "Another occurrence must invalidate review")
        let create = CalendarMutationAction.create(
            role: .hub,
            event: CalendarEventProjection(
                destinationCalendar: calendar, title: "[TEST] Example", start: first.start, end: first.end,
                isAllDay: false))
        let changedCreate = CalendarMutationAction.create(
            role: .hub,
            event: CalendarEventProjection(
                destinationCalendar: changedCalendar, title: "[TEST] Example", start: first.start, end: first.end,
                isAllDay: false))
        try expect(
            create.executableIdentity != changedCreate.executableIdentity,
            "Create review includes the physical destination")
        try expect(
            [delete, create].map(\.executableIdentity) != [create, delete].map(\.executableIdentity),
            "Equal counts cannot authorize reordered actions")
    }

    private static func event(
        calendar: CalendarIdentity, title: String = "[TEST] Example", status: EventStatus = .confirmed,
        occurrence: Double = 1
    ) -> CalendarEvent {
        CalendarEvent(
            id: "test-event", calendar: calendar, title: title, start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200), isAllDay: false, availability: .busy, status: status,
            occurrenceDate: Date(timeIntervalSince1970: occurrence))
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}
