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

## Automation

- `.github/workflows/ci-cd.yaml`: the single push, pull-request, manual CI, and protected-release workflow entry point.
- `.github/actions/`: repository-local composite actions for repeated GitHub Actions mechanics such as pinned tool setup, retained-candidate download, and reviewed recovery-helper staging.
- `scripts/release/`: deterministic release policy, candidate, publication, recovery, and validation tooling.

## Documentation

- `docs/README.md`: documentation index organized by reader task and document authority.
- `docs/development.md`: canonical requirements, build, test, formatting, linting, and package workflow.
- `docs/configuration.md`: YAML schema, selector semantics, CLI reconciliation commands, and safety notes.
- `docs/distribution.md`: user-facing public-beta availability, Homebrew installation, upgrade, uninstallation, configuration retention, and Calendar-permission setup.
- `docs/release-operations.md`: protected release bootstrap, automated operation, credential rotation, incomplete-release resumption, defective-release correction, and incident recovery.
- `docs/specs/`: accepted feature-owned product and behavior contracts. Start with `docs/specs/README.md` for the canonical index and historical migration map.
- `docs/adr/`: durable architecture and lifecycle decisions. Start with `docs/adr/README.md`.
- `docs/plans/`: non-normative delivery plans and implementation evidence. Start with `docs/plans/README.md`.
