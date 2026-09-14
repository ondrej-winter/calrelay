# Spec: Event Projection and Managed-Event Safety

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — split from the accepted EventKit MVP specification on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/projection-and-safety-spec.md`.
- **Scope:** Source-event eligibility, projection shape, ownership markers, and deletion safety.

## Required outcomes

### PROJECT-01 — Inclusion and projection defaults

- Include timed busy events.
- Skip tentative timed events, all-day events, declined events, and cancelled events.
- Copy recurring events occurrence-by-occurrence within the sync window when EventKit exposes occurrences; treat each as an ordinary visible snapshot and do not reproduce recurrence rules.
- Copy only title, start time, end time, all-day flag, and destination calendar.
- The sync-window default is the next 60 days.

### SAFE-01 — Managed-event ownership

- Every event CalRelay may delete is visibly marked with a configured prefix; prefixes are source markers and ownership markers.
- CalRelay may delete stale prefixed events in configured managed calendars.
- CalRelay must never delete unprefixed work/client events or otherwise mutate original unprefixed source events.
- Manual edits to prefixed generated events may be overwritten or deleted by reconciliation.
- Unknown prefixed hub events are preserved by default.

### SAFE-02 — Local mutation boundary

- Mutate only the hub and locally configured writable work/client calendars for the current run.
- Unknown prefixed work-calendar events are relayed blockers and are removed when absent from the expected hub-derived blocker set.

## Acceptance checks

- **PROJECT-AC-01:** Representative events demonstrate the inclusion defaults and occurrence-by-occurrence recurring projection within the sync window.
- **SAFE-AC-01:** CalRelay never deletes unprefixed original work/client events.
- **SAFE-AC-02:** Defaults remain deterministic and do not require live EventKit access to test.

## Open decisions

- Should all-day, declined, and cancelled handling become configurable?
- Should tentative timed events become configurable after real-world testing?
- Can EventKit reliably expose recurring occurrences as ordinary snapshots inside the sync window?
- Is the 60-day default sufficient, or should explicit configuration become required?

## Constraints

- Changing these hard-coded inclusion defaults into user configuration requires an explicit decision.
- Perfect recurring-event support and full semantic two-way editing are excluded.