import Foundation

struct ReconciliationRunContext {
    let hubCalendar: ResolvedCalendar
    let workCalendars: [WorkCalendarResolution]
    let currentWorkPrefixes: Set<String>
    let window: CalendarAccessWindow
    let syncWindowDays: Int
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
