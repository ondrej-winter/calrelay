# calrelay

CalRelay is a local macOS Swift CLI and app that uses Apple Calendar/EventKit-visible calendars to relay availability blockers across multiple work calendars.

The current implementation source of truth is the [CalRelay EventKit MVP spec](docs/specs/calrelay-eventkit-mvp-spec.md), derived from the original idea in [`docs/ideas/calrelay-eventkit-mvp.md`](docs/ideas/calrelay-eventkit-mvp.md).

Implementation work is broken down in the [CalRelay EventKit MVP implementation plan](docs/plans/calrelay-eventkit-mvp-implementation-plan.md).

## Requirements

- macOS 26+
- Swift 6.2+
- Full Calendar access for `CalRelay.app` when prompted by macOS
- Writable Apple Calendar/EventKit calendars for any calendar that CalRelay should mutate

## Build and test

```sh
swift build
swift test
swift run calrelay --help
zsh scripts/build-calrelay-app.sh
```

`swift test` is the local deterministic test gate. It does not require real EventKit access or real calendars. If the active Command Line Tools toolchain cannot load Swift Testing, run tests with full Xcode selected for the command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Repository layout

- `Sources/CalRelayCore/`: pure domain/application logic for the `CalendarRelay` feature, including DTOs, ports, settings validation, projection, and reconciliation planning.
- `Sources/CalRelayAdapters/`: YAML configuration, CLI output formatting, and EventKit outbound adapters.
- `Sources/CalRelay/`: executable `calrelay` CLI command parsing and composition.
- `Sources/CalRelayApp/`: minimal app wrapper used for macOS Calendar permission and EventKit capability checks.
- `Tests/CalRelayContractTests/`: deterministic Swift Testing contract suite used by `swift test`; it uses fakes and does not require real EventKit access.
- `docs/manual-validation.md`: app-backed EventKit validation recipe for local writable test calendars.

## Usage

### App

Build and open the app bundle:

```sh
zsh scripts/build-calrelay-app.sh
open .build/CalRelay.app
```

The app uses bundle identifier `dev.owinter.CalRelay` and owns its own macOS Calendar permission prompt. Use the **List Calendars** button to request Calendar access and confirm visible calendars.

### CLI

List visible EventKit calendars, their source titles, local calendar IDs, and writable status:

```sh
swift run calrelay calendars
```

Run reconciliation in dry-run mode. This reads the configured calendars and prints planned creates/deletes without mutating Apple Calendar:

```sh
swift run calrelay reconcile --config calrelay.yml
```

Apply the planned reconciliation. Mutation only happens when `--apply` is passed:

```sh
swift run calrelay reconcile --config calrelay.yml --apply
```

See [`docs/configuration.md`](docs/configuration.md) for the YAML schema, selector semantics, and safety notes. Use `CalRelay.app` for EventKit permission checks; see [`docs/manual-validation.md`](docs/manual-validation.md) for the app-backed validation recipe.
