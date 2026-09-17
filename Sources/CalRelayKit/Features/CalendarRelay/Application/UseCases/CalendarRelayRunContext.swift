import Foundation

struct ReconciliationRunContext {
    let hubCalendar: ResolvedCalendar
    let workCalendars: [WorkCalendarResolution]
    let managedPrefixes: Set<String>
    let hubEvents: [CalendarEvent]

    var allWorkEvents: [CalendarEvent] { workCalendars.flatMap(\.events) }

    func workEvents(for workCalendar: WorkCalendarResolution) -> [CalendarEvent] { workCalendar.events }
}

struct WorkCalendarResolution {
    let settings: WorkCalendarSettings
    let calendar: ResolvedCalendar
    let events: [CalendarEvent]
}

struct ResolvedCalendar { let reference: CalendarIdentity }
