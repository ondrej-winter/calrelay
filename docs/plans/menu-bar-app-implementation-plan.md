# Implementation Plan: Menu Bar App

## Outcome and basis

Replace CalRelay's Dock presence with a persistent menu bar entry point while
retaining the existing control panel and one app-owned synchronization lifecycle.
Window closure keeps scheduling active; Quit stops it.

**Requirements source:** [macOS app specification revision 9](../specs/macos-app-spec.md),
especially APP-01, APP-04, APP-05, APP-06 and APP-AC-01, APP-AC-10, APP-AC-12,
APP-AC-17, APP-AC-18.
[ADR 0006](../adr/0006-run-calrelay-as-a-menu-bar-app.md) records the accepted
lifecycle decision and supersedes ADR 0001.

**Readiness:** Ready — the accepted outcomes and validation procedures are
defined. T1 resolves bounded platform and UI-query details before production shell
work; it does not reopen the accepted product decision. The owner authorized slice-by-slice implementation and local commits without
pushing on November 6, 2026. Implementation is in progress.

**Execution boundary:** Implement and validate each slice, then commit that slice
locally. Do not push, publish, run protected release operations, change dependencies,
or mutate real calendars. Planning preparation performed no runtime operations;
implementation evidence is recorded with each task below.

**Next action:** T5, aligning delivered guidance. Required native runtime checks
remain explicit; the persistent goal covers all tasks and final checks.

## Scope and implementation approach

- Keep the menu limited to safe status, **Open CalRelay**, and **Quit CalRelay**.
  Existing setup, pause/resume, authorization, manual sync, and cleanup controls
  stay in the control panel. No new quick-sync mutation path is needed.
- Respect icon hiding through macOS settings; do not add a competing in-app
  visibility preference. Spotlight must recover the panel and Quit access even
  with both the Dock and menu bar icons absent. Hidden status does not pause
  automation or remove the requirement to actively surface alert-worthy problems.
- For new actionable or overdue problems after startup, send a notification when
  available; otherwise open/focus the control panel, also on a reported submission
  failure. Coalesce repeated presentation of the same unresolved problem. Keep
  transient retries quiet unless they meet the existing alert criteria. Preserve
  the separate login-startup presentation policy.
- Retain the same bundle identifier, signing identity, configuration, Calendar
  access owner, persistence, login-item registration, and automation bindings.
  No new dependency, service, entitlement, scheduling policy, or data format is
  required by the shell change.
- Use app-scoped ownership for the existing view model and lifecycle. Keep menu
  handlers and window operations thin; do not move reconciliation into AppKit or
  duplicate the scheduling coordinator for the menu.
- Candidate implementation: production `LSUIElement` metadata and an AppKit
  status item owned by the existing app delegate, observing the shared presentation
  state. This fits the existing AppKit window and delegate code. T1 must validate
  this against Apple's SDK documentation and the fake host before selection.
  A SwiftUI menu bar scene is an alternative if it simplifies the same lifecycle
  and accessibility requirements. Use one menu mechanism, not both.
- Keep the fake UI host separately identified and permission-free. Share the
  production shell path with injected fake services so its tests exercise real
  window/menu wiring rather than a parallel shell.
- Helpers, LaunchAgents, operation after app exit, new triggers, visual YAML
  editing, release publication, and unrelated UI redesign remain out of scope.

## Inspected implementation and constraints

- `CalRelayApp.swift` constructs one `CalendarListViewModel` and exposes a SwiftUI
  `Window`. `CalendarListView.swift` currently calls `start()` from `.task`.
  `start()` is guarded against repeats, but hidden startup must not depend on
  SwiftUI creating window content.
- `CalRelayAppDelegate.swift` suppresses the login window, focuses existing
  `NSApp.windows` on reopen, and owns the scheduling-enabled Quit warning. Showing
  existing windows alone may not recover a closed SwiftUI window; explicitly
  verify recreation and focus through the chosen window owner.
- `CalendarAutomationAttentionController.swift` writes `NSApp.dockTile` and
  requests user notifications. Its notification controller can be disabled;
  menu status must remain available independently of notification authorization.
- `CalendarListViewModel+Automation.swift` contains Dock wording and lifecycle
  restoration. `CalendarAutomationTriggerSource.swift` owns real timers and wake
  observation; do not create extra sources when opening the menu or window.
- Both production build paths copy `Resources/CalRelayApp/Info.plist`;
  `Resources/CalRelayUITestHost/Info.plist` is a separate source file. Change source
  metadata rather than patching generated bundles.
- `CalendarUITestComposition.swift` currently injects `.ordinary` launch context,
  a no-op presentation callback, and disabled real automatic attempts. Add bounded
  fake lifecycle seams for hidden-login coverage rather than enabling OS services.
- The executable test runner depends on `CalRelayKit`, not the app executable.
  Exercise AppKit wiring through the fake UI host. Add deterministic kit coverage
  only for meaningful framework-free policies, not a new library abstraction
  solely to access app internals from tests.

## Assumptions and technical questions

No unresolved product decisions remain. Ordinary explicit launches continue to
show the panel; healthy login launches keep it closed under the existing policy.

### Interview outcome — confirmed on November 6, 2026

- **Status:** Confirmed intent. The owner answered “yes” to notification-first
  alerting with automatic panel opening when notifications are unavailable.
- **Stated solution (Y):** Required menu bar app with native macOS icon visibility
  control and Spotlight recovery; a separate app visibility setting is unnecessary.
- **Underlying outcome (X):** Quiet background synchronization without Dock
  clutter, while problems actively reach the user even with the icon hidden.
- **XY-risk:** Low — the owner selected the shell and clarified the desired
  interruption behavior; the mechanism serves that confirmed outcome.
- **Hypothesis and confidence:** The intent is sufficient for plan review, 95%.
  Evidence is the owner's menu bar approval, request for system-controlled
  visibility, insistence that problems open/notify, and approval of the concrete
  notification-first/panel-fallback rule.
- **Primary user:** The project owner using CalRelay on their Mac.
- **Trigger / why now:** The app should maintain availability without occupying
  the Dock or requiring a visible menu bar icon.
- **Success signals:** No Dock icon; macOS can hide the menu item without stopping
  sync; Spotlight recovers controls; an alert-worthy problem after startup sends
  a notification or opens recovery when notifications are unavailable.
- **Constraints:** Existing identity, permissions, mutation authority, startup
  recovery, scheduling cadence, and process-exit boundary remain in force.
- **In scope:** System-controlled icon visibility, Spotlight recovery, menu/panel
  status, and active notification-first recovery.
- **Out of scope:** A competing icon toggle, a new notification channel, helper
  services, execution after Quit, or implementation during this planning task.
- **Accepted assumptions:** None needed for product intent.
- **Open questions / blockers:** No product questions; Q1–Q4 below are technical
  verification dependencies. Implementation still awaits the owner's request.
- **Next step:** Specification and plan refinement under this confirmed intent,
  followed by owner review; no further interview confirmation is needed.

| ID | Question or assumption | Affected work | Resolution |
| --- | --- | --- | --- |
| Q1 | Candidate accessory-app metadata, activation, window recreation, and menu accessibility must work together on the supported macOS toolchain. | T2 and T4 shell wiring | T1: inspect Apple SDK documentation and exercise a disposable fake shell; record the selected API and observed behavior. |
| Q2 | XCUITest must be able to identify the status item and menu reliably without personal screen coordinates. | T2–T4 UI checks | T1: establish the accessible query and stable identifiers. If the OS exposes the item outside the app tree, use an explicit system UI query supported by the test toolchain; record any coverage gap and retain manual evidence. |
| Q3 | This shell change should not invalidate existing configuration-bound standing authorization or login registration. | T4 upgrade checks | Preserve identity and stored formats, inspect a safe fixture with prior preferences, and verify retained authorization; real OS identity continuity requires explicit Mac validation. |
| Q4 | Determine how the selected notification API exposes alert availability and submission errors, and how native menu hiding is preserved. | T1 platform investigation; T3 alert routing; T4 recovery | Inspect Apple documentation during T1, record the platform signals and a fakeable presentation boundary before T3. Do not treat notification submission as proof the user saw an alert or bypass OS presentation controls such as Focus. Native icon visibility and Spotlight integration need Mac runtime evidence. |

## Requirement coverage and execution order

| Requirement | Tasks | Principal evidence |
| --- | --- | --- |
| APP-01 / APP-AC-01: no Dock icon, recoverable control panel | T1, T2 | T2-AC1, T2-AC2, T2-V1, CP-FINAL-3 |
| APP-04 / APP-AC-12: scheduling independent of windows | T2, T4 | T2-AC3, T4-AC1, T4-V1 |
| APP-05 / APP-AC-10: safe menu status and notification fallback | T3 | T3-AC1 through T3-AC3, T3-V1, CP-FINAL-3 |
| APP-01 / APP-AC-17: native hiding and Spotlight recovery | T1, T2, T4 | T2-AC2, T4-AC4, T4-V1, CP-FINAL-3 |
| APP-05 / APP-AC-18: notification-first active recovery | T1, T3, T4 | T3-AC4, T3-V1, T4-AC4, CP-FINAL-3 |
| APP-05 / APP-06 / APP-AC-12: login, Quit, no helper | T4 | T4-AC1 through T4-AC3, T4-V1, CP-FINAL-3 |
| APP-AC-02, APP-AC-04, APP-AC-08, APP-AC-09, APP-AC-16: preserved permissions, confirmation, identity | T2–T5 | Existing regression suites, T4-AC3, CP-FINAL-2 and CP-FINAL-3 |
| Accurate delivered usage and implementation evidence | T5 | T5-AC1, T5-V1 |

Execute sequentially: T1 → T2 → T3 → T4 → T5 → final checks. Each task includes
its focused evidence. The final checks cover the integrated result. No parallel
agent work is required; these tasks share the app shell and fake composition.

## Task details

### T1: Confirm the shell and its verification path

- [x] `T1` — Resolve Q1, Q2, and Q4's platform signals before changing production presentation.

**Basis:** Prerequisite for APP-AC-01 and APP-AC-12.
**Dependencies:** Implementation requested; supported macOS and Swift toolchain,
with Xcode 27+ for the fake UI lane.
**Scope:** S — one bounded platform investigation, no calendar integration.
**Targets:** Existing delegate/window code, both source plists, and the fake host;
any disposable prototype is not a delivered implementation. Investigate one
candidate shell and at most the named alternative; produce the recorded findings
and unresolved failures rather than expanding into an unrelated platform audit.

- [x] `T1-AC1` — Record the chosen menu API, accessory metadata, startup hook,
  single-panel reopen mechanism, and accessible status-item query, citing Apple
  SDK documentation and observations. The chosen approach supports a windowless
  running process without a Dock icon, respects native icon hiding, and provides
  testable notification availability and submission-result handling for T3.
- [x] `T1-V1` — Inspect local SDK documentation or official Apple documentation,
  then exercise one minimal fake shell: show, close, reopen, and focus its panel;
  inspect its status item with accessibility tooling. Record any unsupported
  test-tool query and the manual procedure that supplies the missing evidence.
  Inspect native visibility persistence and notification error/availability
  documentation; record precise signals and limits without live permission prompts.

**Evidence (2026-11-06, risk-first slice):** Selected AppKit `NSStatusItem` with
an `NSMenu`, a stable `autosaveName`, `.removalAllowed` without
`.terminationOnRemoval`, and production/fake-host `LSUIElement = true`. A retained
AppKit `NSWindow` (`isReleasedWhenClosed = false`) hosts the existing SwiftUI panel.
The delegate starts the shared view model at app launch and shows/focuses this
same window for menu, explicit reopen, and recovery. This avoids a second SwiftUI
window lifecycle and preserves pending review sheets.

A disposable permission-free probe under `/private/tmp/calrelay-menu-probe`
compiled and ran on macOS 27.2 / Swift 6.4.2. Its assertions reported
`accessory=true accessibleLabel=true closed=true reopenedSamePanel=true singleVisiblePanel=true`.
The single-panel check intentionally excludes AppKit's status-item window. Native
computer-use inspection saw the panel; its app tree did not expose the system
menu item reliably. The planned XCUITest query is the status item with the explicit
CalRelay accessibility label, checking the app and Control Center surfaces. T2
must validate that query; if unavailable, retain recorded manual menu evidence at
CP-FINAL-3 instead of claiming automated coverage. The probe does not prove
Spotlight, macOS settings persistence, login registration, or real notification
presentation. Those remain the planned runtime checks, not discovery successes.

Authoritative sources and implementation rules:

- [Apple Launch Services keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html):
  `LSUIElement` selects an agent app without Dock presence.
- Apple's installed `AppKit.framework/Headers/NSStatusItem.h` in the macOS SDK:
  visibility persists by `autosaveName`; removal and termination-on-removal are
  separate behaviors. Set the stable name, never force `isVisible = true` on reopen.
- [Last-window termination delegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:)):
  return false so closing the last panel leaves the run loop alive.
- [Notification alert settings](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/alertsetting):
  check alert capability as well as authorization. Submission is not evidence of
  user receipt, and OS presentation controls remain respected. A reported
  submission error selects panel recovery. Fake delivery must cover both outcomes.

The initial unprivileged build was blocked by compiler-cache sandbox access; the
approved build used the normal caches. The existing fake UI baseline is running
separately; it is not claimed passed here. No production app or EventKit was used.

### T2: Deliver the persistent menu shell and recoverable panel

- [x] `T2` — Replace Dock presentation and make startup independent of the window.

**Basis:** APP-01, APP-04, APP-06; APP-AC-01 and APP-AC-12.
**Dependencies:** T1's selected shell, startup, and query mechanisms.
**Scope:** M — one coherent shell/lifecycle slice with fake-backed coverage.
**Confirmed targets:** `Sources/CalRelayApp/CalRelayApp.swift`,
`CalRelayAppDelegate.swift`, `CalendarListView.swift`, `CalendarListViewModel.swift`,
`CalendarUITestComposition.swift` in the same directory; both source plists;
`Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAppBundleMetadataTests.swift`;
`UITests/CalRelayUITests/CalRelayUITests.swift`.
**Proposed new component:** `Sources/CalRelayApp/CalendarMenuBarController.swift`
if the selected AppKit approach needs a separate small presentation controller.

- [x] `T2-AC1` — One app-owned menu item is available with Open CalRelay and Quit
  CalRelay; no Dock icon appears during startup or with the panel open or closed.
  The item respects macOS hiding instead of forcing itself visible.
  Both production and fake bundles use the intended shell metadata while
  retaining their distinct identities and permission metadata.
- [x] `T2-AC2` — Menu Open, explicit launch, and reopen (including Spotlight with
  the item hidden) focus one existing panel or recreate it after closure, without
  duplicates. Intentional Quit remains accessible from the focused app even when
  the status item is hidden. Pending review sheets and their existing
  confirmation/cancellation behavior remain intact.
- [x] `T2-AC3` — One shared view model starts from app lifecycle, including when
  login presentation stays hidden. Closing/reopening the panel or opening the
  menu neither restarts observers/triggers nor terminates the app. No slow work
  moves onto the main actor as part of the shell.
- [x] `T2-V1` — Add metadata regression assertions and fake UI flows for Open,
  close/reopen, focus without duplicates, and a startup counter or equivalent
  fake lifecycle evidence. Introduce injectable fake launch context and shared
  presentation callbacks here so hidden startup can be verified before T2 is
  complete; T4 expands this seam with explicit trigger and Quit scenarios.
  Run `swift run CalRelayKitTests CalendarAppBundleMetadataTests`
  and `make ui-test`; expect the new cases and existing review flows to pass.
  Runtime Dock absence is additionally verified at CP-FINAL-3.

**Evidence (2026-11-06, vertical slice):** Both source plists now declare
`LSUIElement`; the delegate owns one retained panel and status item for production
and fake composition, starts the shared view model independently of presentation,
and keeps the process alive after window closure. The panel exposes intentional
Quit even when the icon is hidden. Fake healthy login uses seeded authorization,
a fixed presentation clock, and the production launch-presentation callback;
reopening uses Launch Services without starting another view model.

RED: the focused metadata suite failed because `LSUIElement` was absent; the menu
UI case failed because there was no status item; the hidden-login case failed
because the panel was visible. GREEN: `CalendarAppBundleMetadataTests` passed,
`make check` passed (SwiftLint: zero violations), `make app` built and strictly
verified the local bundle, and `make ui-test` passed all 12 cases, including menu
close/reopen, healthy hidden login, manual and cleanup reviews, Escape cancellation,
pause/resume, and relaunch disposal. `make format-check` exited successfully with
existing warnings outside this slice's formatted files; `git diff HEAD --check`
passed. The app/Control Center accessibility query reached the actual status item
and Open action, resolving T1's query-reachability uncertainty.

The old Dock-shell UI baseline had one cleanup-sheet timeout and subsequent UI
authorization failures. The complete 12-case run through the new shared shell
passed without those failures. Desktop activity produced interruption diagnostics
but no failures in the passing run. Accessory apps may report background state
with a visible window, so the harness asserts process existence and actual panel
content instead of requiring a Dock-style foreground state. No test skips or
permission bypasses were added. Final macOS settings, Spotlight indexing, login,
wake, and real notification evidence remain at CP-FINAL-3. Self-review found no
remaining blocking issue for this shell slice; scheduling and permission authority,
production identity, and dependency files are unchanged.

### T3: Deliver menu status and notification-independent attention

- [x] `T3` — Deliver safe menu status and notification-first active recovery.

**Basis:** APP-05, APP-AC-10, and APP-AC-18.
**Dependencies:** T2's shared shell and view-model ownership; T1's Q4 platform signals.
**Scope:** M — one presentation and fallback slice.
**Confirmed targets:** `Sources/CalRelayApp/CalendarAutomationAttentionController.swift`,
`CalendarListViewModel.swift`, `CalendarListViewModel+Automation.swift`,
`CalendarUITestComposition.swift`, `CalRelayAppDelegate.swift` in the same directory,
the T2 menu component, and `UITests/CalRelayUITests/CalRelayUITests.swift`.

- [x] `T3-AC1` — Menu and panel use the same current safe operational state.
  Unchecked, disabled/paused, normal, and actionable/overdue states are accurately
  represented. Secondary retry/freshness information does not hide an earlier
  unmet prerequisite. Menus do not expose private configuration or calendar data.
- [x] `T3-AC2` — With notifications denied and the panel closed, attention remains
  represented through the menu indicator and an accessible non-color description
  whenever the user allows the icon to be shown. Active recovery follows T3-AC4
  regardless of icon visibility.
  Recovery clears obsolete warning state on the menu and panel. A status refresh
  failure never leaves a misleading healthy indicator.
- [x] `T3-AC3` — Remove Dock badge dependence and stale Dock wording in production
  and fake presentation. Preserve notification authorization and alert eligibility;
  status presentation never requests Calendar access or authorizes mutation.
- [x] `T3-AC4` — A new runtime actionable/overdue condition sends a notification
  without auto-opening the panel when notifications are available. Unavailable
  notifications or reported submission failure opens/focuses recovery without
  requiring a visible status item. Repeated refreshes do not steal focus again
  for the same unresolved problem; recovery and a subsequent new problem can
  alert again. A transient retry alone does not interrupt the user, and opening
  recovery neither requests Calendar access nor authorizes mutation. Use the
  existing single-panel presentation path rather than a separate recovery window.
- [x] `T3-V1` — Use deterministic fake state transitions for unchecked, healthy,
  paused, blocked, overdue, refresh failure, and recovered states; compare menu and
  panel output while closing/reopening the panel. Run `make ui-test` and expect
  accessible identification and the available/unavailable/failed-submission
  presentation matrix to pass with fake notification delivery and no OS prompts.
  Include hidden-icon presentation, unchanged-problem coalescing, recovery then
  recurrence, and transient-retry silence. Verify fake notifications record only
  safe categories and that fallback preserves any pending confirmation sheet.
  Add a pure selection-policy suite to the custom runner only if meaningful new
  framework-free logic is extracted; register any such suite in
  `Tests/CalRelayKitTests/Main.swift` before running it.

**Evidence (2026-11-06, vertical slice):** Live menu presentation observes the
shared view model and exposes safe primary/scheduling status, non-color attention
symbols, accessible text, and explicit unchecked/checking/failed-refresh states.
No Dock badge remains. Notification-first delivery is orchestrated by the new
framework-free `CalendarAutomationAlertUseCase` and `CalendarAutomationAlertPort`;
AppKit/UserNotifications remain in the app adapter. This additive Kit API has no
existing external consumer migration. Its port accepts only safe application DTOs
and reports notification availability/submission failure, clearing, and panel
presentation. Session state coalesces identical problems; revisions reject obsolete
async completions and source sequence numbers reject out-of-order UI tasks.

New source boundaries: `Sources/CalRelayKit/Features/CalendarRelay/Application/Ports/CalendarAutomationAlertPort.swift`
and `UseCases/CalendarAutomationAlertUseCase.swift` under the same application
folder. `CalendarAutomationAlertTests.swift` is registered in the existing custom
runner. Six deterministic tests cover submitted notifications without panel
opening, denied/failed delivery fallback, recurrence after recovery, quiet startup
and pause, delayed availability after recovery, and out-of-order updates. Nearby
coordination tests retain transient retry and overdue precedence coverage.

RED: the behavior tests failed with no notification submitted, the source-order
regression revived an old problem, and the UI status test could not find scheduling
status with the panel closed. The runtime UI matrix also exposed a fake-adapter
instance mismatch and fragile `NSApp.delegate` casts. Production and fake
composition now capture the actual delegate instance through weak callbacks;
the delegate is the sole view-model owner. This fixes actual recovery delivery and
initial launch-presentation callbacks rather than relying on source inspection.

GREEN: `CalendarAutomationAlertTests` and `CalendarAutomationCoordinationTests`
passed. The final `make ui-test` passed all 14 cases, including notification success
(panel stays closed), denied notification (panel opens), and submission failure
(panel opens), driven by explicit fake flags on window closure. These fixtures use
the real controller/use case/window path, no OS notification service, no live timers,
and no real calendars. The full `make check` and strictly verified `make app` passed.
`make format-check` exited successfully with pre-existing warnings outside the
changed formatted files. A lint finding in the test fixture was fixed with a named
result instead of a large tuple; final lint reports no violations. `git diff HEAD
--check` passed. Self-review found no blocking issue. Real notification/Focus,
native hiding/restoration, and Spotlight remain explicit CP-FINAL-3 evidence.

### T4: Prove login, windowless operation, Quit, and compatibility

- [x] `T4` — Integrate the shell with the existing lifecycle and authorization.

**Basis:** APP-03 through APP-06; APP-AC-01, APP-AC-05, APP-AC-12, APP-AC-16.
**Dependencies:** T2 and T3 integrated through one shared presentation state.
**Scope:** M — lifecycle edge cases and compatibility, without new scheduling rules.
**Confirmed targets:** `Sources/CalRelayApp/CalRelayAppDelegate.swift`,
`CalendarListViewModel+Automation.swift`, `CalendarUITestComposition.swift` in the
same directory; `CalendarLoginLaunchPolicyTests.swift`,
`CalendarAutomationCoordinationTests.swift`, `CalendarAutomationPersistenceTests.swift`
under `Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/`;
`UITests/CalRelayUITests/CalRelayUITests.swift`.

- [x] `T4-AC1` — Fake healthy login initializes automation without creating or
  showing the panel or opening the menu; actionable login opens recovery under
  the existing launch policy. Injected launch/wake/timer/retry and configuration
  changes still reach the single coordinator with the panel closed, with no
  overlap or duplicate observers after repeated reopen. Tests use explicit fake
  triggers rather than waiting for real timers or mutating real calendars.
- [x] `T4-AC2` — Menu Quit reaches the existing warning when scheduling is enabled;
  Cancel leaves the process and lifecycle active, and confirmed Quit exits. A
  disabled-scheduling Quit exits without the scheduling warning. Quitting retains
  saved scheduling and login preferences and introduces no execution after exit.
- [x] `T4-AC3` — A fixture carrying existing authorized preferences retains them
  across the shell upgrade. Calendar prompts remain exclusive to the explicit
  setup/recovery action; manual and cleanup reviews retain exact confirmation.
  Production identity, signing assumptions, persistence keys, and the existing
  same-app login controller are preserved without a policy-version bump.
- [ ] `T4-AC4` — With the icon hidden, launch/reopen recovers controls and Quit
  without restoring menu visibility or duplicating lifecycle ownership. Native
  hiding does not change scheduling. Post-startup problem routing follows T3-AC4
  while actionable-login recovery retains its existing opening policy even when
  notifications are available. No automatic presentation confirms pending mutation.
- [x] `T4-V1` — Extend T2's fake lifecycle composition with explicit trigger
  delivery and retained-preference/Quit scenarios while preserving its
  disabled EventKit, OS registration, notifications, filesystem observation, and
  real timers. Run `make ui-test` for lifecycle/quit cases and
  `swift run CalRelayKitTests CalendarLoginLaunchPolicyTests CalendarAutomationCoordinationTests CalendarAutomationPersistenceTests`
  for deterministic regressions. Record exact checks for hidden initialization,
  single startup, fake trigger delivery, and retained preferences. Real login,
  wake, OS-controlled hiding/restoration, Spotlight, and OS identity continuity
  remain manual CP-FINAL-3 evidence; fake presentation tests cannot prove these
  system integrations.

**Evidence (2026-11-06, lifecycle slice):** The final `make ui-test` passed all
21 cases on macOS 27.2 / Xcode 27.2. New cases prove healthy hidden initialization
before any panel exists, actionable-login recovery, explicit fake wake delivery
while closed, no duplicate panel or repeated operation after reopen, enabled Quit
Cancel/confirm, disabled Quit, and configuration-change recovery. The configuration
fixture changes the synchronization horizon from 30 to 31 days, so the existing
authorization invalidation path receives a mutation-relevant change. The resulting
panel requires fresh reviewed authorization and records zero mutations.

The fake trigger uses an injected fixed clock and the existing coordinator. It
does not register OS timers or wake observation. The separately identified UI host
now defaults to the isolated missing-configuration fixture even without arguments;
it cannot accidentally select production services. This safety regression was
verified only after adding the guard: running the old no-argument branch as a RED
test could have accessed production state. Wake and configuration regressions
were observed failing before their explicit fake event paths were added.

The Dock test first identifies Finder in the system Dock as a positive query
control, then verifies the fake app is absent with the panel open and closed.
Existing review/cleanup tests still pass. The full `make check` includes
`CalendarLoginLaunchPolicyTests`, `CalendarAutomationCoordinationTests`, and
`CalendarAutomationPersistenceTests`; all passed. Metadata, production identity,
stored keys, policy version, and same-app login registration remain unchanged.
No new Calendar permission or OS registration path was introduced.

Native computer-use inspection in System Settings > Menu Bar > Allow in the Menu
Bar successfully hid and restored **CalRelayUITestHost**; the control panel remained
recoverable. The test-host setting was restored to its original enabled state;
the production CalRelay setting was untouched. The computer-use tool could not
launch Spotlight (Launch Services returned a launch failure), so Launch Services
reopen tests are not claimed as Spotlight/indexing evidence. T4-AC4 remains open
for the complete hidden-icon, relaunch, and OS presentation matrix at CP-FINAL-3.

Final source gates: `make format-check`, `make check`, `make app` with strict
signature verification, and the 21-case `make ui-test` all passed. Formatting
reported existing warnings outside changed files; lint reported no violations.
No live EventKit, real notifications, real login registration, or real calendar
mutation was used. Real login/wake, notification/Focus, VoiceOver, and production
identity continuity still require the explicit native acceptance checkpoint.

### T5: Align delivered guidance and review the integrated change

- [ ] `T5` — Replace implementation-pending notes with accurate delivered usage.

**Basis:** Revision 9 compatibility notice and repository documentation policy.
**Dependencies:** T4's integrated behavior and focused evidence.
**Scope:** S — documentation and change review.
**Confirmed targets:** `docs/configuration.md`, `docs/repository-layout.md`,
`docs/development.md`, `docs/specs/macos-app-spec.md`, and this plan. Update other
current references only if the shell change affects their actual instructions;
preserve historical ADR rationale.

- [ ] `T5-AC1` — Current guidance explains menu access, closing versus quitting,
  denied-notification fallback, ordinary launch and login presentation, and the
  expanded fake UI lane, including native icon hiding, Spotlight recovery, and
  notification-first runtime alerts. The old Dock workflow is not presented as
  delivered behavior. Pending-implementation labels are removed only when supported by
  implementation evidence, and unverified OS checks remain explicit.
- [ ] `T5-V1` — Review the full diff against revision 9, verify referenced paths
  and commands, and search current docs/app presentation for stale Dock claims.
  Run `git --no-pager diff HEAD --check`; expect no whitespace errors. Record
  unresolved validation honestly in this plan and the implementation handoff.

**Evidence:** Pending.

## Final checks

**Prerequisites:** T1 through T5 and their required focused evidence.
All commands run from the repository root. Commands below are confirmed from
`docs/development.md` and `Makefile`; execution evidence is recorded per slice.

- [ ] `CP-FINAL-1` — Every in-scope requirement has evidence, the diff contains
  only the intended shell and supporting changes, and existing user work remains
  preserved. No unresolved required check is represented as passed.
- [x] `CP-FINAL-2` — Run `make format-check`, `make check`, `make app`, and
  `make ui-test`. Expect clean formatting, lint/build/custom-runner/smoke results,
  a strictly verified local bundle, and the complete fake UI lane to pass. UI
  tests require Xcode 27+; report missing prerequisites rather than bypassing them.
- [ ] `CP-FINAL-3` — On the supported Mac, inspect the built bundle for no Dock
  icon during launch/open/closed-panel states; test menu keyboard/VoiceOver
  access, panel recovery, healthy and actionable login, wake, denied-notification
  fallback, pause, configuration invalidation, and Quit/Cancel. Confirm the
  process survives window closure and exits on confirmed Quit. Hide/restore the
  icon in macOS settings, verify Spotlight recovery and Quit with both icons
  absent, and check that reopen/relaunch preserves hidden visibility. Exercise
  authorized notification-only runtime alerts and denied-notification panel
  fallback with the icon hidden, separately from login recovery. Any validation
  requiring real EventKit or OS registration is explicit local manual work using
  dedicated harmless calendars, not part of ordinary automated checks. Record
  authorization and evidence before doing that work; pending evidence blocks a
  claim of full lifecycle validation.

**Evidence:** Pending. Production signing/notarization and remote release are not
part of this implementation plan; preserve their existing contracts without
running protected release operations.

## Risks and fallback

- An accessory app can become difficult to recover if closing a window destroys
  its only presentation entry point. T1 and T2 verify recreation and explicit
  launch recovery; do not ship a menu action that merely iterates stale windows.
- A hidden launch can accidentally skip initialization or duplicate triggers
  when a panel later appears. T2 makes startup app-owned; T4 proves lifecycle
  cardinality and trigger delivery with fakes.
- Menu status can drift from the panel or disappear with notification denial.
  T3 uses shared state and keeps menu attention independent of notification
  permission; unchecked and failed-refresh states cannot imply health. Native
  hiding can remove that passive surface, so T3 also provides active alerts and
  a panel fallback. Notification submission is not evidence of user receipt;
  OS presentation controls remain respected and must not be inferred away.
- Test tooling may expose menu bar items through a system surface. T1 establishes
  the query before automation is promised. Any residual automation limitation
  requires recorded manual evidence and remains visible in the handoff.
- The shell does not migrate user data or credentials. If it must be withdrawn,
  a corrective build can restore the prior shell using the same identity and
  stored preferences; no rollback implies calendar mutation reversal. Do not
  publish or perform Git history operations without the owner's separate request.

## Review and status

2026-11-06: Specification revision 8 and ADR 0006 accepted by the owner;
implementation plan prepared for review. Self-review checked requirement coverage,
acyclic dependencies, source versus generated metadata, executable test-runner
constraints, fake-host isolation, status privacy, upgrade continuity, and the
distinction between static checks and Mac runtime evidence. This was not an
independent-agent review. All implementation and validation checkboxes remain
pending; the next action is owner review.

2026-11-06 follow-up: The interview resolved runtime interruption behavior and
system-controlled icon hiding; accepted specification revision 9 now governs this
plan. Existing task and progress IDs are preserved. T1/Q4 covers platform signals;
T3-AC4 and T4-AC4 add active-recovery and hidden-icon checks. No product questions
remain; technical validation and all implementation tasks are still pending.

Preparation checks: local Markdown links resolve, referenced focused suite names
are registered in the custom runner, progress IDs are unique, and
`git --no-pager diff HEAD --check` passes. These are documentation checks, not
implementation, build, or runtime validation. During planning, concurrently staged documentation
was preserved without staging or commits by this agent. Implementation commits are
now explicitly authorized; no push has been performed.

2026-11-06 implementation start: Owner requested a persistent implementation goal
and one local commit per completed slice, without pushing. T1 records the bounded
platform proof and its runtime limits; T2 begins the actual app shell.

2026-11-06 T2: Shared menu/window shell verified and ready for its local slice
commit. All 12 fake UI cases and the complete deterministic gate passed; T3 is next.

2026-11-06 T3: Notification-first routing, live menu state, and closed-panel recovery
verified through deterministic contracts and the 14-case UI lane. T4 is next.

2026-11-06 T4: Lifecycle implementation and the complete 21-case fake UI lane
passed with the full repository gate and signed bundle check. Native icon
hide/restore was observed and the original setting restored. T4-AC4 and
CP-FINAL-3 retain the outstanding system-integration acceptance evidence; T5 is next.
