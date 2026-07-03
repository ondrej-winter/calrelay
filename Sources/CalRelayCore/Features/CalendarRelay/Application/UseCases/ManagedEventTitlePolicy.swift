struct ManagedEventTitlePolicy: Sendable {
    let managedPrefixes: Set<String>

    func isManagedProjection(_ event: CalendarEvent) -> Bool {
        managedPrefixes.contains { prefix in event.title.hasPrefix(prefix) }
    }

    func hasAnyBracketedPrefix(_ event: CalendarEvent) -> Bool {
        event.title.hasPrefix("[") && event.title.contains("]")
    }

    func isRelayedWorkBlocker(_ event: CalendarEvent) -> Bool {
        hasAnyBracketedPrefix(event) || isManagedProjection(event)
    }
}