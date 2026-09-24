# CLI specification implementation plan

## Plan record

- **Status:** Complete; `CLI-P08` through `CLI-P14` have current passing evidence.
  Optional live EventKit validation in `CLI-P07` was not performed.
- **Prepared:** September 24, 2026.
- **Canonical requirements:** [`../specs/cli-spec.md`](../specs/cli-spec.md),
  revision 7, accepted September 16, 2026.
- **Related accepted contracts:**
  [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md),
  [`../specs/configuration-spec.md`](../specs/configuration-spec.md),
  [`../specs/reconciliation-spec.md`](../specs/reconciliation-spec.md),
  [`../specs/projection-and-safety-spec.md`](../specs/projection-and-safety-spec.md),
  and [`../specs/routing-spec.md`](../specs/routing-spec.md).
- **Current state:** The earlier plan at this path completed automated CLI
  implementation through `CLI-P06` and left only conditional live validation in
  `CLI-P07`. It was removed on September 22, 2026 after that handoff. Current HEAD
  already contains the command wrappers, reusable handlers and formatters,
  deterministic process-test composition, and acceptance-oriented tests. The
  material later shared-core change is routing correction `94352fd`, which
  preserves personal-marked hub events during ordinary reconciliation.
- **Readiness:** Ready. Requirements, architecture, likely targets, sequencing,
  and validation commands are known. There is no unresolved product decision.

## Outcome

Demonstrate that current HEAD satisfies `CLI-01` through `CLI-05` and
`CLI-AC-01` through `CLI-AC-15`. If verification exposes a defect, retain the
failing regression test and make the smallest correction that restores the
accepted contract.

If all focused and complete gates pass, the correct result is no production-code
change and a current verified-compliance record, not a speculative rewrite.

## Scope boundaries

### In scope

- `calrelay calendars`, `calrelay config check`, and every `calrelay reconcile`
  mode defined by the accepted CLI contract.
- Configuration selection and validation ordering before EventKit access.
- Ordinary and cleanup preflight selection, non-interactive mutation
  authorization, ordered action presentation, no-change success, progressive
  confirmations, partial-failure behavior, and cleanup verification.
- Process status, standard-output and standard-error routing, privacy-safe
  diagnostics, and successful explanation disclosure.
- Thin ArgumentParser wrappers in `CalRelayCLI` and reusable CLI support in
  `CalRelayKit`.
- Deterministic handler, contract, and executable-process evidence.
- CLI-facing project documentation when current behavior is missing or stale.

### Out of scope

- New commands, flags, configuration fields, or stable numeric failure codes.
- Interactive confirmations, plan tokens, or proof of an earlier dry-run.
- Machine-readable output formats or a requirement to parse presentation text.
- Reconciliation, routing, ownership, marker, or cleanup-range changes not
  required by a failing CLI acceptance check.
- Automatic configuration editing or removal of `legacyMarkers`.
- New dependencies, architecture decisions, or unrelated refactoring.
- Real EventKit access in the ordinary automated test gate.

## Change policy

1. Run existing acceptance evidence before changing production code.
2. Add or strengthen a deterministic failing test for every demonstrated gap.
3. Make the smallest implementation correction that passes that test.
4. Keep `CalRelayCLI` limited to option parsing, terminal output, and composition;
   keep reusable behavior in `CalRelayKit`.
5. Preserve existing stdout confirmations when a later mutation fails.
6. Keep default tests fake-backed, deterministic, isolated, and offline.
7. Do not update an accepted specification unless implementation reveals a real
   contract conflict requiring explicit approval.

## Historical progress

The following identifiers and completion state are preserved from the previous
plan rather than being represented as new work:

- [x] **CLI-P01:** Complete explicit configuration-path resolution.
- [x] **CLI-P02:** Align ordinary output with ordered execution semantics.
- [x] **CLI-P03:** Complete cleanup review, summaries, and migration guidance.
- [x] **CLI-P04:** Complete deterministic handler and acceptance evidence.
- [x] **CLI-P05:** Add deterministic process-level stream and status tests.
- [x] **CLI-P06:** Align documentation and complete the automated handoff gate.
- [ ] **CLI-P07:** Complete explicitly authorized live EventKit validation using
  harmless dedicated calendars. This remains conditional and does not block
  automated conformance.

## Requirements traceability

| Acceptance checks | Current verification owner |
| --- | --- |
| `CLI-AC-01`–`CLI-AC-03` | `CLI-P08`, `CLI-P09`, `CLI-P12` |
| `CLI-AC-04`–`CLI-AC-06` | `CLI-P08`, `CLI-P09`, `CLI-P10`, `CLI-P11` |
| `CLI-AC-07`–`CLI-AC-08` | `CLI-P10`, `CLI-P11`, `CLI-P12` |
| `CLI-AC-09` | `CLI-P10`, `CLI-P12` |
| `CLI-AC-10`–`CLI-AC-11` | `CLI-P09`, `CLI-P12` |
| `CLI-AC-12`–`CLI-AC-13` | `CLI-P11`, `CLI-P12` |
| `CLI-AC-14`–`CLI-AC-15` | `CLI-P10`, `CLI-P11`, `CLI-P12` |

### Current acceptance baseline — September 24, 2026

Current HEAD has deterministic evidence for every required outcome and all
fifteen CLI acceptance checks. No production defect or automated-evidence gap
was identified. The focused union passed in one custom-runner invocation:

```sh
swift run CalRelayKitTests ConfigurationFileSelectionTests CalendarListCommandHandlerTests ConfigCheckCommandHandlerTests ReconcileCommandHandlerTests CalendarNoPromptContractTests CalendarAccessPreflightTests CalendarCleanupAccessTests CalendarAccessPrivacyTests CalendarMutationExecutorTests EventKitExactEventOccurrenceResolverTests RoutingSpecificationTests CalRelayContractTests CalRelayCLISmokeTests
```

The command completed successfully with `CalRelayKitTests passed`. SwiftPM
emitted only non-failing local Command Line Tools linker search-path warnings.

| Acceptance checks | Current evidence | Gap |
| --- | --- | --- |
| `CLI-AC-01`–`CLI-AC-03` | `ConfigurationFileSelectionTests`, `CalendarListCommandHandlerTests`, `ConfigCheckCommandHandlerTests`, `CalendarNoPromptContractTests`, `CalRelayCLISmokeTests` | None. |
| `CLI-AC-04`–`CLI-AC-06` | `ConfigCheckCommandHandlerTests`, `ReconcileCommandHandlerTests`, `CalendarAccessPreflightTests`, `CalendarCleanupAccessTests`, `CalRelayCLISmokeTests` | None. |
| `CLI-AC-07`–`CLI-AC-08` | `CalendarMutationExecutorTests`, `CalendarAccessPrivacyTests`, `ReconcileCommandHandlerTests`, `CalRelayCLISmokeTests` | None. |
| `CLI-AC-09` | `ReconcileCommandHandlerTests`, `CalRelayContractTests`, `CalRelayCLISmokeTests` | None. |
| `CLI-AC-10`–`CLI-AC-11` | `ConfigurationFileSelectionTests`, `ConfigCheckCommandHandlerTests`, `ReconcileCommandHandlerTests`, `CalendarNoPromptContractTests`, `CalRelayCLISmokeTests` | None. |
| `CLI-AC-12`–`CLI-AC-13` | `ReconcileCommandHandlerTests`, `CalendarCleanupAccessTests`, `CalendarAccessPrivacyTests`, `CalRelayCLISmokeTests` | None. |
| `CLI-AC-14`–`CLI-AC-15` | `ReconcileCommandHandlerTests`, `CalendarMutationExecutorTests`, `RoutingSpecificationTests`, `CalRelayContractTests`, `CalRelayCLISmokeTests` | None. |

## Execution order

`CLI-P08` → `CLI-P09` → `CLI-P10` → `CLI-P11` → `CLI-P12` →
`CLI-P13` → `CLI-P14`

Tasks may complete with no production change when current evidence passes.
`CLI-P07` remains a separate conditional live checkpoint.

## Current-HEAD verification tasks

### CLI-P08 — Re-establish the acceptance baseline

Map every accepted outcome and acceptance check to current source and evidence,
then run the focused registered suites before editing production code.

**Likely targets:** this plan, existing CLI tests, and adjacent shared contract
tests. Production source is not a target unless a test fails.

- [x] **CLI-P08-AC1:** Every required outcome and acceptance check maps to
  current implementation and observable deterministic or explicitly manual
  evidence.
- [x] **CLI-P08-AC2:** Historical completed work is preserved, and existing
  behavior is not scheduled for speculative rewriting.
- [x] **CLI-P08-AC3:** Every failure or evidence gap identifies the downstream
  task that owns its resolution.
- [x] **CLI-P08-V1:** The focused baseline suites pass, or exact failures are
  recorded before implementation begins.

**Passing evidence:** The current acceptance table above maps the full contract.
The focused union passed without a failure or evidence gap, so no production
task was opened and no regression test was required.

### CLI-P09 — Verify command, configuration, inventory, and preflight boundaries

Verify executable and command names, configuration-independent inventory,
canonical and explicit configuration selection, early option validation,
configuration-before-EventKit ordering, config-check migration behavior, and
the no-prompt authorization boundary.

**Likely targets if a defect is demonstrated:** `Sources/CalRelayCLI/`,
`CalendarListCommandHandler.swift`, `CalendarListFormatter.swift`,
`ConfigCheckCommandHandler.swift`, `ConfigurationFileSelection.swift`, and their
focused tests.

- [x] **CLI-P09-AC1:** `CLI-AC-01`, `CLI-AC-02`, `CLI-AC-03`, `CLI-AC-10`, and
  `CLI-AC-11` have current deterministic evidence.
- [x] **CLI-P09-AC2:** Missing or invalid selected configuration and invalid flag
  combinations fail before EventKit access.
- [x] **CLI-P09-AC3:** No CLI operation requests Calendar permission.
- [x] **CLI-P09-V1:** Configuration-selection, inventory, config-check,
  no-prompt, and relevant process suites pass.

**Passing evidence:** `ConfigurationFileSelectionTests`,
`CalendarListCommandHandlerTests`, `ConfigCheckCommandHandlerTests`,
`ReconcileCommandHandlerTests`, `CalendarNoPromptContractTests`, and
`CalRelayCLISmokeTests` passed in the focused union. No command, configuration,
inventory, or authorization-boundary change was required.

### CLI-P10 — Verify ordinary dry-run, apply, and explanation

Verify that ordinary presentation and mutation consume the authoritative ordered
actions, empty plans succeed, direct apply is non-interactive, confirmations are
post-success, partial failures stop without rollback, ordinary success performs
no verification read, and explanation shares the dry-run computation and action
sequence.

**Likely targets if a defect is demonstrated:** `ReconcileCommandHandler.swift`,
`ReconciliationPlanFormatter.swift`, `EventExplanationFormatter.swift`,
`CalendarMutationConfirmationFormatter.swift`, and their focused tests. Change a
shared application use case only when the failing evidence identifies a shared
defect.

- [x] **CLI-P10-AC1:** Dry-run, explanation action rows, and apply execution share
  the authoritative ordered action sequence.
- [x] **CLI-P10-AC2:** Empty and nonempty apply satisfy the local ordinary
  completion semantics without a verification claim.
- [x] **CLI-P10-AC3:** Partial failures retain only confirmed output, stop later
  mutations, perform no rollback, and keep diagnostics privacy-safe.
- [x] **CLI-P10-AC4:** Explanation is complete, non-mutating, plan-equivalent,
  and emits no partial success output on failure.
- [x] **CLI-P10-V1:** Reconciliation-handler, mutation-executor, contract,
  routing, privacy, and relevant process suites pass.

**Passing evidence:** `ReconcileCommandHandlerTests`,
`CalendarMutationExecutorTests`, `CalendarAccessPrivacyTests`,
`RoutingSpecificationTests`, `CalRelayContractTests`, and
`CalRelayCLISmokeTests` passed. The post-handoff personal-marker routing
correction remains covered through the shared ordinary computation; no CLI
formatter or handler correction was needed.

### CLI-P11 — Verify explicit legacy-marker cleanup

Verify the separate delete-only workflow, full-range preflight, required legacy
markers, ordered transient review, disclosure restrictions, direct
non-interactive apply, progressive confirmation, complete verification snapshot,
truthful no-match scope, and manual tombstone-removal guidance.

**Likely targets if a defect is demonstrated:** `ReconcileCommandHandler.swift`,
`CalendarCleanupFormatter.swift`, cleanup application use cases only for shared
defects, and their focused tests.

- [x] **CLI-P11-AC1:** Cleanup remains explicit, delete-only, dry-run by default,
  and uses the complete cleanup window.
- [x] **CLI-P11-AC2:** Review content, order, privacy, and local scope satisfy
  `CLI-AC-12` through `CLI-AC-14`.
- [x] **CLI-P11-AC3:** Apply success requires a no-match verification snapshot;
  partial failure retains accurate confirmations without rollback.
- [x] **CLI-P11-V1:** Reconciliation-handler, cleanup-access, privacy,
  exact-occurrence, and relevant process suites pass.

**Passing evidence:** `ReconcileCommandHandlerTests`,
`CalendarCleanupAccessTests`, `CalendarAccessPrivacyTests`,
`EventKitExactEventOccurrenceResolverTests`, and `CalRelayCLISmokeTests` passed.
No cleanup selection, presentation, mutation, verification, or disclosure change
was required.

### CLI-P12 — Verify process semantics and test-composition isolation

Verify binary status, stdout/stderr routing, progressive output, representative
success and failure scenarios, semantic rather than exact-text assertions, and
debug-only explicit activation of deterministic process fixtures.

**Likely targets if evidence is missing:** `CalendarCLIComposition.swift`,
`CalRelayCLISmokeTests.swift`, `Package.swift`, and `Makefile` only when a
required smoke entry is absent.

- [x] **CLI-P12-AC1:** `CLI-AC-07` has current executable-process evidence.
- [x] **CLI-P12-AC2:** Representative success, validation, configuration,
  access, migration, explanation, apply, cleanup, and partial-failure paths are
  covered at process level.
- [x] **CLI-P12-AC3:** Test-only composition cannot be activated in a release
  build.
- [x] **CLI-P12-V1:** `CalRelayCLISmokeTests` and all four help smoke commands
  pass.
- [x] **CLI-P12-V2:** Not applicable — neither `Package.swift` nor process-test
  composition changed in this verification pass.

**Passing evidence:** `CalRelayCLISmokeTests` passed and exercised root,
calendar-listing, configuration-check, and reconciliation help together with
representative success and failure processes. `Package.swift` still defines
`CALRELAY_CLI_PROCESS_TESTING` only for debug configuration, and fixed scenarios
still require explicit `CALRELAY_PROCESS_TESTING=1` activation.

### CLI-P13 — Align CLI-facing documentation

Update project references only when verified behavior changes or inspection
reveals stale usage. Keep `README.md` brief and keep implementation detail out of
accepted specifications.

**Potential targets:** `README.md`, `docs/configuration.md`, and
`docs/development.md`.

- [x] **CLI-P13-AC1:** CLI usage and validation references agree with verified
  behavior.
- [x] **CLI-P13-AC2:** No unnecessary product-contract or architecture change is
  introduced.
- [x] **CLI-P13-V1:** Referenced paths and commands exist, and documentation
  changes pass `git --no-pager diff HEAD --check`.

**Passing evidence:** `README.md`, `docs/configuration.md`,
`docs/development.md`, the `Makefile`, and the package target graph already agree
with the verified CLI. No user-facing project-reference change was needed. The
new plan diff was whitespace-clean before the final gate.

### CLI-P14 — Complete validation and handoff

Run the complete repository gate after focused checks and record actual evidence.

- [x] **CLI-P14-AC1:** All fifteen CLI acceptance checks have current evidence;
  live-only evidence remains explicitly separate.
- [x] **CLI-P14-AC2:** No unrelated behavior, dependency, accepted
  specification, app UI, or workspace content changed.
- [x] **CLI-P14-AC3:** Not applicable — focused verification found no production
  defect, so no implementation correction or new regression test was required.
- [x] **CLI-P14-V1:** `make format-check` passes.
- [x] **CLI-P14-V2:** `make check` passes.
- [x] **CLI-P14-V3:** All explicit CLI help smoke commands pass.
- [x] **CLI-P14-V4:** `git --no-pager diff HEAD --check` passes and final Git
  status is recorded.
- [x] **CLI-P14-V5:** Not applicable — no app source, app resource, app-bundle
  script, accessibility contract, fake UI composition, or UI-test harness changed.

**Passing evidence (September 24, 2026):** Final automated validation completed
successfully:

```sh
make format-check
make check
git --no-pager diff HEAD --check
```

`make format-check` returned success. It reported existing warning-only
formatting diagnostics in unchanged Swift files and made no changes. `make check`
completed with exit status zero: SwiftLint found zero violations in 373 files,
the SwiftPM build succeeded, `CalRelayKitTests` passed, and the root, calendar
inventory, configuration check, and reconciliation help smoke checks succeeded.
The build emitted non-failing local Command Line Tools linker search-path
warnings.

The focused acceptance union and complete gate found no CLI conformance defect.
The final diff adds only this implementation and verification record; no
production source, test, package, dependency, accepted specification, app, or
user-facing project reference changed. No live EventKit access or calendar
mutation was performed.

## Focused validation commands

```sh
swift run CalRelayKitTests ConfigurationFileSelectionTests
swift run CalRelayKitTests CalendarListCommandHandlerTests
swift run CalRelayKitTests ConfigCheckCommandHandlerTests
swift run CalRelayKitTests ReconcileCommandHandlerTests
swift run CalRelayKitTests CalendarNoPromptContractTests
swift run CalRelayKitTests CalendarAccessPreflightTests
swift run CalRelayKitTests CalendarCleanupAccessTests
swift run CalRelayKitTests CalendarAccessPrivacyTests
swift run CalRelayKitTests CalendarMutationExecutorTests
swift run CalRelayKitTests EventKitExactEventOccurrenceResolverTests
swift run CalRelayKitTests RoutingSpecificationTests
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
git --no-pager status --short --branch
```

Do not substitute `swift test`; this repository uses the `CalRelayKitTests`
executable runner. Do not use real EventKit as an ordinary automated check.

## Risks and mitigations

- **Duplicate implementation:** require failing current-HEAD evidence before
  production edits.
- **Shared-core regression:** use test-first corrections and run adjacent app and
  application contract suites when shared code changes.
- **Routing regression:** include `RoutingSpecificationTests` because the latest
  material shared change corrected personal-marker routing behavior.
- **Privacy leakage:** use sentinel IDs, marker values, selectors, calendar
  titles, and event titles and assert their absence from prohibited output.
- **Incorrect convergence claim:** ordinary apply remains locally complete after
  confirmations; only cleanup performs a verification read.
- **Cleanup/ordinary mixing:** retain separate use cases and prove cleanup never
  performs ordinary creates or stale-current-marker deletes.
- **Brittle presentation tests:** assert semantic content, streams, prohibited
  values, and row order rather than complete exact output.
- **Test fixture leakage:** keep fixed process fixtures explicitly activated and
  compiled only under the debug-only testing condition.
- **Real-calendar damage:** keep automated checks fake-backed and require explicit
  authorization plus harmless dedicated calendars for `CLI-P07`.

## Next executable work

No automated CLI implementation work remains. `CLI-P07` may be performed
separately only with explicit authorization and harmless dedicated calendars;
record live observations separately and do not revise the deterministic pass
into a claim about live provider behavior.