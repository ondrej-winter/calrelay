# Spec: Multi-Calendar Routing

## Specification record

- **Status:** Accepted.
- **Revision:** 4 — accepted on September 17, 2026 after the routing stress-test interview; asymmetric reconciliation-window coverage, the reserved shared-hub marker namespace, topology lifecycle procedures, and marker-reuse prerequisites were defined.
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
- The complete valid leading-marker namespace in the shared hub is reserved for authoritative blocker semantics. A manually or externally created non-cancelled valid marked hub event routes under the same rules as any other marked hub event; CalRelay does not authenticate its origin.
- Marker recognition uses the exact parsing and equality rules defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md); routing must not use raw starts-with matching.
- Work-calendar expectations are derived from the reconciled logical hub state defined in [`reconciliation-spec.md`](reconciliation-spec.md), not from a locally owned marked hub projection that the same plan has already classified as stale.

### ROUTE-02 — Multi-computer topology

- Each machine may see the shared hub plus only a subset of work calendars.
- Every current work marker and personal marker must be operator-assigned globally unique across all active CalRelay configurations sharing one hub. Local structural validation proves uniqueness only within one configuration; CalRelay cannot verify the global invariant.
- Each physical work calendar has exactly one active CalRelay writer. Multiple computers may share a hub only when their actively managed physical work-calendar sets are disjoint.
- Each machine is responsible only for its locally configured work calendars and current work markers under that one-writer invariant.
- Machines sharing a hub may independently configure `syncWindowDays` and compute effective windows from their own captured system calendars and time zones. Cross-machine blocker protection exists only while a source interval positively overlaps both the publishing machine's and the receiving machine's effective reconciliation windows; one machine's horizon does not establish topology-wide coverage over that entire horizon.
- A machine does not need a registry of markers owned by other computers. A non-local valid marked hub event supplies all information needed to relay the blocker unchanged.
- A machine must not delete a non-local marked hub event merely because its origin calendar is not configured locally.
- A non-local marked hub event remains authoritative indefinitely while present. A receiving machine must not infer remote staleness, apply an age limit, or gain deletion authority because the owning writer is offline or gone; only the owner or an explicit operator cleanup or removal may retire it.
- Stale valid marked events in locally configured work calendars are deleted when absent from the expected hub-derived blocker set, including markers not configured on that machine.
- The valid leading-marker namespace in configured work calendars is therefore reserved for CalRelay-managed blockers as defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- Violating global marker uniqueness or the one-writer rule can suppress, duplicate, or delete valid blockers. These are documented operator-managed topology requirements rather than runtime-detectable readiness checks.
- For one local deployment, the operator uses either CLI mutation workflows or the macOS app mutation workflows as the active writer. Mixed concurrent CLI and app mutation is not a supported deployment mode and does not require a cross-process lock.

### ROUTE-03 — Legacy-marker migration convergence

- Legacy cleanup does not route or generate events and does not identify which computer or calendar formerly owned a marker.
- Before a marker becomes a legacy tombstone, every active configuration sharing the hub must stop using it as a current work or personal marker. CalRelay cannot verify this globally.
- Any computer may clean the shared hub and its locally visible configured work calendars without requiring a coordinated global pause.
- A not-yet-migrated computer may recreate an event carrying a retired marker after another computer's successful cleanup.
- Repeated cleanup is expected until every computer stops publishing the retired marker and cleans its local topology.
- A successful cleanup run claims only local, point-in-time coverage as defined in [`configuration-spec.md`](configuration-spec.md); it must not claim globally atomic marker retirement.
- Marker retirement must account for dormant or long-offline writers. Before such a writer reconnects to the shared hub, the operator must update it to the current topology and require normal readiness to succeed so it cannot republish a retired assignment.
- A retired marker may become a current work or personal marker again only after operators manually verify that no matching artifact remains anywhere in the topology and that no stale writer can republish the old assignment. Bounded cleanup success alone does not establish that prerequisite.
- Before retirement is considered complete or reuse is allowed, operators must manually inspect and remove any recurring series capable of producing matching occurrences outside the bounded cleanup range. Automatic cleanup remains occurrence-specific and must not delete an entire series merely because one occurrence matches.

### ROUTE-04 — Topology lifecycle

- To transfer one physical work calendar to another computer, stop and update the old writer before starting the new writer so there is no active-writer overlap. The same marker may remain assigned to that physical calendar; assigning a different marker invokes the retirement and cleanup requirements in `ROUTE-03`.
- Legacy cleanup reaches only the shared hub and the work calendars configured for that run. When a physical work calendar is removed from every active configuration, the operator must manually inspect and remove obsolete marked projections remaining in that removed calendar.
- Replacing the shared hub is a coordinated operator migration, not an automatic or atomic CalRelay operation. Operators must transfer any original hub events outside CalRelay, update every active configuration, and manually inspect and clean obsolete marked projections in the former hub.
- During a staggered hub replacement, machines still using the former hub and machines using the replacement hub are partitioned and do not exchange blockers. Operators must account for that degraded interval rather than treating either hub as topology-wide authoritative.

## Acceptance checks

- **ROUTE-AC-01:** A non-cancelled locally marked hub event routes to every configured work calendar except its exact marker's origin calendar regardless of attendee response or availability.
- **ROUTE-AC-02:** A non-cancelled non-local valid marked hub event is preserved and projected unchanged to every locally configured work calendar without remote-marker configuration; a cancelled one is preserved but does not route.
- **ROUTE-AC-03:** An unmarked hub event receives the configured personal marker in every work-calendar projection.
- **ROUTE-AC-04:** Raw starts-with collisions do not alter origin exclusion or remote routing.
- **ROUTE-AC-05:** In a representative multi-computer migration, a later publisher can recreate a retired marker after cleanup, a repeated cleanup removes it locally, and neither run claims global retirement.
- **ROUTE-AC-06:** A representative scenario prevents double-booking across at least two configured work calendars while the source interval is inside every participating machine's effective reconciliation window.
- **ROUTE-AC-07:** A stale locally owned hub projection is excluded from the reconciled logical hub state and is not relayed for an extra cycle.
- **ROUTE-AC-08:** Topology documentation requires globally unique active current/personal markers, disjoint work-calendar sets across machines, exactly one active writer per physical work calendar, and global retirement before tombstoning a marker.
- **ROUTE-AC-09:** Representative machines with different `syncWindowDays`, system calendars, or time zones route a blocker only while its interval positively overlaps both independently computed effective windows, and documentation makes no topology-wide promise from either machine's horizon alone.
- **ROUTE-AC-10:** A manually or externally created non-cancelled valid marked hub event is treated as an authoritative blocker and routed without local or remote-marker registration; a receiving machine preserves it indefinitely while it remains present.
- **ROUTE-AC-11:** Ownership-transfer documentation requires a stop-and-update-before-start handoff, permits the same marker to follow the same physical calendar, and invokes marker retirement when the marker changes.
- **ROUTE-AC-12:** Removing a work calendar leaves its residual cleanup manual, while replacing the hub requires coordinated original-event transfer, configuration cutover, former-hub cleanup, and an explicit warning that staggered hubs are partitioned.
- **ROUTE-AC-13:** Retirement documentation requires dormant writers to adopt the current topology before reconnecting and prohibits marker reuse until operators verify global artifact removal, remove future-producing recurring series, and prevent stale republishing.

## Constraints

- Do not add a global marker registry or require every machine to configure remote markers.
- Do not add cross-machine leader election or coordination to enforce one-writer ownership without an explicit decision.
- Do not add marker authentication, remote-blocker leases or age limits, persistent ownership metadata, or inferred remote deletion authority without an explicit decision.
- Do not add automatic hub migration, cleanup-only selectors for removed work calendars, unbounded recurring-event discovery, whole-series legacy deletion, or a same-host cross-process mutation lock without an explicit decision.
- Mobile-app, team, and multi-user product features are excluded from the current scope.

## Compatibility and breaking changes

- Revision 4 accepts independently computed reconciliation windows and limits cross-machine protection to their overlap. It also reserves the complete valid-marker namespace in the shared hub and keeps non-local marked blockers authoritative without leases or inferred staleness.
- Revision 4 defines operator-managed ownership transfer, work-calendar removal, hub replacement, dormant-writer recovery, recurring-series retirement, and the prerequisites for retired-marker reuse without adding coordination or automatic migration machinery.
- Revision 3 makes previously implicit multi-computer operator obligations explicit: current and personal markers are globally unique, each physical work calendar has one active writer, and active machines sharing a hub manage disjoint work calendars.
- Revision 3 also makes every non-cancelled valid marked hub event authoritative, excludes cancelled marked events from routing, and prevents same-run propagation of stale local hub projections.
