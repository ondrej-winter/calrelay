# CalRelay validation

CalRelay's default local test gate is deterministic and does not require real Apple Calendar data. EventKit behavior depends on local Calendar state, permissions, and writable calendars, so capability checks use the built `CalRelay.app` bundle, which has its own stable macOS permission identity.

Run `make ui-test` before this checklist when app UI code changes. The fake-backed
suite already covers deterministic missing-configuration and unavailable-access
states, privacy-safe ready inventory and dry-run output, ordinary review
cancellation, cleanup review cancellation, and scheduled-sync authorization with
pause/resume. The manual checks below remain for real TCC transitions, EventKit
topology/read/write behavior, provider propagation, configuration-file
observation, login/wake/timer lifecycle, notifications, recurring events, and
actual harmless test-calendar mutation.

Use harmless test calendars before relying on CalRelay for real calendars.

The examples below use `--config calrelay.yml` as an explicit local validation fixture override. Everyday CLI usage defaults to `~/.config/calrelay/config.yaml`; see [`configuration.md`](configuration.md) for the canonical configuration location.

## Build and open the app

```sh
make app
open .build/CalRelay.app
```

Use **Set Up or Recover Calendar Access** to trigger the permission prompt for bundle identifier `dev.owinter.CalRelay`. It is the only CalRelay action allowed to prompt. After full access exists, use **Show Calendar Inventory** to confirm visible calendars without displaying EventKit IDs.

## Implemented Calendar access and readiness checks

1. Open `.build/CalRelay.app` and confirm CalRelay appears as a normal Dock-visible app with no CalRelay menu-bar item.
2. With Calendar access not determined, click **Set Up or Recover Calendar Access** and confirm the macOS full-access prompt appears for `dev.owinter.CalRelay`.
3. Deny or revoke access, refresh status, and confirm the app provides System Settings recovery guidance without prompting again. Repeat with write-only access if available and confirm it is treated as insufficient.
4. With restricted access, confirm the app explains that the restriction must be resolved outside CalRelay.
5. With full access, click the setup/recovery action again and confirm it verifies state without prompting.
6. Click **Show Calendar Inventory** and compare it with the calendars visible in Apple Calendar. Confirm source/account, title, and writable/read-only state are accurate without EventKit calendar IDs and without claiming configured readiness.
7. Remove or invalidate `~/.config/calrelay/config.yaml` while the app is open. Confirm the status refreshes automatically, configuration recovery becomes primary, configuration-dependent actions remain disabled, and no Calendar prompt appears.
8. Restore or atomically replace the file with a valid configuration. Confirm the app automatically reloads current status rather than requiring a manual refresh or using the prior settings.
9. Confirm readiness rejects real missing, ambiguous, physically colliding, unreadable, or read-only roles. Create several simultaneous failures and confirm every safely determinable issue is shown without event details or EventKit IDs.
10. With a ready non-migration configuration, click **Dry Run Sync** and compare aggregate counts with the fresh harmless test-calendar state. Confirm no mutation occurs and no event titles or EventKit IDs are displayed.
11. Run CLI inventory, config check, ordinary dry-run, explanation, and cleanup while access is unavailable. Confirm every command fails nonzero with app recovery guidance and none triggers a permission prompt.

Use only harmless dedicated calendars for steps that can mutate EventKit data.

## Implemented manual ordinary apply checks

Use only confirmed dedicated test calendars for these mutation checks. Do not replace an existing personal configuration just to run them.

1. Confirm an unchanged fresh plan and verify real EventKit delete-first execution and aggregate confirmed counts. Ordinary completion does not perform post-apply verification or imply immediate provider convergence.
2. Change an exact action, physical destination, occurrence, or order while the review is open. Confirm the old confirmation causes no mutation and a new review is required, even with identical counts. Rationale-only changes with identical executable actions do not require renewed confirmation.
3. Change mutation-relevant configuration during review, or invalidate/remove it before mutation. Confirm no stale configuration is used. A changed semantic identity requires fresh review even for an empty plan; comments and diagnostic role-name changes do not change mutation identity.
4. Cause a partial failure only on harmless test calendars. Confirm later actions stop, no rollback occurs, and recovery requires a new manual review. No per-event details are included in the partial result.
5. Confirm repeated clicks cannot start overlapping manual operations and a consumed confirmation cannot be reused.

## Implemented app automation checks

Use harmless dedicated calendars for all checks that can reach automatic mutation. The deterministic test gate covers orchestration and policy; these checks exercise macOS lifecycle, Login Items, notifications, Dock state, and the built app bundle.

1. Grant standing authorization. Confirm CalRelay requests user-notification permission, enables launch-at-login for the normal Dock-visible app, queues a fresh launch attempt, and shows scheduling, login-item, authorization, attempt/success, outcome/count, next-run, retry, and freshness state separately.
2. Deny user-notification permission. Confirm scheduling remains enabled and actionable recovery or overdue freshness remains visible in the control panel and through the Dock badge. Grant permission separately and confirm only actionable recovery or overdue freshness—not every failed attempt—produces a notification.
3. With scheduling enabled, validate a fresh attempt at every app launch and Mac wake, the fixed 15-minute timer cadence, and fresh bounded retries after 1, 5, and 15 minutes for transient failures or partial automatic mutation. Confirm repeated triggers during active work produce at most one later fresh attempt and never overlap manual or cleanup work.
4. Pause scheduling and confirm real timers/retries stop, launch-at-login remains unchanged, and no automatic launch attempt runs. Resume with valid standing authorization and confirm a fresh automatic attempt is queued; invalidate authorization and confirm resume is rejected until a new review.
5. Disable or require approval for CalRelay in **System Settings > General > Login Items** while scheduling remains enabled. Click **Refresh Status** and confirm the login-item row, primary recovery state, and Dock attention update together. Use **Enable Launch at Login** and confirm all three surfaces refresh again.
6. With scheduling enabled, choose **Quit** and confirm the warning explains that synchronization stops while the normal app is not running. Cancel once, then quit and confirm scheduling and authorization remain persisted for the next launch.
7. Relaunch and confirm a fresh automatic attempt runs only when scheduling is enabled and authorization remains valid. Confirm configuration, policy, or physical-topology changes invalidate authorization before mutation.
8. Confirm successful empty and mutating automatic runs update last success, while blocked or failed runs do not. Exhaust bounded retries and confirm the retry state stops and actionable recovery remains visible.
9. Perform an actual login launch with a healthy authorized fixture. Confirm the Dock-visible app process starts, automatic reconciliation runs, and the control-panel window remains closed when the resulting state is healthy or has a bounded retry pending.
10. Repeat an actual login launch with one safe actionable condition at a time, such as paused scheduling, a missing or invalid canonical configuration, revoked Calendar access, invalidated standing authorization, migration pending, an exhausted transient/partial failure, or overdue freshness. Confirm the control panel opens and becomes active with the dependency-ordered recovery state. Restore the healthy fixture between cases.
11. After a healthy hidden login launch, click the CalRelay Dock icon and confirm the control panel opens. Quit and use `open .build/CalRelay.app`; confirm an ordinary Finder/Dock-style launch presents the control panel immediately rather than applying login-item suppression.

Record the tested macOS version, app build identity, exact login transition used, and pass/fail outcome without calendar names, event titles, identifiers, configuration contents, or other personal data. Actual login-item delivery and window behavior remain manual-only lifecycle evidence; the deterministic suite covers the presentation policy separately.

## Configuration-change and confirmation checks

1. Open an ordinary or cleanup review, then edit, atomically replace, remove, or recreate the selected YAML file. Confirm the review closes, its confirmation can no longer be used, configuration-dependent controls become stale immediately, and status reloads from the current file without prompting for Calendar access.
2. Change the file while a dry run, review load, confirmation, or cleanup operation is active. Confirm the active operation is not interrupted mid-mutation, repeated file events coalesce, and exactly one fresh status recovery follows completion. Confirm any newly returned review is invalidated before it can be confirmed.
3. Make the YAML missing, invalid, or migration pending. Confirm the app never continues with the last valid in-memory settings.
4. Start a manual ordinary apply from a reviewed plan, change an executable action, exact target, or action order before confirmation completes, and confirm the changed fresh plan invalidates confirmation even when create/delete counts remain equal. Change only causal links or reason classifications while keeping the ordered executable actions identical and confirm that rationale-only change does not invalidate confirmation.
5. Make a YAML-only formatting change that preserves validated mutation semantics. Confirm status refreshes without requiring renewed authorization.
6. Change a configured selector, current or personal marker, `syncWindowDays`, legacy-marker set, or `workCalendars` declaration order. Confirm automatic mutation stops and a new dry run plus renewed standing authorization is required.
7. Change the selected file after an automatic run loads it but before its first mutation. Confirm the run aborts without mutation and refreshes status.
8. Replace or recreate one configured test calendar so the same source/title selector resolves to a different EventKit calendar identity. Confirm automatic mutation stops and renewed dry-run review and standing authorization are required even though the selector text is unchanged.
9. Simulate an app upgrade whose reconciliation-policy version changes. Confirm standing authorization granted under the previous policy is not reused.
10. Confirm a large but valid deterministic plan is not blocked solely by a mutation-count threshold.

## Basic MVP checks

1. Open `CalRelay.app`, click **Refresh Status**, and confirm configuration validity, full Calendar access, and complete configured readiness are distinct. Click **Show Calendar Inventory** separately and confirm the hub/work calendars are visible and writable where needed without EventKit IDs.
2. Check the selected configuration and complete configured-topology readiness:

   ```sh
   swift run calrelay config check --config calrelay.yml
   ```

   Confirm success reports the selected path and that the complete configured topology is currently ready.

3. Run dry-run and inspect the ordered plan. Confirm action rows appear as hub deletes, declaration-ordered work-calendar deletes, hub creates, and declaration-ordered work-calendar creates, with earlier event intervals before later ones inside each calendar:

   ```sh
   swift run calrelay reconcile --config calrelay.yml
   ```

4. Run the non-mutating full explanation:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --explain
   ```

   Confirm it reports the same effective window and ordered executable actions as dry-run, including every input event's eligibility, routing/source treatment, and existing-state disposition. Confirm planned creates cite every causal source event ID, planned deletes identify the exact selected occurrence and reason, and IDs appear only on successful explanation output. Revoke access or use a failing configuration and confirm the command returns nonzero on standard error without a partial explanation or IDs on standard output.

5. Run apply and confirm success is based on confirmation of every ordered mutation without a post-apply verification claim. After the provider exposes the confirmed mutations to a fresh read, run dry-run again and confirm it reports no changes. If an immediate read still exposes stale state, record the provider lag and allow later fresh reconciliation to converge rather than treating immediate no-change output as required:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --apply
   swift run calrelay reconcile --config calrelay.yml
   ```

6. Rename or move a source event and confirm dry-run shows delete-old plus create-new projection.
7. Create a representative double-booking scenario across at least two work calendars and confirm blockers are projected through the hub within the effective window.
8. Confirm a title such as `[A] Planning` is recognized only as marker `[A]`, while `[ACME] Planning` is not misclassified as `[A]`.
9. Confirm an empty or surrounding-whitespace source title is projected with trimmed text or `(Untitled)` and exactly one space after the marker.
10. Run against a ready snapshot requiring no actions and confirm the empty plan is a successful reconciliation that updates app freshness and last-success state without mutation.

## Projection and safety checks

Use harmless dedicated calendars and representative test events for these checks.

1. Create attendee invitations for the current user with accepted, tentative, declined, pending, and another non-accepted response. Confirm only the accepted invitation is eligible, regardless of whether its availability is busy, free, or tentative.
2. Confirm another attendee's tentative or declined response does not exclude an event accepted by the current user.
3. Create events with no current-user attendee record and representative availability values. Confirm busy, not-supported, and unavailable values are included, while free, tentative, and unknown values are skipped.
4. Repeat representative eligibility cases with all-day events. Confirm eligible events retain EventKit's returned start/end values and all-day flag in every projection.
5. Create events crossing the effective-window start and end. Confirm any positive-duration overlap is included with the complete original interval, while an event ending exactly at the start or beginning exactly at the end is excluded.
6. Confirm projected source titles appear unchanged apart from trimming, `(Untitled)` substitution, and marker addition. Use non-sensitive placeholders because titles cross account boundaries.
7. Inspect generated projections in each provider. Record whether the provider's default availability blocks time; CalRelay does not explicitly set projection availability.
8. Create a non-cancelled valid marked hub event whose availability is free or tentative. Confirm it still routes as an authoritative blocker. Mark or expose it as cancelled and confirm it is preserved according to ownership but no longer routes.
9. Create a manually authored event with a current local work marker in the hub and a valid marker in a configured work calendar. Confirm dry-run shows the documented reserved-namespace ownership risk; do not apply against real data.
10. Create two or more exact managed duplicates for one expected key. Confirm dry-run orders deletion of every existing duplicate before one replacement create, and confirm apply deletes every duplicate before attempting the replacement.
11. Remove or rename a work source while its local hub projection remains visible. Confirm one dry run plans removal of the stale hub projection and its downstream work blockers without relaying the stale hub event for an extra cycle.
12. Cause the first create to fail in a harmless fixture or fake-backed manual harness whose plan also contains deletes and later creates. Confirm every earlier ordered delete was attempted first, the failed create stops all later actions, confirmed deletes are not rolled back, and the result warns that expected blockers may remain missing until a later successful reconciliation.
13. Edit a marked event after planning but before deletion in a controlled test. Confirm the documented plan-time authorization behavior: apply may still delete the exact planned occurrence without reauthorizing its changed visible fields.
14. Delete an exact planned target through a concurrent harmless process before CalRelay reaches it. Confirm CalRelay treats the absent occurrence as a strict mutation failure, does not infer idempotent success, and attempts no later actions.
15. After a partial manual ordinary failure, confirm another manual recovery attempt requires a fresh plan, review, and confirmation. If standing automation is independently enabled, confirm it may later repair state only through a normal fresh automatic run.

## Multi-computer topology check

1. Inventory every active CalRelay configuration sharing the hub and confirm every current work and personal marker is globally unique.
2. Confirm no physical work calendar is actively managed by more than one computer and the machines' configured work-calendar sets are disjoint.
3. Document that CalRelay cannot verify these cross-computer invariants and that violating them can suppress, duplicate, or delete blockers.
4. If testing concurrent processes on harmless calendars, run app and CLI apply concurrently and confirm neither claims atomic isolation; use a later fresh dry run to observe and repair any temporary duplicate or missing projection.

## Marker migration cleanup check

Use only harmless, dedicated test calendars. Cleanup is a broad deletion workflow and must not be tested against calendars containing real events.

1. Confirm the marker is retired from every current work and personal role in every active configuration sharing the test hub, then add a valid unused marker such as `[RETIRED_TEST]` to `legacyMarkers` in the local validation fixture.
2. Create representative `[RETIRED_TEST] Example` events in the test hub and each configured test work calendar.
3. Run config check and confirm it completes ordinary topology preflight, reports migration pending, returns nonzero, and does not claim readiness:

   ```sh
   swift run calrelay config check --config calrelay.yml
   ```

4. Confirm ordinary reconciliation and explanation fail safely with guidance to run cleanup:

   ```sh
   swift run calrelay reconcile --config calrelay.yml
   swift run calrelay reconcile --config calrelay.yml --explain
   ```

5. Preview the cleanup-only plan and confirm it reports local dates `D - 2` through `D + 365`, uses positive-overlap membership, selects only exact `[RETIRED_TEST]` marker matches, and plans no creates. Confirm the summary lists every configured role, including roles with zero matches, with per-role and total selected-deletion counts. Confirm each transient review row shows the selected event's title, configured role, and time or all-day range without EventKit IDs, selectors, calendar titles, or marker values, and that rows follow hub-first then declaration-ordered work-calendar execution order:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --cleanup-legacy
   ```

6. Apply only after reviewing the plan. Confirm direct CLI `--apply` shows the fresh detailed plan and proceeds non-interactively without requiring proof of the earlier dry run:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --cleanup-legacy --apply
   ```

7. Confirm apply reports success only after a complete bounded-range verification snapshot, states that the result is local and point-in-time, and directs you to remove the tombstone manually only after migration is complete for the topology. Then run cleanup dry-run again and confirm it reports no local matches without claiming global or historical marker retirement.
8. Create a matching event older than `D - 2` and confirm cleanup makes no claim to cover or remove it.
9. Create a historical malformed title shape that cannot satisfy the current exact marker grammar and confirm cleanup does not select it; remove it manually from the harmless test calendar.
10. Remove `[RETIRED_TEST]` from `legacyMarkers`, run config check, and confirm ordinary readiness can succeed again.

### Implemented app cleanup checks

Validate this separate review/confirmation flow using confirmed dedicated test calendars and the canonical configuration. Do not replace an existing personal configuration merely to exercise the UI. Full-access live acceptance remains an explicit operator check; deterministic tests are not evidence of real EventKit deletion or provider convergence.

1. Click **Dry Run Legacy Cleanup** and compare the cleanup range, deletion count, configured roles, titles, and time/all-day ranges with the real harmless test-calendar state. IDs, selectors, calendar titles, and explicit marker values must be absent.
2. Confirm **Run Legacy Cleanup…** requires **Confirm Legacy Cleanup** before any real EventKit deletion. Other app operations remain blocked during review and apply; repeated clicks must not overlap deletion.
3. Change an exact target, occurrence, physical calendar, action order, cleanup range, or mutation-relevant configuration before confirmation. Confirm the old authorization performs no deletion and a fresh ordered review is required, even when counts match. Changes that leave the ordered executable actions and configuration identity unchanged do not require reconfirmation.
4. Invalidate or remove the selected file after snapshot loading but before deletion. Confirm every deletion is prevented and the stale confirmation cannot be reused. A later attempt requires a fresh review.
5. Apply only against harmless test calendars and confirm success requires the complete post-mutation bounded-range verification snapshot, including for an empty plan. Success remains local and point-in-time, not proof of global or historical retirement.
6. Cause a partial deletion failure, verification read failure, or remaining verification match on harmless test calendars. Confirm the result is unsuccessful, preserves confirmed deletion counts, omits event details and raw errors, and never rolls back, retries automatically, or deletes newly found matches in that run. Recovery requires refresh and a new review/confirmation.
7. Relaunch and confirm transient review content is not restored or logged.
8. Confirm the app does not edit YAML or enable ordinary sync after cleanup; remove the tombstone manually only after the topology's migration is complete, then refresh status.

## Recurring-event capability check

Recurring-event behavior depends on how EventKit exposes occurrences for the locally configured calendars. A successful EventKit snapshot is authoritative only for that run. CalRelay does not copy recurrence rules or independently prove completeness; it reconciles each returned occurrence, including detached edits, as an ordinary visible event snapshot.

To validate recurring-event behavior with harmless test calendars:

1. Create a short recurring timed event in one configured work calendar, such as a daily or weekly event with two or three future occurrences inside `syncWindowDays`.
2. Run dry-run:

   ```sh
   swift run calrelay reconcile --config calrelay.yml
   ```

3. Confirm the dry-run output includes one planned created projection per returned occurrence, with the expected configured prefix.
4. Run apply only after reviewing the dry-run output:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --apply
   ```

5. After the provider exposes the confirmed occurrence projections to a fresh read, run dry-run again and confirm it reports no changes. Do not require an immediate post-apply read to converge.
6. Edit one occurrence independently and confirm CalRelay projects the detached occurrence using its returned edited fields.
7. On a harmless recurring marked test event, select one occurrence for ordinary or cleanup deletion and confirm only that exact occurrence is removed. If the exact occurrence cannot be resolved, confirm the run fails without deleting the first occurrence or the whole series.
8. If only the first occurrence appears, no occurrences appear, or EventKit returns a shape that does not converge after apply, treat recurring-event support for that calendar source as unvalidated and keep using one-off events for critical blockers until the behavior is investigated.
