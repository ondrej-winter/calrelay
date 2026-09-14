# Spec: CalRelay Default Configuration Path

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — template-alignment audit on September 14, 2026; no configuration-path behavior changed.
- **Canonical artifact:** `docs/specs/calrelay-default-configuration-path-spec.md`.
- **Source of truth:** This document is the canonical default-path contract for the CLI and future app configuration-status UI.
- **Acceptance basis:** Repository history records the accepted path decision and its corresponding implementation. An individual approver and acceptance date were not recorded.
- **Next authorized step:** Maintain this specification with any future configuration-discovery, profile, environment-override, or app-selected-path decision.

## Revision history

- **Revision 2 — September 14, 2026:** Aligned the document structure with the specification template. Preserved the accepted default-path decision and constraints.
- **Revision 1 — July 2, 2026:** Initial default-configuration-path specification.

## Objective

Define one canonical user configuration file for CalRelay so the CLI and future app UI share the same default answer to "where is the real config?"

The canonical configuration file is:

```text
~/.config/calrelay/config.yaml
```

This improves everyday local use by allowing `calrelay reconcile` to work without passing a configuration path, while preserving `--config <path>` as an explicit override for tests, experiments, and temporary alternate configurations.

## Scope

**In scope:** default-path resolution when the CLI receives no `--config` value, continued explicit-path override behavior, missing-file diagnostics, documentation, and the future app first configuration-status milestone.

**Explicit exclusions:** environment-variable overrides, profile support, discovery of multiple paths, remembered alternate app paths, and automatic creation or migration of user configuration files.

## Assumptions

- The current user home directory is available to adapter/bootstrap code for resolving `~`.
- A single-profile file is sufficient until a separately accepted product decision changes that model.

## Current context

- The CLI currently requires `calrelay reconcile --config <path>`.
- YAML parsing is implemented in `YAMLCalendarRelaySettingsLoader` under the inbound configuration adapter.
- Reconciliation settings remain application DTOs in `CalRelayKit`.
- The current app is a Dock-visible SwiftUI control panel and UI-only menu bar surface.
- The app lifecycle spec says future manual sync actions require visible configuration validity before exposing sync controls.
- Configuration source mechanics must remain outside domain/application core.

## Required outcomes

### REQ-01 — Canonical configuration location

- CalRelay has one canonical user configuration file for now: `~/.config/calrelay/config.yaml`.
- The CLI and future app configuration/status UI should use this same path as their default.
- The path should be resolved from the current user's home directory at the adapter/bootstrap edge.
- Documentation and user-facing messages may use the friendly `~/.config/calrelay/config.yaml` form.
- Error details may include the resolved absolute path when that improves clarity.

### REQ-02 — CLI behavior

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

### REQ-03 — Missing-file behavior

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

### REQ-04 — Future app behavior

- The app should use the same default configuration path for its first configuration-status milestone.
- The app should be able to show whether the canonical config exists and whether it validates.
- A later app UI may add "Choose Config..." and remember a selected file, but that is not part of this spec.

## Verification approach

- Build: `swift build`
- Test: `swift test`, or `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` if the active Command Line Tools Swift Testing issue appears.
- CLI help check: `swift run calrelay reconcile --help`
- Missing-default manual check: run `swift run calrelay reconcile` when `~/.config/calrelay/config.yaml` is absent and verify the error is actionable.
- Override manual check: run `swift run calrelay reconcile --config <valid-test-config>` and verify existing behavior is preserved.

## Project structure

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/`: CLI option defaulting, path resolution, and command-facing errors.
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/`: YAML string-to-settings parsing, defaulting, and validation. Filesystem policy should stay out of this loader unless a focused file-loading adapter is introduced.
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

## Verification approach and test strategy

- Prefer focused tests for pure path helper behavior if a small seam is introduced.
- Preserve existing deterministic reconciliation contract tests.
- Use CLI help and missing-file manual checks for command behavior if no clean command test seam exists.
- Do not require real EventKit access to validate missing-file/default-path behavior.

## Binding constraints and execution boundaries

These constraints are mandatory for work governed by this specification.

- **CON-01:** Keep `--config <path>` override support, default to `~/.config/calrelay/config.yaml` with no override, and fail before EventKit access when the selected file is missing.
- **CON-02:** Keep default-path resolution out of `CalRelayKit` domain/application code.
- **CON-03:** Adding environment-variable overrides, profiles, multiple discovery paths, a "Choose Config..." UI, a remembered alternate app path, or automatic file writing requires an explicit decision.
- **CON-04:** Never silently create a default configuration file, search arbitrary directories for configuration files, or make live EventKit access part of default-path validation tests.

## Acceptance checks

- **AC-01 (REQ-01, REQ-02, CON-01):** `swift run calrelay reconcile` attempts to load `~/.config/calrelay/config.yaml`, while `swift run calrelay reconcile --config <path>` uses the explicit override.
- **AC-02 (REQ-03, CON-01):** A missing selected configuration file fails before EventKit access with an actionable message that names the default location, the override option, and `docs/configuration.md`.
- **AC-03 (REQ-01, REQ-02):** README and configuration documentation show default-path and override usage.
- **AC-04 (REQ-04):** The app’s first configuration-status milestone uses the same default path and can show whether the canonical file exists and validates.
- **AC-05 (CON-02, CON-04):** Build and deterministic tests pass without a domain/application API depending on filesystem path resolution or requiring live EventKit access for this behavior.

## Unresolved decisions

- None.

## Traceability

- **REQ-01:** AC-01, AC-03.
- **REQ-02:** AC-01, AC-03.
- **REQ-03:** AC-02.
- **REQ-04:** AC-04.