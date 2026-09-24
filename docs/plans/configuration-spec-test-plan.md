# Configuration specification implementation plan

## Plan record

- **Status:** Complete. `CFG-P01` through `CFG-P09` have current-HEAD evidence
  from September 24, 2026. No production behavior or user guidance required a
  correction; the custom runner required one focused filter-dispatch fix.
- **Prepared:** September 24, 2026.
- **Canonical requirements:**
  [`../specs/configuration-spec.md`](../specs/configuration-spec.md), revision 8,
  accepted September 17, 2026.
- **Related accepted contracts:**
  [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md),
  [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md),
  [`../specs/routing-spec.md`](../specs/routing-spec.md),
  [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md),
  [`../specs/cli-spec.md`](../specs/cli-spec.md), and
  [`../specs/macos-app-spec.md`](../specs/macos-app-spec.md).
- **Current state:** A predecessor plan at this path completed configuration
  specification revision 8 verification in commit `559226d` on September 22,
  2026 and was removed in commit `75e2b73` when routing became the active
  planning focus. Current HEAD already contains extensive configuration
  implementation and acceptance-oriented tests. The material later shared-core
  change is routing correction `94352fd`, which changed ordinary reconciliation
  semantics and advanced the standing-authorization policy to
  `ordinary-reconciliation-policy-v2`.
- **Readiness:** Ready. Requirements, architecture, likely targets, sequencing,
  and validation commands are known. The specification's EventKit-ID selector
  question remains deferred and does not block the accepted source/title model.

## Outcome

Demonstrate that current HEAD satisfies `CONFIG-01` through `CONFIG-09` and
`CONFIG-AC-01` through `CONFIG-AC-18`.

If focused verification exposes a defect, retain a deterministic failing
regression test and make the smallest production correction that restores the
accepted contract. Update user-facing configuration documentation only when
current behavior or guidance is missing or stale.

If all focused and complete gates pass, the correct result is a current
verified-compliance record with no unnecessary production rewrite.

## Scope boundaries

### In scope

- Strict `Yams` parsing and the exact accepted YAML schema.
- Unknown and duplicate mapping-key rejection.
- Marker grammar, case sensitivity, and pairwise uniqueness.
- Selector collision validation and exact runtime resolution.
- `syncWindowDays` defaults and bounds.
- Default and explicit configuration-path semantics.
- Missing-file precedence, privacy-safe failures, and fresh file loading.
- Migration-pending gates for ordinary CLI and app workflows.
- Config-check behavior while migration is pending.
- Bounded legacy cleanup, exact matching, positive-overlap membership, and
  verification.
- App file observation, fresh loading, no cached-valid fallback, and
  pre-mutation race handling.
- Semantic configuration identity, reconciliation-policy version, resolved
  topology identity, authorization invalidation, and opaque persistence.
- Operator-facing retirement, dormant-writer, recurring-series,
  removed-calendar, and marker-reuse documentation.
- Custom test-runner registration and repository validation.

### Out of scope

- Changing the accepted YAML schema, marker grammar, selector semantics, or
  cleanup range.
- EventKit-ID configuration selectors or automatic ID fallback.
- Profiles, environment overrides, remembered alternate app paths, arbitrary
  directory search, or configuration editing.
- Global marker registries, fuzzy deletion, unbounded EventKit scans, or
  whole-series deletion.
- Automatic YAML rewriting or removal of `legacyMarkers`.
- Unrelated refactoring or dependency changes.
- Real EventKit access or real calendar mutation as an automated check.
- Resolving the specification's future selector-stability question.

## Change policy

1. Treat the historical completed plan as context, not current passing evidence.
2. Run existing acceptance-oriented suites before editing production code.
3. Add a failing deterministic test before every behavioral correction.
4. Keep filesystem and `Yams` mechanics in adapters; keep application and
   domain APIs independent of filesystem resolution and live EventKit.
5. Preserve privacy: no raw YAML, marker values, selectors, calendar titles,
   event titles, or raw EventKit IDs in persistence or prohibited diagnostics.
6. Do not update the accepted specification unless a genuine contract conflict
   is found and explicitly approved.
7. Keep agent-created changes unstaged unless an exact Git operation is
   requested.

## Acceptance-check coverage

| Acceptance checks | Owning plan task |
| --- | --- |
| `CONFIG-AC-01` through `CONFIG-AC-04` | `CFG-P02` |
| `CONFIG-AC-05` and `CONFIG-AC-06` | `CFG-P03` |
| `CONFIG-AC-07` and `CONFIG-AC-08` | `CFG-P04` |
| `CONFIG-AC-09` and `CONFIG-AC-10` | `CFG-P05` |
| `CONFIG-AC-11` | `CFG-P02`, `CFG-P03`, and `CFG-P09` |
| `CONFIG-AC-12` and `CONFIG-AC-14` | `CFG-P06` |
| `CONFIG-AC-13`, `CONFIG-AC-16`, and `CONFIG-AC-17` | `CFG-P07` |
| `CONFIG-AC-15` and `CONFIG-AC-18` | `CFG-P08` |

## Execution summary

`CFG-P01` establishes current-HEAD traceability. `CFG-P02` and `CFG-P03`
establish validated settings and file-loading behavior. `CFG-P04` through
`CFG-P07` verify dependent runtime behavior. `CFG-P08` may proceed alongside
runtime verification because its write boundary is limited to project
documentation. `CFG-P09` integrates all evidence and closes the plan.

## Detailed tasks

### CFG-P01 — Re-establish current-HEAD traceability

**Dependencies:** None.

**Likely targets:**

- `docs/plans/configuration-spec-test-plan.md`
- `Tests/CalRelayKitTests/Main.swift`

**Work:**

- Restore the established plan path without copying stale completion claims.
- Record the predecessor plan and later reconciliation-policy change.
- Map every `CONFIG-AC-01` through `CONFIG-AC-18` to current suites and
  documentation.
- Confirm every required suite is registered and individually focusable through
  the custom runner.

- [x] **CFG-P01:** Current-HEAD configuration traceability is established.
- [x] **CFG-P01-AC1:** Every configuration acceptance check has an implementation
  task and observable evidence.
- [x] **CFG-P01-AC2:** Historical passing evidence is identified as historical
  rather than represented as current.
- [x] **CFG-P01-AC3:** Every referenced suite has a matching registration in the
  executable test runner.
- [x] **CFG-P01-V1:** Focused suite names execute through
  `swift run CalRelayKitTests <SuiteName>`.

### CFG-P02 — Verify strict schema, markers, window, and structural selectors

**Dependencies:** `CFG-P01`.

**Likely production targets, only if tests expose a defect:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/YAMLCalendarRelaySettingsLoader.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarRelaySettings.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Domain/Policies/MarkerSyntax.swift`

**Test targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarConfigurationSchemaTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalRelayContractTests.swift`

- [x] **CFG-P02:** Strict schema and structural settings behavior is verified.
- [x] **CFG-P02-AC1:** The normative schema decodes exactly, applies both optional
  defaults, and preserves `workCalendars` declaration order.
- [x] **CFG-P02-AC2:** Missing fields, wrong container or scalar types, unknown
  fields, and duplicate keys fail before EventKit access without raw-YAML
  disclosure.
- [x] **CFG-P02-AC3:** Valid markers match the complete grammar case-sensitively;
  malformed and duplicate personal, work, and legacy markers are rejected.
- [x] **CFG-P02-AC4:** `syncWindowDays` defaults to `100`, accepts `1` and `365`,
  and rejects zero, negative, non-integer, and greater-than-365 values.
- [x] **CFG-P02-AC5:** Exact duplicate selector tuples identify all conflicting
  roles; distinct tuples pass structural validation.
- [x] **CFG-P02-V1:**
  `swift run CalRelayKitTests CalendarConfigurationSchemaTests` passes.
- [x] **CFG-P02-V2:** `swift run CalRelayKitTests CalRelayContractTests` passes.

### CFG-P03 — Verify configuration selection and fresh file loading

**Dependencies:** `CFG-P01`, `CFG-P02`.

**Likely production targets, only if tests expose a defect:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigurationFileSelection.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/FileCalendarRelaySettingsProvider.swift`

**Test targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigurationFileSelectionTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/Config/FileCalendarRelaySettingsProviderTests.swift`

- [x] **CFG-P03:** Configuration selection and fresh loading behavior is
  verified.
- [x] **CFG-P03-AC1:** Default selection resolves to the current user's
  `~/.config/calrelay/config.yaml`.
- [x] **CFG-P03-AC2:** Absolute, relative, `~`, and `~/...` overrides follow the
  contract; `~otheruser` and environment variables remain literal.
- [x] **CFG-P03-AC3:** A missing selected file causes no directory creation,
  fallback search, parsing, or EventKit access and returns actionable guidance.
- [x] **CFG-P03-AC4:** Unreadable, non-UTF-8, and structurally invalid files
  produce privacy-safe invalid results.
- [x] **CFG-P03-AC5:** Every provider call re-reads the selected path; missing or
  invalid replacements never return cached valid settings.
- [x] **CFG-P03-V1:**
  `swift run CalRelayKitTests ConfigurationFileSelectionTests` passes.
- [x] **CFG-P03-V2:**
  `swift run CalRelayKitTests FileCalendarRelaySettingsProviderTests` passes.

### CFG-P04 — Verify runtime readiness and migration gates

**Dependencies:** `CFG-P02`, `CFG-P03`.

**Likely production targets, only if tests expose a defect:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAccessPreflightUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigCheckCommandHandler.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandler.swift`

- [x] **CFG-P04:** Runtime readiness and migration-pending behavior is verified.
- [x] **CFG-P04-AC1:** Runtime resolution uses exact source/title matching and
  rejects zero matches, multiple matches, and duplicate physical-calendar
  resolution.
- [x] **CFG-P04-AC2:** Provider identifiers are never configuration selectors or
  selector fallbacks.
- [x] **CFG-P04-AC3:** Nonempty `legacyMarkers` blocks ordinary CLI dry-run,
  apply, explanation, manual app workflows, standing authorization, and
  scheduling before event reads or mutation.
- [x] **CFG-P04-AC4:** Config check still runs ordinary preflight, aggregates safe
  failures, reports migration pending, returns failure, and never claims
  readiness.
- [x] **CFG-P04-AC5:** CLI and app paths remain non-prompting outside the explicit
  app setup or recovery action.
- [x] **CFG-P04-V1:** `CalendarAccessPreflightTests`,
  `ConfigCheckCommandHandlerTests`, and `ReconcileCommandHandlerTests` pass.
- [x] **CFG-P04-V2:** `CalendarManualDryRunTests`,
  `CalendarStandingAuthorizationTests`, `CalendarAutomaticReconciliationTests`,
  and `CalendarNoPromptContractTests` pass.

### CFG-P05 — Verify bounded legacy cleanup

**Dependencies:** `CFG-P02`, `CFG-P04`.

**Likely production targets, only if tests expose a defect:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/LegacyCleanupWindow.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarCleanupPlan.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarCleanupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualCleanupUseCase.swift`

- [x] **CFG-P05:** Bounded cleanup behavior and verification is established.
- [x] **CFG-P05-AC1:** One captured calendar context produces the moving
  half-open `D - 2` through `D + 366` boundary across daylight-saving
  transitions.
- [x] **CFG-P05-AC2:** Positive-overlap membership retains complete event
  intervals.
- [x] **CFG-P05-AC3:** Cleanup searches every configured role and selects only
  events with exact parsed legacy markers.
- [x] **CFG-P05-AC4:** Cleanup produces deletions only and never performs ordinary
  creates, routing, or current-marker reconciliation.
- [x] **CFG-P05-AC5:** Apply re-reads the full topology and range after deletion
  and fails if verification reads fail or exact matches remain.
- [x] **CFG-P05-AC6:** Confirmed deletions remain applied after partial failure;
  no rollback or automatic retry is introduced.
- [x] **CFG-P05-AC7:** CLI and app success messages remain explicitly local and
  point-in-time.
- [x] **CFG-P05-V1:** `CalendarCleanupAccessTests` and
  `ReconcileCommandHandlerTests` pass.
- [x] **CFG-P05-V2:** `CalendarManualCleanupTests`,
  `CalendarManualCleanupReviewTests`, and `CalendarManualCleanupFailureTests`
  pass.
- [x] **CFG-P05-V3:** `EventKitExactEventOccurrenceResolverTests` passes.

### CFG-P06 — Verify fresh app loading, observation, and mutation races

**Dependencies:** `CFG-P03`, `CFG-P04`, `CFG-P05`.

**Likely production targets, only if tests expose a defect:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/ConfigurationFileObserver.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarControlPanelStatusUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualApplyUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualCleanupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomaticReconciliationUseCase.swift`

- [x] **CFG-P06:** Fresh app loading, observation, and race behavior is verified.
- [x] **CFG-P06-AC1:** Every status refresh and ordinary or cleanup run loads
  fresh settings.
- [x] **CFG-P06-AC2:** Missing, invalid, or migration-pending replacements
  suppress mutation without a last-known-valid fallback.
- [x] **CFG-P06-AC3:** Creation, editing, atomic replacement, and removal trigger
  status invalidation.
- [x] **CFG-P06-AC4:** Observation remains an invalidation signal and does not
  replace per-run loading.
- [x] **CFG-P06-AC5:** Changes during an operation coalesce into one follow-up
  refresh rather than interrupting possible partial mutation.
- [x] **CFG-P06-AC6:** A configuration identity change immediately before first
  mutation aborts without mutation.
- [x] **CFG-P06-AC7:** An observed A-to-B-to-A transition cannot silently
  reactivate an earlier authorization.
- [x] **CFG-P06-V1:** `CalendarConfigurationObservationTests` and
  `CalendarControlPanelStatusTests` pass.
- [x] **CFG-P06-V2:** `CalendarManualApplyTests` and
  `CalendarManualApplySafetyTests` pass.
- [x] **CFG-P06-V3:** Relevant manual-cleanup and automatic-reconciliation suites
  pass.

### CFG-P07 — Verify configuration, policy, topology, and privacy identities

**Dependencies:** `CFG-P04`, `CFG-P06`.

**Likely production targets, only if tests expose a defect:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/OrdinaryConfigurationMutationIdentity.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarStandingAuthorizationBinding.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarStandingAuthorizationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/Persistence/UserDefaultsCalendarAutomationStateStore.swift`

- [x] **CFG-P07:** Configuration, policy, topology, and privacy identities are
  verified.
- [x] **CFG-P07-AC1:** Representation-only YAML differences, diagnostic
  work-role names, and legacy-marker order do not change configuration identity.
- [x] **CFG-P07-AC2:** Every mutation-relevant value and work declaration-order
  change produces a different binding.
- [x] **CFG-P07-AC3:** Current policy is explicitly
  `ordinary-reconciliation-policy-v2`; policy changes alter the binding while
  presentation-only changes do not.
- [x] **CFG-P07-AC4:** Policy-v2 tests cover the later routing correction that
  preserves personal-marked and other non-local valid marked hub events.
- [x] **CFG-P07-AC5:** Topology identity follows hub then declaration-ordered work
  roles and changes on physical identity replacement or unprovable continuity.
- [x] **CFG-P07-AC6:** Stored and displayed representations expose no raw YAML,
  marker, selector, calendar title, event title, or raw EventKit identifier.
- [x] **CFG-P07-AC7:** Returning to a prior configuration, policy, or topology
  does not reactivate revoked standing authorization.
- [x] **CFG-P07-V1:** `CalendarConfigurationIdentityTests` passes.
- [x] **CFG-P07-V2:** `CalendarAutomationPersistenceTests`,
  `CalendarStandingAuthorizationTests`, and `CalendarAutomaticReconciliationTests`
  pass.
- [x] **CFG-P07-V3:** `CalendarAccessPrivacyTests` and
  `RoutingSpecificationTests` pass.

### CFG-P08 — Verify migration documentation

**Dependencies:** `CFG-P01`. This task may run in parallel with `CFG-P04` through
`CFG-P07` because its write boundary is limited to `docs/configuration.md`.

**Likely target, only if current guidance is incomplete or stale:**

- `docs/configuration.md`

- [x] **CFG-P08:** Migration and retired-marker documentation is verified.
- [x] **CFG-P08-AC1:** Documentation requires retiring a tombstoned marker from
  every active configuration sharing the hub.
- [x] **CFG-P08-AC2:** Removed calendars and malformed or non-exact historical
  artifacts are explicitly manual responsibilities.
- [x] **CFG-P08-AC3:** Cleanup is documented as exact-only, bounded, local,
  point-in-time, and potentially repeatable.
- [x] **CFG-P08-AC4:** Dormant writers must adopt the current topology and pass
  readiness before reconnecting.
- [x] **CFG-P08-AC5:** Recurring series capable of producing later occurrences
  require manual handling.
- [x] **CFG-P08-AC6:** Marker reuse requires manual global artifact verification
  and prevention of stale republishing.
- [x] **CFG-P08-V1:** Referenced paths and commands exist and match current CLI
  behavior.
- [x] **CFG-P08-V2:** Documentation changes, if any, pass
  `git --no-pager diff HEAD --check`.

### CFG-P09 — Integrate and complete repository validation

**Dependencies:** `CFG-P02` through `CFG-P08`.

- [x] **CFG-P09:** Configuration specification verification is complete.
- [x] **CFG-P09-AC1:** Every `CONFIG-AC-01` through `CONFIG-AC-18` has current
  evidence.
- [x] **CFG-P09-AC2:** Domain and application code remain independent of `Yams`,
  filesystem path resolution, and live EventKit mechanics.
- [x] **CFG-P09-AC3:** No accepted schema, dependency, public command contract,
  or unrelated behavior changed without explicit need.
- [x] **CFG-P09-AC4:** All new suites, if any, have `runAll()` and are registered
  in the custom runner.
- [x] **CFG-P09-AC5:** Final handoff distinguishes automated evidence from any
  optional manual EventKit observations.
- [x] **CFG-P09-V1:** `make format-check` passes.
- [x] **CFG-P09-V2:** `make check` passes.
- [x] **CFG-P09-V3:** `make app` passes if app sources, app resources, or bundle
  tooling changed; not applicable because no app source, app resource, or bundle
  tooling changed.
- [x] **CFG-P09-V4:** `make ui-test` passes if app presentation, accessibility
  contracts, fake UI composition, or the UI-test harness changed; not applicable
  because none of those surfaces changed.
- [x] **CFG-P09-V5:** `git --no-pager diff HEAD --check` passes.
- [x] **CFG-P09-V6:** Final `git --no-pager status --short --branch` preserves
  unrelated work and leaves agent changes unstaged.

## Focused validation commands

Run the narrow suites while executing their owning tasks:

```sh
swift run CalRelayKitTests CalendarConfigurationSchemaTests
swift run CalRelayKitTests CalRelayContractTests
swift run CalRelayKitTests ConfigurationFileSelectionTests
swift run CalRelayKitTests FileCalendarRelaySettingsProviderTests
swift run CalRelayKitTests CalendarAccessPreflightTests
swift run CalRelayKitTests ConfigCheckCommandHandlerTests
swift run CalRelayKitTests ReconcileCommandHandlerTests
swift run CalRelayKitTests CalendarManualDryRunTests
swift run CalRelayKitTests CalendarCleanupAccessTests
swift run CalRelayKitTests CalendarManualCleanupTests
swift run CalRelayKitTests CalendarManualCleanupReviewTests
swift run CalRelayKitTests CalendarManualCleanupFailureTests
swift run CalRelayKitTests CalendarConfigurationObservationTests
swift run CalRelayKitTests CalendarControlPanelStatusTests
swift run CalRelayKitTests CalendarManualApplyTests
swift run CalRelayKitTests CalendarManualApplySafetyTests
swift run CalRelayKitTests CalendarConfigurationIdentityTests
swift run CalRelayKitTests CalendarAutomationPersistenceTests
swift run CalRelayKitTests CalendarStandingAuthorizationTests
swift run CalRelayKitTests CalendarAutomaticReconciliationTests
swift run CalRelayKitTests CalendarAccessPrivacyTests
swift run CalRelayKitTests CalendarNoPromptContractTests
swift run CalRelayKitTests EventKitExactEventOccurrenceResolverTests
swift run CalRelayKitTests RoutingSpecificationTests
```

Final validation:

```sh
make format-check
make check
git --no-pager diff HEAD --check
git --no-pager status --short --branch
```

Run `make app` only when app sources, `Resources/CalRelayApp/`, or app-bundle
tooling changes. Run `make ui-test` only when app presentation, accessibility
contracts, fake UI composition, or the UI-test harness changes. Do not substitute
`swift test`; this repository uses the `CalRelayKitTests` executable runner. Do
not use real EventKit as an ordinary automated check.

## Risks and mitigations

- **Stale historical evidence:** The prior plan was complete before later
  shared-core changes. Mitigation: require current-HEAD focused and complete
  checks.
- **Duplicate implementation:** Most required behavior already exists.
  Mitigation: make no production edit without a failing acceptance-oriented
  test.
- **Cross-slice scope creep:** Configuration behavior touches access,
  reconciliation, CLI, app, and persistence. Mitigation: change adjacent slices
  only when a configuration acceptance check demonstrates a defect.
- **Policy-version drift:** Reconciliation behavior changed after the predecessor
  plan. Mitigation: include policy-v2 identity and routing suites explicitly.
- **Privacy regression:** Diagnostics or persistence could expose sensitive
  configuration or EventKit values. Mitigation: preserve sentinel-based negative
  assertions and opaque binding representations.
- **File-observer timing instability:** Filesystem observation tests include
  asynchronous delivery. Mitigation: keep temporary isolated fixtures, bounded
  waiting, and no shared developer state.
- **Live calendar damage:** Configuration readiness and cleanup interact with
  EventKit. Mitigation: keep the automated gate fake-backed; use dedicated
  harmless calendars only for separately authorized manual validation.

## Next executable work

No automated configuration-specification implementation work remains. Optional
manual EventKit observations may be performed separately with harmless dedicated
calendars, but they are not part of the deterministic conformance gate.