import Foundation

public struct WorkCalendarProjectionTarget: Equatable, Sendable {
    public let settings: WorkCalendarSettings
    public let calendar: CalendarReference

    public init(settings: WorkCalendarSettings, calendar: CalendarReference) {
        self.settings = settings
        self.calendar = calendar
    }
}

public enum HubToWorkProjector {
    public static func project(
        hubEvents: [EventSnapshot], to workCalendars: [WorkCalendarProjectionTarget], personalPrefix: String
    ) -> [ProjectedEvent] {
        hubEvents.filter(EventInclusionPolicy.includes).flatMap { event in
            project(event: event, to: workCalendars, personalPrefix: personalPrefix)
        }
    }

    private static func project(
        event: EventSnapshot, to workCalendars: [WorkCalendarProjectionTarget], personalPrefix: String
    ) -> [ProjectedEvent] {
        let matchingSourcePrefix = workCalendars.map(\.settings.prefix).first { event.title.hasPrefix($0) }

        return workCalendars.compactMap { target in
            if target.settings.prefix == matchingSourcePrefix { return nil }

            return ProjectedEvent(
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
