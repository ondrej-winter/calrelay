# Spec: macOS App Controls and Automation

## Specification record

- **Status:** Accepted.
- **Revision:** 3 — accepted on September 16, 2026 after the Configuration Revision 4 stress test; migration-pending presentation and reconciliation gates were added.
- **Canonical artifact:** `docs/specs/macos-app-spec.md`.
- **Scope:** The Dock-visible control panel, menu bar, manual sync, scheduling, notifications, migration-pending state, and background-operation gates.

## Required outcomes

### APP-01 — Recoverable control panel and menu bar

- `CalRelay.app` remains a normal Dock-visible app while setup and recovery evolve.
- Its main window is the primary surface for Calendar permission, calendar visibility, configuration status, migration-pending status, and error recovery.
- A clearly labeled setup or recovery action in the main window is the only CalRelay action allowed to request full Calendar access and trigger the macOS permission prompt. Its authorization-state behavior follows [`calendar-access-spec.md`](calendar-access-spec.md).
- The main window provides an all-calendar inventory for configuration setup and recovery after full access exists. Inventory displays every visible calendar and is clearly distinguished from configured-topology readiness.
- Do not make the app Dock-hidden or accessory-only until users can reliably open settings, inspect status, and recover.
- A menu-bar item is optional, user-configurable, and initially UI-only, limited to opening/focusing CalRelay and quitting.
- Menu handlers open or focus app UI rather than orchestrating business workflows.

### APP-02 — Manual sync controls

- After a clear control surface exists, the app may expose a configured-readiness check, Dry Run Sync, and Run Sync Now as separate actions from all-calendar inventory.
- Before exposing manual sync, show configuration validity, migration-pending state, selected calendars, Calendar permission state, and the latest operation result.
- Configured-readiness checks and dry runs use the same non-mutating ordinary access preflight as apply, as defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- When `legacyMarkers` is nonempty, ordinary manual dry-run and sync actions are unavailable and the app explains that CLI legacy cleanup is required. The current app scope does not add a cleanup action.
- Mutating ordinary sync remains explicit, user initiated, and requires a confirmation that summarizes the operation.
- Dry runs remain easy to access but are not mandatory before every mutating run.

### APP-03 — In-app automation and notifications

- In-app timer sync is configurable, disabled by default, initially suggested at 15 minutes, and prevents overlapping runs.
- When enabled, show last run, next run, last result/error, and mutation count.
- Scheduled reconciliation never requests Calendar access. A failed access preflight is reported as an operation failure with recovery guidance and no mutation.
- A migration-pending profile suppresses scheduled and notification-triggered reconciliation, reports actionable cleanup guidance, and performs no ordinary or cleanup mutation.
- Use macOS app lifecycle mechanisms rather than system cron.
- EventKit change notifications are optional coarse invalidation signals; debounce them, protect against loops/noise, and invoke the same ordinary reconciliation workflow rather than treating notifications as authoritative deltas.

### APP-04 — Closed-app operation is deferred

- Launch-at-login, helpers, LaunchAgents, and true background operation are not part of the first menu-bar milestone.
- Consider them only after manual sync and in-app scheduling are proven, and only when sync must run while the main app is closed.
- Any such solution needs controls for enablement, status inspection, and recovery, plus an ADR before implementation because lifecycle, permissions, signing, packaging, rollback, and user trust are affected.

## Compatibility and breaking changes

- Revision 3 requires configuration presentation to distinguish migration pending from both structural invalidity and ordinary configured readiness.
- Manual and automatic ordinary reconciliation are blocked while legacy tombstones exist; legacy cleanup remains CLI-only for the current app scope.
- Existing prompt ownership and inventory/readiness separation remain unchanged.

## Constraints

- Preserve bundle identifier `dev.owinter.CalRelay` unless an explicit migration is approved.
- Keep SwiftUI views, AppKit handlers, delegates, and lifecycle callbacks thin; keep EventKit access behind adapters and reconciliation orchestration in use cases or explicit app composition.
- Do not introduce app-based legacy cleanup, cron, automatic reconciliation, EventKit listening, a login item, a helper app, a LaunchAgent, signing/entitlement changes, or background-only behavior without the relevant explicit decision and, for closed-app operation, an ADR.

## Acceptance checks

- **APP-AC-01:** The Dock-visible app remains the recoverable primary control panel.
- **APP-AC-02:** Authorization-state tests prove that only the explicit setup/recovery action may prompt and that denied, restricted, write-only, revoked, and full-access states receive the required behavior.
- **APP-AC-03:** All-calendar inventory lists visible calendars after full access and is visibly distinct from configured readiness.
- **APP-AC-04:** The first menu-bar milestone is user-configurable, UI-only, and limited to opening/focusing the app and quitting.
- **APP-AC-05:** Manual sync has the prerequisite status surface, ordinary shared access preflight, and confirmation for mutation.
- **APP-AC-06:** Migration-pending presentation blocks ordinary manual sync and gives CLI cleanup guidance without offering or performing cleanup in the app.
- **APP-AC-07:** Timer sync is disabled by default, configurable, overlap-safe, non-prompting, operationally observable, and suppressed during migration pending.
- **APP-AC-08:** Notifications are debounced optional ordinary reconciliation triggers with loop protection and are suppressed during migration pending.
- **APP-AC-09:** Closed-app operation remains deferred pending explicit approval and an ADR.

## Verification approach

- Start implementation validation with `make check` and `make app`.
- Manually validate menu-bar behavior, explicit permission acquisition/recovery, inventory, configured-readiness presentation, and migration-pending gates in a built app bundle.
- Add focused tests for authorization-state mapping, prompt ownership, inventory/readiness/migration presentation, scheduling state, and duplicate-run prevention before automatic sync.
