import Foundation

struct CalendarRelaySettings: Equatable, Sendable {
    let hubCalendar: CalendarSelector
    let personalPrefix: String
    let syncWindowDays: Int
    let workCalendars: [WorkCalendarSettings]
}

struct WorkCalendarSettings: Equatable, Sendable {
    let name: String
    let prefix: String
    let calendar: CalendarSelector
}