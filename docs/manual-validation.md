# CalRelay manual validation

CalRelay's default local test gate is deterministic and does not require real Apple Calendar data. EventKit behavior depends on local Calendar state, permissions, and writable calendars, so these checks must be run from a Terminal process that has Full Calendar access.

Use harmless test calendars before relying on CalRelay for real calendars.

## Basic MVP checks

1. Run `swift run calrelay calendars` and confirm the hub/work calendars are visible and writable where needed.
2. Run dry-run and inspect planned creates/deletes:

   ```sh
   swift run calrelay reconcile --config calrelay.yml
   ```

3. Run apply, then run dry-run again and confirm the second run reports no changes:

   ```sh
   swift run calrelay reconcile --config calrelay.yml --apply
   swift run calrelay reconcile --config calrelay.yml
   ```

4. Rename or move a source event and confirm dry-run shows delete-old plus create-new projection.
5. Create a representative double-booking scenario across at least two work calendars and confirm blockers are projected through the hub within the sync window.

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