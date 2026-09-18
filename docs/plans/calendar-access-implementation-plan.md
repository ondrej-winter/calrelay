# Calendar Access Implementation Plan

## Plan record

- **Requirements basis:** [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md), revision 7, accepted September 16, 2026.
- **Status:** Ready.
- **Implementation progress:** Partial as of September 17, 2026. The reusable access, complete CLI, cleanup, app-status, app ordinary dry-run and reviewed manual apply, opaque-reference, and ordinary explanation slices are implemented. Live app launch/status refresh and CLI unavailable-access checks have been exercised; full-access dedicated-calendar validation, D-05 app cleanup, scheduling, and persisted status remain open.
- **Scope:** Calendar authorization ownership, inventory, ordinary and cleanup preflight, mutation-time access failure, privacy-safe diagnostics, and the EventKit boundary.
- **Execution approach:** Thin, test-backed slices. Cross-capability behavior remains owned by the accepted configuration, projection/safety, reconciliation, CLI, and macOS app specifications.

## Initial implementation findings

- `EventKitCalendarStore` currently requests full Calendar access from inventory, read, create, and delete operations.
- App inventory currently doubles as the permission action and reuses the CLI formatter, including EventKit calendar IDs.
- Readiness is embedded in reconciliation, stops at the first topology failure, and checks writability only for calendars selected by the current plan.
- Exact recurring-occurrence deletion currently uses `event(withIdentifier:)`, which the macOS SDK documents as returning the first matching occurrence.
- Config check, cleanup preflight, cleanup verification, progressive mutation confirmation, and privacy-safe partial results are not implemented.
- Several prerequisites remain owned by adjacent specifications: strict settings and migration state, local-date windows, ordered reconciliation and cleanup plans, and app scheduling/confirmation flows.

## Source-backed EventKit constraints

- The macOS 26 EventKit SDK distinguishes `.fullAccess` and `.writeOnly`; only full access satisfies CalRelay discovery and reconciliation requirements.
- `requestFullAccessToEvents` is isolated to the explicit app setup/recovery path.
- `event(withIdentifier:)` returns the first occurrence of a recurring event and is not sufficient for exact occurrence deletion.
- `EKEvent.occurrenceDate` remains the originally scheduled date when an occurrence is detached and moved.
- `events(matching:)` is synchronous and must not block `@MainActor` UI work.

## Cross-capability dependencies

- **D-01 — Configuration:** strict schema, `legacyMarkers`, marker validation, default `syncWindowDays = 100`, duplicate-selector validation, and migration-pending state.
- **D-02 — Projection and safety:** one captured run context plus canonical ordinary and cleanup local-date windows.
- **D-03 — Reconciliation:** ordered delete-first actions, exact delete identity, shared explanation computation, and deterministic cleanup plans.
- **D-04 — CLI:** config-check and cleanup commands, option precedence, process status, and stdout/stderr rules.
- **D-05 — macOS app:** reviewed manual runs, automatic-run authorization, cleanup confirmation, and privacy-safe persisted status.

## Detailed tasks

### - [x] CA-01 — Establish exact recurring-occurrence identity

Define and validate an application boundary identity that combines the fetched event identifier, physical calendar, original recurring occurrence date when present, and enough snapshot range information for an adapter to find the exact occurrence. The EventKit adapter must fail on zero or multiple matches and delete only `.thisEvent`. Automated selection tests are required; harmless real-EventKit recurring validation remains an explicit manual check.

**Dependencies:** none.

**Likely targets:** application event DTOs, `EventKitCalendarStore.swift`, deterministic adapter-boundary tests, and `docs/manual-validation.md`.

**Evidence:** `CalendarEventIdentity` now carries physical calendar, provider event identifier, stable recurring `occurrenceDate`, and the original loaded snapshot range. The EventKit adapter searches that range and requires exactly one candidate matching calendar, ID, and occurrence date before deleting `.thisEvent`. `CalendarAuthorizationTests` covers detached-occurrence and ambiguous-match selection. Real recurring EventKit mutation remains pending for CA-13 manual validation.

### - [x] CA-02 — Introduce access DTOs and capability-separated ports

Add framework-free authorization states, privacy-safe access failures, an authorization-inspection port, and a separate full-access request port. Add an explicit app setup/recovery use case. Ordinary inventory and reconciliation APIs must not receive the request capability. Continue toward opaque physical-calendar and exact-occurrence references without making provider IDs selectors, visible-set keys, routing inputs, or ownership markers.

**Dependencies:** CA-01 for the final occurrence-reference shape.

**Evidence:** Added framework-free authorization states/errors, separate `CalendarAuthorizationStatusPort` and `CalendarFullAccessRequestPort`, explicit setup and inventory use cases, and access/preflight DTOs. Reusable handlers no longer construct concrete EventKit adapters. `PhysicalCalendarReference` and `CalendarEventReference` now preserve exact provider identity for topology collision checks, mutation targets, deterministic ordering, and reviewed-action equality while redacting their descriptions. Raw provider identifiers are available only through package-internal EventKit lookup and approved successful CLI inventory formatting paths. Deterministic authorization, preflight, cleanup, mutation, reconciliation, privacy, and CLI suites pass.

### - [x] CA-03 — Make EventKit store operations non-prompting

Move permission requesting into a dedicated EventKit request adapter. Inventory, event reads, creates, and deletes inspect authorization and fail without prompting. Map all current and future authorization states fail-closed, keep EventKit mechanics at the adapter edge, and resolve recurring deletes exactly.

**Dependencies:** CA-01 and CA-02.

**Evidence:** `EventKitCalendarAuthorizationStatus` owns status mapping and the only `requestFullAccessToEvents` call. `EventKitCalendarStore` list/read/create/delete methods inspect full access and never request it. CLI composition injects only non-prompting store behavior into ordinary commands.

### - [x] CA-04 — Deliver configuration-independent inventory

Add a reusable inventory use case requiring pre-existing full access. Empty inventory is successful. CLI inventory includes source/account, title, diagnostic EventKit calendar ID, and writability; app inventory omits IDs. Both surfaces distinguish inventory from configured readiness.

**Dependencies:** CA-02 and CA-03.

**Evidence:** `CalendarInventoryUseCase` requires pre-existing full access and treats an empty inventory as success. CLI output includes IDs and a no-readiness disclaimer; app output omits IDs. The app exposes separate setup/recovery and inventory actions and no longer includes a menu-bar scene. Authorization/inventory suites and the app target build pass.

### - [x] CA-05 — Implement shared complete-topology preflight

Resolve every configured role exactly, detect missing and ambiguous selectors plus physical-calendar collisions, check every role's writability, and read sequentially hub first then work calendars in declaration order. Aggregate every safely determinable failure and expose an executable snapshot only on complete success.

**Dependencies:** CA-02, CA-03, D-01, and D-02.

**Evidence:** `CalendarAccessPreflightUseCase` gates on full authorization, resolves every configured role exactly, aggregates missing/ambiguous/collision/read-only/read-failure issues, reads resolvable calendars hub-first then in declaration order, performs no mutation, and returns a snapshot only on complete success. `CalendarAccessPreflightTests` passes.

### - [x] CA-06 — Integrate ordinary configured readiness

Use the same complete preflight and loaded snapshot for config check, ordinary dry-run, apply, explanation, and app manual/automatic operations. Preserve validation-before-EventKit ordering, the migration-pending config-check exception, canonical local-date windows, and ready-empty-plan success.

**Dependencies:** CA-05, D-01, D-02, and D-03.

**Evidence:** Added a DST-safe whole-local-date ordinary window calculator. `ReconcileCalendarsUseCase` now validates settings, runs the shared complete preflight once, and maps the successful ordered snapshot into the existing planner context. Dry-run, apply, and explanation reject aggregate access issues before planning or mutation, require every role to be writable, and reuse the same loaded events. Focused preflight, window, reconciliation, and command-handler suites pass.

### - [x] CA-07 — Implement cleanup preflight and verification

Require legacy markers before EventKit access, read every role over the complete cleanup range, prevent subset deletion, and re-read the full range after confirmed cleanup deletions. Verification failure or any remaining exact legacy-marker match is unsuccessful without rollback.

**Dependencies:** CA-05, D-01, D-02, and D-03.

**Evidence:** Settings now include validated legacy tombstones and the accepted 100-day ordinary default. Added exact marked-title parsing, the full DST-safe cleanup range, a deterministic hub-first/delete-only cleanup plan, complete-topology cleanup preflight, exact occurrence deletion, and a fresh complete-range verification read. Verification read failure or remaining matches is unsuccessful without rollback. `CalendarCleanupAccessTests` and the full deterministic runner pass.

### - [x] CA-08 — Implement ordered mutation execution and partial results

Execute exact ordered actions one at a time, confirm each mutation only after EventKit success, stop at the first failure, and never roll back. Return privacy-safe per-role counts/categories. Ordinary success needs every action confirmation and no verification read; cleanup success additionally needs CA-07 verification.

**Dependencies:** CA-01 through CA-03, CA-06, CA-07, and D-03.

**Evidence:** Added a shared action/confirmation/result boundary and `CalendarMutationExecutor`. Ordinary apply constructs the accepted hub-delete, work-delete, hub-create, work-create phases with deterministic within-calendar ordering. Ordinary and cleanup apply confirm only successful actions, stop on first failure, return privacy-safe role/count/category partial results, and perform no rollback. Empty plans succeed without store calls. Executor, ordinary use-case, cleanup, and full contract tests pass.

### - [x] CA-09 — Wire the complete CLI contract

Add config check and cleanup modes, early option-conflict validation, non-prompting composition, progressive stdout confirmations, stderr failures, binary status semantics, execution-ordered review rows, and the specification's narrow ID-disclosure exceptions.

**Dependencies:** CA-04, CA-06 through CA-08, and D-04.

**Evidence:** Added `calrelay config check`, `--cleanup-legacy`, early ArgumentParser option-conflict validation, ordinary migration blocking, the config-check migration exception, cleanup dry-run/apply review, progressive post-success confirmations, verified cleanup success, and process-level help/validation smoke tests. Ordinary and cleanup rows follow application-owned execution order. Successful results use stdout; thrown failures use ArgumentParser's nonzero stderr path. Ordinary explanation now uses the shared effective window and ordered plan, reports the configured horizon, classifies every input independently across eligibility, exact routing/source treatment, expectation match, and disposition, retains every causal input identity for collapsed creates and exact delete identity/reasons, and renders the approved ID correlation only on successful `--explain`. Planner alignment covers attendee/no-attendee eligibility, all-day and unavailable events, exact marker parsing, authoritative marked-hub routing, reconciled-logical-hub suppression, cancelled replacement, replace-all duplicates, and source-title normalization. Focused contract/handler tests and binary failure tests prove non-mutation, action-order equality, stdout/stderr semantics, and no partial explanation or ID disclosure on failure. `make format-check`, `make check`, and `make app` pass on September 17, 2026. Successful live EventKit explanation remains an explicit CA-13 manual check.

### - [ ] CA-10 — Wire app permission, inventory, readiness, and run integrations

Make the clearly labeled setup/recovery action the only prompt owner. Separate authorization, inventory, configuration validity, readiness, and migration state. Keep EventKit work off `@MainActor`, remove the unsupported menu-bar surface, and ensure manual, scheduled, retry, and cleanup operations cannot access the request capability.

**Dependencies:** CA-03 through CA-08 and D-05.

**Evidence:** The access-owned app slice is complete: the normal Dock-visible app has no menu-bar item; only **Set Up or Recover Calendar Access** can request permission; ID-free inventory is separate; and a reusable status use case presents dependency-ordered configuration, authorization, complete readiness, and migration states without prompting. **Dry Run Sync** reloads the canonical settings and current Calendar snapshot, uses shared preflight/planning, and performs no mutation. **Run Sync Now** now provides exact-plan reviewed manual apply with fresh preflight and pre-mutation configuration validation; see D05-03. The task remains open for app cleanup, scheduled/automatic runs, standing authorization, configuration observation/status recovery, and persisted operation status.

### - [ ] CA-11 — Centralize privacy-safe diagnostics and presentation

Use stable failure/action categories rather than raw framework errors. Encode distinct inventory, readiness, explanation, cleanup-review, partial-result, and persisted-status disclosure models. Add negative tests for IDs, titles, selectors, markers, raw YAML, and EventKit dumps.

**Dependencies:** CA-02 and every presentation-producing task.

**Evidence:** Added purpose-specific inventory, readiness, ordinary app dry-run, cleanup-review, confirmation, partial-result, and cleanup-verification formatting. Failures expose only approved roles, selectors, counts, and categories; the app dry run exposes only aggregate delete/create counts; cleanup review omits IDs/selectors/calendar titles/marker values; app inventory omits IDs. Strict YAML validation rejects duplicate/unknown keys without echoing raw values. `CalendarAccessPrivacyTests` and the dry-run formatter checks pass. The task remains open for D-05-owned persisted app operational status and app cleanup presentation.

### - [ ] CA-12 — Complete deterministic acceptance coverage

Register focused authorization, inventory, preflight, cleanup, mutation, privacy, exact-occurrence, and CLI contract suites in the custom executable runner. Cover every `ACCESS-AC-01` through `ACCESS-AC-15` check without live EventKit.

**Dependencies:** incremental alongside CA-01 through CA-11.

**Evidence:** Focused authorization, inventory, preflight, window, cleanup, mutation, privacy, control-panel status, manual app dry-run/apply, handler, contract, and process-smoke suites are registered in the custom runner. `CalendarManualDryRunTests` proves fresh settings loading, shared planning, migration blocking before Calendar access, non-mutation, and aggregate-only presentation. `CalendarReviewedActionTests` and `CalendarManualApplyTests` cover reviewed executable identities, fresh snapshots/configuration, stale confirmation, cancellation, empty plans, partial failure, and reentrant confirmation. The task remains open for automatic app operation, persisted-state, and app-cleanup acceptance checks.

### - [ ] CA-13 — Update operational documentation and validate

Update manual validation for permission recovery, no-prompt CLI behavior, inventory/readiness separation, aggregate preflight failures, revoked access, partial apply, cleanup verification, and exact recurring deletion. Run focused suites followed by `make format-check`, `make check`, and `make app`.

**Dependencies:** all implementation tasks.

**Earlier evidence:** Updated `README.md`, `docs/configuration.md`, and `docs/manual-validation.md` for permission ownership, inventory/readiness separation, config check, complete ordinary explanation, cleanup, partial failure, and app ordinary dry run. The earlier September 17 gate passed but delayed bundle verification was unstable in the file-provider workspace. D05-01 through D05-03 below supersede that packaging limitation and record the subsequent manual-apply implementation, final gate, and non-mutating live evidence. Full-access permission, provider, successful live dry run/explanation, recurring-occurrence, and mutation validation remain unresolved under D05-04, so CA-13 remains open.

## September 17 manual verification and D-05 continuation

The following checkpoints supplement CA-10 through CA-13; they do not close the
parent tasks while cleanup, automation, persistence, or required live checks remain
unresolved.

### - [x] D05-01 — Repair and verify local app packaging

`make app` reproduced a strict signing failure caused by disallowed
`com.apple.FinderInfo` being attached inside the file-provider workspace. A clean
copy outside the workspace passed signing and delayed strict verification. The
build script now assembles the app in a workspace-keyed local cache and exposes
the existing `.build/CalRelay.app` launch path through a symlink. Bundle identity,
ad-hoc signing, and strict verification are unchanged. See ADR 0002.

### - [x] D05-02 — Exercise available non-mutating live checks

The rebuilt CLI's inventory, config check, ordinary dry run, explanation, and
cleanup dry run all failed nonzero with empty stdout and app recovery guidance
while access was unavailable. Configuration-dependent checks used synthetic
temporary configuration, never the personal configuration. The built app launched
with regular Dock-visible activation policy and one window. Accessibility-based
inspection pressed **Refresh Status**, observed its completion, identified distinct
configuration/access/readiness/migration status areas, and confirmed both
**Dry Run Sync** and **Run Sync Now** were disabled while access was not determined.
No permission setup action was pressed, no authorization state was reset, and no
calendar mutation was attempted.

### - [x] D05-03 — Deliver reviewed manual ordinary apply and validation

Added one-use review tokens and aggregate confirmation UI for **Run Sync Now**.
Confirmation reloads settings, repeats complete preflight/planning, compares ordered
executable identities and semantic configuration, then reloads configuration once
more immediately before execution. Changed plans return a fresh review even when
counts match. Exact delete identity excludes rationale/fetched field changes and
lookup ranges; execution uses the fresh snapshot's occurrence lookup data. Partial
failure consumes review authorization and displays aggregate counts without raw
errors or event details. Actor and view-model guards prevent overlapping current
manual workflows. Global trigger coalescing remains part of the automation slice.

`CalendarReviewedActionTests` and `CalendarManualApplyTests` are registered in the
custom executable runner. The initial missing APIs failed to compile as expected;
an additional empty-plan/configuration-change regression failed at runtime before
the configuration binding was added. Focused tests then passed, including changed
snapshot physical calendars, event references and recurring occurrences, fresh
lookup data, changed writability, configuration races, empty success, cancellation,
privacy-safe partial failure, and concurrent confirmation. Final
`make format-check`, `make check`, `make app`, property-list validation, shell syntax,
`git diff HEAD --check`, and delayed strict signature verification passed on
September 17, 2026. SwiftLint reported zero violations; formatting reported only
pre-existing warnings in untouched files. The installed Swift toolchain also
reported missing search-path warnings, without build or test failure. The rebuilt
app's denied/unavailable-access surface was exercised; full-access manual apply
remains a separate unresolved D05-04 checkpoint.

### - [ ] D05-04 — Complete dedicated-calendar live acceptance

Still requires explicit Calendar permission interaction and confirmed dedicated
test calendars: successful inventory/readiness/dry run/explanation, full-access
manual review/apply/cancel/reconfirmation, provider convergence, cleanup mutation
and verification, and exact recurring-occurrence deletion. Do not treat denied
access checks or fake-backed tests as evidence of these outcomes. Preserve the
existing canonical configuration and do not mutate personal calendars.

### - [ ] D05-05 — Deliver separately reviewed app legacy cleanup

Implement APP-02 cleanup using the shared full-range preflight, deterministic
delete-only plan, executor, and post-delete verification (ACCESS-04, RECON-04,
CONFIG-08). Add a pre-mutation authorization gate, one-use app review tokens,
fresh exact-action/configuration comparison, and transient execution-ordered
review with no IDs, selectors, calendar names, or explicit marker values.
Serialize current manual workflows; preserve confirmed counts after partial or
verification failure. Never mutate YAML or combine cleanup with ordinary sync.

**Dependencies:** D05-03, CA-07, CA-08. D05-04 live acceptance remains separate.
**Validation:** deterministic custom-runner tests for reconfirmation, preflight,
configuration races, cancellation, concurrency, partial failure, verification,
and privacy; existing CLI regression suites; `make format-check`, `make check`,
`make app`, and documentation/diff checks. In progress September 18, 2026.

## Risks and mitigations

- **Recurring identifier ambiguity:** use the original occurrence date plus physical calendar and fail closed on zero or multiple matches.
- **Accidental prompts:** separate inspection and request capabilities and do not inject the request port into ordinary operations.
- **Sensitive diagnostics:** use purpose-specific DTOs/formatters and prohibit raw EventKit errors or object dumps at presentation boundaries.
- **Partial topology use:** make failed preflight results unable to supply an executable snapshot.
- **Authorization changes after preflight:** treat them as mutation-phase partial failure, stop, and do not roll back.
- **Cross-spec duplication:** consume canonical settings, windows, plans, and app coordinators from their owning slices.

## Validation

Focused suites will use exact names registered in `Tests/CalRelayKitTests/Main.swift`. Final Swift/app validation is:

```sh
make format-check
make check
make app
```

Real Calendar mutation is reserved for explicit harmless manual validation.

## Progress tracking

- [x] CA-01 — Establish exact recurring-occurrence identity
- [x] CA-02 — Introduce access DTOs and capability-separated ports
- [x] CA-03 — Make EventKit store operations non-prompting
- [x] CA-04 — Deliver configuration-independent inventory
- [x] CA-05 — Implement shared complete-topology preflight
- [x] CA-06 — Integrate ordinary configured readiness
- [x] CA-07 — Implement cleanup preflight and verification
- [x] CA-08 — Implement ordered mutation execution and partial results
- [x] CA-09 — Wire the complete CLI contract
- [ ] CA-10 — Wire app permission, inventory, readiness, and run integrations
- [ ] CA-11 — Centralize privacy-safe diagnostics and presentation
- [ ] CA-12 — Complete deterministic acceptance coverage
- [ ] CA-13 — Update operational documentation and validate
- [x] D05-01 — Repair and verify local app packaging
- [x] D05-02 — Exercise available non-mutating live checks
- [x] D05-03 — Deliver reviewed manual ordinary apply and validation
- [ ] D05-04 — Complete dedicated-calendar live acceptance
- [ ] D05-05 — Deliver separately reviewed app legacy cleanup

## Next action

Finish dedicated-calendar live acceptance with the operator and continue D-05
with separately confirmed app cleanup, configuration observation and status
recovery, standing authorization, serialized
trigger coalescing, scheduling, and privacy-safe persisted operational state.
Keep CA-10 through CA-13 open until those remaining requirements have evidence.
