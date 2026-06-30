# Implementation Plan: CalRelay EventKit MVP

## Overview

Build `calrelay` as a local macOS Swift Package CLI. The MVP uses Apple Calendar/EventKit as the integration surface, YAML configuration, conservative visible-set reconciliation, dry-run by default, and explicit `--apply` mutation. Core reconciliation logic stays pure and unit-testable under `Sources/CalRelay/Features/CalendarRelay/Domain/`, while EventKit, YAML parsing, permission handling, and CLI I/O stay in adapters.

This plan breaks the accepted MVP spec in `docs/specs/calrelay-eventkit-mvp-spec.md` into ordered implementation tasks that can be completed and verified incrementally.

## Finalized assumptions and decisions

- Use Swift Package Manager with executable command name `calrelay`.
- Use one vertical feature slice: `Sources/CalRelay/Features/CalendarRelay/`.
- Keep EventKit imports only in `Adapters/Outbound/EventKit/`.
- Keep CLI parsing/output in `Adapters/Inbound/CLI/`.
- Keep configuration loading/parsing/defaulting at adapter/bootstrap boundaries.
- Use YAML for configuration.
- Use `Yams` as the YAML parser dependency.
- Use `swift-argument-parser` as the CLI parser dependency.
- Identify configured calendars by source/title selector, not EventKit ID-only.
- Calendar listing should still display EventKit IDs for troubleshooting.
- Target macOS 26+ for the MVP.
- Prefer CLI shape:

  ```sh
  calrelay calendars
  calrelay reconcile --config calrelay.yml
  calrelay reconcile --config calrelay.yml --apply
  ```

- Default reconciliation mode is dry-run. Mutation requires `--apply`.
- MVP event inclusion rules are hard-coded:
  - include timed busy events
  - include timed tentative events
  - skip all-day events
  - skip declined events
  - skip cancelled events
- Add separate configuration documentation from the beginning in `docs/configuration.md`.

Canonical YAML shape for the MVP uses source/title selectors:

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

## Dependency graph

```text
SwiftPM executable/package skeleton
  -> Application DTOs and ports
    -> Pure domain event/projection/reconciliation model
      -> Unit tests for routing/deletion/idempotency rules
    -> YAML config adapter and validation
    -> Application orchestration with fake calendar ports
    -> CLI commands and output formatting
    -> EventKit outbound adapter
      -> list calendars/capability command
      -> dry-run reconciliation using real snapshots
      -> apply reconciliation mutations
        -> manual EventKit write/idempotency/rename checks
```

## Phase 1: Package foundation

### Task 1: Create SwiftPM CLI skeleton

**Description:** Add a SwiftPM package with an executable target named `calrelay`, a `CalRelay` module, and a minimal CLI entry point using `swift-argument-parser` that supports `--help` without EventKit access.

**Acceptance criteria:**

- [x] `Package.swift` defines an executable product named `calrelay`.
- [x] `Package.swift` includes `swift-argument-parser` for CLI parsing.
- [x] `swift run calrelay --help` prints available commands/options and exits successfully.
- [x] Source directories follow the documented vertical-slice structure.

**Verification:**

- [x] `swift build`
- [x] `swift run calrelay --help`

**Dependencies:** None

**Files likely touched:**

- `Package.swift`
- `Package.resolved` if SwiftPM creates it
- `Sources/CalRelay/main.swift` or equivalent CLI entry point
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/...`

**Estimated scope:** Medium: 3-5 files

### Task 2: Define application DTOs, ports, and settings contracts

**Description:** Define stable internal contracts: calendar snapshots, event snapshots, calendar source/title selectors, calendar role/config settings, sync window, reconciliation plan, and calendar store port protocols.

**Acceptance criteria:**

- [x] Application DTOs model calendars, sources/accounts, writability, event snapshots, settings, and reconciliation changes without importing EventKit.
- [x] Outbound calendar port exposes calendar listing, event reading, event creation, and managed-event deletion operations.
- [x] Settings DTO includes hub calendar selector, work calendar selectors, unique prefixes, personal prefix, and sync window days.

**Verification:**

- [x] `swift build`
- [x] DTO/port files compile without EventKit imports outside adapters.

**Dependencies:** Task 1

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Application/DTOs/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/Ports/...`

**Estimated scope:** Small-Medium: 2-4 files

### Task 3: Add static settings validation rules

**Description:** Implement static validation for configuration shape before reconciliation orchestration: hub selector present, one or more work calendars, unique prefixes, personal prefix not conflicting with work prefixes, and positive sync window. Selector resolution and writable-calendar validation happen later after calendars are loaded through the calendar port.

**Acceptance criteria:**

- [x] Duplicate prefixes are rejected with user-actionable errors.
- [x] Missing hub/work calendar selectors are rejected.
- [x] Empty source/title selector fields are rejected.
- [x] Non-positive sync windows are rejected.
- [x] Validation errors do not expose private event contents or unnecessary path details.

**Verification:**

- [x] `swift test` with focused settings validation tests.
- [x] `swift build`

**Dependencies:** Task 2

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Application/UseCases/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/DTOs/...`
- `Tests/Unit/Features/CalendarRelay/Application/...`

**Estimated scope:** Medium: 3-5 files

### Checkpoint: Foundation

- [x] `swift build` passes.
- [x] `swift test` passes for initial DTO/settings validation tests.
- [x] No EventKit types appear in Domain/Application APIs.
- [x] `swift run calrelay --help` works.

## Phase 2: Pure reconciliation core

### Task 4: Implement event inclusion and visible equality model

**Description:** Add pure logic for deciding which source events participate in reconciliation and how visible events compare: calendar + title + start + end + all-day flag.

**Acceptance criteria:**

- [x] Timed busy events are included.
- [x] Tentative timed events are included.
- [x] All-day, declined, and cancelled events are skipped.
- [x] Repeated titles and adjacent meetings remain distinct when start/end differ.

**Verification:**

- [x] Focused domain tests for inclusion and equality.
- [x] `swift test`

**Dependencies:** Task 2

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Domain/...`
- `Tests/Unit/Features/CalendarRelay/Domain/...`

**Estimated scope:** Small: 1-2 files

### Task 5: Implement routing from work calendars to hub

**Description:** Build expected hub projections from unprefixed work-calendar events using each work calendar's configured prefix.

**Acceptance criteria:**

- [x] `ACME: Client Planning` produces hub event `[ACME] Client Planning`.
- [x] Source events excluded by MVP inclusion rules do not produce projections.
- [x] Generated projections copy only title, start, end, all-day flag, and destination calendar.

**Verification:**

- [x] Focused domain tests for work-to-hub projection.
- [x] `swift test`

**Dependencies:** Task 4

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Domain/...`
- `Tests/Unit/Features/CalendarRelay/Domain/...`

**Estimated scope:** Small: 1-2 files

### Task 6: Implement routing from hub to work calendars

**Description:** Build expected work-calendar projections from hub events. Prefixed hub events route to every configured work calendar except the matching source prefix; unprefixed hub events route to all work calendars using the personal-origin prefix.

**Acceptance criteria:**

- [ ] `[ACME] Client Planning` in the hub routes to BETA/CONTOSO but not ACME.
- [ ] Unprefixed hub event `Dentist` routes to all configured work calendars as `[ME] Dentist`.
- [ ] Remote/unknown prefixed hub events can route into locally configured work calendars but are not treated as hub events this machine may delete.

**Verification:**

- [ ] Focused domain tests for prefixed hub routing, unprefixed hub routing, and remote-prefixed blockers.
- [ ] `swift test`

**Dependencies:** Task 4

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Domain/...`
- `Tests/Unit/Features/CalendarRelay/Domain/...`

**Estimated scope:** Small-Medium: 2-3 files

### Task 7: Implement conservative create/delete reconciliation plan

**Description:** Compare expected projections to current visible events and produce a plan of creates/deletes. Apply deletion safety rules: delete stale configured-prefix generated events only; never delete unprefixed work/client events; preserve unknown prefixed events by default.

**Acceptance criteria:**

- [ ] Missing expected projections appear as creates.
- [ ] Stale locally managed prefixed projections appear as deletes.
- [ ] Unprefixed events are never proposed for deletion.
- [ ] Unknown prefixed hub/work events are preserved unless the prefix is configured/owned for that run.
- [ ] Rename/change behavior appears as delete old projection + create new projection.
- [ ] Running reconciliation against its own expected state produces no changes.

**Verification:**

- [ ] Unit tests for stale prefixed deletion, refusal to delete unprefixed events, unknown prefix preservation, rename/change, and idempotent second run.
- [ ] `swift test`

**Dependencies:** Tasks 5 and 6

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Domain/...`
- `Tests/Unit/Features/CalendarRelay/Domain/...`

**Estimated scope:** Medium: 3-5 files

### Checkpoint: Reconciliation core

- [ ] `swift test` passes without real EventKit access.
- [ ] Unit tests cover all reconciliation bullets from the spec's testing strategy.
- [ ] Domain code remains pure Swift/Foundation and has no EventKit, CLI, YAML, logging, or OS permission concerns.
- [ ] Reconciliation plan output is suitable for both dry-run printing and apply-mode execution.

## Phase 3: Configuration and CLI orchestration

### Task 8: Add YAML configuration loading adapter

**Description:** Add YAML file parsing with `Yams` for the initial configuration shape and map parsed values into validated application settings DTOs.

**Acceptance criteria:**

- [ ] Source/title selector YAML parses successfully.
- [ ] `syncWindowDays` defaults to 60 when omitted.
- [ ] Parse/default/validation errors are clear and safe.
- [ ] `Yams` is added to `Package.swift` and `Package.resolved` changes are intentional if SwiftPM creates or updates it.

**Verification:**

- [ ] Unit tests for config parsing/defaulting/validation.
- [ ] `swift build`
- [ ] `swift test`

**Dependencies:** Task 3

**Files likely touched:**

- `Package.swift`
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/DTOs/...`
- `Tests/Unit/Features/CalendarRelay/Adapters/...`
- `docs/configuration.md`

**Estimated scope:** Medium: 3-5 files

### Task 9: Add application use case orchestration with fake calendar ports

**Description:** Implement use cases that load snapshots through the calendar port, invoke pure reconciliation, return dry-run plans, and execute apply-mode operations through the port only when requested.

**Acceptance criteria:**

- [ ] Dry-run use case reads calendars/events and returns a reconciliation plan without calling mutation methods.
- [ ] Calendar selectors that match zero calendars are rejected.
- [ ] Calendar selectors that match multiple calendars are rejected.
- [ ] Apply use case validates settings and calendar writability before mutation.
- [ ] Apply use case creates missing projections and deletes stale safe projections via the outbound port.
- [ ] Cancellation can propagate through async operations.

**Verification:**

- [ ] Application tests with fake calendar port prove dry-run does not mutate and apply mutates only planned changes.
- [ ] `swift test`

**Dependencies:** Tasks 3 and 7

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Application/UseCases/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/Ports/...`
- `Tests/Unit/Features/CalendarRelay/Application/...`

**Estimated scope:** Medium: 3-5 files

### Task 10: Implement CLI command parsing and dry-run output

**Description:** Add user-facing CLI commands/options for listing calendars and reconciling from a config file. Reconciliation defaults to dry-run and prints planned creates/deletes without mutation.

**Acceptance criteria:**

- [ ] CLI supports `calrelay calendars`.
- [ ] CLI supports `calrelay reconcile --config <file> [--apply]`.
- [ ] Without `--apply`, CLI prints planned creates/deletes and performs no mutations.
- [ ] Output is understandable while avoiding unnecessary raw private data beyond explicit user-facing dry-run output.

**Verification:**

- [ ] CLI parser tests or focused command tests.
- [ ] `swift run calrelay --help`
- [ ] `swift test`

**Dependencies:** Tasks 7, 8, and 9

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/UseCases/...`
- `Tests/Unit/Features/CalendarRelay/Adapters/Inbound/CLI/...`

**Estimated scope:** Medium: 3-5 files

### Checkpoint: CLI and application without EventKit

- [ ] `swift build` passes.
- [ ] `swift test` passes using fakes only.
- [ ] `swift run calrelay --help` works.
- [ ] A fake/in-memory application test proves dry-run and apply orchestration behavior.
- [ ] README and `docs/configuration.md` match command names and YAML shape.

## Phase 4: EventKit adapter and capability validation

### Task 11: Implement EventKit calendar listing adapter

**Description:** Add the outbound EventKit adapter for macOS 26+ permission request/status and calendar/source listing, mapping EventKit calendars into application DTOs with writable/read-only status.

**Acceptance criteria:**

- [ ] EventKit imports are limited to `Adapters/Outbound/EventKit/...`.
- [ ] EventKit permission handling uses the macOS 26+ API baseline and remains isolated inside the EventKit adapter.
- [ ] `calrelay calendars` requests/handles calendar permission at the platform boundary.
- [ ] Calendar output includes calendar ID, title, source/account information, and writability.
- [ ] Permission denied/revoked/unavailable states fail safely with clear messages.

**Verification:**

- [ ] `swift build`
- [ ] `swift test`
- [ ] Manual: `swift run calrelay calendars` on macOS with Apple Calendar available.

**Dependencies:** Tasks 2 and 10

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Outbound/EventKit/...`
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/...`
- `Tests/Unit/Features/CalendarRelay/Adapters/Outbound/EventKit/...` for mapping where feasible

**Estimated scope:** Medium: 3-5 files

### Task 12: Implement EventKit event read mapping

**Description:** Read events for configured calendars within the sync window and map EventKit event instances/occurrences into application event snapshots.

**Acceptance criteria:**

- [ ] Reads only configured hub/work calendars for the current run.
- [ ] Uses sync window from validated settings, defaulting to next 60 days.
- [ ] Maps title, start, end, all-day flag, status/availability fields needed for inclusion rules.
- [ ] Recurring occurrences exposed by EventKit inside the window are treated as ordinary snapshots.

**Verification:**

- [ ] Unit tests for mapper logic where possible without real EventKit.
- [ ] `swift build`
- [ ] Manual dry-run against test calendars with timed, all-day, tentative, declined/cancelled if feasible.

**Dependencies:** Tasks 9 and 11

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Outbound/EventKit/...`
- `Tests/Unit/Features/CalendarRelay/Adapters/Outbound/EventKit/...`

**Estimated scope:** Medium: 3-5 files

### Task 13: Wire real dry-run reconciliation through EventKit

**Description:** Connect config loading, EventKit reads, application reconciliation, and CLI dry-run output for real locally visible Apple Calendar data.

**Acceptance criteria:**

- [ ] `swift run calrelay reconcile --config <file>` performs a dry-run with no mutations.
- [ ] Planned creates/deletes match expected routing rules for representative test calendars.
- [ ] Read-only target calendars are reported before apply mode would mutate.
- [ ] Errors remain clear for missing calendars, denied permissions, or invalid config.

**Verification:**

- [ ] `swift build`
- [ ] `swift test`
- [ ] Manual dry-run check with representative local calendars.

**Dependencies:** Tasks 8, 9, 10, 11, and 12

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/...`
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Outbound/EventKit/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/UseCases/...`

**Estimated scope:** Medium: 3-5 files

### Task 14: Implement EventKit apply mutations

**Description:** Add create/delete operations in the EventKit adapter and wire `--apply` to execute the validated reconciliation plan.

**Acceptance criteria:**

- [ ] `--apply` is required for mutation.
- [ ] Config, permission status, selector resolution, and writability are validated before any mutation starts.
- [ ] Create operations create disposable projection events with expected title/start/end/all-day/calendar fields.
- [ ] Delete operations delete only event snapshots selected by conservative reconciliation logic.
- [ ] Mutations execute in deterministic order: create missing projections first, then delete stale safe projections.
- [ ] Partial failures are reported clearly so a later dry-run/apply can converge.
- [ ] Apply rejects denied permissions/read-only calendars before mutation.
- [ ] No original unprefixed work/client events are deleted.

**Verification:**

- [ ] Application tests with fakes still pass.
- [ ] `swift build`
- [ ] `swift test`
- [ ] Manual EventKit write check: create and delete harmless generated blockers in configured writable test calendars.

**Dependencies:** Task 13

**Files likely touched:**

- `Sources/CalRelay/Features/CalendarRelay/Adapters/Outbound/EventKit/...`
- `Sources/CalRelay/Features/CalendarRelay/Application/UseCases/...`
- `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/...`

**Estimated scope:** Medium: 3-5 files

### Checkpoint: EventKit MVP capability

- [ ] `swift build` passes.
- [ ] `swift test` passes.
- [ ] Calendar list/capability command works locally.
- [ ] Dry-run produces expected creates/deletes without mutation.
- [ ] Apply mode can create/delete harmless generated projections in test calendars.
- [ ] EventKit imports remain adapter-only.

## Phase 5: MVP verification, docs, and hardening

### Task 15: Add user-facing configuration and operations documentation

**Description:** Document setup, config format, command usage, and manual MVP checks so behavior is reproducible despite EventKit depending on local calendar state.

**Acceptance criteria:**

- [ ] README explains build/test/run commands and links to the spec, implementation plan, and configuration reference.
- [ ] `docs/configuration.md` documents YAML schema, source/title selector matching, defaults, and safety notes.
- [ ] YAML examples use safe placeholder calendar/source names.
- [ ] Manual checks include calendar listing, dry-run, apply/idempotency, rename/change, and double-booking scenario.
- [ ] Permission and writable-calendar requirements are documented.

**Verification:**

- [ ] Documentation review against implemented command names/options.
- [ ] Commands in docs are copy/pasteable.

**Dependencies:** Tasks 13 and 14, because final command names/options should be known.

**Files likely touched:**

- `README.md`
- `docs/configuration.md`
- Optional `docs/operations.md`

**Estimated scope:** Small-Medium: 2-3 files

### Task 16: Perform MVP acceptance validation and close gaps

**Description:** Run the full local quality gate and manual EventKit acceptance checks from the spec, then fix any implementation gaps discovered.

**Acceptance criteria:**

- [ ] `swift build` passes.
- [ ] `swift test` passes.
- [ ] `swift run calrelay --help` passes.
- [ ] `swift run calrelay calendars` works.
- [ ] Dry-run shows expected creates/deletes.
- [ ] Apply followed by second apply/dry-run produces no second-run changes.
- [ ] Rename/change produces delete-old + create-new.
- [ ] Representative double-booking scenario is projected across at least two work calendars for the sync window.

**Verification:**

- [ ] Commands above plus manual EventKit validation notes.

**Dependencies:** Tasks 1-15

**Files likely touched:**

- Any small fixes in implementation/tests/docs found during validation.

**Estimated scope:** Small-Medium, but variable depending on discovered issues.

### Checkpoint: Complete MVP

- [ ] All spec success criteria are met or explicitly documented as not validated due to local EventKit constraints.
- [ ] No default tests require real EventKit, real user calendars, external providers, OAuth, or network APIs.
- [ ] Docs match implemented commands/config.
- [ ] Conservative deletion and unknown-prefix preservation are covered by tests.
- [ ] Ready for review or next implementation session.

## Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Source/title selectors may match multiple calendars | High | Calendar listing exposes source/title/ID; validation fails on ambiguous selectors. |
| EventKit write permissions differ by account/provider even when visible in Apple Calendar | High | Capability/list command and manual write check happen before relying on apply behavior. |
| Recurring occurrence behavior may not match assumptions | Medium-High | Treat recurrence as a capability check in Task 12; document limitations if EventKit does not expose occurrences cleanly. |
| Prefix-based deletion could delete user-created prefixed events | Medium | Preserve unknown prefixes; document that configured prefixes mark CalRelay-managed projections; dry-run by default. |
| YAML parser dependency affects package policy | Low-Medium | Use approved `Yams`; update manifest and lockfile together. |
| CLI parser dependency affects package policy | Low | Use approved `swift-argument-parser`; update manifest and lockfile together. |
| EventKit permission APIs differ by macOS version | Low-Medium | Target macOS 26+ for MVP and keep permission handling isolated in the EventKit adapter. |
| CLI output may expose private event titles/times | Medium | Keep diagnostics privacy-safe; accept explicit dry-run output as user-facing command output; avoid logging raw calendar contents. |
| Manual EventKit validation depends on local Apple Calendar state | Medium | Keep default tests fake/deterministic; document manual checks separately. |

## Open questions

- Can EventKit reliably expose recurring occurrences as ordinary visible event snapshots inside the sync window?
- Is the 60-day default sync window sufficient after real-world testing?
- Are source/title selectors stable enough across the user's Apple Calendar accounts, or will a fallback ID selector be needed later?
- Which exact `Yams` and `swift-argument-parser` versions should be pinned after the SwiftPM package is created?

## Recommended first implementation slice

Start with Tasks 1-3:

1. Create the SwiftPM executable skeleton for `calrelay`.
2. Add initial vertical-slice directories.
3. Add application DTOs/ports/settings contracts using source/title selectors.
4. Add static settings validation and focused tests.
5. Run `swift build` and `swift test`.

This leaves the repository in a buildable, tested state before tackling reconciliation and EventKit behavior.