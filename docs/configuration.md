# CalRelay configuration

CalRelay reads YAML configuration that identifies one hub calendar and one or more work calendars by Calendar source title and calendar title.

## Example

```yaml
hubCalendar:
  sourceTitle: "iCloud"
  calendarTitle: "Personal Work"
personalPrefix: "[ME]"
syncWindowDays: 60
workCalendars:
  - name: "ACME"
    prefix: "[ACME]"
    calendar:
      sourceTitle: "Google"
      calendarTitle: "ACME Work"
```

## Fields

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `hubCalendar.sourceTitle` | String | Yes | None | Calendar account/source title that contains the hub calendar. |
| `hubCalendar.calendarTitle` | String | Yes | None | Hub calendar title. |
| `personalPrefix` | String | Yes | None | Prefix used when copying unprefixed hub events into work calendars. |
| `syncWindowDays` | Integer | No | `60` | Number of days in the reconciliation window. Must be greater than zero. |
| `workCalendars[].name` | String | Yes | None | Human-readable configured work calendar name used in validation messages. |
| `workCalendars[].prefix` | String | Yes | None | Prefix that identifies projections from this work calendar, such as `[ACME]`. Must be unique. |
| `workCalendars[].calendar.sourceTitle` | String | Yes | None | Calendar account/source title that contains the work calendar. |
| `workCalendars[].calendar.calendarTitle` | String | Yes | None | Work calendar title. |

## Selector semantics

Calendar selectors use `sourceTitle` plus `calendarTitle` rather than EventKit calendar IDs. This keeps configuration readable and avoids relying on opaque local identifiers. Later calendar-resolution steps reject selectors that match zero calendars or multiple calendars.

Use the calendar listing command to discover the exact source/calendar titles and writable status visible to EventKit:

```sh
swift run calrelay calendars
```

The listing includes EventKit calendar IDs for troubleshooting, but IDs are not the canonical configuration key for the MVP.

## Commands

Dry-run reconciliation is the default and performs no calendar mutations:

```sh
swift run calrelay reconcile --config calrelay.yml
```

Apply mode creates missing prefixed projection events and deletes stale prefixed projections selected by the reconciliation plan:

```sh
swift run calrelay reconcile --config calrelay.yml --apply
```

Review dry-run output before using `--apply`, especially when introducing new prefixes or changing calendar selectors.

## Validation and safety notes

- At least one work calendar must be configured.
- Source/title selector fields must not be empty.
- `syncWindowDays` must be positive.
- Work calendar prefixes must be unique.
- `personalPrefix` must not match any configured work calendar prefix.
- Configured prefixes identify CalRelay-managed projections during reconciliation. Use dry-run output to review planned deletes before running apply mode.
- Configuration errors are reported without echoing raw YAML content.
- CalRelay requires full Calendar access. If macOS denies or restricts access, listing and reconciliation fail safely.
- Apply mode requires writable target calendars. Read-only calendars are rejected before planned mutations are executed.
- CalRelay must never delete unprefixed original work/client events; deletion is limited to stale prefixed projections selected by the conservative reconciliation logic.
- Timed events from calendars that do not expose EventKit availability are treated as blocking events for MVP reconciliation, unless they are all-day, declined, or cancelled.
