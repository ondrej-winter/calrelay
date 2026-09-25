# Spec: macOS App Controls and Automation

## Specification record

- **Status:** Accepted.
- **Revision:** 7 — accepted on September 25, 2026 with the Homebrew distribution contract; the production app identity was made an explicit upgrade-compatibility requirement.
- **Acceptance basis:** The product interviews approved on September 16, 2026 prioritize reliably accurate relayed availability with minimal ongoing user effort for a developer who is comfortable editing YAML; when partial failure cannot avoid both harms, stale over-blocking is removed before replacement blockers are created. The project owner approved the production distribution identity boundary on September 25, 2026.
- **Canonical artifact:** `docs/specs/macos-app-spec.md`.
- **Scope:** The Dock-visible control panel, manual ordinary reconciliation, explicit legacy cleanup, scheduled reconciliation while the normal app is running, launch-at-login, operational status, user notifications, and lifecycle boundaries.

## Required outcomes

### APP-01 — Recoverable control panel and operational state

- `CalRelay.app` remains a normal Dock-visible app. Its main window is the primary surface for setup, Calendar permission, all-calendar inventory, configuration status, configured readiness, scheduling, migration recovery, and operation results.
- The first credible automation milestone does not include a menu-bar item. Users open or focus the normal app through standard macOS surfaces.
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

- While scheduling is enabled, the normal app is running, configuration and access remain healthy, migration is not pending, and standing authorization matches the current configuration, policy, and resolved topology, CalRelay targets an ordinary successful reconciliation in every rolling 60-minute period.
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
- When user notifications are unavailable, persistent in-app degraded state plus a Dock badge or equivalent visible app indicator provides the fallback.
- Human-facing macOS notifications are distinct from EventKit change notifications. User alerts are reserved for overdue freshness and actionable recovery rather than every failed attempt.
- A healthy automatic login launch keeps the control-panel window closed. A login launch with setup or recovery requiring user action opens the control panel.
- Explicit Quit warns that synchronization stops and availability may become stale until the next manual launch or login. Quitting does not disable scheduling or launch-at-login.

### APP-06 — Lifecycle boundary and deferred operation

- Scheduled reconciliation runs only while the normal Dock-visible app process is running. The accepted lifecycle decision is recorded in [`../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md`](../adr/0001-launch-normal-app-at-login-for-scheduled-sync.md).
- Launch-at-login for the normal app is part of this milestone. A login-item registration failure is actionable and prevents the app from presenting automation as fully healthy.
- Sync while the normal app process is closed remains out of scope. Do not add a helper app, LaunchAgent, background-only mode, or equivalent closed-app execution without a later explicit product decision and an ADR covering lifecycle, permissions, signing, packaging, rollback, and user trust.
- Production distribution retains the bundle identifier `dev.owinter.CalRelay` and one stable Developer Team signing identity so compatible upgrades do not intentionally create a new Calendar-permission, persistence, or launch-at-login identity. Distribution artifact requirements are owned by [`distribution-spec.md`](distribution-spec.md).

## Compatibility and breaking changes

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
- EventKit-triggered reconciliation and the optional menu-bar surface are deferred from the first automation milestone.
- Existing Calendar prompt ownership, inventory/readiness separation, migration hard block, and no-rollback behavior remain unchanged.

## Implementation freedoms

- The exact transient-failure categories, retry delays, retry cap, and retry reset mechanics are implementation choices provided retries remain finite, use bounded backoff, never reuse stale plans, and support the freshness and notification outcomes above.
- The authorization identities' hash, encoding, storage API, policy-version representation, and file-observation mechanism are implementation choices provided they satisfy the semantic-equivalence, invalidation, topology-binding, and privacy requirements in [`configuration-spec.md`](configuration-spec.md).
- Status labels, explanatory wording, layout, and secondary-issue ordering are presentation choices. The dependency-ordered primary recovery action and semantic distinctions in this specification are stable contracts.
- The concrete macOS launch-at-login registration API and user-notification API are implementation choices. The lifecycle boundary, failure visibility, and permission fallback behavior are stable contracts.
- These implementation freedoms do not authorize a helper, LaunchAgent, menu-bar item, EventKit-triggered reconciliation, or closed-app execution.

## Constraints

- Preserve bundle identifier `dev.owinter.CalRelay` unless an explicit migration is approved.
- Keep SwiftUI views, AppKit handlers, delegates, lifecycle callbacks, notification callbacks, and login-item callbacks thin. Reusable orchestration belongs in application use cases or explicit app composition, and EventKit access remains behind adapters.
- Keep the app on the canonical single-profile configuration model. Do not add a visual YAML editor or a remembered alternate configuration path without an explicit decision.
- Do not persist sensitive calendar or configuration content to support status, authorization, or change detection.
- Do not add cron, EventKit-triggered reconciliation, a menu-bar item, a helper app, a LaunchAgent, background-only behavior, automatic legacy cleanup, or automatic configuration editing without the relevant explicit decision.

## Acceptance checks

- **APP-AC-01:** The Dock-visible app remains the recoverable primary control panel, and a healthy login launch stays unobtrusive while an actionable setup or recovery state opens the window.
- **APP-AC-02:** Authorization-state tests prove that only the explicit Calendar setup/recovery action may prompt and that denied, restricted, write-only, revoked, and full-access states receive the required behavior.
- **APP-AC-03:** Inventory, configuration validity, configured readiness, migration state, authorization state, scheduling state, and operation results remain semantically distinct; simultaneous failures produce a dependency-ordered primary action plus all secondary issues.
- **APP-AC-04:** First scheduling enablement requires a successful ordinary dry run and explicit standing authorization bound to the current configuration mutation identity, reconciliation-policy version, and resolved-topology identity; a change to any binding suspends automation until review and renewal.
- **APP-AC-05:** Launch-at-login, launch, wake, fixed 15-minute cadence, one-hour overdue detection, bounded retry, pause, login-item degradation, and Quit warning follow `APP-03` through `APP-06`.
- **APP-AC-06:** Automatic runs never prompt for Calendar access or per-run mutation confirmation, never use a last-known-valid configuration fallback, and perform no mutation when any gate fails.
- **APP-AC-07:** Trigger-concurrency tests prove no overlap among app-owned triggers, at most one coalesced fresh follow-up run, and no reuse of stale configuration, preflight, snapshot, or plan data; the app makes no cross-process serialization claim.
- **APP-AC-08:** Manual ordinary apply recomputes before mutation, compares ordered executable actions including physical calendar and exact delete-occurrence identity, invalidates confirmation for executable or order changes even when the aggregate summary is unchanged, and tolerates rationale-only changes.
- **APP-AC-09:** Migration pending blocks ordinary manual and automatic reconciliation, while app cleanup uses the complete cleanup preflight, execution-ordered transient per-event exact-plan review, separate confirmation, post-apply verification, prohibited-detail omission, and no automatic YAML editing.
- **APP-AC-10:** Persisted operational state contains only the approved timestamps, categories, and counts; human-notification denial leaves scheduling available with persistent in-app and Dock-visible fallback status.
- **APP-AC-11:** Deterministic-plan size does not independently block automatic apply, and EventKit change notifications do not trigger reconciliation in this milestone.
- **APP-AC-12:** The menu-bar item and closed-app synchronization remain absent; enabling scheduling enables launch-at-login for the normal app without introducing helper-based execution.
- **APP-AC-13:** A ready empty ordinary plan updates freshness and last-success state; a mutating ordinary run succeeds after every ordered action is confirmed without a post-apply verification read.
- **APP-AC-14:** A partial manual ordinary failure requires a new fresh manual review and confirmation for manual recovery, while independently authorized scheduling may repair it only through a later normal fresh automatic run.
- **APP-AC-15:** Upgrade and topology tests invalidate standing authorization after a reconciliation-policy version change, work-calendar declaration-order change, physical calendar identity change, or unproven EventKit calendar continuity, without persisting raw configuration or calendar IDs.
- **APP-AC-16:** A compatible production upgrade retains bundle identifier `dev.owinter.CalRelay` and the established Developer Team signing identity; a change to either is handled as a documented distribution migration rather than an ordinary upgrade.

## Verification approach

- Start implementation validation with `make check` and `make app`.
- Add deterministic tests for state precedence, configuration/policy/topology authorization identity, configuration and topology invalidation, ordered stale confirmation, empty-plan freshness, manual partial-failure recovery, trigger coalescing, retry and overdue transitions, persistence privacy, and duplicate-run prevention.
- Manually validate Calendar and user-notification permission flows, login launch, wake, unobtrusive healthy startup, actionable startup, Quit warning, inventory/readiness separation, scheduling pause, configuration edits, migration cleanup, and Dock-visible fallback status in a built app bundle.
- Do not use real calendar mutation as an ordinary automated check; use harmless dedicated calendars for explicit manual EventKit validation.