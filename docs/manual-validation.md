# CalRelay validation

CalRelay's default local test gate is deterministic and does not require real Apple Calendar data. EventKit behavior depends on local Calendar state, permissions, and writable calendars, so capability checks use the built `CalRelay.app` bundle, which has its own stable macOS permission identity.

Use harmless test calendars before relying on CalRelay for real calendars.

The examples below use `--config calrelay.yml` as an explicit local validation fixture override. Everyday CLI usage defaults to `~/.config/calrelay/config.yaml`; see [`configuration.md`](configuration.md) for the canonical configuration location.

## Build and open the app

```sh
make app
open .build/CalRelay.app
```

Use the app's explicit Calendar access setup/recovery action to trigger the permission prompt for bundle identifier `dev.owinter.CalRelay`. After full access exists, use the separate all-calendar inventory to confirm visible calendars.

## Accepted app automation milestone checks

This section describes manual acceptance checks for macOS App Specification Revision 6. Until that revision is implemented, record the checks as pending rather than interpreting missing controls as a validation pass.

1. Open `.build/CalRelay.app` and confirm CalRelay appears as a normal Dock-visible app with no CalRelay menu-bar item.
2. Confirm the main window distinguishes all-calendar inventory, configuration validity, configured readiness, migration state, standing authorization, scheduling, and latest operation status.
3. Complete a successful ordinary dry run, review its create/delete summary, and confirm scheduling cannot be enabled until explicit standing authorization is granted.
4. Enable scheduling and confirm launch-at-login is enabled for the normal app. Confirm the fixed cadence is 15 minutes and is not user configurable.
5. Log out and in with the app healthy. Confirm CalRelay launches without opening the main window and performs a gated ordinary run.
6. Repeat login with setup or recovery requiring action. Confirm the main window opens and presents the first dependency-ordered recovery action plus any secondary issues.
7. Wake the Mac and confirm one prompt gated run occurs regardless of the previous run time.
8. Trigger timer, wake, and manual actions during an active run. Confirm app-owned triggers do not overlap and coalesce into at most one follow-up run using fresh configuration, preflight, snapshots, and planning. Confirm the app does not claim to serialize a separate CLI apply process.
9. Cause a transient failure and confirm finite bounded-backoff retry state is visible. Confirm an actionable failure does not enter an aggressive retry loop.
10. Confirm more than 60 minutes since the latest successful ordinary reconciliation is shown as overdue and generates a user notification when allowed.
11. Deny user-notification permission and confirm scheduling remains available with persistent in-app degraded state plus a Dock badge or equivalent visible indicator.
12. Pause scheduling and confirm the warning persists. Confirm launch-at-login remains enabled until changed separately.
13. Disable launch-at-login while scheduling remains enabled and confirm automation is presented as degraded rather than healthy.
14. Choose Quit and confirm the app warns that synchronization stops and availability may become stale until the next manual launch or login.

Use only harmless dedicated calendars for steps that can mutate EventKit data.

## Configuration-change and confirmation checks

1. With scheduling authorized, make a YAML-only formatting change that preserves validated mutation semantics. Confirm status refreshes without requiring renewed authorization.
2. Change a configured selector, current or personal marker, `syncWindowDays`, legacy-marker set, or `workCalendars` declaration order. Confirm automatic mutation stops and a new dry run plus renewed standing authorization is required.
3. Make the YAML missing, invalid, or migration pending. Confirm the app never continues with the last valid in-memory settings.
4. Change the selected file after an automatic run loads it but before its first mutation. Confirm the run aborts without mutation and refreshes status.
5. Start a manual ordinary apply from a reviewed plan, change an executable action, exact target, or action order before confirmation completes, and confirm the changed fresh plan invalidates confirmation even when create/delete counts remain equal. Change only causal links or reason classifications while keeping the ordered executable actions identical and confirm that rationale-only change does not invalidate confirmation.
6. Replace or recreate one configured test calendar so the same source/title selector resolves to a different EventKit calendar identity. Confirm automatic mutation stops and renewed dry-run review and standing authorization are required even though the selector text is unchanged.
7. Simulate an app upgrade whose reconciliation-policy version changes. Confirm standing authorization granted under the previous policy is not reused.
8. Confirm a large but valid deterministic plan is not blocked solely by a mutation-count threshold.

## Basic MVP checks

1. Open `CalRelay.app`, click **List Calendars**, and confirm the hub/work calendars are visible and writable where needed.
2. Check the selected configuration and complete configured-topology readiness:

   ```sh
   swift run calrelay config check --config calrelay.yml
   ```

   Confirm success reports the selected path and that the complete configured topology is currently ready.

3. Run dry-run and inspect the ordered plan. Confirm action rows appear as hub deletes, declaration-ordered work-calendar deletes, hub creates, and declaration-ordered work-calendar creates, with earlier event intervals before later ones inside each calendar:

   ```sh
   swift run calrelay reconcile --config calrelay.yml
   ```

4. Run full explanation and confirm it reports the effective window, classifies every input event, and lists the same ordered executable-action sequence as dry-run with causal EventKit event and calendar IDs:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --explain
   ```

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

5. Preview the cleanup-only plan and confirm it reports local dates `D - 2` through `D + 365`, uses positive-overlap membership, selects only exact `[RETIRED_TEST]` marker matches, plans no creates, and shows each selected event's title, configured role, and time or all-day range without EventKit IDs, selectors, calendar titles, or marker values. Confirm rows follow hub-first then declaration-ordered work-calendar execution order:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --cleanup-legacy
   ```

6. Apply only after reviewing the plan. Confirm direct CLI `--apply` shows the fresh detailed plan and proceeds non-interactively without requiring proof of the earlier dry run:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --cleanup-legacy --apply
   ```

7. Confirm apply reports success only after a complete bounded-range verification snapshot, then run cleanup dry-run again and confirm it reports no local matches without claiming global or historical marker retirement.
8. Create a matching event older than `D - 2` and confirm cleanup makes no claim to cover or remove it.
9. Create a historical malformed title shape that cannot satisfy the current exact marker grammar and confirm cleanup does not select it; remove it manually from the harmless test calendar.
10. Remove `[RETIRED_TEST]` from `legacyMarkers`, run config check, and confirm ordinary readiness can succeed again.

Repeat the migration with the accepted app cleanup surface:

1. Confirm migration pending blocks **Dry Run Sync**, **Run Sync Now**, and automatic reconciliation but exposes separate cleanup actions.
2. Run app cleanup dry-run and confirm it shows the cleanup range, counts, and a transient execution-ordered row for each selected event containing title, configured role, and time or all-day range, while omitting IDs, selectors, calendar titles, and marker values.
3. Confirm cleanup apply requires separate confirmation for the exact fresh detailed plan and is not authorized by scheduled-sync standing authorization.
4. Change the cleanup snapshot before mutation and confirm a changed fresh plan invalidates the prior confirmation.
5. Apply only against harmless test calendars and confirm success requires the complete post-mutation bounded-range verification snapshot.
6. Relaunch the app and inspect persistent status and logs. Confirm cleanup titles, roles, time ranges, IDs, and other event details were not persisted.
7. Confirm the app does not edit YAML; remove the tombstone manually only after the topology's migration is complete.

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
