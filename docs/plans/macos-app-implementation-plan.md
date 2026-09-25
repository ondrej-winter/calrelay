# macOS app implementation plan

## Plan record

- **Status:** Proposed and implementation-ready.
- **Prepared:** September 25, 2026.
- **Canonical requirements:**
  [`../specs/macos-app-spec.md`](../specs/macos-app-spec.md), revision 6,
  accepted September 16, 2026.
- **Related capability contracts:**
  [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md),
  [`../specs/configuration-spec.md`](../specs/configuration-spec.md),
  [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md), and
  [`../specs/routing-spec.md`](../specs/routing-spec.md).
- **Related decisions:**
  [`../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md`](../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md),
  [`../adr/0002-build-local-app-bundles-outside-file-provider-workspaces.md`](../adr/0002-build-local-app-bundles-outside-file-provider-workspaces.md),
  and
  [`../adr/0003-use-xctest-only-for-isolated-ui-automation.md`](../adr/0003-use-xctest-only-for-isolated-ui-automation.md).
- **Readiness:** Ready. Requirements, architecture, sequencing, and validation
  boundaries are known. No product decision currently blocks execution.
- **Current-state basis:** Substantial implementation and capability-specific
  deterministic coverage already exist. Work therefore starts with current-HEAD
  verification and permits production changes only when a failing acceptance
  test demonstrates a concrete defect or uncovered behavior.
- **Verification status:** Not run while preparing this plan. Existing source and
  test locations below are evidence candidates, not claims that current HEAD has
  passed the app acceptance contract.

## Outcome

Demonstrate that current HEAD satisfies `APP-01` through `APP-06` and
`APP-AC-01` through `APP-AC-15`.

Use a verification-first approach. If existing evidence passes, the correct
result is an app-specific compliance record rather than a speculative rewrite.
If evidence exposes a defect, retain a failing deterministic contract test or
isolated UI test and make the smallest correction that restores the accepted
contract.

## Scope boundaries

### In scope

- The normal Dock-visible control panel and dependency-ordered recovery state.
- Calendar setup, all-calendar inventory, configured readiness, and prompt
  ownership.
- Manual ordinary dry run, reviewed ordinary apply, and reviewed migration
  cleanup.
- Standing authorization setup, persistence, validation, and invalidation.
- Launch, wake, fixed timer, retry, freshness, configuration-change, and
  app-process-local operation coordination.
- Privacy-limited operational persistence and presentation.
- User notifications, in-app state, and Dock-visible fallback attention.
- Launch-at-login health, login-launch presentation, reopening, and Quit
  behavior.
- Fake-backed macOS UI workflows and accessibility identifiers.
- App bundle metadata, packaging, documentation alignment, and explicit live
  macOS validation.

### Out of scope

- A menu-bar UI.
- Helper applications, LaunchAgents, background-only execution, or sync after
  the normal app exits.
- EventKit change notifications as reconciliation triggers.
- A visual YAML editor or remembered alternate configuration paths.
- A user-configurable scheduling interval.
- Automatic migration cleanup or automatic YAML editing.
- Cross-process serialization against CLI apply.
- Provider APIs, OAuth, or network-backed calendar integration.
- Unrelated refactoring, dependency changes, or architectural restructuring.

## Change policy and architecture constraints

1. Run existing evidence before changing production code.
2. For each demonstrated gap, add or strengthen a failing deterministic contract
   test or isolated UI test before changing production behavior.
3. Make the smallest correction that passes the new evidence; do not rewrite
   already compliant capability code.
4. Keep SwiftUI views, app delegates, notification callbacks, timer callbacks,
   and login-item handlers thin.
5. Keep deterministic policy, boundary DTOs, and orchestration in `CalRelayKit`.
6. Keep EventKit, ServiceManagement, UserNotifications, SwiftUI, AppKit,
   filesystem observation, and other macOS integration mechanics in adapters or
   `CalRelayApp` composition.
7. Keep default tests offline, fake-backed, deterministic, and independent of
   real calendars, wall-clock timing, and shared developer state.
8. Do not persist raw configuration, calendar names, selectors, markers,
   EventKit identifiers, event titles, event details, or EventKit object dumps.
9. Review `CalendarReconciliationPolicyVersion.current` if a correction changes
   ordinary executable actions, exact targets, or execution order for identical
   inputs.
10. Do not add an ADR unless execution intentionally changes an accepted durable
    lifecycle, persistence, packaging, permission, security, or signing decision.
11. Preserve the production bundle identifier `dev.owinter.CalRelay`.
12. Keep live EventKit and operating-system validation separate from automated
    completion evidence and use only harmless, dedicated local calendars.

## Evidence and acceptance traceability

The source and test columns identify current evidence candidates. `APP-P01`
must verify each mapping before any row is treated as satisfied.

| Requirement | Current source evidence candidates | Current test evidence candidates | Planned task |
| --- | --- | --- | --- |
| `APP-01` | `Sources/CalRelayApp/CalendarListView.swift`; `Sources/CalRelayApp/CalendarListViewModel.swift`; `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarControlPanelStatusUseCase.swift` | `CalendarControlPanelStatusTests`; `CalendarAuthorizationTests`; `CalendarNoPromptContractTests`; isolated UI scenarios | `APP-P02`, `APP-P06`, `APP-P07` |
| `APP-02` | `CalendarManualDryRunUseCase.swift`; `CalendarManualApplyUseCase.swift`; `CalendarManualCleanupUseCase.swift`; app review views and view models | Manual dry-run, apply, reviewed-action, cleanup, and access contract suites | `APP-P03`, `APP-P07` |
| `APP-03` | `CalendarStandingAuthorizationUseCase.swift`; standing-authorization DTOs; automation persistence adapter; app scheduling controls | `CalendarStandingAuthorizationTests`; `CalendarConfigurationIdentityTests`; `CalendarAutomationPersistenceTests` | `APP-P04` |
| `APP-04` | `CalendarAutomaticReconciliationUseCase.swift`; `CalendarAutomationSchedulingPolicy.swift`; `CalendarAppOperationCoordinator.swift`; configuration observer and app trigger source | `CalendarAutomaticReconciliationTests`; `CalendarAutomationCoordinationTests`; `CalendarConfigurationObservationTests` | `APP-P05` |
| `APP-05` | automation persistence DTOs and adapter; attention policy/controller; automation presentation | `CalendarAutomationPersistenceTests`; `CalendarAutomationCoordinationTests`; isolated UI scenarios | `APP-P06`, `APP-P07` |
| `APP-06` | `CalRelayApp.swift`; `CalRelayAppDelegate.swift`; `CalendarLaunchAtLoginController.swift`; app bundle resources | `CalendarLoginLaunchPolicyTests`; `CalendarAppBundleMetadataTests`; live macOS validation | `APP-P06`, `APP-P08` |
| `APP-AC-01` | Control-panel view/view model, app delegate, login-launch policy | `CalendarControlPanelStatusTests`; `CalendarLoginLaunchPolicyTests`; isolated UI and live startup checks | `APP-P02`, `APP-P06`, `APP-P07`, `APP-P08` |
| `APP-AC-02` | Calendar setup/recovery composition and authorization boundary | `CalendarAuthorizationTests`; `CalendarNoPromptContractTests`; live TCC validation | `APP-P02`, `APP-P08` |
| `APP-AC-03` | Control-panel status DTO/use case and app presentation composition | `CalendarControlPanelStatusTests`; isolated UI scenarios | `APP-P02`, `APP-P07` |
| `APP-AC-04` | Standing-authorization use case, binding, mutation identity, persistence | `CalendarStandingAuthorizationTests`; `CalendarConfigurationIdentityTests`; `CalendarAutomationPersistenceTests` | `APP-P04` |
| `APP-AC-05` | Trigger source, scheduling policy, automation view-model extension, login controller, app delegate | Automation, coordination, login policy, bundle, UI, and live lifecycle checks | `APP-P05`, `APP-P06`, `APP-P08` |
| `APP-AC-06` | Automatic reconciliation use case and no-prompt boundaries | `CalendarAutomaticReconciliationTests`; `CalendarNoPromptContractTests` | `APP-P04`, `APP-P05` |
| `APP-AC-07` | App operation coordinator, automatic use case, configuration observation | `CalendarAutomationCoordinationTests`; `CalendarConfigurationObservationTests` | `APP-P05` |
| `APP-AC-08` | Manual apply use case and executable-action identity DTO | `CalendarManualApplyTests`; `CalendarManualApplySafetyTests`; `CalendarManualApplyFreshSnapshotTests`; `CalendarReviewedActionTests` | `APP-P03` |
| `APP-AC-09` | Manual cleanup use case, cleanup formatter, review view, migration presentation | Manual cleanup, cleanup access, privacy, and isolated UI suites | `APP-P03`, `APP-P07` |
| `APP-AC-10` | Automation persistence adapter and attention policy/controller | `CalendarAutomationPersistenceTests`; automation coordination tests; UI and live notification checks | `APP-P06`, `APP-P07`, `APP-P08` |
| `APP-AC-11` | Automatic reconciliation and trigger composition | `CalendarAutomaticReconciliationTests`; static trigger inspection | `APP-P05` |
| `APP-AC-12` | Normal app composition, login controller, package and bundle metadata | `CalendarAppBundleMetadataTests`; static artifact inspection; live process check | `APP-P06`, `APP-P08` |
| `APP-AC-13` | Manual and automatic ordinary reconciliation success handling | Manual apply and automatic reconciliation suites | `APP-P03`, `APP-P05` |
| `APP-AC-14` | Manual apply failure handling and automatic fresh-run orchestration | Manual apply failure/safety tests; automatic reconciliation and coordination tests; isolated UI failure scenario | `APP-P03`, `APP-P05`, `APP-P07` |
| `APP-AC-15` | Standing-authorization binding, topology identity, policy version, opaque persistence | `CalendarStandingAuthorizationTests`; `CalendarConfigurationIdentityTests`; `CalendarAutomationPersistenceTests` | `APP-P04` |

## Execution order

`APP-P01` establishes baseline evidence and the authoritative acceptance map.
After it completes, `APP-P02`, `APP-P03`, and `APP-P04` can be investigated in
parallel, but changes to shared app presentation files must be integrated
serially. `APP-P05` depends on authorization semantics from `APP-P04`.
`APP-P06` depends on the resolved control-panel and automation state model.
`APP-P07` verifies the assembled fake-backed workflows. `APP-P08` is the final
documentation, quality-gate, and separate live-validation checkpoint.

## Detailed tasks

### APP-P01 — Establish baseline and app-specific traceability

**Requirements:** All `APP-01` through `APP-06` and `APP-AC-01` through
`APP-AC-15`.

**Dependencies:** None.

**Likely files:** This plan, the owning specification, existing app sources,
contract tests, UI tests, `docs/development.md`, and the `Makefile`.

**Work:**

- Inspect Git status and preserve all existing staged, unstaged, and untracked
  work.
- Run the current complete deterministic gate and app-bundle build before
  production edits.
- Verify every row in the traceability table against current source and tests.
- Classify each acceptance check as already evidenced, missing evidence, or a
  demonstrated production defect.
- Separate deterministic, isolated XCUITest, and live macOS evidence.
- Reuse completed capability evidence without treating it as automatic proof of
  the app-level acceptance contract.

- [ ] **APP-P01-AC1:** Every accepted app requirement maps to an implementation
  surface and an observable verification path.
- [ ] **APP-P01-AC2:** Missing evidence is distinguished from failing behavior.
- [ ] **APP-P01-AC3:** Existing capability plans and tests are referenced rather
  than duplicated or rewritten.
- [ ] **APP-P01-V1:** `make check` passes on the pre-change baseline, or each
  failure is recorded with its exact command and observed result.
- [ ] **APP-P01-V2:** `make app` produces and strictly verifies the production
  app bundle, or the failure is recorded with its exact command and observed
  result.

**Expected result:** A trustworthy current-HEAD evidence map and a bounded list
of demonstrated gaps, if any.

**Risk and rollback:** Baseline commands may reveal unrelated failures. Do not
hide them or broaden this task to fix them; record them and isolate whether they
block app verification. This task should not change production behavior.

### APP-P02 — Verify control-panel precedence and permission ownership

**Requirements:** `APP-01`, `APP-AC-01`, `APP-AC-02`, and `APP-AC-03`.

**Dependencies:** `APP-P01` evidence map.

**Likely files if a gap is demonstrated:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarControlPanelStatus.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarControlPanelStatusUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomationAttentionPolicy.swift`
- `Sources/CalRelayApp/CalendarListViewModel.swift`
- `Sources/CalRelayApp/CalendarListViewModel+Automation.swift`
- `Sources/CalRelayApp/CalendarListView.swift`
- Control-panel, authorization, privacy, and no-prompt contract tests

**Test-first verification:**

- Cover the full dependency order: configuration, Calendar access, topology,
  migration, standing authorization, launch-at-login, scheduling/retry/freshness,
  then healthy.
- Add simultaneous-failure cases proving that the primary action can succeed and
  that later known issues remain secondary.
- Cover not-determined, restricted, denied or revoked, write-only, full-access,
  and unknown Calendar authorization states.
- Prove that only the explicit setup/recovery action can request access.
- Prove that inventory is ID-free, configuration-independent, and cannot claim
  configured readiness.
- If private app composition prevents credible deterministic verification,
  extract only the smallest pure presentation policy needed for testing.

- [ ] **APP-P02-AC1:** Primary recovery state follows the accepted dependency
  order for simultaneous failures.
- [ ] **APP-P02-AC2:** Configuration, inventory, readiness, migration,
  authorization, scheduling, and operation history remain semantically distinct.
- [ ] **APP-P02-AC3:** A partial prior result remains prominent without hiding an
  earlier unmet prerequisite.
- [ ] **APP-P02-AC4:** Only the setup/recovery workflow can prompt for full
  Calendar access.
- [ ] **APP-P02-AC5:** Inventory is ID-free and separate from configured
  readiness.
- [ ] **APP-P02-V1:**
  `swift run CalRelayKitTests CalendarAuthorizationTests CalendarNoPromptContractTests CalendarControlPanelStatusTests CalendarAccessPrivacyTests`
  passes.

**Expected result:** Either current behavior receives complete deterministic
evidence, or the smallest tested policy/presentation correction restores it.

**Risk and rollback:** Control-panel state is composed across app and application
layers. Avoid replacing established capability status with an app-only parallel
model. Revert only the bounded correction if it causes precedence regressions.

### APP-P03 — Verify manual ordinary reconciliation and migration cleanup

**Requirements:** `APP-02`, `APP-AC-08`, `APP-AC-09`, `APP-AC-13`, and the manual
recovery portion of `APP-AC-14`.

**Dependencies:** `APP-P01` evidence map.

**Likely files if a gap is demonstrated:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualDryRunUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualApplyUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualCleanupUseCase.swift`
- `Sources/CalRelayApp/CalendarListViewModel.swift`
- `Sources/CalRelayApp/CalendarListViewModel+Cleanup.swift`
- `Sources/CalRelayApp/CalendarCleanupReviewView.swift`
- Manual dry-run, apply, reviewed-action, cleanup, access, and privacy tests

**Test-first verification:**

- Prove that dry run is non-mutating and aggregate-only.
- Prove that ordinary apply reloads configuration and repeats preflight,
  snapshots, and planning immediately before mutation.
- Compare ordered executable actions including physical calendar and exact
  recurring-delete occurrence identity.
- Reject executable or order changes even when aggregate counts are unchanged,
  while tolerating rationale-only changes.
- Prove that a ready empty plan succeeds without mutation or post-apply reread.
- Prove that partial manual failure consumes confirmation and requires a fresh
  manual review.
- Prove that migration pending blocks ordinary manual and automatic actions.
- Prove that cleanup uses complete preflight, ordered transient detail, separate
  confirmation, exact deletion, and complete post-apply no-match verification.
- Prove that cleanup never edits YAML, enables ordinary scheduling, or persists
  event-level review data.

- [ ] **APP-P03-AC1:** Ordinary confirmation is bound to the fresh ordered
  executable plan, not only aggregate counts.
- [ ] **APP-P03-AC2:** Rationale-only changes do not invalidate an otherwise
  identical executable plan.
- [ ] **APP-P03-AC3:** Partial manual failure cannot resume under consumed
  confirmation.
- [ ] **APP-P03-AC4:** Ready empty ordinary plans count as successful without a
  verification read.
- [ ] **APP-P03-AC5:** Cleanup remains separate, migration-only, privacy-safe,
  exact-plan-reviewed, and verification-backed.
- [ ] **APP-P03-V1:**
  `swift run CalRelayKitTests CalendarManualDryRunTests CalendarManualApplyTests CalendarReviewedActionTests`
  passes.
- [ ] **APP-P03-V2:**
  `swift run CalRelayKitTests CalendarManualCleanupTests CalendarCleanupAccessTests CalendarAccessPrivacyTests`
  passes.

**Expected result:** Manual workflows receive exact stale-review, partial-failure,
empty-plan, cleanup, and privacy evidence without changing their product scope.

**Risk and rollback:** Executable identity changes can affect both manual and
standing authorization semantics. Reassess the policy version before retaining
such a production change. Do not weaken comparison to preserve old tests.

### APP-P04 — Verify standing authorization binding and invalidation

**Requirements:** `APP-03`, `APP-AC-04`, the authorization portions of
`APP-AC-06`, and `APP-AC-15`.

**Dependencies:** `APP-P01`; use the readiness semantics verified by `APP-P02`.

**Likely files if a gap is demonstrated:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarStandingAuthorizationBinding.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/OrdinaryConfigurationMutationIdentity.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarStandingAuthorizationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/Persistence/UserDefaultsCalendarAutomationStateStore.swift`
- Scheduling controls in the app view and view model
- Standing-authorization, configuration-identity, persistence, and no-prompt
  tests

**Test-first verification:**

- Prove that first enablement requires a successful fresh ordinary dry run and
  explicit confirmation.
- Prove that review alone neither mutates calendars nor grants authorization.
- Bind authorization to semantic configuration identity, current reconciliation
  policy version, and declaration-ordered physical topology identity.
- Preserve equivalence for representation-only YAML and diagnostic role-name
  changes.
- Invalidate for mutation-relevant settings, work-calendar declaration order,
  policy version, physical calendar identity, or unproven continuity.
- Invalidate immediately on an observed selected-file change, including an
  `A → B → A` sequence.
- Prove that pause preserves a matching authorization but cannot reactivate an
  invalid authorization.
- Prove that standing authorization cannot authorize manual apply or cleanup.
- Prove that persisted identity is opaque and reveals none of its inputs.

- [ ] **APP-P04-AC1:** Scheduling cannot become enabled before confirmed fresh
  standing authorization.
- [ ] **APP-P04-AC2:** Every required configuration, policy, topology, and
  continuity change invalidates authorization.
- [ ] **APP-P04-AC3:** Pause/resume preserves only a still-matching binding.
- [ ] **APP-P04-AC4:** Authorization identity remains opaque in persistence,
  diagnostics, descriptions, and UI.
- [ ] **APP-P04-AC5:** Authorization setup and validation never request Calendar
  permission or mutate calendars.
- [ ] **APP-P04-V1:**
  `swift run CalRelayKitTests CalendarStandingAuthorizationTests CalendarConfigurationIdentityTests CalendarAutomationPersistenceTests CalendarNoPromptContractTests`
  passes.

**Expected result:** Current authorization receives complete binding and upgrade
evidence, or a minimal tested correction closes the demonstrated gap.

**Risk and rollback:** Persisted binding compatibility is safety-sensitive. Fail
closed for unknown or obsolete data, do not migrate by assuming physical calendar
continuity, and increment the policy version when behavior identity changes.

### APP-P05 — Verify scheduling, lifecycle triggers, retry, and overlap

**Requirements:** `APP-04`, `APP-AC-05`, `APP-AC-06`, `APP-AC-07`, `APP-AC-11`,
the automatic portion of `APP-AC-13`, and the automatic-repair portion of
`APP-AC-14`.

**Dependencies:** `APP-P04` authorization semantics.

**Likely files if a gap is demonstrated:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomaticReconciliationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomationSchedulingPolicy.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAppOperationCoordinator.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/ConfigurationFileObserver.swift`
- `Sources/CalRelayApp/CalendarAutomationTriggerSource.swift`
- `Sources/CalRelayApp/CalendarListViewModel+Automation.swift`
- Automatic reconciliation, coordination, and configuration-observation tests

**Test-first verification:**

- Prove the fixed 15-minute timer cadence and the more-than-60-minute overdue
  boundary.
- Prove that launch and wake request prompt ordinary attempts whenever scheduling
  is enabled, regardless of prior success time.
- Prove finite bounded backoff and retry exhaustion.
- Prove that retries reload configuration, authorization state, preflight,
  topology, snapshots, and plans rather than resuming stale work.
- Prove that any gate failure or pre-mutation file change prevents all mutation
  and that no last-known-valid configuration fallback exists.
- Prove that ready empty plans and fully confirmed mutating plans update freshness.
- Prove that deterministic plan size does not independently block automatic
  mutation.
- Prove that automatic runs never prompt or request per-run confirmation.
- Prove no overlap among app-owned manual, cleanup, automatic, and configuration
  recovery work.
- Prove at most one coalesced fresh follow-up and that configuration recovery
  precedes pending automatic work.
- Confirm statically that no cross-process lock or EventKit-change trigger is
  claimed.

- [ ] **APP-P05-AC1:** Launch, wake, timer, and retry use the accepted gates and
  fresh data.
- [ ] **APP-P05-AC2:** App-owned operations never overlap and pending automatic
  triggers coalesce into at most one fresh follow-up.
- [ ] **APP-P05-AC3:** Configuration recovery has priority over pending automatic
  reconciliation.
- [ ] **APP-P05-AC4:** User-action failures remain actionable without aggressive
  retry.
- [ ] **APP-P05-AC5:** Automatic repair after partial state occurs only through a
  later normal fresh authorized run.
- [ ] **APP-P05-AC6:** Plan size does not independently block apply, and EventKit
  notifications do not trigger reconciliation.
- [ ] **APP-P05-V1:**
  `swift run CalRelayKitTests CalendarAutomaticReconciliationTests CalendarAutomationCoordinationTests CalendarConfigurationObservationTests`
  passes.

**Expected result:** Scheduling and coordination have deterministic evidence for
freshness, retry, coalescing, stale-data rejection, and no-overlap behavior.

**Risk and rollback:** Concurrency corrections can create duplicate or lost
follow-ups. Keep serialization in one coordinator, use deterministic fakes, and
remove a correction if it cannot prove both no-overlap and fresh follow-up
behavior.

### APP-P06 — Verify persistence, attention, login launch, and lifecycle limits

**Requirements:** `APP-05`, `APP-06`, lifecycle portions of `APP-AC-01`,
`APP-AC-05`, `APP-AC-10`, and `APP-AC-12`.

**Dependencies:** `APP-P02`, `APP-P04`, and `APP-P05` state semantics.

**Likely files if a gap is demonstrated:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/Persistence/UserDefaultsCalendarAutomationStateStore.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomationAttentionPolicy.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarLoginLaunchPolicy.swift`
- `Sources/CalRelayApp/CalendarAutomationAttentionController.swift`
- `Sources/CalRelayApp/CalendarLaunchAtLoginController.swift`
- `Sources/CalRelayApp/CalRelayAppDelegate.swift`
- `Sources/CalRelayApp/CalRelayApp.swift`
- `Resources/CalRelayApp/Info.plist`
- Persistence, coordination, login-policy, bundle-metadata, and privacy tests

**Test-first verification:**

- Assert a persistence allowlist containing only approved preferences, opaque
  authorization, timestamps, result or failure categories, retry metadata, and
  aggregate mutation counts.
- Assert that corrupt or unsupported persistence fails closed without retaining
  standing authorization.
- Assert fixed privacy-safe notification content and that notification denial
  does not block scheduling.
- Assert persistent in-app state and Dock-visible fallback attention when human
  notifications are unavailable.
- Verify that enabling scheduling attempts launch-at-login registration for the
  normal app and that disabled, approval-required, or unavailable registration
  degrades health visibly.
- Verify that a healthy login-item launch remains hidden through its initial
  fresh automatic attempt, while actionable setup or recovery opens the panel.
- Verify ordinary Dock/Finder launch, reopening, and explicit Quit warning.
- Verify Quit does not clear scheduling or launch-at-login preferences.
- Verify the stable production bundle identifier and the absence of menu-bar,
  helper, LaunchAgent, accessory-only, or closed-app execution artifacts.

- [ ] **APP-P06-AC1:** Persistence and presentation obey the approved privacy
  allowlist.
- [ ] **APP-P06-AC2:** Notification denial leaves scheduling available with
  in-app and Dock-visible fallback status.
- [ ] **APP-P06-AC3:** Login launch presentation follows the healthy and recovery
  state matrix.
- [ ] **APP-P06-AC4:** Launch-at-login degradation is actionable and prevents a
  fully healthy presentation.
- [ ] **APP-P06-AC5:** Explicit Quit and closed-app behavior match ADR 0001.
- [ ] **APP-P06-AC6:** The production app remains Dock-visible with bundle
  identifier `dev.owinter.CalRelay` and no helper-based execution.
- [ ] **APP-P06-V1:**
  `swift run CalRelayKitTests CalendarAutomationPersistenceTests CalendarAutomationCoordinationTests CalendarLoginLaunchPolicyTests CalendarAppBundleMetadataTests`
  passes.
- [ ] **APP-P06-V2:** Static inspection finds no menu-bar, helper, LaunchAgent,
  background-only, or EventKit-triggered reconciliation artifact.

**Expected result:** Operational state, privacy, attention, launch presentation,
and the normal-app-only lifecycle boundary receive app-specific evidence.

**Risk and rollback:** ServiceManagement, UserNotifications, Dock behavior, and
login startup cannot be proven completely by deterministic tests. Keep adapters
thin, fail visibly, and defer claims about live integration to `APP-P08`.

### APP-P07 — Verify isolated XCUITest workflows and accessibility contracts

**Requirements:** UI-facing evidence for `APP-AC-01` through `APP-AC-05`,
`APP-AC-08` through `APP-AC-10`, and `APP-AC-14`.

**Dependencies:** `APP-P02` through `APP-P06`.

**Likely files if evidence is missing:**

- `Sources/CalRelayApp/CalendarListView.swift`
- `Sources/CalRelayApp/CalendarCleanupReviewView.swift`
- `Sources/CalRelayApp/CalendarUITestComposition.swift`
- `UITests/CalRelayUITests/CalRelayUITests.swift`
- `Resources/CalRelayUITestHost/Info.plist`
- `scripts/build-calrelay-ui-test-app.sh`

**Test-first verification:**

- Run existing missing-configuration, access-unavailable, ready, manual review,
  migration cleanup, and scheduling scenarios.
- Verify disabled controls and primary/secondary presentation for dependency
  state.
- Verify manual and cleanup review confirmation, cancellation, keyboard escape,
  failure, and relaunch disposal.
- Verify ordinary inventory and dry-run presentation omit prohibited identifiers
  and event details.
- Verify cleanup review displays only permitted transient detail.
- Verify scheduling authorization, pause/resume, degraded state, and
  notification-denial fallback presentation where deterministic composition can
  represent them.
- Add only scenarios required to close an APP acceptance evidence gap.
- Preserve fake-host isolation from EventKit, permissions, notifications,
  ServiceManagement, timers, wake events, and production persistence.

- [ ] **APP-P07-AC1:** Primary panel and review workflows expose stable
  accessibility identifiers.
- [ ] **APP-P07-AC2:** Review cancellation, completion, failure, and relaunch
  disposal behavior is covered.
- [ ] **APP-P07-AC3:** UI output obeys inventory, ordinary-review,
  cleanup-review, and notification privacy boundaries.
- [ ] **APP-P07-AC4:** UI-test composition remains isolated from production
  macOS services and personal state.
- [ ] **APP-P07-V1:** `make ui-test` passes using the isolated UI-test host.

**Expected result:** The user-visible workflows receive stable fake-backed smoke
coverage without turning XCUITest into live system integration testing.

**Risk and rollback:** Broader UI automation would be slower and flaky. Prefer
deterministic application tests for policy and retain only high-value workflow
checks in XCUITest.

### APP-P08 — Align documentation, run final gates, and record live evidence

**Requirements:** Final evidence for all requirements and acceptance checks.

**Dependencies:** `APP-P01` through `APP-P07`.

**Likely documentation files only if verified behavior or instructions change:**

- `docs/configuration.md`
- `docs/development.md`
- `docs/repository-layout.md`
- `README.md`
- This plan

**Work:**

- Update project references only when verified behavior or operational
  instructions differ from current documentation.
- Do not recreate the previously consolidated manual-validation document merely
  for this task. Keep app-specific evidence in this plan unless a durable project
  workflow genuinely belongs in a canonical project reference.
- Record focused and complete command results against their canonical plan IDs.
- Reassess whether any retained correction requires a reconciliation-policy
  version increment, specification update, or ADR. Obtain explicit approval
  before changing the accepted product contract.
- Preserve unrelated work and leave agent-created changes unstaged.
- Perform live macOS checks separately from the deterministic gate.

- [ ] **APP-P08-AC1:** Every `APP-AC-01` through `APP-AC-15` row has current
  deterministic, isolated UI, or explicitly identified live-only evidence.
- [ ] **APP-P08-AC2:** Documentation agrees with verified app behavior and
  lifecycle boundaries.
- [ ] **APP-P08-AC3:** No unrelated cleanup, dependency update, or silent
  accepted-contract change was introduced.
- [ ] **APP-P08-V1:** `make format-check` passes.
- [ ] **APP-P08-V2:** `make check` passes.
- [ ] **APP-P08-V3:** `make app` passes with strict signature verification.
- [ ] **APP-P08-V4:** `make ui-test` passes when app UI, accessibility, fake
  composition, or the UI-test harness changed; otherwise the passing `APP-P07-V1`
  evidence is referenced.
- [ ] **APP-P08-V5:** `git --no-pager diff HEAD --check` passes.
- [ ] **APP-P08-V6:** Final Git status and diff review confirm that unrelated
  work was preserved.

**Expected result:** A complete app acceptance record, aligned documentation, and
a clean handoff that distinguishes automated proof from live macOS observations.

**Risk and rollback:** Live service checks can alter local permissions, login
items, notifications, or calendars. Use a dedicated environment and calendars,
record observations without personal data, and restore only task-created local
settings after validation.

## Separate live macOS validation checkpoint

These checks require a suitable Mac and the production app bundle. They do not
form part of the ordinary deterministic gate and must not be represented as
automated passes.

- [ ] **APP-LIVE-01:** Validate initial Calendar permission acquisition and
  denied or revoked recovery under the production bundle identity.
- [ ] **APP-LIVE-02:** Validate ID-free inventory versus configured readiness
  using harmless dedicated calendars.
- [ ] **APP-LIVE-03:** Validate notification authorization and denial, including
  persistent in-app and Dock-badge fallback.
- [ ] **APP-LIVE-04:** Validate launch-at-login registration, approval-required
  state, disablement, and recovery.
- [ ] **APP-LIVE-05:** Validate that a healthy login launch remains unobtrusive
  and an actionable login launch opens the control panel.
- [ ] **APP-LIVE-06:** Validate wake-triggered reconciliation and observable
  fixed-cadence scheduling behavior without relying on wall-clock timing in
  automated tests.
- [ ] **APP-LIVE-07:** Validate scheduling pause/resume, ordinary reopen behavior,
  and the explicit Quit warning.
- [ ] **APP-LIVE-08:** Validate configuration creation, edit, replacement, and
  removal refresh current status without cached-setting fallback.
- [ ] **APP-LIVE-09:** Validate migration cleanup only with harmless dedicated
  calendars, including transient detail and privacy boundaries.
- [ ] **APP-LIVE-10:** Validate that synchronization stops after the normal app
  exits and that no helper or background process continues running.

## Risks and mitigations

- **False green from shared capability tests:** Require explicit APP-level
  traceability and isolated user-workflow evidence.
- **Live-service behavior cannot be fully deterministic:** Keep TCC,
  ServiceManagement, wake, notifications, Dock attention, and Quit presentation
  in the separate live checkpoint.
- **Privacy regression:** Use sentinel-based persistence and output tests that
  assert prohibited values are absent.
- **Stale authorization after behavior change:** Reassess and increment policy
  identity when executable actions, targets, or order change.
- **App wrapper gains orchestration:** Reuse application use cases and extract a
  pure policy only when required for deterministic verification.
- **Flaky UI automation:** Keep the UI host fake-backed and exclude live EventKit,
  permission prompts, timers, login items, notifications, and production state.
- **Duplicating completed capability work:** Start from current tests and plans;
  change production code only for demonstrated app-contract gaps.
- **Parallel edit conflicts:** Investigations may proceed in parallel, but edits
  to `CalendarListViewModel`, `CalendarListView`, test-runner registration, and
  shared UI-test composition must be integrated serially.
- **Live calendar damage:** Use only dedicated local test calendars and never run
  live mutation as part of `make check`.

## Handoff

- **Readiness:** Ready.
- **Next executable task:** `APP-P01`.
- **Unresolved product decisions:** None.
- **Blocked work:** None.
- **Expected implementation posture:** Verification-first; production changes
  are conditional on failing acceptance evidence.
- **Deferred by the accepted contract:** Menu-bar UI, closed-app sync, helpers,
  LaunchAgents, EventKit-triggered runs, alternate remembered configuration
  paths, visual configuration editing, and automatic cleanup.