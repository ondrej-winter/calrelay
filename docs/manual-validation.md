# CalRelay validation

CalRelay's default local test gate is deterministic and does not require real Apple Calendar data. EventKit behavior depends on local Calendar state, permissions, and writable calendars, so capability checks use the built `CalRelay.app` bundle, which has its own stable macOS permission identity.

Use harmless test calendars before relying on CalRelay for real calendars.

The examples below use `--config calrelay.yml` as an explicit local validation fixture override. Everyday CLI usage defaults to `~/.config/calrelay/config.yaml`; see [`configuration.md`](configuration.md) for the canonical configuration location.

## Build and open the app

```sh
make app
open .build/CalRelay.app
```

Use the app's **List Calendars** button to trigger the Calendar permission prompt for bundle identifier `dev.owinter.CalRelay` and confirm visible calendars.

## App lifecycle and menu bar checks

1. Open `.build/CalRelay.app` and confirm CalRelay appears as a normal Dock-visible app.
2. Confirm the main window describes Calendar permission and visible-calendar checks, without sync, timer, or background reconciliation controls.
3. Confirm the CalRelay menu bar item is visible by default.
4. Open the menu bar item and choose **Open CalRelay**. Confirm the main app window opens or focuses.
5. In the app control panel, turn off **Show CalRelay in the menu bar** and confirm the menu bar item is removed.
6. Quit and reopen the app, then confirm the hidden menu bar preference persists.
7. Re-enable **Show CalRelay in the menu bar**, quit, reopen, and confirm the menu bar item returns.
8. Open the menu bar item and choose **Quit**. Confirm the app exits through the normal app lifecycle.

The menu bar item is intentionally UI-only. It must not start sync, schedule background work, listen for Calendar changes, or mutate calendars.

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
