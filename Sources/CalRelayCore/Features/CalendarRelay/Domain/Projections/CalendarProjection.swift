import Foundation

public struct WorkCalendarProjectionTarget: Equatable, Sendable {
    public let settings: WorkCalendarSettings
    public let calendar: CalendarIdentity

    public init(settings: WorkCalendarSettings, calendar: CalendarIdentity) {
        self.settings = settings
        self.calendar = calendar
    }
}

public enum WorkToHubProjector {
    public static func project(
        events: [CalendarEvent], from workCalendar: WorkCalendarSettings, to hubCalendar: CalendarIdentity
    ) -> [CalendarEventProjection] {
        events.filter(EventInclusionPolicy.includes).map { event in
            CalendarEventProjection(
                destinationCalendar: hubCalendar, title: "\(workCalendar.prefix) \(event.title)", start: event.start,
                end: event.end, isAllDay: event.isAllDay)
        }
    }
}

public enum HubToWorkProjector {
    public static func project(
        hubEvents: [CalendarEvent], to workCalendars: [WorkCalendarProjectionTarget], personalPrefix: String
    ) -> [CalendarEventProjection] {
        hubEvents.filter(EventInclusionPolicy.includes).flatMap { event in
            project(event: event, to: workCalendars, personalPrefix: personalPrefix)
        }
    }

    private static func project(
        event: CalendarEvent, to workCalendars: [WorkCalendarProjectionTarget], personalPrefix: String
    ) -> [CalendarEventProjection] {
        let matchingSourcePrefix = workCalendars.map(\.settings.prefix).first { event.title.hasPrefix($0) }

        return workCalendars.compactMap { target in
            if target.settings.prefix == matchingSourcePrefix { return nil }

            return CalendarEventProjection(
                destinationCalendar: target.calendar,
                title: projectedTitle(
                    for: event.title, matchingSourcePrefix: matchingSourcePrefix, personalPrefix: personalPrefix),
                start: event.start, end: event.end, isAllDay: event.isAllDay)
        }
    }

    private static func projectedTitle(for title: String, matchingSourcePrefix: String?, personalPrefix: String)
        -> String
    {
        if matchingSourcePrefix != nil || title.hasPrefix("[") { return title }

        return "\(personalPrefix) \(title)"
    }
}