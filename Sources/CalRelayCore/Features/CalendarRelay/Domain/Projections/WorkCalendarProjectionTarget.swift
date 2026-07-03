public struct WorkCalendarProjectionTarget: Equatable, Sendable {
    public let settings: WorkCalendarSettings
    public let calendar: CalendarIdentity

    public init(settings: WorkCalendarSettings, calendar: CalendarIdentity) {
        self.settings = settings
        self.calendar = calendar
    }
}