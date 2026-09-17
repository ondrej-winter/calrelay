struct ManagedEventTitlePolicy: Sendable {
    let managedPrefixes: Set<String>

    func isManagedProjection(_ event: CalendarEvent) -> Bool {
        guard let marker = MarkedEventTitle.marker(in: event.title) else { return false }
        return managedPrefixes.contains(marker)
    }

    func hasValidMarker(_ event: CalendarEvent) -> Bool { MarkedEventTitle.marker(in: event.title) != nil }

    func isRelayedWorkBlocker(_ event: CalendarEvent) -> Bool { hasValidMarker(event) }
}
