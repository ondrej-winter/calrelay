# Calendar Access Implementation Plan

## Plan record

- **Requirements basis:** [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md), revision 7, accepted September 16, 2026.
- **Related accepted contracts:** [`../specs/configuration-spec.md`](../specs/configuration-spec.md), [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md), [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md), [`../specs/cli-spec.md`](../specs/cli-spec.md), and [`../specs/macos-app-spec.md`](../specs/macos-app-spec.md).
- **Architecture decision:** [`../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md`](../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md).
- **Readiness:** Ready. Required outcomes, sequencing, privacy constraints, and validation are specific enough to execute without an unresolved product decision.
- **Progress date:** September 19, 2026.
- **Implementation state:** Partial. The shared access boundary, non-prompting EventKit adapter, complete preflight, CLI/manual-app flows, cleanup, mutation-time failure handling, exact occurrence handling, reusable privacy contracts, allowlisted automation persistence, app scheduling and automatic-run coordination, and operational presentation/relaunch recovery are implemented. Remaining closure is deterministic acceptance mapping plus dedicated-calendar and live macOS lifecycle validation.
- **Execution approach:** Close only the remaining gaps. Do not replace or duplicate behavior already implemented under the access slice or behavior owned by adjacent accepted specifications.

## Outcome

Complete Calendar Access Specification revision 7 by integrating the existing reusable access behavior into automatic macOS app operation, persisting only the minimum privacy-safe authorization and operational metadata, proving the remaining contracts deterministically, and validating real EventKit and lifecycle behavior with dedicated harmless calendars.

## Scope

### In scope

- Configuration-, reconciliation-policy-, and resolved-topology-bound standing authorization.
- Non-prompting scheduled and automatic ordinary reconciliation.
- Shared complete ordinary preflight before every automatic attempt.
- Mutation-time authorization and selected-configuration rechecks.
- App-process run serialization, trigger coalescing, and fresh retry attempts.
- Privacy-safe persistence of standing authorization and aggregate operational status.
- Actionable denial, revocation, recovery, retry, and freshness presentation.
- Deterministic access, automatic-run, persistence, privacy, and coordination tests.
- Dedicated-calendar manual validation of macOS permission and lifecycle behavior.

### Out of scope

- Helper apps, LaunchAgents, or closed-app synchronization.
- EventKit notification-triggered reconciliation.
- Menu-bar UI.
- Cross-process locking against CLI operations.
- Automatic legacy cleanup or automatic configuration editing.
- Provider APIs, OAuth, provider-specific sync tokens, or external network dependencies.
- Mutation-count thresholds or anomaly heuristics for otherwise valid deterministic plans.
- A visual YAML editor or a remembered alternate configuration path.

## Constraints and invariants

- Only the explicit app setup/recovery action may receive `CalendarFullAccessRequestPort` or trigger the system prompt.
- CLI, inventory, status, manual ordinary operations, cleanup, scheduling, automatic runs, and retries inspect authorization but never request it.
- Automatic attempts reload and structurally validate the selected configuration before Calendar access and never fall back to a last-known-valid in-memory configuration.
- Every automatic attempt uses a fresh run context, preflight, snapshot, and plan. A retry never resumes or reuses an earlier plan.
- Ordinary and cleanup work never overlap inside the app process. A trigger received during active work can produce at most one fresh follow-up attempt.
- A failed applicable preflight prevents every mutation. A mutation-phase failure stops later actions and does not roll back confirmed actions.
- Ordinary success requires confirmation of every ordered action but no post-apply verification read. A ready empty plan is a successful reconciliation.
- Cleanup remains manually reviewed and separately confirmed and still requires complete post-delete verification.
- Domain and application APIs remain free of EventKit, SwiftUI, AppKit, filesystem-adapter, and serialization-library types.
- Persisted state and diagnostics must not contain event titles, notes, attendees, locations, URLs, raw configuration, selectors, calendar names, marker values, raw EventKit identifiers, cleanup review rows, framework object dumps, or raw framework errors.
- Physical calendar identity may contribute to opaque authorization/action identity, but EventKit IDs remain troubleshooting identifiers rather than selectors, fallbacks, visible-set keys, or ownership markers.

## Requirement-to-current-state matrix

| Acceptance check | Current state | Remaining closure |
| --- | --- | --- |
| `ACCESS-AC-01` | **Partial.** Setup/recovery prompt ownership and non-prompting inventory, CLI, manual ordinary, and cleanup paths are implemented and tested. | Prove that scheduling, automatic attempts, and retries also never prompt; validate denial, later grant, and revocation through the stable app bundle. Owned by `CA-10`, `CA-12`, and `D05-04`. |
| `ACCESS-AC-02` | **Implemented.** Configuration-independent inventory, empty-inventory success, CLI IDs, app ID omission, and readiness separation are present. | Retain regression coverage and live inventory checks under `D05-04`. |
| `ACCESS-AC-03` | **Partial.** CLI and manual-app ordinary operations share complete preflight. | Route every automatic attempt through the same complete preflight and reject every topology/readability/writability failure before mutation. Owned by `CA-10` and `CA-12`. |
| `ACCESS-AC-04` | **Implemented.** Migration-pending config check completes access preflight, aggregates failures, returns nonzero, and does not claim readiness. | Retain regression coverage. |
| `ACCESS-AC-05` | **Implemented.** CLI and app cleanup use complete-range, all-role preflight and block all deletion on failure. | Complete dedicated-calendar validation under `D05-04`. |
| `ACCESS-AC-06` | **Implemented.** Safely determinable failures aggregate and prevent mutation. | Retain regression coverage for automatic attempts. |
| `ACCESS-AC-07` | **Implemented.** Cleanup performs complete post-mutation verification and preserves no-rollback failure semantics. | Complete live cleanup verification under `D05-04`. |
| `ACCESS-AC-08` | **Implemented.** Mutation-phase failure produces a privacy-safe partial result, stops later mutations, and performs no rollback. | Exercise the same executor semantics through automatic attempts and live validation. |
| `ACCESS-AC-09` | **Partial.** CLI/app transient disclosure rules and reusable privacy tests are implemented. | Prove that persisted authorization/status, automatic failures, notifications, and relaunch state contain no prohibited Calendar or configuration payload. Owned by `CA-11` and `CA-12`. |
| `ACCESS-AC-10` | **Implemented.** Deterministic core tests are fake-backed and domain/application APIs do not expose EventKit types. | Keep new automatic and persistence tests offline and fake-backed. |
| `ACCESS-AC-11` | **Partial.** App cleanup presentation and reusable diagnostics follow the stricter disclosure contract. | Implement and test privacy-safe persisted operational status and automatic-run presentation. Owned by `CA-11` and `CA-12`. |
| `ACCESS-AC-12` | **Implemented.** Exact recurring-occurrence selection fails closed on missing or ambiguous matches and never substitutes another occurrence or series. | Complete harmless real-EventKit recurring validation under `D05-04`. |
| `ACCESS-AC-13` | **Implemented.** Ordinary, cleanup, and cleanup-verification snapshots use hub-first declaration order and retain sequential non-atomic semantics. | Prove automatic attempts consume the same snapshot-loading boundary without adding notification restarts or double reads. |
| `ACCESS-AC-14` | **Implemented at the access boundary.** Reviewed-action identity distinguishes physical destinations and exact delete occurrences without using EventKit IDs as selectors or ownership markers. | Consume the existing opaque physical identity in standing-authorization topology binding under `CA-10`; do not create a competing identity model. |
| `ACCESS-AC-15` | **Implemented in reusable/manual flows.** Ready empty plans succeed, ordered actions require confirmation, ordinary work has no verification read, and cleanup retains complete verification. | Prove identical success semantics through automatic attempts and persisted freshness state. |

## Dependency order

1. Preserve the completed reusable access and manual/CLI baseline (`CA-01` through `CA-09`, `D05-01`, `D05-02`, `D05-03`, and `D05-05`).
2. Establish privacy-safe standing-authorization and operational persistence (`CA-11A`).
3. Add automatic trigger coordination and standing-authorization orchestration (`CA-10A` and `CA-10B`).
4. Enforce fresh preflight, pre-mutation rechecks, failure propagation, retry, and coalescing (`CA-10C`).
5. Complete persisted status, denial/revocation recovery, and presentation (`CA-11B` and `CA-10D`).
6. Close deterministic acceptance coverage (`CA-12`).
7. Perform dedicated-calendar and lifecycle validation (`D05-04`).
8. Update documentation and run the final repository gates (`CA-13`).

`CA-11A` and the application-only portions of `CA-10A` may proceed in parallel if their shared DTO and port names are agreed first. Avoid parallel edits to app composition, the control-panel status model, or `Tests/CalRelayKitTests/Main.swift`.

## Detailed tasks

### - [x] CA-01 — Establish exact recurring-occurrence identity

Define an application boundary identity that combines fetched event identity, physical calendar identity, original recurring occurrence date when present, and the snapshot range needed to resolve the exact EventKit occurrence. Fail closed on zero or multiple matches and delete only the exact occurrence.

**Evidence:** Exact occurrence selection and failure behavior are implemented in the application/EventKit boundary with deterministic coverage.

### - [x] CA-02 — Introduce access DTOs and capability-separated ports

Keep authorization inspection, full-access request, inventory, configured preflight, snapshots, and mutation behind framework-free application boundaries. Only explicit setup/recovery composition receives the request capability.

**Evidence:** Access DTOs and separated authorization ports are implemented without EventKit types in domain/application APIs.

### - [x] CA-03 — Make EventKit store operations non-prompting

Inventory, reads, creates, and deletes inspect authorization and fail when full access is unavailable. They never request Calendar permission implicitly.

**Evidence:** `EventKitCalendarStore` follows the non-prompting boundary and propagates access changes through typed failures.

### - [x] CA-04 — Deliver configuration-independent inventory

Provide CLI and app all-calendar inventory independent of configuration. CLI success may show troubleshooting IDs; app inventory omits them and does not claim configured readiness.

**Evidence:** CLI/app handlers, formatters, views, and deterministic inventory tests are present.

### - [x] CA-05 — Implement shared complete-topology preflight

Resolve every configured role, detect missing/ambiguous/colliding calendars, read hub first and work calendars in declaration order, verify writability, aggregate safely determinable failures, and expose no executable snapshot on failure.

**Evidence:** Shared ordinary and cleanup access preflight use cases and contract tests are implemented.

### - [x] CA-06 — Integrate ordinary configured readiness

Use shared complete preflight for config check, CLI reconciliation/explanation, app status, manual dry run, and reviewed manual apply, including migration-pending aggregation and configuration observation recovery.

**Evidence:** CLI/app composition and deterministic contract/handler tests cover the implemented surfaces.

### - [x] CA-07 — Implement cleanup preflight and verification

Use the complete cleanup range for every role before deletion and require a second complete verification snapshot after attempted deletion. Verification failure does not roll back or claim success.

**Evidence:** Shared cleanup use cases, app/CLI integration, and access tests are implemented.

### - [x] CA-08 — Implement ordered mutation execution and partial results

Execute deterministic ordered actions, confirm each successful action, stop at the first failure, preserve confirmed counts, return privacy-safe partial results, and never roll back.

**Evidence:** `CalendarMutationExecutor` and ordinary/cleanup use cases have deterministic coverage.

### - [x] CA-09 — Wire the complete CLI access contract

Keep calendars, config check, ordinary dry-run/apply/explanation, and cleanup non-prompting; preserve stdout/stderr, exit-status, disclosure, and no-partial-explanation rules.

**Evidence:** CLI command handlers and deterministic handler/contract tests are implemented.

### - [x] CA-10 — Complete automatic app access integration

Integrate standing authorization and automatic ordinary execution using the existing access, configuration, reconciliation, and mutation boundaries. Do not move scheduling policy or configuration identity ownership into the access adapter.

**Dependencies:** `CA-01` through `CA-09`, `CA-11A`, `D05-03`, and `D05-05`.

**Likely targets:** application DTOs and use cases under `Sources/CalRelayKit/Features/CalendarRelay/Application/`, app composition under `Sources/CalRelayApp/`, and new fake-backed contract suites under `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/`.

#### - [x] CA-10A — Implement standing-authorization orchestration

- Derive the authorization binding from the current ordinary configuration mutation identity, explicit reconciliation-policy version, and hub-first declaration-ordered resolved physical topology identity.
- Reuse existing configuration and physical-calendar identity boundaries rather than creating a second selector or topology model.
- Require a successful current dry run and explicit aggregate review before granting standing authorization.
- Persist only an opaque versioned binding through `CA-11A`; do not persist raw selectors, names, markers, EventKit identifiers, YAML, snapshots, or plan details.
- Invalidate authorization when configuration semantics, policy version, or resolved physical topology changes. Returning to an older identity must not silently reactivate an old grant.
- Keep manual ordinary apply and cleanup authorization independent from standing authorization.

**Evidence:** The application use case, opaque binding derivation, fresh aggregate review/confirmation, mismatch invalidation, non-reactivation behavior, app composition, and deterministic standing-authorization contract suite are implemented.

#### - [x] CA-10B — Add scheduled and automatic trigger coordination

- Add one app-owned coordinator for manual ordinary work, cleanup, automatic runs, status refresh, and configuration-change recovery.
- Connect enabled scheduling to app launch, wake, and fixed 15-minute timer triggers as owned by the macOS app specification.
- Prevent app-process overlap. Triggers received during active work coalesce into at most one follow-up attempt.
- Do not claim or add cross-process locking against CLI operations.
- Keep views, app lifecycle callbacks, notification callbacks, and login-item callbacks thin.

**Evidence:** `CalendarAppOperationCoordinator` serializes app-owned work with configuration-recovery priority and one coalesced automatic follow-up. App composition connects enabled scheduling to launch, wake, the fixed 15-minute timer, and persisted retry timers without claiming cross-process locking.

#### - [x] CA-10C — Enforce fresh access gates for every attempt

- Reload and structurally validate the selected configuration before Calendar access on every initial, follow-up, or retry attempt.
- Block missing, invalid, and migration-pending configuration without falling back to prior in-memory settings.
- Inspect full Calendar authorization without receiving the request capability.
- Run the shared complete ordinary preflight and load a fresh ordered snapshot.
- Recompute and compare the standing-authorization binding before mutation.
- Revalidate selected-file/configuration identity and Calendar authorization immediately before the first mutation.
- Execute only the fresh ordered plan, stop after the first mutation failure, and never roll back confirmed actions.
- Count a ready empty plan as success; count a mutating run as success after every ordered action is confirmed; perform no ordinary post-apply verification read.
- Use finite bounded-backoff retries only for transient automatic failures. Every retry reloads all inputs and recomputes the plan; user-action failures do not enter an aggressive retry loop.

**Evidence:** `CalendarAutomaticReconciliationUseCase` performs fresh configuration, access, topology, snapshot, authorization-binding, selected-file, and pre-mutation checks for every ordinary or retry attempt. It persists safe aggregate outcomes, uses bounded 1/5/15-minute retries for transient failures, and atomically preserves concurrent authorization revocation.

#### - [x] CA-10D — Present denial, revocation, retry, and recovery state

- Map access denial, restriction, write-only state, revocation, topology failure, standing-authorization invalidation, partial mutation, retry, and overdue freshness into privacy-safe app state.
- Preserve dependency-ordered recovery actions from the macOS app specification.
- Allow later lifecycle/timer triggers to reevaluate user-action failures without requesting access.
- Keep notification denial from disabling scheduling; provide persistent in-app and Dock-visible fallback state.

**Evidence:** The app presents dependency-ordered automation state, safe operation history, retry/freshness state, user notifications for actionable recovery, and Dock/in-app fallback when notification permission is unavailable. Pause/resume, launch-at-login recovery, and enabled-scheduling Quit warning are wired through thin app boundaries.

#### - [x] CA-10-AC1 — Prove automatic operations are non-prompting and fully gated

Every scheduled, launch, wake, follow-up, and retry attempt must use the same full ordinary preflight, receive no permission-request capability, and perform zero mutations when configuration, migration, authorization, topology, standing-authorization, or pre-mutation identity checks fail.

#### - [x] CA-10-AC2 — Prove fresh-plan and completion semantics

Empty automatic plans update success/freshness; mutating plans succeed only after every ordered confirmation; partial failure stops later actions without rollback; retries and coalesced follow-ups use fresh configuration, preflight, snapshots, and plans.

#### - [x] CA-10-V1 — Pass focused automatic-operation suites

Run exact registered suites covering standing authorization, automatic execution, selected-file change, denial/revocation, policy/topology invalidation, trigger coalescing, bounded retry, empty success, and partial failure.

**Evidence:** `CalendarStandingAuthorizationTests`, `CalendarAutomaticReconciliationTests`, and `CalendarAutomationCoordinationTests` pass through the custom SwiftPM executable runner, and `swift build --product CalRelayApp` passes.

### - [ ] CA-11 — Complete privacy-safe persistence and operational presentation

Persist only the latest minimal metadata needed for standing authorization and app recovery across relaunch. Extend presentation without weakening reusable access diagnostics or retaining transient cleanup/event detail.

**Dependencies:** completed reusable privacy boundaries. `CA-11A` precedes automatic integration; `CA-11B` consumes results from `CA-10`.

**Likely targets:** application DTOs and ports under `Sources/CalRelayKit/Features/CalendarRelay/Application/`, concrete local persistence in app adapters/composition, `CalendarControlPanelStatus`, and the app view model/views.

#### - [x] CA-11A — Add allowlisted standing-authorization and status persistence

- Define purpose-specific application DTOs and ports for scheduling preference, opaque standing-authorization binding, attempt/success timestamps, safe result/failure category, aggregate confirmed create/delete counts, retry state, and freshness metadata.
- Use a deterministic versioned representation for persisted authorization identity. Do not use Swift's randomized `Hasher` or a reversible serialization of configuration/topology data.
- Make prohibited data structurally unrepresentable in persistence DTOs rather than relying only on call-site redaction.
- Add a concrete app persistence adapter with safe decoding, version handling, corruption recovery, and no implicit authorization reactivation.
- Never serialize rich configuration, event, plan, preflight snapshot, cleanup review, framework error, or EventKit object types.

**Evidence:** Purpose-specific application DTOs and the `CalendarAutomationStateStore` port are implemented with a versioned `UserDefaults` adapter. Deterministic tests cover round-trip behavior, opaque semantic binding, prohibited-value absence, unsupported-version recovery, corruption recovery, and authorization-safe reset.

#### - [x] CA-11B — Extend operational state and relaunch recovery

- Restore only approved persisted metadata after relaunch and rederive live configuration, authorization, topology, scheduling, retry, and freshness state.
- Show scheduling and launch-at-login health, standing-authorization state, last attempt, last success, next nominal timer run, active retry, latest safe result/failure category, aggregate mutation counts, and overdue freshness.
- Preserve the primary recovery order defined by the macOS app specification: configuration, Calendar access, topology, migration, standing authorization, launch-at-login, scheduling/retry/freshness, then healthy state.
- Discard transient ordinary/cleanup review data after completion, cancellation, failure, or relaunch.

**Evidence:** Approved persisted metadata is restored and live scheduling, launch-at-login, authorization, retry, freshness, attention, notification, and Quit-warning presentation is rederived. The AppKit lifecycle adapter identifies login-item launches from the `kAEOpenApplication` Apple event only when `keyAEPropData` equals `keyAELaunchedAsLogInItem`; it does not use an ambiguous default-launch heuristic. Only that launch context initially suppresses the SwiftUI control panel. After live control-panel state, persisted automation state, and login-item health are available, `CalendarLoginLaunchPolicy` keeps healthy or actively retrying login launches hidden and opens actionable setup, recovery, exhausted-failure, or overdue-freshness states. Healthy launches remain suppressed through the prompt automatic launch attempt. Ordinary Dock/Finder launches stay visible, and a Dock reopen presents the hidden control panel. `CalendarLoginLaunchPolicyTests`, `swift build --product CalRelayApp`, `make format-check`, `make check`, and `make app` pass; an actual login-session behavior check remains under `D05-04C`.

#### - [ ] CA-11-AC1 — Prove persisted disclosure compliance

Stored data, relaunch state, persistent diagnostics, and notifications contain only approved opaque identities, timestamps, safe categories, and aggregate counts. They contain no event details, raw configuration, selectors, names, markers, EventKit identifiers, review rows, or raw framework errors.

#### - [ ] CA-11-V1 — Pass persistence and presentation suites

Run round-trip, version/corruption, negative disclosure, relaunch recovery, notification-denial, transient-review disposal, and primary-state-precedence tests.

### - [ ] CA-12 — Complete deterministic acceptance coverage

Map every Calendar Access acceptance check to deterministic evidence or an explicitly manual-only EventKit/lifecycle checkpoint. Keep default suites fast, isolated, offline, fake-backed, and registered in the custom test runner.

**Dependencies:** implement incrementally with `CA-10` and `CA-11`; complete before `D05-04` final closure.

**Likely targets:** contract suites under `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/`, adjacent app/CLI handler tests, and `Tests/CalRelayKitTests/Main.swift`.

#### - [ ] CA-12A — Extend no-prompt and authorization-state coverage

- Prove only setup/recovery can request access.
- Cover not-determined, restricted, denied, write-only, full-access, revoked, and unknown/future authorization states.
- Prove inventory, status, config check, manual ordinary, automatic ordinary, cleanup, retry, and scheduling never request access.

#### - [ ] CA-12B — Cover automatic preflight and mutation behavior

- Cover missing, ambiguous, colliding, unreadable, and read-only roles for automatic attempts.
- Verify hub-first declaration-ordered reads and all-or-nothing mutation gating.
- Cover configuration/policy/topology standing-authorization invalidation and selected-file change immediately before mutation.
- Cover empty-plan success, ordered mutation confirmation without an ordinary verification read, partial failure, fresh retry, fresh coalesced follow-up, no automatic cleanup, and no plan-size heuristic.

#### - [ ] CA-12C — Cover persisted privacy and coordination

- Test persistence allowlisting and search serialized output/log captures for prohibited representative values.
- Cover relaunch recovery, cleanup-review transience, privacy-safe automatic/partial results, and notification fallback.
- Cover app-process no-overlap and at-most-one coalesced follow-up without asserting cross-process serialization.

#### - [ ] CA-12-AC1 — Map all acceptance checks to evidence

Maintain a test/evidence map for `ACCESS-AC-01` through `ACCESS-AC-15`; leave any unavailable live EventKit or lifecycle requirement explicitly pending rather than treating absent behavior as a pass.

#### - [ ] CA-12-V1 — Pass all registered custom-runner suites

Run focused exact suite names while iterating, then pass the full `swift run CalRelayKitTests` path through the repository quality gate.

### - [ ] CA-13 — Update operational documentation and complete validation

Update canonical project references after implementation and perform the complete code/tooling/app handoff gate. Do not duplicate accepted product contracts in project documentation.

**Dependencies:** `CA-10`, `CA-11`, `CA-12`, and `D05-04`.

**Likely targets:** `docs/configuration.md`, `docs/manual-validation.md`, `docs/development.md` if commands or lifecycle setup change, `docs/repository-layout.md` if new package areas are introduced, and this plan.

#### - [ ] CA-13A — Align documentation and progress evidence

- Remove pending-automation wording only after the corresponding implementation and evidence exist.
- Document standing authorization, scheduling/recovery state, privacy-safe persistence, and operator validation without exposing sensitive local data.
- Distinguish deterministic evidence, live EventKit evidence, local mutation confirmation, cleanup verification, and provider convergence.
- Synchronize detailed and dashboard checkboxes and record concise completion evidence or blockers.

#### - [ ] CA-13B — Run the complete repository gates

From the repository root, run:

```sh
make format-check
make check
make app
git --no-pager diff HEAD --check
```

Do not substitute `swift test` for the custom test runner. If a required check is blocked or fails for an unrelated pre-existing reason, report it explicitly without weakening or skipping the gate silently.

#### - [ ] CA-13-AC1 — Confirm documentation and implementation consistency

The accepted specifications, application behavior, operational references, manual-validation procedure, and progress evidence must describe the same permission, authorization, scheduling, success, privacy, and recovery semantics.

#### - [ ] CA-13-V1 — Pass or accurately report every final gate

All required repository checks pass, or every unresolved failure is identified with command output, scope, and impact. No check is claimed as passed unless it was run.

### - [x] D05-01 — Repair and verify local app packaging

Build the stable `dev.owinter.CalRelay` app bundle with the required Calendar usage description and verify packaging/signature behavior.

**Evidence:** App packaging and bundle validation were completed before this gap plan.

### - [x] D05-02 — Exercise available non-mutating live checks

Launch the app and exercise non-prompting status/inventory and unavailable-access behavior without mutating personal calendars or configuration.

**Evidence:** Available denied/not-determined non-mutating checks were performed; full-access dedicated-calendar validation remains in `D05-04`.

### - [x] D05-03 — Deliver reviewed manual ordinary apply

Provide aggregate dry-run review, exact fresh-plan confirmation, pre-mutation access/configuration checks, ordered execution, partial results, and no automatic retry authorization.

**Evidence:** Manual ordinary review/apply and deterministic confirmation/access coverage are implemented.

### - [ ] D05-04 — Complete dedicated-calendar live acceptance

Validate real EventKit permissions, exact mutations, provider visibility, and automatic app lifecycle behavior using only harmless dedicated calendars and the stable app bundle identity.

**Dependencies:** `CA-10`, `CA-11`, and `CA-12`. Already implemented manual checks may be exercised earlier, but final closure follows automatic integration.

**Likely target:** `docs/manual-validation.md` for the maintained procedure and privacy-safe evidence record.

#### - [ ] D05-04A — Validate permission and inventory transitions

- Validate the first full-access request through setup/recovery.
- Validate denial, System Settings recovery, later grant, restricted/write-only presentation where reproducible, revocation, and relaunch.
- Confirm inventory, status, CLI, manual ordinary, cleanup, scheduling, automatic attempts, and retries never prompt.
- Confirm app inventory omits EventKit IDs while successful CLI inventory includes approved troubleshooting IDs.

#### - [ ] D05-04B — Validate ordinary, cleanup, and exact occurrence behavior

- Validate configured readiness, dry-run, explanation, manual apply, and later provider convergence.
- Validate all-or-nothing topology failure and privacy-safe failure output.
- Validate cleanup review, exact deletion, complete verification, verification failure, and no rollback.
- Validate partial mutation failure and exact recurring-occurrence deletion without first-occurrence or whole-series substitution.

#### - [ ] D05-04C — Validate automatic lifecycle behavior

- Validate standing-authorization grant, relaunch restoration, and invalidation after mutation-relevant configuration, policy-version, or resolved physical-topology change.
- Validate launch-at-login health, launch/wake runs, fixed cadence, bounded retry, freshness, pause, Quit warning, and notification-denial fallback.
- Validate that an actual login-item Apple-event launch stays hidden when healthy or actively retrying, opens for actionable recovery, and remains distinct from an ordinary Dock/Finder launch and a later Dock reopen.
- Validate no overlap, at-most-one coalesced fresh follow-up, pre-mutation selected-file change abort, denial/revocation recovery, and no automatic cleanup.

#### - [ ] D05-04-AC1 — Preserve operator data and record limitations safely

Use only dedicated harmless calendars, preserve the operator's personal configuration and calendars, and record provider-specific limitations without calendar names, event titles, identifiers, or other personal content.

#### - [ ] D05-04-V1 — Record complete live evidence

Record dates, build identity, tested authorization/lifecycle transitions, pass/fail outcomes, and any blocked provider behavior in `docs/manual-validation.md` or this maintained plan without sensitive Calendar payload.

### - [x] D05-05 — Deliver separately reviewed app legacy cleanup

Provide a transient execution-ordered cleanup review, one-use exact-plan confirmation, complete preflight, mutation-time access gate, verified deletion, privacy-safe partial/verification failure, and no automatic cleanup authorization.

**Evidence:** App cleanup dry-run/apply, exact review identity, access/privacy behavior, and deterministic tests are implemented.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Accidental system permission prompt | Keep request capability available only to setup/recovery composition; automatic and scheduled use cases receive inspection/store ports only. |
| Standing authorization survives a meaningful change | Bind it to mutation-relevant configuration, explicit policy version, and ordered resolved physical topology; fail closed when continuity cannot be proved. |
| Unstable or reversible persisted identity | Use a deterministic versioned opaque representation; do not use Swift `Hasher` or serialize raw configuration/topology values. |
| Raw EventKit/calendar data leaks into storage or notifications | Use allowlisted purpose-specific persistence DTOs and negative disclosure tests with representative prohibited values. |
| Retry or coalescing reuses stale work | Reenter through one automatic-run boundary that reloads configuration and recomputes preflight, snapshots, and plan for every attempt. |
| App workflows overlap | Coordinate ordinary, cleanup, status recovery, and triggers through one app-owned serialization boundary. |
| Partial mutation is misreported as success | Preserve progressive confirmations and counts, stop at first failure, categorize the result, and update last-success only for complete ordinary success. |
| Provider read-after-write lag prompts an unsafe extra ordinary read | Preserve local ordered-confirmation success semantics and allow later fresh reconciliation to converge. Cleanup alone retains mandatory verification. |
| UI/lifecycle code takes over orchestration | Keep SwiftUI/AppKit/lifecycle callbacks thin and place reusable sequencing in application use cases or explicit app composition. |
| Automation scope expands into helper architecture | Preserve the accepted normal-app-only ADR boundary; helper, LaunchAgent, background-only, or closed-app work requires a later explicit decision. |

## Validation strategy

### Focused deterministic validation

- Run exact suites registered in `Tests/CalRelayKitTests/Main.swift` while implementing each application boundary.
- Keep tests independent of EventKit, wall-clock time, real calendars, shared defaults, and network access.
- Use fakes for authorization transitions, selected-file identity changes, topology churn, timer/wake/launch triggers, persistence, retry delay, notifications, and mutation failures.
- Add suites using established naming patterns, such as `CalendarStandingAuthorizationTests`, `CalendarAutomaticReconciliationTests`, `CalendarAppRunCoordinatorTests`, and `CalendarOperationalStatusPrivacyTests`, if those names fit the final package structure.

### Manual macOS validation

- Use the stable built app identity and dedicated harmless calendars.
- Exercise first request, denial, later grant, revocation, relaunch, scheduled attempts, wake/launch triggers, retry, coalescing, topology churn, cleanup verification, and exact recurring occurrence behavior.
- Treat real EventKit/system settings/lifecycle behavior as manual evidence; do not add it to default automated tests.

### Final validation

```sh
make format-check
make check
make app
git --no-pager diff HEAD --check
```

## Completion gates

Calendar Access revision 7 is complete only when:

1. Every row in the requirement matrix is implemented and has deterministic or explicitly manual evidence.
2. Automatic and scheduled operations cannot request Calendar access and use the same complete ordinary preflight as manual/CLI operations.
3. Standing authorization fails closed on configuration, policy, physical-topology, access, migration, or selected-file identity changes.
4. Persisted state and notifications pass the strict disclosure contract.
5. Automatic retries and coalesced follow-ups always use fresh inputs and never overlap app-owned ordinary or cleanup work.
6. Dedicated-calendar live validation covers permission acquisition, denial, later grant, revocation, relaunch, scheduled operation, mutation, cleanup verification, and exact recurring occurrence handling.
7. Documentation reflects observed behavior, and every final validation gate passes or is accurately reported as blocked.

## Progress tracking

### Completed baseline

- [x] CA-01 — Establish exact recurring-occurrence identity
- [x] CA-02 — Introduce access DTOs and capability-separated ports
- [x] CA-03 — Make EventKit store operations non-prompting
- [x] CA-04 — Deliver configuration-independent inventory
- [x] CA-05 — Implement shared complete-topology preflight
- [x] CA-06 — Integrate ordinary configured readiness
- [x] CA-07 — Implement cleanup preflight and verification
- [x] CA-08 — Implement ordered mutation execution and partial results
- [x] CA-09 — Wire the complete CLI access contract
- [x] D05-01 — Repair and verify local app packaging
- [x] D05-02 — Exercise available non-mutating live checks
- [x] D05-03 — Deliver reviewed manual ordinary apply
- [x] D05-05 — Deliver separately reviewed app legacy cleanup

### Remaining automatic integration

- [ ] CA-10 — Complete automatic app access integration
- [ ] CA-10A — Complete app integration for the implemented standing-authorization orchestration
- [ ] CA-10B — Add scheduled and automatic trigger coordination
- [ ] CA-10C — Enforce fresh access gates for every attempt
- [ ] CA-10D — Present denial, revocation, retry, and recovery state
- [ ] CA-10-AC1 — Prove automatic operations are non-prompting and fully gated
- [ ] CA-10-AC2 — Prove fresh-plan and completion semantics
- [ ] CA-10-V1 — Pass focused automatic-operation suites

### Remaining persistence and presentation

- [ ] CA-11 — Complete privacy-safe persistence and operational presentation
- [x] CA-11A — Add allowlisted standing-authorization and status persistence
- [ ] CA-11B — Extend operational state and relaunch recovery
- [ ] CA-11-AC1 — Prove persisted disclosure compliance
- [ ] CA-11-V1 — Pass persistence and presentation suites

### Remaining deterministic coverage

- [ ] CA-12 — Complete deterministic acceptance coverage
- [ ] CA-12A — Extend no-prompt and authorization-state coverage
- [ ] CA-12B — Cover automatic preflight and mutation behavior
- [ ] CA-12C — Cover persisted privacy and coordination
- [ ] CA-12-AC1 — Map all acceptance checks to evidence
- [ ] CA-12-V1 — Pass all registered custom-runner suites

### Remaining live acceptance

- [ ] D05-04 — Complete dedicated-calendar live acceptance
- [ ] D05-04A — Validate permission and inventory transitions
- [ ] D05-04B — Validate ordinary, cleanup, and exact occurrence behavior
- [ ] D05-04C — Validate automatic lifecycle behavior
- [ ] D05-04-AC1 — Preserve operator data and record limitations safely
- [ ] D05-04-V1 — Record complete live evidence

### Remaining documentation and final validation

- [ ] CA-13 — Update operational documentation and complete validation
- [ ] CA-13A — Align documentation and progress evidence
- [ ] CA-13B — Run the complete repository gates
- [ ] CA-13-AC1 — Confirm documentation and implementation consistency
- [ ] CA-13-V1 — Pass or accurately report every final gate

## Next executable work

Start with `CA-11A` and the application-only identity/orchestration portion of `CA-10A`. Establish the allowlisted persistence contract and opaque standing-authorization binding before connecting scheduled triggers or automatic mutation.
