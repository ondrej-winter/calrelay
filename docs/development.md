# CalRelay development workflow

This page is the canonical local development reference for requirements, build commands, tests, formatting, linting, and package hygiene.

## Requirements

- macOS 26+
- Swift 6.2+
- Xcode 27+ for macOS UI tests
- `make` for the canonical local development commands
- `swift-format` for formatting checks
- SwiftLint for lint checks
- `uvx` for the Fabrica-assisted commit workflow
- Full Calendar access for `CalRelay.app` when prompted by macOS
- Writable Apple Calendar/EventKit calendars for any calendar that CalRelay should mutate

## Build and test

Use the `Makefile` as the canonical local tooling entrypoint:

```sh
make help
make check
make ui-test
make app
make commit
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

`make ui-test` is a separate fake-backed macOS UI smoke lane. It requires full
Xcode at `XCODE_DEVELOPER_DIR` (default:
`/Applications/Xcode.app/Contents/Developer`) and runs the shared
`CalRelayUITests` scheme. The command builds an ad-hoc-signed host with the
separate bundle identifier `dev.owinter.CalRelay.UITestHost`, launches only
explicit deterministic scenarios, and never uses EventKit, requests Calendar or
notification permission, registers launch-at-login, starts wake/timer triggers,
or reads production persistence. The suite covers:

- missing configuration;
- Calendar access unavailable;
- ready-state inventory and ordinary dry run;
- manual-sync review and cancellation;
- migration-cleanup review and cancellation; and
- scheduled-sync authorization with pause/resume.

UI tests intentionally remain outside `make check`. Run them when app sources,
accessibility contracts, fake UI composition, or the UI-test harness changes.
The external DerivedData cache lives under
`~/Library/Caches/dev.owinter.CalRelay/xcode-ui-tests`; the isolated app bundle
lives under `~/Library/Caches/dev.owinter.CalRelay/ui-test-builds` and is linked
at `.build/CalRelayUITestHost.app`. The latest result bundle is
`.build/CalRelayUITests.xcresult`. These caches are disposable and are not
removed by `make clean`.

The package manifest (`Package.swift`) is the source of truth for products, targets, and dependencies. Keep `Package.resolved` committed with intentional dependency resolution updates.
`CalRelayUITests.xcodeproj` owns only the XCTest UI-test bundle and shared scheme;
it does not replace or duplicate the SwiftPM app and library target graph. See
[ADR 0003](adr/0003-use-xctest-only-for-isolated-ui-automation.md).

Run `make commit` to create a Conventional Commit with Fabrica using the repository skill root and configured model. Review the staged changes before invoking it because the command starts a Git commit workflow.

## App bundle

Build the app bundle with:

```sh
make app
```

The signed bundle lives in a workspace-specific directory under
`~/Library/Caches/dev.owinter.CalRelay/builds`; `.build/CalRelay.app` is a symlink.
This keeps file-provider metadata from breaking code signing while preserving
the usual launch path. `make app` recreates the cached bundle and verifies its
signature strictly. `make clean` removes SwiftPM products, not this external
cache. See [ADR 0002](adr/0002-build-local-app-bundles-outside-file-provider-workspaces.md).

Open the built app when you need macOS Calendar permission and EventKit visibility checks:

```sh
open .build/CalRelay.app
```

For app-backed EventKit validation with harmless local test calendars, see [`manual-validation.md`](manual-validation.md).