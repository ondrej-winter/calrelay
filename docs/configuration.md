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

## Validation and safety notes

- At least one work calendar must be configured.
- Source/title selector fields must not be empty.
- `syncWindowDays` must be positive.
- Work calendar prefixes must be unique.
- `personalPrefix` must not match any configured work calendar prefix.
- Configured prefixes identify CalRelay-managed projections during reconciliation. Use dry-run output to review planned deletes before running apply mode.
- Configuration errors are reported without echoing raw YAML content.