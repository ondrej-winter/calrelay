# CalRelay configuration

CalRelay reads a strict YAML configuration that identifies one hub calendar and one or more locally available work calendars by Calendar source title and calendar title. The documented keys and nesting are the accepted schema; unknown fields and duplicate mapping keys are rejected.

## Configuration file location

By default, the CLI and macOS app read the canonical user configuration file at:

```text
~/.config/calrelay/config.yaml
```

For normal use, create the YAML configuration there. CalRelay does not create or rewrite this file automatically and does not search arbitrary directories for configuration files. The app does not provide a visual configuration editor or remember an alternate configuration path.

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

Marker identity is case-sensitive. `[ACME]` and `[acme]` are different markers. The personal marker, every current work marker, and every legacy marker must be pairwise distinct within one configuration.

When multiple active CalRelay configurations share a hub, every current work marker and personal marker must also be globally unique across those configurations. CalRelay has no global marker registry and cannot verify this operator-managed requirement. A collision can suppress or delete a valid blocker rather than merely produce an ambiguous label.

A title has marker semantics only in this exact shape:

```text
[ACME] Planning
```

The marker must be followed by exactly one ASCII space and nonempty title text. CalRelay compares the parsed marker exactly; it does not use raw starts-with matching. For example, marker `[A]` does not match `[ACME] Planning`.

When generating a projection, CalRelay trims surrounding whitespace from the source title and uses `(Untitled)` if nothing remains.

### Reserved marker namespace

Every non-cancelled valid marked event in the hub acts as an authoritative blocker source regardless of its attendee response or availability. A marker owned by a locally configured work calendar is not routed back to that origin calendar; an unknown or remote marker is copied unchanged into every locally configured work calendar. A cancelled valid marked hub event is preserved according to ownership rules but is not routed.

In the hub, every current locally configured work-marker namespace is reserved for CalRelay projections. A manually created title such as `[ACME] Vendor Call` is indistinguishable from a local ACME projection and may be deleted when stale or duplicated.

In configured work calendars, the valid leading-marker namespace is reserved for CalRelay-managed blockers. A manually created title such as `[FOCUS] Deep Work` is indistinguishable from a relayed blocker and may be deleted when no matching marked hub event exists. Use an unmarked title for ordinary source events that CalRelay must preserve.

### Multi-computer topology

Multiple computers may share the hub, but their actively managed physical work calendars must be disjoint. Each physical work calendar has exactly one active CalRelay writer. CalRelay cannot verify this across computers; violating it can create duplicates or cause one writer to delete another writer's projections.

The app prevents overlap among triggers inside its own process, but it does not lock out CLI processes or CalRelay running elsewhere. Concurrent applies and non-atomic sequential calendar reads can temporarily create duplicate, stale, or missing projections. A later fresh reconciliation is the recovery mechanism.

## Projection eligibility, window, and copied data

CalRelay applies one fixed eligibility policy to timed and all-day source events:

- a reliably cancelled event is skipped;
- when EventKit identifies you as an attendee, only your accepted response is included, and acceptance overrides the event's availability value;
- your tentative, declined, pending, delegated, unknown, or other non-accepted response skips the event;
- other attendees' responses and non-cancelled overall event status are ignored; and
- when EventKit exposes no current-user attendee record, busy, not-supported, and unavailable events are included, while free, tentative, unknown, and future unrecognized availability values are skipped.

This policy is not configurable. A non-cancelled valid marked hub event bypasses source eligibility because it is already the relay's authoritative blocker envelope.

At ordinary-run start, CalRelay captures the Mac's current system calendar and time zone. If `D` is the captured local date, the effective window covers local dates `D - 2` through `D + syncWindowDays`, inclusive. An event is in the window when any positive-duration portion overlaps it. Events touching only the start or end boundary are excluded, and overlapping events keep their complete original interval rather than being clipped.

CalRelay copies EventKit's returned start, end, and all-day values unchanged and relies on EventKit for timed-event display and floating all-day behavior across time zones. It does not set projection availability explicitly; destination-provider defaults determine whether the visible projection is reported as busy.

Projected titles are copied after trimming surrounding whitespace and substituting `(Untitled)` for an empty result. Titles can therefore cross personal and work account boundaries and may be exposed through providers, notifications, sharing, and delegated calendar access.

EventKit's successful recurring-occurrence snapshot is authoritative for that run. CalRelay projects each returned occurrence, including detached edits, independently without reproducing recurrence rules or promising that a provider exposed every theoretical occurrence.

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

## macOS app scheduling contract

The accepted macOS automation milestone uses the same canonical YAML and reusable reconciliation behavior as the CLI. The app reloads and validates the file for every status refresh and every manual or automatic run; it never continues mutating from a last-known-valid copy after the selected file becomes missing, invalid, or migration pending.

Before scheduling can be enabled for the first time, the app requires a successful ordinary dry run, presents its create/delete summary, and obtains explicit standing authorization for automatic ordinary apply runs. Enabling scheduling also enables launch-at-login for the normal Dock-visible app.

While the normal app is running and healthy, automatic reconciliation uses:

- a fixed 15-minute cadence;
- one prompt run at every app launch and Mac wake; and
- bounded retries for transient failures.

The app treats more than 60 minutes since the latest successful ordinary reconciliation as overdue freshness. Scheduling may be paused after setup, but the paused state remains visibly degraded because CalRelay is no longer maintaining freshness.

Standing authorization is bound to the mutation-relevant validated settings. Changing a configured calendar selector, current or personal marker, `syncWindowDays`, or legacy-marker set suspends automatic mutation until the app presents a successful dry run for the new settings and the user renews authorization. Comments, quoting, key order, and other YAML-only formatting changes do not require reauthorization when validated mutation behavior is unchanged.

These requirements are the accepted contract for the next app implementation milestone. CLI behavior and arguments remain unchanged.

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
- only an explicit legacy-cleanup workflow in the CLI or app may use the tombstones.

Preview cleanup first:

```sh
swift run calrelay reconcile --cleanup-legacy
```

After reviewing the deletion-only plan, apply it explicitly:

```sh
swift run calrelay reconcile --cleanup-legacy --apply
```

Before adding a marker to `legacyMarkers`, retire it from every current work-marker and personal-marker role in every active configuration sharing the hub. CalRelay cannot verify this global prerequisite.

The accepted app milestone also provides an explicit cleanup dry-run and apply surface. App cleanup uses the same bounded plan, complete-topology preflight, exact marker selection, and post-apply verification as the CLI. It presents each selected event's title, configured role, and time or all-day range transiently and requires separate confirmation for the exact fresh cleanup plan; scheduling authorization never authorizes cleanup. EventKit IDs, selectors, calendar titles, and marker values remain hidden, and review details are never persisted or logged.

CLI cleanup dry-run shows the same per-event review details. Direct `--cleanup-legacy --apply` shows its fresh detailed plan and remains non-interactive: `--apply` alone authorizes mutation, and a prior dry-run is recommended but not enforced.

Cleanup performs no ordinary creates or current-marker reconciliation. With `D` as the captured local date, it searches the configured hub and every locally configured work calendar over local dates `D - 2` through `D + 365`, inclusive, using the same positive-overlap rule as ordinary reconciliation. Every configured role must resolve uniquely, be writable, and be readable over that complete bounded range before deletion begins.

After completing its planned deletions, cleanup apply re-reads the entire configured cleanup range and reports success only if that verification snapshot contains no matching legacy marker. Cleanup success remains local and point-in-time: another computer may recreate `[OLD]` later, and matching events older than the two-date lookback may remain indefinitely. Repeated cleanup is expected until every publisher has migrated. Remove `legacyMarkers` manually only after the required cleanup runs for your topology; CalRelay never edits the YAML automatically.

Cleanup accepts only the current exact marker grammar. Historical events using an old arbitrary prefix, malformed separator, empty marked title, or another non-exact shape require manual identification and removal; CalRelay never uses fuzzy or heuristic deletion.

## Validation and safety notes

- At least one work calendar must be configured.
- Source/title selector fields and work-calendar names must not be empty.
- `syncWindowDays` controls the ordinary forward horizon, accepts `1...365`, and defaults to `100` when omitted.
- Each ordinary and cleanup run includes a fixed two-local-date lookback. Whole local dates use the system calendar and time zone captured at run start.
- Unknown YAML fields, duplicate mapping keys, malformed markers, marker collisions, and exact duplicate selector tuples fail before EventKit access.
- Configuration errors are reported without echoing raw YAML content.
- App automation authorization does not preserve or expose raw YAML, selectors, calendar titles, or marker values; mutation-relevant changes require renewed dry-run review and authorization.
- CalRelay requires full Calendar access. CLI commands never prompt; use the setup/recovery surface in `CalRelay.app` when access is unavailable.
- Ordinary config check, dry-run, apply, and explanation require every configured calendar to be readable over the ordinary window and currently writable.
- Cleanup requires every configured calendar to be readable over the complete cleanup range and currently writable.
- CalRelay never deletes an unmarked original work/client event during ordinary reconciliation.
- Plan-time ownership remains the authority after mutation begins. A marked event edited after planning may still be deleted as the exact planned occurrence.
- Ordinary apply attempts all creates before any deletes and stops immediately on the first mutation failure without rollback.
- When two or more managed events satisfy one expected visible key, CalRelay creates one replacement and deletes every existing duplicate rather than choosing one survivor.
- Current-marker and legacy projections older than the moving two-date lookback may remain indefinitely.

For app-backed EventKit validation checks, see [`docs/manual-validation.md`](manual-validation.md).
