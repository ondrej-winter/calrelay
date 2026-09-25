# Routing implementation plan

## Plan record

- **Status:** Complete. Current HEAD complies with routing specification revision
  4 under the automated and documentation evidence recorded below; no production
  correction was necessary.
- **Prepared:** September 25, 2026.
- **Canonical requirements:**
  [`../specs/routing-spec.md`](../specs/routing-spec.md), revision 4,
  accepted September 17, 2026.
- **Related accepted contracts:**
  [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md),
  [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md),
  [`../specs/configuration-spec.md`](../specs/configuration-spec.md), and
  [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md).
- **Scope:** Verification-first implementation work required to demonstrate
  current compliance with hub/work routing, multi-computer topology, migration
  convergence, and topology lifecycle requirements.
- **Current state:** Current HEAD already contains a registered focused routing
  suite and extensive accepted behavior. Commit `94352fd` corrected
  personal-marker hub authority on September 24, 2026; commits `a88ab0d` and
  `acf0466` subsequently changed calendar capture and reconciliation-plan
  mechanics without changing the accepted routing contract.
- **Readiness:** Complete. No product decision, external dependency, unresolved
  failure, or follow-up implementation task remains.

## Outcome

Demonstrate that current HEAD satisfies `ROUTE-01` through `ROUTE-04` and
`ROUTE-AC-01` through `ROUTE-AC-13`.

Use a verification-first approach: establish current acceptance evidence before
changing production code, add or strengthen a deterministic failing test for any
real gap, make only the smallest correction that restores the accepted contract,
and keep operator-managed topology lifecycle requirements in project
documentation rather than adding runtime coordination.

If all current behavior and guidance pass, the correct result is a verified
compliance record with no speculative production rewrite.

## Scope boundaries

### In scope

- Current-HEAD acceptance traceability for all routing requirements.
- Deterministic routing, reconciliation, window-overlap, and cleanup-convergence
  tests.
- Personal-marker hub authority and stale-local logical-hub exclusion.
- Shared-hub convergence with machine-local work-calendar visibility.
- Operator guidance for marker uniqueness, writer ownership, lifecycle changes,
  retirement, and reuse.
- Reconciliation-policy version review if a correction changes ordinary
  executable actions, exact targets, or order.
- Focused and complete repository validation.

### Out of scope

- A global marker registry or remote-marker configuration.
- Marker authentication, leases, age limits, inferred remote staleness, or
  persistent ownership metadata.
- Leader election or cross-machine enforcement of the one-writer invariant.
- Automatic work-calendar removal cleanup or automatic hub migration.
- Unbounded recurring-event discovery or whole-series deletion.
- A same-host CLI/app cross-process lock.
- Mobile, team, or multi-user features.
- Live EventKit mutation as an automated completion gate.
- Unrelated cleanup or architectural restructuring.

## Architecture and change policy

- Keep projection and marker-routing rules deterministic in the CalendarRelay
  domain layer.
- Keep logical-hub construction and reconciliation orchestration in the
  application layer.
- Keep cleanup and command-result wording in inbound adapters.
- Keep EventKit mechanics and framework types outside domain and application APIs.
- Test through public projectors and application use cases. Shared test stores
  may model visibility, overlap-filtered reads, creates, and deletes, but must not
  reproduce routing policy.
- Do not change production code without a failing acceptance-level test.
- Increment `CalendarReconciliationPolicyVersion.current` if and only if
  identical validated settings and snapshots can produce different executable
  actions, exact targets, or order.

## Execution sequence

1. `ROUTE-P01` — establish the current acceptance baseline.
2. `ROUTE-P02` — verify relay direction and exact marker semantics.
3. `ROUTE-P03` — verify shared-hub convergence and authority boundaries.
4. `ROUTE-P04` — verify independently computed window overlap.
5. `ROUTE-P05` — verify migration convergence and cleanup truthfulness.
6. `ROUTE-P06` — make conditional corrections and review policy identity.
7. `ROUTE-P07` — verify operator topology and lifecycle guidance.
8. `ROUTE-P08` — run integrated and final validation.

After `ROUTE-P01`, `ROUTE-P02` through `ROUTE-P05` are logically independent.
Edits to the shared routing suite must be serialized. `ROUTE-P07` may proceed in
parallel because its expected write boundary is documentation only.

## ROUTE-P01 — Establish the current routing acceptance baseline

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/RoutingSpecificationTests.swift`
- `Tests/CalRelayKitTests/Main.swift`
- `docs/specs/routing-spec.md`

- [x] **ROUTE-P01:** Current routing acceptance coverage is baselined.
- [x] **ROUTE-P01-AC1:** Every routing outcome and acceptance check has direct
  evidence or a named verification task below.
- [x] **ROUTE-P01-AC2:** Commits `94352fd`, `a88ab0d`, and `acf0466` are included
  in the current-state assessment.
- [x] **ROUTE-P01-AC3:** No production code was changed before the focused
  acceptance baseline.
- [x] **ROUTE-P01-V1:**
  `swift run CalRelayKitTests RoutingSpecificationTests` passes.

**Passing evidence (September 25, 2026):** The workspace was clean before this
plan was added. The exact registered suite completed with `CalRelayKitTests
passed`. Source inspection confirmed that hub deletion ownership uses only
current work markers, work-calendar marker management accepts every valid marker,
and work expectations are derived after stale local hub projections are removed.
SwiftPM emitted non-fatal linker search-path warnings for absent Command Line
Tools paths.

## ROUTE-P02 — Verify relay direction and exact marker behavior

**Dependencies:** `ROUTE-P01`.

**Requirements:** `ROUTE-01`, `ROUTE-AC-01` through `ROUTE-AC-04`,
`ROUTE-AC-07`, and the marked-hub authority portion of `ROUTE-AC-10`.

**Primary test targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/RoutingSpecificationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalRelayContractTests.swift`

**Conditional production targets:**

- `Sources/CalRelayKit/Features/CalendarRelay/Domain/Projections/CalendarProjection.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ManagedEventTitlePolicy.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Domain/Planning/ReconciliationPlan.swift`

- [x] **ROUTE-P02:** Relay direction and exact marker behavior are directly
  verified.
- [x] **ROUTE-P02-AC1:** A local work marker routes unchanged to every other work
  calendar and skips only its exact origin.
- [x] **ROUTE-P02-AC2:** Marked-hub routing bypasses attendee-response and
  availability eligibility.
- [x] **ROUTE-P02-AC3:** A non-local valid marker routes unchanged to every
  configured work calendar without registration.
- [x] **ROUTE-P02-AC4:** A cancelled valid marked hub event remains preserved but
  produces no blocker projections.
- [x] **ROUTE-P02-AC5:** An eligible unmarked hub event receives the personal
  marker in every work projection.
- [x] **ROUTE-P02-AC6:** A hub event already carrying the configured personal
  marker remains authoritative rather than local deletion-owned output.
- [x] **ROUTE-P02-AC7:** `[A]` and `[ACME]` demonstrate exact parsed-marker
  equality rather than raw-prefix matching.
- [x] **ROUTE-P02-AC8:** A stale locally owned hub projection is removed from the
  logical hub before work expectations are derived.
- [x] **ROUTE-P02-V1:** `RoutingSpecificationTests` and `CalRelayContractTests`
  pass.

**Passing evidence (September 25, 2026):** The focused suite union passed with
the existing exact-marker, cancellation, personal-marker authority, and
same-cycle stale logical-hub scenarios. No production correction was required.

## ROUTE-P03 — Verify shared-hub convergence and authority boundaries

**Dependencies:** `ROUTE-P01`.

**Requirements:** `ROUTE-02`, `ROUTE-AC-02`, `ROUTE-AC-06`, and
`ROUTE-AC-10`.

- [x] **ROUTE-P03:** Shared-hub multi-machine behavior is directly verified.
- [x] **ROUTE-P03-AC1:** An eligible Work A source reaches the hub and Work B
  without feeding back to Work A.
- [x] **ROUTE-P03-AC2:** Machine B routes marker `[A]` without configuring it or
  maintaining a remote-marker registry.
- [x] **ROUTE-P03-AC3:** Fresh runs converge to empty plans after confirmed
  mutations become visible.
- [x] **ROUTE-P03-AC4:** A manually or externally created valid marked hub event
  remains authoritative and preserved over repeated receiver runs.
- [x] **ROUTE-P03-AC5:** A receiver may delete a stale marked blocker from its
  configured work calendar without gaining deletion authority over the non-local
  hub source.
- [x] **ROUTE-P03-V1:** `RoutingSpecificationTests` passes.

**Passing evidence (September 25, 2026):** The shared-state routing scenarios
passed through the public reconciliation use case with machine-local calendar
visibility, no remote-marker registry, and stable fresh-run convergence.

## ROUTE-P04 — Verify independent reconciliation-window overlap

**Dependencies:** `ROUTE-P01`.

**Requirements:** `ROUTE-AC-06` and `ROUTE-AC-09`.

- [x] **ROUTE-P04:** Cross-machine coverage is limited to the overlap of
  independently computed windows.
- [x] **ROUTE-P04-AC1:** An interval positively overlapping both machine windows
  is published and routed to the receiver.
- [x] **ROUTE-P04-AC2:** An interval inside only the publisher's window does not
  establish receiver protection.
- [x] **ROUTE-P04-AC3:** An interval inside only the receiver's window is not
  protected when the publisher never exposes it to the hub.
- [x] **ROUTE-P04-AC4:** Exact-touch boundaries remain excluded and full
  overlapping intervals remain unclipped.
- [x] **ROUTE-P04-V1:** `RoutingSpecificationTests` and
  `OrdinaryReconciliationWindowTests` pass.

**Passing evidence (September 25, 2026):** Different forward horizons and UTC,
America/Los_Angeles, and Asia/Tokyo calendars passed the inside-both,
publisher-only, receiver-only, and exact-touch scenarios.

## ROUTE-P05 — Verify marker-retirement convergence and cleanup claims

**Dependencies:** `ROUTE-P01`.

**Requirements:** `ROUTE-03` and `ROUTE-AC-05`.

**Primary test targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/RoutingSpecificationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarCleanupAccessTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupReviewTests.swift`

- [x] **ROUTE-P05:** Eventual-convergence migration behavior and output scope are
  verified.
- [x] **ROUTE-P05-AC1:** Initial cleanup deletes exact retired-marker matches only
  from the locally configured topology.
- [x] **ROUTE-P05-AC2:** A not-yet-migrated writer can recreate a retired marker
  after another machine's cleanup.
- [x] **ROUTE-P05-AC3:** Repeated cleanup removes the recreated locally visible
  artifact.
- [x] **ROUTE-P05-AC4:** Cleanup performs no routing, ordinary creates, or
  current-marker reconciliation.
- [x] **ROUTE-P05-AC5:** CLI and app success wording remains local and
  point-in-time and makes no global, historical, recurring-series, or future
  retirement claim.
- [x] **ROUTE-P05-V1:** Routing, cleanup-access, CLI cleanup, and app cleanup
  review suites pass.

**Passing evidence (September 25, 2026):** The initial-cleanup, stale-republisher,
and repeated-cleanup scenario passed. Cleanup access, CLI output, and app review
tests also passed and retained bounded local point-in-time claims without ordinary
creates or global-retirement wording.

## ROUTE-P06 — Apply only evidence-driven corrections and review policy identity

**Dependencies:** A failing or missing acceptance condition from `ROUTE-P02`
through `ROUTE-P05`. If none exists, record this task as not applicable with
baseline evidence.

- [x] **ROUTE-P06:** Not applicable — focused and adjacent acceptance evidence
  exposed no production defect.
- [x] **ROUTE-P06-AC1:** Not applicable — no behavior correction was required, so
  there was no new red/green production slice.
- [x] **ROUTE-P06-AC2:** Pure routing remains in domain code, reconciliation
  orchestration remains in application code, and presentation wording remains in
  adapters.
- [x] **ROUTE-P06-AC3:** No registry, authentication, lease, age limit, ownership
  metadata, automatic migration, or new coordination mechanism is introduced.
- [x] **ROUTE-P06-AC4:** Not applicable — executable ordinary behavior did not
  change, so `ordinary-reconciliation-policy-v2` remains current.
- [x] **ROUTE-P06-V1:** Not applicable — no correction was needed.
- [x] **ROUTE-P06-V2:** Not applicable — no policy version change was needed;
  `CalendarConfigurationIdentityTests` nevertheless passed in the focused union.

**Disposition (September 25, 2026):** No Swift source, test, policy identity,
adapter output, or configuration behavior required a change.

## ROUTE-P07 — Verify topology lifecycle and retirement documentation

**Dependencies:** `ROUTE-P01`. May proceed alongside `ROUTE-P02` through
`ROUTE-P05`.

**Target:** `docs/configuration.md`.

Do not recreate the removed `docs/manual-validation.md`. Keep product contracts
in accepted specifications and operator procedures in project references.

- [x] **ROUTE-P07:** Operator-facing routing and lifecycle guidance satisfies
  `ROUTE-AC-08` through `ROUTE-AC-13`.
- [x] **ROUTE-P07-AC1:** Documentation requires globally unique current and
  personal markers, disjoint active work-calendar sets, and exactly one active
  writer per physical work calendar.
- [x] **ROUTE-P07-AC2:** Documentation limits cross-machine coverage to the
  overlap of independent windows and keeps non-local marked hub events
  authoritative without leases or inferred staleness.
- [x] **ROUTE-P07-AC3:** Documentation covers CLI-versus-app writer choice,
  stop-and-update-before-start ownership transfer, same-marker continuity,
  removed-calendar manual cleanup, coordinated hub replacement, and staggered-hub
  partitioning.
- [x] **ROUTE-P07-AC4:** Documentation requires global retirement before
  tombstoning, dormant-writer updates, recurring-series removal, global artifact
  verification, and stale-republishing prevention before marker reuse.
- [x] **ROUTE-P07-V1:** Referenced commands and paths are valid and documentation
  changes, if any, pass `git --no-pager diff HEAD --check`.

**Passing evidence (September 25, 2026):** `docs/configuration.md` already
contains every required topology, transfer, removal, hub-replacement, dormant
writer, recurrence, and marker-reuse warning. Both cleanup command examples and
all referenced repository paths exist. No user-guidance correction was required,
and `git --no-pager diff HEAD --check` passed after adding this plan.

## ROUTE-P08 — Run integrated and final validation

**Dependencies:** All prior tasks have a completed, failed, not-applicable, or
explicitly blocked disposition.

Run the focused suite union:

```sh
swift run CalRelayKitTests \
  RoutingSpecificationTests \
  CalRelayContractTests \
  ReconciliationSpecificationTests \
  OrdinaryReconciliationWindowTests \
  CalendarCleanupAccessTests \
  ReconcileCommandHandlerTests \
  CalendarManualCleanupReviewTests \
  CalendarConfigurationSchemaTests \
  CalendarConfigurationIdentityTests
```

Then run:

```sh
make format-check
make check
git --no-pager diff HEAD --check
git --no-pager status --short
```

Run `make app` if app sources, app resources, or the app-bundle script changes.
Run `make ui-test` if app presentation, accessibility contracts, fake UI
composition, or UI-test infrastructure changes. Do not use real EventKit or
calendar mutation as an automated gate.

- [x] **ROUTE-P08:** Integrated routing verification and repository handoff are
  complete.
- [x] **ROUTE-P08-AC1:** Every routing acceptance check has final current-HEAD
  evidence or a clearly reported unresolved failure.
- [x] **ROUTE-P08-AC2:** Final diff inspection finds no unrelated architecture,
  configuration, UI, EventKit, or dependency changes.
- [x] **ROUTE-P08-AC3:** The handoff distinguishes automated evidence,
  conditional checks, and unperformed live validation.
- [x] **ROUTE-P08-V1:** The focused suite union passes.
- [x] **ROUTE-P08-V2:** `make format-check` passes.
- [x] **ROUTE-P08-V3:** `make check` passes.
- [x] **ROUTE-P08-V4:** `git --no-pager diff HEAD --check` passes.
- [x] **ROUTE-P08-V5:** `make app` and `make ui-test` are not applicable because
  no app source, app resource, app-bundle script, presentation contract,
  accessibility contract, fake UI composition, or UI-test infrastructure changed.
- [x] **ROUTE-P08-V6:** Final status and diff review confirm that unrelated work
  was preserved.

**Passing evidence (September 25, 2026):** The exact focused suite union passed.
`make format-check` and `make check` passed; the latter completed strict SwiftLint,
`swift build`, the complete custom `CalRelayKitTests` runner, and every configured
CLI help smoke check. `git --no-pager diff HEAD --check` passed. Existing
swift-format diagnostics and linker search-path warnings for absent Command Line
Tools locations were non-fatal. No live EventKit or calendar mutation was run.

## Acceptance traceability

| Requirement | Expected current evidence |
| --- | --- |
| `ROUTE-AC-01` | Exact local-marker exclusion in `testRelayDirectionUsesExactMarkersAndMarkedHubAuthority`. |
| `ROUTE-AC-02` | Non-local and cancelled marked handling in relay-direction and external-hub scenarios. |
| `ROUTE-AC-03` | Personal projection in `testRelayDirectionUsesExactMarkersAndMarkedHubAuthority`. |
| `ROUTE-AC-04` | `[A]` versus `[ACME]` exact-marker scenario. |
| `ROUTE-AC-05` | `testRetiredMarkerCanBeRepublishedAndRemovedByRepeatedCleanup` plus cleanup formatter tests. |
| `ROUTE-AC-06` | Shared-hub convergence and independent-window overlap scenarios. |
| `ROUTE-AC-07` | `testStaleLocalHubProjectionIsExcludedFromLogicalHub`. |
| `ROUTE-AC-08` | Multi-computer marker and writer guidance in `docs/configuration.md`. |
| `ROUTE-AC-09` | Independent-window test plus topology-window documentation. |
| `ROUTE-AC-10` | External and personal-marked hub-authority scenarios. |
| `ROUTE-AC-11` | Ownership-transfer guidance in `docs/configuration.md`. |
| `ROUTE-AC-12` | Removed-calendar and hub-replacement guidance in `docs/configuration.md`. |
| `ROUTE-AC-13` | Dormant-writer, recurring-series, artifact-removal, and marker-reuse guidance. |

## Risks and mitigations

- **Duplicated policy in tests:** Keep fake stores limited to port mechanics and
  invoke real projectors and use cases.
- **Non-local hub events accidentally gain deletion ownership:** Maintain the
  distinction between current local work markers and every other valid hub
  marker.
- **Window tests overstate topology guarantees:** Cover publisher-only,
  receiver-only, exact-touch, and inside-both cases.
- **Cleanup output implies global retirement:** Assert required local wording and
  prohibited global or historical claims.
- **Behavior changes leave standing authorization valid:** Review the policy
  version for every executable-action change.
- **Parallel edits conflict:** Serialize changes to `RoutingSpecificationTests`;
  allow documentation review to proceed independently.
- **Unnecessary architecture expansion:** Correct existing projectors, policies,
  planners, or use cases before introducing a new abstraction.

## Handoff

- **Next task:** None; this verification plan is complete.
- **Blocked work:** None.
- **Unresolved decisions:** None.
- **Repository changes:** This plan file only. Swift source, tests, configuration,
  operator guidance, app code, dependencies, and policy identity were unchanged.
- **Automated evidence:** Focused routing-related union, complete repository test
  runner, strict lint, format check, build, CLI help smoke checks, and diff
  hygiene all passed on September 25, 2026.
- **Conditional evidence:** App bundle and UI gates were not applicable because
  their change boundaries were untouched.
- **Manual evidence:** No live EventKit or calendar mutation was performed; it is
  neither required nor appropriate as an ordinary automated compliance gate.
- **Completion condition:** `ROUTE-P01` through `ROUTE-P08` and all required child
  checks have passing evidence or an explicit not-applicable disposition.