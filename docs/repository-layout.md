# CalRelay repository layout

This page describes the main source, test, and documentation areas in the repository. The root `README.md` stays intentionally brief and links here for navigation details.

## Source targets

- `Sources/CalRelayKit/`: standalone shared `CalendarRelay` library target. It owns calendar relay business logic, application use cases, DTOs, ports, settings validation, projection, reconciliation planning, YAML configuration loading, reusable command handlers/formatters, and EventKit outbound adapters used by thin wrappers.
- `Sources/CalRelayCLI/`: executable `calrelay` CLI wrapper. It owns ArgumentParser command declarations, command-line options, terminal printing, and composition by delegating reusable behavior to `CalRelayKit`.
- `Sources/CalRelayApp/`: Dock-visible SwiftUI app wrapper for setup, status, manual workflows, lifecycle presentation, and composition of the reusable CalRelayKit capabilities. The accepted first automation milestone does not include a menu-bar surface.

`CalRelayKit` is the intended integration point for command-line, macOS, and future UI wrappers. Keep wrapper targets focused on UI, lifecycle, option parsing, and presentation-shell concerns; put reusable calendar relay behavior and related infrastructure behind kit APIs.

## Tests

- `Tests/CalRelayKitTests/`: consolidated deterministic executable test runner for shared library, CLI-support, and contract behavior; it uses fakes and does not require real EventKit access.
- `UITests/CalRelayUITests/`: XCUITest smoke workflows for deterministic macOS app presentation and review/cancellation flows.
- `CalRelayUITests.xcodeproj/`: minimal UI-test-only Xcode project and shared scheme. `Package.swift` remains authoritative for application products, library targets, and dependencies.
- `Resources/CalRelayUITestHost/` and `scripts/build-calrelay-ui-test-app.sh`: separately identified, ad-hoc-signed fake host packaging used only by XCUITest. Generated host bundles live outside the workspace and `.build/CalRelayUITestHost.app` is a symlink.

## Documentation

- `docs/development.md`: canonical requirements, build, test, formatting, linting, and package workflow.
- `docs/configuration.md`: YAML schema, selector semantics, CLI reconciliation commands, and safety notes.
- `docs/specs/`: accepted feature-owned product and behavior contracts. Start with `docs/specs/README.md` for the canonical index and historical migration map.
- `docs/adr/`: durable architecture and lifecycle decisions. Start with `docs/adr/README.md`.
