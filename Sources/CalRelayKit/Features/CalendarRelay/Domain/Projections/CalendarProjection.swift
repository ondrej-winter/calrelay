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
                destinationCalendar: hubCalendar,
                title: ProjectionTitle.marked(marker: workCalendar.prefix, sourceTitle: event.title),
                start: event.start, end: event.end, isAllDay: event.isAllDay)
        }
    }
}

public enum HubToWorkProjector {
    public static func project(
        hubEvents: [CalendarEvent], to workCalendars: [WorkCalendarProjectionTarget], personalPrefix: String
    ) -> [CalendarEventProjection] {
        hubEvents.filter(isRoutingSource).flatMap { event in
            project(event: event, to: workCalendars, personalPrefix: personalPrefix)
        }
    }

    private static func isRoutingSource(_ event: CalendarEvent) -> Bool {
        if MarkedEventTitle.marker(in: event.title) != nil { return event.status != .cancelled }
        return EventInclusionPolicy.includes(event)
    }

    private static func project(
        event: CalendarEvent, to workCalendars: [WorkCalendarProjectionTarget], personalPrefix: String
    ) -> [CalendarEventProjection] {
        let marker = MarkedEventTitle.marker(in: event.title)
        let matchingSourcePrefix = workCalendars.map(\.settings.prefix).first { $0 == marker }

        return workCalendars.compactMap { target in
            if target.settings.prefix == matchingSourcePrefix { return nil }

            return CalendarEventProjection(
                destinationCalendar: target.calendar,
                title: projectedTitle(for: event.title, marker: marker, personalPrefix: personalPrefix),
                start: event.start, end: event.end, isAllDay: event.isAllDay)
        }
    }

    private static func projectedTitle(for title: String, marker: String?, personalPrefix: String) -> String {
        if marker != nil { return title }

        return ProjectionTitle.marked(marker: personalPrefix, sourceTitle: title)
    }
}

private enum ProjectionTitle {
    static func marked(marker: String, sourceTitle: String) -> String {
        let normalizedTitle = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(marker) \(normalizedTitle.isEmpty ? "(Untitled)" : normalizedTitle)"
    }
}
