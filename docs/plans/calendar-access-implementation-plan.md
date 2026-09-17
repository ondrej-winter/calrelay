# Calendar Access Implementation Plan

## Plan record

- **Requirements basis:** [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md), revision 7, accepted September 16, 2026.
- **Status:** Ready.
- **Implementation progress:** Partial as of September 17, 2026. The reusable access, complete CLI, cleanup, app-status, opaque-reference, and ordinary explanation slices are implemented; D-05 app run workflows and manual EventKit validation remain open.
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

**Evidence:** The access-owned app slice is complete: the normal Dock-visible app has no menu-bar item; only **Set Up or Recover Calendar Access** can request permission; ID-free inventory is separate; and a reusable status use case presents dependency-ordered configuration, authorization, complete readiness, and migration states without prompting. Deterministic status tests and the app target pass. The task remains open because D-05-owned reviewed manual sync, app cleanup, scheduled/automatic runs, standing authorization, and persisted operation status are not yet implemented.

### - [ ] CA-11 — Centralize privacy-safe diagnostics and presentation

Use stable failure/action categories rather than raw framework errors. Encode distinct inventory, readiness, explanation, cleanup-review, partial-result, and persisted-status disclosure models. Add negative tests for IDs, titles, selectors, markers, raw YAML, and EventKit dumps.

**Dependencies:** CA-02 and every presentation-producing task.

**Evidence:** Added purpose-specific inventory, readiness, cleanup-review, confirmation, partial-result, and cleanup-verification formatting. Failures expose only approved roles, selectors, counts, and categories; cleanup review omits IDs/selectors/calendar titles/marker values; app inventory omits IDs. Strict YAML validation rejects duplicate/unknown keys without echoing raw values. `CalendarAccessPrivacyTests` passes. The task remains open for D-05-owned persisted app operational status and app cleanup presentation.

### - [ ] CA-12 — Complete deterministic acceptance coverage

Register focused authorization, inventory, preflight, cleanup, mutation, privacy, exact-occurrence, and CLI contract suites in the custom executable runner. Cover every `ACCESS-AC-01` through `ACCESS-AC-15` check without live EventKit.

**Dependencies:** incremental alongside CA-01 through CA-11.

**Evidence:** Focused authorization, inventory, preflight, window, cleanup, mutation, privacy, control-panel status, handler, contract, and process-smoke suites are registered in the custom runner. Access checks independent of the absent D-05 app run workflows are covered. The task remains open for manual/automatic app operation and app-cleanup acceptance checks.

### - [ ] CA-13 — Update operational documentation and validate

Update manual validation for permission recovery, no-prompt CLI behavior, inventory/readiness separation, aggregate preflight failures, revoked access, partial apply, cleanup verification, and exact recurring deletion. Run focused suites followed by `make format-check`, `make check`, and `make app`.

**Dependencies:** all implementation tasks.

**Evidence:** Updated `README.md`, `docs/configuration.md`, and `docs/manual-validation.md` for permission ownership, inventory/readiness separation, config check, complete ordinary explanation, cleanup, partial failure, and pending app workflows. `make format-check`, `make check`, `make app`, and `git diff HEAD --check` pass on September 17, 2026. The app-bundle target clears disallowed extended attributes before and after signing and runs `codesign --verify --deep --strict` before reporting success. On this file-provider-backed workspace, provenance metadata is reattached asynchronously, so a delayed standalone strict verification is not stable even though in-target verification passes. Formatter output contains only pre-existing warnings in untouched files. Explicit harmless EventKit permission, provider, successful live explanation, recurring-occurrence, and mutation validation was not run in this automated session, so the task remains open.

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

## Next action

Perform the explicit harmless EventKit validation in `docs/manual-validation.md`, then execute the D-05 plan for reviewed app runs, app cleanup, scheduling, and privacy-safe persisted operational state before closing CA-10 through CA-13.
