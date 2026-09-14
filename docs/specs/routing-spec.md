# Spec: Multi-Calendar Routing

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — split from the accepted EventKit MVP specification on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/routing-spec.md`.
- **Scope:** Hub/work routing and multi-computer topology.

## Required outcomes

### ROUTE-01 — Relay direction

With a hub calendar, work calendars carrying unique prefixes, and a personal-origin prefix:

- A work-calendar event is projected into the hub with that work calendar's prefix.
- A prefixed hub event is projected into every other work calendar, but not back into its origin calendar.
- An unprefixed hub event is projected into every work calendar with the personal-origin prefix.
- Remote prefixed hub events can act as blockers for locally configured work calendars.

### ROUTE-02 — Multi-computer topology

- Each machine may see the shared hub plus only a subset of work calendars.
- Each machine is responsible only for its locally configured work calendars and prefixes.
- A machine must not delete hub events with unknown or remote prefixes merely because their source calendar is not configured locally.
- Stale prefixed events in locally configured work calendars are deleted when absent from the expected hub-derived blocker set, including prefixes not configured on that machine.

## Acceptance checks

- **ROUTE-AC-01:** In a representative multi-computer topology, unknown prefixed hub events are preserved while remote blockers are projected into locally configured work calendars.
- **ROUTE-AC-02:** A representative scenario prevents double-booking across at least two configured work calendars over the configured sync window.

## Constraints

- Mobile-app, team, and multi-user product features are excluded from the current scope.