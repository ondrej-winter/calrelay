# Spec: Event Projection and Managed-Event Safety

## Specification record

- **Status:** Accepted.
- **Revision:** 6 — accepted on September 17, 2026 after the routing stress-test interview; the complete valid-marker namespace in the shared hub was explicitly reserved for authoritative blocker semantics.
- **Canonical artifact:** `docs/specs/projection-and-safety-spec.md`.
- **Scope:** Source-event eligibility, reconciliation and cleanup windows, projection shape, marker ownership, and deletion safety.

## Required outcomes

### PROJECT-01 — Source-event eligibility and projection shape

- A reliably cancelled event is ineligible.
- When EventKit identifies the current user as an attendee, the event is eligible only when that user's response is accepted. Accepted response makes the event eligible regardless of its availability value; tentative, declined, pending, delegated, unknown, and every other non-accepted response make it ineligible.
- Other attendees' responses do not affect eligibility. Overall EventKit status other than reliable cancellation does not affect eligibility.
- When EventKit exposes no current-user attendee record, availability determines eligibility:
  - busy, not-supported, and unavailable values are eligible; and
  - free, tentative, unknown, and future unrecognized values are ineligible.
- Apply the same eligibility policy to timed and all-day source events.
- A non-cancelled valid marked hub event is an authoritative blocker source and bypasses the attendee and availability rules above. A cancelled valid marked hub event does not route.
- Normalize a projected source title by trimming surrounding whitespace. If the result is empty, use `(Untitled)`.
- A generated marked title consists of one configured marker, exactly one ASCII space, and the nonempty normalized source title.
- Copy the normalized source title across configured account boundaries. This intentionally exposes source titles to destination calendar providers, notifications, sharing, and delegated viewers; user-facing documentation must warn about that confidentiality trade-off.
- Copy EventKit's returned start time, end time, and all-day flag unchanged. Do not clip an interval at a reconciliation boundary or perform custom time-zone conversion; rely on EventKit for timed-event display and floating all-day semantics.
- Apart from title normalization and marker addition, a projection contains only title, start time, end time, all-day flag, and destination calendar. CalRelay does not explicitly set projection availability and relies on the destination calendar provider's default behavior, which may not guarantee that a visible projection is reported as busy.
- This eligibility policy is fixed and deterministic. Making any part configurable requires a later explicit decision.

### PROJECT-02 — Effective reconciliation window

- At the start of each ordinary reconciliation run, capture one reference instant and the Mac's current system calendar and time zone. Use that captured context for the entire run even if system settings later change.
- Let `D` be the local date containing the captured reference instant in that calendar and time zone.
- The effective reconciliation window is the half-open interval from the start of local date `D - 2 days` through, but not including, the start of local date `D + syncWindowDays + 1 days`.
- The two-date lookback is fixed and not configurable.
- `syncWindowDays` is the configurable `1...365` forward horizon defined in [`configuration-spec.md`](configuration-spec.md). When omitted, it defaults to `100`, so the window includes `D` and the 100 following local dates in addition to the two preceding local dates.
- For example, when `D` is September 15, 2026 and `syncWindowDays` is `100`, the effective window covers September 13 through December 24, 2026, inclusive.
- Whole local calendar dates, rather than elapsed 24-hour durations, define the boundaries across daylight-saving and other local-time transitions.
- An event belongs to the effective window exactly when its interval has positive-duration overlap with the half-open window: its start is before the window end and its end is after the window start.
- An overlapping event is projected with its complete original interval even when it begins before the window start or ends after the window end. An event ending exactly at the window start or starting exactly at the window end is outside the window.
- The same effective window governs the entire loaded snapshot and ordinary plan: input event reads, projection generation, visible-key matching, creates, and stale, cancelled, or duplicate-replacement deletes.
- Successful reconciliation explanation reports the effective boundaries as required by [`cli-spec.md`](cli-spec.md).

### PROJECT-03 — Recurring occurrence snapshots

- Treat a successful EventKit range read as the authoritative visible occurrence snapshot for that run; CalRelay does not independently prove that a provider exposed every theoretical occurrence.
- Reconcile every returned recurring occurrence independently as an ordinary event snapshot, including detached occurrences with their returned edited fields.
- Do not reproduce recurrence rules or claim provider-independent recurrence completeness.
- A calendar read failure blocks the run, but unverifiable recurrence completeness alone does not.

### PROJECT-04 — Exact marked-title recognition

- Marker syntax and case-sensitive identity are defined by [`configuration-spec.md`](configuration-spec.md).
- A title has marker semantics only when it begins with one complete valid marker followed by exactly one ASCII space and nonempty title text.
- Marker recognition parses that complete leading marker and compares it by exact equality. Raw character-prefix matching, longest-prefix precedence, and configuration-order precedence are prohibited.
- A marker by itself, a marker with no separating space, more than one separating space, a tab or newline separator, or an invalid marker token does not establish marker semantics.

### SAFE-01 — Ordinary managed-event ownership

- In the hub, an event marked with a current locally configured work marker is a locally managed work projection and may be deleted when stale, cancelled, or part of duplicate replacement.
- In the hub, a valid marked event whose marker is not a current locally configured work marker is preserved during ordinary reconciliation and treated as a remote-style blocker source.
- The complete valid leading-marker namespace in the shared hub is reserved for authoritative blocker semantics as defined by [`routing-spec.md`](routing-spec.md). A manually or externally created non-cancelled valid marked hub event is indistinguishable from routing input and is relayed without origin authentication or remote-marker registration.
- In every configured work calendar, the valid leading-marker namespace is reserved for CalRelay-managed blocker semantics. Any valid marked event may be suppressed as feedback and deleted when absent from the expected hub-derived blocker set.
- Because title markers are the visible ownership mechanism, a manually created event using a current local work marker in the hub or any valid marker in a configured work calendar is indistinguishable from a managed projection and may be overwritten or deleted. Any valid marked hub event may also propagate its title across configured account boundaries. User-facing documentation must warn about the hub routing/disclosure risk and both destructive namespaces.
- CalRelay must never delete an unmarked work/client event or otherwise mutate an original unmarked source event.
- Manual edits to marked generated events may be overwritten or deleted by ordinary reconciliation.
- Ordinary ownership and stale-repair guarantees cover only the current effective window. A current-marker projection that has moved before the two-date lookback may remain indefinitely after a later source deletion, rename, or correction.

### SAFE-02 — Legacy cleanup ownership

- A configured legacy marker is explicit deletion authorization only for the dedicated CLI or app legacy-cleanup workflow. It never authorizes ordinary or scheduled reconciliation deletion.
- Cleanup selects an event only when the title satisfies `PROJECT-04` and the parsed marker exactly equals one configured legacy marker.
- Cleanup may delete matching events from the configured hub and every locally configured work calendar over the cleanup range defined by [`configuration-spec.md`](configuration-spec.md).
- Cleanup does not route events, generate projections, infer an origin calendar, or perform ordinary current-marker reconciliation.
- A manually created marked hub or work-calendar event is eligible for cleanup when its marker is configured as a legacy tombstone.
- Legacy cleanup never authorizes deletion outside the configured topology or outside the product-defined cleanup range.
- Historical managed events whose title shape cannot be expressed by the current exact marker grammar are outside automatic cleanup. CalRelay must not use fuzzy prefix matching or heuristics to delete them; user-facing documentation provides manual removal guidance.
- Legacy cleanup owns only its moving bounded range. A matching projection older than that range may remain indefinitely.

### SAFE-03 — Local mutation boundary

- Ordinary reconciliation mutates only the hub and locally configured writable work/client calendars for the current run.
- Unknown or remote marked hub events are preserved while their blocker projections into locally configured work calendars are created, retained, or removed according to the expected hub-derived set.
- Cleanup mutates only the hub and locally configured writable work/client calendars that passed the complete cleanup preflight.
- Once mutation begins, the plan-time ownership decision remains the deletion authority for that attempt. A selected event may still be deleted by its exact planned occurrence identity when its visible fields or marker change after planning; CalRelay does not reauthorize deletion from a new snapshot after the first mutation.

## Acceptance checks

- **PROJECT-AC-01:** Representative timed and all-day events prove cancellation precedence; accepted current-user attendee inclusion regardless of availability; rejection of every non-accepted current-user response; disregard of other attendees and non-cancelled overall status; and the no-attendee availability matrix.
- **PROJECT-AC-02:** Projection tests trim surrounding title whitespace, substitute `(Untitled)` for empty results, and generate exactly `marker + one ASCII space + nonempty title`.
- **PROJECT-AC-03:** Projection tests preserve returned timed and all-day start/end values and the all-day flag, do not clip boundary-overlapping intervals, do not explicitly copy availability, and document title disclosure and provider-default availability risks.
- **PROJECT-AC-04:** Marker parsing accepts only the complete grammar and separator shape, compares exact case-sensitive identities, and rejects raw starts-with false positives such as `[A]` against `[ACME] Planning`.
- **PROJECT-AC-05:** Deterministic boundary tests with an injected reference instant, system calendar, and time zone prove the two-date lookback, the configured forward horizon, the omitted default of 100, positive-overlap membership, exact-touch exclusion, full-interval preservation, and correct behavior across a daylight-saving transition.
- **PROJECT-AC-06:** Recurrence tests treat every returned occurrence, including a detached edit, independently and make no claim about occurrences absent from a successful EventKit snapshot.
- **PROJECT-AC-07:** Dry-run, apply, and explanation use one captured effective window for input reads, projection generation, matching, creates, and stale, cancelled, or duplicate-replacement deletes.
- **SAFE-AC-01:** Ordinary reconciliation deletes stale local-work-marker hub projections, preserves non-local marked hub events, treats non-cancelled marked hub events as authoritative blockers, and never plans deletion of an unmarked original work/client event.
- **SAFE-AC-02:** Representative manually marked events demonstrate authoritative routing for any valid marked hub event, deletion risk for a current-local-marker hub event, and deletion risk for any valid marked event in a configured work calendar.
- **SAFE-AC-03:** CLI and app cleanup select exact legacy-marker matches across the configured hub and work calendars, select no current-marker, malformed-marker, or unmarked events, and perform no creates or ordinary reconciliation deletes.
- **SAFE-AC-04:** Deterministic tests demonstrate the bounded historical ownership rule and the accepted plan-time deletion authority when an event changes after planning.
- **SAFE-AC-05:** Defaults remain deterministic and do not require live EventKit access to test.

## Open decisions

- None for this revision.

## Constraints

- Changing these hard-coded inclusion defaults into user configuration requires an explicit decision.
- Changing the fixed two-date lookback, making the lookback configurable, adding a configured reconciliation time zone, explicitly setting projection availability, or redacting projected titles requires an explicit decision.
- Do not introduce hidden ownership metadata or a persistent identity store without an explicit decision.
- Perfect recurring-event support and full semantic two-way editing are excluded.

## Compatibility and breaking changes

- Revision 6 explicitly reserves every valid leading marker in the shared hub for authoritative blocker routing and documents that manually or externally created marked events propagate without origin authentication.
- Revision 5 replaces the broad tentative/declined/all-day defaults with explicit current-user attendee and availability precedence, includes eligible all-day events, defines positive-overlap window membership, and treats returned recurring occurrences as authoritative only for the current run.
- Revision 5 also records title disclosure, provider-default projection availability, bounded historical ownership, both destructive marker namespaces, exact-only legacy cleanup, and plan-time deletion authority as accepted trade-offs.
- Revision 4 permits the explicit app cleanup workflow to exercise the existing bounded legacy-marker deletion authority; the selected events and safety boundaries are unchanged.
- Revision 3 replaces raw starts-with ownership with exact parsed-marker equality and reserves valid leading markers in configured work calendars for managed blocker semantics.
- Source titles are now trimmed for projection, and empty results use `(Untitled)` rather than creating an empty marked title.
- Legacy markers add explicit cleanup-only deletion ownership over the bounded migration range; ordinary reconciliation cannot use that authorization.
