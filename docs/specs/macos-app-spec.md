# Spec: macOS App Controls and Automation

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — consolidates the accepted app lifecycle and menu-bar direction on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/macos-app-spec.md`.
- **Scope:** The Dock-visible control panel, menu bar, manual sync, in-app scheduling, change notifications, and background-operation gates.

## Required outcomes

### APP-01 — Recoverable control panel and menu bar

- `CalRelay.app` remains a normal Dock-visible app while setup and recovery evolve.
- Its main window is the primary surface for Calendar permission, calendar visibility, configuration status, and error recovery.
- Do not make the app Dock-hidden or accessory-only until users can reliably open settings, inspect status, and recover.
- A menu-bar item is optional, user-configurable, and initially UI-only, limited to opening/focusing CalRelay and quitting.
- Menu handlers open or focus app UI rather than orchestrating business workflows.

### APP-02 — Manual sync controls

- After a clear control surface exists, the app may expose Check Calendars, Dry Run Sync, and Run Sync Now.
- Before exposing manual sync, show configuration validity, selected calendars, Calendar permission state, and the latest operation result.
- Mutating sync remains explicit, user initiated, and requires a confirmation that summarizes the operation.
- Dry runs remain easy to access but are not mandatory before every mutating run.

### APP-03 — In-app automation and notifications

- In-app timer sync is configurable, disabled by default, initially suggested at 15 minutes, and prevents overlapping runs.
- When enabled, show last run, next run, last result/error, and mutation count.
- Use macOS app lifecycle mechanisms rather than system cron.
- EventKit change notifications are optional coarse invalidation signals; debounce them, protect against loops/noise, and invoke the same reconciliation workflow rather than treating notifications as authoritative deltas.

### APP-04 — Closed-app operation is deferred

- Launch-at-login, helpers, LaunchAgents, and true background operation are not part of the first menu-bar milestone.
- Consider them only after manual sync and in-app scheduling are proven, and only when sync must run while the main app is closed.
- Any such solution needs controls for enablement, status inspection, and recovery, plus an ADR before implementation because lifecycle, permissions, signing, packaging, rollback, and user trust are affected.

## Constraints

- Preserve bundle identifier `dev.owinter.CalRelay` unless an explicit migration is approved.
- Keep SwiftUI views, AppKit handlers, delegates, and lifecycle callbacks thin; keep EventKit access behind adapters and reconciliation orchestration in use cases or explicit app composition.
- Do not introduce cron, automatic reconciliation, EventKit listening, a login item, a helper app, a LaunchAgent, signing/entitlement changes, or background-only behavior without the relevant explicit decision and, for closed-app operation, an ADR.

## Acceptance checks

- **APP-AC-01:** The Dock-visible app remains the recoverable primary control panel.
- **APP-AC-02:** The first menu-bar milestone is user-configurable, UI-only, and limited to opening/focusing the app and quitting.
- **APP-AC-03:** Manual sync has the prerequisite status surface and confirmation for mutation.
- **APP-AC-04:** Timer sync is disabled by default, configurable, overlap-safe, and operationally observable.
- **APP-AC-05:** Notifications are debounced optional reconciliation triggers with loop protection.
- **APP-AC-06:** Closed-app operation remains deferred pending explicit approval and an ADR.

## Verification approach

- Start implementation validation with `make check` and `make app`.
- Manually validate menu-bar behavior and Calendar permission in a built app bundle.
- Add focused tests for status mapping, scheduling state, and duplicate-run prevention before automatic sync.