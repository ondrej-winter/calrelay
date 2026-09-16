# CalRelay configuration

CalRelay reads a strict YAML configuration that identifies one hub calendar and one or more locally available work calendars by Calendar source title and calendar title. The documented keys and nesting are the accepted schema; unknown fields and duplicate mapping keys are rejected.

## Configuration file location

By default, the CLI reads the canonical user configuration file at:

```text
~/.config/calrelay/config.yaml
```

For normal use, create the YAML configuration there. CalRelay does not create or rewrite this file automatically and does not search arbitrary directories for configuration files.

Use `--config <path>` for tests, experiments, or temporary alternate configurations:

```sh
swift run calrelay reconcile --config ./calrelay.yml
```

Explicit override paths behave as follows:

- absolute paths are used as supplied;
- relative paths resolve against the process's current working directory;
- `~` and `~/...` expand to the current user's home directory;
- `~otheruser` and environment variables such as `$HOME` are not expanded.

## Canonical schema example

```yaml
hubCalendar:
  sourceTitle: "iCloud"
  calendarTitle: "Personal Work"
personalPrefix: "[ME]"
syncWindowDays: 100
workCalendars:
  - name: "ACME"
    prefix: "[ACME]"
    calendar:
      sourceTitle: "Google"
      calendarTitle: "ACME Work"
legacyMarkers: []
```

## Fields

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `hubCalendar.sourceTitle` | String | Yes | None | Exact Calendar account/source title that contains the hub calendar. |
| `hubCalendar.calendarTitle` | String | Yes | None | Exact hub calendar title. |
| `personalPrefix` | Marker string | Yes | None | Marker added when copying an unmarked hub event into work calendars. |
| `syncWindowDays` | Integer | No | `100` | Number of future local dates after the run's reference date included in ordinary reconciliation. Must be from `1` through `365`. |
| `workCalendars[].name` | String | Yes | None | Nonempty configured role name used in diagnostics. |
| `workCalendars[].prefix` | Marker string | Yes | None | Current marker that identifies projections originating from this work calendar. |
| `workCalendars[].calendar.sourceTitle` | String | Yes | None | Exact Calendar account/source title that contains the work calendar. |
| `workCalendars[].calendar.calendarTitle` | String | Yes | None | Exact work calendar title. |
| `legacyMarkers[]` | Marker string | No | Empty list | Temporary cleanup tombstones used only by explicit legacy cleanup. |

No other fields are accepted at the root or inside nested mappings.

## Marker and title semantics

The YAML field names retain `Prefix` for compatibility, but each value is a complete marker, not an arbitrary text prefix.

A marker must contain one bracketed ASCII identifier:

```text
\[[A-Za-z0-9_-]+\]
```

Valid examples include `[ACME]`, `[client-2]`, and `[MY_WORK]`. Invalid examples include `ACME`, `[]`, `[ACME Team]`, `[ACME!]`, and `[A][B]`.

Marker identity is case-sensitive. `[ACME]` and `[acme]` are different markers. The personal marker, every current work marker, and every legacy marker must be pairwise distinct.

A title has marker semantics only in this exact shape:

```text
[ACME] Planning
```

The marker must be followed by exactly one ASCII space and nonempty title text. CalRelay compares the parsed marker exactly; it does not use raw starts-with matching. For example, marker `[A]` does not match `[ACME] Planning`.

When generating a projection, CalRelay trims surrounding whitespace from the source title and uses `(Untitled)` if nothing remains.

### Reserved marker namespace

Any valid marked event in the hub acts as a blocker source. A marker owned by a locally configured work calendar is not routed back to that origin calendar; an unknown or remote marker is copied unchanged into every locally configured work calendar.

In configured work calendars, the valid leading-marker namespace is reserved for CalRelay-managed blockers. A manually created title such as `[FOCUS] Deep Work` is indistinguishable from a relayed blocker and may be deleted when no matching marked hub event exists. Use an unmarked title for ordinary source events that CalRelay must preserve.

## Selector semantics

Calendar selectors use `sourceTitle` plus `calendarTitle`, not EventKit calendar IDs. Use the calendar listing command to discover the exact source/calendar titles and writable status visible to EventKit:

```sh
swift run calrelay calendars
```

The listing includes EventKit calendar IDs for troubleshooting, but IDs are not configuration keys or automatic selector fallbacks.

Two roles cannot use the same exact source-title/calendar-title selector tuple. Distinct tuples still undergo runtime preflight, which rejects selectors matching zero or multiple visible calendars and rejects two roles that resolve to the same physical EventKit calendar.

## Ordinary commands

Validate the selected configuration and the current readiness of every configured calendar without mutating calendars:

```sh
swift run calrelay config check
```

On success, config check reports the selected path and that the complete configured topology is currently ready.

Config check accepts the same explicit override as reconciliation:

```sh
swift run calrelay config check --config ./calrelay.yml
```

Ordinary reconciliation is dry-run by default:

```sh
swift run calrelay reconcile
```

Apply only after reviewing the dry-run plan:

```sh
swift run calrelay reconcile --apply
```

Use `--explain` for a non-mutating, end-to-end account of the exact ordinary reconciliation plan. It reports the effective window, classifies every input event, and lists every planned action with causal EventKit IDs. It cannot be combined with `--apply` or `--cleanup-legacy`.

```sh
swift run calrelay reconcile --explain
```

## Changing or retiring a marker

Changing or removing a marker can leave old projections in the shared hub and configured work calendars. Do not reuse an old marker for a different origin. Retire markers explicitly with the top-level `legacyMarkers` list.

For example, after changing `[OLD]` to `[NEW]`:

```yaml
personalPrefix: "[ME]"
workCalendars:
  - name: "ACME"
    prefix: "[NEW]"
    calendar:
      sourceTitle: "Google"
      calendarTitle: "ACME Work"
legacyMarkers:
  - "[OLD]"
```

While `legacyMarkers` is nonempty, the configuration is migration pending:

- ordinary dry-run, apply, explanation, and scheduled reconciliation are blocked before EventKit access;
- config check still performs ordinary topology preflight but returns nonzero, reports migration pending, and does not claim readiness;
- legacy cleanup is the only reconciliation mode that may use the tombstones.

Preview cleanup first:

```sh
swift run calrelay reconcile --cleanup-legacy
```

After reviewing the deletion-only plan, apply it explicitly:

```sh
swift run calrelay reconcile --cleanup-legacy --apply
```

Cleanup performs no ordinary creates or current-marker reconciliation. It searches the configured hub and every locally configured work calendar from the start of local date September 15, 2026 through the end of local date `D + 365`, where `D` is the run's captured reference local date. Every configured role must resolve uniquely, be writable, and be readable over that complete range before deletion begins.

After completing its planned deletions, cleanup apply re-reads the entire configured cleanup range and reports success only if that verification snapshot contains no matching legacy marker. Cleanup success remains local and point-in-time: another computer that still publishes `[OLD]` may recreate matching events later. Repeated cleanup is expected until every publisher has migrated. Remove `legacyMarkers` manually only after the required cleanup runs for your topology; CalRelay never edits the YAML automatically.

## Validation and safety notes

- At least one work calendar must be configured.
- Source/title selector fields and work-calendar names must not be empty.
- `syncWindowDays` controls the ordinary forward horizon, accepts `1...365`, and defaults to `100` when omitted.
- Each ordinary run also includes a fixed two-local-date lookback. Whole local dates use the system calendar and time zone captured at run start.
- Unknown YAML fields, duplicate mapping keys, malformed markers, marker collisions, and exact duplicate selector tuples fail before EventKit access.
- Configuration errors are reported without echoing raw YAML content.
- CalRelay requires full Calendar access. CLI commands never prompt; use the setup/recovery surface in `CalRelay.app` when access is unavailable.
- Ordinary config check, dry-run, apply, and explanation require every configured calendar to be readable over the ordinary window and currently writable.
- Cleanup requires every configured calendar to be readable over the complete cleanup range and currently writable.
- CalRelay never deletes an unmarked original work/client event during ordinary reconciliation.
- Timed events from calendars that do not expose EventKit availability are treated as blocking events unless they are all-day, declined, or cancelled.
- "Declined" status is evaluated from the current user's own attendee response, not from other attendees.

For app-backed EventKit validation checks, see [`docs/manual-validation.md`](manual-validation.md).
