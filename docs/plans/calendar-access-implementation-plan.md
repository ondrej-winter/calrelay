# Calendar access implementation plan

## Plan record

- **Status:** Ready.
- **Prepared:** September 24, 2026.
- **Canonical requirements:**
  [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md),
  revision 7, accepted September 16, 2026.
- **Scope:** Implementation and verification work required by the calendar-access
  contract only.
- **Current state:** Revision 7 was previously implemented and verification was
  closed on September 23, 2026. The only relevant later change is the routing
  correction in commit `94352fd`, which touched ordinary reconciliation and
  standing-authorization identity. Work therefore begins with current-HEAD
  verification and permits production changes only when a failing acceptance
  test demonstrates a concrete regression or uncovered defect.
- **Readiness:** Ready. The accepted requirements, existing architecture,
  affected surfaces, sequencing, and validation commands are known. There is no
  unresolved product decision.

## Outcome

Demonstrate that current HEAD satisfies `ACCESS-01` through `ACCESS-07` and
`ACCESS-AC-01` through `ACCESS-AC-15`. If verification exposes a defect, retain
the failing regression test and make the smallest calendar-access correction
that restores the accepted contract.

If all focused and complete gates pass, the correct implementation result is no
production change and a verified-compliant handoff, not a speculative rewrite.

## Scope boundaries

### In scope

- Full Calendar authorization and setup/recovery prompt ownership.
- CLI and app all-calendar inventory.
- Shared ordinary configured-topology preflight.
- Dedicated complete-range cleanup preflight and verification.
- Runtime access and mutation failures.
- Ordered mutation confirmation and privacy-safe partial results.
- Exact recurring-occurrence deletion.
- Physical-calendar executable-action and topology identity.
- Calendar-access disclosure boundaries.
- EventKit adapter and composition boundaries.
- Production app Calendar permission metadata.
- Deterministic acceptance coverage and explicit dedicated-calendar manual
  validation.

### Out of scope

- Reimplementing completed scheduling, persistence, reconciliation, cleanup, or
  app-lifecycle behavior.
- Routing, projection, configuration, CLI, or app changes not required by a
  failing calendar-access acceptance check.
- EventKit identifiers as configuration selectors, selector fallbacks,
  visible-set keys, routing inputs, or ownership markers.
- Partial-topology reconciliation or cleanup.
- Provider APIs, OAuth, provider-specific synchronization tokens, or
  network-backed tests.
- Automatic cleanup, automatic configuration editing, helper apps, or
  closed-app synchronization.
- Changes to the accepted specification unless implementation reveals a real
  contract conflict requiring explicit approval.
- Unrelated refactoring, dependency changes, or cleanup.

## Change policy

1. Run the existing acceptance evidence before changing production code.
2. When evidence is missing or behavior fails, add or strengthen a deterministic
   test first.
3. Make the smallest production correction that passes the new test.
4. Preserve the existing hexagonal and vertical-slice boundaries.
5. Keep default tests fake-backed, deterministic, isolated, and independent of
   EventKit and real calendars.
6. Do not represent manual or live EventKit observations as automated passes.

## Requirements traceability

| Requirements | Owning task |
| --- | --- |
| `ACCESS-01`, `ACCESS-02`, `ACCESS-AC-01`, `ACCESS-AC-02` | `CALACC-02` |
| `ACCESS-03`, `ACCESS-AC-03`, `ACCESS-AC-04`, `ACCESS-AC-06`, ordinary portions of `ACCESS-AC-13` and `ACCESS-AC-15` | `CALACC-03` |
| `ACCESS-04`, `ACCESS-AC-05`, `ACCESS-AC-07`, cleanup portions of `ACCESS-AC-13` and `ACCESS-AC-15` | `CALACC-04` |
| `ACCESS-05`, `ACCESS-AC-08`, `ACCESS-AC-12`, `ACCESS-AC-14`, mutation portions of `ACCESS-AC-15` | `CALACC-05` |
| `ACCESS-06`, `ACCESS-AC-09`, `ACCESS-AC-11` | `CALACC-06` |
| `ACCESS-07`, `ACCESS-AC-10`, boundary portions of `ACCESS-AC-12` through `ACCESS-AC-14` | `CALACC-05`, `CALACC-06` |
| Complete contract and live macOS boundary | `CALACC-07` |

## Execution summary

Execute `CALACC-01` first. `CALACC-02`, `CALACC-03`, and `CALACC-04` may be
investigated independently after the baseline, but implement discovered fixes
sequentially because their tests and application surfaces overlap. Complete
`CALACC-05` and `CALACC-06` after those behavioral gates, then finish with
`CALACC-07`.

## CALACC-01 — Establish the current acceptance baseline

**Dependencies:** None.

**Scope basis:** Determine whether the post-closure routing change introduced a
calendar-access regression and prevent duplicate implementation of completed
work.

**Likely targets:**

- `Tests/CalRelayKitTests/Main.swift`
- `Tests/CalRelayKitTests/Features/CalendarRelay/`
- `Tests/CalRelayKitTests/CalRelayCLI/`

**Work:**

- Recheck Git status and preserve all unrelated staged, unstaged, and untracked
  work.
- Build a current traceability matrix for all seven outcomes and fifteen
  acceptance checks.
- Run the registered access-focused suites before editing production code.
- Classify each failure as a calendar-access regression, an unrelated
  pre-existing failure, or a missing assertion around currently correct
  behavior.
- Do not modify production code without a failing acceptance-level test.

- [ ] **CALACC-01-AC1:** Every `ACCESS-01` through `ACCESS-07` outcome and
  `ACCESS-AC-01` through `ACCESS-AC-15` check has current automated evidence or
  an explicitly identified gap.
- [ ] **CALACC-01-AC2:** No task recreates completed work solely because it
  appeared in a historical implementation plan.
- [ ] **CALACC-01-AC3:** Unrelated workspace changes remain untouched.
- [ ] **CALACC-01-V1:** The focused suite union runs using exact suite names
  registered in `Tests/CalRelayKitTests/Main.swift`.

## CALACC-02 — Verify permission ownership and inventory

**Dependencies:** `CALACC-01` acceptance baseline.

**Requirements:** `ACCESS-01`, `ACCESS-02`, `ACCESS-AC-01`, `ACCESS-AC-02`.

**Likely targets if a defect is exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAccessSetupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarInventoryUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/Ports/CalendarAuthorizationPorts.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarListFormatter.swift`
- `Sources/CalRelayApp/CalendarListViewModel.swift`
- `Resources/CalRelayApp/Info.plist`
- `scripts/build-calrelay-app.sh`

**Work:**

- Verify that only `CalendarAccessSetupUseCase` receives the full-access request
  capability.
- Verify setup requests full access only from `.notDetermined`.
- Verify denied, revoked, write-only, restricted, full-access, and unknown states
  do not prompt and produce the specified recovery presentation.
- Verify every CLI, inventory, status, manual, cleanup, standing-authorization,
  automatic, and retry path remains non-prompting.
- Verify CLI inventory is configuration-independent, accepts an empty inventory,
  displays source, title, EventKit calendar ID, and writability, and makes no
  configured-readiness claim.
- Verify app inventory omits EventKit IDs and remains distinct from configuration
  validity and configured readiness.
- Verify production app metadata contains both required nonempty Calendar usage
  descriptions.

- [ ] **CALACC-02-AC1:** Only the explicit app setup/recovery path can request
  full Calendar access.
- [ ] **CALACC-02-AC2:** Every non-setup operation remains non-prompting for every
  authorization state.
- [ ] **CALACC-02-AC3:** CLI and app inventories satisfy their distinct
  disclosure contracts, including empty-inventory success.
- [ ] **CALACC-02-V1:** `CalendarAuthorizationTests`,
  `CalendarNoPromptContractTests`, `CalendarListCommandHandlerTests`, and
  `CalendarAppBundleMetadataTests` pass.

## CALACC-03 — Verify shared ordinary topology preflight

**Dependencies:** `CALACC-01` acceptance baseline.

**Requirements:** `ACCESS-03`, `ACCESS-AC-03`, `ACCESS-AC-04`,
`ACCESS-AC-06`, and the ordinary portions of `ACCESS-AC-13` and
`ACCESS-AC-15`.

**Likely targets if a defect is exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAccessPreflightUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarControlPanelStatusUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualApplyUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarAutomaticReconciliationUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/ConfigCheckCommandHandler.swift`

**Work:**

- Verify config check, CLI dry-run/apply/explanation, app dry-run/apply, standing
  authorization, and automatic reconciliation use the shared ordinary
  preflight.
- Verify file loading, parsing, and structural validation precede EventKit
  access.
- Verify preflight rejects unavailable authorization, missing selectors,
  ambiguous selectors, physical-calendar collisions, unreadable calendars, and
  read-only calendars.
- Verify all safely determinable failures are aggregated without mutation.
- Verify snapshot reads are sequential: hub first, then work calendars in
  configuration declaration order.
- Verify migration-pending config check still completes preflight and cannot
  claim readiness.
- Regression-test the post-closure routing change against physical-topology
  readiness, declaration-ordered reads, no-subset mutation, standing-
  authorization topology binding, and ordinary local-confirmation semantics.
- Keep one shared preflight rather than introducing wrapper-specific variants.

- [ ] **CALACC-03-AC1:** Every ordinary surface rejects the same complete set of
  topology failures before mutation or success.
- [ ] **CALACC-03-AC2:** Resolvable roles are read hub-first and then in work
  declaration order, including when other failures are aggregated.
- [ ] **CALACC-03-AC3:** Migration-pending config check performs preflight but
  never reports readiness.
- [ ] **CALACC-03-AC4:** A ready empty ordinary plan succeeds without mutation or
  a post-mutation verification read.
- [ ] **CALACC-03-V1:** `CalendarAccessPreflightTests`,
  `ConfigCheckCommandHandlerTests`, `ReconcileCommandHandlerTests`,
  `CalendarControlPanelStatusTests`, `CalendarManualDryRunTests`,
  `CalendarManualApplyTests`, `CalendarStandingAuthorizationTests`, and
  `CalendarAutomaticReconciliationTests` pass.

## CALACC-04 — Verify cleanup preflight and verification

**Dependencies:** `CALACC-01` acceptance baseline.

**Requirements:** `ACCESS-04`, `ACCESS-AC-05`, `ACCESS-AC-07`, and the cleanup
portions of `ACCESS-AC-13` and `ACCESS-AC-15`.

**Likely targets if a defect is exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarCleanupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarManualCleanupUseCase.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/LegacyCleanupWindow.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarCleanupFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/App/CalendarManualCleanupFormatter.swift`

**Work:**

- Verify cleanup rejects an empty `legacyMarkers` list before EventKit access.
- Verify CLI and app cleanup use the same complete cleanup-range preflight.
- Verify every configured role is read over the complete cleanup range, hub first
  and then in declaration order.
- Verify any missing, ambiguous, colliding, unreadable, or read-only role
  prevents every deletion.
- Verify all planned deletions complete before verification begins.
- Verify post-delete validation rereads the entire topology and succeeds only
  when no exact configured legacy-marker match remains.
- Verify read failure or remaining matches return failure without rollback or a
  false success claim.
- Preserve cleanup's stronger verification semantics; do not add them to
  ordinary apply.

- [ ] **CALACC-04-AC1:** Cleanup never deletes a readable subset when any
  configured role fails preflight.
- [ ] **CALACC-04-AC2:** Cleanup preflight and verification use the complete
  cleanup range and required read order.
- [ ] **CALACC-04-AC3:** Verification failure leaves confirmed deletions applied
  and reports unsuccessful completion.
- [ ] **CALACC-04-V1:** `CalendarCleanupAccessTests`,
  `CalendarManualCleanupTests`, `CalendarManualCleanupReviewTests`, and cleanup
  coverage in `ReconcileCommandHandlerTests` pass.

## CALACC-05 — Verify mutation, occurrence, and action identity

**Dependencies:** Passing `CALACC-03` ordinary preflight and `CALACC-04` cleanup
preflight behavior.

**Requirements:** `ACCESS-05`, boundary behavior from `ACCESS-07`,
`ACCESS-AC-08`, `ACCESS-AC-12`, `ACCESS-AC-14`, and the mutation portions of
`ACCESS-AC-15`.

**Likely targets if a defect is exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarMutation.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarExecutableActionIdentity.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Application/UseCases/CalendarMutationExecutor.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/EventKitCalendarStore.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/EventKit/EventKitExactEventOccurrenceSelector.swift`

**Work:**

- Verify mutations execute sequentially in supplied plan order.
- Verify every successful action produces local confirmation.
- Verify the first mutation failure stops later actions and reports only
  confirmed counts, failed role, and failure category.
- Verify no rollback occurs.
- Verify ordinary apply performs no post-mutation verification read.
- Verify executable identity includes the physical source or destination
  calendar, exact event identity, recurring occurrence, and ordered action
  position.
- Verify recurring deletion resolves exactly one matching occurrence and fails
  on zero or multiple matches without substitution or inferred success.
- Keep EventKit types and raw identifier mechanics inside the outbound adapter.

- [ ] **CALACC-05-AC1:** Partial mutation results contain no event details or
  provider identifiers.
- [ ] **CALACC-05-AC2:** Ordinary success requires confirmation of every ordered
  action and performs no verification read.
- [ ] **CALACC-05-AC3:** Exact recurring-occurrence resolution has deterministic
  zero, one, and multiple-match coverage.
- [ ] **CALACC-05-AC4:** Physical-calendar, exact-occurrence, or action-order
  changes invalidate reviewed or standing authorization as required.
- [ ] **CALACC-05-V1:** `CalendarMutationExecutorTests`,
  `EventKitExactEventOccurrenceResolverTests`, `CalendarReviewedActionTests`,
  `CalendarManualApplyTests`, `CalendarStandingAuthorizationTests`, and
  `CalendarAutomationPersistenceTests` pass.

## CALACC-06 — Verify disclosure and architecture boundaries

**Dependencies:** Passing `CALACC-02` through `CALACC-05` behavior.

**Requirements:** `ACCESS-06`, `ACCESS-07`, `ACCESS-AC-09`, `ACCESS-AC-10`,
and `ACCESS-AC-11`.

**Likely targets if a defect is exposed:**

- `Sources/CalRelayKit/Features/CalendarRelay/Application/DTOs/CalendarAccess.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarListFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/EventExplanationFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/CLI/CalendarCleanupFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Inbound/App/CalendarManualCleanupFormatter.swift`
- `Sources/CalRelayKit/Features/CalendarRelay/Adapters/Outbound/Persistence/UserDefaultsCalendarAutomationStateStore.swift`

**Work:**

- Verify failures, readiness output, partial results, app inventory, ordinary
  success output, cleanup output, logs, and persisted state omit protected IDs
  and event details.
- Preserve the two narrow ID-disclosure exceptions: successful CLI inventory and
  successful explicitly requested ordinary explanation.
- Verify cleanup review discloses only the transient title, configured role, and
  time range allowed by the specification.
- Verify marker values, selectors, calendar names, titles, IDs, and raw
  configuration are absent from persisted operational state.
- Search EventKit imports and ensure they remain adapter-only.
- Search full-access request capability injection and ensure it remains setup-
  only.
- Add no logging of EventKit objects or calendar content.

- [ ] **CALACC-06-AC1:** Protected-value sentinels are absent from restricted
  outputs and persisted state.
- [ ] **CALACC-06-AC2:** Inventory and ordinary explanation retain only their
  approved disclosure exceptions.
- [ ] **CALACC-06-AC3:** Domain and application interfaces contain no EventKit
  types.
- [ ] **CALACC-06-V1:** `CalendarAccessPrivacyTests`,
  `CalendarListCommandHandlerTests`, `ReconcileCommandHandlerTests`,
  `CalendarAutomationPersistenceTests`, and `CalendarAppBundleMetadataTests`
  pass.

## CALACC-07 — Final integration and handoff

**Dependencies:** Passing acceptance and verification for `CALACC-02` through
`CALACC-06`.

**Work:**

1. Run focused suites while iterating.
2. Run the complete repository gates.
3. Run app-bundle validation if app sources, app resources, or bundle tooling
   changed.
4. Run UI automation only if app UI, accessibility contracts, fake composition,
   or the UI-test harness changed.
5. Perform live EventKit validation only as an explicit manual check using
   dedicated harmless calendars and the stable production app bundle identity.
6. Update project documentation only if observed usage, permission recovery,
   supported behavior, or operational instructions changed.

### Final automated validation

```sh
make format-check
make check
git --no-pager diff HEAD --check
```

### Conditional validation

```sh
make app
make ui-test
```

Run `make app` when app sources, `Resources/CalRelayApp/`, or the app-bundle
script changes. Run `make ui-test` when app UI, accessibility behavior, fake UI
composition, or the UI-test harness changes.

### Explicit manual EventKit validation

- Build and open `.build/CalRelay.app`.
- Verify not-determined authorization prompts only from the setup action.
- Verify denial, revocation, and later recovery provide guidance without
  automatic re-prompting.
- Verify CLI inventory includes approved calendar IDs while app inventory omits
  them.
- Verify ordinary readiness and cleanup against dedicated calendars only.
- Verify a recurring cleanup deletion targets only the selected occurrence.
- Record manual observations separately and never represent them as deterministic
  automated passes.

- [ ] **CALACC-07-AC1:** All fifteen acceptance checks have current passing
  evidence.
- [ ] **CALACC-07-AC2:** No unrelated behavior, dependencies, or accepted
  contracts changed.
- [ ] **CALACC-07-AC3:** Manual EventKit checks use only dedicated harmless
  calendars and disclose no personal calendar data.
- [ ] **CALACC-07-V1:** `make format-check` and `make check` pass.
- [ ] **CALACC-07-V2:** Conditional app and UI checks pass or are recorded as not
  applicable with their scope reason.
- [ ] **CALACC-07-V3:** The final diff is whitespace-clean and preserves
  unrelated workspace changes.

## Risks and mitigations

- **Duplicate implementation:** Historical plans already delivered the access
  slice. Mitigation: require failing current-HEAD evidence before production
  changes.
- **Cross-slice scope creep:** Access behavior collaborates with reconciliation,
  configuration, CLI, and app slices. Mitigation: change those surfaces only
  when an access acceptance check fails and keep the owning accepted contracts
  unchanged.
- **Privacy regression:** Raw identifiers or event details could leak through
  diagnostics or persistence. Mitigation: use sentinel assertions and retain the
  two narrow disclosure exceptions only.
- **Live-calendar risk:** Real EventKit validation can expose or mutate personal
  data. Mitigation: keep automated tests fake-backed and use only dedicated
  harmless calendars for explicit manual checks.
- **Provider convergence ambiguity:** Immediate reads may not reflect confirmed
  ordinary mutations. Mitigation: preserve local confirmation semantics for
  ordinary apply and reserve complete post-mutation verification for cleanup.

## Next executable work

Start with `CALACC-01`: recheck the workspace, execute the current access-focused
suite union, and produce the current acceptance traceability before changing any
production source.