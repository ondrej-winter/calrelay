# CLI Specification Implementation Plan

## Plan record

- **Requirements basis:** [`../specs/cli-spec.md`](../specs/cli-spec.md), revision 7, accepted September 16, 2026.
- **Related accepted contracts:** [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md), [`../specs/configuration-spec.md`](../specs/configuration-spec.md), and [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md).
- **Readiness:** Ready. Required outcomes, sequencing, architectural boundaries, privacy constraints, and validation are specific enough to execute without an unresolved product decision.
- **Progress date:** September 20, 2026.
- **Implementation state:** Partial. The command hierarchy, shared application use cases, preflight behavior, planning, mutation execution, cleanup verification, explanation, and initial CLI tests exist. This plan closes conformance and evidence gaps instead of rebuilding the CLI.
- **Execution approach:** Implement small CLI-facing vertical slices, add focused deterministic evidence with each slice, then add process-level coverage and complete the repository gates.
- **Workspace constraint:** Preserve the pre-existing staged deletion of `docs/plans/calendar-access-implementation-plan.md`. Do not restore, modify, stage, or otherwise include it in CLI implementation work.

## Outcome

Bring the existing `calrelay` executable into demonstrable conformance with CLI Specification revision 7, including complete explicit configuration-path semantics, truthful no-change output, ordered ordinary and cleanup presentation, cleanup coverage summaries and migration guidance, stable stdout/stderr behavior, deterministic process-level evidence, and documented validation.

## Scope

### In scope

- `calrelay calendars` inventory behavior and output.
- `calrelay config check` default and explicit configuration selection, validation, readiness, and migration-pending behavior.
- Ordinary `calrelay reconcile` dry-run, `--apply`, and `--explain` behavior.
- `calrelay reconcile --cleanup-legacy` dry-run and apply behavior.
- CLI option validation, non-interactive mutation authorization, process status, stdout/stderr routing, progressive confirmations, privacy-safe diagnostics, and no-change semantics.
- Reusable CLI handlers and formatters in `CalRelayKit`, with thin ArgumentParser wrappers in `CalRelayCLI`.
- Deterministic fake-backed handler, contract, and executable-process tests.
- CLI-facing project documentation, manual validation instructions, and quality-gate alignment.

### Out of scope

- New public commands, flags, configuration fields, or stable numeric failure categories.
- Interactive confirmations, plan tokens, or proof that a prior dry-run occurred.
- A stable machine-readable output format or a requirement that scripts parse presentation text.
- Changes to reconciliation selection rules, cleanup range, marker grammar, projection ownership, or EventKit occurrence targeting.
- Automatic configuration editing or automatic removal of `legacyMarkers`.
- New app behavior, except preserving callers of shared `CalRelayKit` APIs.
- Real EventKit or real-calendar mutation in the default automated test gate.
- New external dependencies or a new architecture decision record.

## Constraints and invariants

- Product behavior remains owned by the accepted specifications; this plan must not silently redefine those contracts.
- Domain and application APIs remain independent of ArgumentParser, filesystem path discovery, terminal streams, and EventKit framework types.
- Filesystem selection, option parsing, live adapter construction, and terminal output remain adapter or composition concerns.
- CLI commands never request Calendar permission or trigger the macOS permission prompt.
- Configuration file existence, YAML parsing, and structural validation complete before EventKit access for config check and every reconciliation mode.
- Ordinary modes use the complete ordinary preflight; cleanup uses the complete bounded-range cleanup preflight and post-apply verification.
- Ordinary and cleanup detailed rows follow the authoritative ordered executable sequence.
- Mutation confirmation is printed only after the individual mutation succeeds.
- Partial failures stop later mutations, perform no rollback, preserve prior confirmations on standard output, and write privacy-safe diagnostics to standard error.
- Successful inventory and ordinary explanation retain their narrow EventKit-ID disclosure exceptions. Cleanup review and all failure output omit prohibited IDs and details.
- Ordinary apply performs no post-apply verification read or claim. Cleanup apply succeeds only after its required no-match verification snapshot.
- Default tests remain deterministic, isolated, offline, fake-backed, and independent of real Calendar permission or calendar data.

## Current implementation assessment

The following behavior is already present and should be preserved rather than duplicated:

- The `calrelay` root command and `calendars`, `config check`, and `reconcile` command hierarchy.
- Dry-run as the ordinary and cleanup default, with `--apply` as non-interactive mutation authorization.
- Early ArgumentParser validation for `--apply --explain` and `--cleanup-legacy --explain`.
- Shared ordinary and cleanup use cases, complete topology preflight, deterministic planning, ordered mutation execution, stop-on-first-failure behavior, and no rollback.
- Migration-pending gates, shared ordinary explanation, progressive post-success mutation confirmations, and cleanup post-apply verification.
- Successful CLI inventory ID disclosure, successful explanation ID disclosure, cleanup ID omission, and privacy-safe partial-result DTOs.
- Initial handler tests, contract tests, privacy tests, help smoke tests, and process checks for invalid option combinations and failed explanation setup.

The implementation and evidence gaps to close are:

- Explicit override selection lacks the required `~` and leading `~/` expansion and complete deterministic path-semantics coverage.
- Relative-path resolution is currently implicit in filesystem behavior rather than explicit and injectable for deterministic verification.
- Empty ordinary `--apply` currently says planned mutations were performed even though no mutation occurred.
- Ordinary detailed formatting reconstructs delete/create groups rather than rendering directly from the authoritative ordered action sequence.
- Cleanup output does not report every configured role covered or per-role deletion counts, including zero-count roles.
- Cleanup apply does not yet provide all required prior-dry-run and post-success tombstone guidance.
- Handler coverage is incomplete for no-change, multi-role ordering, prohibited cleanup details, and partial failure output.
- Process-level tests do not yet prove representative successful stdout, progressive stdout plus stderr on partial failure, or the full binary-status contract without live EventKit.
- The Makefile directly smoke-checks only root help even though the accepted specification lists four help invocations.

## Execution sequence

1. Complete configuration-path selection and its focused tests.
2. Correct ordinary ordered and no-change presentation with focused tests.
3. Complete cleanup review, counts, privacy, and migration guidance with focused tests.
4. Fill deterministic handler and contract coverage across the complete CLI acceptance surface.
5. Add the smallest debug-only fake CLI composition seam needed for true process-level stream and status tests.
6. Align documentation and validation entry points, then run focused and complete automated gates.
7. Perform separately authorized real EventKit validation with harmless dedicated calendars, or record it explicitly as pending.

Tasks `CLI-P01`, `CLI-P02`, and `CLI-P03` are conceptually independent, but `CLI-P02` and `CLI-P03` both touch `ReconcileCommandHandler.swift`; execute them sequentially unless separate workers coordinate non-overlapping edits. Later tasks depend on the completed behavior slices and should not reimplement them.

## Detailed plan

### - [x] CLI-P01 — Complete explicit configuration-path resolution

Implement all explicit override semantics owned by `CONFIG-04` and required by `CLI-AC-10` at the filesystem adapter boundary.

**Dependencies:** none.

**Likely targets:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigurationFileSelection.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigurationFileSelectionTests.swift`

**Implementation notes:**

- Add an injectable current working directory alongside the existing injectable home directory and file-existence check.
- Preserve absolute override paths as supplied for file access.
- Resolve relative overrides against the process current working directory.
- Expand exactly `~` and a leading `~/` against the current user's home directory.
- Do not expand `~otheruser`, `$HOME`, other environment syntax, or arbitrary embedded tildes.
- Preserve a useful user-facing selected-path representation while using the correctly resolved path for filesystem access.
- Retain distinct missing-file guidance for the canonical default and an explicit override.

#### - [x] CLI-P01-AC1 — Prove every accepted override form

Tests cover the canonical default, absolute override, relative override, exact `~`, and leading `~/...` using injected home and working directories rather than developer state.

#### - [x] CLI-P01-AC2 — Reject unsupported expansion without reinterpretation

Tests prove that `~otheruser`, `$HOME/...`, and unrelated tilde-containing paths are not expanded and that missing-file diagnostics retain explicit-override semantics.

#### - [x] CLI-P01-V1 — Pass focused configuration-selection tests

Run `swift run CalRelayKitTests ConfigurationFileSelectionTests` and record the result before continuing.

**Completion evidence (September 20, 2026):** Passed `swift run CalRelayKitTests ConfigurationFileSelectionTests`.

### - [x] CLI-P02 — Align ordinary reconciliation output with ordered execution semantics

Make ordinary dry-run and apply output consume the authoritative ordered actions and report empty-plan success truthfully.

**Dependencies:** `CLI-P01` is not a behavioral prerequisite, but complete it first to keep CLI handler changes reviewable.

**Likely targets:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconciliationPlanFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandler.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`
- Relevant formatter assertions in `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalRelayContractTests.swift`

**Implementation notes:**

- Render detailed rows directly from `OrdinaryReconciliationResult.actions`; do not reconstruct their semantic sequence from separate create/delete collections.
- Retain useful aggregate create/delete counts without allowing headings or grouping to reorder detailed rows.
- Keep ordinary dry-run non-mutating and label it accordingly.
- Report a ready empty ordinary dry-run as successful no-change.
- Report a ready empty ordinary apply as successful no-change and explicitly avoid claiming that mutations occurred.
- For nonempty apply, retain progressive confirmations and report completion only after every ordered action succeeds.
- Do not perform or claim an ordinary post-apply verification read.

#### - [x] CLI-P02-AC1 — Prove exact ordinary presentation order

A representative multi-role test asserts hub deletes, declaration-ordered work deletes, hub creates, and declaration-ordered work creates in the same sequence as `OrdinaryReconciliationResult.actions`.

#### - [x] CLI-P02-AC2 — Prove truthful no-change output

Focused tests cover empty ordinary dry-run and empty ordinary apply, require success wording, and reject any statement that mutations were performed or post-apply state was verified.

#### - [x] CLI-P02-AC3 — Preserve successful-only confirmations and local apply completion

Tests retain confirmation-after-success behavior and prove nonempty apply output does not promise provider convergence or an immediate empty later plan.

#### - [x] CLI-P02-V1 — Pass focused ordinary CLI tests

Run `swift run CalRelayKitTests ReconcileCommandHandlerTests` and the relevant `CalRelayContractTests` formatter coverage.

**Completion evidence (September 20, 2026):** Passed `swift run CalRelayKitTests ReconcileCommandHandlerTests` and `swift run CalRelayKitTests CalRelayContractTests`.

### - [ ] CLI-P03 — Complete cleanup review, summaries, and migration guidance

Close cleanup presentation gaps without changing shared cleanup selection, mutation authorization, or verification behavior.

**Dependencies:** `CLI-P02`, because both tasks update `ReconcileCommandHandler.swift` and should remain separate reviewable slices.

**Likely targets:**

- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarCleanupFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandler.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`

**Implementation notes:**

- Derive configured role order from validated settings: hub first, followed by work roles in YAML declaration order.
- Pass CLI-specific role-summary context to the formatter rather than expanding the shared cleanup domain plan solely for presentation.
- Report the bounded cleanup range, local point-in-time scope, all configured roles covered, total selected deletions, and per-role deletion counts including zeros.
- Preserve one transient review row per selected deletion in exact execution order.
- Continue showing only the approved title with marker removed, configured role, and time or all-day range.
- Continue omitting marker values, EventKit event and calendar IDs, selectors, and calendar titles.
- Before cleanup mutation, identify the plan as fresh, recommend prior dry-run without requiring it, and preserve `--apply` as sufficient non-interactive authorization.
- After verified success, state that CalRelay did not edit configuration and direct the operator to remove tombstones manually only after eventual-convergence migration is complete for the topology.
- Distinguish dry-run no-match in the loaded snapshot from apply no-match in the post-mutation verification snapshot.

#### - [ ] CLI-P03-AC1 — Prove complete role and count reporting

Tests cover hub and multiple work roles, including zero-count roles, and verify role summaries and detailed rows retain configuration and execution order.

#### - [ ] CLI-P03-AC2 — Prove cleanup privacy and local-scope wording

Tests use sentinel marker values, selectors, calendar titles, and EventKit IDs and assert their absence while retaining approved title, role, and time-range review details and rejecting global-retirement claims.

#### - [ ] CLI-P03-AC3 — Prove direct apply and post-success guidance

Tests require the fresh apply plan before mutation, non-interactive authorization wording, successful-only confirmations, verified no-match success, no automatic YAML edit claim, and eventual-convergence tombstone guidance.

#### - [ ] CLI-P03-V1 — Pass focused cleanup CLI tests

Run `swift run CalRelayKitTests ReconcileCommandHandlerTests`, `CalendarCleanupAccessTests`, and `CalendarAccessPrivacyTests`.

### - [ ] CLI-P04 — Complete deterministic handler and acceptance evidence

Expand fake-backed coverage so every CLI acceptance check has deterministic evidence or an explicitly manual-only checkpoint.

**Dependencies:** `CLI-P01`, `CLI-P02`, and `CLI-P03`.

**Likely targets:**

- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/CommandHandlerTestSupport.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarListCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigCheckCommandHandlerTests.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`
- Adjacent suites under `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/`
- `Tests/CalRelayKitTests/Main.swift` only if a new suite is necessary

**Coverage to establish:**

- Missing and structurally invalid configurations fail before Calendar access.
- Cleanup without legacy markers fails before Calendar access.
- Ordinary migration pending blocks before Calendar access, while config check still performs ordinary preflight before reporting migration pending.
- Config check, ordinary dry-run, apply, and explanation use the ordinary window; cleanup uses the bounded cleanup window and complete verification read.
- Empty inventory remains successful and makes no readiness claim.
- Ordinary and cleanup partial mutation confirm only successful actions, stop at the first failure, perform no rollback, and expose only privacy-safe counts, role, category, and recovery guidance.
- Explanation performs no mutation, covers every loaded input and planned action, shares the ordered action sequence with dry-run, and emits no partial success output or IDs on failure.
- Cleanup remains delete-only and does not run ordinary projection or current-marker reconciliation.

#### - [ ] CLI-P04-AC1 — Map `CLI-AC-01` through `CLI-AC-06`

Record deterministic tests for discovery, config check, flag validation, preflight selection, cleanup-only behavior, and ordinary/cleanup no-change success.

#### - [ ] CLI-P04-AC2 — Map `CLI-AC-07` through `CLI-AC-11`

Record handler or process evidence for binary success semantics, stream routing, partial mutation, explanation equivalence/privacy, configuration ordering, and non-prompting access failures.

#### - [ ] CLI-P04-AC3 — Map `CLI-AC-12` through `CLI-AC-15`

Record deterministic evidence for cleanup details and verification, direct cleanup apply, all detailed execution-order requirements, and ordinary non-interactive local completion without verification.

#### - [ ] CLI-P04-V1 — Pass the focused deterministic acceptance set

Run the exact registered suites needed by the acceptance map and keep any unavailable real EventKit evidence explicitly pending rather than reporting it as passed.

### - [ ] CLI-P05 — Add deterministic process-level stream and status tests

Test the actual executable without granting tests live Calendar access by introducing the smallest safe CLI-owned composition seam.

**Dependencies:** `CLI-P01` through `CLI-P04`.

**Likely targets:**

- `Package.swift`
- CLI composition code under `Sources/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/`
- `Sources/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarsCommand.swift`
- `Sources/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigCheckCommand.swift`
- `Sources/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommand.swift`
- `Tests/CalRelayKitTests/CalRelayCLI/Features/CalendarRelay/Adapters/Inbound/CLI/CalRelayCLISmokeTests.swift`

**Implementation notes:**

- Centralize live CLI dependency construction behind a CLI-owned composition helper so command declarations remain thin.
- Add a custom debug-only Swift compilation condition for process-test fixtures.
- Under that condition only, allow explicit test environment activation and a fixed scenario selector.
- Compile fake scenario composition out of release builds.
- Use fixed non-sensitive fixtures. Do not accept arbitrary serialized calendar data, credentials, raw YAML, or event content through the environment.
- Without explicit test activation, always construct the existing live EventKit adapters.
- Add no public flag and make no change to production command help.
- Keep process assertions semantic: status zero versus nonzero, expected stream, required sections, prohibited details, and relative row order rather than complete presentation snapshots.

#### - [ ] CLI-P05-AC1 — Prove representative successful processes

Process tests cover empty inventory, ready config check, ordinary no-change apply, cleanup no-match dry-run/apply, and all four help commands with status `0`, successful results on stdout, and no failure diagnostics on stderr.

#### - [ ] CLI-P05-AC2 — Prove validation, configuration, and access failures

Process tests cover incompatible flags before configuration access, missing or invalid selected configuration, migration pending, and unavailable Calendar access with nonzero status, actionable privacy-safe stderr, and no false stdout success result.

#### - [ ] CLI-P05-AC3 — Prove progressive output under partial failure

Ordinary and cleanup process scenarios retain only confirmations for completed actions on stdout, write the privacy-safe partial or verification failure plus recovery guidance to stderr, return nonzero, stop later mutations, and perform no rollback.

#### - [ ] CLI-P05-V1 — Pass the executable smoke suite through the custom runner

Run `swift run CalRelayKitTests CalRelayCLISmokeTests` after ensuring the debug CLI executable is available, then confirm the same suite passes within `make check`.

### - [ ] CLI-P06 — Align documentation and complete automated validation

Update project references only where observable behavior or validation workflow changes, then run the complete code/tooling handoff gate.

**Dependencies:** `CLI-P01` through `CLI-P05`.

**Likely targets:**

- `docs/configuration.md`
- `docs/manual-validation.md`
- `docs/development.md` only if the canonical development workflow changes
- `README.md` only if its brief quick-start commands become inaccurate
- `Makefile`
- This plan

**Documentation notes:**

- Keep normative behavior in the accepted specification and avoid copying it wholesale into user documentation.
- Verify explicit override examples match implemented absolute, relative, and supported tilde semantics.
- Ensure cleanup guidance covers all-role summaries, per-role counts, transient review details, local point-in-time scope, and manual tombstone removal after migration completion.
- Keep the README brief and link to canonical detail.
- Make all four specification-listed help commands explicit smoke checks in the repository gate without replacing process-level tests.

#### - [ ] CLI-P06-AC1 — Align project references and validation entry points

Referenced commands, paths, cleanup workflow, and help checks match the implementation and accepted contracts without introducing a competing behavior source of truth.

#### - [ ] CLI-P06-AC2 — Preserve documentation and workspace hygiene

Documentation contains no sensitive local data, all referenced repository paths exist, agent-created changes remain unstaged, and the unrelated staged plan deletion remains untouched.

#### - [ ] CLI-P06-V1 — Pass complete automated gates

Run `make format-check`, `make check`, the four explicit CLI help invocations, and `git --no-pager diff HEAD --check`. Report any skipped or pre-existing failure accurately.

### - [ ] CLI-P07 — Complete authorized live validation and final handoff

Perform real EventKit checks only with explicit authorization and harmless dedicated calendars, then record complete or pending evidence honestly.

**Dependencies:** `CLI-P01` through `CLI-P06`.

**Execution boundary:** Live Calendar access and mutation are not authorized merely by implementing this plan. If authorization or suitable calendars are unavailable, leave the live checkpoint open and hand off the automated result with the limitation stated.

**Validation reference:** [`../manual-validation.md`](../manual-validation.md).

**Live scenarios:**

- Inventory and unavailable-access behavior without prompting.
- Ready config check and migration-pending config check.
- Ordinary dry-run and explanation action-sequence equivalence.
- Non-interactive ordinary apply, later provider-visible idempotency, rename/change, and no-change success.
- Cleanup dry-run, fresh non-interactive apply review, complete verification, local-scope wording, and manual tombstone handling.
- Partial application and recurring exact-occurrence behavior where safely reproducible.

#### - [ ] CLI-P07-AC1 — Record live EventKit evidence or an explicit blocker

Complete the harmless-calendar checklist when authorized, or identify the missing authorization/environment condition without treating deterministic tests as proof of real EventKit behavior.

#### - [ ] CLI-P07-V1 — Re-run affected gates and prepare final handoff

After any changes resulting from live validation, rerun the affected focused suites plus `make format-check` and `make check`, re-check Git status, and summarize completed work, pending live evidence, and unrelated preserved workspace changes.

## Acceptance coverage

| CLI acceptance checks | Primary plan evidence |
| --- | --- |
| `CLI-AC-01`–`CLI-AC-02` | `CLI-P01`, `CLI-P04`, `CLI-P05` |
| `CLI-AC-03` | Existing command validation plus `CLI-P04`, `CLI-P05` |
| `CLI-AC-04`–`CLI-AC-05` | `CLI-P03`, `CLI-P04` |
| `CLI-AC-06` | `CLI-P02`, `CLI-P03`, `CLI-P05` |
| `CLI-AC-07`–`CLI-AC-08` | `CLI-P04`, `CLI-P05` |
| `CLI-AC-09` | `CLI-P02`, `CLI-P04`, `CLI-P05` |
| `CLI-AC-10` | `CLI-P01`, `CLI-P04`, `CLI-P05` |
| `CLI-AC-11` | `CLI-P04`, `CLI-P05`, `CLI-P07` |
| `CLI-AC-12`–`CLI-AC-13` | `CLI-P03`, `CLI-P04`, `CLI-P05` |
| `CLI-AC-14` | `CLI-P02`, `CLI-P03`, `CLI-P04` |
| `CLI-AC-15` | `CLI-P02`, `CLI-P04`, `CLI-P05`, `CLI-P07` |

## Focused validation commands

Use exact registered custom-runner suite names while iterating:

```sh
swift run CalRelayKitTests ConfigurationFileSelectionTests
swift run CalRelayKitTests CalendarListCommandHandlerTests
swift run CalRelayKitTests ConfigCheckCommandHandlerTests
swift run CalRelayKitTests ReconcileCommandHandlerTests
swift run CalRelayKitTests CalendarCleanupAccessTests
swift run CalRelayKitTests CalendarAccessPrivacyTests
swift run CalRelayKitTests CalRelayContractTests
swift run CalRelayKitTests CalRelayCLISmokeTests
```

Final automated validation:

```sh
make format-check
make check
swift run calrelay --help
swift run calrelay calendars --help
swift run calrelay config check --help
swift run calrelay reconcile --help
git --no-pager diff HEAD --check
```

Do not use `swift test`; this repository uses the `CalRelayKitTests` executable runner. Do not use real EventKit as an ordinary automated check.

## Risks and mitigations

- **Test composition leaking into production:** guard fixed fake scenarios with a custom debug-only compilation condition, require explicit activation, and compile them out of release builds.
- **Presentation tests becoming brittle:** assert semantic content, stream destination, prohibited values, and row order rather than full exact text snapshots.
- **Cleanup summaries weakening shared boundaries:** derive zero-count role coverage from validated settings at the CLI handler/formatter boundary instead of adding presentation-only fields to domain cleanup planning.
- **Privacy regression:** use sentinel IDs, marker values, selectors, calendar titles, and event titles in tests and assert their absence on every prohibited output surface.
- **Accidental ordinary verification claim:** keep ordinary success tied to local ordered mutation confirmations and test that no post-apply verification wording or extra snapshot read appears.
- **Concurrent workspace changes:** re-read affected files and Git status before editing, leave agent-created changes unstaged, and preserve the existing staged deletion.
- **Real-calendar damage:** keep default tests fake-backed and run manual mutation only with explicit authorization and dedicated harmless calendars.

## Progress tracking

### Configuration-path slice

- [x] CLI-P01 — Complete explicit configuration-path resolution
- [x] CLI-P01-AC1 — Prove every accepted override form
- [x] CLI-P01-AC2 — Reject unsupported expansion without reinterpretation
- [x] CLI-P01-V1 — Pass focused configuration-selection tests

### Ordinary presentation slice

- [x] CLI-P02 — Align ordinary reconciliation output with ordered execution semantics
- [x] CLI-P02-AC1 — Prove exact ordinary presentation order
- [x] CLI-P02-AC2 — Prove truthful no-change output
- [x] CLI-P02-AC3 — Preserve successful-only confirmations and local apply completion
- [x] CLI-P02-V1 — Pass focused ordinary CLI tests

### Cleanup presentation slice

- [ ] CLI-P03 — Complete cleanup review, summaries, and migration guidance
- [ ] CLI-P03-AC1 — Prove complete role and count reporting
- [ ] CLI-P03-AC2 — Prove cleanup privacy and local-scope wording
- [ ] CLI-P03-AC3 — Prove direct apply and post-success guidance
- [ ] CLI-P03-V1 — Pass focused cleanup CLI tests

### Deterministic acceptance coverage

- [ ] CLI-P04 — Complete deterministic handler and acceptance evidence
- [ ] CLI-P04-AC1 — Map `CLI-AC-01` through `CLI-AC-06`
- [ ] CLI-P04-AC2 — Map `CLI-AC-07` through `CLI-AC-11`
- [ ] CLI-P04-AC3 — Map `CLI-AC-12` through `CLI-AC-15`
- [ ] CLI-P04-V1 — Pass the focused deterministic acceptance set

### Process-level coverage

- [ ] CLI-P05 — Add deterministic process-level stream and status tests
- [ ] CLI-P05-AC1 — Prove representative successful processes
- [ ] CLI-P05-AC2 — Prove validation, configuration, and access failures
- [ ] CLI-P05-AC3 — Prove progressive output under partial failure
- [ ] CLI-P05-V1 — Pass the executable smoke suite through the custom runner

### Documentation and automated gate

- [ ] CLI-P06 — Align documentation and complete automated validation
- [ ] CLI-P06-AC1 — Align project references and validation entry points
- [ ] CLI-P06-AC2 — Preserve documentation and workspace hygiene
- [ ] CLI-P06-V1 — Pass complete automated gates

### Live validation and handoff

- [ ] CLI-P07 — Complete authorized live validation and final handoff
- [ ] CLI-P07-AC1 — Record live EventKit evidence or an explicit blocker
- [ ] CLI-P07-V1 — Re-run affected gates and prepare final handoff

## Handoff

- **Plan readiness:** Ready.
- **Next executable task:** `CLI-P03` — complete cleanup review, summaries, privacy, and migration guidance.
- **Blocking product decisions:** None.
- **Conditional final checkpoint:** `CLI-P07` requires explicit authorization and suitable harmless dedicated calendars; it does not block automated implementation and validation through `CLI-P06`.
- **Deferred enhancements:** machine-readable output, new public commands or flags, stable failure-code categories, cross-process locking, provider APIs, and automatic marker-retirement editing remain outside this plan.
