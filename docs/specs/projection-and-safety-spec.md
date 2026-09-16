# Spec: Event Projection and Managed-Event Safety

## Specification record

- **Status:** Accepted.
- **Revision:** 3 — accepted on September 16, 2026 after the Configuration Revision 4 stress test; exact marker parsing, title normalization, reserved work-calendar marker semantics, and cleanup tombstone ownership were defined.
- **Canonical artifact:** `docs/specs/projection-and-safety-spec.md`.
- **Scope:** Source-event eligibility, reconciliation and cleanup windows, projection shape, marker ownership, and deletion safety.

## Required outcomes

### PROJECT-01 — Inclusion and projection defaults

- Include timed busy events.
- Skip tentative timed events, all-day events, declined events, and cancelled events.
- Copy recurring events occurrence-by-occurrence within the applicable read window when EventKit exposes occurrences; treat each as an ordinary visible snapshot and do not reproduce recurrence rules.
- Normalize a projected source title by trimming surrounding whitespace. If the result is empty, use `(Untitled)`.
- A generated marked title consists of one configured marker, exactly one ASCII space, and the nonempty normalized source title.
- Apart from that title normalization and marker addition, copy only title, start time, end time, all-day flag, and destination calendar.

### PROJECT-02 — Effective reconciliation window

- At the start of each ordinary reconciliation run, capture one reference instant and the Mac's current system calendar and time zone. Use that captured context for the entire run even if system settings later change.
- Let `D` be the local date containing the captured reference instant in that calendar and time zone.
- The effective reconciliation window is the half-open interval from the start of local date `D - 2 days` through, but not including, the start of local date `D + syncWindowDays + 1 days`.
- The two-date lookback is fixed and not configurable.
- `syncWindowDays` is the configurable `1...365` forward horizon defined in [`configuration-spec.md`](configuration-spec.md). When omitted, it defaults to `100`, so the window includes `D` and the 100 following local dates in addition to the two preceding local dates.
- For example, when `D` is September 15, 2026 and `syncWindowDays` is `100`, the effective window covers September 13 through December 24, 2026, inclusive.
- Whole local calendar dates, rather than elapsed 24-hour durations, define the boundaries across daylight-saving and other local-time transitions.
- The same effective window governs the entire loaded snapshot and ordinary plan: input event reads, projection generation, visible-key matching, creates, and stale or surplus deletes.
- Successful reconciliation explanation reports the effective boundaries as required by [`cli-spec.md`](cli-spec.md).

### PROJECT-03 — Exact marked-title recognition

- Marker syntax and case-sensitive identity are defined by [`configuration-spec.md`](configuration-spec.md).
- A title has marker semantics only when it begins with one complete valid marker followed by exactly one ASCII space and nonempty title text.
- Marker recognition parses that complete leading marker and compares it by exact equality. Raw character-prefix matching, longest-prefix precedence, and configuration-order precedence are prohibited.
- A marker by itself, a marker with no separating space, more than one separating space, a tab or newline separator, or an invalid marker token does not establish marker semantics.

### SAFE-01 — Ordinary managed-event ownership

- In the hub, an event marked with a current locally configured work marker is a locally managed work projection and may be deleted when stale or surplus.
- In the hub, a valid marked event whose marker is not a current locally configured work marker is preserved during ordinary reconciliation and treated as a remote-style blocker source.
- In every configured work calendar, the valid leading-marker namespace is reserved for CalRelay-managed blocker semantics. Any valid marked event may be suppressed as feedback and deleted when absent from the expected hub-derived blocker set.
- Because title markers are the visible ownership mechanism, a manually created marked event in a configured work calendar is indistinguishable from a managed blocker and may be overwritten or deleted. User-facing documentation must warn about this behavior.
- CalRelay must never delete an unmarked work/client event or otherwise mutate an original unmarked source event.
- Manual edits to marked generated events may be overwritten or deleted by ordinary reconciliation.

### SAFE-02 — Legacy cleanup ownership

- A configured legacy marker is explicit deletion authorization only for `calrelay reconcile --cleanup-legacy`.
- Cleanup selects an event only when the title satisfies `PROJECT-03` and the parsed marker exactly equals one configured legacy marker.
- Cleanup may delete matching events from the configured hub and every locally configured work calendar over the cleanup range defined by [`configuration-spec.md`](configuration-spec.md).
- Cleanup does not route events, generate projections, infer an origin calendar, or perform ordinary current-marker reconciliation.
- A manually created marked hub or work-calendar event is eligible for cleanup when its marker is configured as a legacy tombstone.
- Legacy cleanup never authorizes deletion outside the configured topology or outside the product-defined cleanup range.

### SAFE-03 — Local mutation boundary

- Ordinary reconciliation mutates only the hub and locally configured writable work/client calendars for the current run.
- Unknown or remote marked hub events are preserved while their blocker projections into locally configured work calendars are created, retained, or removed according to the expected hub-derived set.
- Cleanup mutates only the hub and locally configured writable work/client calendars that passed the complete cleanup preflight.

## Acceptance checks

- **PROJECT-AC-01:** Representative events demonstrate the inclusion defaults and occurrence-by-occurrence recurring projection within the applicable window.
- **PROJECT-AC-02:** Projection tests trim surrounding title whitespace, substitute `(Untitled)` for empty results, and generate exactly `marker + one ASCII space + nonempty title`.
- **PROJECT-AC-03:** Marker parsing accepts only the complete grammar and separator shape, compares exact case-sensitive identities, and rejects raw starts-with false positives such as `[A]` against `[ACME] Planning`.
- **PROJECT-AC-04:** Deterministic boundary tests with an injected reference instant, system calendar, and time zone prove the two-date lookback, the configured forward horizon, the omitted default of 100, the half-open end boundary, and correct behavior across a daylight-saving transition.
- **PROJECT-AC-05:** Dry-run, apply, and explanation use one captured effective window for input reads, projection generation, matching, creates, and stale or surplus deletes.
- **SAFE-AC-01:** Ordinary reconciliation deletes stale local-work-marker hub projections, preserves non-local marked hub events, and never deletes unmarked original work/client events.
- **SAFE-AC-02:** Representative manually marked work-calendar events demonstrate the documented reserved-namespace deletion risk.
- **SAFE-AC-03:** Cleanup selects exact legacy-marker matches across the configured hub and work calendars, selects no current-marker or unmarked events, and performs no creates or ordinary reconciliation deletes.
- **SAFE-AC-04:** Defaults remain deterministic and do not require live EventKit access to test.

## Open decisions

- Should all-day, declined, and cancelled handling become configurable?
- Should tentative timed events become configurable after real-world testing?
- Can EventKit reliably expose recurring occurrences as ordinary snapshots inside the sync window?

## Constraints

- Changing these hard-coded inclusion defaults into user configuration requires an explicit decision.
- Changing the fixed two-date lookback, making the lookback configurable, or adding a configured reconciliation time zone requires an explicit decision.
- Do not introduce hidden ownership metadata or a persistent identity store without an explicit decision.
- Perfect recurring-event support and full semantic two-way editing are excluded.

## Compatibility and breaking changes

- Revision 3 replaces raw starts-with ownership with exact parsed-marker equality and reserves valid leading markers in configured work calendars for managed blocker semantics.
- Source titles are now trimmed for projection, and empty results use `(Untitled)` rather than creating an empty marked title.
- Legacy markers add explicit cleanup-only deletion ownership over the bounded migration range; ordinary reconciliation cannot use that authorization.
