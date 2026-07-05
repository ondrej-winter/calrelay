# CalRelay development workflow

This page is the canonical local development reference for requirements, build commands, tests, formatting, linting, and package hygiene.

## Requirements

- macOS 26+
- Swift 6.2+
- `make` for the canonical local development commands
- `swift-format` for formatting checks
- SwiftLint for lint checks
- Full Calendar access for `CalRelay.app` when prompted by macOS
- Writable Apple Calendar/EventKit calendars for any calendar that CalRelay should mutate

## Build and test

Use the `Makefile` as the canonical local tooling entrypoint:

```sh
make help
make check
make app
```

`make check` runs linting, a SwiftPM build, the deterministic SwiftPM executable test runner, and a CLI help smoke check. The underlying commands remain ordinary SwiftPM commands and can still be run directly when debugging a specific step:

```sh
make format-check
make format
make lint
make build
make test
swift run calrelay --help
```

`make format-check` and `make format` use the repository `swift-format` configuration. The formatter is available as a separate target so a future formatting-only change can adopt it without mixing mechanical formatting churn into feature work.

`make test` is the local deterministic test gate. It runs `swift run CalRelayKitTests` and does not require real EventKit access, real calendars, `CalRelay.app`, Swift Testing, XCTest, or a separately selected full Xcode toolchain.

The package manifest (`Package.swift`) is the source of truth for products, targets, and dependencies. Keep `Package.resolved` committed with intentional dependency resolution updates.

## App bundle

Build the app bundle with:

```sh
make app
```

Open the built app when you need macOS Calendar permission and EventKit visibility checks:

```sh
open .build/CalRelay.app
```

For app-backed EventKit validation with harmless local test calendars, see [`manual-validation.md`](manual-validation.md).