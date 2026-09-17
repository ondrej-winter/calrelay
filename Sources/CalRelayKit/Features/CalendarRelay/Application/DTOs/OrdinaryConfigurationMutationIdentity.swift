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

    private struct WorkIdentity: Equatable, Sendable {
        let selector: CalendarSelector
        let marker: String
    }
}
