# CalRelay repository layout

This page describes the main source and test areas in the repository. The root `README.md` stays intentionally brief and links here for navigation details.

## Source targets

- `Sources/CalRelayKit/`: standalone shared `CalendarRelay` library target. It owns calendar relay business logic, application use cases, DTOs, ports, settings validation, projection, reconciliation planning, YAML configuration loading, reusable command handlers/formatters, and EventKit outbound adapters used by thin wrappers.
- `Sources/CalRelayCLI/`: executable `calrelay` CLI wrapper. It owns ArgumentParser command declarations, command-line options, terminal printing, and composition by delegating reusable behavior to `CalRelayKit`.
- `Sources/CalRelayApp/`: Dock-visible SwiftUI app control panel and UI-only menu bar surface used for macOS Calendar permission and EventKit capability checks.

`CalRelayKit` is the intended integration point for command-line, macOS, and future UI wrappers. Keep wrapper targets focused on UI, lifecycle, option parsing, and presentation-shell concerns; put reusable calendar relay behavior and related infrastructure behind kit APIs.

## Tests

- `Tests/CalRelayKitTests/`: consolidated deterministic executable test runner for shared library, CLI-support, and contract behavior; it uses fakes and does not require real EventKit access.

## Documentation

- `docs/configuration.md`: YAML schema, selector semantics, CLI reconciliation commands, and safety notes.
- `docs/manual-validation.md`: app-backed EventKit validation recipe for local writable test calendars.
- `docs/specs/`: feature-owned product and behavior specifications. Start with `docs/specs/README.md` for the canonical index and legacy-spec migration map.
- `docs/ideas/`: original ideas and exploratory notes.
- `docs/plans/`: implementation plans.