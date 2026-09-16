# Spec: CalRelay Command-Line Interface

## Specification record

- **Status:** Accepted.
- **Revision:** 7 — accepted on September 16, 2026 after the reconciliation stress-test interview; detailed action output was bound to execution order and delete-first non-interactive apply was retained.
- **Canonical artifact:** `docs/specs/cli-spec.md`.
- **Scope:** `calrelay` command behavior, user-facing output, command validation, and legacy-marker cleanup controls.

## Required outcomes

### CLI-01 — Commands and ordinary safety controls

- The executable command name is `calrelay`.
- `calrelay calendars` requires no configuration and reports every EventKit-visible calendar with source/account, title, EventKit calendar ID, and writable/read-only status.
- Calendar-listing success means inventory discovery succeeded; it does not claim configuration validity or reconciliation readiness.
- `calrelay config check` uses the default configuration selection defined in [`configuration-spec.md`](configuration-spec.md); `--config <path>` overrides it.
- `calrelay reconcile` uses the same default or explicit configuration selection.
- Ordinary `calrelay reconcile` is dry-run by default and prints every planned action in the exact execution order defined by [`reconciliation-spec.md`](reconciliation-spec.md) without mutating calendars.
- Ordinary `calrelay reconcile --apply` performs the planned mutations only after configuration validation and complete ordinary access preflight succeed.
- `--apply` is sufficient CLI authorization for mutation. Apply remains non-interactive and must not require an additional terminal confirmation.
- `calrelay reconcile --explain` is a supported non-mutating mode that explains the complete ordinary reconciliation computation as defined in [`reconciliation-spec.md`](reconciliation-spec.md).
- `--apply` and `--explain` are mutually exclusive. Supplying both fails during command validation before configuration selection, file access, or EventKit access.
- Config check, ordinary dry-run, apply, and explanation use the ordinary non-mutating configured-topology readiness preflight defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- A configuration with nonempty `legacyMarkers` blocks every ordinary reconciliation mode after structural validation, as defined in [`configuration-spec.md`](configuration-spec.md).

### CLI-02 — Legacy-marker cleanup mode

- `calrelay reconcile --cleanup-legacy` is the only CLI command mode that processes configured `legacyMarkers`. The app may expose the separate explicit workflow defined in [`macos-app-spec.md`](macos-app-spec.md); it uses the same reusable cleanup behavior and does not alter this command contract.
- Cleanup is dry-run by default and reports the exact legacy-marker deletions that would be attempted without mutating calendars.
- `calrelay reconcile --cleanup-legacy --apply` performs those deletions only after configuration validation and the complete cleanup preflight defined in [`calendar-access-spec.md`](calendar-access-spec.md) succeed.
- Cleanup mode is cleanup-only: it performs no ordinary creates, current-marker stale deletes, routing, or full ordinary explanation.
- Cleanup mode requires at least one configured legacy marker. An empty list fails nonzero with guidance and before EventKit access.
- `--cleanup-legacy` and `--explain` are mutually exclusive and fail during command validation before configuration selection, file access, or EventKit access.
- `--cleanup-legacy` may be combined with `--apply` and `--config`.
- Cleanup dry-run reports the product-defined cleanup range, configured roles covered, per-marker or per-role deletion counts, the local point-in-time scope, and one review row in execution order for every selected event containing its title, configured role, and start/end or all-day date range.
- Cleanup apply displays the fresh selected-event review rows before mutation, but `--apply` remains sufficient non-interactive authorization. The CLI recommends a prior dry-run but does not require a plan token, proof of review, or interactive confirmation.
- Cleanup review omits EventKit event and calendar IDs, source/title selectors, calendar titles, and marker values. Titles and time ranges are transient command output and must not be written to persistent logs.
- Cleanup apply reports success only after the post-mutation full-range verification required by [`calendar-access-spec.md`](calendar-access-spec.md) finds no matching legacy-marker events. A verification failure or remaining match returns nonzero while retaining accurate confirmations for completed deletions.
- Cleanup output must not claim global marker retirement. A successful no-change cleanup reports that no matching events were found in the loaded local snapshot; a successful apply reports that none appeared in its post-mutation verification snapshot.
- After successful cleanup, CalRelay does not edit the configuration; output directs the operator to remove tombstones only when the eventual-convergence migration is complete for their topology.

### CLI-03 — Process status and output streams

- Process status has stable binary semantics: `0` means the requested command completed according to its defined success condition; every unsuccessful or partially applied invocation returns nonzero.
- Individual nonzero values are not stable product-level failure categories.
- Successful command results are written to standard output. Failure diagnostics and recovery guidance are written to standard error.
- Exact wording, headings, input-event row ordering, and formatting may evolve unless a semantic output requirement is explicitly stated here or in an owning specification. Ordinary dry-run action rows, ordinary explanation planned-action rows, and cleanup review rows follow the normative execution order. Scripts must not be required to parse presentation text.
- Successful calendar discovery returns `0` even when EventKit reports zero visible calendars and writes an understandable empty-inventory result to standard output.
- Successful config check writes the selected configuration path and an explicit statement that the complete configured topology is currently ready to standard output.
- Migration-pending config check writes its selected path and safely determinable preflight failures plus migration guidance to standard error, returns nonzero, and does not print a readiness success statement.
- A ready ordinary dry-run or apply whose plan contains no executable actions returns `0` and reports that no changes are needed. A no-change apply is a successful ordinary reconciliation even though no mutation occurs.
- A successful cleanup dry-run or apply with no matching legacy-marker events returns `0` and reports the local no-match result without claiming global retirement.
- Apply writes an action-confirmation line to standard output only after that individual EventKit create or delete succeeds.
- Ordinary apply reports success after every action in the ordered plan is confirmed. It does not claim a post-apply verification read or guarantee that an immediate later provider read produces an empty plan.
- If a later ordinary or cleanup mutation fails, already emitted standard output remains an accurate record of confirmed mutations; the privacy-safe partial-application summary, failure category, and recovery guidance are written to standard error, and the process returns nonzero.

### CLI-04 — Full ordinary reconciliation explanation

- Explanation uses the same selected configuration, effective reconciliation window, ordinary configured-topology preflight, loaded calendar snapshot, and deterministic planning computation as ordinary dry-run.
- Explanation annotates the exact ordered plan returned by that shared computation. For the same loaded snapshot, its planned-action sequence must equal dry-run's sequence; explanation must not independently approximate or reimplement planning decisions.
- Successful explanation output has two semantic sections:
  1. every input event read from every configured calendar in the effective reconciliation window, with the complete classification required by [`reconciliation-spec.md`](reconciliation-spec.md); and
  2. every planned create and delete in execution order, with the causal links and classifications required by that specification.
- Successful explanation reports the effective reconciliation start and end boundaries and configured forward horizon used for the run.
- Successful explanation includes the EventKit event and calendar IDs required for within-output correlation by the reconciliation specification. Those IDs are diagnostic only and do not become selectors, equality keys, ownership markers, or fallback behavior.
- Explanation performs no mutation. If configuration, preflight, snapshot loading, or explanation generation fails, the command returns nonzero and does not emit a partial success explanation.

### CLI-05 — Permission, validation, privacy, and delegation

- CLI commands never request Calendar access or trigger the macOS permission prompt. When full access is unavailable, they fail with guidance to use the setup/recovery surface in `CalRelay.app`.
- Command-facing configuration errors are actionable and privacy-safe.
- For config check and every reconciliation mode, selected-file existence, parsing, and structural validation complete before EventKit access.
- Discovery, readiness, cleanup, and partial-application output follow the disclosure rules in [`calendar-access-spec.md`](calendar-access-spec.md).
- CLI behavior delegates reusable relay and cleanup behavior to `CalRelayKit`; option parsing and terminal presentation remain in the CLI adapter.

## Compatibility and breaking changes

- Revision 7 makes ordinary dry-run, ordinary explanation planned-action rows, and cleanup review rows follow actual execution order. Ordinary `--apply` remains sufficient non-interactive authorization despite the delete-first behavior defined by the reconciliation specification.
- Revision 7 defines ordinary CLI success as local confirmation of the ordered mutations, without a post-apply verification claim; cleanup retains verified no-match success.
- Revision 6 changes successful cleanup presentation from aggregate-only output to transient per-event title, configured-role, and time-range review. It retains the existing command arguments and treats `--cleanup-legacy --apply` as sufficient non-interactive mutation authorization.
- Revision 5 does not change CLI arguments, status, output, or mutation authorization. It clarifies that the CLI is no longer the product's only cleanup presentation after app cleanup is added.
- Revision 4 adds the explicit `--cleanup-legacy` reconciliation mode and makes it mutually exclusive with `--explain`.
- Nonempty `legacyMarkers` now block ordinary reconciliation and make config check return nonzero after ordinary preflight.
- Cleanup uses a separate full-range preflight and performs deletions only; it never silently combines migration with ordinary reconciliation.
- Successful cleanup review receives only the narrow transient detail exception defined by [`calendar-access-spec.md`](calendar-access-spec.md) and does not receive the EventKit-ID disclosure exception granted to successful ordinary explanation.
- Existing binary status, stdout/stderr routing, ordinary explanation, progressive mutation confirmation, and no-rollback rules remain in force.

## Validation

- `make check` is the local quality gate.
- `swift run calrelay --help`, `swift run calrelay calendars --help`, `swift run calrelay config check --help`, and `swift run calrelay reconcile --help` are smoke checks.
- Explicit local validation includes config check, ordinary dry-run, full explanation, apply, cleanup dry-run, cleanup apply with transient per-event review, no-change success, migration-pending gates, idempotency, rename/change, partial-application reporting, and harmless EventKit write checks.

## Acceptance checks

- **CLI-AC-01:** Calendar listing requires no configuration, never prompts, lists all visible calendars with source/account, title, ID, and writability without making a readiness claim, and returns `0` with an empty-inventory result when discovery succeeds with zero calendars.
- **CLI-AC-02:** Config check uses the canonical default or explicit override, never mutates, succeeds only when the complete configured topology is currently ready, and reports migration pending nonzero after ordinary preflight when tombstones exist.
- **CLI-AC-03:** Invalid `--apply --explain` and `--cleanup-legacy --explain` combinations fail before configuration or EventKit access.
- **CLI-AC-04:** Ordinary config check, dry-run, apply, and explanation use ordinary preflight; cleanup dry-run and apply use full-range cleanup preflight.
- **CLI-AC-05:** Cleanup requires at least one legacy marker, is dry-run by default, mutates only with `--apply`, and contains no ordinary creates or deletes.
- **CLI-AC-06:** Ready no-change ordinary and cleanup runs report their respective no-change conditions and return `0` without overstating scope; an empty ordinary plan counts as a successful reconciliation.
- **CLI-AC-07:** Process-level tests prove binary status semantics, successful-result output on standard output, failure diagnostics on standard error, and no requirement to parse exact presentation text.
- **CLI-AC-08:** An ordinary or cleanup mutation-phase failure returns nonzero, retains only post-success mutation confirmations on standard output, reports the privacy-safe partial result on standard error, stops later mutations, and performs no rollback.
- **CLI-AC-09:** Ordinary explanation is non-mutating, covers every input and planned action, may disclose IDs only on successful output, and has exactly the same ordered executable-action sequence as the shared ordinary dry-run plan for the loaded snapshot.
- **CLI-AC-10:** A missing or structurally invalid selected configuration fails before EventKit access, and explicit overrides preserve their selected path semantics.
- **CLI-AC-11:** CLI access failures are non-prompting, actionable, privacy-safe, written to standard error, and return nonzero.
- **CLI-AC-12:** Cleanup output reports the moving bounded range and local point-in-time result, shows each selected event's title, configured role, and time range, omits EventKit IDs and other prohibited details, never claims global or historical retirement, and reports apply success only after a no-match verification snapshot.
- **CLI-AC-13:** Direct cleanup `--apply` displays the fresh detailed plan and proceeds without interactive confirmation or proof of an earlier dry-run.
- **CLI-AC-14:** Ordinary dry-run, ordinary explanation planned-action rows, cleanup dry-run, and the fresh cleanup plan display actions in execution order while retaining presentation-text freedom outside that semantic sequence.
- **CLI-AC-15:** Direct ordinary `--apply` remains non-interactive and succeeds after confirming every ordered action without performing or claiming a post-apply verification read.
