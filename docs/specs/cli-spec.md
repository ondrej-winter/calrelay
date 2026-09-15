# Spec: CalRelay Command-Line Interface

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 15, 2026 after the calendar-access contract review; calendar discovery, configured readiness, and non-prompting CLI behavior changed.
- **Canonical artifact:** `docs/specs/cli-spec.md`.
- **Scope:** `calrelay` command behavior, user-facing output, and command validation.

## Required outcomes

### CLI-01 — Commands and safety controls

- The executable command name is `calrelay`.
- `calrelay calendars` requires no configuration and reports every EventKit-visible calendar with source/account, title, EventKit calendar ID, and writable/read-only status.
- Calendar-listing success means inventory discovery succeeded; it does not claim configuration validity or reconciliation readiness.
- `calrelay config check` uses the default configuration selection defined in [`configuration-spec.md`](configuration-spec.md); `--config <path>` overrides it.
- Config check validates the selected configuration and performs the non-mutating configured-topology readiness preflight defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- Reconciliation is dry-run by default and prints planned creates and deletes without mutating calendars.
- Dry-run performs the same configured-topology readiness preflight as config check and apply before reporting success.
- Apply-mode reconciliation occurs only when `--apply` is explicitly requested after configuration validation and the complete access preflight succeeds.
- `calrelay reconcile` uses the default configuration selection defined in [`configuration-spec.md`](configuration-spec.md); `--config <path>` overrides it.

### CLI-02 — Diagnostics and validation

- CLI commands never request Calendar access or trigger the macOS permission prompt. When full access is unavailable, they fail with guidance to use the setup/recovery surface in `CalRelay.app`.
- Command-facing configuration errors are actionable and privacy-safe.
- The missing-default error names the default location, the override option, and `docs/configuration.md`.
- Discovery, readiness, and partial-application output follows the disclosure rules in [`calendar-access-spec.md`](calendar-access-spec.md).
- CLI behavior delegates reusable relay behavior to `CalRelayKit`; option parsing and terminal presentation remain in the CLI adapter.

## Compatibility and breaking changes

- Revision 2 adds the nested `calrelay config check` command and makes its success the explicit CLI signal for configured readiness.
- `calrelay calendars` remains configuration-independent but must no longer prompt for Calendar access, and it displays EventKit calendar IDs by default.
- Dry-run now fails unless the complete selected topology passes the same full-access, readability, and writability preflight as apply.

## Validation

- `make check` is the local quality gate.
- `swift run calrelay --help`, `swift run calrelay calendars --help`, `swift run calrelay config check --help`, and `swift run calrelay reconcile --help` are smoke checks.
- Explicit local validation includes dry-run, apply, idempotency, rename/change, and harmless EventKit write checks.

## Acceptance checks

- **CLI-AC-01:** Calendar listing requires no configuration, never prompts, and lists all visible calendars with source/account, title, ID, and writability without making a readiness claim.
- **CLI-AC-02:** Config check uses the canonical default or explicit override, never mutates, and succeeds only when the complete configured topology is currently ready.
- **CLI-AC-03:** Dry-run and apply use the same access preflight; apply additionally requires explicit `--apply` and performs no mutation when preflight fails.
- **CLI-AC-04:** A missing selected configuration for config check or reconciliation fails before EventKit access, and explicit overrides preserve their selected path.
- **CLI-AC-05:** CLI access failures are non-prompting, actionable, and privacy-safe.