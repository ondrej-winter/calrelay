# Spec: CalRelay App Lifecycle and Menu Bar Direction

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — template-alignment audit on September 14, 2026; no lifecycle decisions changed.
- **Canonical artifact:** `docs/specs/calrelay-app-lifecycle-spec.md`.
- **Source of truth:** This document is the canonical lifecycle direction for `CalRelay.app`; the EventKit MVP specification remains authoritative for relay behavior and safety rules.
- **Acceptance basis:** Repository history records this document as the lifecycle roadmap and later implementation of its initial app/menu-bar direction. An individual approver and acceptance date were not recorded.
- **Next authorized step:** Use this accepted direction for scoped app work. Any automatic or background operation still requires the explicitly stated approval and ADR boundaries.

## Revision history

- **Revision 2 — September 14, 2026:** Aligned the document structure with the specification template. Preserved the existing accepted lifecycle decisions and deferrals.
- **Revision 1 — July 1, 2026:** Initial lifecycle and menu-bar specification.

## Objective

Define the intended macOS app lifecycle direction for CalRelay before planning or implementing menu bar, manual sync, or background behavior.

This spec is for a single-user local macOS app that should be easy to set up, safe to recover when permissions or configuration fail, and eventually capable of running calendar relay workflows with minimal user attention.

## Scope

**In scope:** the staged lifecycle direction for the Dock-visible app, an initial UI-only menu-bar control, later manual sync controls, and the conditions required before in-app scheduling or background operation.

**Out of scope:** implementing a background helper, launch-at-login integration, automatic reconciliation, or EventKit notification listening. Those items remain deferred as described in the required outcomes and explicit exclusions below.

## Assumptions

- The existing stable app bundle identifier remains the Calendar-permission identity unless an explicitly approved migration changes it.
- The EventKit MVP reconciliation safety requirements remain binding for every future app-triggered relay operation.

## Current context

- `CalRelay.app` is currently a normal SwiftUI macOS app.
- The app is built from the SwiftPM executable target in `Sources/CalRelayApp/`.
- The app bundle metadata lives in `Resources/CalRelayApp/Info.plist`.
- The app uses bundle identifier `dev.owinter.CalRelay`, which gives it a stable macOS Calendar permission identity.
- The current app window is a minimal capability-check surface for requesting Calendar permission and listing EventKit-visible calendars.
- The CLI remains the main reconciliation interface for the current EventKit MVP.
- Existing project rules keep EventKit, permissions, app lifecycle, and macOS platform APIs at adapter or app/bootstrap boundaries.

## Required outcomes

### REQ-01 — Stage 1: Normal app control panel

CalRelay should remain a normal macOS app while setup and recovery workflows are still evolving.

- The app should remain visible in the Dock and app switcher by default.
- The main window should be the primary place for Calendar permission checks, calendar visibility checks, future configuration status, and user-facing error recovery.
- The app should not become Dock-hidden or accessory-only until there is a reliable way to open settings, inspect status, and recover from failures.

### REQ-02 — Stage 2: Minimal menu-bar control surface

CalRelay may add a menu bar status item as a convenience control surface while still remaining a normal app.

- The first menu bar version should be UI-only.
- The first menu bar version should let the user show or hide the menu bar item from app settings.
- The menu bar item should not imply background sync, cron, EventKit event listening, or automatic reconciliation.
- Initial menu actions should stay minimal, such as:
  - Open CalRelay
  - Quit
- Menu actions should open or focus app UI rather than duplicating business workflow orchestration in menu handlers.
- Calendar permission state and EventKit-visible calendar listing are enough app-window recovery/status surface before this UI-only menu bar milestone.

### REQ-03 — Stage 3: Manual sync actions from GUI or menu

After the app has a clear control surface, it may expose explicit user-triggered relay actions.

- Manual actions may include:
  - Check Calendars
  - Dry Run Sync
  - Run Sync Now
- The app should show configuration validity, selected source/target calendars, Calendar permission state, and the latest operation result before exposing manual sync actions.
- Dry-run behavior should remain easy to access, but a dry run is not required before every mutating action.
- Apply/mutating behavior should remain explicit and user-initiated at this stage.
- Mutating GUI or menu-triggered sync should require a confirmation step that summarizes the intended operation before changes are applied.
- User-facing status should include enough context to understand success, failure, and whether mutations occurred.

### REQ-04 — Stage 4: In-app timer while the app is running

After manual sync is safe and observable, CalRelay may add scheduled reconciliation while the app process is running.

- Timer-based sync should be configurable and easy to disable.
- Timer-based sync should be disabled by default.
- When timer-based sync is enabled, the initial suggested interval should be 15 minutes unless later evidence supports a different default.
- Timer-based sync should prevent overlapping reconciliation runs.
- Timer-based sync should surface last run time, next run time, last result or error, and mutation count in the app or menu UI.
- Timer-based sync should use Swift/macOS app lifecycle mechanisms, not system cron.

### REQ-05 — Stage 5: Debounced EventKit change notifications

CalRelay may later listen for EventKit calendar store change notifications as an optimization.

- EventKit notifications should be treated as coarse invalidation signals, not precise event deltas.
- Change notifications should trigger the same reconciliation workflow after debouncing.
- Event listening should not replace visible-set reconciliation.
- Event listening should guard against noisy notifications, repeated triggers, and sync loops.

### REQ-06 — Stage 6: Launch-at-login or background helper

A true background process, launch-at-login helper, or LaunchAgent-style integration is future work and should not be part of the first menu bar milestone.

- Background operation should be considered only after manual sync and in-app scheduling are proven.
- Background operation should be justified only when CalRelay must run sync while the main app is closed.
- Background operation should provide clear user controls for enabling, disabling, status inspection, and error recovery.
- Background operation requires an ADR before implementation because it affects lifecycle, permissions, signing, packaging, rollback, and user trust.

## Explicit exclusions for the first menu bar milestone

- **EXC-01:** Do not introduce system cron, a LaunchAgent, login item, helper app, or background-only daemon.
- **EXC-02:** Do not hide the app from the Dock or make it accessory-only by default, add automatic reconciliation, or add EventKit change-notification listening.
- **EXC-03:** Do not move EventKit or reconciliation orchestration into SwiftUI views, app delegates, or menu handlers.
- **EXC-04:** Do not change the existing app bundle identifier or Calendar permission identity.

## Verification approach

Validation commands for future implementation work should start with the existing local quality gate:

- Build: `swift build`
- Test: `swift test`
- App bundle build: `zsh scripts/build-calrelay-app.sh`
- Manual app check: `open .build/CalRelay.app`

For this spec-only step, the validation is review of this document before any implementation plan is written.

## Project structure

Expected future implementation locations, if this spec is accepted:

- `Sources/CalRelayApp/`: app lifecycle, SwiftUI window, AppKit status item integration, and app-level composition.
- `Sources/CalRelayKit/Features/CalendarRelay/`: pure application/domain behavior for reconciliation remains here.
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/`: EventKit access and permissions remain here.
- `docs/specs/`: durable product and lifecycle specifications.
- `docs/plans/`: implementation plans only after the relevant spec is accepted.

## Conventions

- Keep app lifecycle and menu bar code at the app/bootstrap edge.
- Keep SwiftUI views and AppKit menu handlers thin.
- Keep EventKit access behind outbound adapters.
- Keep reconciliation orchestration in application use cases or explicit app-level composition, not directly in UI controls.
- Prefer explicit user-triggered actions before automatic or background behavior.
- Prefer macOS-native lifecycle mechanisms over cron for app-integrated scheduling.
- Preserve the app bundle identifier unless there is an explicit migration reason.

## Verification approach and test strategy

Testing expectations for later implementation work:

- Keep deterministic unit tests focused on core reconciliation behavior.
- Test app/menu lifecycle behavior at the thinnest practical boundary.
- Manually validate menu bar behavior in a real built app bundle.
- Manually validate Calendar permission behavior with the stable app bundle identity.
- Add focused tests for scheduling state, duplicate-run prevention, and status mapping before introducing automatic sync.

## Binding constraints and execution boundaries

These constraints are mandatory for work governed by this specification.

- **CON-01:** Keep the normal app recoverable while setup and error handling are immature, and keep mutating calendar operations explicit until automation has clear status and safety controls.
- **CON-02:** Treat EventKit notifications as triggers for reconciliation, not authoritative deltas.
- **CON-03:** Hiding the Dock icon, becoming accessory-only, adding launch-at-login, a helper app, LaunchAgent behavior, signing/entitlement changes, or automatic reconciliation requires an explicit decision.
- **CON-04:** Never use system cron as the primary app-integrated scheduling mechanism or place EventKit/Calendar-permission mechanics in the domain/application core.

## Acceptance checks

- **AC-01 (REQ-01):** The Dock-visible app remains the recoverable primary control panel for Calendar permission, calendar visibility, configuration status, and error recovery.
- **AC-02 (REQ-02):** The first menu-bar milestone is user-configurable, UI-only, and limited to opening/focusing the app and quitting.
- **AC-03 (REQ-03):** Before manual sync is exposed, the app displays configuration validity, selected calendars, Calendar permission state, and the latest operation result; mutating sync requires confirmation.
- **AC-04 (REQ-04):** Any in-app timer is disabled by default, configurable, prevents overlapping runs, and shows the required operational status before automatic mutation.
- **AC-05 (REQ-05):** EventKit notifications are optional reconciliation triggers subject to debouncing, loop protection, and the same safety controls as manual sync.
- **AC-06 (REQ-06, CON-03):** Background sync, launch-at-login, and closed-app operation remain deferred until explicitly approved and documented in an ADR.

## Confirmed decisions

Resolved decisions before implementation planning:

- **DEC-01:** The first menu-bar item is user-configurable; Calendar permission state and EventKit-visible calendar listing are sufficient before adding it.
- **DEC-02:** Manual sync requires visible configuration validity, selected source/target calendars, Calendar permission state, and the latest operation result; mutating sync requires confirmation but not a mandatory dry run.
- **DEC-03:** Future in-app timer sync is disabled by default, with 15 minutes as the initial suggested enabled interval; automatic sync requires visible last/next run times, result/error, and mutation count.
- **DEC-04:** A launch-at-login helper or LaunchAgent is justified only when sync must run while the main app is closed, and any background-operation decision requires an ADR before implementation.

## Traceability

- **REQ-01:** AC-01.
- **REQ-02:** AC-02.
- **REQ-03:** AC-03.
- **REQ-04:** AC-04.
- **REQ-05:** AC-05.
- **REQ-06:** AC-06.