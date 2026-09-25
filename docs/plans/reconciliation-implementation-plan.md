# Reconciliation implementation plan

## Plan record

- **Status:** Complete; `REC-01` through `REC-08` have current passing evidence.
- **Prepared:** September 25, 2026.
- **Canonical requirements:**
  [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md), revision 6,
  accepted September 16, 2026.
- **Scope:** Verification-first implementation work required to bring ordinary
  reconciliation, cleanup planning, exact explanation, reviewed plans, and fresh
  automatic attempts into full compliance with the accepted reconciliation
  contract.
- **Current state:** Current HEAD satisfies all nineteen reconciliation acceptance
  checks with deterministic evidence. Ordered ordinary actions are authoritative,
  compatibility summaries are derived, exact occurrence ordering uses typed
  identity values, and focused convergence coverage proves provider-lag repetition,
  partial duplicate replacement, later repair, and fresh coalesced automatic work.
- **Readiness:** Complete. Required focused suites, formatting, linting, build,
  full deterministic tests, CLI help smoke checks, diff inspection, and workspace
  review have passed. There are no unresolved product decisions or blockers.

## Outcome

Demonstrate that current HEAD satisfies `RECON-01` through `RECON-06` and
`RECON-AC-01` through `RECON-AC-19`. If verification exposes a defect, retain a
focused failing regression test and make the smallest correction that restores
the accepted contract.

The implementation must preserve pure visible-set matching, exact occurrence
targeting, deterministic delete-first ordering, shared ordinary explanation,
fresh reviewed and automatic plans, local ordinary completion semantics, and
cleanup's stronger post-mutation verification requirement.

## Current-state assessment

Source inspection indicates that most accepted behavior is already present:

- `ReconciliationPlanner` performs pure visible-key matching, replaces managed
  duplicate sets, treats cancelled managed events as unsatisfying, and models a
  rename or visible change as an old delete plus a new create.
- `ReconcileCalendarsUseCase` owns one shared ordinary computation used by dry
  run, apply preparation, standing authorization, and explanation.
- Locally owned hub projections selected for deletion are excluded before
  work-calendar expectations are produced.
- Ordinary executable actions are ordered as hub deletes, declaration-ordered
  work deletes, hub creates, and declaration-ordered work creates.
- Reviewed-plan comparison includes physical-calendar and exact occurrence
  identity while tolerating rationale-only changes.
- Cleanup has a separate ordered delete-only plan and a complete fresh no-match
  verification snapshot.
- Automatic retry invokes a fresh attempt rather than retaining the prior plan.
- Ordinary success does not perform a post-mutation verification read; cleanup
  does.
- The EventKit adapter fails rather than substituting another occurrence or a
  recurring series when an exact planned occurrence cannot be resolved.
- Commit `a88ab0d` already implements per-run system-calendar capture; this plan
  must not duplicate or reverse that work.

The principal design risk is that ordinary results currently expose both:

1. `ReconciliationPlan.creates` and `ReconciliationPlan.deletes`, a partitioned
   visible-set delta; and
2. `OrdinaryReconciliationResult.actions`, the ordered executable sequence that
   revision 6 defines as the ordinary plan.

The implementation must prevent those representations from diverging while
retaining the pure domain planner and compatibility-facing create/delete
summaries.

Inspection also found acceptance scenarios that need stronger direct evidence:

- provider read-after-write lag repeating a previously confirmed action;
- replacement-create failure after every managed duplicate has been deleted;
- the complete within-calendar sort contract, including Unicode-scalar title
  order and exact-occurrence tie-breaking;
- a coalesced automatic follow-up computing a fresh plan; and
- later fresh reconciliation repairing temporary duplicate, stale, and missing
  projections.

## Scope boundaries

### In scope

- Direct deterministic evidence for `RECON-AC-01` through `RECON-AC-19`.
- A single authoritative application-level ordered ordinary plan.
- Visible-set equality, managed duplicate replacement, cancellation behavior,
  causal links, and reconciled logical-hub routing.
- Exact explanation classifications, action reasons, and approved diagnostic
  identifiers.
- Cleanup selection, ordering, local point-in-time semantics, and complete
  no-match verification.
- Exact occurrence targeting for ordinary and cleanup deletion.
- Delete-first mutation ordering, stop-on-first-failure, and no rollback.
- Fresh manual ordinary and cleanup reviewed-plan comparison.
- Fresh automatic retry and coalesced-follow-up behavior.
- Provider-lag and eventual-repair scenarios.
- CLI execution-order and explanation integration.
- Documentation alignment only when implementation changes a public contract,
  API, or operational workflow.

### Out of scope

- Persistent identity stores, hidden source IDs, notes metadata, or provider IDs
  as visible-set reconciliation keys.
- Cross-process locks, atomic cross-calendar snapshots, or EventKit-notification
  restart behavior.
- Combining cleanup and ordinary reconciliation into one plan or run.
- Partial-topology ordinary reconciliation or cleanup.
- Marker grammar, event eligibility, configuration schema, or routing changes
  not required by a failing reconciliation acceptance check.
- Real EventKit or calendar mutation as an automated check.
- Unrelated refactoring, package changes, dependency updates, or formatting
  churn.

## Change policy

1. Run the existing focused suites before changing production code.
2. Map every reconciliation acceptance check to direct evidence and distinguish
   a failing behavior from an evidence gap.
3. Add or strengthen a deterministic test before changing behavior.
4. Confirm a regression test fails for the expected reason before applying a
   production correction.
5. Make the smallest production change that passes the new test.
6. Keep pure matching in the domain and orchestration, ordering, ports, reviewed
   identity, and explanation in the application layer.
7. Do not move reconciliation or cleanup orchestration into SwiftUI views, app
   delegates, menu handlers, or CLI command declarations.
8. Preserve public API shape where practical. Call out any unavoidable breaking
   API change explicitly.
9. Keep default tests deterministic, fake-backed, isolated, offline, and
   independent of EventKit and real calendars.

## Execution summary

1. `REC-01` establishes the current acceptance baseline and evidence ledger.
2. `REC-02` makes the ordered executable sequence authoritative when current
   evidence demonstrates that the split representations can diverge.
3. `REC-03` closes visible-set and explanation coverage.
4. `REC-04` independently closes cleanup and exact-occurrence coverage.
5. `REC-05` proves global ordering, provider-lag behavior, and eventual repair.
6. `REC-06` proves fresh reviewed, retry, and coalesced-follow-up plans.
7. `REC-07` verifies adapter output and documentation disposition.
8. `REC-08` runs final repository gates and prepares the handoff.

`REC-03` and `REC-04` may proceed in parallel after their prerequisites when
their edits do not overlap. `REC-05` integrates the ordinary-planning evidence
before `REC-06` validates app workflow freshness.

## REC-01 — Establish the reconciliation acceptance baseline

**Dependencies:** None.

**Requirements:** All required outcomes and `RECON-AC-01` through
`RECON-AC-19`.

**Relevant existing suites:**

- `CalRelayContractTests`
- `RoutingSpecificationTests`
- `CalendarCleanupAccessTests`
- `CalendarMutationExecutorTests`
- `CalendarManualApplyTests`
- `CalendarManualCleanupTests`
- `CalendarAutomaticReconciliationTests`
- `CalendarAutomationCoordinationTests`
- `EventKitExactEventOccurrenceResolverTests`
- `ReconcileCommandHandlerTests`

**Work:**

- Run the registered suites that collectively cover reconciliation.
- Create an acceptance ledger mapping every `RECON-AC-*` requirement to a
  concrete test.
- Record whether each requirement is directly demonstrated, indirectly covered,
  missing evidence, or failing.
- Separate reconciliation failures from unrelated pre-existing failures.
- Do not modify production code while establishing the baseline.

- [x] **REC-01:** The current reconciliation baseline and acceptance ledger are
  recorded.
- [x] **REC-01-AC1:** Every `RECON-AC-01` through `RECON-AC-19` entry maps to at
  least one observable test or an explicit evidence gap.
- [x] **REC-01-AC2:** Current failures are separated from missing coverage and
  unrelated pre-existing failures.
- [x] **REC-01-V1:** The focused existing reconciliation suites complete and
  their actual results are recorded.

**Passing baseline (September 25, 2026):** The following registered suite union
completed with `CalRelayKitTests passed` before production changes:

```sh
swift run CalRelayKitTests \
  CalRelayContractTests RoutingSpecificationTests CalendarCleanupAccessTests \
  CalendarManualApplyTests CalendarManualCleanupTests \
  CalendarReviewedActionTests CalendarAutomaticReconciliationTests \
  CalendarAutomationCoordinationTests ReconcileCommandHandlerTests \
  EventKitExactEventOccurrenceResolverTests CalendarMutationExecutorTests \
  OrdinaryReconciliationCalendarCaptureTests OrdinaryReconciliationWindowTests
```

SwiftPM emitted non-fatal linker warnings for absent Command Line Tools search
paths. There were no reconciliation failures or unrelated failures. The baseline
identified evidence gaps rather than failing existing behavior.

### `RECON-AC-*` acceptance ledger at the `REC-01` checkpoint

| Check | Evidence and disposition |
| --- | --- |
| `RECON-AC-01` | **Partial:** `testPlansNoChangesWhenExpectedStateAlreadyExists` proves visible-snapshot idempotency. Direct provider read-after-write lag evidence remains for `REC-05`. |
| `RECON-AC-02` | **Direct:** `testPlansRenameAsDeleteOldAndCreateNew`. |
| `RECON-AC-03` | **Direct:** `testReplacesCancelledManagedProjectionForExpectedKey`, `testDoesNotProjectCancelledMarkedHubEvent`, routing preservation coverage, and `testApplyExecutesDeleteBeforeCreate`. |
| `RECON-AC-04` | **Partial:** `testReplacesAllManagedDuplicatesForExpectedKey` proves replace-all selection. Replacement-create failure followed by later repair remains for `REC-05`. |
| `RECON-AC-05` | **Direct:** `testStaleLocalHubProjectionDoesNotRouteForExtraCycle` and `RoutingSpecificationTests.testStaleLocalHubProjectionIsExcludedFromLogicalHub`. |
| `RECON-AC-06` | **Direct:** `testExplanationUsesSharedOrderedActionsAndCreateCausality`. |
| `RECON-AC-07` | **Direct:** `testExplanationClassifiesEveryInputDimensionAndReportsWindow` and `testExplanationUsesSharedOrderedActionsAndCreateCausality`. |
| `RECON-AC-08` | **Direct:** the explanation classification fixtures cover eligibility, routing, expectation, disposition, and action-reason categories. |
| `RECON-AC-09` | **Partial:** exact identifiers are present in explanation and reviewed identity. Complete tied-delete ordering and selected-set independence evidence remains for `REC-03` and `REC-05`. |
| `RECON-AC-10` | **Partial:** `testCleanupDryRunSelectsOnlyExactLegacyMarkersInTopologyOrder` and cleanup verification tests cover exact selection, topology order, and no-match verification. The complete within-calendar sort remains for `REC-04`. |
| `RECON-AC-11` | **Direct:** `EventKitExactEventOccurrenceResolverTests` proves exact, missing, and ambiguous occurrence behavior. |
| `RECON-AC-12` | **Direct:** `RoutingSpecificationTests.testRetiredMarkerCanBeRepublishedAndRemovedByRepeatedCleanup`. |
| `RECON-AC-13` | **Partial:** ordinary formatter, executor, apply-order, and stop-on-failure tests cover global order and failure semantics. Complete within-calendar temporal, all-day, Unicode-scalar, and occurrence tie-break ordering remains for `REC-05`. |
| `RECON-AC-14` | **Direct:** all mapped planner, explanation, cleanup, and mutation evidence is deterministic and fake-backed. |
| `RECON-AC-15` | **Direct:** manual ordinary and cleanup suites cover fresh replan, exact physical-calendar and occurrence identity, rationale-only tolerance, and order changes with equal counts. |
| `RECON-AC-16` | **Partial:** `testRetryReloadsFreshConfigurationSnapshotAndPlan` proves retry freshness. The coordinator proves one coalesced follow-up is scheduled, but execution-level fresh settings and snapshot evidence remains for `REC-06`. |
| `RECON-AC-17` | **Evidence gap:** no single acceptance scenario yet demonstrates later fresh repair of temporary duplicate, stale, and missing outcomes. Planned for `REC-05`. |
| `RECON-AC-18` | **Direct:** `testExplanationUsesSharedOrderedActionsAndCreateCausality`. |
| `RECON-AC-19` | **Direct:** ready-empty automatic/manual/CLI tests and ordinary apply read-count assertions prove local success without verification; cleanup apply tests prove the stronger complete no-match verification. |

## REC-02 — Make the ordered executable sequence authoritative

**Dependencies:** `REC-01`.

**Requirements:** `RECON-03`, `RECON-05`, `RECON-06`, `RECON-AC-06`,
`RECON-AC-09`, `RECON-AC-13`, and `RECON-AC-15`.

**Likely production targets if current invariants are insufficient:**

- `Sources/CalRelayKit/Features/CalendarRelay/Domain/Planning/ReconciliationPlan.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/OrdinaryReconciliationResult.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarExecutableActionIdentity.swift`

**Work:**

- Retain the domain planner as a pure visible-set delta computation.
- Treat `OrdinaryReconciliationResult.actions` as the sole authoritative
  application-level executable plan.
- Ensure create/delete summaries are derived from the ordered sequence rather
  than independently supplied values.
- Prevent repository code from constructing an inconsistent summary and action
  sequence.
- Preserve compatibility-facing create/delete summaries for formatters, manual
  reviews, standing authorization, and callers.
- Audit `ReconcileCalendarsUseCase.dryRun`, which returns the partitioned domain
  plan, and retain it only as a compatibility summary rather than a second
  executable plan.
- Keep configured roles and mutation-execution concerns in the application layer
  rather than moving them into the pure domain planner.

**Tests:**

- Prove every ordinary consumer uses the same ordered actions.
- Prove summaries exactly equal the ordered sequence's create/delete partitions.
- Prove action reordering changes reviewed identity even when counts and visible
  fields remain equal.

- [x] **REC-02:** Ordinary reconciliation has one authoritative ordered
  executable-action sequence.
- [x] **REC-02-AC1:** Create/delete summaries cannot diverge from authoritative
  actions.
- [x] **REC-02-AC2:** Domain matching remains deterministic and independent of
  adapters, EventKit, SwiftUI, and filesystem concerns.
- [x] **REC-02-AC3:** Every mutation and detailed-output consumer preserves the
  authoritative order.
- [x] **REC-02-V1:** Focused plan, formatter, reviewed-action, and use-case tests
  pass.

**Implementation evidence (September 25, 2026):**

- `OrdinaryReconciliationResult` now stores only ordered `actions`; its
  compatibility `plan` is derived from those actions.
- The deprecated `init(plan:actions:)` remains source-compatible but cannot make
  its independently supplied summary authoritative.
- `ReconcileCalendarsUseCase` constructs the result from ordered actions only.
- `testOrdinaryResultDerivesCompatibilityPlanFromAuthoritativeActions` failed
  first because the invariant-preserving initializer did not exist, then passed
  after the minimal implementation.
- `CalRelayContractTests`, `CalendarReviewedActionTests`,
  `CalendarMutationExecutorTests`, `ReconcileCommandHandlerTests`,
  `CalendarManualApplyTests`, and `CalendarAutomaticReconciliationTests` passed
  together after the change.

## REC-03 — Close visible-set and explanation coverage

**Dependencies:** `REC-02`.

**Requirements:** `RECON-01`, `RECON-02`, `RECON-03`, `RECON-AC-01` through
`RECON-AC-09`, `RECON-AC-14`, and `RECON-AC-18`.

**Preferred test organization:**

Add a focused registered suite at
`Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/ReconciliationSpecificationTests.swift`
and register its `runAll()` entry point in `Tests/CalRelayKitTests/Main.swift`.
This keeps reconciliation acceptance evidence cohesive without continuing to
expand the broad `CalRelayContractTests` suite.

**Required scenarios:**

- Visible equality uses only physical calendar, exact title, start, end, and
  all-day flag.
- Provider event identity does not affect expectation satisfaction.
- Rename or visible change becomes an old delete plus a new create.
- One non-cancelled managed match is retained.
- A cancelled managed match is deleted and replaced.
- Two or more managed matches are all deleted and replaced by one create.
- A cancelled non-local marked hub event is preserved and creates no work
  blocker.
- A stale local hub projection is excluded from logical-hub routing in the same
  run.
- Multiple causal source occurrences create one expectation and retain every
  causal identity.
- Dry-run and explanation return identical ordered actions from identical
  snapshots.
- Explanation classifies every input across eligibility, routing, expectation,
  and disposition.
- Exact duplicate events remain distinguishable by diagnostic event ID.
- Exact identity does not change visible matching or selected-action membership.

Production code changes are permitted only when one of these acceptance tests
fails.

- [x] **REC-03:** Visible-set planning and explanation have direct deterministic
  acceptance coverage.
- [x] **REC-03-AC1:** Rename, cancellation, duplicate replacement, logical-hub
  routing, and set-semantic causality match `RECON-01`.
- [x] **REC-03-AC2:** Explanation annotates the shared computation rather than
  recomputing reconciliation.
- [x] **REC-03-AC3:** EventKit identifiers affect only approved diagnostic,
  exact-target, reviewed-identity, and final tie-breaking roles.
- [x] **REC-03-V1:** `ReconciliationSpecificationTests`,
  `CalRelayContractTests`, and `RoutingSpecificationTests` pass.

**Passing evidence (September 25, 2026):** A new registered
`ReconciliationSpecificationTests` suite directly covers visible-key fields,
provider-ID independence, rename, cancellation, duplicate replacement, stale
logical-hub exclusion, cancelled non-local marker preservation, shared dry-run and
explanation actions, complete input classification, set-semantic causal links,
and exact-duplicate diagnostic identity. The focused suite started green, so no
production correction was justified.

## REC-04 — Verify cleanup planning and exact occurrence targeting

**Dependencies:** `REC-01`. This task may proceed in parallel with `REC-03` when
their edits do not overlap.

**Requirements:** `RECON-04`, `RECON-AC-10`, `RECON-AC-11`, `RECON-AC-12`,
`RECON-AC-14`, and the cleanup portion of `RECON-AC-19`.

**Likely production targets if defects are exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarCleanupPlan.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarCleanupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/EventKitExactEventOccurrenceSelector.swift`

**Work:**

- Verify exact, case-sensitive legacy-marker matching.
- Verify hub-first and work-calendar declaration order.
- Add a complete within-calendar cleanup sort test covering ascending start,
  ascending end, timed before all-day, exact Unicode-scalar title order, and
  exact occurrence identity as the final tie-breaker.
- Verify cleanup performs deletes only.
- Verify post-apply validation is a fresh exact no-match check and does not
  produce or execute a second cleanup plan.
- Verify a later recreated legacy event produces a new cleanup delete without
  invalidating the earlier run's local point-in-time success.
- Verify missing or ambiguous exact recurring occurrences stop cleanup without
  substitution.

- [x] **REC-04:** Cleanup planning and execution satisfy the complete
  deterministic contract.
- [x] **REC-04-AC1:** Only exact legacy-marker matches are selected.
- [x] **REC-04-AC2:** Cleanup ordering satisfies every global and within-calendar
  ordering rule.
- [x] **REC-04-AC3:** Post-delete verification performs no unplanned deletion.
- [x] **REC-04-AC4:** Recurrence deletion never substitutes a different
  occurrence or series.
- [x] **REC-04-V1:** Cleanup, manual cleanup, CLI cleanup, and exact occurrence
  suites pass.

**Passing evidence (September 25, 2026):**

- `testCleanupPlannerUsesCompleteWithinCalendarOrder` directly proves ascending
  start, ascending end, timed-before-all-day, Unicode-scalar title order, and
  exact occurrence tie-breaking.
- Existing cleanup access, manual cleanup, CLI cleanup, routing convergence, and
  exact EventKit occurrence suites prove exact marker selection, topology order,
  delete-only execution, fresh no-match verification without a second plan, later
  recreation and repeated cleanup, and no missing/ambiguous occurrence
  substitution.
- `ReconciliationSpecificationTests` and `CalendarCleanupAccessTests` passed
  together; no production correction was required.

## REC-05 — Prove ordered mutation, provider lag, and eventual repair

**Dependencies:** `REC-02` and `REC-03`.

**Requirements:** `RECON-02`, `RECON-06`, `RECON-AC-01`, `RECON-AC-04`,
`RECON-AC-13`, `RECON-AC-17`, and `RECON-AC-19`.

**Likely production targets if defects are exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarMutationExecutor.swift`

**Required scenarios:**

- Full ordinary order is hub deletes, declaration-ordered work deletes, hub
  creates, and declaration-ordered work creates.
- Within-calendar action order covers every defined temporal, all-day, title,
  and exact-occurrence sort field.
- A hub-phase failure prevents every later work-calendar action.
- Replace-all duplicates are all deleted before the replacement create.
- Replacement-create failure leaves confirmed duplicate deletes applied and the
  blocker temporarily absent.
- A later fresh run repairs the missing blocker.
- Provider lag may cause a later fresh snapshot to repeat a confirmed create or
  target an already-absent delete.
- No cooldown, mutation overlay, old-plan suppression, or ordinary verification
  read is introduced.
- Scripted fresh snapshots demonstrate repair of temporary duplicate, stale, and
  missing projections.
- Empty ordinary plans succeed without mutation or verification reads.

- [x] **REC-05:** Ordered mutation and eventual-repair behavior have direct
  deterministic evidence.
- [x] **REC-05-AC1:** The first failed action stops all later actions without
  rollback.
- [x] **REC-05-AC2:** Duplicate replacement failure demonstrates the accepted
  temporary missing-blocker risk.
- [x] **REC-05-AC3:** Provider lag may repeat actions without creating false
  verification or idempotency claims.
- [x] **REC-05-AC4:** Later fresh reconciliation repairs duplicate, stale, and
  missing visible state.
- [x] **REC-05-V1:** Planner, executor, CLI apply, and convergence-focused tests
  pass.

**Implementation evidence (September 25, 2026):** A new registered
`ReconciliationConvergenceTests` suite proves complete global and within-calendar
ordinary order, hub-phase stop-on-failure, replace-all deletion before a failing
replacement create, fresh missing-blocker repair, provider-lag repetition without
verification reads, and later duplicate/stale convergence to empty plans. Its
initial ordering assertion failed because occurrence timestamps were stringified
for the final tie-break; pre-reference-date values therefore had incorrect
lexicographic order. `ActionSortKey` now compares typed event reference and
optional occurrence date values. The convergence suite and the broader planner,
executor, CLI, manual-apply, and automatic suites pass after that focused fix.

## REC-06 — Verify reviewed plans and fresh automatic attempts

**Dependencies:** `REC-02` and `REC-05`.

**Requirements:** `RECON-05`, `RECON-AC-15`, and `RECON-AC-16`.

**Likely production targets if defects are exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualApplyUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualCleanupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomaticReconciliationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAppOperationCoordinator.swift`
- `Sources/CalRelayApp/CalendarListViewModel+Automation.swift` only if a proven
  composition defect requires an app-source change.

**Work:**

- Preserve existing physical-calendar, event-reference, occurrence, order, and
  configuration-change reviewed-plan tests.
- Verify rationale-only changes tolerate diagnostic changes while executing the
  fresh actions.
- Verify same-count but executably different plans require renewed review.
- Verify partial manual ordinary failure consumes confirmation and manual
  recovery requires a fresh review.
- Verify cleanup review uses the same exact ordered-target semantics.
- Verify each retry performs a new settings load, preflight, snapshot, and plan.
- Add direct evidence that a coalesced follow-up starts a new automatic attempt
  and cannot reuse the preceding plan or partially applied action list.
- Keep workflow orchestration outside SwiftUI. Introduce a test seam at the
  application or composition boundary if the existing seam cannot demonstrate
  fresh coalesced execution.

- [x] **REC-06:** Manual, cleanup, retry, and coalesced automatic flows use fresh
  exact plans.
- [x] **REC-06-AC1:** Reviewed plans compare ordered executable identity rather
  than counts, age, or visible summaries.
- [x] **REC-06-AC2:** Rationale-only changes do not invalidate unchanged
  executable identity.
- [x] **REC-06-AC3:** Retry and coalesced-follow-up attempts independently load
  and compute fresh inputs.
- [x] **REC-06-V1:** Reviewed-action, manual apply, manual cleanup, automatic
  reconciliation, and coordination suites pass.

**Passing evidence (September 25, 2026):** Existing manual ordinary and cleanup
suites prove fresh exact ordered-plan comparison, physical-calendar and occurrence
identity, rationale-only tolerance, same-count invalidation, and consumed
confirmation after partial failure. Existing retry coverage proves independent
settings, inventory, and snapshot loading.
`testCoalescedFollowUpLoadsAndExecutesFreshPlan` now composes the application
operation coordinator with the real automatic use case: after a partial first
attempt, one coalesced follow-up performs new settings, inventory, hub, and work
reads and executes a different fresh create rather than resuming the failed plan.
No app-source change or new composition seam was required.

## REC-07 — Verify adapters and documentation disposition

**Dependencies:** `REC-03` through `REC-06`.

**Requirements:** `RECON-03`, `RECON-AC-06`, `RECON-AC-07`, `RECON-AC-10`,
`RECON-AC-13`, and `RECON-AC-19`.

**Likely targets:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconciliationPlanFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/EventExplanationFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandler.swift`
- `docs/configuration.md`

**Work:**

- Verify ordinary dry-run and explanation action rows follow execution order.
- Verify CLI apply executes the same sequence presented by dry-run for the same
  snapshot.
- Verify successful explanation contains the approved IDs and every required
  semantic classification.
- Verify cleanup remains separate and has no explanation mode.
- Verify ordinary no-change success does not claim post-apply verification.
- Update project documentation only if behavior, public API usage, or operational
  guidance changes.
- Do not modify the accepted specification unless implementation reveals a real
  contract conflict requiring explicit approval.

- [x] **REC-07:** Inbound adapters accurately expose the shared reconciliation
  behavior.
- [x] **REC-07-AC1:** CLI dry-run, apply, and explanation agree on the
  authoritative ordinary plan.
- [x] **REC-07-AC2:** Cleanup output remains separate, ordered, and privacy-safe.
- [x] **REC-07-AC3:** Documentation remains accurate without duplicating
  implementation detail into the specification.
- [x] **REC-07-V1:** `ReconcileCommandHandlerTests` and CLI smoke tests pass.

**Documentation disposition (September 25, 2026):** Handler and process-level
coverage already proves execution-ordered ordinary dry-run and explanation rows,
post-success apply confirmations, invalid cleanup-plus-explanation rejection,
separate ordered privacy-safe cleanup output, and ordinary no-change success
without a verification claim. `docs/configuration.md` already documents delete-first
phase order, within-calendar ordering, duplicate replacement risk, provider lag,
local ordinary completion, and cleanup verification. No public workflow or
configuration guidance changed, so no project-documentation edit was required.

## REC-08 — Run final gates and prepare handoff

**Dependencies:** `REC-01` through `REC-07`.

Run focused verification with exact registered suite names:

```sh
swift run CalRelayKitTests ReconciliationSpecificationTests ReconciliationConvergenceTests CalRelayContractTests RoutingSpecificationTests
swift run CalRelayKitTests CalendarMutationExecutorTests EventKitExactEventOccurrenceResolverTests
swift run CalRelayKitTests CalendarCleanupAccessTests CalendarManualCleanupTests ReconcileCommandHandlerTests
swift run CalRelayKitTests CalendarReviewedActionTests CalendarManualApplyTests CalendarAutomaticReconciliationTests CalendarAutomationCoordinationTests
```

The `ReconciliationSpecificationTests` filter applies only when the focused suite
is introduced and registered.

Run the required repository gates:

```sh
make format-check
make check
git --no-pager diff HEAD --check
git status --short
```

Run `make app` when any file under `Sources/CalRelayApp/` changes. Run
`make ui-test` only when app presentation, accessibility behavior, or the UI
workflow changes. Do not use live EventKit or real calendar mutation as an
automated gate.

- [x] **REC-08:** Final validation and handoff are complete.
- [x] **REC-08-AC1:** Every `RECON-AC-*` requirement has current passing
  evidence.
- [x] **REC-08-AC2:** Final diff inspection finds no unrelated configuration,
  routing, projection, or app-lifecycle changes.
- [x] **REC-08-V1:** `make format-check` passes.
- [x] **REC-08-V2:** `make check` passes.
- [x] **REC-08-V3:** `git --no-pager diff HEAD --check` passes.
- [x] **REC-08-V4:** `make app` and `make ui-test` are not applicable because no
  app source, app resource, accessibility contract, fake UI composition, or UI
  workflow changed.
- [x] **REC-08-V5:** The handoff lists every validation command actually run and
  does not claim unrun validation.

**Final validation evidence (September 25, 2026):**

- All four focused suite groups listed above completed with
  `CalRelayKitTests passed`.
- `make format-check` passed.
- The first combined `make format-check && make check` run stopped at SwiftLint
  because a task-owned test contained one extra blank line. After that minimal
  correction, the complete command passed.
- The passing `make check` run completed strict SwiftLint, `swift build`, the full
  deterministic `CalRelayKitTests` runner, and all four CLI help smoke checks.
- `git --no-pager diff HEAD --check` passed before and after the completion-record
  update.
- Tooling emitted non-fatal existing formatting suggestions in untouched app
  files and linker search-path warnings for absent Command Line Tools framework
  directories; neither affected the passing gates.

## Requirement coverage summary

- **Visible-set model and exact explanation:** `REC-02`, `REC-03`.
- **Idempotency and provider convergence:** `REC-03`, `REC-05`.
- **Cleanup planning and exact occurrence deletion:** `REC-04`.
- **Reviewed ordinary and cleanup plans:** `REC-06`.
- **Automatic retry and coalesced-follow-up freshness:** `REC-06`.
- **Global and within-calendar mutation order:** `REC-02`, `REC-04`, `REC-05`.
- **CLI and app boundary behavior:** `REC-06`, `REC-07`.
- **Complete acceptance closure:** `REC-01`, `REC-08`.

## Risks and mitigations

- **Risk:** The split ordinary-plan representations drift apart.
  **Mitigation:** Make ordered actions authoritative and derive compatibility
  summaries from them.
- **Risk:** A broad rewrite destabilizes behavior already compliant with the
  specification. **Mitigation:** Begin with current evidence and require a
  focused failing test before behavioral production changes.
- **Risk:** Exact-order tests become coupled to presentation wording.
  **Mitigation:** Assert typed actions and executable identities; test formatting
  only for semantic row order.
- **Risk:** Provider-lag tests accidentally model a retained mutation overlay.
  **Mitigation:** Script independent fresh snapshots and prove each run trusts
  only its current snapshot.
- **Risk:** Coalescing is tested only as coordinator state rather than fresh
  execution. **Mitigation:** Demonstrate that the follow-up invokes a new
  automatic attempt and performs new settings and calendar reads.
- **Risk:** Ordinary and cleanup sort implementations diverge. **Mitigation:**
  Extract shared pure ordering logic only if focused tests demonstrate actual
  duplication or inconsistency; do not refactor speculatively.
- **Risk:** API cleanup creates an unnecessary breaking change. **Mitigation:**
  Preserve compatibility summaries and call shapes where practical while
  preventing repository code from maintaining two independent executable plans.

## Handoff

- **Next task:** None; the reconciliation implementation plan is complete.
- **Blocked work:** None.
- **Unresolved decisions:** None.
- **Implementation result:** Acceptance-focused tests, one authoritative-plan
  correction, and one typed exact-occurrence ordering fix. No wholesale planner
  rewrite, dependency change, configuration change, app-source change, or accepted
  specification change was required.
- **Completion condition:** Satisfied. `REC-01` through `REC-08` and all required
  child acceptance and verification checks have passing evidence or an explicit
  not-applicable disposition.
