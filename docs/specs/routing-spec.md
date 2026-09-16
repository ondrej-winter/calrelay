# Spec: Multi-Calendar Routing

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 16, 2026 after the Configuration Revision 4 stress test; exact marker routing and eventual-convergence marker migration were defined.
- **Canonical artifact:** `docs/specs/routing-spec.md`.
- **Scope:** Hub/work routing, exact marker treatment, and multi-computer topology.

## Required outcomes

### ROUTE-01 — Relay direction

With a hub calendar, work calendars carrying unique current markers, and a personal-origin marker:

- An eligible work-calendar source event is projected into the hub with that work calendar's marker and normalized title as defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- A hub event marked with a current locally configured work marker is projected unchanged into every other configured work calendar, but not back into that marker's origin calendar.
- A valid marked hub event whose marker does not equal a current locally configured work marker is a remote-style blocker and is projected unchanged into every configured work calendar.
- An unmarked hub event is projected into every configured work calendar with the personal-origin marker.
- Marker recognition uses the exact parsing and equality rules defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md); routing must not use raw starts-with matching.

### ROUTE-02 — Multi-computer topology

- Each machine may see the shared hub plus only a subset of work calendars.
- Each machine is responsible only for its locally configured work calendars and current work markers.
- A machine does not need a registry of markers owned by other computers. A non-local valid marked hub event supplies all information needed to relay the blocker unchanged.
- A machine must not delete a non-local marked hub event merely because its origin calendar is not configured locally.
- Stale valid marked events in locally configured work calendars are deleted when absent from the expected hub-derived blocker set, including markers not configured on that machine.
- The valid leading-marker namespace in configured work calendars is therefore reserved for CalRelay-managed blockers as defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).

### ROUTE-03 — Legacy-marker migration convergence

- Legacy cleanup does not route or generate events and does not identify which computer or calendar formerly owned a marker.
- Any computer may clean the shared hub and its locally visible configured work calendars without requiring a coordinated global pause.
- A not-yet-migrated computer may recreate an event carrying a retired marker after another computer's successful cleanup.
- Repeated cleanup is expected until every computer stops publishing the retired marker and cleans its local topology.
- A successful cleanup run claims only local, point-in-time coverage as defined in [`configuration-spec.md`](configuration-spec.md); it must not claim globally atomic marker retirement.

## Acceptance checks

- **ROUTE-AC-01:** A locally marked hub event routes to every configured work calendar except its exact marker's origin calendar.
- **ROUTE-AC-02:** A non-local valid marked hub event is preserved and projected unchanged to every locally configured work calendar without remote-marker configuration.
- **ROUTE-AC-03:** An unmarked hub event receives the configured personal marker in every work-calendar projection.
- **ROUTE-AC-04:** Raw starts-with collisions do not alter origin exclusion or remote routing.
- **ROUTE-AC-05:** In a representative multi-computer migration, a later publisher can recreate a retired marker after cleanup, a repeated cleanup removes it locally, and neither run claims global retirement.
- **ROUTE-AC-06:** A representative scenario prevents double-booking across at least two configured work calendars over the configured sync window.

## Constraints

- Do not add a global marker registry or require every machine to configure remote markers.
- Mobile-app, team, and multi-user product features are excluded from the current scope.
