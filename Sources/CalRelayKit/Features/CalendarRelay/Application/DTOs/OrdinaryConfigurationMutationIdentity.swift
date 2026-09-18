/// In-memory semantic comparison only; never persist or display these values.
struct OrdinaryConfigurationMutationIdentity: Equatable, Sendable {
    private let hub: CalendarSelector
    private let personalMarker: String
    private let windowDays: Int
    private let work: [WorkIdentity]
    private let legacyMarkers: Set<String>

    init(_ settings: CalendarRelaySettings) {
        hub = settings.hubCalendar.calendar
        personalMarker = settings.personalPrefix
        windowDays = settings.syncWindowDays
        work = settings.workCalendars.map { WorkIdentity(selector: $0.calendar, marker: $0.prefix) }
        legacyMarkers = Set(settings.legacyMarkers)
    }

    var stableIdentityComponents: [String] {
        var components = [
            "hub", hub.sourceTitle, hub.calendarTitle, "personalMarker", personalMarker, "windowDays",
            String(windowDays), "workCount", String(work.count)
        ]
        for workIdentity in work {
            components.append(contentsOf: [
                "work", workIdentity.selector.sourceTitle, workIdentity.selector.calendarTitle, workIdentity.marker
            ])
        }
        let sortedLegacyMarkers = legacyMarkers.sorted()
        components.append(contentsOf: ["legacyMarkerCount", String(sortedLegacyMarkers.count)])
        for marker in sortedLegacyMarkers { components.append(contentsOf: ["legacyMarker", marker]) }
        return components
    }

    private struct WorkIdentity: Equatable, Sendable {
        let selector: CalendarSelector
        let marker: String
    }
}
