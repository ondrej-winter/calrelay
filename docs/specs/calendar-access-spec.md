# Spec: Calendar Access

## Specification record

- **Status:** Accepted.
- **Revision:** 7 — accepted on September 16, 2026 after the reconciliation stress-test interview; hub-first declaration-ordered reads, physical-calendar action identity, and local ordinary mutation completion were defined.
- **Canonical artifact:** `docs/specs/calendar-access-spec.md`.
- **Scope:** Calendar permission, discovery, ordinary and cleanup configured-topology preflight, writability, runtime access failures, and EventKit boundary behavior.

## Required outcomes

### ACCESS-01 — Permission ownership and authorization states

- Only full read/write Calendar authorization qualifies for calendar discovery, ordinary reconciliation readiness, or legacy cleanup. Write-only access is insufficient.
- Only a clearly labeled setup or recovery action in `CalRelay.app` may request full Calendar access and trigger the macOS permission prompt.
- The app permission action behaves according to the current authorization state:
  - when access is not determined, request full access;
  - when access is denied, write-only, or was later revoked, provide System Settings recovery guidance without requesting again;
  - when access is restricted, explain that the restriction must be resolved outside CalRelay;
  - when full access exists, verify and display the state without prompting.
- CLI commands and manual, scheduled, or cleanup reconciliation never request Calendar access. They inspect the current state and fail with actionable recovery guidance when full access is unavailable.

### ACCESS-02 — Calendar discovery

- `calrelay calendars` is a configuration-independent inventory command. It requires pre-existing full Calendar access and never prompts.
- Discovery lists every EventKit-visible calendar with its source/account, title, EventKit calendar ID, and writable/read-only status.
- Successful inventory discovery includes the empty inventory: zero visible calendars does not by itself make discovery fail.
- Discovery success means only that the current inventory was listed. It does not imply that a configuration is valid or ready for reconciliation or cleanup.
- `CalRelay.app` provides an equivalent all-calendar inventory for setup and recovery and clearly distinguishes inventory from configured readiness.
- EventKit calendar IDs displayed by successful CLI discovery are troubleshooting identifiers, not canonical configuration keys. The app inventory does not display EventKit IDs.

### ACCESS-03 — Ordinary configured-topology readiness preflight

- `calrelay config check` and every CLI or app ordinary reconciliation dry-run, apply, and explanation use the same non-mutating configured-topology access preflight after the selected configuration passes file and structural validation.
- Full Calendar authorization is required before configured readiness can succeed.
- For every configured hub or work-calendar role, ordinary preflight must establish all of the following:
  - its source/title selector resolves to exactly one currently visible EventKit calendar;
  - its resolved EventKit calendar ID is distinct from every other configured role;
  - reading its events over the effective ordinary reconciliation window defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md) succeeds; and
  - EventKit currently reports the calendar as writable.
- Ordinary snapshot reads proceed hub first and then through work calendars in configuration declaration order. Preflight still collects every safely determinable topology failure rather than treating the first read failure as permission to mutate a subset.
- Preflight must not create, update, or delete an event as a capability probe.
- Preflight collects and reports every safely determinable failure across the configured topology. Missing matches, ambiguous matches, role collisions, read failures, and read-only calendars are readiness failures.
- Any readiness failure prevents config check, ordinary dry-run, apply, or explanation from reporting success. Explanation requires the same writability checks even though it never mutates. Apply must complete the entire preflight before its first mutation, and any preflight failure prevents all mutations for that run.
- A migration-pending config check still completes this preflight and aggregates its access failures, but migration pending independently prevents a success or readiness claim as defined in [`configuration-spec.md`](configuration-spec.md).
- A successful preflight reports current readiness only; it is not a guarantee that authorization or remote calendar availability will remain unchanged during later mutation.

### ACCESS-04 — Legacy-cleanup preflight

- CLI and app legacy-cleanup dry-run and apply use the same dedicated non-mutating cleanup preflight after the selected configuration passes file and structural validation and contains at least one legacy marker.
- Cleanup preflight applies the same full-authorization, exact selector resolution, distinct physical-role, and writability requirements as ordinary preflight.
- For every configured role, cleanup preflight must successfully read events over the complete cleanup range defined in [`configuration-spec.md`](configuration-spec.md), not merely the ordinary reconciliation window.
- Cleanup snapshot reads and the required post-apply verification reads proceed hub first and then through work calendars in configuration declaration order.
- Cleanup preflight collects and reports every safely determinable failure across the complete configured topology.
- Cleanup apply must complete the entire cleanup preflight and load the complete cleanup snapshot before its first deletion. Any cleanup-preflight failure prevents every deletion for that run.
- Cleanup must not create, update, or delete an event as a capability probe and must not clean only a readable subset when another configured role fails.
- After every planned cleanup deletion succeeds, cleanup apply re-reads every configured role over the complete cleanup range. It reports success only when that verification snapshot contains no exact configured legacy-marker match.
- A post-mutation verification read failure or remaining match makes the invocation unsuccessful and nonzero. Confirmed deletions remain applied and are reported accurately; no rollback is attempted.
- A recurring-event deletion must resolve the exact occurrence selected by the plan. If EventKit cannot resolve that occurrence unambiguously, stop the run without substituting the first occurrence for an identifier, another occurrence, or the whole series.

### ACCESS-05 — Failure after mutation begins

- If Calendar access changes or an EventKit mutation fails after successful ordinary or cleanup preflight and mutation has begun, stop the run immediately rather than attempting later planned mutations.
- Report the run as partially applied with privacy-safe per-role action counts or categories and the failure category. Never report that run as successful.
- Do not attempt compensating rollback through EventKit. A later ordinary reconciliation or repeated cleanup, as applicable, is the recovery mechanism.
- Ordinary apply is successful when every action in its ordered plan receives EventKit mutation confirmation. It performs no post-mutation verification read; an immediately repeated provider read is not required to reflect those confirmed mutations.
- A ready ordinary run with an empty plan is successful without entering mutation. Cleanup retains the stronger post-mutation verification requirement in `ACCESS-04`.

### ACCESS-06 — Privacy-safe access diagnostics and cleanup review

- Interactive access, readiness, cleanup, and partial-application diagnostics may identify a configured role, its source/title selector, and a failure or action category, except where an owning presentation contract such as app cleanup deliberately allows less disclosure.
- Failure, readiness, and partial-application diagnostics omit event titles, event details, EventKit event IDs, and EventKit calendar IDs.
- Successful cleanup dry-run output and the fresh cleanup plan shown immediately before mutation may transiently disclose each selected event's title, configured role, and start/end or all-day date range so the deletion plan is reviewable.
- Cleanup review never discloses EventKit event IDs, EventKit calendar IDs, source/title selectors, calendar titles, or marker values. Event titles and time ranges shown for review must not be written to persistent logs or persisted app operational state.
- EventKit IDs may appear in user-facing output only for:
  1. successful `calrelay calendars` inventory, which displays calendar IDs as required by `ACCESS-02`; and
  2. successful, explicitly requested ordinary `calrelay reconcile --explain` output, which may display event and calendar IDs with the human-readable event details and reasons required by [`cli-spec.md`](cli-spec.md).
- Legacy-cleanup output, including successful dry-run and apply output, must not disclose EventKit IDs.
- Other successful CLI output and app inventory omit EventKit IDs.
- Persistent logs and persisted app operational status contain only the timestamps, counts, and categories allowed by [`macos-app-spec.md`](macos-app-spec.md). They do not contain calendar names, source/title selectors, EventKit IDs, event titles, event details, marker values, or raw configuration.

### ACCESS-07 — EventKit boundary

- EventKit types, calendar IDs, calendar stores, permission APIs, and mutation mechanics remain in adapters or app/bootstrap code.
- Map EventKit types into application DTOs at the adapter boundary.
- Mutate only distinct calendars configured for the current run and only after the applicable complete preflight succeeds.
- Configured calendars are read sequentially, hub first and then through work calendars in configuration declaration order. The resulting successful reads are the snapshot for that attempt; CalRelay does not claim an atomic cross-calendar EventKit snapshot.
- A deletion boundary DTO must carry enough occurrence identity to resolve the exact planned recurring occurrence without making EventKit IDs visible-set reconciliation keys or ownership markers.
- Boundary action identity includes the resolved physical destination or source calendar for the current plan. That identity supports exact reviewed-plan comparison and opaque standing-authorization topology binding but never becomes a configuration selector, selector fallback, visible-set key, routing input, or ownership marker.
- Once mutation begins, adapters target the exact planned event or occurrence without reauthorizing deletion from changed visible fields. EventKit identifier churn, an absent occurrence—including one already removed by another process—or ambiguous occurrence resolution causes a mutation failure rather than substitution or idempotent-success inference.

## Compatibility and breaking changes

- Revision 7 makes hub-first then declaration-ordered work-calendar reads normative for ordinary snapshots, cleanup snapshots, and cleanup verification. It also permits resolved physical calendar identity in exact executable-action identity and opaque topology authorization without making EventKit IDs selectors or reconciliation keys.
- Revision 7 defines ordinary success as local confirmation of every ordered mutation, with no post-apply verification read, while preserving cleanup's stronger complete-range no-match verification.
- Revision 6 requires exact recurring-occurrence resolution, makes sequential non-atomic reads explicit, and permits transient cleanup titles, roles, and time ranges only for successful plan review.
- Revision 5 adds app ordinary and cleanup surfaces without adding alternate access semantics: app and CLI operations use the same applicable complete-topology preflight and no-subset mutation gates.
- Persisted app operational status follows the existing privacy boundary for persistent logs and may contain only the explicitly approved timestamps, counts, and categories.
- Revision 4 preserves the ordinary configured-topology preflight while requiring migration-pending config check to report non-readiness after completing that preflight.
- Legacy cleanup receives a separate full-range preflight; ordinary-window readiness is insufficient authorization for cleanup mutation.
- Successful legacy-cleanup review may show the approved transient event details but does not receive the EventKit-ID disclosure exception granted to successful inventory and ordinary explanation.

## Validation

- `calrelay calendars` lists every visible calendar, source/account, title, EventKit ID, and writability without configuration or mutation.
- Config check, ordinary dry-run, apply, and explanation demonstrate the shared ordinary preflight and aggregate failure behavior.
- CLI and app legacy cleanup dry-run and apply demonstrate the full-range cleanup preflight and all-or-nothing preflight gate.
- Successful inventory and ordinary explanation demonstrate their narrow ID-disclosure exceptions; cleanup review demonstrates transient title/role/time disclosure with ID omission; failures and persistent logs demonstrate event-detail and ID omission.
- Real EventKit capability checks are explicit local validation through `CalRelay.app` or the CLI; default deterministic tests do not require real EventKit access.
- Manually validate permission acquisition and recovery with the stable `CalRelay.app` bundle identity.

## Acceptance checks

- **ACCESS-AC-01:** Authorization-state tests prove that only the explicit app setup/recovery action may prompt and that inventory, config check, ordinary reconciliation, cleanup, and scheduling never prompt.
- **ACCESS-AC-02:** Discovery lists all visible calendars with source/account, title, ID, and writability without requiring configuration, treats a successfully discovered empty inventory as success, and does not claim configured readiness.
- **ACCESS-AC-03:** Every CLI, manual-app, and automatic-app ordinary operation uses the same complete preflight and rejects missing, ambiguous, colliding, unreadable, or read-only configured calendars.
- **ACCESS-AC-04:** Migration-pending config check completes ordinary preflight, aggregates access failures, returns nonzero, and does not claim readiness.
- **ACCESS-AC-05:** CLI and app cleanup preflight read the complete cleanup range for every role and prevent all deletion when any role is missing, ambiguous, colliding, unreadable, or read-only.
- **ACCESS-AC-06:** A preflight with multiple safely determinable failures reports all of them and performs no mutation.
- **ACCESS-AC-07:** Cleanup apply performs a complete post-mutation verification read; a read failure or remaining exact legacy-marker match returns nonzero without rollback or a false cleanup-success claim.
- **ACCESS-AC-08:** A mutation-phase failure returns a privacy-safe partial result, stops later mutations, and performs no rollback.
- **ACCESS-AC-09:** Successful CLI inventory and ordinary explanation may disclose the approved IDs; cleanup review may transiently disclose only title, configured role, and time range; failures, readiness output, partial-application diagnostics, other successful output, app inventory, and persistent logs omit event details and unapproved IDs.
- **ACCESS-AC-10:** Deterministic core tests run without EventKit access or EventKit types in domain/application APIs.
- **ACCESS-AC-11:** Persisted app operational status and app cleanup presentation obey their stricter disclosure contract without weakening the reusable access-diagnostic boundary.
- **ACCESS-AC-12:** Recurring-event mutation tests delete only the exact planned occurrence and fail without substitution when exact occurrence resolution is missing or ambiguous.
- **ACCESS-AC-13:** Snapshot-loading tests read the hub first and work calendars in declaration order for ordinary, cleanup, and cleanup-verification snapshots, while retaining sequential non-atomic semantics without EventKit-notification restart or double-read requirements.
- **ACCESS-AC-14:** Exact-action identity tests distinguish physical destination calendars and exact delete occurrences for reviewed-plan and topology authorization purposes without using EventKit IDs as selectors, fallbacks, visible-set keys, or ownership markers.
- **ACCESS-AC-15:** Ordinary success tests require confirmation of every ordered action but no verification read, accept a ready empty plan as success, and keep cleanup success dependent on the complete no-match verification snapshot.

## Constraints

- Do not pass EventKit types into domain/application APIs.
- Do not mutate calendars to test access readiness.
- Do not support partial-topology ordinary reconciliation or cleanup when any configured role fails the applicable preflight.
- Do not use EventKit calendar IDs as an automatic selector fallback.
- Do not rely on live external provider APIs in default tests.
- Direct provider APIs, OAuth, app registrations, tenant approvals, and provider-specific sync tokens are excluded.
