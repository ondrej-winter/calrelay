# calrelay

CalRelay is a local macOS Swift CLI that uses Apple Calendar/EventKit-visible calendars to relay availability blockers across multiple work calendars.

The current implementation source of truth is the [CalRelay EventKit MVP spec](docs/specs/calrelay-eventkit-mvp-spec.md), derived from the original idea in [`docs/ideas/calrelay-eventkit-mvp.md`](docs/ideas/calrelay-eventkit-mvp.md).

Implementation work is broken down in the [CalRelay EventKit MVP implementation plan](docs/plans/calrelay-eventkit-mvp-implementation-plan.md).

## Requirements

- macOS 26+
- Swift 6.2+
- Full Calendar access for the `calrelay` executable when prompted by macOS
- Writable Apple Calendar/EventKit calendars for any calendar that CalRelay should mutate

## Build and test

```sh
swift build
swift run CalRelayContractTests
swift run calrelay --help
```

`CalRelayContractTests` is the current local deterministic test gate. The default `swift test` command is not used yet because this repository currently keeps its runnable contract checks in a SwiftPM executable target rather than a SwiftPM test target.

## Usage

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

See [`docs/configuration.md`](docs/configuration.md) for the YAML schema, selector semantics, and safety notes.