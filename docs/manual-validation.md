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

This section describes manual acceptance checks for macOS App Specification Revision 4. Until that revision is implemented, record the checks as pending rather than interpreting missing controls as a validation pass.

1. Open `.build/CalRelay.app` and confirm CalRelay appears as a normal Dock-visible app with no CalRelay menu-bar item.
2. Confirm the main window distinguishes all-calendar inventory, configuration validity, configured readiness, migration state, standing authorization, scheduling, and latest operation status.
3. Complete a successful ordinary dry run, review its create/delete summary, and confirm scheduling cannot be enabled until explicit standing authorization is granted.
4. Enable scheduling and confirm launch-at-login is enabled for the normal app. Confirm the fixed cadence is 15 minutes and is not user configurable.
5. Log out and in with the app healthy. Confirm CalRelay launches without opening the main window and performs a gated ordinary run.
6. Repeat login with setup or recovery requiring action. Confirm the main window opens and presents the first dependency-ordered recovery action plus any secondary issues.
7. Wake the Mac and confirm one prompt gated run occurs regardless of the previous run time.
8. Trigger timer, wake, and manual actions during an active run. Confirm they do not overlap and coalesce into at most one follow-up run using fresh configuration, preflight, snapshots, and planning.
9. Cause a transient failure and confirm finite bounded-backoff retry state is visible. Confirm an actionable failure does not enter an aggressive retry loop.
10. Confirm more than 60 minutes since the latest successful ordinary reconciliation is shown as overdue and generates a user notification when allowed.
11. Deny user-notification permission and confirm scheduling remains available with persistent in-app degraded state plus a Dock badge or equivalent visible indicator.
12. Pause scheduling and confirm the warning persists. Confirm launch-at-login remains enabled until changed separately.
13. Disable launch-at-login while scheduling remains enabled and confirm automation is presented as degraded rather than healthy.
14. Choose Quit and confirm the app warns that synchronization stops and availability may become stale until the next manual launch or login.

Use only harmless dedicated calendars for steps that can mutate EventKit data.

## Configuration-change and confirmation checks

1. With scheduling authorized, make a YAML-only formatting change that preserves validated mutation semantics. Confirm status refreshes without requiring renewed authorization.
2. Change a configured selector, current or personal marker, `syncWindowDays`, or legacy-marker set. Confirm automatic mutation stops and a new dry run plus renewed standing authorization is required.
3. Make the YAML missing, invalid, or migration pending. Confirm the app never continues with the last valid in-memory settings.
4. Change the selected file after an automatic run loads it but before its first mutation. Confirm the run aborts without mutation and refreshes status.
5. Start a manual ordinary apply from a reviewed plan, change calendar state before confirmation completes, and confirm a changed fresh plan invalidates the confirmation even when create/delete counts remain equal.
6. Confirm a large but valid deterministic plan is not blocked solely by a mutation-count threshold.

## Basic MVP checks

1. Open `CalRelay.app`, click **List Calendars**, and confirm the hub/work calendars are visible and writable where needed.
2. Check the selected configuration and complete configured-topology readiness:

   ```sh
   swift run calrelay config check --config calrelay.yml
   ```

   Confirm success reports the selected path and that the complete configured topology is currently ready.

3. Run dry-run and inspect planned creates/deletes:

   ```sh
   swift run calrelay reconcile --config calrelay.yml
   ```

4. Run full explanation and confirm it reports the effective window, classifies every input event, and lists the same planned creates/deletes as dry-run with causal EventKit event and calendar IDs:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --explain
   ```

5. Run apply, then run dry-run again and confirm the second run reports no changes:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --apply
   swift run calrelay reconcile --config calrelay.yml
   ```

6. Rename or move a source event and confirm dry-run shows delete-old plus create-new projection.
7. Create a representative double-booking scenario across at least two work calendars and confirm blockers are projected through the hub within the effective window.
8. Confirm a title such as `[A] Planning` is recognized only as marker `[A]`, while `[ACME] Planning` is not misclassified as `[A]`.
9. Confirm an empty or surrounding-whitespace source title is projected with trimmed text or `(Untitled)` and exactly one space after the marker.

## Marker migration cleanup check

Use only harmless, dedicated test calendars. Cleanup is a broad deletion workflow and must not be tested against calendars containing real events.

1. Add a valid unused marker such as `[RETIRED_TEST]` to `legacyMarkers` in the local validation fixture.
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

5. Preview the cleanup-only plan and confirm it reports the September 15, 2026 through `D + 365` local-date range, selects only exact `[RETIRED_TEST]` marker matches, plans no creates, and does not expose EventKit IDs:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --cleanup-legacy
   ```

6. Apply only after reviewing the plan:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --cleanup-legacy --apply
   ```

7. Confirm apply reports success only after a full-range verification snapshot, then run cleanup dry-run again and confirm it reports no local matches without claiming global marker retirement.
8. Remove `[RETIRED_TEST]` from `legacyMarkers`, run config check, and confirm ordinary readiness can succeed again.

Repeat the migration with the accepted app cleanup surface:

1. Confirm migration pending blocks **Dry Run Sync**, **Run Sync Now**, and automatic reconciliation but exposes separate cleanup actions.
2. Run app cleanup dry-run and confirm it reports only the cleanup range and privacy-safe deletion counts, without event titles, details, IDs, selectors, calendar titles, or marker values.
3. Confirm cleanup apply requires separate confirmation for the exact fresh cleanup plan and is not authorized by scheduled-sync standing authorization.
4. Change the cleanup snapshot before mutation and confirm a changed fresh plan invalidates the prior confirmation.
5. Apply only against harmless test calendars and confirm success requires the complete post-mutation verification snapshot.
6. Confirm the app does not edit YAML; remove the tombstone manually only after the topology's migration is complete.

## Recurring-event capability check

Recurring-event behavior depends on how EventKit exposes occurrences for the locally configured calendars. CalRelay does not copy recurrence rules; it reconciles each occurrence that EventKit returns inside the configured sync window as an ordinary visible event snapshot.

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

5. Run dry-run again and confirm it reports no changes.
6. If only the first occurrence appears, no occurrences appear, or EventKit returns a shape that does not converge after apply, treat recurring-event support for that calendar source as unvalidated and keep using one-off timed events for critical blockers until the behavior is investigated.
