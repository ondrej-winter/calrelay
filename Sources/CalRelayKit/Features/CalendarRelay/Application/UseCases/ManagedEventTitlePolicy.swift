struct ManagedEventTitlePolicy: Sendable {
    let currentWorkPrefixes: Set<String>

    func isLocallyManagedHubProjection(_ event: CalendarEvent) -> Bool {
        guard let marker = MarkedEventTitle.marker(in: event.title) else { return false }
        return currentWorkPrefixes.contains(marker)
    }

    func hasValidMarker(_ event: CalendarEvent) -> Bool { MarkedEventTitle.marker(in: event.title) != nil }

    func isRelayedWorkBlocker(_ event: CalendarEvent) -> Bool { hasValidMarker(event) }
}
