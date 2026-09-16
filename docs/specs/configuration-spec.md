# Spec: Configuration Discovery, YAML Settings, and Marker Migration

## Specification record

- **Status:** Accepted.
- **Revision:** 4 — accepted on September 16, 2026 after a focused configuration-contract stress test; the YAML schema, marker grammar, path semantics, validation bounds, and legacy-marker migration workflow were made normative.
- **Canonical artifact:** `docs/specs/configuration-spec.md`.
- **Scope:** YAML settings, marker and selector contracts, canonical configuration discovery, structural validation, migration-pending state, and legacy-marker cleanup coverage.

## Required outcomes

### CONFIG-01 — Normative YAML schema

- Use YAML, parsed with `Yams`, as the configuration format.
- The document root is one mapping with exactly these fields:
  - `hubCalendar`, required, containing exactly the nonempty string fields `sourceTitle` and `calendarTitle`;
  - `personalPrefix`, required, containing one valid marker as defined by `CONFIG-02`;
  - `syncWindowDays`, optional, containing an integer from `1` through `365` inclusive and defaulting to `100` when omitted;
  - `workCalendars`, required, containing one or more work-calendar mappings; and
  - `legacyMarkers`, optional, containing a sequence of valid markers and defaulting to an empty sequence when omitted.
- Each `workCalendars` entry contains exactly:
  - `name`, a nonempty string used to identify the configured role in diagnostics;
  - `prefix`, one valid current work marker; and
  - `calendar`, a mapping containing exactly the nonempty string fields `sourceTitle` and `calendarTitle`.
- Unknown fields at the root or any nested mapping are structural-validation failures.
- Duplicate keys in any YAML mapping are structural-validation failures; CalRelay must not silently select one duplicate value.
- Other YAML syntax supported by `Yams` remains allowed when it decodes unambiguously into this schema.
- `syncWindowDays` counts future local dates after the reference date as defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md). The fixed two-local-date lookback is not configurable and is not included in `syncWindowDays`.
- Pass validated settings into application use cases as explicit DTOs.

### CONFIG-02 — Exact marker contract

- Although the compatibility field names remain `personalPrefix` and `workCalendars[].prefix`, each value is a complete marker rather than an arbitrary character prefix.
- A valid marker matches the complete regular expression `\[[A-Za-z0-9_-]+\]`.
- Marker identity is case-sensitive. For example, `[ACME]` and `[acme]` are distinct markers.
- The personal marker, every current work marker, and every legacy marker must be pairwise distinct. Any exact duplicate is a structural-validation failure before EventKit access.
- Event-title marker recognition, separator rules, projection normalization, and deletion ownership are defined by [`projection-and-safety-spec.md`](projection-and-safety-spec.md). Configuration order must not affect marker recognition.

### CONFIG-03 — Calendar selectors and structural role collisions

- Calendar selection uses source/title selectors. EventKit IDs may be displayed by successful calendar discovery and successful explicit reconciliation explanation, but they are not configuration keys or automatic selector fallbacks.
- Selector strings are matched exactly at runtime as defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- If two configured roles contain the same exact `sourceTitle` and `calendarTitle` tuple, structural validation fails before EventKit access and identifies both conflicting roles.
- Distinct selector tuples still require runtime configured-topology preflight because they can resolve to zero calendars, multiple calendars, or the same physical EventKit calendar.

### CONFIG-04 — Canonical location and explicit override

- The canonical user configuration file is `~/.config/calrelay/config.yaml`.
- `calrelay config check`, every `calrelay reconcile` mode, and the app configuration-status milestone use this path by default.
- Resolve the canonical `~` from the current user's home directory at the adapter/bootstrap edge.
- `calrelay config check` and `calrelay reconcile` accept `--config <path>` as an explicit override for tests, experiments, and temporary configurations.
- For an explicit override:
  - use an absolute path as supplied;
  - resolve a relative path against the process's current working directory;
  - expand only `~` or a leading `~/` to the current user's home directory;
  - do not support `~otheruser`, environment-variable expansion, or arbitrary directory search.
- Documentation and friendly diagnostics may use the `~/.config/calrelay/config.yaml` form; diagnostics may include a resolved absolute path when useful.

### CONFIG-05 — Missing-file and structural-validation behavior

- If the selected file for config check, reconciliation, cleanup, or app configuration status is missing, fail before parsing or EventKit access.
- The default-path error identifies the expected location, the `--config <path>` override, and `docs/configuration.md`.
- YAML parsing and all structural validation in `CONFIG-01` through `CONFIG-03` complete before EventKit access.
- Configuration failures do not echo or log raw YAML contents.
- The app can show whether the canonical config exists and structurally validates before exposing manual sync actions.

### CONFIG-06 — Runtime selector resolution

- After file and structural validation, runtime configured readiness applies the exact-match and distinct-role requirements defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- A structurally valid source/title selector is not considered ready merely because one of several possible matches is writable. Zero matches, multiple matches, and two configured roles resolving to the same EventKit calendar are access-preflight failures.

### CONFIG-07 — Migration-pending state

- A structurally valid configuration with one or more `legacyMarkers` is in migration-pending state.
- Migration-pending state blocks ordinary reconciliation dry-run, apply, explanation, and scheduled reconciliation. These operations fail after structural validation but before EventKit access and direct the operator to `calrelay reconcile --cleanup-legacy`.
- `calrelay config check` still performs the ordinary configured-topology preflight, aggregates safely determinable access failures, reports migration pending, returns nonzero, and must not claim ordinary reconciliation readiness.
- Ordinary reconciliation resumes only after the operator completes the necessary cleanup and removes all `legacyMarkers` from the configuration.
- CalRelay must not automatically remove, rewrite, or otherwise modify `legacyMarkers` or any other configuration field.

### CONFIG-08 — Legacy-marker cleanup coverage

- `legacyMarkers` are temporary, cleanup-only deletion tombstones. They do not identify an origin calendar, route events, generate events, or participate in ordinary reconciliation.
- Cleanup is available only through the explicit CLI mode defined in [`cli-spec.md`](cli-spec.md).
- At cleanup-run start, capture one reference instant and the Mac's current system calendar and time zone and use that context for the entire run.
- Let `D` be the local date containing that reference instant. The cleanup range is the half-open interval from the start of local date September 15, 2026 through, but not including, the start of local date `D + 366 days`. It therefore includes `D` and the following 365 local dates.
- Cleanup searches the configured hub and every locally configured work calendar over the complete cleanup range and selects only events whose parsed marker exactly equals a configured legacy marker.
- Cleanup dry-run success is based on the complete loaded cleanup snapshot. Cleanup apply success additionally requires a post-mutation verification read over the complete configured topology and cleanup range and means that verification snapshot contained no matching legacy-marker events.
- Cleanup success is local and point-in-time. It does not prove global marker retirement, prevent later recreation, or cover calendars not visible to that run.
- Multi-computer migration uses eventual convergence. A not-yet-migrated computer may recreate retired-marker events after another computer succeeds, and repeated idempotent cleanup is expected until all publishers have migrated.

## Compatibility and breaking changes

- Revision 4 replaces arbitrary starts-with prefix semantics with the exact marker grammar and case-sensitive identity in `CONFIG-02`. Existing values outside that grammar become invalid.
- Revision 4 makes the documented YAML keys and nesting normative, rejects unknown fields and duplicate mapping keys, and limits `syncWindowDays` to `1...365`.
- Exact duplicate selector tuples now fail structurally before EventKit access rather than being deferred to runtime preflight.
- Explicit override paths now have stable current-working-directory and current-user tilde-expansion semantics.
- `legacyMarkers` and migration-pending state add an explicit, bounded marker-retirement workflow. Existing configurations that omit `legacyMarkers` remain ordinary profiles.
- The omitted `syncWindowDays` default remains `100`, and the fixed two-date lookback remains owned by [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- EventKit IDs remain visible troubleshooting data only on the approved successful CLI surfaces and cannot repair an ambiguous or missing source/title selector.

## Constraints

- Keep filesystem path resolution, environment access, and `FileManager` mechanics out of domain/application code.
- Do not log raw YAML contents.
- Do not silently create, migrate, modify, or overwrite user configuration files; do not search arbitrary directories.
- Keep a single-profile model. Environment overrides, profiles, multiple remembered app paths, and a “Choose Config...” UI require an explicit decision.
- Do not add hidden ownership metadata, a global marker registry, an unbounded EventKit scan, or a claim of globally atomic migration without a new explicit decision.

## Acceptance checks

- **CONFIG-AC-01:** The normative example and schema tests prove the exact accepted keys and nesting, default `legacyMarkers` to empty, reject unknown fields, and reject duplicate YAML mapping keys without exposing raw YAML.
- **CONFIG-AC-02:** Marker validation accepts representative values matching `\[[A-Za-z0-9_-]+\]`, rejects malformed values, compares case-sensitively, and rejects every duplicate across personal, current work, and legacy markers.
- **CONFIG-AC-03:** Omitting `syncWindowDays` produces `100`; values `1` and `365` are accepted; zero, negative, non-integer, and values above `365` are rejected before EventKit access.
- **CONFIG-AC-04:** Exact duplicate selector tuples fail structural validation with both roles identified; distinct tuples proceed to runtime preflight.
- **CONFIG-AC-05:** Default selection uses `~/.config/calrelay/config.yaml`; explicit absolute, relative, `~`, and `~/...` paths follow `CONFIG-04`; unsupported expansion forms are not interpreted.
- **CONFIG-AC-06:** A missing selected file fails before parsing or EventKit access with actionable guidance.
- **CONFIG-AC-07:** Runtime readiness rejects zero-match, multi-match, and duplicate-physical-calendar role resolution without EventKit-ID fallback.
- **CONFIG-AC-08:** Nonempty `legacyMarkers` blocks ordinary reconciliation and scheduling, while config check completes ordinary access preflight, reports migration pending, returns nonzero, and makes no readiness claim.
- **CONFIG-AC-09:** Cleanup computes the fixed September 15, 2026 through `D + 365` inclusive local-date range from one captured context and exact-matches only configured legacy markers.
- **CONFIG-AC-10:** Cleanup apply re-reads the full cleanup range after its planned deletions, succeeds only when that verification snapshot contains no exact legacy-marker match, and makes no global-retirement claim when another computer can later recreate the marker.
- **CONFIG-AC-11:** Deterministic tests pass without domain/application APIs depending on filesystem-path resolution or live EventKit access.

## Open decision

- Are source/title selectors stable enough across the user's accounts, or will a future explicit EventKit-ID selector be needed? Automatic ID fallback remains prohibited.
