# Personal-prefix hub authority routing fix plan

## Plan record

- **Prepared:** September 24, 2026.
- **Status:** Complete; `PHR-01` through `PHR-05` have implementation and
  validation evidence.
- **Readiness:** Complete. The accepted specifications settled the required
  behavior, and no unresolved product or implementation decision remains.
- **Goal:** Ensure a valid hub event carrying the configured personal prefix
  remains an authoritative non-local blocker instead of being classified as a
  locally owned projection and deleted.
- **Canonical requirements:**
  - `docs/specs/routing-spec.md`, revision 4.
  - `docs/specs/projection-and-safety-spec.md`, revision 6.
  - `docs/specs/reconciliation-spec.md`, revision 6.
  - `docs/specs/macos-app-spec.md`, revision 6.

## Problem statement

Ordinary reconciliation previously used a shared concept of managed prefixes
for two different responsibilities:

1. deciding which marked hub events are locally owned projections eligible for
   deletion; and
2. recognizing marked events on work calendars as managed relay artifacts.

Including the configured personal prefix in hub deletion ownership incorrectly
classified a hub event such as `[PERSONAL] Dentist` as locally owned.
Reconciliation could therefore delete it rather than preserve and route it as
an authoritative non-local marked hub source.

The accepted specifications require:

- every non-cancelled valid marked hub event to bypass ordinary attendee and
  availability eligibility;
- only current locally configured work markers to imply local hub ownership;
- a valid marked hub event without a current local work marker to route
  unchanged to every configured work calendar;
- non-local marked hub events to be preserved indefinitely while present;
- stale valid marked work-calendar events to remain managed and eligible for
  deletion; and
- standing authorization to be invalidated whenever reconciliation-policy
  behavior changes executable actions.

## Scope

### In scope

- Add a deterministic routing regression for a personal-prefix hub event.
- Separate hub projection ownership from work-calendar marker management.
- Preserve and route personal-prefix hub events as non-local authoritative
  blockers.
- Retain stale current-work-marker hub cleanup.
- Retain feedback suppression and stale deletion for every valid marked
  work-calendar event.
- Correct ordinary explanation classification.
- Advance the reconciliation-policy version.
- Prove that persisted authorization derived under the prior policy fails
  closed.
- Run focused and repository-wide validation.
- Review the final diff and preserve unrelated existing work.

### Out of scope

- Changing any accepted product specification.
- Adding a marker registry, marker authentication, ownership metadata, or
  leases.
- Treating the personal prefix as an origin marker for hub-to-work exclusion.
- Changing marker parsing or equality.
- Changing cleanup-only legacy-marker behavior.
- Changing standing-authorization storage serialization.
- Migrating old standing authorization to the new policy.
- Modifying app UI, EventKit adapters, configuration syntax, or user
  documentation.
- Performing live EventKit mutation or manual calendar validation.
- Unrelated cleanup or refactoring.

## Contract traceability

| Contract | Planned evidence |
| --- | --- |
| `ROUTE-01` | A personal-prefix hub event routes unchanged to every configured work calendar and bypasses attendee/availability eligibility. |
| `ROUTE-02` | The personal prefix is not mistaken for a current locally configured work marker. |
| `ROUTE-AC-07` | A stale locally owned current-work-marker hub projection is deleted and excluded from same-run work routing. |
| `ROUTE-AC-10` | A non-local valid marked hub event remains authoritative and is preserved. |
| `PROJECT-01` | Non-cancelled valid marked hub events bypass ordinary eligibility. |
| `SAFE-AC-01` | Hub deletion ownership is limited to current local work markers. |
| `SAFE-AC-02` | Valid marked work events remain managed and potentially deletable. |
| `RECON-01` | Work expectations are generated from the reconciled logical hub state. |
| `RECON-02` | Applying the plan and loading the resulting visible state produces an empty second plan. |
| `APP-AC-04` and `APP-AC-15` | Reconciliation-policy v1 authorization is invalidated before automatic mutation. |

## Change policy

1. Establish the defect with a failing regression before changing production
   behavior.
2. Make the smallest implementation change that restores the accepted
   contract.
3. Keep marker parsing and projection behavior unchanged.
4. Do not broaden deletion ownership.
5. Keep all changes within the CalendarRelay application slice.
6. Add authorization-invalidation coverage before advancing the policy
   version.
7. Do not manipulate Git staging or overwrite unrelated workspace changes.

## Tasks

### [x] PHR-01 — Establish the routing regression

**Dependencies:** None.

Add a deterministic routing contract scenario with a hub event such as:

```text
[PERSONAL] Dentist
```

Give the event an ordinarily ineligible combination such as free availability
and a declined current-user attendee status to prove that valid marked hub
authority bypasses normal eligibility.

**File:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/RoutingSpecificationTests.swift`

#### Acceptance and verification

- [x] **PHR-01-AC1:** The event is not included in hub deletions.
- [x] **PHR-01-AC2:** A projection is created in every configured work
  calendar.
- [x] **PHR-01-AC3:** No work calendar is excluded as an inferred origin.
- [x] **PHR-01-AC4:** Every projection retains the original marked title
  unchanged.
- [x] **PHR-01-AC5:** Applying the plan preserves the original hub event.
- [x] **PHR-01-AC6:** A second run against the resulting snapshot has no
  creates or deletes.
- [x] **PHR-01-V1:** The regression was observed failing before the production
  correction.
- [x] **PHR-01-V2:** `RoutingSpecificationTests` passes after the correction.

### [x] PHR-02 — Separate hub ownership from work marker management

**Dependencies:** `PHR-01`.

Introduce an explicit set containing only current work-calendar prefixes for
ordinary hub ownership.

Use separate policy operations for:

- determining whether a hub event is a locally managed projection; and
- determining whether a work-calendar event has a valid relay marker.

**Files:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarRelayRunContext.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ManagedEventTitlePolicy.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalRelayContractTests.swift`

**Required behavior:**

- Hub reconciliation receives only current configured work prefixes as managed
  deletion prefixes.
- A valid marker on a hub event implies local ownership only when it exactly
  equals a current local work prefix.
- The configured personal prefix does not grant hub deletion authority.
- Any valid marked work-calendar event remains feedback-suppressed and managed
  for stale deletion.
- A stale current-work-marker hub projection remains deletable.
- A stale locally owned hub projection is removed before deriving work-calendar
  expectations and therefore does not route for an extra cycle.

#### Acceptance and verification

- [x] **PHR-02-AC1:** `[PERSONAL]` is preserved when it is not a current work
  marker.
- [x] **PHR-02-AC2:** `[ACME]` remains locally owned when `[ACME]` is a current
  work marker.
- [x] **PHR-02-AC3:** Stale `[ACME]` hub projections are deleted.
- [x] **PHR-02-AC4:** Deleted stale local hub projections do not produce
  same-run work projections.
- [x] **PHR-02-AC5:** Valid marked work events retain their existing feedback
  suppression and deletion behavior.
- [x] **PHR-02-AC6:** No persistent metadata, registry, or additional
  dependency is introduced.

### [x] PHR-03 — Correct ordinary explanation classification

**Dependencies:** `PHR-02`.

Ensure explanation uses the same ownership distinction as executable
reconciliation.

**Files:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalRelayContractTests.swift`

**Required classification for a personal-prefix hub event:**

```text
eligibility = markedHubEligibilityBypass
routing = nonLocalValidMarkerHubSource
disposition = preservedUnmanagedOrNonLocal
```

#### Acceptance and verification

- [x] **PHR-03-AC1:** The event is not described as a local work-marker
  source.
- [x] **PHR-03-AC2:** The event is not described as retained local managed
  state.
- [x] **PHR-03-AC3:** Existing local-marker, duplicate, cancellation,
  invalid-marker, and work-calendar classifications remain covered.
- [x] **PHR-03-V1:** `CalRelayContractTests` passes.

### [x] PHR-04 — Advance reconciliation policy and invalidate legacy authorization

**Dependencies:** `PHR-02`.

Because the correction changes executable ordinary actions for an identical
validated configuration and snapshot, advance the policy version from:

```text
ordinary-reconciliation-policy-v1
```

to:

```text
ordinary-reconciliation-policy-v2
```

**Files:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarStandingAuthorizationBinding.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarConfigurationIdentityTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomationPersistenceTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarStandingAuthorizationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomaticReconciliationTests.swift`

**Compatibility rule:**

Persisted authorization serialization remains `v1:<digest>`. That prefix is
the storage-envelope version, not the reconciliation-policy version. Policy v2
changes the digest input, so a grant created under policy v1 no longer matches.
No authorization migration is permitted because a changed mutation policy
requires renewed review.

#### Acceptance and verification

- [x] **PHR-04-AC1:** The current policy value is explicitly asserted as
  `ordinary-reconciliation-policy-v2`.
- [x] **PHR-04-AC2:** Identical settings and topology produce different
  bindings under policy v1 and policy v2.
- [x] **PHR-04-AC3:** Presentation-only work-calendar name changes remain
  authorization-equivalent.
- [x] **PHR-04-AC4:** Persisted policy-v1 authorization validates as
  invalidated.
- [x] **PHR-04-AC5:** Returning to an earlier identity does not silently
  reactivate an invalidated grant.
- [x] **PHR-04-AC6:** Automatic reconciliation with a policy-v1 grant reports
  that standing authorization is required.
- [x] **PHR-04-AC7:** Automatic reconciliation performs zero calendar
  mutations.
- [x] **PHR-04-AC8:** The invalid legacy grant is removed from persisted state.
- [x] **PHR-04-V1:** The policy checkpoint was observed failing before the
  production version bump.

### [x] PHR-05 — Complete validation and final review

**Dependencies:** `PHR-01` through `PHR-04`.

Run the focused contract suites:

```sh
cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
swift run CalRelayKitTests \
  RoutingSpecificationTests \
  CalRelayContractTests \
  CalendarConfigurationIdentityTests \
  CalendarAutomationPersistenceTests \
  CalendarStandingAuthorizationTests \
  CalendarAutomaticReconciliationTests
```

Run the required repository gates:

```sh
cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
make format-check

cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
make check

cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
git --no-pager diff --check
```

Inspect final scope and workspace state:

```sh
cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
git --no-pager status --short --branch

cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
git --no-pager diff --stat

cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
git --no-pager diff --cached --stat
```

#### Acceptance and verification

- [x] **PHR-05-V1:** All six focused suites pass.
- [x] **PHR-05-V2:** `make format-check` passes.
- [x] **PHR-05-V3:** `make check` passes.
- [x] **PHR-05-V4:** SwiftLint reports zero violations.
- [x] **PHR-05-V5:** The full deterministic test runner passes.
- [x] **PHR-05-V6:** CLI help smoke checks pass.
- [x] **PHR-05-V7:** `git diff --check` passes.
- [x] **PHR-05-V8:** Existing linker search-path warnings are reported as
  pre-existing rather than concealed.
- [x] **PHR-05-V9:** No app source or resource changed, so `make app` is not
  required.
- [x] **PHR-05-V10:** No real EventKit or calendar mutation is used for
  validation.
- [x] **PHR-05-V11:** The unrelated staged deletion of
  `docs/plans/calendar-access-revision-7-verification-closure-plan.md` remains
  untouched.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Personal prefix is accidentally reintroduced into hub ownership | Keep hub ownership represented by `currentWorkPrefixes` and cover `[PERSONAL]` with a routing regression. |
| The fix unintentionally stops stale work-event cleanup | Retain marker-validity management for all work-calendar marked events and preserve its contract coverage. |
| Stale local hub projections route for one additional cycle | Derive work expectations from the reconciled hub state after planned hub deletions. |
| Explanation disagrees with executable behavior | Test personal-prefix classification through the ordinary explanation path. |
| Existing scheduled automation executes changed policy without renewed review | Include the policy version in authorization identity and test automatic fail-closed behavior with zero mutations. |
| Storage-format `v1` is confused with policy v1 | State explicitly that `v1:<digest>` is the persistence envelope and remains unchanged. |
| Unrelated workspace work is disturbed | Do not run Git index/history mutations; inspect staged and unstaged changes separately. |

## Documentation decision

No accepted specification or project-reference update is required. The
corrected behavior was already required by the routing, projection/safety,
reconciliation, and macOS automation specifications. This change aligns
implementation and tests with those contracts rather than changing product
behavior.

## Completion evidence

- Routing and policy-version RED/GREEN cycles were observed.
- All six focused suites passed.
- `make format-check` passed.
- `make check` passed.
- `git diff --check` passed.
- Final review found no Critical or Required issues.
- The only reported warnings were existing linker search-path warnings.
- The unrelated staged documentation deletion was preserved.