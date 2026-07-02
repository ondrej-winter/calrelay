# Spec: CalRelay Default Configuration Path

## Objective

Define one canonical user configuration file for CalRelay so the CLI and future app UI share the same default answer to "where is the real config?"

The canonical configuration file is:

```text
~/.config/calrelay/config.yaml
```

This improves everyday local use by allowing `calrelay reconcile` to work without passing a configuration path, while preserving `--config <path>` as an explicit override for tests, experiments, and temporary alternate configurations.

## Current context

- The CLI currently requires `calrelay reconcile --config <path>`.
- YAML parsing is implemented in `YAMLCalendarRelaySettingsLoader` under the inbound configuration adapter.
- Reconciliation settings remain application DTOs in `CalRelayCore`.
- The current app is a Dock-visible SwiftUI control panel and UI-only menu bar surface.
- The app lifecycle spec says future manual sync actions require visible configuration validity before exposing sync controls.
- Configuration source mechanics must remain outside domain/application core.

## Desired behavior

### Canonical config location

- CalRelay has one canonical user configuration file for now: `~/.config/calrelay/config.yaml`.
- The CLI and future app configuration/status UI should use this same path as their default.
- The path should be resolved from the current user's home directory at the adapter/bootstrap edge.
- Documentation and user-facing messages may use the friendly `~/.config/calrelay/config.yaml` form.
- Error details may include the resolved absolute path when that improves clarity.

### CLI behavior

- `calrelay reconcile` should load `~/.config/calrelay/config.yaml` by default.
- `calrelay reconcile --config <path>` should continue to load the explicitly provided file.
- `--config` should be documented as an override rather than a required option.

Default usage:

```sh
swift run calrelay reconcile
```

Override usage:

```sh
swift run calrelay reconcile --config ./calrelay.yml
```

### Missing-file behavior

If the selected configuration file does not exist, CalRelay should fail before parsing or EventKit access with an actionable user-facing error.

For the default path, the message should communicate:

- no CalRelay configuration file was found
- where the user should create it
- that `--config <path>` can be used as an override
- that `docs/configuration.md` contains an example

Example message:

```text
No CalRelay configuration file found at ~/.config/calrelay/config.yaml.
Create one there or pass --config <path>.
See docs/configuration.md for an example.
```

### Future app behavior

- The app should use the same default configuration path for its first configuration-status milestone.
- The app should be able to show whether the canonical config exists and whether it validates.
- A later app UI may add "Choose Config..." and remember a selected file, but that is not part of this spec.

## Commands and validation

- Build: `swift build`
- Test: `swift test`, or `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` if the active Command Line Tools Swift Testing issue appears.
- CLI help check: `swift run calrelay reconcile --help`
- Missing-default manual check: run `swift run calrelay reconcile` when `~/.config/calrelay/config.yaml` is absent and verify the error is actionable.
- Override manual check: run `swift run calrelay reconcile --config <valid-test-config>` and verify existing behavior is preserved.

## Project structure

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/`: CLI option defaulting, path resolution, and command-facing errors.
- `Sources/CalRelayAdapters/Features/CalendarRelay/Adapters/Inbound/Config/`: YAML string-to-settings parsing, defaulting, and validation. Filesystem policy should stay out of this loader unless a focused file-loading adapter is introduced.
- `Sources/CalRelayApp/`: future app configuration-status UI should reuse the same default path convention at the app/bootstrap edge.
- `docs/configuration.md`: default path and usage examples.
- `README.md`: concise usage examples showing default and override behavior.

## Conventions

- Keep filesystem path resolution at adapter/bootstrap boundaries.
- Do not pass filesystem paths, environment variables, or `FileManager` details into domain/application core.
- Keep configuration errors actionable but privacy-safe.
- Do not log raw YAML contents.
- Do not create, modify, migrate, or overwrite user configuration files automatically in this change.
- Keep the configuration model single-profile for now.

## Testing strategy

- Prefer focused tests for pure path helper behavior if a small seam is introduced.
- Preserve existing deterministic reconciliation contract tests.
- Use CLI help and missing-file manual checks for command behavior if no clean command test seam exists.
- Do not require real EventKit access to validate missing-file/default-path behavior.

## Boundaries

- Always: keep `--config <path>` override support.
- Always: default to `~/.config/calrelay/config.yaml` when no override is provided.
- Always: fail before EventKit access when the selected config file is missing.
- Always: keep default path resolution out of `CalRelayCore`.
- Ask first: before adding environment variable overrides such as `CALRELAY_CONFIG`.
- Ask first: before adding profile support or multiple config discovery paths.
- Ask first: before adding a "Choose Config..." UI or remembered alternate app config path.
- Ask first: before writing a config file automatically.
- Never: silently create a default config file.
- Never: search arbitrary directories for config files.
- Never: make live EventKit access part of default-path validation tests.

## Success criteria

- `swift run calrelay reconcile` attempts to load `~/.config/calrelay/config.yaml`.
- `swift run calrelay reconcile --config <path>` continues to work as an explicit override.
- Missing config errors are clear and tell the user where to create the file or how to pass an override.
- README and configuration docs show default-path usage.
- Build and deterministic tests pass.
- No domain/application API depends on filesystem path resolution.

## Open questions

- None blocking. The accepted default path is `~/.config/calrelay/config.yaml`.