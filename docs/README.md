# CalRelay documentation

Use this index to find the canonical document for a task. Keeping each kind of
information in one place avoids duplicating product contracts, architectural
rationale, and operational instructions.

## Choose the right document

| Task | Start here |
| --- | --- |
| Configure calendars, markers, reconciliation, or scheduling | [Configuration](configuration.md) |
| Build, test, format, or validate the repository | [Development workflow](development.md) |
| Navigate source, tests, and documentation | [Repository layout](repository-layout.md) |
| Install, upgrade, verify, or uninstall the public beta | [Distribution](distribution.md) |
| Bootstrap, publish, resume, or recover a release | [Release operations](release-operations.md) |
| Review or change product behavior | [Specifications](specs/README.md) |
| Understand durable architecture and lifecycle decisions | [Architecture decisions](adr/README.md) |
| Follow delivery sequencing and implementation evidence | [Implementation plans](plans/README.md) |

## Documentation roles

- `docs/specs/` contains accepted capability-owned product and behavior
  contracts. Specifications are the source of truth for product behavior.
- `docs/adr/` records durable architecture, lifecycle, security, packaging, and
  operational decisions. ADRs explain rationale without replacing specifications.
- The project references directly under `docs/` explain current usage,
  configuration, development, distribution, and operations.
- `docs/plans/` contains non-normative delivery plans and implementation evidence.
  Plans must reference, rather than redefine, accepted contracts and decisions.

When documents disagree, resolve the inconsistency in the owning canonical
surface instead of adding another copy of the guidance.
