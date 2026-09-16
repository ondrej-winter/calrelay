# Spec: Multi-Calendar Routing

## Specification record

- **Status:** Accepted.
- **Revision:** 3 — accepted on September 16, 2026 after the projection and safety stress-test interview; authoritative marked-hub routing, global marker uniqueness, one-writer work-calendar ownership, and migration prerequisites were defined.
- **Canonical artifact:** `docs/specs/routing-spec.md`.
- **Scope:** Hub/work routing, exact marker treatment, and multi-computer topology.

## Required outcomes

### ROUTE-01 — Relay direction

With a hub calendar, work calendars carrying unique current markers, and a personal-origin marker:

- An eligible work-calendar source event is projected into the hub with that work calendar's marker and normalized title as defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- Every non-cancelled valid marked event in the reconciled logical hub state is an authoritative blocker source regardless of its attendee response or availability.
- A non-cancelled hub event marked with a current locally configured work marker is projected unchanged into every other configured work calendar, but not back into that marker's origin calendar.
- A non-cancelled valid marked hub event whose marker does not equal a current locally configured work marker is a remote-style blocker and is projected unchanged into every configured work calendar.
- A cancelled valid marked hub event is preserved according to ownership rules but is excluded from blocker routing.
- An unmarked hub event is projected into every configured work calendar with the personal-origin marker.
- Marker recognition uses the exact parsing and equality rules defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md); routing must not use raw starts-with matching.
- Work-calendar expectations are derived from the reconciled logical hub state defined in [`reconciliation-spec.md`](reconciliation-spec.md), not from a locally owned marked hub projection that the same plan has already classified as stale.

### ROUTE-02 — Multi-computer topology

- Each machine may see the shared hub plus only a subset of work calendars.
- Every current work marker and personal marker must be operator-assigned globally unique across all active CalRelay configurations sharing one hub. Local structural validation proves uniqueness only within one configuration; CalRelay cannot verify the global invariant.
- Each physical work calendar has exactly one active CalRelay writer. Multiple computers may share a hub only when their actively managed physical work-calendar sets are disjoint.
- Each machine is responsible only for its locally configured work calendars and current work markers under that one-writer invariant.
- A machine does not need a registry of markers owned by other computers. A non-local valid marked hub event supplies all information needed to relay the blocker unchanged.
- A machine must not delete a non-local marked hub event merely because its origin calendar is not configured locally.
- Stale valid marked events in locally configured work calendars are deleted when absent from the expected hub-derived blocker set, including markers not configured on that machine.
- The valid leading-marker namespace in configured work calendars is therefore reserved for CalRelay-managed blockers as defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- Violating global marker uniqueness or the one-writer rule can suppress, duplicate, or delete valid blockers. These are documented operator-managed topology requirements rather than runtime-detectable readiness checks.

### ROUTE-03 — Legacy-marker migration convergence

- Legacy cleanup does not route or generate events and does not identify which computer or calendar formerly owned a marker.
- Before a marker becomes a legacy tombstone, every active configuration sharing the hub must stop using it as a current work or personal marker. CalRelay cannot verify this globally.
- Any computer may clean the shared hub and its locally visible configured work calendars without requiring a coordinated global pause.
- A not-yet-migrated computer may recreate an event carrying a retired marker after another computer's successful cleanup.
- Repeated cleanup is expected until every computer stops publishing the retired marker and cleans its local topology.
- A successful cleanup run claims only local, point-in-time coverage as defined in [`configuration-spec.md`](configuration-spec.md); it must not claim globally atomic marker retirement.

## Acceptance checks

- **ROUTE-AC-01:** A non-cancelled locally marked hub event routes to every configured work calendar except its exact marker's origin calendar regardless of attendee response or availability.
- **ROUTE-AC-02:** A non-cancelled non-local valid marked hub event is preserved and projected unchanged to every locally configured work calendar without remote-marker configuration; a cancelled one is preserved but does not route.
- **ROUTE-AC-03:** An unmarked hub event receives the configured personal marker in every work-calendar projection.
- **ROUTE-AC-04:** Raw starts-with collisions do not alter origin exclusion or remote routing.
- **ROUTE-AC-05:** In a representative multi-computer migration, a later publisher can recreate a retired marker after cleanup, a repeated cleanup removes it locally, and neither run claims global retirement.
- **ROUTE-AC-06:** A representative scenario prevents double-booking across at least two configured work calendars over the configured sync window.
- **ROUTE-AC-07:** A stale locally owned hub projection is excluded from the reconciled logical hub state and is not relayed for an extra cycle.
- **ROUTE-AC-08:** Topology documentation requires globally unique active current/personal markers, disjoint work-calendar sets across machines, exactly one active writer per physical work calendar, and global retirement before tombstoning a marker.

## Constraints

- Do not add a global marker registry or require every machine to configure remote markers.
- Do not add cross-machine leader election or coordination to enforce one-writer ownership without an explicit decision.
- Mobile-app, team, and multi-user product features are excluded from the current scope.

## Compatibility and breaking changes

- Revision 3 makes previously implicit multi-computer operator obligations explicit: current and personal markers are globally unique, each physical work calendar has one active writer, and active machines sharing a hub manage disjoint work calendars.
- Revision 3 also makes every non-cancelled valid marked hub event authoritative, excludes cancelled marked events from routing, and prevents same-run propagation of stale local hub projections.
