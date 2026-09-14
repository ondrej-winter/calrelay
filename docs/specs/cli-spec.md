# Spec: Reconciliation Command-Line Interface

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — split from the accepted EventKit MVP and default-path specifications on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/cli-spec.md`.
- **Scope:** `calrelay` command behavior, user-facing output, and command validation.

## Required outcomes

### CLI-01 — Commands and safety controls

- The executable command name is `calrelay`.
- The calendar-listing command reports calendars, sources/accounts, and writable/read-only status.
- Reconciliation is dry-run by default and prints planned creates and deletes without mutating calendars.
- Apply-mode reconciliation occurs only when `--apply` is explicitly requested after configuration validation succeeds.
- `calrelay reconcile` uses the default configuration selection defined in [`configuration-spec.md`](configuration-spec.md); `--config <path>` overrides it.

### CLI-02 — Diagnostics and validation

- Command-facing configuration errors are actionable and privacy-safe.
- The missing-default error names the default location, the override option, and `docs/configuration.md`.
- CLI behavior delegates reusable relay behavior to `CalRelayKit`; option parsing and terminal presentation remain in the CLI adapter.

## Validation

- `make check` is the local quality gate.
- `swift run calrelay --help` and `swift run calrelay reconcile --help` are smoke checks.
- Explicit local validation includes dry-run, apply, idempotency, rename/change, and harmless EventKit write checks.

## Acceptance checks

- **CLI-AC-01:** Calendar listing and dry-run output work without mutation; apply requires `--apply`.
- **CLI-AC-02:** Missing default configuration fails before EventKit access and explicit configuration overrides preserve their selected path.