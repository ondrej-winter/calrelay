# Spec: Configuration Discovery and YAML Settings

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — consolidates accepted EventKit MVP configuration and default-path requirements on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/configuration-spec.md`.
- **Scope:** YAML settings, selector contract, canonical configuration discovery, validation, and app configuration status.

## Required outcomes

### CONFIG-01 — Settings model

- Use YAML, parsed with `Yams`, as the initial configuration format.
- Settings define a hub calendar, one or more locally available work/client calendars, a unique prefix per work calendar, a personal-origin prefix, and a sync window.
- Calendar selection uses source/title selectors. EventKit IDs may be displayed for troubleshooting but are not configuration keys.
- Pass validated settings into application use cases as explicit DTOs.

### CONFIG-02 — Canonical location and override

- The canonical user configuration file is `~/.config/calrelay/config.yaml`.
- The CLI and first app configuration-status milestone use this path by default.
- Resolve `~` from the current user's home directory at the adapter/bootstrap edge.
- `--config <path>` remains an explicit override for tests, experiments, and temporary configurations.
- Documentation and friendly diagnostics may use the `~/.config/calrelay/config.yaml` form; diagnostics may include a resolved absolute path when useful.

### CONFIG-03 — Missing-file and validation behavior

- If the selected file is missing, fail before parsing or EventKit access.
- The default-path error identifies the expected location, the `--config <path>` override, and `docs/configuration.md`.
- The app can show whether the canonical config exists and validates before exposing manual sync actions.

## Constraints

- Keep filesystem path resolution, environment access, and `FileManager` mechanics out of domain/application code.
- Do not log raw YAML contents.
- Do not silently create, migrate, modify, or overwrite user configuration files; do not search arbitrary directories.
- Keep a single-profile model. Environment overrides, profiles, multiple paths, remembered alternate app paths, and a “Choose Config...” UI require an explicit decision.

## Acceptance checks

- **CONFIG-AC-01:** Default discovery selects `~/.config/calrelay/config.yaml`; an explicit override selects its supplied file.
- **CONFIG-AC-02:** A missing selected configuration file fails before EventKit access with actionable guidance.
- **CONFIG-AC-03:** README and `docs/configuration.md` document the default and override behavior.
- **CONFIG-AC-04:** Build and deterministic tests pass without domain/application APIs depending on filesystem-path resolution or live EventKit access.

## Open decision

- Are source/title selectors stable enough across the user's accounts, or will a fallback ID selector be needed later?