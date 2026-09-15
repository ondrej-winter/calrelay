# Spec: Event Projection and Managed-Event Safety

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 15, 2026 after the CLI Revision 2 stress test; the effective whole-local-date reconciliation window and 100-day default forward horizon were defined.
- **Canonical artifact:** `docs/specs/projection-and-safety-spec.md`.
- **Scope:** Source-event eligibility, reconciliation-window boundaries, projection shape, ownership markers, and deletion safety.

## Required outcomes

### PROJECT-01 — Inclusion and projection defaults

- Include timed busy events.
- Skip tentative timed events, all-day events, declined events, and cancelled events.
- Copy recurring events occurrence-by-occurrence within the effective reconciliation window when EventKit exposes occurrences; treat each as an ordinary visible snapshot and do not reproduce recurrence rules.
- Copy only title, start time, end time, all-day flag, and destination calendar.

### PROJECT-02 — Effective reconciliation window

- At the start of each run, capture one reference instant and the Mac's current system calendar and time zone. Use that captured context for the entire run even if system settings later change.
- Let `D` be the local date containing the captured reference instant in that calendar and time zone.
- The effective reconciliation window is the half-open interval from the start of local date `D - 2 days` through, but not including, the start of local date `D + syncWindowDays + 1 days`.
- The two-date lookback is fixed and not configurable.
- `syncWindowDays` is the configurable forward horizon defined in [`configuration-spec.md`](configuration-spec.md). When omitted, it defaults to `100`, so the window includes `D` and the 100 following local dates in addition to the two preceding local dates.
- For example, when `D` is September 15, 2026 and `syncWindowDays` is `100`, the effective window covers September 13 through December 24, 2026, inclusive.
- Whole local calendar dates, rather than elapsed 24-hour durations, define the boundaries across daylight-saving and other local-time transitions.
- The same effective window governs the entire loaded snapshot and plan: input event reads, projection generation, visible-key matching, creates, and stale or surplus deletes.
- Successful reconciliation explanation reports the effective boundaries as required by [`cli-spec.md`](cli-spec.md).

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
- **PROJECT-AC-02:** Deterministic boundary tests with an injected reference instant, system calendar, and time zone prove the two-date lookback, the configured forward horizon, the omitted default of 100, the half-open end boundary, and correct behavior across a daylight-saving transition.
- **PROJECT-AC-03:** Dry-run, apply, and explanation use one captured effective window for input reads, projection generation, matching, creates, and stale or surplus deletes.
- **SAFE-AC-01:** CalRelay never deletes unprefixed original work/client events.
- **SAFE-AC-02:** Defaults remain deterministic and do not require live EventKit access to test.

## Open decisions

- Should all-day, declined, and cancelled handling become configurable?
- Should tentative timed events become configurable after real-world testing?
- Can EventKit reliably expose recurring occurrences as ordinary snapshots inside the sync window?

## Constraints

- Changing these hard-coded inclusion defaults into user configuration requires an explicit decision.
- Changing the fixed two-date lookback, making the lookback configurable, or adding a configured reconciliation time zone requires an explicit decision.
- Perfect recurring-event support and full semantic two-way editing are excluded.

## Compatibility and breaking changes

- Revision 2 changes the omitted forward-horizon default from 60 to 100 local dates and adds a fixed two-local-date lookback.
- Reconciliation may now plan creates and stale or surplus deletes for events on the two preceding local dates, and may plan actions farther into the future than the former default.
- Window boundaries now use whole dates in one system calendar/time-zone snapshot rather than elapsed-duration arithmetic. Operators should review dry-run output after upgrading.
