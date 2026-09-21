# Configuration Specification Test Plan

## Plan record

- **Requirements basis:** [`../specs/configuration-spec.md`](../specs/configuration-spec.md), revision 8, accepted September 17, 2026.
- **Related accepted contracts:** [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md), [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md), [`../specs/routing-spec.md`](../specs/routing-spec.md), [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md), [`../specs/cli-spec.md`](../specs/cli-spec.md), and [`../specs/macos-app-spec.md`](../specs/macos-app-spec.md).
- **Readiness:** Ready. The required outcomes, test boundaries, expected evidence, sequencing, and validation commands are specific enough to execute without an unresolved product decision.
- **Progress date:** September 21, 2026.
- **Implementation state:** In progress. `CFG-P01` and `CFG-P02` are complete with focused schema, path-selection, and fresh file-provider coverage plus full repository validation; `CFG-P03` is the next executable slice.
- **Execution approach:** Add focused deterministic contract evidence for uncovered behavior, preserve useful existing suites, fix only defects exposed by specification-derived tests, then run the complete repository gate.

## Outcome

Produce durable, deterministic evidence that CalRelay conforms to Configuration Specification revision 8 across strict YAML loading, marker and selector validation, path discovery, migration gating, bounded legacy cleanup, fresh app loading, semantic authorization identities, topology and policy invalidation, persistence privacy, and operator-facing migration documentation.

The completed test work must make every `CONFIG-AC-01` through `CONFIG-AC-18` acceptance check traceable to executable evidence or, where the contract explicitly describes an operator-managed prerequisite that CalRelay cannot prove, to a focused documentation review.

## Scope

### In scope

- Strict `Yams`-backed schema and type validation for the accepted YAML document.
- Marker grammar, case-sensitive identity, pairwise uniqueness, and selector-role collision validation.
- Canonical and explicit configuration-path selection, missing-file behavior, and fresh file-provider loading.
- Runtime exact selector resolution and physical-calendar collision rejection through fake-backed preflight tests.
- Migration-pending gates across config check, ordinary manual operations, and scheduled reconciliation.
- Bounded legacy cleanup range, exact matching, positive-overlap membership, post-delete verification, and local point-in-time claims.
- App configuration observation, fresh-load behavior, pre-mutation race protection, and no last-known-valid fallback.
- Configuration, reconciliation-policy, and resolved-topology authorization identities, including privacy-safe persistence.
- Migration and marker-reuse documentation requirements that are intentionally outside runtime verification authority.
- Custom executable test-runner registration, focused checks, and the complete repository validation gate.

### Out of scope

- Changing the accepted YAML schema, marker grammar, cleanup range, selector semantics, routing behavior, or mutation authority.
- Adding EventKit-ID selectors or automatic ID fallback. The open selector-stability question remains a future product decision.
- Adding profiles, environment-variable overrides, remembered alternate app paths, directory search, or configuration editing.
- Adding a global marker registry, global artifact scanner, whole-series deletion, or automatic proof of marker retirement.
- Reorganizing unrelated tests or production code merely to centralize configuration coverage.
- Real EventKit access or real calendar mutation in the default automated test lane.
- Migrating the repository away from its custom SwiftPM executable test runner.

## Constraints and invariants

- Product behavior remains owned by the accepted specifications; tests must not redefine those contracts from current implementation behavior.
- Use `swift run CalRelayKitTests <ExactRegisteredSuiteName>` for focused execution and `make test` or `make check` for the complete deterministic runner. Do not substitute `swift test`, XCTest, or Swift Testing.
- New suites must expose `runAll()` and be registered in `Tests/CalRelayKitTests/Main.swift`.
- Default tests remain fast, deterministic, isolated, offline, fake-backed, and independent of EventKit, Calendar permission, real calendars, wall-clock time, and shared user configuration.
- Filesystem tests use isolated temporary directories and remove them after each scenario.
- Seed fixtures with safe placeholder data. Privacy tests may use deliberately distinctive synthetic values but must not contain real calendar names, event titles, identifiers, or credentials.
- Assert typed results and observable boundary effects where possible. Assert diagnostic text only when actionable wording, stream routing, or prohibited disclosure is part of the contract.
- Use call counters or fakes to prove structural and migration failures occur before calendar-store access or mutation.
- Do not assert Yams implementation-specific error wording; assert CalRelay's normalized safe failure contract.
- If a new specification-derived test fails against production code, preserve the failing regression test, make the smallest conforming implementation change, and rerun focused and complete validation.
- If implementation and the accepted specification conflict in a way that requires a product decision, stop the affected task and obtain explicit approval rather than weakening the test.

## Test strategy

### Test levels

1. **Pure validation and loader contracts:** Direct tests of YAML decoding, DTO defaults, `SettingsValidator`, and semantic authorization binding behavior.
2. **Adapter contracts:** Temporary-filesystem tests of path selection, file loading, repeated reads, disappearance, replacement, and privacy-safe failures.
3. **Application integration contracts:** Fake-backed access preflight, manual, cleanup, automatic, observation, and authorization tests proving ordering and no-mutation gates.
4. **Process smoke contracts:** Existing executable-process tests for config-check exit status, stdout/stderr behavior, migration pending, and invalid configuration.
5. **Documentation checks:** Semantic inspection of operator obligations that runtime code cannot prove, followed by repository path and diff validation.

### Test naming and structure

- Name tests by observable behavior, not by implementation method.
- Keep arrange, act, and assert phases visually clear.
- A test may contain multiple assertions only when they prove one behavioral concept.
- Prefer table-driven loops for marker grammar, YAML type boundaries, and identity mutation matrices when failures still identify the individual case.
- Avoid duplicating the production parser or planner in test helpers. Fixtures should describe inputs and expected externally observable outcomes.

### Current coverage baseline

The following suites already contain relevant evidence and should be extended rather than replaced when their ownership remains clear:

- `CalRelayContractTests`: DTO validation, canonical YAML, defaults, safe errors, unknown keys, duplicate keys, and baseline selector failures.
- `ConfigurationFileSelectionTests`: default, absolute, relative, tilde, unsupported expansion, and missing-file diagnostics.
- `ConfigCheckCommandHandlerTests` and `CalRelayCLISmokeTests`: readiness, invalid configuration, migration-pending process behavior, and no mutation.
- `CalendarAccessPreflightTests`: missing, ambiguous, colliding, unreadable, read-only, and ordered runtime topology behavior.
- `CalendarCleanupAccessTests` and manual-cleanup suites: cleanup range, exact tombstones, application, verification, and partial failures.
- `CalendarConfigurationObservationTests`: creation, edit, atomic replacement, removal, refresh coalescing, and review invalidation.
- `CalendarAutomationPersistenceTests`, `CalendarStandingAuthorizationTests`, and `CalendarAutomaticReconciliationTests`: opaque binding, persistence privacy, configuration/policy/topology invalidation, and automatic no-mutation gates.
- `CalendarManualApplyTests`: fresh review, pre-mutation configuration checks, exact action identity, and consumed confirmation.

This baseline is based on source inspection only. A checkbox remains open until the planned focused or complete validation produces current evidence.

## Acceptance-check traceability

| Specification check | Planned evidence |
| --- | --- |
| `CONFIG-AC-01` | `CFG-P01-AC1` proves accepted keys, nesting, defaults, unknown-key rejection, duplicate-key rejection, and private error output. |
| `CONFIG-AC-02` | `CFG-P01-AC2` proves complete marker grammar, case sensitivity, and all personal/current/legacy duplicate relationships. |
| `CONFIG-AC-03` | `CFG-P01-AC3` proves the omitted default, accepted boundaries, and rejected value/type boundaries before calendar access. |
| `CONFIG-AC-04` | `CFG-P01-AC4` proves exact hub/work and work/work selector collisions identify all roles while distinct tuples reach runtime preflight. |
| `CONFIG-AC-05` | `CFG-P02-AC1` proves canonical, absolute, relative, supported tilde, and unsupported expansion behavior. |
| `CONFIG-AC-06` | `CFG-P02-AC2` proves missing-file precedence, actionable guidance, no creation or directory search, and no calendar access. |
| `CONFIG-AC-07` | `CFG-P03-AC1` proves zero-match, multi-match, and physical-collision rejection without ID fallback. |
| `CONFIG-AC-08` | `CFG-P03-AC2` and `CFG-P03-AC3` prove ordinary and scheduled gates plus migration-pending config-check behavior. |
| `CONFIG-AC-09` | `CFG-P04-AC1` and `CFG-P04-AC2` prove one captured moving range, positive overlap, topology coverage, and exact tombstone matching. |
| `CONFIG-AC-10` | `CFG-P04-AC3` and `CFG-P04-AC4` prove complete verification and bounded local claims. |
| `CONFIG-AC-11` | `CFG-P08-AC1` proves deterministic architecture and test isolation boundaries. |
| `CONFIG-AC-12` | `CFG-P02-AC3`, `CFG-P05-AC1`, and `CFG-P05-AC2` prove fresh selected-file loading and no cached fallback. |
| `CONFIG-AC-13` | `CFG-P06-AC1`, `CFG-P06-AC2`, and `CFG-P06-AC5` prove semantic identity, observed invalidation, and persistence privacy. |
| `CONFIG-AC-14` | `CFG-P05-AC3` proves pre-mutation abort and no silent A-to-B-to-A reactivation. |
| `CONFIG-AC-15` | `CFG-P07-AC1` proves the required active-topology, removed-calendar, historical-artifact, and no-fuzzy-cleanup documentation. |
| `CONFIG-AC-16` | `CFG-P06-AC3` proves policy-version binding and establishes a maintenance checkpoint for mutation-semantic changes. |
| `CONFIG-AC-17` | `CFG-P06-AC4` and `CFG-P06-AC5` prove ordered physical topology binding, invalidation, and raw-ID nondisclosure. |
| `CONFIG-AC-18` | `CFG-P07-AC2` proves dormant-writer, recurring-series, global-verification, reuse, and stale-republication documentation. |

## Detailed work plan

### - [ ] CFG-P01 — Complete strict schema, marker, window, and structural selector tests

Add focused loader and validation coverage without duplicating parser logic. Prefer a dedicated `CalendarConfigurationSchemaTests` suite when the added matrix would make `CalRelayContractTests` harder to navigate; otherwise keep tightly related baseline tests in the existing suite.

**Dependencies:** None.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalRelayContractTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarCleanupAccessTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarConfigurationSchemaTests.swift` if a focused suite is warranted
- `Tests/CalRelayKitTests/Main.swift` if a suite is added
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/YAMLCalendarRelaySettingsLoader.swift` only if a failing test exposes a defect
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarRelaySettings.swift` only if a failing test exposes a defect

**Scenario matrix:**

- Parse the normative example into the exact DTO and preserve work-calendar and legacy-marker declaration order.
- Default omitted `syncWindowDays` to `100` and omitted `legacyMarkers` to an empty sequence.
- Accept comments, equivalent scalar quoting, mapping-key reordering, and supported unambiguous Yams flow syntax.
- Reject non-mapping roots, malformed YAML, missing required fields, wrong field types, empty work lists, and missing nested selector fields.
- Reject unknown and duplicate keys independently at the root, hub selector, work entry, and work selector levels.
- Seed prohibited synthetic values into invalid input and prove normalized errors do not echo them.

#### - [ ] CFG-P01-AC1 — Prove the exact schema and privacy-safe structural failures

Tests accept only the documented fields and nesting, apply both optional defaults, preserve ordered sequences, accept representation-only YAML variants, and reject every unknown, duplicate, missing, malformed, or wrong-type structure without echoing raw YAML or seeded private values.

#### - [ ] CFG-P01-AC2 — Prove complete marker grammar and pairwise uniqueness

Tests accept representative values matching `\[[A-Za-z0-9_-]+\]`, treat `[ACME]` and `[acme]` as distinct, reject empty, partial, embedded, whitespace-bearing, punctuation-bearing, multi-marker, and non-ASCII forms, and cover personal/work, work/work, personal/legacy, work/legacy, and legacy/legacy duplicates.

#### - [ ] CFG-P01-AC3 — Prove `syncWindowDays` defaults, boundaries, and types

Tests accept omission as `100`, accept `1` and `365`, and reject zero, negative integers, `366`, fractional numbers, strings, booleans, and null before calendar-store access.

#### - [ ] CFG-P01-AC4 — Prove structural selector collision diagnostics

Tests reject exact hub/work and work/work source-title/calendar-title tuple collisions, identify all conflicting roles and declaration indexes, keep case-different tuples structurally distinct, and allow distinct tuples to proceed to runtime preflight.

#### - [ ] CFG-P01-V1 — Pass focused schema and validation suites

Run the exact registered schema-related suite names and record a pass only after the new tests have executed successfully through `CalRelayKitTests`.

### - [ ] CFG-P02 — Complete configuration selection and fresh file-provider tests

Separate path-resolution mechanics from selected-file loading. Add provider-level evidence for missing, unreadable, invalid, replaced, and repeatedly loaded files without relying on process-global home or working-directory state.

**Dependencies:** `CFG-P01`, because provider tests consume the accepted loader behavior and safe error boundary.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigurationFileSelectionTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/Config/FileCalendarRelaySettingsProviderTests.swift`
- `Tests/CalRelayKitTests/Main.swift` if a provider suite is added
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigurationFileSelection.swift` only if a failing test exposes a defect
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/FileCalendarRelaySettingsProvider.swift` only if a failing test exposes a defect

**Scenario matrix:**

- Default selection below an injected home directory.
- Absolute paths preserved, relative paths resolved against an injected working directory, and only exact `~` or leading `~/` expanded.
- `~otheruser`, `$HOME`, and embedded tildes remain literal relative-path content.
- Missing default and explicit files produce source-appropriate actionable guidance.
- Missing files and parent directories are not created, no alternate directories are searched, and calendar access is not attempted.
- Unreadable, non-UTF-8, and structurally invalid files become privacy-safe invalid-provider results.
- Repeated calls reread the selected path; valid-to-missing, valid-to-invalid, and valid-to-migration-pending transitions never return previous settings.

#### - [ ] CFG-P02-AC1 — Prove canonical and explicit path semantics

Tests cover the default path, absolute and relative overrides, supported current-user tilde expansion, and literal handling of unsupported expansion forms with stable display paths.

#### - [ ] CFG-P02-AC2 — Prove missing and invalid file precedence without side effects

Tests show that missing, unreadable, and invalid selected files fail before parsing-dependent use-case work or calendar access, provide the required guidance without raw content, create nothing, and search nowhere else.

#### - [ ] CFG-P02-AC3 — Prove every provider call loads the selected file afresh

Tests change or remove the selected file between calls and prove the provider returns the current missing, invalid, valid, or migration-pending result rather than any cached last-known-valid settings.

#### - [ ] CFG-P02-V1 — Pass focused path and file-provider suites

Run `ConfigurationFileSelectionTests` and the exact registered provider-suite name, then record current passing evidence.

### - [ ] CFG-P03 — Complete runtime readiness and migration-pending gates

Use fake authorization and calendar-store ports to prove that structural success is not runtime readiness and that migration pending has intentionally different behavior for ordinary operations and config check.

**Dependencies:** `CFG-P01` and `CFG-P02`.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAccessPreflightTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualDryRunTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomaticReconciliationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigCheckCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/CalRelayCLISmokeTests.swift`

#### - [ ] CFG-P03-AC1 — Prove exact runtime selector resolution without ID fallback

Tests reject zero matches, multiple exact matches even when one is writable, unreadable or read-only roles, and two roles resolving to one physical calendar; a complete exact-match topology returns an ordered hub-then-declaration-ordered-work snapshot without mutation or EventKit-ID fallback.

#### - [ ] CFG-P03-AC2 — Prove migration pending blocks every ordinary mutation path

Nonempty `legacyMarkers` block ordinary dry-run, apply, explanation, standing-authorization grant, and automatic scheduling after structural validation but before calendar event access or mutation, direct the operator to explicit cleanup, and never edit YAML.

#### - [ ] CFG-P03-AC3 — Prove config check still preflights but never claims readiness

Migration-pending config check performs ordinary topology preflight, aggregates safely determinable access failures, returns a nonzero process result, reports migration pending, makes no readiness claim, and performs no mutation.

#### - [ ] CFG-P03-V1 — Pass focused readiness, migration, and process suites

Run the relevant access, manual, automatic, command-handler, and CLI smoke suites and record current passing evidence.

### - [ ] CFG-P04 — Complete bounded cleanup coverage and verification tests

Strengthen boundary evidence around the one captured run context, positive-overlap membership, exact tombstone ownership, complete topology reads, and post-delete verification without expanding cleanup authority.

**Dependencies:** `CFG-P01` and `CFG-P03`.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarCleanupAccessTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupSnapshotTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupFailureTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupReviewTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/CalRelayCLISmokeTests.swift`

**Boundary matrix:**

- Start at local midnight `D - 2` and end at local midnight `D + 366` using one captured reference instant, calendar, and time zone.
- Cover spring-forward and fall-back daylight-saving transitions.
- Exclude an event ending exactly at the range start and one starting exactly at the range end.
- Include events that positively overlap either boundary and retain their complete returned intervals.
- Search hub first and then all configured work calendars in declaration order.
- Select exact parsed legacy markers only; exclude current markers, raw starts-with forms, malformed separators, malformed brackets, empty marked titles, and unmarked events.

#### - [ ] CFG-P04-AC1 — Prove the moving cleanup range and positive-overlap membership

Tests calculate `D - 2` through `D + 365` inclusive from one captured local context, handle both daylight-saving directions, exercise exact-touch exclusion and positive-overlap inclusion, and retain complete event intervals.

#### - [ ] CFG-P04-AC2 — Prove cleanup-only exact marker selection over the complete topology

Tests read every configured role in topology order and select only exact legacy-marker events, with no ordinary creates, current-marker deletes, fuzzy matching, malformed-shape deletion, or unconfigured-calendar claim.

#### - [ ] CFG-P04-AC3 — Prove complete post-delete verification and no rollback

Cleanup apply rereads the full range and topology after planned deletions, succeeds only on a no-match snapshot, fails on a remaining match or verification read error, preserves confirmed deletions, stops later mutation on failure, and does not roll back.

#### - [ ] CFG-P04-AC4 — Prove truthful local point-in-time cleanup claims

CLI and app success output state the bounded local point-in-time result and do not claim global retirement, historical coverage, removed-calendar coverage, recurring-series retirement, or protection against later recreation.

#### - [ ] CFG-P04-V1 — Pass focused cleanup contract and process suites

Run the cleanup access, manual cleanup, command-handler, and CLI smoke suites and record current passing evidence.

### - [ ] CFG-P05 — Complete app fresh-loading and configuration-race tests

Prove that observation only invalidates state, every status or run performs its own fresh load, and a selected-file change before the first mutation cannot reuse an earlier authorization even when the file later returns to an old identity.

**Dependencies:** `CFG-P02`, `CFG-P03`, and `CFG-P04`.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarConfigurationObservationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarControlPanelStatusTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualDryRunTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualApplyTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualApplySafetyTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomaticReconciliationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarStandingAuthorizationTests.swift`

#### - [ ] CFG-P05-AC1 — Prove status and every app operation load fresh settings

Provider call-count and scripted-result tests prove configuration status, manual dry-run, manual apply review and confirmation, cleanup review and confirmation, standing-authorization review, and automatic attempts load and validate the current selected-file result without a cached fallback.

#### - [ ] CFG-P05-AC2 — Prove file observation is invalidation-only and safely coalesced

Creation, in-place edit, atomic replacement, and removal prompt refresh; observation carries no settings payload; open reviews are invalidated; changes during an active operation coalesce into one fresh follow-up refresh rather than interrupting the active mutation.

#### - [ ] CFG-P05-AC3 — Prove pre-mutation changes and A-to-B-to-A transitions cannot reuse authorization

Scripted valid-A to changed-B, missing, invalid, or migration-pending transitions abort before the first mutation and consume the confirmation; restoring A after B does not reactivate an earlier standing grant until a new successful review and renewal.

#### - [ ] CFG-P05-V1 — Pass focused observation, status, manual, and automatic suites

Run the exact affected suites and record current evidence that every configuration race suppresses mutation.

### - [ ] CFG-P06 — Complete semantic identity, policy, topology, and privacy tests

Add a focused identity matrix through the public opaque standing-authorization binding. Do not expose or persist internal semantic components merely to make them easier to test.

**Dependencies:** `CFG-P01`, `CFG-P03`, and `CFG-P05`.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarConfigurationIdentityTests.swift` if a focused suite is warranted
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomationPersistenceTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarStandingAuthorizationTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomaticReconciliationTests.swift`
- `Tests/CalRelayKitTests/Main.swift` if a suite is added
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/OrdinaryConfigurationMutationIdentity.swift` only if a failing test exposes a defect
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarStandingAuthorizationBinding.swift` only if a failing test exposes a defect

**Identity matrix:**

- Equivalent identity: comments, scalar quoting, mapping-key order, omitted versus explicit default `syncWindowDays`, diagnostic work-role names, and reordered legacy markers with the same set.
- Changed identity: hub source or title, personal marker, effective window, work source or title, work marker, work declaration order, work-role addition/removal, and legacy-marker set addition/removal.
- Changed topology: any physical calendar identity, role-to-calendar mapping, role order, or unprovable continuity.
- Changed policy: any product-controlled version representing changed executable actions, exact targets, or order for identical configuration and snapshot inputs.

#### - [ ] CFG-P06-AC1 — Prove representation-only equivalence and diagnostic-name insensitivity

Equivalent YAML representations, omitted versus explicit defaults, diagnostic work-role renames, and legacy-marker set reordering derive the same opaque binding when policy and resolved topology are unchanged.

#### - [ ] CFG-P06-AC2 — Prove every mutation-relevant configuration change alters identity

One-at-a-time changes to every mutation-relevant value, including work declaration order and legacy-marker set membership, derive a different binding and require fresh authorization.

#### - [ ] CFG-P06-AC3 — Prove reconciliation-policy version binding and maintenance rules

Tests show a policy-version change invalidates prior authorization while presentation-only changes do not. The test or adjacent maintenance note couples the current policy identifier to representative executable targets and order so mutation-semantic changes require an explicit version review.

#### - [ ] CFG-P06-AC4 — Prove ordered resolved-topology identity and continuity invalidation

Tests bind the hub and declaration-ordered work roles to physical calendar identities, reject swapped or changed mappings and unproven continuity, and never use those identities as configuration selectors or visible ownership markers.

#### - [ ] CFG-P06-AC5 — Prove opaque persistence and output reveal no prohibited inputs

Round-trip persistence, descriptions, debug descriptions, status, and failure output contain none of the seeded raw YAML, selectors, calendar titles, markers, diagnostic names, raw EventKit calendar IDs, or reversible identity components.

#### - [ ] CFG-P06-V1 — Pass focused identity, persistence, authorization, and automation suites

Run the exact affected suites and record current evidence for semantic equality, invalidation, privacy, and persistence behavior.

### - [ ] CFG-P07 — Verify migration and retired-marker documentation contracts

Review the project-facing configuration guide semantically rather than snapshotting whole paragraphs. Edit only if an accepted operator obligation is absent, ambiguous, or contradicted.

**Dependencies:** `CFG-P04`, because cleanup scope and wording must already be understood; this task may otherwise proceed in parallel with `CFG-P05` and `CFG-P06` if edits do not overlap.

**Likely target:**

- `docs/configuration.md`

#### - [ ] CFG-P07-AC1 — Verify active-topology retirement, removed-calendar handling, and exact-only cleanup guidance

Documentation requires retiring a tombstoned marker from every active configuration sharing the hub, manually handling removed calendars and non-exact historical artifacts, and never treating fuzzy, raw-prefix, or heuristic deletion as available.

#### - [ ] CFG-P07-AC2 — Verify dormant-writer, recurring-series, global-verification, and reuse guidance

Documentation requires dormant writers to adopt the current topology and pass readiness before reconnecting, manual removal of future-producing recurring series, global artifact verification before marker reuse, and prevention of stale republishing.

#### - [ ] CFG-P07-V1 — Validate documentation references and diff hygiene

Verify every referenced path and command, then run `git --no-pager diff HEAD --check`. Do not invent a Markdown formatter; none is configured.

### - [ ] CFG-P08 — Integrate suites and complete repository validation

Register any new suites, run focused evidence after each task, then execute the complete gate. Keep live EventKit validation outside this plan unless separately authorized with harmless dedicated calendars.

**Dependencies:** `CFG-P01` through `CFG-P07`.

**Likely targets:**

- `Tests/CalRelayKitTests/Main.swift`
- All source or test files changed by earlier tasks
- `docs/configuration.md` if `CFG-P07` required changes

#### - [ ] CFG-P08-AC1 — Preserve deterministic architecture and safety boundaries

Review changed APIs and imports to confirm domain and application code remain independent of Yams, filesystem path resolution, EventKit types, SwiftUI, and live OS services; all default tests remain isolated, offline, fake-backed, and non-mutating.

#### - [ ] CFG-P08-AC2 — Register and focus every new suite through the custom runner

Every new suite has `runAll()`, is registered in `Tests/CalRelayKitTests/Main.swift`, and can be selected by its exact registered name without preventing the unfiltered complete runner from executing it.

#### - [ ] CFG-P08-AC3 — Complete final traceability and handoff evidence

Every `CONFIG-AC-01` through `CONFIG-AC-18` row points to passing automated evidence or a completed documentation check, unresolved failures remain open, and the handoff records exact commands, results, limitations, and any specification conflict.

#### - [ ] CFG-P08-V1 — Pass `make format-check`

Run the repository formatting check and report warning-only diagnostics separately from failures.

#### - [ ] CFG-P08-V2 — Pass `make check`

Run linting, build, the complete deterministic executable test runner, and configured CLI help smoke checks through the canonical repository gate.

#### - [ ] CFG-P08-V3 — Pass final diff hygiene

Run `git --no-pager diff HEAD --check` after all edits and confirm agent-created changes remain unstaged unless an exact Git operation was requested.

#### - [ ] CFG-P08-V4 — Run conditional app validation when applicable

Run `make app` if app sources, app resources, or the app-bundle script changed. Run `make ui-test` only if app presentation, accessibility contracts, fake UI composition, or the UI-test harness changed. Otherwise record each command as not applicable with the reason rather than as a pass.

## Focused validation commands

Use only exact suite names registered in `Tests/CalRelayKitTests/Main.swift`. Expected focused commands include:

```sh
swift run CalRelayKitTests CalendarConfigurationSchemaTests
swift run CalRelayKitTests CalRelayContractTests
swift run CalRelayKitTests ConfigurationFileSelectionTests
swift run CalRelayKitTests FileCalendarRelaySettingsProviderTests
swift run CalRelayKitTests CalendarAccessPreflightTests
swift run CalRelayKitTests CalendarCleanupAccessTests
swift run CalRelayKitTests CalendarConfigurationObservationTests
swift run CalRelayKitTests CalendarConfigurationIdentityTests
swift run CalRelayKitTests CalendarAutomationPersistenceTests
swift run CalRelayKitTests CalendarStandingAuthorizationTests
swift run CalRelayKitTests CalendarAutomaticReconciliationTests
swift run CalRelayKitTests ConfigCheckCommandHandlerTests
swift run CalRelayKitTests CalRelayCLISmokeTests
```

`CalendarConfigurationSchemaTests`, `FileCalendarRelaySettingsProviderTests`, and `CalendarConfigurationIdentityTests` are proposed names, not currently registered commands. Use them only if those suites are created and registered; otherwise use the existing owning suite name.

## Final validation commands

For Swift source, tests, package, scripts, or tooling changes:

```sh
make format-check
make check
git --no-pager diff HEAD --check
```

For documentation-only execution of `CFG-P07` before any code or test edits:

```sh
git --no-pager diff HEAD --check
```

Conditional commands:

```sh
make app
make ui-test
```

Apply the conditions in `CFG-P08-V4`; do not run real EventKit or real-calendar mutation as an ordinary automated check.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Existing broad contract suites become harder to maintain as matrices expand. | Add a focused suite only when it creates a clear ownership boundary; do not move unrelated tests. |
| Tests accidentally encode Yams diagnostics or current implementation details. | Assert CalRelay's normalized error category, privacy behavior, and boundary effects rather than dependency wording or private helpers. |
| Filesystem tests become machine-dependent or leak temporary files. | Inject home/current directories where supported, use unique temporary roots, and clean them with `defer`. |
| Identity tests expose sensitive internal components to gain test access. | Test through opaque public bindings and persistence; do not make semantic identity components public or displayable. |
| Policy-version coverage gives false confidence about future semantic changes. | Keep an explicit maintenance checkpoint tied to representative executable actions, targets, and order; require review whenever reconciliation semantics change. |
| App freshness tests confuse observation with authoritative settings. | Use observation only to trigger invalidation and separately assert that every operation calls the provider again. |
| Cleanup tests overstate global or historical authority. | Assert bounded ranges, exact markers, configured topology only, and explicit local point-in-time wording. |
| A test reveals a contract/implementation disagreement requiring a product decision. | Leave the affected checkbox open, document the conflict, and obtain explicit approval before changing the accepted specification or weakening evidence. |

## Unresolved decisions and assumptions

- **No blocking decision:** Revision 8 is accepted and supplies executable acceptance checks.
- **Future selector decision:** Whether source/title selectors should later be supplemented by explicit EventKit-ID selectors is outside this plan. Automatic ID fallback remains prohibited.
- **Working assumption:** Focused new suites will be created only when their test matrix is materially clearer than extending an existing owner. This is a test-organization choice, not a product behavior decision.
- **Working assumption:** No app presentation or UI-test harness change is expected. If implementation work crosses that boundary, `CFG-P08-V4` becomes applicable.

## Progress Tracking

### Schema and structural validation

- [x] CFG-P01 — Complete strict schema, marker, window, and structural selector tests
- [x] CFG-P01-AC1 — Prove the exact schema and privacy-safe structural failures
- [x] CFG-P01-AC2 — Prove complete marker grammar and pairwise uniqueness
- [x] CFG-P01-AC3 — Prove `syncWindowDays` defaults, boundaries, and types
- [x] CFG-P01-AC4 — Prove structural selector collision diagnostics
- [x] CFG-P01-V1 — Pass focused schema and validation suites

### Configuration selection and file provider

- [x] CFG-P02 — Complete configuration selection and fresh file-provider tests
- [x] CFG-P02-AC1 — Prove canonical and explicit path semantics
- [x] CFG-P02-AC2 — Prove missing and invalid file precedence without side effects
- [x] CFG-P02-AC3 — Prove every provider call loads the selected file afresh
- [x] CFG-P02-V1 — Pass focused path and file-provider suites

### Runtime readiness and migration

- [ ] CFG-P03 — Complete runtime readiness and migration-pending gates
- [ ] CFG-P03-AC1 — Prove exact runtime selector resolution without ID fallback
- [ ] CFG-P03-AC2 — Prove migration pending blocks every ordinary mutation path
- [ ] CFG-P03-AC3 — Prove config check still preflights but never claims readiness
- [ ] CFG-P03-V1 — Pass focused readiness, migration, and process suites

### Legacy cleanup

- [ ] CFG-P04 — Complete bounded cleanup coverage and verification tests
- [ ] CFG-P04-AC1 — Prove the moving cleanup range and positive-overlap membership
- [ ] CFG-P04-AC2 — Prove cleanup-only exact marker selection over the complete topology
- [ ] CFG-P04-AC3 — Prove complete post-delete verification and no rollback
- [ ] CFG-P04-AC4 — Prove truthful local point-in-time cleanup claims
- [ ] CFG-P04-V1 — Pass focused cleanup contract and process suites

### App freshness and races

- [ ] CFG-P05 — Complete app fresh-loading and configuration-race tests
- [ ] CFG-P05-AC1 — Prove status and every app operation load fresh settings
- [ ] CFG-P05-AC2 — Prove file observation is invalidation-only and safely coalesced
- [ ] CFG-P05-AC3 — Prove pre-mutation changes and A-to-B-to-A transitions cannot reuse authorization
- [ ] CFG-P05-V1 — Pass focused observation, status, manual, and automatic suites

### Identity, policy, topology, and privacy

- [ ] CFG-P06 — Complete semantic identity, policy, topology, and privacy tests
- [ ] CFG-P06-AC1 — Prove representation-only equivalence and diagnostic-name insensitivity
- [ ] CFG-P06-AC2 — Prove every mutation-relevant configuration change alters identity
- [ ] CFG-P06-AC3 — Prove reconciliation-policy version binding and maintenance rules
- [ ] CFG-P06-AC4 — Prove ordered resolved-topology identity and continuity invalidation
- [ ] CFG-P06-AC5 — Prove opaque persistence and output reveal no prohibited inputs
- [ ] CFG-P06-V1 — Pass focused identity, persistence, authorization, and automation suites

### Documentation

- [ ] CFG-P07 — Verify migration and retired-marker documentation contracts
- [ ] CFG-P07-AC1 — Verify active-topology retirement, removed-calendar handling, and exact-only cleanup guidance
- [ ] CFG-P07-AC2 — Verify dormant-writer, recurring-series, global-verification, and reuse guidance
- [ ] CFG-P07-V1 — Validate documentation references and diff hygiene

### Integration and final validation

- [ ] CFG-P08 — Integrate suites and complete repository validation
- [ ] CFG-P08-AC1 — Preserve deterministic architecture and safety boundaries
- [ ] CFG-P08-AC2 — Register and focus every new suite through the custom runner
- [ ] CFG-P08-AC3 — Complete final traceability and handoff evidence
- [ ] CFG-P08-V1 — Pass `make format-check`
- [ ] CFG-P08-V2 — Pass `make check`
- [ ] CFG-P08-V3 — Pass final diff hygiene
- [ ] CFG-P08-V4 — Run conditional app validation when applicable

## Next executable work

Continue with `CFG-P03`: complete runtime readiness and migration-pending gates, then run the focused access, ordinary-operation, config-check, and process suites before changing another capability area.