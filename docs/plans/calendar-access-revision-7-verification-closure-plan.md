# Calendar access revision 7 verification-closure plan

## Plan record

- **Status:** Complete; `CAV-01` through `CAV-05` are complete.
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
- **Readiness:** Verification closure is complete. No unresolved product
  decision, implementation blocker, or known calendar-access behavior defect
  remains in this plan.

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
| `ACCESS-01` — Permission ownership and authorization states | Implemented | **Directly tested.** The exact `ACCESS-AC-01` evidence below covers setup-only requests, every non-setup operation, automatic retry and revocation, and packaged permission metadata. | None. |
| `ACCESS-02` — Calendar discovery | Implemented | **Directly tested.** `CalendarAuthorizationTests.testInventoryReturnsEmptySuccessfulInventory`, `CalendarListCommandHandlerTests.testCalendarListHandlerFormatsCalendarsFromInjectedStore`, `CalendarListCommandHandlerTests.testCalendarListHandlerTreatsEmptyInventoryAsSuccessWithoutReadinessClaim`, `CalendarListCommandHandlerTests.testCalendarListHandlerReportsReadOnlyCalendars`, and `CalendarListCommandHandlerTests.testAppInventoryFormattingOmitsEventKitCalendarIDs`. | None. |
| `ACCESS-03` — Ordinary configured-topology readiness | Implemented | **Directly tested.** `CalendarAccessPreflightTests.testPreflightAggregatesTopologyFailuresAndReadsResolvableRolesInOrder`, `CalendarAccessPreflightTests.testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation`, `ConfigCheckCommandHandlerTests.testConfigCheckReportsReadyTopologyWithoutMutation`, `ReconcileCommandHandlerTests.testOrdinaryModesUseOrdinaryAccessWindow`, `CalendarManualDryRunTests.testDryRunLoadsFreshSettingsAndReturnsAggregateCountsWithoutMutation`, `CalendarManualApplyTests.testReviewRequiresOneUseConfirmationAndFreshPreflight`, and `CalendarAutomaticReconciliationTests.testAutomaticPreflightFailuresPreventAllMutations`. | None. |
| `ACCESS-04` — Legacy-cleanup preflight | Implemented | **Directly tested.** `CalendarCleanupAccessTests.testCleanupDryRunSelectsOnlyExactLegacyMarkersInTopologyOrder`, `CalendarCleanupAccessTests.testCleanupApplyVerifiesCompleteRangeAfterDeletes`, `CalendarCleanupAccessTests.testCleanupApplyFailsWhenVerificationFindsRemainingMatchWithoutRollback`, `CalendarCleanupAccessTests.testCleanupApplyFailsWhenVerificationReadFailsWithoutRollback`, `CalendarManualCleanupTests.testReviewApplyAndOneUseConfirmation`, and `EventKitExactEventOccurrenceResolverTests.testResolvesOnlyTheExactPlannedOccurrence`, `EventKitExactEventOccurrenceResolverTests.testMissingExactOccurrenceThrowsEventNotFound`, and `EventKitExactEventOccurrenceResolverTests.testDuplicateExactCandidatesThrowEventAmbiguous`. | None. |
| `ACCESS-05` — Failure after mutation begins | Implemented | **Directly tested.** `CalendarMutationExecutorTests.testExecutorConfirmsOrderedActionsAfterSuccess`, `CalendarMutationExecutorTests.testExecutorStopsAtFirstFailureAndReportsPrivacySafeCounts`, `CalendarMutationExecutorTests.testExecutorTreatsEmptyPlanAsSuccess`, `ReconcileCommandHandlerTests.testApplyFailureOnlyConfirmsCompletedActions`, `CalendarManualApplyTests.testPartialFailureConsumesConfirmationAndOmitsDetails`, and `CalendarAutomaticReconciliationTests.testPartialMutationPersistsOnlyAggregateConfirmedCounts`. | None. |
| `ACCESS-06` — Privacy-safe diagnostics and cleanup review | Implemented | **Directly tested.** The exact sentinel-backed tests listed for `ACCESS-AC-09` and `ACCESS-AC-11` below cover approved CLI disclosure and readiness, failure, cleanup, app, automatic-notification, and serialized-state denylists. | None. |
| `ACCESS-07` — EventKit boundary | Implemented | **Directly tested.** `CalendarAuthorizationTests.testOpaqueProviderReferencesPreserveIdentityWithoutStringExposure`, `CalendarAccessPreflightTests.testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation`, `CalendarReviewedActionTests.runAll`, `CalendarConfigurationIdentityTests.testResolvedTopologyOrderAndContinuityDeriveDifferentBindings`, and `EventKitExactEventOccurrenceResolverTests.testResolvesOnlyTheExactPlannedOccurrence`, `EventKitExactEventOccurrenceResolverTests.testMissingExactOccurrenceThrowsEventNotFound`, and `EventKitExactEventOccurrenceResolverTests.testDuplicateExactCandidatesThrowEventAmbiguous` cover opaque physical identity, ordered snapshots, reviewed-action identity, topology binding, and exact recurring-occurrence resolution. | None. |

## Acceptance-check traceability

| Acceptance check | Verification state | Exact automated evidence | Remaining gap |
| --- | --- | --- | --- |
| `ACCESS-AC-01` | **Directly tested** | `CalendarAuthorizationTests.testSetupRequestsOnlyWhenAuthorizationIsNotDetermined`; `CalendarAuthorizationTests.testSetupDoesNotRequestForSettledAuthorizationStates`; `CalendarNoPromptContractTests.testInventoryAndConfigCheckNeverRequestCalendarAccess`; `CalendarNoPromptContractTests.testCLIOrdinaryOperationsNeverRequestCalendarAccess`; `CalendarNoPromptContractTests.testManualAppOrdinaryOperationsNeverRequestCalendarAccess`; `CalendarNoPromptContractTests.testCleanupOperationsNeverRequestCalendarAccess`; `CalendarNoPromptContractTests.testStandingAuthorizationNeverRequestsCalendarAccess`; `CalendarAutomaticReconciliationTests.testAutomaticAndRetryAttemptsNeverRequestCalendarAccess`; `CalendarAutomaticReconciliationTests.testAuthorizationRevocationBetweenAttemptsDoesNotRequestAgain`; `CalendarAppBundleMetadataTests.testProductionSourceInfoPlistContainsNonemptyCalendarUsageDescriptions`; `CalendarAppBundleMetadataTests.testUITestHostSourceInfoPlistOmitsCalendarUsageDescriptions`; `CalendarAppBundleMetadataTests.testAppBuildRejectsMissingCalendarUsageDescriptions`; and `CalendarAppBundleMetadataTests.testAppBuildRejectsEmptyCalendarUsageDescriptions`. | None. |
| `ACCESS-AC-02` | **Directly tested** | `CalendarAuthorizationTests.testInventoryReturnsEmptySuccessfulInventory`; `CalendarListCommandHandlerTests.testCalendarListHandlerFormatsCalendarsFromInjectedStore`; `CalendarListCommandHandlerTests.testCalendarListHandlerTreatsEmptyInventoryAsSuccessWithoutReadinessClaim`; and `CalendarListCommandHandlerTests.testCalendarListHandlerReportsReadOnlyCalendars`. | None. |
| `ACCESS-AC-03` | **Directly tested** | `CalendarAccessPreflightTests.testPreflightAggregatesTopologyFailuresAndReadsResolvableRolesInOrder`; `CalendarAccessPreflightTests.testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation`; `ConfigCheckCommandHandlerTests.testConfigCheckReportsReadyTopologyWithoutMutation`; `ReconcileCommandHandlerTests.testOrdinaryModesUseOrdinaryAccessWindow`; `CalendarManualDryRunTests.testDryRunLoadsFreshSettingsAndReturnsAggregateCountsWithoutMutation`; `CalendarManualApplyTests.testReviewRequiresOneUseConfirmationAndFreshPreflight`; and `CalendarAutomaticReconciliationTests.testAutomaticPreflightFailuresPreventAllMutations`. | None. |
| `ACCESS-AC-04` | **Directly tested** | `ConfigCheckCommandHandlerTests.testMigrationPendingConfigCheckStillRunsPreflightAndFails` and `ConfigCheckCommandHandlerTests.testMigrationPendingConfigCheckAggregatesPreflightFailuresWithoutReadinessClaim`. | None. |
| `ACCESS-AC-05` | **Directly tested** | `CalendarCleanupAccessTests.testCleanupDryRunSelectsOnlyExactLegacyMarkersInTopologyOrder`; `CalendarCleanupAccessTests.testCleanupApplyVerifiesCompleteRangeAfterDeletes`; `CalendarManualCleanupTests.testReviewApplyAndOneUseConfirmation`; `ReconcileCommandHandlerTests.testCleanupModesUseCleanupAccessWindow`; and `ReconcileCommandHandlerTests.testCleanupApplyEmitsFreshReviewAndProgressiveConfirmation`. | None. |
| `ACCESS-AC-06` | **Directly tested** | `CalendarAccessPreflightTests.testPreflightAggregatesTopologyFailuresAndReadsResolvableRolesInOrder`; `CalendarAutomaticReconciliationTests.testAutomaticPreflightFailuresPreventAllMutations`; `CalendarManualApplyTests.testConfigurationChangesBeforeFirstMutationAbort`; and `CalendarManualCleanupTests.testConfigurationRaceVetoesAllDeletion`. | None. |
| `ACCESS-AC-07` | **Directly tested** | `CalendarCleanupAccessTests.testCleanupApplyVerifiesCompleteRangeAfterDeletes`; `CalendarCleanupAccessTests.testCleanupApplyFailsWhenVerificationFindsRemainingMatchWithoutRollback`; `CalendarCleanupAccessTests.testCleanupApplyFailsWhenVerificationReadFailsWithoutRollback`; and `CalendarManualCleanupTests.testReviewApplyAndOneUseConfirmation`. | None. |
| `ACCESS-AC-08` | **Directly tested** | `CalendarMutationExecutorTests.testExecutorStopsAtFirstFailureAndReportsPrivacySafeCounts`; `CalendarManualApplyTests.testPartialFailureConsumesConfirmationAndOmitsDetails`; `CalendarManualCleanupTests.testFailuresPreserveConfirmedCounts`; and `CalendarAutomaticReconciliationTests.testPartialMutationPersistsOnlyAggregateConfirmedCounts`. | None. |
| `ACCESS-AC-09` | **Directly tested** | `CalendarAccessPrivacyTests.testReadinessAndAccessFailuresOmitProtectedIdentifiersAndEventDetails`; `CalendarAccessPrivacyTests.testMutationFailureOmitsProtectedIdentifiersAndEventDetails`; `CalendarAccessPrivacyTests.testCleanupErrorsRemainAggregateAndActionable`; `CalendarListCommandHandlerTests.testCalendarListHandlerFormatsCalendarsFromInjectedStore`; `CalendarListCommandHandlerTests.testAppInventoryFormattingOmitsEventKitCalendarIDs`; `ReconcileCommandHandlerTests.testReconcileHandlerFormatsExplanationFromInjectedStoreAndConfig`; `ReconcileCommandHandlerTests.testExplanationAccessFailureEmitsNoPartialOutputOrIdentifiers`; `ReconcileCommandHandlerTests.testCleanupDryRunReportsCompleteRoleSummariesAndPrivateOrderedReview`; `ReconcileCommandHandlerTests.testCleanupApplyFailureOnlyConfirmsCompletedActionsAndStaysPrivate`; `CalendarManualCleanupTests.testReviewPrivacyAndExecutionOrder`; `CalendarAutomationPersistenceTests.testRuntimeDescriptionsAndAttentionOutputRemainOpaque`; and `CalendarAutomationPersistenceTests.testAutomaticOperationPersistsAndNotifiesWithoutSensitiveInputs`. | None. |
| `ACCESS-AC-10` | **Directly tested** | `CalendarAccessPreflightTests.testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation` and `CalendarMutationExecutorTests.testExecutorConfirmsOrderedActionsAfterSuccess` execute through fake ports without live EventKit access; the complete custom `CalRelayKitTests` runner and `make check` compile and execute the framework-free domain and application boundaries. | None. |
| `ACCESS-AC-11` | **Directly tested** | `CalendarManualCleanupTests.testReviewPrivacyAndExecutionOrder`; `CalendarAutomationPersistenceTests.testRuntimeDescriptionsAndAttentionOutputRemainOpaque`; and `CalendarAutomationPersistenceTests.testAutomaticOperationPersistsAndNotifiesWithoutSensitiveInputs`. | None. |
| `ACCESS-AC-12` | **Directly tested** | `EventKitExactEventOccurrenceResolverTests.testResolvesOnlyTheExactPlannedOccurrence`; `EventKitExactEventOccurrenceResolverTests.testMissingExactOccurrenceThrowsEventNotFound`; and `EventKitExactEventOccurrenceResolverTests.testDuplicateExactCandidatesThrowEventAmbiguous`. | None. |
| `ACCESS-AC-13` | **Directly tested** | `CalendarAccessPreflightTests.testReadyPreflightReturnsCompleteOrderedSnapshotWithoutMutation`; `CalendarCleanupAccessTests.testCleanupDryRunSelectsOnlyExactLegacyMarkersInTopologyOrder`; `CalendarCleanupAccessTests.testCleanupApplyVerifiesCompleteRangeAfterDeletes`; and `CalendarAutomaticReconciliationTests.testFreshAuthorizedAttemptAppliesAndPersistsAggregateSuccess`. | None. |
| `ACCESS-AC-14` | **Directly tested** | `CalendarReviewedActionTests.runAll`; `CalendarConfigurationIdentityTests.testResolvedTopologyOrderAndContinuityDeriveDifferentBindings`; `CalendarAutomationPersistenceTests.testBindingIsSemanticVersionedAndOpaque`; and `CalendarAuthorizationTests.testOpaqueProviderReferencesPreserveIdentityWithoutStringExposure`. | None. |
| `ACCESS-AC-15` | **Directly tested** | `CalendarMutationExecutorTests.testExecutorConfirmsOrderedActionsAfterSuccess`; `CalendarMutationExecutorTests.testExecutorTreatsEmptyPlanAsSuccess`; `ReconcileCommandHandlerTests.testEmptyApplyReportsSuccessfulNoChange`; `CalendarManualApplyTests.testReviewRequiresOneUseConfirmationAndFreshPreflight`; `CalendarAutomaticReconciliationTests.testReadyEmptyPlanUpdatesSuccessWithoutMutation`; and `CalendarCleanupAccessTests.testCleanupApplyVerifiesCompleteRangeAfterDeletes`. | None. |

Every required outcome and acceptance check has exact automated evidence. `CAV-05`
is the final integration checkpoint.

## Execution summary

`CAV-01` through `CAV-05` are complete. No task is blocked.

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

### [x] CAV-05 — Integrate traceability and run the complete automated gate

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

- [x] **CAV-05-AC1:** Every new suite provides `runAll()` and is registered in
  the custom runner at
  `/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay/Tests/CalRelayKitTests/Main.swift`.
- [x] **CAV-05-AC2:** The final traceability maps every `ACCESS-01` through
  `ACCESS-07` outcome and every `ACCESS-AC-01` through `ACCESS-AC-15` check to
  passing automated evidence.
- [x] **CAV-05-AC3:** No manual or live EventKit observation is represented as
  an automated pass.
- [x] **CAV-05-AC4:** No completed scheduling, persistence, coordination,
  reconciliation, or cleanup work is reimplemented.
- [x] **CAV-05-V1:** Every focused task suite passes.
- [x] **CAV-05-V2:** The repository formatting and quality gates pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  make format-check && \
  make check
  ```

- [x] **CAV-05-V3:** The app build and bundle validation pass:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  make app
  ```

- [x] **CAV-05-V4:** The final diff contains no whitespace errors:

  ```sh
  cd '/Users/owinter/Documents/Projects/ondrej-winter.nosync/calrelay' && \
  git --no-pager diff HEAD --check
  ```

- [x] **CAV-05-V5:** Each conditional check is either run and passes or is
  reported as not applicable with its scope reason.

- **Passing evidence:** The CAV-01 through CAV-04 focused suites all passed in one
  custom-runner invocation: `CalendarAuthorizationTests`,
  `CalendarNoPromptContractTests`, `CalendarAutomaticReconciliationTests`,
  `EventKitExactEventOccurrenceResolverTests`, `CalendarAccessPrivacyTests`,
  `CalendarListCommandHandlerTests`, `ReconcileCommandHandlerTests`,
  `CalendarManualCleanupTests`, `CalendarAutomationPersistenceTests`, and
  `CalendarAppBundleMetadataTests`. The newly added suites each expose `runAll()`
  and are registered in `Tests/CalRelayKitTests/Main.swift`.
- **Verification result (September 23, 2026):** The focused union passed with
  `CalRelayKitTests passed`. `make format-check` exited successfully with the
  repository’s existing non-fatal formatter warnings. `make check` passed strict
  SwiftLint with 0 violations, `swift build`, the complete custom test runner,
  and all four CLI help smoke checks. `make app` built and strictly verified the
  signed bundle; `plutil` extracted both required Calendar usage-description
  strings from the final bundle, and `codesign --verify --deep --strict` passed.
  `git --no-pager diff HEAD --check` passed after the final documentation update.
  The CLI-entry/composition smoke check was not applicable because no source
  under `Sources/CalRelayCLI` changed. UI automation was not applicable because
  no app UI, accessibility, fake UI composition, UI-test-host, or UI-test source
  changed. No manual or live EventKit observation is recorded as automated
  evidence, no accepted specification changed, and no completed product behavior
  was reimplemented.

## Handoff

Verification closure is complete. Keep all tests deterministic, isolated,
fake-backed, and offline. Do not request live Calendar permission, open real
calendars, or mutate EventKit data as part of ordinary automated verification.
