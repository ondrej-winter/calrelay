# Spec: Calendar Access

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 15, 2026 after an explicit calendar-access contract review; permission ownership, discovery, configured readiness, and runtime failure behavior changed.
- **Canonical artifact:** `docs/specs/calendar-access-spec.md`.
- **Scope:** Calendar permission, discovery, configured-topology access preflight, writability, runtime access failures, and EventKit boundary behavior.

## Required outcomes

### ACCESS-01 — Permission ownership and authorization states

- Only full read/write Calendar authorization qualifies for calendar discovery or reconciliation readiness. Write-only access is insufficient.
- Only a clearly labeled setup or recovery action in `CalRelay.app` may request full Calendar access and trigger the macOS permission prompt.
- The app permission action behaves according to the current authorization state:
  - when access is not determined, request full access;
  - when access is denied, write-only, or was later revoked, provide System Settings recovery guidance without requesting again;
  - when access is restricted, explain that the restriction must be resolved outside CalRelay;
  - when full access exists, verify and display the state without prompting.
- CLI commands and manual or scheduled reconciliation never request Calendar access. They inspect the current state and fail with actionable recovery guidance when full access is unavailable.

### ACCESS-02 — Calendar discovery

- `calrelay calendars` is a configuration-independent inventory command. It requires pre-existing full Calendar access and never prompts.
- Discovery lists every EventKit-visible calendar with its source/account, title, EventKit calendar ID, and writable/read-only status.
- Discovery success means only that the current inventory was listed. It does not imply that a configuration is valid or ready for reconciliation.
- `CalRelay.app` provides an equivalent all-calendar inventory for setup and recovery and clearly distinguishes inventory from configured readiness.
- EventKit calendar IDs are displayed discovery data and troubleshooting identifiers, but they are not canonical configuration keys.

### ACCESS-03 — Configured-topology readiness preflight

- `calrelay config check`, reconciliation dry-run, and reconciliation apply use the same non-mutating configured-topology access preflight after the selected configuration passes file and structural validation.
- Full Calendar authorization is required before configured readiness can succeed.
- For every configured hub or work-calendar role, preflight must establish all of the following:
  - its source/title selector resolves to exactly one currently visible EventKit calendar;
  - its resolved EventKit calendar ID is distinct from every other configured role;
  - reading its events over the configured sync window succeeds;
  - EventKit currently reports the calendar as writable.
- Preflight must not create, update, or delete an event as a capability probe.
- Preflight collects and reports every safely determinable failure across the configured topology. Missing matches, ambiguous matches, role collisions, read failures, and read-only calendars are readiness failures.
- Any readiness failure prevents `calrelay config check`, dry-run, or apply from reporting success. Apply must complete the entire preflight before its first mutation, and any preflight failure prevents all mutations for that run.
- A successful preflight reports current readiness; it is not a guarantee that authorization or remote calendar availability will remain unchanged during later mutation.

### ACCESS-04 — Failure after mutation begins

- If Calendar access changes or an EventKit mutation fails after successful preflight and mutation has begun, stop the run immediately rather than attempting later planned mutations.
- Report the run as partially applied with privacy-safe per-role action counts or categories and the failure category. Never report that run as successful.
- Do not attempt compensating rollback through EventKit. A later reconciliation is the recovery mechanism.

### ACCESS-05 — Privacy-safe access diagnostics

- Interactive access, readiness, and partial-application diagnostics may identify a configured role, its source/title selector, and a failure or action category.
- Interactive access and readiness diagnostics omit event titles and EventKit calendar IDs by default. The explicit discovery command and app inventory are the exception and display calendar IDs as required by `ACCESS-02`.
- Persistent logs contain counts and categories only. They do not contain calendar names, source/title selectors, EventKit IDs, event titles, or event details.

### ACCESS-06 — EventKit boundary

- EventKit types, calendar IDs, calendar stores, permission APIs, and mutation mechanics remain in adapters or app/bootstrap code.
- Map EventKit types into application DTOs at the adapter boundary.
- Mutate only distinct calendars configured for the current run and only after configured-topology preflight succeeds.

## Compatibility and breaking changes

- Revision 2 intentionally makes access checks fail closed. Implementations that prompt from CLI or reconciliation, permit write-only access, perform partial-topology preflight, or mutate after a preflight failure do not conform.
- Dry-run now requires the same full configured-topology access readiness as apply.
- Existing implementations may require changes before the accepted permission, readiness, diagnostics, and partial-application contracts are satisfied.

## Validation

- `calrelay calendars` lists every visible calendar, source/account, title, EventKit ID, and writability without configuration or mutation.
- `calrelay config check`, dry-run, and apply demonstrate the shared non-mutating preflight and aggregate failure behavior.
- Real EventKit capability checks are explicit local validation through `CalRelay.app` or the CLI; default deterministic tests do not require real EventKit access.
- Manually validate permission acquisition and recovery with the stable `CalRelay.app` bundle identity.

## Acceptance checks

- **ACCESS-AC-01:** Authorization-state tests prove that only the explicit app setup/recovery action may request access and that CLI, dry-run, apply, and scheduled reconciliation never prompt.
- **ACCESS-AC-02:** Discovery lists all visible calendars with source/account, title, ID, and writability without requiring configuration, and its output does not claim configured readiness.
- **ACCESS-AC-03:** Config check, dry-run, and apply reject missing, ambiguous, colliding, unreadable, or read-only configured calendars.
- **ACCESS-AC-04:** A preflight with multiple safely determinable failures reports all of them and performs no mutation.
- **ACCESS-AC-05:** A mutation-phase access or EventKit failure stops later mutations and returns a privacy-safe partial-application result without rollback or a success claim.
- **ACCESS-AC-06:** Interactive and persistent diagnostics obey the disclosure boundaries in `ACCESS-05`.
- **ACCESS-AC-07:** Deterministic core tests run without EventKit access or EventKit types in domain/application APIs.

## Constraints

- Do not pass EventKit types into domain/application APIs.
- Do not mutate calendars to test access readiness.
- Do not support partial-topology reconciliation when any configured role fails preflight.
- Do not use EventKit calendar IDs as an automatic selector fallback.
- Do not rely on live external provider APIs in default tests.
- Direct provider APIs, OAuth, app registrations, tenant approvals, and provider-specific sync tokens are excluded.