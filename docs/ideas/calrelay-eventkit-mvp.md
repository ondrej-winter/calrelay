# CalRelay EventKit MVP

## Problem Statement

How might we keep one personal Apple Calendar work calendar as the reliable availability hub across multiple client calendars, without needing blocked Google/Microsoft APIs and without accidentally echoing events back into their source calendar?

The first practical pain to solve is preventing double-booking across multiple work calendars. A rough CLI MVP is useful only if it can prevent an actual double-booking scenario across the configured calendars for the next 60 days.

## Recommended Direction

Build CalRelay as a local macOS EventKit-based relay. Apple Calendar is the integration surface: if a client calendar is visible and writable in Apple Calendar, CalRelay can participate without OAuth apps, tenant admin approvals, or provider-specific API onboarding.

The MVP should use **visible set reconciliation** rather than provider IDs, hidden metadata, or local identity mapping. CalRelay repeatedly computes the expected visible event set from configured calendars and reconciles managed calendars to that expected set.

Generated events are disposable projections. A rename is not detected as a rename. Instead:

```text
old projection no longer expected -> delete it
new projection now expected -> create it
```

## Core Principle

CalRelay copies visible calendar fields only:

- title
- start time
- end time
- all-day flag
- destination calendar

For MVP equality, events are compared by:

```text
calendar + title + start + end + all-day flag
```

Timezone normalization may be added after EventKit behavior is tested.

For the first MVP, source-event inclusion should default to:

- include timed busy events
- include tentative timed events
- skip all-day events
- skip declined events
- skip cancelled events

Recurring events should be copied occurrence by occurrence inside the sync window. The MVP does not need to preserve or reproduce the original recurrence-rule configuration.

## Managed-Event Convention

Every event CalRelay is allowed to delete must be visibly marked with a configured prefix.

This creates the safety rule:

> CalRelay may delete stale prefixed events in configured managed calendars. CalRelay must never delete unprefixed events from work/client calendars.

Prefixes are both:

- human-readable source markers
- CalRelay ownership markers

Manual edits to prefixed generated events may be overwritten or deleted by reconciliation.

Risk posture differs by calendar role:

- Hub calendar: prefer avoiding missed blockers.
- Work/client calendars: prefer avoiding excessive mutation.

## Routing Model

Assume this configuration:

```text
Hub calendar: Personal Work

Work calendars:
- ACME with prefix [ACME]
- BETA with prefix [BETA]
- CONTOSO with prefix [CONTOSO]

Personal-origin prefix: [ME]
```

### Work calendar to hub

An unprefixed event in a work calendar is projected into the hub with that work calendar's prefix.

```text
ACME: Client Planning
-> Personal Work: [ACME] Client Planning
```

### Prefixed hub event to other work calendars

A prefixed event in the hub is projected to every work calendar except the calendar matching the prefix.

```text
Personal Work: [ACME] Client Planning
-> BETA: [ACME] Client Planning
-> CONTOSO: [ACME] Client Planning
-> not ACME
```

### Unprefixed hub event to all work calendars

An unprefixed event in the hub is treated as a personal-origin event and projected to all configured work calendars using the personal-origin prefix.

```text
Personal Work: Dentist
-> ACME: [ME] Dentist
-> BETA: [ME] Dentist
-> CONTOSO: [ME] Dentist
```

This avoids generating unprefixed client events, so CalRelay always knows what it owns.

## Reconciliation Algorithm

For each sync run:

1. Read all configured work calendars.
2. Read the hub calendar.
3. Build expected hub projections from raw work-calendar events.
   - Example: `ACME` event `Client Planning` becomes `[ACME] Client Planning` in the hub.
4. Delete stale managed prefixed events in the hub whose expected source projection no longer exists.
5. Create missing expected hub projections.
6. Build expected work-calendar projections from hub events.
   - Prefixed `[ACME] X` goes to every work calendar except `ACME`.
   - Unprefixed `Y` goes to every work calendar as `[ME] Y`.
7. For each work calendar, delete stale managed prefixed projections and create missing expected projections.
8. Repeat safely. A second run should produce no changes.

## Rename and Change Behavior

CalRelay does not track source IDs and does not detect renames. It performs set reconciliation.

Before source rename:

```text
ACME source:
- Client Planning, 10:00-11:00

Personal Work projection:
- [ACME] Client Planning, 10:00-11:00
```

After source rename:

```text
ACME source:
- Roadmap Planning, 10:00-11:00
```

CalRelay computes the expected hub state:

```text
Personal Work expected:
- [ACME] Roadmap Planning, 10:00-11:00
```

The old projection is no longer expected, so it is deleted. The new projection is missing, so it is created.

## MVP Scope

### In

- Swift/macOS CLI-first EventKit spike.
- Calendar permission request.
- Listing available calendars, sources/accounts, and writable/read-only status.
- Configuration for:
  - hub calendar
  - multiple work/client calendars
  - unique prefix per work calendar
  - personal-origin prefix, such as `[ME]`
  - sync window, defaulting to the next 60 days
- Dry-run reconciliation that prints events to create/delete.
- Apply mode that performs reconciliation. Once calendar IDs/names and unique prefixes validate successfully, `--apply` is enough for non-interactive execution.
- Idempotency check: running sync twice should make the second run a no-op.
- Rename/change check: renaming a source event deletes the old projection and creates the new projection.

### Out

- Direct Google Calendar API.
- Direct Microsoft Graph API.
- OAuth, app registrations, tenant approvals, or provider-specific sync tokens.
- Hidden source IDs.
- Notes metadata.
- Local identity mapping store.
- Privacy sanitization.
- Mutation of original unprefixed client/work events.
- Full semantic two-way editing of arbitrary original events.
- Mobile app.
- Team or multi-user product features.
- Perfect recurring-event support before the EventKit capability spike proves viability.

## Key Assumptions to Validate

- [ ] EventKit can write to the client calendars that appear in Apple Calendar.
  - Test by creating, updating, and deleting a harmless generated blocker in each configured client calendar.
- [ ] Prefix-based ownership is safe enough for a personal tool.
  - Test that stale prefixed events can be deleted without risking unprefixed original client events.
- [ ] Visible equality is good enough for MVP.
  - Test with repeated titles, adjacent meetings, all-day events, and timezone behavior.
- [ ] Prefix-based routing is understandable in daily Apple Calendar use.
  - Test manually with `[ACME]`, `[BETA]`, and `[ME]` events.
- [ ] Repeated sync runs are idempotent.
  - Test that the second run after reconciliation produces no creates or deletes.
- [ ] Occurrence-by-occurrence recurring-event projection is practical with EventKit inside the configured sync window.
  - Test that visible recurring instances can be projected without preserving recurrence rules.
- [ ] The first useful MVP can prevent double-booking across the configured work calendars for the next 60 days.
  - Test with a real or representative conflict scenario across at least two work calendars.

## Not Doing and Why

- Direct provider APIs — they undermine the point of bypassing blocked client API/OAuth/admin workflows.
- True calendar merge semantics — too ambiguous and dangerous for client calendars.
- Hidden identity tracking — unnecessary for the chosen visible set-reconciliation MVP and adds complexity before EventKit viability is proven.
- Deleting unprefixed client events — unacceptable risk; unprefixed work-calendar events are treated as originals.
- UI/menu bar app first — a CLI/capability spike proves EventKit writability and sync safety faster.
- Rich product configuration UX — configuration can start as a file until the behavior is proven.

## Open Questions Before Building

- Should all-day, declined, and cancelled events remain hard-skipped after the MVP, or become configurable later?
- Should tentative timed events remain included by default after real-world testing?
- Can EventKit reliably expose recurring occurrences in a way that supports occurrence-by-occurrence projection inside the sync window?
- Should hub events with a prefix for an unknown or removed work calendar be ignored or treated as stale managed events?
- Is the 60-day default sync window sufficient, or should it become user-configurable immediately after the MVP?

## First Implementation Target

1. Create a Swift Package CLI skeleton.
2. Add an EventKit capability command that lists calendars and writability.
3. Add a small config file for hub calendar, work calendars, prefixes, and sync window.
4. Implement dry-run set reconciliation.
5. Implement apply mode with conservative delete/create rules.
6. Run twice and verify the second run is a no-op.
7. Rename a source event and verify the old projection is deleted and the new projection is created.
8. Verify that a representative double-booking scenario is prevented across the configured calendars for the next 60 days.
