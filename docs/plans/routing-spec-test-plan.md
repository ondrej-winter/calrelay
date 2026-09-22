# Routing Specification Test Plan

## Plan record

- **Requirements basis:** [`../specs/routing-spec.md`](../specs/routing-spec.md), revision 4, accepted September 17, 2026.
- **Related accepted contracts:** [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md), [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md), [`../specs/configuration-spec.md`](../specs/configuration-spec.md), and [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md).
- **Readiness:** Ready. The accepted specifications settle routing behavior, topology boundaries, migration convergence, and validation expectations without an unresolved product decision.
- **Progress date:** September 22, 2026.
- **Implementation state:** Complete. Deterministic acceptance evidence and operator guidance are in place; no production routing correction was required.
- **Execution approach:** Add a focused deterministic acceptance suite, make only evidence-driven production corrections, align operational documentation, and complete focused plus repository-wide validation.
- **Workspace constraint:** Preserve the pre-existing staged deletions of `docs/plans/cli-implementation-plan.md` and `docs/plans/configuration-spec-test-plan.md`; do not recreate, unstage, or otherwise alter them.

## Outcome

Provide explicit deterministic evidence for `ROUTE-AC-01` through `ROUTE-AC-13`, including shared-hub multi-machine convergence, independently computed reconciliation-window overlap, repeated cleanup after stale republishing, and topology lifecycle procedures. Correct production behavior only when a focused acceptance test exposes non-conformance.

## Scope

### In scope

- A focused `RoutingSpecificationTests` suite registered with the custom executable test runner.
- Fake-backed shared-hub scenarios with machine-local calendar visibility.
- Exact local, remote, personal, cancelled, and stale-local routing coverage.
- Multi-machine convergence and independent-window overlap coverage.
- Legacy-marker recreation and repeated local cleanup coverage.
- Topology lifecycle and manual-validation guidance.
- Reconciliation-policy version review if executable ordinary semantics change.

### Out of scope

- Global marker registries, remote-marker configuration, leader election, marker authentication, leases, inferred remote deletion authority, persistent ownership metadata, automatic hub migration, unbounded recurrence discovery, whole-series deletion, cross-process locks, or mobile/team features.
- Real EventKit mutation in the automated gate.
- Unrelated refactoring.

## Constraints and invariants

- Domain and application APIs remain deterministic and independent of EventKit, filesystem mechanics, and UI frameworks.
- Test support models calendar visibility, positive-overlap reads, shared state, and port mutation mechanics; it must not reproduce routing policy.
- Non-local marked hub events remain preserved without an age limit or inferred staleness.
- Work-calendar valid-marker events remain managed blockers and may be deleted when absent from hub-derived expectations.
- Cross-machine protection is promised only over the positive overlap of independently computed machine windows.
- Cleanup claims only bounded local point-in-time success.
- Any change to ordinary executable actions, exact targets, or order requires review of `CalendarReconciliationPolicyVersion`.

## Execution sequence

1. `ROUTE-P01` — focused suite and shared-topology test support.
2. `ROUTE-P02` — relay direction and exact-marker semantics.
3. `ROUTE-P03` — shared-hub convergence and authority boundaries.
4. `ROUTE-P04` — independent-window overlap.
5. `ROUTE-P05` — migration recreation and repeated cleanup.
6. `ROUTE-P06` — conditional production corrections and policy review.
7. `ROUTE-P07` — lifecycle and manual-validation documentation.
8. `ROUTE-P08` — traceability and final validation.

## Detailed plan

### - [x] ROUTE-P01 — Establish the focused routing acceptance harness

**Likely targets:** `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/RoutingSpecificationTests.swift`, `Tests/CalRelayKitTests/Main.swift`.

#### - [x] ROUTE-P01-AC1 — Register an exact focused suite

`RoutingSpecificationTests.runAll()` is selectable by the exact suite name `RoutingSpecificationTests`.

#### - [x] ROUTE-P01-AC2 — Keep topology fixtures deterministic and privacy-safe

Fixtures use fixed dates, injected calendars and time zones, harmless titles, deterministic IDs, and no live services.

#### - [x] ROUTE-P01-AC3 — Avoid reproducing routing policy in test support

The shared store implements only port-level visibility, overlap filtering, mutation, and observation.

#### - [x] ROUTE-P01-V1 — Pass the focused suite

Run `swift run CalRelayKitTests RoutingSpecificationTests`.

### - [x] ROUTE-P02 — Prove relay direction, exact markers, and logical-hub behavior

**Requirements:** `ROUTE-01`, `ROUTE-AC-01` through `ROUTE-AC-04`, and `ROUTE-AC-07`.

#### - [x] ROUTE-P02-AC1 — Prove exact local-marker origin exclusion

A non-cancelled locally marked hub event routes unchanged to every other work calendar, not its exact origin, regardless of response or availability.

#### - [x] ROUTE-P02-AC2 — Prove non-local and cancelled marked-hub handling

A non-local valid marked hub event is preserved and routes unchanged; its cancelled form is preserved without routing.

#### - [x] ROUTE-P02-AC3 — Prove personal routing

An eligible unmarked hub event receives the personal marker in every work projection.

#### - [x] ROUTE-P02-AC4 — Prove raw-prefix collisions are irrelevant

Representative `[A]` and `[ACME]` events use exact parsed marker equality.

#### - [x] ROUTE-P02-AC5 — Prove stale-local logical-hub exclusion

A stale locally owned hub projection is deleted and does not route for an extra cycle.

#### - [x] ROUTE-P02-V1 — Pass focused relay tests

Run `RoutingSpecificationTests` and `CalRelayContractTests`.

### - [x] ROUTE-P03 — Prove shared-hub multi-machine convergence and authority boundaries

**Requirements:** `ROUTE-02`, `ROUTE-AC-02`, `ROUTE-AC-06`, and `ROUTE-AC-10`.

#### - [x] ROUTE-P03-AC1 — Prove work-to-hub-to-remote-work convergence

An eligible Work A source reaches the shared hub and Work B without feeding back to Work A.

#### - [x] ROUTE-P03-AC2 — Prove no remote-marker registry is required

Machine B routes marker `[A]` without configuring it.

#### - [x] ROUTE-P03-AC3 — Prove stable convergence

After confirmed actions become visible, fresh runs on both machines are empty.

#### - [x] ROUTE-P03-AC4 — Prove non-local hub authority persists

A manually seeded `[EXTERNAL]` hub event remains untouched and authoritative over repeated receiver runs.

#### - [x] ROUTE-P03-AC5 — Prove asymmetric deletion boundaries

A stale marked local-work blocker is deleted while the non-local hub source remains protected.

#### - [x] ROUTE-P03-V1 — Pass focused topology tests

Run `RoutingSpecificationTests`.

### - [x] ROUTE-P04 — Prove independently computed window overlap

**Requirements:** `ROUTE-AC-06` and `ROUTE-AC-09`.

#### - [x] ROUTE-P04-AC1 — Route events inside both windows

An interval positively overlapping both independently calculated windows reaches the receiver.

#### - [x] ROUTE-P04-AC2 — Exclude publisher-only horizon coverage from the receiver

An event published inside only the publisher's longer horizon remains outside the receiver's plan.

#### - [x] ROUTE-P04-AC3 — Do not publish outside the publisher window

An event inside only the receiver's theoretical horizon never reaches the hub.

#### - [x] ROUTE-P04-AC4 — Preserve exact positive-overlap semantics

Exact boundary touches are excluded while positive-duration overlaps are included.

#### - [x] ROUTE-P04-V1 — Pass routing and window suites

Run `RoutingSpecificationTests` and `OrdinaryReconciliationWindowTests`.

### - [x] ROUTE-P05 — Prove eventual-convergence marker migration

**Requirements:** `ROUTE-03` and `ROUTE-AC-05`.

#### - [x] ROUTE-P05-AC1 — Prove initial local cleanup

Cleanup removes exact retired-marker occurrences from the cleaner's visible topology without ordinary creates.

#### - [x] ROUTE-P05-AC2 — Prove stale republishing remains possible

A not-yet-migrated writer can recreate the retired marker after cleanup.

#### - [x] ROUTE-P05-AC3 — Prove repeated cleanup converges locally

A later cleanup removes the recreated local match.

#### - [x] ROUTE-P05-AC4 — Prove cleanup output does not overstate retirement

Cleanup output remains local, bounded, and point-in-time without global or historical claims.

#### - [x] ROUTE-P05-V1 — Pass routing and cleanup suites

Run `RoutingSpecificationTests`, `CalendarCleanupAccessTests`, and `ReconcileCommandHandlerTests`.

### - [x] ROUTE-P06 — Apply only necessary production corrections and review policy identity

This task is `Not applicable` when the acceptance suite passes without production changes.

**Disposition:** Not applicable. The focused suite passed against unchanged production code. Ordinary executable actions, exact targets, and ordering did not change, so `CalendarReconciliationPolicyVersion` remains unchanged.

#### - [x] ROUTE-P06-AC1 — Make only evidence-driven corrections

Each production edit is tied to a failing routing acceptance case.

#### - [x] ROUTE-P06-AC2 — Preserve prohibited-feature boundaries

No correction introduces excluded coordination, identity, expiry, or migration machinery.

#### - [x] ROUTE-P06-AC3 — Review reconciliation-policy version impact

Increment the policy version only if identical inputs can produce changed ordinary executable actions, exact targets, or order.

#### - [x] ROUTE-P06-V1 — Pass source-impact suites

Run the routing suite and, when policy semantics change, the configuration identity, standing authorization, and automatic reconciliation suites.

### - [x] ROUTE-P07 — Complete topology lifecycle and manual-validation guidance

**Requirements:** `ROUTE-AC-08`, the documentation portion of `ROUTE-AC-09`, and `ROUTE-AC-11` through `ROUTE-AC-13`.

#### - [x] ROUTE-P07-AC1 — Cover active-topology invariants

Require globally unique active markers, disjoint work sets, and one writer per physical work calendar.

#### - [x] ROUTE-P07-AC2 — Cover independent-window limitations

Add a representative different-horizon or time-zone check without a topology-wide promise.

#### - [x] ROUTE-P07-AC3 — Cover ownership transfer

Document stop-and-update-before-start, same-marker continuation, and retirement after a marker change.

#### - [x] ROUTE-P07-AC4 — Cover removal and hub replacement

Document manual removed-calendar cleanup, coordinated hub replacement, former-hub cleanup, and staggered partitioning.

#### - [x] ROUTE-P07-AC5 — Cover dormant writers and marker reuse

Require current topology before reconnecting and global artifact, recurrence, and stale-writer checks before reuse.

#### - [x] ROUTE-P07-AC6 — Cover stale-publisher cleanup repetition

Extend the harmless migration procedure with recreation and repeated cleanup.

#### - [x] ROUTE-P07-V1 — Validate documentation hygiene

Run `git --no-pager diff HEAD --check` and verify referenced commands and paths.

### - [x] ROUTE-P08 — Complete traceability and repository validation

#### - [x] ROUTE-P08-AC1 — Map every routing acceptance check

Record evidence for `ROUTE-AC-01` through `ROUTE-AC-13`.

#### - [x] ROUTE-P08-AC2 — Preserve custom-runner conventions

The suite has `runAll()` and exact-name filtering.

#### - [x] ROUTE-P08-AC3 — Preserve workspace changes

The pre-existing staged deletions remain untouched and no unrelated cleanup is included.

#### - [x] ROUTE-P08-V1 — Pass formatting validation

Run `make format-check`.

#### - [x] ROUTE-P08-V2 — Pass the complete repository gate

Run `make check`.

#### - [x] ROUTE-P08-V3 — Pass final diff hygiene

Run `git --no-pager diff HEAD --check`.

#### - [x] ROUTE-P08-V4 — Run conditional app checks when applicable

Run `make app` or `make ui-test` only if their documented source boundaries change.

**Disposition:** Not applicable. No app source, `Resources/CalRelayApp/`, app-bundle script, accessibility contract, fake UI composition, or UI-test harness changed.

#### - [x] ROUTE-P08-V5 — Record live-validation status honestly

Record whether authorized harmless multi-machine/EventKit validation was run or remains unperformed.

**Status:** Not performed. Automated evidence is deterministic and fake-backed. Real EventKit mutation and physical multi-machine/provider convergence remain explicit operator checks in [`../manual-validation.md`](../manual-validation.md).

## Acceptance coverage

| Acceptance check | Completion evidence |
| --- | --- |
| `ROUTE-AC-01` | `testRelayDirectionUsesExactMarkersAndMarkedHubAuthority()` proves exact local-origin exclusion and unchanged routing despite response or availability. |
| `ROUTE-AC-02` | `testRelayDirectionUsesExactMarkersAndMarkedHubAuthority()` and `testExternalMarkedHubEventRemainsAuthoritativeAndWorkDeletionStaysLocal()` prove non-local marked routing, cancelled exclusion, and hub preservation. |
| `ROUTE-AC-03` | `testRelayDirectionUsesExactMarkersAndMarkedHubAuthority()` proves personal-marker projection of an eligible unmarked hub event. |
| `ROUTE-AC-04` | `testRelayDirectionUsesExactMarkersAndMarkedHubAuthority()` proves exact `[A]` versus `[ACME]` marker equality. |
| `ROUTE-AC-05` | `testRetiredMarkerCanBeRepublishedAndRemovedByRepeatedCleanup()` proves initial cleanup, stale republishing, repeated cleanup, and bounded success wording. |
| `ROUTE-AC-06` | `testTwoMachinesConvergeThroughSharedHubWithoutRemoteMarkerRegistry()` and `testIndependentWindowsLimitCrossMachineCoverageToTheirOverlap()` prove Work A → hub → Work B protection within both windows. |
| `ROUTE-AC-07` | `testStaleLocalHubProjectionIsExcludedFromLogicalHub()` proves same-cycle deletion and exclusion from routing. |
| `ROUTE-AC-08` | [`../manual-validation.md`](../manual-validation.md), **Multi-computer topology check**, steps 1–3 and **Marker migration cleanup check**, step 1. |
| `ROUTE-AC-09` | `testIndependentWindowsLimitCrossMachineCoverageToTheirOverlap()` plus **Multi-computer topology check**, step 4. |
| `ROUTE-AC-10` | `testTwoMachinesConvergeThroughSharedHubWithoutRemoteMarkerRegistry()` and `testExternalMarkedHubEventRemainsAuthoritativeAndWorkDeletionStaysLocal()` plus **Multi-computer topology check**, step 5. |
| `ROUTE-AC-11` | [`../manual-validation.md`](../manual-validation.md), **Multi-computer topology check**, step 6. |
| `ROUTE-AC-12` | [`../manual-validation.md`](../manual-validation.md), **Multi-computer topology check**, steps 7–8. |
| `ROUTE-AC-13` | [`../manual-validation.md`](../manual-validation.md), **Multi-computer topology check**, step 9 and **Marker migration cleanup check**, steps 8–13. |

## Validation record

- Red checkpoint: `swift run CalRelayKitTests RoutingSpecificationTests` failed with the intentional `RoutingSpecificationTests not implemented` placeholder.
- Focused green checkpoint: `swift run CalRelayKitTests RoutingSpecificationTests` passed against unchanged production code.
- Related regression suites: `swift run CalRelayKitTests RoutingSpecificationTests CalendarCleanupAccessTests ReconcileCommandHandlerTests OrdinaryReconciliationWindowTests CalRelayContractTests` passed.
- Formatting: `make format-check` passed. The repository emits existing formatter warnings outside the task files; direct formatter lint of both touched Swift files passed with no warnings after task-local formatting.
- Complete gate: `make check` passed with exit code 0, including strict SwiftLint, SwiftPM build, the complete custom test runner, and CLI help smoke checks.
- Conditional app and UI checks: not applicable because their documented source boundaries did not change.
- Live EventKit and physical multi-machine validation: not performed; the operator procedures are documented for harmless dedicated calendars.
- Final diff hygiene: `git --no-pager diff HEAD --check` passed.
- Workspace preservation: the pre-existing staged deletions of `docs/plans/cli-implementation-plan.md` and `docs/plans/configuration-spec-test-plan.md` remained staged and untouched.

## Risks and mitigations

- **Duplicated policy in tests:** Keep the fake at port mechanics and drive public use cases.
- **Overstated topology guarantees:** Test sequential eventual convergence only; do not claim atomic snapshots or locking.
- **Authorization identity drift:** Review the policy version whenever ordinary executable semantics change.
- **Unsafe cleanup validation:** Keep automation fake-backed and use dedicated calendars only for explicitly authorized manual checks.
- **Documentation duplication:** Keep contracts in the owning specifications and operational steps in project references.

## Completion result

Revision-4 routing compliance is covered by deterministic acceptance tests and topology lifecycle guidance. No production routing implementation or reconciliation-policy version change was necessary. Remaining real-provider validation is intentionally manual and must use harmless dedicated calendars.