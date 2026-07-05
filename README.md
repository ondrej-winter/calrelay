# calrelay

CalRelay is a local macOS Swift CLI and app that uses Apple Calendar/EventKit-visible calendars to relay availability blockers across multiple work calendars.

The current implementation source of truth is the [CalRelay EventKit MVP spec](docs/specs/calrelay-eventkit-mvp-spec.md), derived from the original idea in [`docs/ideas/calrelay-eventkit-mvp.md`](docs/ideas/calrelay-eventkit-mvp.md).

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
swift run calrelay reconcile
```

## Documentation

- [Development workflow](docs/development.md): local requirements, build/test commands, formatting, linting, and package notes.
- [Repository layout](docs/repository-layout.md): source targets, test organization, and the `CalRelayKit` integration boundary.
- [Configuration](docs/configuration.md): YAML file location, schema, selector semantics, CLI reconciliation commands, and safety notes.
- [Manual validation](docs/manual-validation.md): app-backed EventKit validation with harmless local test calendars.
- [App lifecycle spec](docs/specs/calrelay-app-lifecycle-spec.md): current app lifecycle behavior and staged direction.
- [EventKit MVP spec](docs/specs/calrelay-eventkit-mvp-spec.md): canonical product and behavior specification.

