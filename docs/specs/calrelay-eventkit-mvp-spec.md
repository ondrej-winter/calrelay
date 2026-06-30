# Spec: CalRelay EventKit MVP

## Objective

Build a local macOS Swift CLI that uses EventKit-visible Apple Calendar calendars to prevent double-booking across configured work/client calendars for a configurable sync window, defaulting to the next 60 days.

The MVP is for a single user who wants one personal Apple Calendar work calendar to act as a reliable availability hub across multiple client calendars without requiring direct Google Calendar API, Microsoft Graph API, OAuth app registration, tenant approval, or provider-specific sync tokens.

## Current context

- Source idea: `docs/ideas/calrelay-eventkit-mvp.md`.
- The repository currently has no Swift package skeleton.
- `README.md` is intentionally minimal and should link to this spec as the canonical product/implementation definition.
- Project rules prefer Swift Package Manager, hexagonal architecture, vertical feature slices, and adapters around EventKit/platform APIs.
- Apple Calendar/EventKit is the integration surface: if a client calendar is visible and writable in Apple Calendar, CalRelay can participate.
- The MVP targets macOS 26+.

## Desired behavior

### Core workflow

- Request calendar permission at the platform boundary.
- List available calendars, sources/accounts, and writable/read-only status.
- Load configuration for:
  - hub calendar
  - one or more locally available work/client calendars
  - unique prefix per work/client calendar
  - personal-origin prefix, such as `[ME]`
  - sync window, defaulting to the next 60 days
- Use YAML as the initial configuration format.
- Perform dry-run reconciliation that prints events to create and delete without mutating calendars.
- Perform apply-mode reconciliation only when explicitly requested with `--apply` after configuration validation succeeds.
- Repeat safely: running reconciliation twice after a successful apply should produce no second-run changes.

### Reconciliation model

- Use visible set reconciliation rather than provider IDs, hidden metadata, notes metadata, or a local identity mapping store.
- Treat generated events as disposable projections.
- Do not detect renames as renames. A changed or renamed source event means:

  ```text
  old projection no longer expected -> delete it
  new projection now expected -> create it
  ```

- Copy only visible calendar fields:
  - title
  - start time
  - end time
  - all-day flag
  - destination calendar
- For MVP equality, compare events by:

  ```text
  calendar + title + start + end + all-day flag
  ```

- Timezone normalization may be added after EventKit behavior is tested.

### Source event inclusion defaults

For the first MVP:

- Include timed busy events.
- Include tentative timed events.
- Skip all-day events.
- Skip declined events.
- Skip cancelled events.
- Copy recurring events occurrence-by-occurrence inside the sync window when EventKit exposes those occurrences.
- Treat each exposed recurring occurrence as an ordinary visible event snapshot for reconciliation.
- Do not preserve or reproduce original recurrence-rule configuration.

### Managed-event safety convention

- Every event CalRelay is allowed to delete must be visibly marked with a configured prefix.
- Prefixes are both human-readable source markers and CalRelay ownership markers.
- CalRelay may delete stale prefixed events in configured managed calendars.
- CalRelay must never delete unprefixed events from work/client calendars.
- CalRelay must preserve unknown prefixed events by default rather than treating them as stale local projections.
- CalRelay must mutate only the hub calendar and locally configured writable work/client calendars for the current run.
- Manual edits to prefixed generated events may be overwritten or deleted by reconciliation.

### Multi-computer topology

CalRelay may run on multiple computers where each machine can see the shared hub calendar plus only a subset of work/client calendars. For example:

```text
Laptop A: Personal Work hub + ACME
Laptop B: Personal Work hub + BETA
Laptop C: Personal Work hub + ACME + BETA
```

Each machine is responsible only for its locally configured work calendars and prefixes. A machine must not delete hub events with unknown or remote prefixes just because their source work calendar is not configured locally.

Remote prefixed hub events can still act as blockers for local work calendars. For example, if Laptop A is configured only with ACME but sees `[BETA] Sales Call` in the hub, it may project `[BETA] Sales Call` into ACME to prevent double-booking, but it must not delete the `[BETA]` hub event.

### Routing rules

Given this conceptual configuration:

```text
Hub calendar: Personal Work

Work calendars:
- ACME with prefix [ACME]
- BETA with prefix [BETA]
- CONTOSO with prefix [CONTOSO]

Personal-origin prefix: [ME]
```

Work calendar to hub:

```text
ACME: Client Planning
-> Personal Work: [ACME] Client Planning
```

Prefixed hub event to other work calendars:

```text
Personal Work: [ACME] Client Planning
-> BETA: [ACME] Client Planning
-> CONTOSO: [ACME] Client Planning
-> not ACME
```

Unprefixed hub event to all work calendars:

```text
Personal Work: Dentist
-> ACME: [ME] Dentist
-> BETA: [ME] Dentist
-> CONTOSO: [ME] Dentist
```

Remote prefixed hub event to locally configured work calendar:

```text
Machine configuration: hub + ACME only

Personal Work: [BETA] Sales Call
-> ACME: [BETA] Sales Call
-> do not delete [BETA] Sales Call from Personal Work
```

Unknown prefixed events in work calendars are preserved by default unless a future configuration explicitly opts into managing that prefix.

### Initial configuration shape

The initial configuration format is YAML. The implementation uses `Yams` rather than hand-rolling a parser.

Example single-work-calendar configuration using source/title selectors:

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

Calendar selection is by source/title selector for the MVP. EventKit calendar IDs may be displayed by the calendar listing command for troubleshooting, but they are not the canonical configuration key.

The executable command name is `calrelay`.

## Commands and validation

Initial commands once the SwiftPM package exists:

- Build: `swift build`
- Test: `swift test`
- Basic command/help check: `swift run calrelay --help`.
- Calendar capability check: run the CLI command that lists calendars, sources/accounts, and writability.
- Dry-run check: run reconciliation in dry-run mode and inspect planned creates/deletes.
- Idempotency check: run reconciliation twice after apply and confirm the second run is a no-op.
- Rename/change check: rename a representative source event and confirm the old projection is deleted and the new projection is created.
- EventKit write check: create, update, and delete a harmless generated blocker in each configured writable test calendar.
- Double-booking check: verify a representative conflict across at least two configured work calendars is projected across calendars for the next 60 days.

## Project structure

- `Package.swift`: SwiftPM package manifest.
- `Sources/CalRelay/Features/CalendarRelay/Domain/`: pure projection and reconciliation rules.
- `Sources/CalRelay/Features/CalendarRelay/Application/UseCases/`: use-case orchestration.
- `Sources/CalRelay/Features/CalendarRelay/Application/Ports/`: EventKit/calendar store outbound port protocols and CLI-facing inbound use-case protocols when needed.
- `Sources/CalRelay/Features/CalendarRelay/Application/DTOs/`: commands, queries, results, event snapshots, calendar snapshots, and settings DTOs.
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/`: command parsing and user-facing command output.
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Outbound/EventKit/`: EventKit calendar adapter, permission handling, and platform mapping.
- `Tests/Unit/Features/CalendarRelay/`: deterministic domain/application tests with fakes.
- `Tests/Integration/Features/CalendarRelay/Adapters/`: optional EventKit adapter capability tests that are not required for default local test runs.
- `docs/specs/calrelay-eventkit-mvp-spec.md`: accepted specification.

## Conventions

- Keep EventKit, permissions, calendar IDs, calendar stores, and mutation mechanics inside adapters.
- Keep reconciliation logic pure and unit-testable.
- Keep configuration loading, parsing, defaulting, and validation in adapters or bootstrap code before constructing application services.
- Use YAML for initial configuration and document any YAML parser dependency.
- Use source/title selectors as the MVP calendar configuration model rather than EventKit ID-only configuration.
- Use `swift-argument-parser` for CLI command parsing rather than maintaining custom parsing logic.
- Target macOS 26+ and keep EventKit permission APIs isolated inside the EventKit adapter.
- Pass validated settings into application use cases as explicit DTOs.
- Prefer Swift structured concurrency for asynchronous workflows.
- Default to dry-run unless `--apply` is passed.
- Use conservative deletion rules.
- Use the project-configured logging mechanism for diagnostics; prefer Apple's `Logger` from `os` if no other logging stack exists.
- CLI user output may be explicit command output, but production diagnostics should not rely on ad hoc `print()` calls.
- Do not introduce direct provider APIs, OAuth, hidden source identifiers, notes metadata, or local identity mapping in the MVP.
- Do not log secrets, full raw user calendar contents, full file paths, or unnecessary private user data.

## Testing strategy

Unit-test set reconciliation for:

- work-to-hub projection
- prefixed hub-to-other-work projection
- unprefixed hub-to-all-work projection using the personal-origin prefix
- stale prefixed deletion
- refusal to delete unprefixed events
- idempotent second run
- rename/change behavior as delete old projection plus create new projection
- skipped all-day events
- skipped declined events
- skipped cancelled events
- repeated titles and adjacent meetings
- tentative timed event inclusion
- recurring occurrences treated as ordinary visible event snapshots when EventKit exposes them in the sync window
- unknown prefixed hub events preserved rather than deleted as stale local projections
- remote prefixed hub events projected into locally configured work calendars
- unknown prefixed work-calendar events preserved by default

Use fakes for calendar repository/EventKit ports in domain and application tests. Reserve real EventKit checks for manual validation or explicit integration/capability runs, because they depend on local Apple Calendar state, permissions, and writable calendars.

## Boundaries

- Always: statically validate required selectors, prefix uniqueness, personal-prefix conflicts, and sync-window values before reconciliation.
- Always: resolve selectors against visible EventKit calendars and validate apply-mode writability before mutation.
- Always: fail safely when calendar permissions are unavailable, denied, revoked, or a target calendar is read-only.
- Always: mutate only calendars configured for the current run.
- Always: map EventKit framework types into application DTOs at the adapter boundary.
- Always: keep SwiftUI/AppKit/menu-bar/background-agent work out of the MVP unless explicitly approved later.
- Ask first: adding persistent stores, hidden source IDs, provider APIs, OAuth, UI/menu-bar app, background agent behavior, launch agents, or synchronization daemons.
- Ask first: changing the source event inclusion defaults from hard-coded MVP behavior to user configuration.
- Never: mutate or delete original unprefixed work/client calendar events.
- Never: pass EventKit types into domain or application APIs.
- Never: rely on live external provider APIs in default tests.

## Success criteria

- This spec is accepted and implementation tasks are traceable to it.
- A SwiftPM CLI can list calendars, sources/accounts, and writable status.
- Given representative configured calendars, dry-run mode shows expected creates/deletes without mutation.
- Apply mode can reconcile generated prefixed projections.
- Running reconciliation twice after apply produces no second-run changes.
- Renaming a source event deletes the old projection and creates the new projection.
- CalRelay never deletes unprefixed original work/client events.
- CalRelay preserves unknown prefixed events by default in multi-computer setups.
- CalRelay can project remote prefixed hub blockers into locally configured work calendars.
- A representative double-booking scenario is prevented across at least two configured work calendars over the next 60 days.
- Unit tests cover the core reconciliation rules without real EventKit access.

## Open questions

- Are source/title selectors stable enough across the user's Apple Calendar accounts, or will a fallback ID selector be needed later?
- Should all-day, declined, and cancelled event handling remain hard-coded for MVP or become configurable from day one?
- Should tentative timed events remain included by default after real-world testing?
- Which exact `Yams` and `swift-argument-parser` versions should be pinned after the SwiftPM package is created?
- Can EventKit reliably expose recurring occurrences as ordinary visible event snapshots inside the sync window?
- Is the 60-day default sync window sufficient, or should the first implementation require explicit configuration?

## Explicitly out of scope

- Direct Google Calendar API.
- Direct Microsoft Graph API.
- OAuth, app registrations, tenant approvals, or provider-specific sync tokens.
- Hidden source IDs.
- Notes metadata.
- Local identity mapping store.
- Privacy sanitization beyond conservative field copying and safe diagnostics.
- Mutation of original unprefixed client/work events.
- Full semantic two-way editing of arbitrary original events.
- Mobile app.
- Team or multi-user product features.
- Perfect recurring-event support before the EventKit capability spike proves viability.
- UI/menu-bar app before the CLI/capability spike proves EventKit writability and sync safety.