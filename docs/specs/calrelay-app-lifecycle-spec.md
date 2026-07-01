# Spec: CalRelay App Lifecycle and Menu Bar Direction

## Objective

Define the intended macOS app lifecycle direction for CalRelay before planning or implementing menu bar, manual sync, or background behavior.

This spec is for a single-user local macOS app that should be easy to set up, safe to recover when permissions or configuration fail, and eventually capable of running calendar relay workflows with minimal user attention.

## Current context

- `CalRelay.app` is currently a normal SwiftUI macOS app.
- The app is built from the SwiftPM executable target in `Sources/CalRelayApp/`.
- The app bundle metadata lives in `Resources/CalRelayApp/Info.plist`.
- The app uses bundle identifier `dev.owinter.CalRelay`, which gives it a stable macOS Calendar permission identity.
- The current app window is a minimal capability-check surface for requesting Calendar permission and listing EventKit-visible calendars.
- The CLI remains the main reconciliation interface for the current EventKit MVP.
- Existing project rules keep EventKit, permissions, app lifecycle, and macOS platform APIs at adapter or app/bootstrap boundaries.

## Desired behavior

### Stage 1: Normal app control panel

CalRelay should remain a normal macOS app while setup and recovery workflows are still evolving.

- The app should remain visible in the Dock and app switcher by default.
- The main window should be the primary place for Calendar permission checks, calendar visibility checks, future configuration status, and user-facing error recovery.
- The app should not become Dock-hidden or accessory-only until there is a reliable way to open settings, inspect status, and recover from failures.

### Stage 2: Minimal menu bar control surface

CalRelay may add a menu bar status item as a convenience control surface while still remaining a normal app.

- The first menu bar version should be UI-only.
- The first menu bar version should let the user show or hide the menu bar item from app settings.
- The menu bar item should not imply background sync, cron, EventKit event listening, or automatic reconciliation.
- Initial menu actions should stay minimal, such as:
  - Open CalRelay
  - Quit
- Menu actions should open or focus app UI rather than duplicating business workflow orchestration in menu handlers.
- Calendar permission state and EventKit-visible calendar listing are enough app-window recovery/status surface before this UI-only menu bar milestone.

### Stage 3: Manual sync actions from GUI or menu

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

### Stage 4: In-app timer while app is running

After manual sync is safe and observable, CalRelay may add scheduled reconciliation while the app process is running.

- Timer-based sync should be configurable and easy to disable.
- Timer-based sync should be disabled by default.
- When timer-based sync is enabled, the initial suggested interval should be 15 minutes unless later evidence supports a different default.
- Timer-based sync should prevent overlapping reconciliation runs.
- Timer-based sync should surface last run time, next run time, last result or error, and mutation count in the app or menu UI.
- Timer-based sync should use Swift/macOS app lifecycle mechanisms, not system cron.

### Stage 5: Debounced EventKit change notifications

CalRelay may later listen for EventKit calendar store change notifications as an optimization.

- EventKit notifications should be treated as coarse invalidation signals, not precise event deltas.
- Change notifications should trigger the same reconciliation workflow after debouncing.
- Event listening should not replace visible-set reconciliation.
- Event listening should guard against noisy notifications, repeated triggers, and sync loops.

### Stage 6: Launch-at-login or background helper

A true background process, launch-at-login helper, or LaunchAgent-style integration is future work and should not be part of the first menu bar milestone.

- Background operation should be considered only after manual sync and in-app scheduling are proven.
- Background operation should be justified only when CalRelay must run sync while the main app is closed.
- Background operation should provide clear user controls for enabling, disabling, status inspection, and error recovery.
- Background operation requires an ADR before implementation because it affects lifecycle, permissions, signing, packaging, rollback, and user trust.

## Non-goals for the first menu bar milestone

- Do not introduce system cron.
- Do not introduce a LaunchAgent, login item, helper app, or background-only daemon.
- Do not hide the app from the Dock or make it accessory-only by default.
- Do not add automatic reconciliation.
- Do not add EventKit change notification listening.
- Do not move EventKit or reconciliation orchestration into SwiftUI views, app delegates, or menu handlers.
- Do not change the existing app bundle identifier or Calendar permission identity.

## Commands and validation

Validation commands for future implementation work should start with the existing local quality gate:

- Build: `swift build`
- Test: `swift test`
- App bundle build: `zsh scripts/build-calrelay-app.sh`
- Manual app check: `open .build/CalRelay.app`

For this spec-only step, the validation is review of this document before any implementation plan is written.

## Project structure

Expected future implementation locations, if this spec is accepted:

- `Sources/CalRelayApp/`: app lifecycle, SwiftUI window, AppKit status item integration, and app-level composition.
- `Sources/CalRelayCore/Features/CalendarRelay/`: pure application/domain behavior for reconciliation remains here.
- `Sources/CalRelayAdapters/Features/CalendarRelay/Adapters/Outbound/EventKit/`: EventKit access and permissions remain here.
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

## Testing strategy

Testing expectations for later implementation work:

- Keep deterministic unit tests focused on core reconciliation behavior.
- Test app/menu lifecycle behavior at the thinnest practical boundary.
- Manually validate menu bar behavior in a real built app bundle.
- Manually validate Calendar permission behavior with the stable app bundle identity.
- Add focused tests for scheduling state, duplicate-run prevention, and status mapping before introducing automatic sync.

## Boundaries

- Always: keep the normal app recoverable while setup and error handling are immature.
- Always: keep mutating calendar operations explicit until automation has clear status and safety controls.
- Always: treat EventKit notifications as triggers for reconciliation, not as authoritative deltas.
- Ask first: before hiding the Dock icon or making CalRelay accessory-only.
- Ask first: before adding launch-at-login, a helper app, LaunchAgent behavior, or signing/entitlement changes.
- Ask first: before adding automatic reconciliation.
- Never: use system cron as the primary app-integrated scheduling mechanism.
- Never: place EventKit framework details or Calendar permission mechanics in domain/application core.

## Success criteria

- The lifecycle direction is documented before implementation planning begins.
- The first menu bar milestone is explicitly scoped as UI-only.
- Background sync, EventKit event listening, and launch-at-login behavior are explicitly deferred.
- The spec preserves the existing app permission identity and normal app recoverability.
- Lifecycle decisions needed for implementation planning are explicit before planning starts.

## Resolved lifecycle decisions

Resolved decisions before implementation planning:

- The first menu bar item should be user-configurable from the beginning.
- Calendar permission state and EventKit-visible calendar listing are sufficient before adding the first UI-only menu bar item.
- Manual sync actions require user-facing configuration validity, selected source/target calendars, Calendar permission state, and latest operation result.
- Mutating sync from the GUI or menu requires explicit confirmation, but not a mandatory dry run first.
- Future in-app timer sync should be disabled by default, with 15 minutes as the initial suggested interval when enabled.
- Automatic sync is not safe until the app or menu can show last run time, next run time, last result or error, and mutation count.
- A separate launch-at-login helper or LaunchAgent is justified only if sync must run while the main app is closed.
- Any future background-operation decision requires an ADR before implementation.