# CalRelay specifications

This directory contains the accepted, capability-owned product and behavior contracts for CalRelay. Update the specification that owns a behavior rather than adding requirements to an umbrella MVP or lifecycle document.

## Canonical capability specifications

- [`calendar-access-spec.md`](calendar-access-spec.md): Calendar permission, discovery, writability, and the EventKit boundary.
- [`reconciliation-spec.md`](reconciliation-spec.md): visible-set reconciliation, idempotency, and deterministic core behavior.
- [`projection-and-safety-spec.md`](projection-and-safety-spec.md): source-event inclusion, projection fields, and deletion ownership rules.
- [`routing-spec.md`](routing-spec.md): hub/work routing and multi-computer topology.
- [`configuration-spec.md`](configuration-spec.md): YAML settings, selectors, default-path discovery, and configuration validation.
- [`cli-spec.md`](cli-spec.md): `calrelay` command behavior, dry-run/apply controls, and CLI-facing diagnostics.
- [`macos-app-spec.md`](macos-app-spec.md): the control panel, menu bar, manual sync, scheduling, notifications, and background-operation gates.

Together, these documents define the current EventKit MVP. The original idea remains at [`../ideas/calrelay-eventkit-mvp.md`](../ideas/calrelay-eventkit-mvp.md).

## Migration from umbrella specifications

| Former specification | Replacement canonical specifications |
| --- | --- |
| `calrelay-eventkit-mvp-spec.md` | `calendar-access-spec.md`, `reconciliation-spec.md`, `projection-and-safety-spec.md`, `routing-spec.md`, `configuration-spec.md`, and `cli-spec.md` |
| `calrelay-default-configuration-path-spec.md` | `configuration-spec.md` and `cli-spec.md` |
| `calrelay-app-lifecycle-spec.md` | `macos-app-spec.md` |

The former paths remain as compatibility stubs for repository history and inbound links. They are no longer authoritative for new behavior changes.

## Cross-slice rules

- Calendar permission, EventKit types, calendar IDs, stores, and mutation mechanics remain at adapter or app/bootstrap boundaries.
- Domain and application APIs remain deterministic and independent of EventKit, filesystem-path resolution, UI frameworks, and live external provider APIs.
- A capability that crosses slices must reference the owning specification instead of duplicating the other slice's normative requirement.
- Automation requires the relevant explicit decision in [`macos-app-spec.md`](macos-app-spec.md); closed-app operation additionally requires an ADR.
