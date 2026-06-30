import Foundation

public struct CalendarRelaySettings: Equatable, Sendable {
    public let hubCalendar: CalendarSelector
    public let personalPrefix: String
    public let syncWindowDays: Int
    public let workCalendars: [WorkCalendarSettings]

    public init(
        hubCalendar: CalendarSelector,
        personalPrefix: String,
        syncWindowDays: Int,
        workCalendars: [WorkCalendarSettings]
    ) {
        self.hubCalendar = hubCalendar
        self.personalPrefix = personalPrefix
        self.syncWindowDays = syncWindowDays
        self.workCalendars = workCalendars
    }
}

public struct WorkCalendarSettings: Equatable, Sendable {
    public let name: String
    public let prefix: String
    public let calendar: CalendarSelector

    public init(name: String, prefix: String, calendar: CalendarSelector) {
        self.name = name
        self.prefix = prefix
        self.calendar = calendar
    }
}