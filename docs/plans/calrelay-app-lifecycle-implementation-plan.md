# Implementation Plan: CalRelay App Lifecycle and UI-Only Menu Bar

## Overview

Implement the next app lifecycle milestone from `docs/specs/calrelay-app-lifecycle-spec.md`: keep `CalRelay.app` as a normal Dock-visible SwiftUI macOS app, improve the app-side control panel enough to remain recoverable, then add a **user-configurable, UI-only menu bar status item** with minimal actions (`Open CalRelay`, `Quit`).

This plan deliberately defers manual sync, timer sync, EventKit notifications, launch-at-login, LaunchAgent/helper behavior, accessory-only mode, and background reconciliation.

## Lifecycle/menu bar milestone baseline

The app lifecycle and UI-only menu bar milestone implementation and machine validation are complete as of commit `5ca914d3051465a17b6e3b98243cc26000721751` (`feat(app): add optional menu bar control surface for CalRelay`). Use this commit as the baseline before starting the next lifecycle milestone. Real macOS GUI interaction checks are intentionally deferred to a future GUI/manual validation pass.

## Implementation status

Status as of 2026-07-02:

- Tasks 1-5 are implemented in the working tree.
- `Sources/CalRelayApp/CalRelayApp.swift` now owns SwiftUI scene composition only.
- `CalendarListViewModel`, `CalendarListView`, app settings keys, and menu bar actions now live in separate app-edge files under `Sources/CalRelayApp/`.
- The app control panel now describes Calendar permission and visible-calendar checks as the current recovery/status surface.
- The menu bar item uses SwiftUI `MenuBarExtra` and is controlled by `@AppStorage("showMenuBarItem")`, defaulting to enabled.
- The menu contains only `Open CalRelay` and `Quit`; no sync, timer, EventKit notification, launch-at-login, helper, or background behavior was added.
- `README.md` and `docs/manual-validation.md` were updated for the implemented control panel and UI-only menu bar behavior.

Validation already run:

- [x] `swift build` passed.
- [x] `swift test` was attempted and hit the documented active Command Line Tools issue: `no such module 'Testing'`.
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed, including the Swift Testing contract suite.
- [x] `zsh scripts/build-calrelay-app.sh` passed and rebuilt `.build/CalRelay.app`.
- [x] Additional native app self-test verified bundle metadata, code signature, launch/process lifecycle, and preference persistence via CLI/AppleScript.
- [ ] Visual menu bar interaction and Calendar permission/listing checks still need human confirmation in the real macOS UI.

Native app self-test results:

- [x] `.build/CalRelay.app/Contents/Info.plist` contains `CFBundleIdentifier = dev.owinter.CalRelay`.
- [x] `.build/CalRelay.app/Contents/Info.plist` does not define `LSUIElement`, so this build does not opt into accessory-only/Dock-hidden mode.
- [x] `.build/CalRelay.app/Contents/Info.plist` contains `CFBundleExecutable = CalRelayApp`.
- [x] `codesign --verify --verbose=2 .build/CalRelay.app` passed.
- [x] `open .build/CalRelay.app` launched the app process at `.build/CalRelay.app/Contents/MacOS/CalRelayApp`.
- [x] `osascript` quit the app by bundle identifier and `pgrep` confirmed no remaining CalRelay app process.
- [x] `defaults write/read dev.owinter.CalRelay showMenuBarItem` verified the app preference domain stores `showMenuBarItem` values and preserves them across an app launch/quit cycle.
- [ ] System Events UI inspection was attempted, but native menu bar/window details were not reliably scriptable in this environment; use `docs/manual-validation.md` for the remaining visual checks.

## Current-state findings

- `Sources/CalRelayApp/CalRelayApp.swift` is currently a single-file SwiftUI app with:
  - `CalRelayApp: App`
  - private `CalendarListViewModel`
  - private `CalendarListView`
  - direct construction of `EventKitCalendarStore()` inside the view model.
- `Resources/CalRelayApp/Info.plist` preserves bundle identifier `dev.owinter.CalRelay`; this must not change.
- The app bundle is built by `scripts/build-calrelay-app.sh` and signed ad hoc.
- Core reconciliation already lives in `Sources/CalRelayCore/Features/CalendarRelay/...`.
- EventKit access already lives in `Sources/CalRelayAdapters/Features/CalendarRelay/Adapters/Outbound/EventKit/EventKitCalendarStore.swift`.
- CLI reconciliation exists in `Sources/CalRelay/Features/CalendarRelay/Adapters/Inbound/CLI/CalRelayCommand.swift`, but this plan does **not** move sync actions into the app or menu yet.

## Architecture decisions

- Keep lifecycle and menu bar code in `Sources/CalRelayApp/` as app/bootstrap/inbound adapter code.
- Split the current single app file into focused app-edge files before adding status item behavior.
- Keep the app Dock-visible by default; do not add `LSUIElement`, activation policy changes, login items, helper targets, or LaunchAgents.
- Persist only the menu bar visibility preference in app-owned settings. Prefer `@AppStorage("showMenuBarItem")` with a default value of `true`; a tiny `UserDefaults` wrapper is acceptable only if it keeps hide/show behavior clearer.
- The menu bar item should default to **on**, with a user-facing setting to hide or show it.
- Prefer SwiftUI `MenuBarExtra` first because the app already uses SwiftUI and targets macOS 26. Fall back to a small AppKit `NSStatusItem` adapter only if SwiftUI scene conditionality or window focusing does not meet the acceptance criteria in the SwiftPM-built app bundle.
- Menu handlers should only open/focus app UI or quit; they must not call `ReconcileCalendarsUseCase`, load YAML config, mutate calendars, start timers, or subscribe to EventKit changes.
- Keep EventKit permission/calendar listing through `EventKitCalendarStore` and `CalendarListFormatter` for the current recovery/status surface.

## Task list

## Phase 1: App edge cleanup and recoverable control panel

### Task 1: Split the app entry, view model, and view into focused files

**Description:** Refactor `Sources/CalRelayApp/CalRelayApp.swift` so the app entry point, calendar-list view model, and calendar-list view are separate focused files under `Sources/CalRelayApp/`. This keeps the current behavior unchanged while making room for lifecycle/menu-bar code.

**Acceptance criteria:**

- [x] `CalRelayApp.swift` contains only the SwiftUI `@main` app entry and scene composition.
- [x] `CalendarListViewModel` lives in its own file and remains `@MainActor`.
- [x] `CalendarListView` lives in its own file.
- [x] The **List Calendars** flow still requests Calendar access and renders EventKit-visible calendars.
- [x] No EventKit types leak into `CalRelayCore`.

**Verification:**

- [x] `swift build`
- [x] `swift test` via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- [x] `zsh scripts/build-calrelay-app.sh`
- [ ] Manual app check: open `.build/CalRelay.app`, click **List Calendars**, confirm existing behavior.

**Dependencies:** None

**Files likely touched:**

- `Sources/CalRelayApp/CalRelayApp.swift`
- `Sources/CalRelayApp/CalendarListViewModel.swift`
- `Sources/CalRelayApp/CalendarListView.swift`

**Estimated scope:** Small: 2-3 files

### Task 2: Add an explicit app control panel/status surface

**Description:** Evolve the current minimal calendar-list screen into a small control panel that clearly communicates the Stage 1 role: permission check, visible calendar check, and future configuration/status location. This is still UI-only and does not add reconciliation controls.

**Acceptance criteria:**

- [x] Main window remains the primary recovery/status surface.
- [x] UI copy clearly says the app currently supports Calendar permission and visible-calendar checks.
- [x] UI does not expose `Dry Run Sync`, `Run Sync Now`, background sync, or scheduling controls.
- [x] Calendar permission/listing errors remain user-actionable.

**Verification:**

- [x] `swift build`
- [x] `zsh scripts/build-calrelay-app.sh`
- [ ] Manual app check: control panel copy and **List Calendars** behavior.

**Dependencies:** Task 1

**Files likely touched:**

- `Sources/CalRelayApp/CalendarListView.swift`
- Optional: `README.md` if user-visible app behavior copy changes materially.

**Estimated scope:** Small: 1-2 files

### Checkpoint: Stage 1 normal app baseline

- [ ] App remains visible in Dock and app switcher.
- [x] Bundle identifier remains `dev.owinter.CalRelay`.
- [ ] Calendar permission and visible-calendar listing still work through the app bundle.
- [x] No accessory-only, launch-at-login, helper, cron, or automatic sync behavior exists.

## Phase 2: User-configurable UI-only menu bar item

### Task 3: Add app-owned menu bar visibility preference

**Description:** Add a simple app-edge settings model for whether the menu bar item is visible. Use `@AppStorage` or a tiny app settings wrapper in `Sources/CalRelayApp/`; this is an app adapter concern, not a core application DTO.

**Acceptance criteria:**

- [x] The main app UI has a user-facing toggle for showing/hiding the menu bar item.
- [x] The implementation uses a stable app-edge preference key, preferably `showMenuBarItem`.
- [x] The preference persists across app restarts.
- [x] The menu bar item defaults to **on**.
- [x] No runtime configuration keys are added to `CalRelayCore`.

**Verification:**

- [x] `swift build`
- [x] `zsh scripts/build-calrelay-app.sh`
- [x] CLI/AppleScript app check: preference value persisted across app launch/quit cycle.
- [ ] Manual app check: toggle preference in the UI, quit/reopen, confirm visual persistence.

**Dependencies:** Task 2

**Files likely touched:**

- `Sources/CalRelayApp/CalRelayApp.swift`
- `Sources/CalRelayApp/CalendarListView.swift`
- Optional: `Sources/CalRelayApp/AppSettings.swift`

**Estimated scope:** Small: 1-3 files

### Task 4: Add a SwiftUI/AppKit menu bar status item with minimal actions

**Description:** Add a menu bar item controlled by the visibility preference. First try SwiftUI `MenuBarExtra`; if conditional scene inclusion or runtime hide/show is awkward in the SwiftPM-built app bundle, use a tiny AppKit `NSStatusItem` adapter owned by `Sources/CalRelayApp/`. The first item should be UI-only and contain only minimal lifecycle actions.

**Acceptance criteria:**

- [ ] When enabled, a CalRelay menu bar item appears.
- [ ] When disabled, the status item is removed/hidden at runtime and remains hidden after restart.
- [x] Menu contains `Open CalRelay` and `Quit`.
- [ ] `Open CalRelay` opens or focuses the main app window.
- [x] `Quit` terminates the app through normal app lifecycle.
- [x] Menu actions do not instantiate `ReconcileCalendarsUseCase`, load YAML config, mutate calendars, start timers, or listen to EventKit changes.
- [ ] App remains Dock-visible while menu item is enabled.

**Verification:**

- [x] `swift build`
- [x] `zsh scripts/build-calrelay-app.sh`
- [ ] Manual app check: enable item, use `Open CalRelay`, close/reopen window if applicable, use `Quit`.

**Dependencies:** Task 3

**Files likely touched:**

- `Sources/CalRelayApp/CalRelayApp.swift`
- `Sources/CalRelayApp/MenuBarControl.swift` or `Sources/CalRelayApp/MenuBarStatusItemController.swift`
- Optional: `Sources/CalRelayApp/AppWindowController.swift` if focusing/opening the SwiftUI window needs a small adapter.

**Estimated scope:** Medium: 2-4 files

### Checkpoint: First menu bar milestone

- [x] Menu bar item is user-configurable.
- [ ] App remains normal Dock-visible app.
- [x] Menu is UI-only: no sync, no timers, no EventKit notifications, no background behavior.
- [ ] Manual real-app validation completed with `.build/CalRelay.app`.

## Phase 3: Documentation and validation closure

### Task 5: Update lifecycle/user documentation

**Description:** Update docs to reflect the implemented Stage 1/Stage 2 app behavior and preserve future-stage boundaries.

**Acceptance criteria:**

- [x] `README.md` app section mentions the control panel and optional menu bar item.
- [x] `README.md` links to `docs/specs/calrelay-app-lifecycle-spec.md` or this implementation plan so the UI-only lifecycle staging remains discoverable.
- [x] `docs/specs/calrelay-app-lifecycle-spec.md` remains the lifecycle source of truth; if changed, only update it to reflect accepted implementation details, not to expand scope.
- [x] `docs/manual-validation.md` includes a manual menu bar validation recipe if menu behavior is implemented.
- [x] Docs explicitly avoid implying background sync or automatic reconciliation.

**Verification:**

- [x] Documentation review against implemented UI.
- [x] Commands in docs remain copy/pasteable:
  - `swift build`
  - `swift test`
  - `zsh scripts/build-calrelay-app.sh`
  - `open .build/CalRelay.app`

**Dependencies:** Tasks 3-4

**Files likely touched:**

- `README.md`
- `docs/manual-validation.md`
- Optional: `docs/specs/calrelay-app-lifecycle-spec.md` if accepted implementation details need recording.

**Estimated scope:** Small: 1-3 files

### Task 6: Run full local quality gate and final manual lifecycle check

**Description:** Run the project quality gate and manually verify the app lifecycle constraints from the spec.

**Acceptance criteria:**

- [x] `swift build` passes.
- [x] `swift test` passes, using `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` if the active Command Line Tools Swift Testing runtime issue appears again.
- [x] `zsh scripts/build-calrelay-app.sh` succeeds.
- [x] Opening `.build/CalRelay.app` launches the built app process.
- [ ] Visual Dock/app-switcher confirmation still needs human confirmation.
- [ ] Calendar listing still works with bundle identifier `dev.owinter.CalRelay`.
- [ ] Menu bar item can be enabled/disabled and remains UI-only.
- [x] No `Info.plist` change hides the Dock icon or changes the bundle identifier.

**Verification:**

- [x] `swift build`
- [x] `swift test` or `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- [x] `zsh scripts/build-calrelay-app.sh`
- [x] Native app metadata, signature, process lifecycle, and preference persistence self-test.
- [ ] Manual app/menu lifecycle validation.

**Dependencies:** Tasks 1-5

**Files likely touched:**

- No planned code files unless validation reveals gaps.
- Handoff notes should include validation results.

**Estimated scope:** Small, variable if issues are found.

### Checkpoint: Complete first lifecycle/menu milestone

- [ ] All Stage 1 behavior remains intact.
- [ ] Stage 2 UI-only menu bar item works and is user-configurable.
- [x] Spec non-goals are preserved.
- [x] Docs and manual validation notes match implemented behavior.
- [ ] Ready for review before any Stage 3 manual sync planning.

## Explicit non-goals

- Do not add `Dry Run Sync`, `Run Sync Now`, or manual reconciliation buttons/menu actions.
- Do not add automatic reconciliation.
- Do not add in-app timers.
- Do not listen for EventKit change notifications.
- Do not add launch-at-login, LoginItems, helper apps, LaunchAgents, or system cron.
- Do not hide the Dock icon or make the app accessory-only.
- Do not change `CFBundleIdentifier` from `dev.owinter.CalRelay`.
- Do not move EventKit APIs into `CalRelayCore`.

## Implementation notes for the first pass

- Keep the first implementation intentionally manual-validation driven for app/menu lifecycle behavior. Do not add broad UI automation unless a thin deterministic seam naturally appears.
- If `MenuBarExtra` is used, keep the visibility preference close to scene composition and verify that disabling the preference removes or hides the menu item both immediately and after restart.
- If `NSStatusItem` is used, keep it as an app-edge adapter with no reconciliation or EventKit orchestration responsibilities.
- Treat `Open CalRelay` as lifecycle/window management only. Any future sync action belongs in a later plan after configuration validity, selected calendars, permission state, latest operation status, and confirmation behavior exist.

## Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| SwiftPM-built SwiftUI app may have limitations around `MenuBarExtra` or window focusing | Medium | Try the smallest SwiftUI-native approach first; fall back to an app-edge AppKit `NSStatusItem` controller if needed. |
| Menu item could accidentally imply background operation | Medium | Keep menu labels minimal and docs explicit: `Open CalRelay`, `Quit` only. |
| Window focusing from menu may be awkward with SwiftUI `Window` scene | Medium | Keep a tiny app-edge helper if needed; avoid business logic in it. |
| Preference storage could sprawl into core settings | Low | Keep menu preference in `Sources/CalRelayApp/` only. |
| Changing app metadata could disrupt Calendar permissions | High | Avoid `Info.plist` bundle identifier changes; review diff before validation. |

## Decisions resolved before implementation

- The menu bar item should default to **on**.
- The implementation plan should be stored in `docs/plans/calrelay-app-lifecycle-implementation-plan.md`.

## Open questions

- None blocking for the first UI-only menu bar milestone.