# calrelay

CalRelay is a local macOS Swift CLI and app that uses Apple Calendar/EventKit-visible calendars to relay availability blockers across multiple work calendars.

The current implementation source of truth is the feature-sliced [CalRelay specifications index](docs/specs/README.md).

## Quick start

Use the `Makefile` as the canonical local tooling entrypoint:

```sh
make check
make app
swift run calrelay --help
```

Build and open the app bundle when you need macOS Calendar permission and EventKit visibility checks:

```sh
open .build/CalRelay.app
```

Everyday CLI reconciliation reads `~/.config/calrelay/config.yaml` by default and is dry-run unless `--apply` is passed:

```sh
swift run calrelay calendars
swift run calrelay config check
swift run calrelay reconcile
```

Use the app's explicit setup/recovery action when full Calendar access is unavailable. CLI commands inspect permission state and never trigger the macOS Calendar prompt.

## Documentation

- [Development workflow](docs/development.md): local requirements, build/test commands, formatting, linting, and package notes.
- [Repository layout](docs/repository-layout.md): source targets, test organization, and the `CalRelayKit` integration boundary.
- [Configuration](docs/configuration.md): YAML file location, schema, selector semantics, CLI reconciliation commands, and safety notes.
- [Specifications](docs/specs/README.md): canonical feature-owned product, relay, configuration, CLI, and macOS app behavior contracts.
- [Architecture decisions](docs/adr/README.md): durable architecture, lifecycle, packaging, and testing decisions.

