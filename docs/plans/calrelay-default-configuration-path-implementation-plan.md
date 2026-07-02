# CalRelay Default Configuration Path Implementation Plan

## Goal

Implement the behavior specified in [`docs/specs/calrelay-default-configuration-path-spec.md`](../specs/calrelay-default-configuration-path-spec.md):

- `swift run calrelay reconcile` defaults to `~/.config/calrelay/config.yaml`.
- `swift run calrelay reconcile --config <path>` remains an explicit override.
- Missing configuration fails before YAML parsing or EventKit access with an actionable user-facing error.
- Configuration path mechanics remain at the CLI, app, or bootstrap edge and do not leak into `CalRelayCore`.
- README and configuration docs show the new default-path workflow.

## Progress status

- [x] Add a CLI-edge configuration path helper.
- [x] Make `--config` optional in `ReconcileCommand`.
- [x] Add actionable missing-file diagnostics.
- [x] Add focused deterministic tests.
- [x] Update documentation.
- [x] Validate incrementally.

Validation evidence so far:

- [x] `swift build` passed.
- [x] `swift test --filter ConfigurationFileSelectionTests` was attempted and hit the known active Command Line Tools Swift Testing issue: `no such module 'Testing'`.
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter ConfigurationFileSelectionTests` passed with 4 tests.
- [x] `swift run calrelay reconcile --help` confirmed `USAGE: calrelay reconcile [--config <config>] [--apply]` and override-focused help text.
- [x] `swift run calrelay reconcile --config ./.tmp/nonexistent-calrelay-config.yaml 2>&1` confirmed the explicit missing-config error before YAML parsing or EventKit access.
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with 5 tests.
- [x] README and configuration documentation updated to show default-path usage and explicit override semantics.

## Scope

### In scope

- CLI default configuration path selection for `calrelay reconcile`.
- Optional `--config <path>` override semantics.
- CLI-edge missing-file diagnostics for default and explicit paths.
- Focused deterministic tests for path selection and missing-file messages.
- Documentation updates for normal default-path usage and override usage.

### Out of scope

- `CALRELAY_CONFIG` environment variable support.
- Multiple profiles.
- Configuration discovery paths beyond `~/.config/calrelay/config.yaml`.
- Automatic configuration file creation, migration, or overwrite.
- App “Choose Config...” UI.
- Remembered alternate app configuration paths.
- Live EventKit access as part of default-path validation tests.

## Current context

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/CalRelayCommand.swift` currently requires `@Option var config: String` for `reconcile`.
- `YAMLCalendarRelaySettingsLoader` in `Sources/CalRelayAdapters/Features/CalendarRelay/Adapters/Inbound/Config/` parses YAML strings into application DTOs and should not own filesystem policy.
- `CalRelayCore` owns settings DTOs, validation, and reconciliation orchestration and should remain unaware of filesystem paths.
- `README.md` and `docs/configuration.md` currently show `--config calrelay.yml` as the ordinary reconciliation path.
- Existing deterministic tests cover YAML parsing and reconciliation behavior but do not yet cover CLI configuration path selection.

## Target files

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/CalRelayCommand.swift`
  - Make `--config` optional and call the CLI-edge selection helper before loading YAML.
- `Sources/CalRelayCommandSupport/ConfigurationFileSelection.swift`
  - New CLI-edge support helper for default path construction, override selection, file-existence checks, and CLI-facing errors.
- `Tests/CalRelayCLITests/ConfigurationFileSelectionTests.swift` or equivalent focused CLI-support test file
  - Add deterministic tests for selection and error messaging without adding more cases to the already-large contract test suite.
- `Package.swift`
  - Add a tiny CLI support library target and focused CLI test target so tests can access the CLI-edge helper without moving filesystem policy into `CalRelayCore`.
- `README.md`
  - Update CLI usage examples.
- `docs/configuration.md`
  - Add canonical configuration location and override semantics.

## Implementation sequence

### 1. Add a CLI-edge configuration path helper — Done

Create a tiny CLI support library target so the helper can be tested cleanly without importing the executable target or moving path policy into core. Add the helper at:

```text
Sources/CalRelayCommandSupport/ConfigurationFileSelection.swift
```

Update `Package.swift` so:

- executable target `CalRelay` depends on the new `CalRelayCommandSupport` target;
- focused test target `CalRelayCLITests` depends on `CalRelayCommandSupport`;
- `CalRelayCore` remains free of filesystem path-resolution policy.

Responsibilities:

- Define the canonical default relative path `.config/calrelay/config.yaml`.
- Resolve the default path from the current user's home directory at runtime.
- Preserve the friendly display path `~/.config/calrelay/config.yaml` for default-path messages.
- Select an explicit override path when `--config <path>` is provided.
- Check for file existence before YAML parsing and before EventKit access.
- Produce actionable, privacy-safe user-facing errors.

Recommended helper shape:

- A selected-file result type that carries:
  - the resolved path used for `String(contentsOfFile:encoding:)`;
  - a display path for user-facing diagnostics;
  - whether the path came from the canonical default or an explicit override.
- A missing-file error type that conforms to `Error` and either `CustomStringConvertible` or `LocalizedError` so ArgumentParser prints the intended user-facing message rather than a Swift debug representation.
- The default display path should remain exactly `~/.config/calrelay/config.yaml`.

The helper should support deterministic tests by allowing injection of:

- home directory URL or path;
- file-existence check closure.

Keep the executable-facing API narrow. Prefer a small `public` API only for the selection behavior used by `ReconcileCommand`; keep implementation details internal. If tests need access to internal details, use `@testable import CalRelayCommandSupport` only in the focused CLI test target.

### 2. Make `--config` optional in `ReconcileCommand` — Done

Update `ReconcileCommand` in `CalRelayCommand.swift` so that:

- `swift run calrelay reconcile` selects `~/.config/calrelay/config.yaml`.
- `swift run calrelay reconcile --config <path>` preserves existing explicit override behavior.
- Help text describes `--config` as an override rather than a required option.

The option should become optional, for example:

```swift
@Option(name: .long, help: "Override path to the CalRelay YAML configuration file.")
var config: String?
```

The command should resolve and validate the selected file before:

1. reading YAML;
2. parsing settings;
3. constructing or invoking EventKit-backed reconciliation.

Throw missing-file errors in a form that ArgumentParser renders as the intended user-facing text. Prefer `LocalizedError.errorDescription` for the exact multiline message and verify the live CLI output during validation.

### 3. Add actionable missing-file diagnostics — Done

For the default path, align with the spec's required message shape:

```text
No CalRelay configuration file found at ~/.config/calrelay/config.yaml.
Create one there or pass --config <path>.
See docs/configuration.md for an example.
```

For an explicit override path, use a clear override-specific message, for example:

```text
No CalRelay configuration file found at <provided-path>.
Check the path or pass a different --config <path>.
```

This avoids implying that the canonical config was selected when the user deliberately provided an alternate file.

### 4. Add focused deterministic tests — Done

Prefer testing the pure helper instead of requiring real CLI execution or EventKit access.

Use a focused CLI/support test location rather than adding more cases to `Tests/CalRelayContractTests/CalRelayContractTests.swift`. The current contract test target depends only on `CalRelayCore` and `CalRelayAdapters`, so it cannot access a helper that lives only in the `CalRelay` executable target without an intentional package change.

Package/test strategy:

1. Introduce a tiny library target named `CalRelayCommandSupport` for command-support behavior that is not domain/application logic.
2. Have the `CalRelay` executable target and the focused `CalRelayCLITests` test target depend on it.
3. Do not move the helper into `CalRelayCore`; default-path and filesystem policy are adapter/bootstrap concerns.
4. Keep the new support target scoped to CLI command support. If future app configuration-status UI needs shared canonical path behavior, split a neutral shared configuration-support target later rather than making the app depend on CLI-specific error wording.

Recommended cases:

- no override selects `<home>/.config/calrelay/config.yaml`;
- explicit override path is selected instead of the default;
- missing default config error includes:
  - `~/.config/calrelay/config.yaml`;
  - `Create one there`;
  - `--config <path>`;
  - `docs/configuration.md`;
- missing explicit config error includes the provided path and does not use default-path creation guidance.

- If package changes are needed for helper access, keep them minimal and document that they exist only to test CLI-edge behavior without leaking path policy into core.

### 5. Update documentation — Done

Update `README.md` CLI examples to show default usage first:

```sh
swift run calrelay reconcile
```

Then show override usage:

```sh
swift run calrelay reconcile --config ./calrelay.yml
```

Show apply mode using the default path unless an override is needed:

```sh
swift run calrelay reconcile --apply
```

Update `docs/configuration.md` with a “Configuration file location” section covering:

- default file: `~/.config/calrelay/config.yaml`;
- create the documented YAML example there for normal use;
- use `--config <path>` for tests, experiments, or temporary alternate configurations;
- CalRelay does not create configuration files automatically;
- CalRelay does not search arbitrary directories for configuration files.

Review `docs/manual-validation.md` during implementation. It contains explicit `--config calrelay.yml` examples for local validation workflows. Keep those override-based examples if they intentionally describe a safe local fixture workflow; otherwise update them separately from the everyday default-path examples in README/configuration docs.

### 6. Validate incrementally — Done for implemented slices

Run focused and full checks after implementation:

```sh
swift build
swift test
swift run calrelay reconcile --help
swift run calrelay reconcile --config ./.tmp/nonexistent-calrelay-config.yaml
```

If the active Command Line Tools Swift Testing issue appears, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Manual checks:

- Verify help text presents `--config` as optional override.
- Verify the explicit nonexistent override command renders the intended missing-file message and does not reach YAML parsing or EventKit.
- Verify missing-default behavior without modifying any real user config. Prefer helper tests with injected paths. If a manual command is needed, avoid moving or deleting `~/.config/calrelay/config.yaml`; explicitly state when helper tests cover this instead of a live CLI check.
- Verify explicit override still works with a safe local valid test config when available.

## Risks and mitigations

### Raw Foundation file errors leak to users

Mitigation: perform an explicit file-existence check and throw a CLI-specific error before reading the file.

### Tests depend on the developer's real home directory

Mitigation: inject home directory and file-existence behavior into the helper tests.

### CLI helper is hard to test from the current package layout

Mitigation: use the planned `CalRelayCommandSupport` library target plus a focused `CalRelayCLITests` test target. Do not move filesystem policy into `CalRelayCore` just to make tests easier.

### CLI errors render as Swift debug descriptions

Mitigation: make the missing-file error conform to `CustomStringConvertible` or `LocalizedError`, then verify `swift run calrelay reconcile --help` and error-path behavior show the intended user-facing text.

### Filesystem policy leaks into the YAML loader or core

Mitigation: keep path selection in CLI command support used by the `CalRelay` executable. Leave `YAMLCalendarRelaySettingsLoader.load(_:)` as string-to-settings parsing.

### Scope expands into app UI or environment variables

Mitigation: keep app config UI, `CALRELAY_CONFIG`, profile support, and config creation as non-goals for this pass.

## Success criteria

- `swift run calrelay reconcile` attempts to load `~/.config/calrelay/config.yaml`.
- `swift run calrelay reconcile --config <path>` continues to work as an explicit override.
- Missing default config errors tell the user where to create the file, how to override it, and where to find an example.
- Missing explicit config errors identify the selected path and remain actionable.
- README and configuration docs show default-path usage.
- Deterministic tests cover the path selection helper and missing-file messages.
- Build and deterministic tests pass.
- No domain or application API depends on filesystem path resolution.
