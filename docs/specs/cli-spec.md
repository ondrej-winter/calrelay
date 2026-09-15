# Spec: CalRelay Command-Line Interface

## Specification record

- **Status:** Accepted.
- **Revision:** 3 — accepted on September 15, 2026 after a focused stress test of Revision 2; binary process status, output streams, apply progress, and full reconciliation explanation behavior changed.
- **Canonical artifact:** `docs/specs/cli-spec.md`.
- **Scope:** `calrelay` command behavior, user-facing output, and command validation.

## Required outcomes

### CLI-01 — Commands and safety controls

- The executable command name is `calrelay`.
- `calrelay calendars` requires no configuration and reports every EventKit-visible calendar with source/account, title, EventKit calendar ID, and writable/read-only status.
- Calendar-listing success means inventory discovery succeeded; it does not claim configuration validity or reconciliation readiness.
- `calrelay config check` uses the default configuration selection defined in [`configuration-spec.md`](configuration-spec.md); `--config <path>` overrides it.
- `calrelay reconcile` uses the default configuration selection defined in [`configuration-spec.md`](configuration-spec.md); `--config <path>` overrides it.
- `calrelay reconcile` is dry-run by default and prints planned creates and deletes without mutating calendars.
- `calrelay reconcile --apply` performs the planned mutations only after configuration validation and the complete access preflight succeeds.
- `--apply` is sufficient CLI authorization for mutation. Apply remains non-interactive and must not require an additional terminal confirmation.
- `calrelay reconcile --explain` is a supported non-mutating mode that explains the complete reconciliation computation as defined in [`reconciliation-spec.md`](reconciliation-spec.md).
- `--apply` and `--explain` are mutually exclusive. Supplying both fails during command validation before configuration selection, file access, or EventKit access.
- Config check, dry-run, apply, and explanation use the same non-mutating configured-topology readiness preflight defined in [`calendar-access-spec.md`](calendar-access-spec.md).

### CLI-02 — Process status and output streams

- Process status has stable binary semantics: `0` means the requested command completed according to its defined success condition; every unsuccessful or partially applied invocation returns nonzero.
- Individual nonzero values are not stable product-level failure categories.
- Successful command results are written to standard output. Failure diagnostics and recovery guidance are written to standard error.
- Exact wording, headings, row ordering, and formatting may evolve unless a semantic output requirement is explicitly stated here or in an owning specification. Scripts must not be required to parse presentation text.
- Successful calendar discovery returns `0` even when EventKit reports zero visible calendars and writes an understandable empty-inventory result to standard output.
- Successful config check writes the selected configuration path and an explicit statement that the complete configured topology is currently ready to standard output.
- A ready dry-run or apply whose plan contains no creates or deletes returns `0` and reports that no changes are needed.
- Apply writes an action-confirmation line to standard output only after that individual EventKit create or delete succeeds.
- If a later apply mutation fails, already emitted standard output remains an accurate record of confirmed mutations; the privacy-safe partial-application summary, failure category, and recovery guidance are written to standard error, and the process returns nonzero.

### CLI-03 — Full reconciliation explanation

- Explanation uses the same selected configuration, effective reconciliation window, configured-topology preflight, loaded calendar snapshot, and deterministic planning computation as dry-run.
- Explanation annotates the exact plan returned by that shared computation. For the same loaded snapshot, its planned creates and deletes must equal dry-run's plan; explanation must not independently approximate or reimplement planning decisions.
- Successful explanation output has two semantic sections:
  1. every input event read from every configured calendar in the effective reconciliation window, with the complete classifications defined in [`reconciliation-spec.md`](reconciliation-spec.md);
  2. every planned create and delete, with its causal relationship to the classified inputs and reconciliation rules.
- Planned creates identify the missing expected projection, cite the causal source EventKit event ID or IDs, and identify the destination EventKit calendar ID.
- Planned deletes identify the exact existing EventKit event ID and distinguish stale managed projections from surplus managed duplicates.
- Successful, explicitly requested explanation output may include EventKit event IDs and calendar IDs alongside event title, source/calendar name, start, end, and semantic reasons. This is the narrow disclosure exception defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- Explanation reports the effective reconciliation-window boundaries defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).

### CLI-04 — Diagnostics and validation

- CLI commands never request Calendar access or trigger the macOS permission prompt. When full access is unavailable, they fail with guidance to use the setup/recovery surface in `CalRelay.app`.
- Command-facing configuration errors are actionable and privacy-safe.
- The missing-default error names the default location, the override option, and `docs/configuration.md`.
- For config check and every reconciliation mode, selected-file existence, parsing, and structural validation complete before EventKit access.
- Discovery, readiness, and partial-application output follow the disclosure rules in [`calendar-access-spec.md`](calendar-access-spec.md).
- CLI behavior delegates reusable relay behavior to `CalRelayKit`; option parsing and terminal presentation remain in the CLI adapter.

## Compatibility and breaking changes

- Revision 3 makes `0` versus nonzero process status and standard-output versus standard-error routing part of the accepted CLI contract. It does not stabilize exact text or individual nonzero values.
- Revision 3 makes `reconcile --explain` a supported full-plan explanation mode rather than an eligibility-only diagnostic. Existing explanation implementations may require substantial changes.
- `--apply --explain` is now an invalid combination and must fail before configuration or EventKit access rather than silently choosing one mode.
- Apply output now confirms mutations progressively after each succeeds. A partially applied run preserves confirmed action lines on standard output, reports the failure on standard error, and returns nonzero.
- Successful `calendars` inventory and successful, explicitly requested `reconcile --explain` are the only CLI output surfaces allowed to disclose EventKit IDs.
- The effective window and default forward horizon changed as defined in [`configuration-spec.md`](configuration-spec.md) and [`projection-and-safety-spec.md`](projection-and-safety-spec.md).

## Validation

- `make check` is the local quality gate.
- `swift run calrelay --help`, `swift run calrelay calendars --help`, `swift run calrelay config check --help`, and `swift run calrelay reconcile --help` are smoke checks.
- Explicit local validation includes config check, dry-run, full explanation, apply, no-change success, idempotency, rename/change, partial-application reporting, and harmless EventKit write checks.

## Acceptance checks

- **CLI-AC-01:** Calendar listing requires no configuration, never prompts, lists all visible calendars with source/account, title, ID, and writability without making a readiness claim, and returns `0` with an empty-inventory result when discovery succeeds with zero calendars.
- **CLI-AC-02:** Config check uses the canonical default or explicit override, never mutates, succeeds only when the complete configured topology is currently ready, and reports the selected path plus complete-topology readiness on standard output.
- **CLI-AC-03:** Supplying `--apply` and `--explain` together fails nonzero during command validation before configuration or EventKit access.
- **CLI-AC-04:** Config check, dry-run, apply, and explanation use the same access preflight; apply additionally requires explicit `--apply`, requires no second prompt, and performs no mutation when preflight fails.
- **CLI-AC-05:** A ready no-change dry-run or apply reports no changes and returns `0`.
- **CLI-AC-06:** Process-level tests prove binary status semantics, successful-result output on standard output, failure diagnostics on standard error, and no requirement to parse exact presentation text.
- **CLI-AC-07:** A mutation-phase failure returns nonzero, retains only post-success mutation confirmations on standard output, reports the privacy-safe partial result on standard error, stops later mutations, and performs no rollback.
- **CLI-AC-08:** Explanation is non-mutating, covers every input event and every planned action, uses the accepted semantic classifications, may disclose IDs only on successful output, and has exactly the same creates and deletes as the shared dry-run plan for the loaded snapshot.
- **CLI-AC-09:** A missing or structurally invalid selected configuration for config check or reconciliation fails before EventKit access, and explicit overrides preserve their selected path.
- **CLI-AC-10:** CLI access failures are non-prompting, actionable, privacy-safe, written to standard error, and return nonzero.
