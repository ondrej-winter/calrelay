# Superseded: CalRelay Default Configuration Path

## Specification record

- **Status:** Superseded on September 14, 2026.
- **Former canonical artifact:** `docs/specs/calrelay-default-configuration-path-spec.md`.
- **Reason:** Default-path behavior now belongs with the YAML settings and configuration-discovery contract, while CLI interaction belongs with the command-line specification. This is a documentation reorganization only; no configuration behavior changed.

## Canonical replacements

- [`configuration-spec.md`](configuration-spec.md): canonical path, YAML settings, selectors, validation, filesystem boundaries, and future app configuration status.
- [`cli-spec.md`](cli-spec.md): default command behavior, `--config <path>`, and CLI-facing diagnostics.

See [`README.md`](README.md) for the full capability index.