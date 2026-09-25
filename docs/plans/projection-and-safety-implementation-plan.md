# Projection and safety implementation plan

## Plan record

- **Status:** Ready; implementation has not started.
- **Prepared:** September 24, 2026.
- **Canonical requirements:**
  [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md),
  revision 6, accepted September 17, 2026.
- **Scope:** Verification-first implementation work required to bring ordinary
  reconciliation into full compliance with the accepted projection-and-safety
  contract.
- **Current state:** Existing implementation and deterministic tests cover the
  accepted projection shape, eligibility, marker grammar, overlap boundaries,
  recurrence treatment, managed-event ownership, cleanup ownership, and
  plan-before-mutation safety requirements. The confirmed remaining defect is
  that `ReconcileCalendarsUseCase` captures `Calendar.current` when the use case
  is constructed instead of capturing the current system calendar once at the
  start of each ordinary reconciliation run.
- **Readiness:** Ready. The defect, affected entry points, compatibility needs,
  test strategy, implementation sequence, and validation commands are known.
  There are no unresolved product decisions or blockers.

## Outcome

Make ordinary reconciliation capture the production Mac system calendar and
time zone once per run and reuse that exact captured value throughout the run,
as required by `PROJECT-02`, `PROJECT-AC-05`, and `PROJECT-AC-07`.

The implementation must retain deterministic fixed-calendar injection for tests,
sample production calendar state afresh on later runs of the same long-lived use
case, and preserve all existing projection, routing, ownership, cleanup, and
mutation-safety behavior.

## Scope boundaries

### In scope

- Sampling the production system `Calendar` once for each ordinary
  reconciliation computation.
- Reusing the captured value for the complete snapshot, effective window,
  projection generation, matching, planning, explanation, and resulting apply
  execution.
- Propagating provider semantics through long-lived ordinary-reconciliation
  wrappers so they do not freeze the system calendar at construction.
- Capturing one calendar value per CLI reconciliation command invocation.
- Retaining fixed-calendar construction paths for deterministic unit, contract,
  and UI-test fixtures.
- Adding deterministic regression coverage for per-run freshness, one read per
  run, and within-run consistency.
- Re-running the existing projection-and-safety acceptance evidence to guard
  against unrelated behavior changes.

### Out of scope

- Changes to event eligibility, projection fields, title normalization, marker
  parsing, routing, recurrence treatment, reconciliation planning, action order,
  or deletion ownership.
- Changes to cleanup selection, cleanup range, cleanup verification, or manual
  cleanup review semantics.
- Changes to control-panel status or configuration-check behavior; those
  readiness checks are not ordinary reconciliation runs.
- A configured reconciliation calendar or time zone, use of
  `Calendar.autoupdatingCurrent`, or any change to the fixed two-date lookback.
- Specification changes. The accepted specification already defines the intended
  behavior.
- User-documentation changes unless implementation reveals that current guidance
  is inaccurate.
- Live EventKit or real-calendar mutation as part of automated validation.
- Unrelated refactoring, package changes, dependency updates, or formatting
  churn.

## Change policy

1. Establish the current deterministic baseline before editing Swift sources.
2. Add a failing contract test that demonstrates the confirmed defect.
3. Make the smallest provider and constructor change that passes the new test.
4. Preserve fixed-calendar injection and existing call-site compatibility where
   practical.
5. Keep one run's calendar value concrete and immutable after capture; do not
   retain an automatically updating calendar as run context.
6. Keep cleanup and status behavior outside the change unless compilation or a
   failing accepted contract proves that a narrow compatibility edit is needed.
7. Validate focused suites first, then the complete repository gate.

## Accepted-contract coverage

| Requirement | Planned evidence |
| --- | --- |
| `PROJECT-AC-01` through `PROJECT-AC-04` | Existing `CalRelayContractTests` remain green. |
| `PROJECT-AC-05` | New run-scoped calendar-capture suite plus `OrdinaryReconciliationWindowTests`. |
| `PROJECT-AC-06` | Existing routing and exact-occurrence suites remain green. |
| `PROJECT-AC-07` | New dry-run, apply, and explanation one-capture contract. |
| `SAFE-AC-01` and `SAFE-AC-02` | Existing reconciliation and routing suites remain green. |
| `SAFE-AC-03` | Existing CLI and app cleanup suites remain green. |
| `SAFE-AC-04` | Existing manual apply and cleanup fresh-snapshot suites remain green. |
| `SAFE-AC-05` | Fixed-calendar convenience construction and offline deterministic tests remain available. |

## Expected file impact

### Core production source

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`

### Long-lived ordinary-reconciliation wrappers

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualDryRunUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualApplyUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarStandingAuthorizationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomaticReconciliationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandler.swift`

### Deterministic tests

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/OrdinaryReconciliationCalendarCaptureTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualDryRunTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualApplyTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarStandingAuthorizationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomaticReconciliationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/Main.swift`

### Composition expected to remain source-compatible

- `Sources/CalRelayApp/CalRelayApp.swift`
- `Sources/CalRelayApp/CalendarUITestComposition.swift`
- `Sources/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarCLIComposition.swift`

These composition files should require no edit when the provider-based
initializers retain a fixed `calendar:` convenience overload. If compilation
requires a composition edit, keep it to constructor wiring and include the
additional app validation required by repository policy.

## Execution order

Execute `CAL-01` through `CAL-06` in order. The red-test checkpoint in `CAL-02`
must precede the production correction in `CAL-03`. Wrapper propagation in
`CAL-04` depends on the finalized core constructor shape. Focused and complete
verification follow in `CAL-05` and `CAL-06`.

## CAL-01 — Establish the pre-change baseline

**Dependencies:** None.

Before editing, recheck Git status and run the existing projection-and-safety
evidence:

```sh
git status --short

swift run CalRelayKitTests \
  OrdinaryReconciliationWindowTests \
  CalRelayContractTests \
  RoutingSpecificationTests \
  CalendarCleanupAccessTests \
  CalendarManualApplyTests \
  CalendarManualCleanupTests \
  EventKitExactEventOccurrenceResolverTests \
  CalendarManualDryRunTests \
  CalendarStandingAuthorizationTests \
  CalendarAutomaticReconciliationTests \
  ReconcileCommandHandlerTests

make test
```

- [ ] **CAL-01:** The pre-change verification baseline is established.
- [ ] **CAL-01-AC1:** The targeted projection-and-safety suites pass before
  implementation, or each pre-existing failure is recorded and classified
  before source changes begin.
- [ ] **CAL-01-AC2:** The complete deterministic test runner passes before
  implementation, or unrelated pre-existing failures are recorded.
- [ ] **CAL-01-V1:** Git status is rechecked immediately before editing and all
  unrelated staged, unstaged, and untracked work is preserved.

## CAL-02 — Add deterministic failing calendar-capture contracts

**Dependencies:** `CAL-01`.

Create
`Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/OrdinaryReconciliationCalendarCaptureTests.swift`
and register its exact suite name in `Tests/CalRelayKitTests/Main.swift`.

Use a thread-safe synchronous `@Sendable` calendar provider and a recording fake
calendar store. Reuse one `ReconcileCalendarsUseCase` instance while changing the
provider's deterministic calendar between runs. Cover `dryRunResult`,
`applyResult`, and `explain` and verify that:

- the provider is invoked exactly once per valid reconciliation computation;
- every calendar-store event read in a run receives the window calculated from
  that run's captured calendar;
- explanation reports the same effective window used for input reads;
- apply executes the actions produced from that run without a later provider
  read; and
- a later run on the same reconciler observes the provider's changed calendar.

Extend existing wrapper and CLI suites with focused retained-instance checks:

- `CalendarManualDryRunTests`
- `CalendarManualApplyTests`
- `CalendarStandingAuthorizationTests`
- `CalendarAutomaticReconciliationTests`
- `ReconcileCommandHandlerTests`

For manual apply and standing authorization, repeated review operations are
sufficient to establish provider freshness; no real mutation is required. Tests
must remain fake-backed, deterministic, offline, and independent of the machine's
actual calendar and time zone.

- [ ] **CAL-02:** A red contract demonstrates construction-time calendar capture
  and guards every long-lived ordinary entry point.
- [ ] **CAL-02-AC1:** The core suite proves one provider read per run and a changed
  provider value across runs of the same reconciler.
- [ ] **CAL-02-AC2:** Dry-run, apply, and explanation each prove within-run window
  consistency.
- [ ] **CAL-02-AC3:** Manual dry-run, manual apply, standing authorization,
  automatic reconciliation, and CLI command handling have regression assertions
  that prevent wrapper-level construction-time capture.
- [ ] **CAL-02-AC4:** Existing fixed-calendar tests remain deterministic and do
  not read the live system calendar.
- [ ] **CAL-02-V1:**
  `swift run CalRelayKitTests OrdinaryReconciliationCalendarCaptureTests` fails
  for the expected missing or stale provider behavior before the production
  correction is completed.

## CAL-03 — Capture the calendar once at core run entry

**Dependencies:** `CAL-02`.

Modify
`Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`.

Replace the stored fixed calendar with a sendable provider:

```swift
private let calendarProvider: @Sendable () -> Calendar
```

Provide a production initializer whose provider defaults to `{ .current }` and a
fixed-calendar convenience initializer retaining the existing `calendar:` call
shape for deterministic tests. The fixed initializer should wrap its value in a
closure rather than changing test behavior.

At the shared computation boundary, invoke the provider exactly once and pass the
captured `Calendar` into run-context loading and effective-window calculation.
The resulting context must remain the sole basis for snapshot reads, projections,
matching, plans, ordered actions, and explanations. Apply must execute those
already-produced actions without another provider read.

Do not store or pass `Calendar.autoupdatingCurrent` as run context. The accepted
contract requires one concrete calendar and time-zone interpretation for the
entire run.

- [ ] **CAL-03:** The core reconciler uses one run-scoped calendar capture.
- [ ] **CAL-03-AC1:** `ReconcileCalendarsUseCase` no longer captures the production
  `Calendar.current` value during construction.
- [ ] **CAL-03-AC2:** Each valid `dryRunResult`, `applyResult`, `explain`, and
  `standingAuthorizationDryRun` computation samples the provider once through the
  shared path.
- [ ] **CAL-03-AC3:** Snapshot reads, planning, action ordering, explanation, and
  apply execution use the one captured run context.
- [ ] **CAL-03-AC4:** Existing `calendar: fixedCalendar` callers remain
  deterministic and source-compatible.
- [ ] **CAL-03-V1:**
  `swift run CalRelayKitTests OrdinaryReconciliationCalendarCaptureTests` passes.

## CAL-04 — Propagate provider semantics through wrappers and CLI

**Dependencies:** `CAL-03`.

Modify the four long-lived app use cases and the reconciliation CLI handler listed
under expected file impact.

For each app use case:

- accept a sendable provider defaulting to `{ .current }`;
- forward that provider directly into the retained reconciler;
- retain a fixed `calendar: Calendar` convenience construction path; and
- never invoke the provider in the wrapper initializer.

Review and confirmation are separate reconciliation computations and may capture
different calendars. Existing fresh-plan and executable-identity checks remain
responsible for requiring renewed review when a changed window changes planned
actions.

For `ReconcileCommandHandler`, store a provider, capture `now()` and the calendar
once near the beginning of `run`, and pass the captured fixed value through the
selected ordinary or cleanup branch. The same captured value must be used for
cleanup window formatting and cleanup execution. Retain the fixed `calendar:`
initializer used by deterministic CLI tests.

- [ ] **CAL-04:** Every retained ordinary-reconciliation entry point preserves
  per-run calendar capture.
- [ ] **CAL-04-AC1:** Manual dry-run, manual apply review, and standing-
  authorization review sample a fresh calendar for each operation.
- [ ] **CAL-04-AC2:** Automatic reconciliation samples a fresh calendar for each
  automatic attempt.
- [ ] **CAL-04-AC3:** CLI reconciliation samples the provider once per command
  invocation and reuses the value throughout the selected path.
- [ ] **CAL-04-AC4:** Existing fixed-calendar contract and UI-test composition
  remains deterministic.
- [ ] **CAL-04-AC5:** Cleanup ownership, selection, planning, and verification
  behavior is unchanged.
- [ ] **CAL-04-V1:** All focused wrapper and CLI provider-propagation regression
  tests pass.

## CAL-05 — Run focused projection-and-safety verification

**Dependencies:** `CAL-04`.

Run the new suite first:

```sh
swift run CalRelayKitTests OrdinaryReconciliationCalendarCaptureTests
```

Run all directly affected entry-point suites:

```sh
swift run CalRelayKitTests \
  CalendarManualDryRunTests \
  CalendarManualApplyTests \
  CalendarStandingAuthorizationTests \
  CalendarAutomaticReconciliationTests \
  ReconcileCommandHandlerTests
```

Run the broader accepted-spec contracts:

```sh
swift run CalRelayKitTests \
  OrdinaryReconciliationWindowTests \
  CalRelayContractTests \
  RoutingSpecificationTests \
  CalendarCleanupAccessTests \
  CalendarManualCleanupTests \
  EventKitExactEventOccurrenceResolverTests
```

- [ ] **CAL-05:** Focused and adjacent acceptance evidence passes after the
  correction.
- [ ] **CAL-05-AC1:** `PROJECT-AC-05` is demonstrated for injected reference
  instants, calendars, time zones, and window boundaries.
- [ ] **CAL-05-AC2:** `PROJECT-AC-07` is demonstrated for dry-run, apply, and
  explanation using one captured effective window.
- [ ] **CAL-05-AC3:** Existing projection, marker, recurrence, routing, cleanup,
  ownership, and plan-time deletion-authority contracts remain green.
- [ ] **CAL-05-V1:** All three focused validation groups complete successfully
  without live EventKit access.

## CAL-06 — Resolve documentation disposition and run final gates

**Dependencies:** `CAL-05`.

The expected documentation disposition is no change:

- `docs/specs/projection-and-safety-spec.md` already defines run-scoped capture;
  and
- `docs/configuration.md` already tells users that ordinary-run start captures
  the Mac's current system calendar and time zone.

Only update those documents if implementation reveals a genuine contract or
guidance mismatch.

Run the required repository gates:

```sh
make format-check
make check
git --no-pager diff HEAD --check
git status --short
```

Inspect the complete diff and confirm that it contains only the calendar-provider
correction, compatibility wiring, and deterministic tests. `make app` is not
expected when app sources remain unchanged. If constructor fallout requires an
edit under `Sources/CalRelayApp/`, run `make app` before handoff.

- [ ] **CAL-06:** Final repository validation and handoff are complete.
- [ ] **CAL-06-AC1:** The accepted specification and user documentation accurately
  describe the resulting behavior without an unnecessary contract change.
- [ ] **CAL-06-AC2:** Final diff inspection finds no unrelated projection,
  cleanup, routing, ownership, or architecture changes.
- [ ] **CAL-06-V1:** `make format-check` passes.
- [ ] **CAL-06-V2:** `make check` passes.
- [ ] **CAL-06-V3:** `git --no-pager diff HEAD --check` passes.
- [ ] **CAL-06-V4:** `make app` passes if and only if app sources required an
  implementation edit; otherwise record it as not applicable with the reason.
- [ ] **CAL-06-V5:** The final handoff reports every command actually run and any
  skipped, blocked, or unrelated failing check without claiming unrun evidence.

## Risks and mitigations

- **Risk:** A provider is forwarded but invoked by a long-lived wrapper during
  construction. **Mitigation:** Retained-instance wrapper tests change the
  provider after construction and before later operations.
- **Risk:** The provider is read more than once during one computation, allowing
  a mixed effective window. **Mitigation:** The core contract records exact read
  count and all event-read boundaries for dry-run, apply, and explanation.
- **Risk:** Existing tests silently begin reading the developer's live system
  calendar. **Mitigation:** Keep explicit fixed-calendar overloads and preserve
  existing fixture call shapes.
- **Risk:** Manual review and confirmation use different windows. **Mitigation:**
  Treat them as distinct fresh computations and retain exact executable-action
  identity comparison before mutation.
- **Risk:** Constructor changes cause unnecessary app or CLI composition churn.
  **Mitigation:** Preserve default and fixed-value call shapes; edit composition
  only if compilation demonstrates a need.

## Handoff

- **Next task:** `CAL-01`.
- **Blocked work:** None.
- **Unresolved decisions:** None.
- **Completion condition:** `CAL-01` through `CAL-06` and all required child
  acceptance and verification checks have recorded passing evidence or an
  explicit approved not-applicable disposition.