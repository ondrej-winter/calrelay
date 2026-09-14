# Spec: CalRelay EventKit MVP

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — template-alignment audit on September 14, 2026; no product requirements changed.
- **Canonical artifact:** `docs/specs/calrelay-eventkit-mvp-spec.md`.
- **Source of truth:** This specification supersedes the exploratory note at `docs/ideas/calrelay-eventkit-mvp.md` for MVP requirements.
- **Acceptance basis:** Repository history identifies this file as the canonical product definition and records subsequent implementation and requirement updates. An individual approver and acceptance date were not recorded.
- **Next authorized step:** Maintain this specification when MVP behavior changes; derive or update implementation plans only for accepted changes.

## Revision history

- **Revision 2 — September 14, 2026:** Aligned the document structure with the specification template. Preserved the existing accepted requirements, boundaries, and unresolved decisions.
- **Revision 1 — June 30, 2026:** Initial canonical MVP specification, subsequently refined through repository changes.

## Objective

Build a local macOS Swift CLI that uses EventKit-visible Apple Calendar calendars to prevent double-booking across configured work/client calendars for a configurable sync window, defaulting to the next 60 days.

The MVP is for a single user who wants one personal Apple Calendar work calendar to act as a reliable availability hub across multiple client calendars without requiring direct Google Calendar API, Microsoft Graph API, OAuth app registration, tenant approval, or provider-specific sync tokens.

## Current context

- Source idea: `docs/ideas/calrelay-eventkit-mvp.md`.
- The repository now has a Swift Package Manager implementation with separate core, adapter, CLI, app, and test targets.
- `README.md` links to this spec as the canonical product definition and to the implementation plan for completed MVP delivery notes.
- Project rules prefer Swift Package Manager, hexagonal architecture, vertical feature slices, and adapters around EventKit/platform APIs.
- Apple Calendar/EventKit is the integration surface: if a client calendar is visible and writable in Apple Calendar, CalRelay can participate.
- The MVP targets macOS 26+.

## Required outcomes

### REQ-01 — Core workflow

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

### REQ-02 — Visible-set reconciliation model

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

### REQ-03 — Source-event inclusion defaults

For the first MVP:

- Include timed busy events.
- Skip tentative timed events.
- Skip all-day events.
- Skip declined events.
- Skip cancelled events.
- Copy recurring events occurrence-by-occurrence inside the sync window when EventKit exposes those occurrences.
- Treat each exposed recurring occurrence as an ordinary visible event snapshot for reconciliation.
- Do not preserve or reproduce original recurrence-rule configuration.

### REQ-04 — Managed-event safety convention

- Every event CalRelay is allowed to delete must be visibly marked with a configured prefix.
- Prefixes are both human-readable source markers and CalRelay ownership markers.
- CalRelay may delete stale prefixed events in configured managed calendars.
- CalRelay must never delete unprefixed events from work/client calendars.
- CalRelay must preserve unknown prefixed hub events by default rather than treating them as stale local projections.
- CalRelay must delete stale prefixed events from work calendars when they are no longer expected from the hub, even when the prefix belongs to a work calendar not configured on the current machine.
- CalRelay must mutate only the hub calendar and locally configured writable work/client calendars for the current run.
- Manual edits to prefixed generated events may be overwritten or deleted by reconciliation.

### REQ-05 — Multi-computer topology

CalRelay may run on multiple computers where each machine can see the shared hub calendar plus only a subset of work/client calendars. For example:

```text
Laptop A: Personal Work hub + ACME
Laptop B: Personal Work hub + BETA
Laptop C: Personal Work hub + ACME + BETA
```

Each machine is responsible only for its locally configured work calendars and prefixes. A machine must not delete hub events with unknown or remote prefixes just because their source work calendar is not configured locally.

Remote prefixed hub events can still act as blockers for local work calendars. For example, if Laptop A is configured only with ACME but sees `[BETA] Sales Call` in the hub, it may project `[BETA] Sales Call` into ACME to prevent double-booking, but it must not delete the `[BETA]` hub event.

### REQ-06 — Routing rules

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

Unknown prefixed events in the hub are preserved by default unless a future configuration explicitly opts into managing that prefix. Unknown prefixed events in work calendars are treated as relayed blockers and removed when absent from the expected hub-derived blocker set.

### REQ-07 — Initial configuration shape

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
- `Sources/CalRelayKit/Features/CalendarRelay/Domain/`: pure projection and reconciliation rules.
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/`: use-case orchestration.
- `Sources/CalRelayKit/Features/CalendarRelay/Application/Ports/`: EventKit/calendar store outbound port protocols.
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/`: settings, snapshots, reconciliation plans, commands, queries, and results that cross application boundaries.
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/`: user-facing output formatting.
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/Config/`: YAML configuration parsing, defaulting, and mapping into application DTOs.
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/`: EventKit calendar adapter, permission handling, and platform mapping.
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/`: executable CLI command parsing and composition.
- `Sources/CalRelayApp/`: minimal app wrapper used for app-bundle Calendar permission and capability validation.
- `Tests/CalRelayContractTests/`: deterministic domain/application/adapter contract tests with fakes. This target is the default `swift test` gate and does not require real EventKit access.
- Optional real EventKit capability checks are documented in `docs/manual-validation.md` and are run through `CalRelay.app` or explicit local validation, not default tests.
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

## Verification approach

The following validation establishes conformance for the requirements above.

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
- tentative timed event exclusion
- recurring occurrences treated as ordinary visible event snapshots when EventKit exposes them in the sync window
- unknown prefixed hub events preserved rather than deleted as stale local projections
- remote prefixed hub events projected into locally configured work calendars
- unknown prefixed work-calendar events deleted when absent from the expected hub-derived blocker set

Use fakes for calendar repository/EventKit ports in domain and application tests. Reserve real EventKit checks for `CalRelay.app`-backed capability runs or explicit integration checks, because they depend on local Apple Calendar state, permissions, and writable calendars.

## Binding constraints and execution boundaries

These constraints are mandatory for work governed by this specification.

- **CON-01:** Statically validate required selectors, prefix uniqueness, personal-prefix conflicts, and sync-window values before reconciliation.
- **CON-02:** Resolve selectors against visible EventKit calendars and validate apply-mode writability before mutation.
- **CON-03:** Fail safely when Calendar permission is unavailable, denied, revoked, or a target calendar is read-only.
- **CON-04:** Mutate only calendars configured for the current run and map EventKit types into application DTOs at the adapter boundary.
- **CON-05:** Keep SwiftUI/AppKit/menu-bar/background-agent work out of the MVP unless explicitly approved later.
- **CON-06:** Adding persistent stores, hidden source IDs, provider APIs, OAuth, UI/menu-bar app, background-agent behavior, launch agents, or synchronization daemons requires an explicit decision.
- **CON-07:** Changing hard-coded MVP source-event inclusion defaults to user configuration requires an explicit decision.
- **CON-08:** Never mutate or delete original unprefixed work/client events, pass EventKit types into domain/application APIs, or rely on live external provider APIs in default tests.

## Acceptance checks

- **AC-01 (REQ-01):** A SwiftPM CLI lists calendars, sources/accounts, and writable status; dry-run shows expected creates/deletes without mutation; apply runs only when explicitly requested.
- **AC-02 (REQ-01, REQ-02):** A second reconciliation after successful apply produces no changes, and renaming a source event deletes the old projection and creates the new projection.
- **AC-03 (REQ-03):** Representative events demonstrate the documented inclusion defaults, including occurrence-by-occurrence projection of visible recurring instances within the sync window.
- **AC-04 (REQ-04, CON-08):** CalRelay never deletes unprefixed original work/client events.
- **AC-05 (REQ-05, REQ-06):** In a representative multi-computer topology, unknown prefixed hub events are preserved while remote prefixed hub blockers can be projected into locally configured work calendars.
- **AC-06 (REQ-06):** A representative scenario prevents double-booking across at least two configured work calendars over the next 60 days.
- **AC-07 (REQ-07, CON-01, CON-02, CON-03):** Invalid configuration, unavailable Calendar permission, and read-only mutation targets fail before unsafe mutation.
- **AC-08 (REQ-02, CON-04, CON-08):** Deterministic unit tests cover core reconciliation rules without real EventKit access or EventKit types in domain/application APIs.

## Unresolved decisions

- **OPEN-01:** Are source/title selectors stable enough across the user's Apple Calendar accounts, or will a fallback ID selector be needed later?
- **OPEN-02:** Should all-day, declined, and cancelled event handling remain hard-coded for MVP or become configurable from day one?
- **OPEN-03:** Should tentative timed events become configurable after real-world testing?
- **OPEN-04:** Can EventKit reliably expose recurring occurrences as ordinary visible event snapshots inside the sync window?
- **OPEN-05:** Is the 60-day default sync window sufficient, or should the first implementation require explicit configuration?

## Explicit exclusions

- **EXC-01:** Direct Google Calendar API, Microsoft Graph API, OAuth, app registrations, tenant approvals, and provider-specific sync tokens.
- **EXC-02:** Hidden source IDs, notes metadata, and a local identity mapping store.
- **EXC-03:** Privacy sanitization beyond conservative field copying and safe diagnostics.
- **EXC-04:** Mutation of original unprefixed client/work events and full semantic two-way editing of arbitrary original events.
- **EXC-05:** Mobile-app, team, and multi-user product features.
- **EXC-06:** Perfect recurring-event support and a UI/menu-bar app before the CLI/capability spike proves EventKit writability and sync safety.

## Traceability

- **REQ-01–REQ-02:** AC-01, AC-02, AC-08.
- **REQ-03:** AC-03.
- **REQ-04:** AC-04.
- **REQ-05–REQ-06:** AC-05, AC-06.
- **REQ-07:** AC-07.