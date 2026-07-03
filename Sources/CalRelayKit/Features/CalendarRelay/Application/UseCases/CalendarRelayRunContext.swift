import Foundation

struct PlannedRun {
    let plan: ReconciliationPlan
    let calendarsByID: [String: RelayCalendar]
}

struct ReconciliationRunContext {
    let hubCalendar: ResolvedCalendar
    let workCalendars: [WorkCalendarResolution]
    let managedPrefixes: Set<String>
    let hubEvents: [CalendarEvent]
    let workEventsByCalendarID: [String: [CalendarEvent]]
    let calendarsByID: [String: RelayCalendar]

    var allWorkEvents: [CalendarEvent] { workEventsByCalendarID.values.flatMap { $0 } }

    func workEvents(for workCalendar: WorkCalendarResolution) -> [CalendarEvent] {
        workEventsByCalendarID[workCalendar.calendar.snapshot.id, default: []]
    }
}

struct WorkCalendarResolution {
    let settings: WorkCalendarSettings
    let calendar: ResolvedCalendar
}

struct ResolvedCalendar {
    let snapshot: RelayCalendar

    var reference: CalendarIdentity {
        CalendarIdentity(id: snapshot.id, title: snapshot.title, sourceTitle: snapshot.sourceTitle)
    }
}