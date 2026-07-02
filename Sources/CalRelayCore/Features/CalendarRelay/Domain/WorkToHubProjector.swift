import Foundation

public enum WorkToHubProjector {
    public static func project(
        events: [EventSnapshot], from workCalendar: WorkCalendarSettings, to hubCalendar: CalendarReference
    ) -> [ProjectedEvent] {
        events.filter(EventInclusionPolicy.includes).map { event in
            ProjectedEvent(
                destinationCalendar: hubCalendar, title: "\(workCalendar.prefix) \(event.title)", start: event.start,
                end: event.end, isAllDay: event.isAllDay)
        }
    }
}
