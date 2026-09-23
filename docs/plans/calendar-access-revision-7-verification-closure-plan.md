# Calendar access revision 7 verification-closure plan

## Plan record

- **Status:** In progress; `CAV-01` through `CAV-04` are complete, and `CAV-05` is next.
- **Prepared:** September 22, 2026.
- **Canonical requirements:**
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/docs/specs/calendar-access-spec.md`,
  revision 7, accepted September 16, 2026.
- **Scope:** Remaining implementation and automated-verification work for the
  calendar-access contract only.
- **Out of scope:** Recreating the deleted historical
  `calendar-access-implementation-plan.md`; repeating completed scheduling,
  coordination, persistence, reconciliation, cleanup, or app-lifecycle work;
  manual EventKit or real-calendar acceptance; and changes to the accepted
  specification without a newly discovered contract conflict.
- **Readiness:** No unresolved product decision or implementation blocker is
  known. Current evidence indicates verification gaps rather than a known
  production behavior defect.

The canonical specification defines seven required outcomes, `ACCESS-01`
through `ACCESS-07`, and fifteen acceptance checks, `ACCESS-AC-01` through
`ACCESS-AC-15`. There are no `ACCESS-08` through `ACCESS-15` required outcomes.

## Change policy

This is a verification-closure plan. Add or strengthen automated tests before
changing production behavior. Production changes are permitted only when a new
test exposes a defect, except for the narrowly scoped deterministic
recurring-occurrence resolver refactor in `CAV-02`, which is justified to make
the existing EventKit-store zero/one/many resolution decision directly
testable.

Any production correction discovered by the planned tests must:

1. retain the failing regression test;
2. make the smallest change that fixes that failure;
3. preserve the accepted specification rather than reinterpret it;
4. remain within the existing hexagonal and vertical-slice boundaries; and
5. avoid unrelated cleanup or completed historical work.

## Status definitions

- **Directly tested:** Automated tests exercise the specified behavior and its
  observable result.
- **Partially direct:** Most of the behavior is directly tested, but a concrete
  surface or failure case remains uncovered.
- **Indirectly tested:** Architecture, capability separation, or another test
  path supports the behavior, but the exact surface is not asserted.
- **Uncovered:** No suitable automated assertion currently exercises the
  behavior.

## Required-outcome traceability

| Outcome | Implementation state | Automated-verification state | Remaining closure |
| --- | --- | --- | --- |
| `ACCESS-01` — Permission ownership and authorization states | Implemented | **Directly tested.** `CalendarAuthorizationTests` proves setup requests only for `.notDetermined`; `CalendarNoPromptContractTests` plus `CalendarAutomaticReconciliationTests` prove inventory, config check, ordinary CLI and app operations, cleanup, standing authorization, automatic ordinary runs, retries, and revocation never request; and `CalendarAppBundleMetadataTests` plus the guarded app build prove the production permission metadata remains present while the fake UI-test host remains permission-free. | None. |
| `ACCESS-02` — Calendar discovery | Implemented | **Directly tested.** Configuration-independent inventory, empty success, CLI IDs and writability, app ID omission, and separation from configured readiness are covered. | None; retain the existing tests. |
| `ACCESS-03` — Ordinary configured-topology readiness | Implemented | **Directly tested.** Shared preflight covers authorization, missing, ambiguous, colliding, unreadable, and read-only roles; ordered reads, aggregation, no-prompt behavior, and no-mutation gates are covered across reusable, CLI, manual-app, and automatic paths. | None; retain the existing tests. |
| `ACCESS-04` — Legacy-cleanup preflight | Implemented | **Directly tested.** Complete-range reads, all-role gating, no-prompt behavior, ordered verification, remaining-match failure, verification-read failure, no rollback, and exact recurring-occurrence resolution are covered. | None. |
| `ACCESS-05` — Failure after mutation begins | Implemented | **Directly tested.** Ordered confirmation, stop-on-first-failure, partial counts, no rollback, empty ordinary success, and no ordinary verification reread are covered. | None. |
| `ACCESS-06` — Privacy-safe diagnostics and cleanup review | Implemented | **Directly tested.** Sentinel-backed tests cover approved CLI inventory and explanation disclosure plus readiness, failure, cleanup, app, automatic-notification, and serialized-state denylists. | None. |
| `ACCESS-07` — EventKit boundary | Implemented | **Directly tested.** Opaque physical identities, ordered snapshots, reviewed-action identity, topology binding, and the deterministic exact-occurrence zero/one/many decision consumed by `EventKitCalendarStore` are covered. | None. |

## Acceptance-check traceability

| Acceptance check | Verification state | Existing automated evidence | Concrete remaining gap |
| --- | --- | --- | --- |
| `ACCESS-AC-01` | **Directly tested** | `CalendarAuthorizationTests`, `CalendarNoPromptContractTests`, `CalendarAutomaticReconciliationTests`, `CalendarAppBundleMetadataTests`, and the guarded app build | None. |
| `ACCESS-AC-02` | **Directly tested** | `CalendarAuthorizationTests`, `CalendarListCommandHandlerTests`, and `CalRelayContractTests` | None. |
| `ACCESS-AC-03` | **Directly tested** | `CalendarAccessPreflightTests`, `ConfigCheckCommandHandlerTests`, `ReconcileCommandHandlerTests`, `CalendarManualDryRunTests`, `CalendarManualApplyTests`, and `CalendarAutomaticReconciliationTests` | None. |
| `ACCESS-AC-04` | **Directly tested** | `ConfigCheckCommandHandlerTests` | None. |
| `ACCESS-AC-05` | **Directly tested** | `CalendarCleanupAccessTests`, `CalendarManualCleanupTests`, and `ReconcileCommandHandlerTests` | None. |
| `ACCESS-AC-06` | **Directly tested** | `CalendarAccessPreflightTests` and the manual and automatic preflight suites | None. |
| `ACCESS-AC-07` | **Directly tested** | `CalendarCleanupAccessTests`, `CalendarManualCleanupFailureTests`, and CLI cleanup tests | None. |
| `ACCESS-AC-08` | **Directly tested** | `CalendarMutationExecutorTests`, manual apply and cleanup failure tests, and automatic reconciliation tests | None. |
| `ACCESS-AC-09` | **Directly tested** | `CalendarAccessPrivacyTests`, `CalendarListCommandHandlerTests`, `ReconcileCommandHandlerTests`, `CalendarManualCleanupTests`, and `CalendarAutomationPersistenceTests` | None. |
| `ACCESS-AC-10` | **Directly tested** | Fake-backed custom runner and framework-free domain and application APIs | None. All new tests must remain deterministic, fake-backed, offline, and independent of live EventKit access. |
| `ACCESS-AC-11` | **Directly tested** | Sentinel-backed cleanup presentation, real automatic-operation outcome and attention, and UserDefaults serialization tests | None. |
| `ACCESS-AC-12` | **Directly tested** | `testResolvesOnlyTheExactPlannedOccurrence`, `testMissingExactOccurrenceThrowsEventNotFound`, and `testDuplicateExactCandidatesThrowEventAmbiguous` in `EventKitExactEventOccurrenceResolverTests` | None. |
| `ACCESS-AC-13` | **Directly tested** | Ordinary, cleanup, cleanup-verification, and automatic ordered-read tests | None. |
| `ACCESS-AC-14` | **Directly tested** | `CalendarReviewedActionTests`, configuration identity, standing authorization, and opaque-reference tests | None. |
| `ACCESS-AC-15` | **Directly tested** | Mutation executor, CLI ordinary apply, cleanup verification, manual apply, and automatic reconciliation tests | None. |

Every acceptance check now has direct automated evidence. `CAV-05` remains as the
integration checkpoint for final traceability and complete-gate confirmation.

## Execution summary

Execute `CAV-01` through `CAV-04` before the integration checkpoint `CAV-05`.
The first four tasks are logically independent, but apply them sequentially if
each changes
`/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Main.swift`
to avoid overlapping suite-registration edits.

The next executable task is `CAV-05`. No task is blocked.

## Detailed tasks

### [x] CAV-01 — Add the complete no-prompt authorization matrix

**Scope basis:** `ACCESS-01`, `ACCESS-AC-01`.

Create a request-capable authorization spy and exercise every operation that
must inspect authorization without owning the request capability.

**Likely files:**

- Add
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarNoPromptContractTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Main.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/CommandHandlerTestSupport.swift`
  only if the matrix needs a small reusable valid-configuration or store
  fixture.

Production files must remain unchanged unless this matrix exposes an actual
request-capability leak.

**Required matrix:**

1. Explicit app setup or recovery:
   - `.notDetermined` requests exactly once;
   - every settled state requests zero times.
2. Configuration-independent inventory.
3. Config check with valid configuration.
4. CLI ordinary dry-run, apply, and explanation.
5. Manual-app dry-run, reviewed apply, and apply confirmation.
6. CLI and app cleanup review, dry-run, and apply.
7. Standing-authorization review and confirmation.
8. Automatic ordinary and retry attempts.
9. A revocation transition represented by a fake changing from `.fullAccess`
   to `.denied` between attempts.

For each non-setup surface:

- inject the spy only through the authorization-status interface accepted by
  the subject;
- assert a zero request count for every authorization state;
- assert unavailable authorization fails or produces the specified unavailable
  result without mutation; and
- assert `.fullAccess` proceeds through the intended fake-backed path without
  requesting.

Retain the existing automatic ordinary and retry assertions in
`CalendarAutomaticReconciliationTests`; avoid rebuilding their entire behavioral
fixture if the new suite can cover the remaining surfaces and explicitly retain
that existing evidence.

#### Acceptance and verification

- **Passing evidence:**
  `CalendarAuthorizationTests.testSetupRequestsOnlyWhenAuthorizationIsNotDetermined`,
  `CalendarAuthorizationTests.testSetupDoesNotRequestForSettledAuthorizationStates`,
  `CalendarNoPromptContractTests.testInventoryAndConfigCheckNeverRequestCalendarAccess`,
  `CalendarNoPromptContractTests.testCLIOrdinaryOperationsNeverRequestCalendarAccess`,
  `CalendarNoPromptContractTests.testManualAppOrdinaryOperationsNeverRequestCalendarAccess`,
  `CalendarNoPromptContractTests.testCleanupOperationsNeverRequestCalendarAccess`,
  `CalendarNoPromptContractTests.testStandingAuthorizationNeverRequestsCalendarAccess`,
  `CalendarAutomaticReconciliationTests.testAutomaticAndRetryAttemptsNeverRequestCalendarAccess`,
  and
  `CalendarAutomaticReconciliationTests.testAuthorizationRevocationBetweenAttemptsDoesNotRequestAgain`.
- [x] **CAV-01-AC1:** Only explicit setup with `.notDetermined` records one
  full-access request.
- [x] **CAV-01-AC2:** Inventory, config check, ordinary CLI and app operations,
  cleanup, standing authorization, automatic ordinary runs, and retries record
  zero requests in every authorization state.
- [x] **CAV-01-AC3:** Revocation is handled as unavailable authorization without
  requesting again.
- [x] **CAV-01-AC4:** Every unavailable path also proves that no calendar
  mutation occurred.
- [x] **CAV-01-V1:** The focused suites pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  swift run CalRelayKitTests \
    CalendarAuthorizationTests \
    CalendarNoPromptContractTests \
    CalendarAutomaticReconciliationTests
  ```

### [x] CAV-02 — Test the exact recurring-occurrence resolution decision

**Dependencies:** None.

**Scope basis:** `ACCESS-04`, `ACCESS-07`, `ACCESS-AC-12`.

Refactor the pure candidate-selection seam into a deterministic throwing
resolver used directly by `EventKitCalendarStore`. This is the only production
refactor authorized without first exposing a behavioral defect because the
current private zero/one/many decision cannot be tested at the same boundary
that controls deletion.

**Likely files:**

- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/EventKitExactEventOccurrenceSelector.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/EventKitCalendarStore.swift`.
- Add
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/EventKitExactEventOccurrenceResolverTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Main.swift`.

**Resolver boundary:**

- Accept only `CalendarEventIdentity` and adapter-owned occurrence-candidate
  values.
- Remain deterministic and free of live `EKEventStore` access.
- Match event reference, physical calendar reference, and original occurrence
  date.
- Return exactly one candidate index or equivalent deterministic selection.
- Throw `EventKitCalendarStoreError.eventNotFound` for zero exact matches.
- Throw `EventKitCalendarStoreError.eventAmbiguous` for multiple exact matches.
- Keep `EKEvent`, `EKCalendar`, and every other EventKit framework type out of
  domain and application APIs.

**Required cases:**

1. Exact success selects the planned occurrence despite another occurrence from
   the same series, the same event reference in another physical calendar, and
   an unrelated event in the lookup range.
2. Missing exact occurrence throws `eventNotFound` even when another occurrence
   from the same series is present.
3. Duplicate exact candidates throw `eventAmbiguous`.
4. Missing and ambiguous cases never return the first candidate, a neighboring
   occurrence, or a whole-series target.

#### Acceptance and verification

- [x] **CAV-02-AC1:** The exact planned recurring occurrence resolves
  successfully.
- [x] **CAV-02-AC2:** A missing exact occurrence fails with `eventNotFound`.
- [x] **CAV-02-AC3:** An ambiguous exact occurrence fails with
  `eventAmbiguous`.
- [x] **CAV-02-AC4:** `EventKitCalendarStore` consumes the tested resolver rather
  than retaining separate untested selection logic.
- [x] **CAV-02-AC5:** No EventKit framework type crosses into domain or
  application APIs.
- [x] **CAV-02-V1:** The focused suites pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  swift run CalRelayKitTests \
    EventKitExactEventOccurrenceResolverTests \
    CalendarAuthorizationTests
  ```

Any production behavior correction beyond the resolver extraction requires a
failing regression test first.

### [x] CAV-03 — Close the privacy allowlist and denylist matrix

**Dependencies:** None.

**Scope basis:** `ACCESS-06`, `ACCESS-AC-09`, `ACCESS-AC-11`.

Use conspicuous sentinel values for every protected category:

- EventKit event ID;
- EventKit calendar ID;
- event title;
- calendar title;
- source/title selector;
- marker value; and
- raw configuration fragment.

Assert approved positive disclosure separately from prohibited disclosure. Do
not add a negative assertion that searches for a value never inserted into the
subject under test.

**Likely files:**

- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAccessPrivacyTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarListCommandHandlerTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Adapters/Inbound/CLI/ReconcileCommandHandlerTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarManualCleanupReviewTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAutomationPersistenceTests.swift`.

Production formatter, error, app-presentation, or persistence files must change
only if a sentinel-backed assertion exposes a disclosure defect.

**Required positive assertions:**

- Successful CLI inventory includes the EventKit calendar ID.
- Successful, explicitly requested ordinary CLI explanation may include its
  approved event and calendar IDs.
- Successful cleanup review includes only the approved event title, configured
  role, and time or all-day date range.

**Required negative assertions:**

The event-ID and calendar-ID sentinels must not appear in:

- readiness output;
- access failures;
- explanation failure or partial explanation;
- mutation failure and partial-application diagnostics;
- cleanup review or cleanup success and failure output;
- app inventory;
- app cleanup presentation beyond its narrower allowlist;
- automatic outcomes and attention messages; or
- serialized persistent operational state.

Cleanup output must additionally omit source/title selectors, physical calendar
titles, and marker values. Persisted state must additionally omit calendar
names, event titles and details, marker values, and raw configuration.

#### Acceptance and verification

- [x] **CAV-03-AC1:** Positive disclosure tests prove that identifiers are
  available only in successful CLI inventory and explicitly requested,
  successful ordinary CLI explanation.
- [x] **CAV-03-AC2:** Readiness, failure, cleanup, app, automatic, and
  persistence surfaces reject both event-ID and calendar-ID sentinels.
- [x] **CAV-03-AC3:** Cleanup review retains its approved transient title,
  role, and time information while rejecting every prohibited field.
- [x] **CAV-03-AC4:** Every negative assertion uses protected data actually
  present in the constructed input.
- [x] **CAV-03-AC5:** No production change is made unless a sentinel-backed
  test fails against current output.
- [x] **CAV-03-V1:** The focused suites pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  swift run CalRelayKitTests \
    CalendarAccessPrivacyTests \
    CalendarListCommandHandlerTests \
    ReconcileCommandHandlerTests \
    CalendarManualCleanupTests \
    CalendarAutomationPersistenceTests
  ```

- **Passing evidence:**
  `CalendarAccessPrivacyTests.testReadinessAndAccessFailuresOmitProtectedIdentifiersAndEventDetails`,
  `CalendarAccessPrivacyTests.testMutationFailureOmitsProtectedIdentifiersAndEventDetails`,
  `CalendarAccessPrivacyTests.testCleanupErrorsRemainAggregateAndActionable`,
  `CalendarListCommandHandlerTests.testCalendarListHandlerFormatsCalendarsFromInjectedStore`,
  `CalendarListCommandHandlerTests.testAppInventoryFormattingOmitsEventKitCalendarIDs`,
  `ReconcileCommandHandlerTests.testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig`,
  `ReconcileCommandHandlerTests.testExplanationAccessFailureEmitsNoPartialOutputOrIdentifiers`,
  `ReconcileCommandHandlerTests.testCleanupDryRunReportsCompleteRoleSummariesAndPrivateOrderedReview`,
  `ReconcileCommandHandlerTests.testCleanupApplyFailureOnlyConfirmsCompletedActionsAndStaysPrivate`,
  `CalendarManualCleanupTests.testReviewPrivacyAndExecutionOrder`,
  `CalendarAutomationPersistenceTests.testRuntimeDescriptionsAndAttentionOutputRemainOpaque`,
  and
  `CalendarAutomationPersistenceTests.testAutomaticOperationPersistsAndNotifiesWithoutSensitiveInputs`.
- **Verification result (September 22, 2026):** The focused command above
  passed with `CalRelayKitTests passed`. `make format-check` exited successfully;
  it reported non-fatal formatter warnings under the current configuration.
  `make check` then passed
  strict SwiftLint with 0 violations, `swift build`, the complete
  `CalRelayKitTests` runner, and all four CLI help smoke checks. `git --no-pager
  diff --check` also passed. No production source changed; the only implementation
  adjustments during validation were test-fixture cleanup required by Swift 6
  sendability and SwiftLint.

### [x] CAV-04 — Automate app Calendar-usage metadata verification

**Dependencies:** None.

**Scope basis:** Packaging support for `ACCESS-01` and `ACCESS-AC-01`.

The source property list already contains both required usage descriptions. Add
automated evidence that they remain present in the source and the built app.

**Likely files:**

- Retain unless a test exposes invalid content:
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Resources/CalRelayApp/Info.plist`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/scripts/build-calrelay-app.sh`.
- Add
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Features/CalendarRelay/Contracts/CalendarAppBundleMetadataTests.swift`.
- Update
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Main.swift`.

Do not add Calendar permission metadata to
`/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Resources/CalRelayUITestHost/Info.plist`.
The fake UI-test host intentionally never requests Calendar permission.

**Deterministic source check:**

Parse the source property list with `PropertyListSerialization` and assert that
these keys are present, are strings, and are nonempty:

- `NSCalendarsFullAccessUsageDescription`;
- `NSCalendarsUsageDescription`.

Resolve the resource from `#filePath` or another deterministic source-relative
path; do not depend on the process working directory.

**App-build check:**

Extend the app build script to validate the copied
`/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/.build/CalRelay.app/Contents/Info.plist`.
The build must fail before reporting success when the property list is invalid,
either key is absent, or either value is empty. Use installed macOS tooling such
as `plutil` or `/usr/libexec/PlistBuddy`; do not add a package dependency.

#### Acceptance and verification

- [x] **CAV-04-AC1:** The deterministic suite fails if either source metadata
  key is missing or empty.
- [x] **CAV-04-AC2:** `make app` fails if either key is missing or empty in the
  copied bundle.
- [x] **CAV-04-AC3:** A successful app build contains both nonempty values in
  its final signed bundle.
- [x] **CAV-04-AC4:** The fake UI-test host remains independent of Calendar
  permission metadata.
- [x] **CAV-04-V1:** The focused suite and app build pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  swift run CalRelayKitTests CalendarAppBundleMetadataTests && \
  make app
  ```

The build script, rather than a handoff-only diagnostic command, must enforce
the metadata failure.

- **Passing evidence:**
  `CalendarAppBundleMetadataTests.testProductionSourceInfoPlistContainsNonemptyCalendarUsageDescriptions`,
  `CalendarAppBundleMetadataTests.testUITestHostSourceInfoPlistOmitsCalendarUsageDescriptions`,
  `CalendarAppBundleMetadataTests.testAppBuildRejectsMissingCalendarUsageDescriptions`,
  and
  `CalendarAppBundleMetadataTests.testAppBuildRejectsEmptyCalendarUsageDescriptions`.
  The build-script fixture exercises both required keys in both missing and
  whitespace-only forms.
- **Verification result (September 23, 2026):** The focused suite passed with
  `CalRelayKitTests passed`. `make app` built and strictly verified the signed
  bundle, and `plutil` extracted nonempty values for both Calendar usage-description
  keys from the final `.build/CalRelay.app/Contents/Info.plist`. `make
  format-check` exited successfully with the repository’s existing non-fatal
  formatter warnings. `make check` passed strict SwiftLint with 0 violations,
  `swift build`, the complete `CalRelayKitTests` runner, and all four CLI help
  smoke checks. `zsh -n scripts/build-calrelay-app.sh` and `git --no-pager diff
  --check` also passed. The source production property list required no change,
  and the fake UI-test-host property list remains free of Calendar permission
  metadata.

### [ ] CAV-05 — Integrate traceability and run the complete automated gate

**Dependencies:** `CAV-01`, `CAV-02`, `CAV-03`, `CAV-04`.

Add the relevant `ACCESS-AC-*` identifiers to newly added or materially
strengthened behavioral tests. Keep each assertion behavioral; do not add a test
that merely enumerates requirement IDs and passes without exercising behavior.

Update this plan's traceability tables with exact test names and evidence as
tasks complete. Do not modify the accepted calendar-access specification unless
implementation reveals a genuine contract conflict, and do not recreate the
deleted historical implementation plan.

**Conditional automated checks:**

- If implementation changes a CLI entry point or composition source under
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Sources/CalRelayCLI`,
  run:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  swift run CalRelayKitTests CalRelayCLISmokeTests
  ```

- If an unexpected defect requires changing app UI source, accessibility
  behavior, fake UI composition, or the UI-test harness, run:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  make ui-test
  ```

Handler-only test additions do not by themselves require a production CLI
process change. The expected test-only, resolver, and app-build-script work does
not require UI automation unless its scope expands into the listed app surfaces.

#### Acceptance and verification

- [ ] **CAV-05-AC1:** Every new suite provides `runAll()` and is registered in
  the custom runner at
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Main.swift`.
- [ ] **CAV-05-AC2:** The final traceability maps every `ACCESS-01` through
  `ACCESS-07` outcome and every `ACCESS-AC-01` through `ACCESS-AC-15` check to
  passing automated evidence.
- [ ] **CAV-05-AC3:** No manual or live EventKit observation is represented as
  an automated pass.
- [ ] **CAV-05-AC4:** No completed scheduling, persistence, coordination,
  reconciliation, or cleanup work is reimplemented.
- [ ] **CAV-05-V1:** Every focused task suite passes.
- [ ] **CAV-05-V2:** The repository formatting and quality gates pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  make format-check && \
  make check
  ```

- [ ] **CAV-05-V3:** The app build and bundle validation pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  make app
  ```

- [ ] **CAV-05-V4:** The final diff contains no whitespace errors:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  git --no-pager diff HEAD --check
  ```

- [ ] **CAV-05-V5:** Each conditional check is either run and passes or is
  reported as not applicable with its scope reason.

## Handoff

Begin with `CAV-01`. Keep all tests deterministic, isolated, fake-backed, and
offline. Do not request live Calendar permission, open real calendars, or mutate
EventKit data as part of this plan's automated verification.
