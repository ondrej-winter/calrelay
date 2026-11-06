# Spec: macOS App Controls and Automation

## Specification record

- **Status:** Accepted.
- **Revision:** 9 — accepted on November 6, 2026; refines revision 8 with system-controlled menu bar visibility, explicit Spotlight recovery, and notification-first problem alerts with a control-panel fallback. Implementation is pending review of the [menu bar implementation plan](../plans/menu-bar-app-implementation-plan.md).
- **Acceptance basis:** The product interviews approved on September 16, 2026 prioritize reliably accurate relayed availability with minimal ongoing user effort for a developer who is comfortable editing YAML; when partial failure cannot avoid both harms, stale over-blocking is removed before replacement blockers are created. The project owner approved the production distribution identity boundary on September 25, 2026. On November 6, 2026, the project owner approved replacing Dock presence with a menu bar app, retaining the control panel, continuing sync with the window closed, showing status and problems in the menu bar, retaining launch-at-login, and stopping synchronization on Quit. The owner requested the specification change and an implementation plan for review, without implementing it yet.
- **Canonical artifact:** `docs/specs/macos-app-spec.md`.
- **Revision 9 acceptance:** In the follow-up interview, the project owner requested control of icon visibility through macOS settings and confirmed that problems must still actively reach them. The owner approved notifications first for alert-worthy problems arising after startup, with automatic control-panel opening when notifications are unavailable. Existing login recovery presentation remains in effect.
- **Scope:** The menu bar app and recoverable control panel, manual ordinary reconciliation, explicit legacy cleanup, scheduled reconciliation while the app process is running, launch-at-login, operational status, user notifications, and lifecycle boundaries.

## Required outcomes

### APP-01 — Recoverable control panel and operational state

- `CalRelay.app` runs as a menu bar app with no Dock icon, including while its control panel is open. Its main window remains the primary surface for setup, Calendar permission, all-calendar inventory, configuration status, configured readiness, scheduling, migration recovery, and operation results.
- While the app is running, its menu bar item provides operational status, an **Open CalRelay** action, and **Quit CalRelay**, subject to the user's macOS menu bar visibility setting. Open CalRelay opens the control panel or focuses the existing one, including after its last window has been closed; repeated use does not create duplicate control panels. An ordinary explicit launch or reopen through Spotlight (Command-Space, CalRelay, Return), Finder, or another standard launch surface also opens or focuses the control panel.
- The user can hide or restore the menu bar item through macOS settings independently of CalRelay. The app respects that choice across control-panel presentation and relaunch; it does not force the icon visible for recovery or add a competing in-app visibility preference. Hiding the item does not quit, pause, or alter synchronization or launch-at-login. With the item hidden, explicit launch or reopen still recovers the control panel and access to intentional Quit under APP-05.
- Closing the control-panel window does not quit the app, pause scheduling, cancel app-owned triggers, or change launch-at-login. Startup, configuration observation, scheduling, and status updates do not depend on the window being visible or on the user opening the menu.
- Menu actions remain presentation and lifecycle entry points. Calendar setup, standing-authorization review, manual sync confirmation, and cleanup review remain in the control panel under their existing authorization rules.
- The primary user may be expected to create and edit `~/.config/calrelay/config.yaml` manually. A visual configuration editor and alternate remembered app configuration paths are not required.
- A clearly labeled setup or recovery action in the main window is the only CalRelay action allowed to request full Calendar access and trigger the macOS Calendar permission prompt. Authorization-state behavior follows [`calendar-access-spec.md`](calendar-access-spec.md).
- After full access exists, the main window provides the all-calendar inventory defined in [`calendar-access-spec.md`](calendar-access-spec.md). Inventory remains visibly distinct from configuration validity and configured-topology readiness.
- The control panel shows one primary state and immediate recovery action, selected by dependency order so that the action can succeed. Later known issues remain visible as secondary issues.
- The primary dependency order is:
  1. selected configuration missing or structurally invalid;
  2. full Calendar access unavailable;
  3. configured topology not currently ready;
  4. migration pending and explicit cleanup required;
  5. ordinary standing authorization missing or invalidated;
  6. launch-at-login unavailable or disabled while scheduling remains enabled;
  7. scheduling paused, transient retry active, or freshness overdue; and
  8. healthy.
- A partial prior result remains prominent in operation history and recovery guidance, but it does not hide an earlier unmet prerequisite whose recovery action must occur first.

### APP-02 — Manual ordinary reconciliation and legacy cleanup

- Configured-readiness checks, ordinary dry runs, ordinary manual apply, and automatic ordinary apply use the shared ordinary access preflight defined in [`calendar-access-spec.md`](calendar-access-spec.md).
- The app exposes **Dry Run Sync** and **Run Sync Now** separately from all-calendar inventory. Migration pending disables both ordinary actions.
- **Run Sync Now** is a manual mutation flow. It loads fresh configuration and calendar state, presents the resulting aggregate create/delete summary, and requires explicit confirmation for that exact deterministic ordered ordinary plan. The aggregate presentation is not required to expose per-action order.
- Immediately before a confirmed manual mutation begins, the app repeats configuration loading, validation, ordinary preflight, snapshot loading, and planning. If the ordered executable-action sequence differs from the reviewed plan, it performs no mutation and requires review and confirmation of the fresh aggregate summary, including when aggregate counts remain unchanged. Rationale-only changes with identical ordered executable actions do not invalidate confirmation.
- When `legacyMarkers` is nonempty, the app explains that ordinary reconciliation is blocked and exposes a separate legacy-cleanup dry-run and apply workflow using the cleanup range, planning, preflight, verification, and local point-in-time semantics owned by the other capability specifications.
- Legacy-cleanup dry run presents the cleanup range, deletion counts, and one transient review row in execution order for every selected event containing its title, configured role, and start/end or all-day date range.
- Legacy-cleanup apply requires a successful fresh cleanup dry run and explicit confirmation for that exact detailed deterministic cleanup plan.
- Immediately before cleanup deletion begins, the app reloads configuration and calendar state and recomputes the ordered plan. Any executable-action or order change invalidates the prior confirmation and requires a new execution-ordered review; rationale-only changes with identical ordered actions do not. An unchanged plan still receives a fresh complete cleanup preflight before its first deletion.
- App cleanup review omits EventKit event and calendar IDs, source/title selectors, calendar titles, and marker values. Event titles, configured roles, and time ranges are displayed only transiently for review and are never persisted or written to logs.
- Scheduling authorization never authorizes cleanup. The app never combines cleanup with ordinary reconciliation and never removes or rewrites `legacyMarkers`; after verified cleanup, the developer removes tombstones from YAML when migration is complete for their topology.

### APP-03 — Setup and standing authorization for automatic mutation

- Scheduled reconciliation is disabled before setup. Setup is not complete until the user first enables it through the required authorization flow.
- First enablement requires a present and structurally valid non-migration-pending configuration, full Calendar access, complete configured-topology readiness, and a successful ordinary dry run.
- The app presents the dry-run create/delete summary and explains the automatic triggers before obtaining explicit standing authorization for future gated ordinary apply runs.
- Standing authorization covers automatic ordinary reconciliation initiated by launch, wake, the fixed timer, or bounded retry. These automatic runs do not require per-run confirmation.
- Standing authorization is bound to the ordinary configuration mutation identity, reconciliation-policy version, and resolved-topology identity defined in [`configuration-spec.md`](configuration-spec.md). A mutation-relevant configuration or work-calendar declaration-order change, policy version change, physical calendar identity change, or unproven EventKit calendar continuity suspends automatic mutation until a new successful dry run is reviewed and the user renews authorization.
- Invalid configuration, migration pending, unavailable full access, failed configured-topology readiness, or an in-flight selected-file change suppresses automatic mutation. The last previously valid settings are never used as a fallback for mutation.
- The user may pause scheduled reconciliation after setup. A pause is an intentional degraded state with a persistent warning that CalRelay is not maintaining freshness.
- Enabling scheduling also enables launch-at-login. Pausing scheduling leaves launch-at-login enabled until the user changes it separately. Disabling launch-at-login while scheduling remains enabled is allowed but visibly degrades post-login freshness.
- Automatic standing authorization does not replace the confirmation required by the separate manual **Run Sync Now** or legacy-cleanup apply flows.

### APP-04 — Freshness, triggers, retry, and overlap

- While scheduling is enabled, the app process is running, configuration and access remain healthy, migration is not pending, and standing authorization matches the current configuration, policy, and resolved topology, CalRelay targets an ordinary successful reconciliation in every rolling 60-minute period, including while the control panel is closed.
- Automatic reconciliation uses a fixed 15-minute timer cadence; the interval is not user configurable.
- Every launch and every wake triggers an ordinary run promptly when scheduling is enabled, regardless of the previous run time. All ordinary gates still apply before mutation.
- Every manual or automatic run reloads and structurally validates the selected configuration before Calendar access. External selected-file changes also trigger a prompt configuration-status refresh.
- If the selected file changes after a run loads it but before the first mutation, the run aborts without mutation, refreshes status, and follows the configuration-change authorization rules in [`configuration-spec.md`](configuration-spec.md).
- Ordinary and cleanup runs never overlap. Any automatic or manual triggers received during an active run coalesce into at most one follow-up run that reloads configuration and repeats validation, applicable preflight, snapshot loading, and planning. Coalescing does not broaden any trigger's mutation authorization.
- This no-overlap rule covers triggers coordinated inside the app process only. The app does not acquire a cross-process lock against CLI apply, and later reconciliation repairs any duplicate or missing projection caused by concurrent processes as defined in [`reconciliation-spec.md`](reconciliation-spec.md).
- A transient automatic-run failure receives a finite series of bounded-backoff retries. Retry attempts use fresh configuration, preflight, snapshots, and plans; they never resume an old or partially applied plan.
- A partially applied manual ordinary run does not authorize a retry. The app reports the partial result, and another manual attempt requires a fresh plan, review, and confirmation. Independently enabled standing automation may later repair the visible set only through its normal fresh-run authorization and trigger rules.
- Failures requiring user action do not enter an aggressive retry loop. They remain actionable through the primary and secondary state model, while later ordinary lifecycle or timer triggers may re-evaluate the gates.
- Freshness is overdue when scheduling is enabled and more than 60 minutes have elapsed since the latest successful ordinary reconciliation. Retry and overdue states are distinct and may coexist.
- A ready ordinary run with a successful fresh snapshot and an empty plan counts as a successful reconciliation for freshness and last-success state. A mutating ordinary run counts as successful after every ordered action is confirmed; no post-apply verification read is required.
- A valid deterministic plan is authoritative regardless of action count. Automatic reconciliation does not add heuristic mutation-count limits or anomaly thresholds.
- EventKit change notifications are not reconciliation triggers in this milestone. Adding them requires a later explicit decision covering debounce, feedback-loop protection, coalescing, and observable benefit.

### APP-05 — Operational visibility, persistence, and user notification

- The control panel shows scheduling and launch-at-login state, standing-authorization state, last attempt, last success, next nominal timer run, active retry state, latest result or failure category, create/delete counts, and whether freshness is overdue.
- Persist only the latest privacy-safe operational metadata needed across relaunch: attempt and success timestamps, result or failure category, and aggregate mutation counts. Do not persist raw configuration, calendar names, source/title selectors, marker values, EventKit IDs, event titles, event details, or EventKit object dumps.
- Setup requests macOS user-notification permission for overdue freshness and failures requiring user action. Denial does not block scheduling.
- The menu bar item reflects operational health while the control panel is closed. Its indicator and accessible description distinguish normal operation from a state requiring attention without relying on color alone; opening its menu exposes privacy-safe scheduling and recovery status consistent with the control panel. Paused or disabled scheduling is identified as not maintaining freshness rather than presented as healthy automatic synchronization. Status that has not yet been checked is not presented as healthy.
- Persistent in-app degraded state and menu bar attention status remain available independently of notification permission, with menu visibility subject to the user's macOS setting. Recovering from an attention state updates both surfaces; no Dock badge is required. A menu indicator alone is not sufficient active alerting when a problem is alert-worthy.
- Menu bar presentation uses only privacy-safe operational state and generic recovery categories. It does not expose calendar names, event titles, selectors, marker values, raw configuration, or EventKit IDs.
- Human-facing macOS notifications are distinct from EventKit change notifications. User alerts are reserved for overdue freshness and actionable recovery rather than every failed attempt.
- For a newly alert-worthy problem arising after startup, send a macOS user notification when notifications are available; do not also open the control panel automatically. When notifications are unavailable or notification submission reports failure, automatically open or focus the control panel with the actionable state. This fallback applies whether or not the menu bar item is hidden and does not itself request Calendar access or authorize mutation. Coalesce repeated presentation of the same unresolved problem rather than repeatedly stealing focus on each status refresh. Transient failures undergoing bounded retries remain quiet unless they also meet the existing actionable-recovery or overdue-freshness criteria.
- A healthy automatic login launch keeps the control-panel window closed. A login launch with setup or recovery requiring user action opens the control panel.
- Explicit Quit warns that synchronization stops and availability may become stale until the next manual launch or login. Quitting does not disable scheduling or launch-at-login.

### APP-06 — Lifecycle boundary and deferred operation

- Scheduled reconciliation runs only while the menu bar app process is running. Closing its control panel leaves that process running; explicit Quit stops synchronization. The accepted lifecycle decision is recorded in [ADR 0006](../adr/0006-run-calrelay-as-a-menu-bar-app.md), which supersedes the Dock-visible shell decision in ADR 0001.
- Launch-at-login starts this same menu bar app and remains coupled to scheduling enablement under APP-03. A login-item registration failure is actionable and prevents the app from presenting automation as fully healthy. Healthy login launches keep the control panel closed under APP-05 while respecting the user's menu bar visibility setting.
- Sync after the app process has exited remains out of scope. Do not add a helper app, LaunchAgent, separate background service, or equivalent execution after Quit without a later explicit product decision and an ADR covering lifecycle, permissions, signing, packaging, rollback, and user trust. The running menu bar app with its control panel closed is within scope.
- Production distribution retains the bundle identifier `dev.owinter.CalRelay` and one stable Developer Team signing identity so compatible upgrades do not intentionally create a new Calendar-permission, persistence, or launch-at-login identity. Distribution artifact requirements are owned by [`distribution-spec.md`](distribution-spec.md).

## Compatibility and breaking changes

- Revision 9 makes system-controlled icon hiding explicit and preserves Spotlight access while the icon is hidden. Runtime actionable recovery and overdue freshness now use notification-first alerting with automatic panel recovery when notifications are unavailable, replacing reliance on a visible menu indicator alone. The existing startup recovery policy and mutation authority remain unchanged.
- Revision 8 deliberately removes Dock presence and replaces Dock-based reopening and warning status with the menu bar. Users access the existing control panel and Quit through the menu bar. Closing the window continues scheduling; Quit still stops it. This shell change does not change reconciliation policy, standing-authorization bindings, persisted preferences, Calendar permission ownership, configuration, or production identity and must not itself require renewed standing authorization. Revision 7 introduced the identity boundary below.
- Revision 7 makes the production bundle identifier and Developer Team signing identity explicit upgrade-compatibility boundaries; changing either requires a documented distribution migration.
- Revision 6 binds standing authorization to configuration identity, reconciliation-policy version, and opaque resolved-topology identity. The delete-first reconciliation policy invalidates authorization granted under the previous create-first policy, and unproven physical calendar identity churn requires renewed review.
- Revision 6 makes ordinary and cleanup confirmation compare ordered executable actions while retaining aggregate-only ordinary review and execution-ordered per-event cleanup review. Rationale-only changes do not invalidate confirmation.
- Revision 6 counts a ready empty ordinary plan as success, defines mutating ordinary success by confirmed ordered actions without post-apply verification, and keeps manual partial-failure recovery separately confirmed from automatic retry authorization.
- Revision 5 replaces aggregate-only app cleanup review with transient per-event title, configured-role, and time-range review while preserving exact fresh-plan confirmation and persistence privacy.
- Revision 5 clarifies that app trigger serialization does not serialize separate CLI processes.
- Revision 4 replaces configurable timer scheduling with a fixed 15-minute cadence and a 60-minute freshness target.
- Launch-at-login moves into the first credible automation milestone, while helper-based and closed-app operation remain deferred.
- Automatic ordinary mutation uses explicit configuration-, policy-, and topology-bound standing authorization; manual ordinary apply and cleanup retain exact ordered-plan confirmation.
- Legacy cleanup is no longer CLI-only: the app adds an explicit cleanup dry-run/apply surface without changing cleanup semantics or automatically editing YAML.
- EventKit-triggered reconciliation remains deferred. Revision 8 brings the menu bar surface into scope.
- Existing Calendar prompt ownership, inventory/readiness separation, migration hard block, and no-rollback behavior remain unchanged.

## Implementation freedoms

- The exact transient-failure categories, retry delays, retry cap, and retry reset mechanics are implementation choices provided retries remain finite, use bounded backoff, never reuse stale plans, and support the freshness and notification outcomes above.
- The authorization identities' hash, encoding, storage API, policy-version representation, and file-observation mechanism are implementation choices provided they satisfy the semantic-equivalence, invalidation, topology-binding, and privacy requirements in [`configuration-spec.md`](configuration-spec.md).
- Status labels, explanatory wording, layout, and secondary-issue ordering are presentation choices. The dependency-ordered primary recovery action and semantic distinctions in this specification are stable contracts.
- The concrete macOS launch-at-login registration API and user-notification API are implementation choices. The lifecycle boundary, failure visibility, and permission fallback behavior are stable contracts.
- Menu bar framework, symbol, layout, and exact status wording are implementation choices subject to APP-01 and APP-05. These freedoms do not authorize a helper, LaunchAgent, EventKit-triggered reconciliation, or execution after the app exits.

## Constraints

- Preserve bundle identifier `dev.owinter.CalRelay` unless an explicit migration is approved.
- Keep SwiftUI views, AppKit handlers, delegates, lifecycle callbacks, notification callbacks, and login-item callbacks thin. Reusable orchestration belongs in application use cases or explicit app composition, and EventKit access remains behind adapters.
- Keep the app on the canonical single-profile configuration model. Do not add a visual YAML editor or a remembered alternate configuration path without an explicit decision.
- Do not persist sensitive calendar or configuration content to support status, authorization, or change detection.
- Do not add cron, EventKit-triggered reconciliation, a helper app, a LaunchAgent, a separate background service, automatic legacy cleanup, or automatic configuration editing without the relevant explicit decision.

## Acceptance checks

- **APP-AC-01:** The running app provides a menu bar item subject to the user's macOS visibility setting and has no Dock icon, including with the control panel open. Open CalRelay and an ordinary explicit launch or reopen open or focus the recoverable control panel without duplicates. A healthy login launch keeps the window closed while an actionable setup or recovery state opens it.
- **APP-AC-02:** Authorization-state tests prove that only the explicit Calendar setup/recovery action may prompt and that denied, restricted, write-only, revoked, and full-access states receive the required behavior.
- **APP-AC-03:** Inventory, configuration validity, configured readiness, migration state, authorization state, scheduling state, and operation results remain semantically distinct; simultaneous failures produce a dependency-ordered primary action plus all secondary issues.
- **APP-AC-04:** First scheduling enablement requires a successful ordinary dry run and explicit standing authorization bound to the current configuration mutation identity, reconciliation-policy version, and resolved-topology identity; a change to any binding suspends automation until review and renewal.
- **APP-AC-05:** Launch-at-login, launch, wake, fixed 15-minute cadence, one-hour overdue detection, bounded retry, pause, login-item degradation, and Quit warning follow `APP-03` through `APP-06`.
- **APP-AC-06:** Automatic runs never prompt for Calendar access or per-run mutation confirmation, never use a last-known-valid configuration fallback, and perform no mutation when any gate fails.
- **APP-AC-07:** Trigger-concurrency tests prove no overlap among app-owned triggers, at most one coalesced fresh follow-up run, and no reuse of stale configuration, preflight, snapshot, or plan data; the app makes no cross-process serialization claim.
- **APP-AC-08:** Manual ordinary apply recomputes before mutation, compares ordered executable actions including physical calendar and exact delete-occurrence identity, invalidates confirmation for executable or order changes even when the aggregate summary is unchanged, and tolerates rationale-only changes.
- **APP-AC-09:** Migration pending blocks ordinary manual and automatic reconciliation, while app cleanup uses the complete cleanup preflight, execution-ordered transient per-event exact-plan review, separate confirmation, post-apply verification, prohibited-detail omission, and no automatic YAML editing.
- **APP-AC-10:** Persisted operational state contains only the approved timestamps, categories, and counts. With notifications denied, scheduling remains available and menu bar attention status remains independent of notification permission. When the user allows the item to be visible, its accessible description communicates attention independently of color. Opening the menu shows privacy-safe status consistent with the panel, including paused, disabled, and unchecked states; recovery clears obsolete attention state on both surfaces. Active alerting follows APP-AC-18 even when the icon is hidden.
- **APP-AC-11:** Deterministic-plan size does not independently block automatic apply, and EventKit change notifications do not trigger reconciliation in this milestone.
- **APP-AC-12:** Enabling scheduling enables launch-at-login for the same menu bar app without a helper. With the control panel never opened during a healthy login launch, app startup and gated scheduled work still occur. Closing and reopening the panel leaves one scheduling lifecycle and configuration observer active. Quit uses the existing warning when scheduling is enabled, Cancel leaves the app running, and confirmed Quit stops synchronization without changing persisted scheduling or login preferences. Execution after the app exits remains absent.
- **APP-AC-13:** A ready empty ordinary plan updates freshness and last-success state; a mutating ordinary run succeeds after every ordered action is confirmed without a post-apply verification read.
- **APP-AC-14:** A partial manual ordinary failure requires a new fresh manual review and confirmation for manual recovery, while independently authorized scheduling may repair it only through a later normal fresh automatic run.
- **APP-AC-15:** Upgrade and topology tests invalidate standing authorization after a reconciliation-policy version change, work-calendar declaration-order change, physical calendar identity change, or unproven EventKit calendar continuity, without persisting raw configuration or calendar IDs.
- **APP-AC-16:** A compatible production upgrade retains bundle identifier `dev.owinter.CalRelay` and the established Developer Team signing identity; a change to either is handled as a documented distribution migration rather than an ordinary upgrade.
- **APP-AC-17:** Hiding the item in macOS Menu Bar settings leaves the app running and scheduling unchanged. With no Dock or menu bar icon, Spotlight launch or reopen opens or focuses one control panel and provides intentional Quit access with the existing warning. Closing the panel and relaunching do not override the user's hidden-icon setting; restoring visibility through macOS makes the item available again.
- **APP-AC-18:** For a new actionable or overdue problem after startup, fake notification availability selects notification-only presentation when available and control-panel opening when unavailable or submission fails, with either menu visibility setting. Repeated refreshes of the same unresolved problem do not repeatedly reopen or focus the panel; recovery followed by a new problem can alert again. A transient retry alone does not produce this interruption. Recovery presentation never prompts for Calendar access or confirms mutation; login recovery keeps its existing policy.

## Verification approach

- Run `make format-check`, `make check`, `make app`, and the fake-backed `make ui-test` lane according to [`../development.md`](../development.md).
- Add deterministic tests for state precedence, configuration/policy/topology authorization identity, configuration and topology invalidation, ordered stale confirmation, empty-plan freshness, manual partial-failure recovery, trigger coalescing, retry and overdue transitions, persistence privacy, and duplicate-run prevention.
- Add fake-backed UI coverage for menu status, accessible identification, opening/focusing/closing/reopening the panel, Quit cancellation, and notification-first versus panel-fallback recovery; retain manual sync and cleanup confirmation coverage. Use deterministic lifecycle coverage for hidden startup, repeated presentation without duplicate triggers, alert coalescing, and recovery followed by a new problem. Metadata tests alone do not prove runtime Dock absence, system-controlled icon hiding, Spotlight recovery, or notification behavior.
- Manually validate no Dock icon with the panel open and closed, menu bar accessibility and status, Calendar and user-notification permission flows, login launch, wake, unobtrusive healthy startup, actionable startup, Quit warning and cancellation, inventory/readiness separation, scheduling pause, configuration edits, migration cleanup, and menu bar fallback status in a built app bundle. Confirm window closure preserves scheduled operation and Quit ends the process.
- Manually hide and restore the item through macOS Menu Bar settings, verify Spotlight recovery and Quit access with both icons absent, and verify that hidden-icon launches do not restore the icon. Check notification-first runtime recovery and the automatic panel fallback when notifications are denied, separately from the existing actionable-login behavior.
- Do not use real calendar mutation as an ordinary automated check; use harmless dedicated calendars for explicit manual EventKit validation.
