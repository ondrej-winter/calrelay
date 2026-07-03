import Foundation

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
