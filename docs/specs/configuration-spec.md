# Spec: Configuration Discovery and YAML Settings

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 15, 2026 after the calendar-access contract review; configured selector-resolution readiness and config-check selection behavior changed.
- **Canonical artifact:** `docs/specs/configuration-spec.md`.
- **Scope:** YAML settings, selector contract, canonical configuration discovery, validation, and app configuration status.

## Required outcomes

### CONFIG-01 — Settings model

- Use YAML, parsed with `Yams`, as the initial configuration format.
- Settings define a hub calendar, one or more locally available work/client calendars, a unique prefix per work calendar, a personal-origin prefix, and a sync window.
- Calendar selection uses source/title selectors. EventKit IDs are displayed by calendar discovery but are not configuration keys or automatic selector fallbacks.
- Pass validated settings into application use cases as explicit DTOs.

### CONFIG-02 — Canonical location and override

- The canonical user configuration file is `~/.config/calrelay/config.yaml`.
- `calrelay config check`, `calrelay reconcile`, and the first app configuration-status milestone use this path by default.
- Resolve `~` from the current user's home directory at the adapter/bootstrap edge.
- `calrelay config check` and `calrelay reconcile` accept `--config <path>` as an explicit override for tests, experiments, and temporary configurations.
- Documentation and friendly diagnostics may use the `~/.config/calrelay/config.yaml` form; diagnostics may include a resolved absolute path when useful.

### CONFIG-03 — Missing-file and validation behavior

- If the selected file for config check, reconciliation, or app configuration status is missing, fail before parsing or EventKit access.
- The default-path error identifies the expected location, the `--config <path>` override, and `docs/configuration.md`.
- The app can show whether the canonical config exists and validates before exposing manual sync actions.

### CONFIG-04 — Runtime selector resolution

- File and structural validation complete before EventKit access.
- Runtime configured readiness then applies the exact-match and distinct-role requirements defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- A structurally valid source/title selector is not considered ready merely because one of several possible matches is writable. Zero matches, multiple matches, and two configured roles resolving to the same EventKit calendar are access-preflight failures.

## Compatibility and breaking changes

- Revision 2 makes runtime selector resolution fail closed: every configured role must resolve exactly once, and every role must resolve to a distinct physical EventKit calendar.
- EventKit IDs remain visible troubleshooting data but cannot silently repair an ambiguous or missing source/title selector.

## Constraints

- Keep filesystem path resolution, environment access, and `FileManager` mechanics out of domain/application code.
- Do not log raw YAML contents.
- Do not silently create, migrate, modify, or overwrite user configuration files; do not search arbitrary directories.
- Keep a single-profile model. Environment overrides, profiles, multiple paths, remembered alternate app paths, and a “Choose Config...” UI require an explicit decision.

## Acceptance checks

- **CONFIG-AC-01:** Default configuration selection uses `~/.config/calrelay/config.yaml`; an explicit override selects its supplied file.
- **CONFIG-AC-02:** A missing selected configuration file for config check or reconciliation fails before EventKit access with actionable guidance.
- **CONFIG-AC-03:** README and `docs/configuration.md` document the default and override behavior.
- **CONFIG-AC-04:** Build and deterministic tests pass without domain/application APIs depending on filesystem-path resolution or live EventKit access.
- **CONFIG-AC-05:** Runtime readiness rejects zero-match, multi-match, and duplicate-physical-calendar role resolution without using EventKit IDs as fallback selectors.

## Open decision

- Are source/title selectors stable enough across the user's accounts, or will a future explicit EventKit-ID selector be needed? Revision 2 prohibits automatic ID fallback.