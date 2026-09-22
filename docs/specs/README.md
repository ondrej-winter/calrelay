# CalRelay specifications

This directory contains the accepted, capability-owned product and behavior contracts for CalRelay. Update the specification that owns a behavior rather than adding requirements to an umbrella MVP or lifecycle document.

## Canonical capability specifications

- [`calendar-access-spec.md`](calendar-access-spec.md): Calendar permission, discovery, ordinary and cleanup preflight, runtime access failures, writability, and the EventKit boundary.
- [`reconciliation-spec.md`](reconciliation-spec.md): visible-set reconciliation, deterministic cleanup planning, idempotency, and exact explanation.
- [`projection-and-safety-spec.md`](projection-and-safety-spec.md): source-event inclusion, exact marker recognition, projection fields, and deletion ownership rules.
- [`routing-spec.md`](routing-spec.md): hub/work marker routing, eventual-convergence migration, and multi-computer topology.
- [`configuration-spec.md`](configuration-spec.md): strict YAML settings, markers, selectors, path discovery, validation, and migration cleanup coverage.
- [`cli-spec.md`](cli-spec.md): `calrelay` discovery, config check, ordinary dry-run/apply/explanation, legacy cleanup, and CLI-facing diagnostics.
- [`macos-app-spec.md`](macos-app-spec.md): the control panel, manual sync and cleanup, standing authorization, launch-at-login, scheduling, freshness, recovery state, user notifications, and closed-app boundary.

Together, these documents define the current EventKit MVP.

## Historical specification migrations

| Former specification | Replacement canonical specifications |
| --- | --- |
| `calrelay-eventkit-mvp-spec.md` | `calendar-access-spec.md`, `reconciliation-spec.md`, `projection-and-safety-spec.md`, `routing-spec.md`, `configuration-spec.md`, and `cli-spec.md` |
| `calrelay-default-configuration-path-spec.md` | `configuration-spec.md` and `cli-spec.md` |
| `calrelay-app-lifecycle-spec.md` | `macos-app-spec.md` |

The former specification files have been removed. Use the listed canonical specifications for current requirements and behavior changes.

## Cross-slice rules

- Calendar permission, EventKit types, calendar IDs, stores, and mutation mechanics remain at adapter or app/bootstrap boundaries.
- Domain and application APIs remain deterministic and independent of EventKit, filesystem-path resolution, UI frameworks, and live external provider APIs.
- A capability that crosses slices must reference the owning specification instead of duplicating the other slice's normative requirement.
- Automation requires the relevant explicit decision in [`macos-app-spec.md`](macos-app-spec.md). The normal-app launch-at-login decision is recorded in [`../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md`](../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md); closed-app operation requires a later explicit decision and a new ADR.
