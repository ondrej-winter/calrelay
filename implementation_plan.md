# Implementation Plan

[Overview]
Consolidate `CalRelayCore` into fewer, more cohesive source files while preserving the existing Calendar Relay behavior and public API contracts.

`CalRelayCore` currently contains one vertical slice, `Features/CalendarRelay`, with small domain model files, separate projection/planning helpers, and a 205-line application use case that mixes orchestration with private run-context, calendar-resolution, projection, and write-validation helpers. The consolidation should reduce source-file sprawl, clarify ownership of domain concepts, and make the reconciliation workflow easier to review without changing inputs, outputs, ordering, cancellation behavior, or adapter-facing contracts.

The implementation must follow the existing Swift Package Manager target layout, hexagonal boundaries, and vertical-slice conventions. Domain types must remain pure Swift/Foundation concepts. Application code must continue to depend inward on domain concepts and expose stable ports/DTOs to adapters. The existing contract suite in `Tests/CalRelayContractTests/CalRelayContractTests.swift` is the primary behavioral safety net and must pass after each major consolidation step.

[Types]
The type changes are organizational only: preserve existing public type names, initializers, stored properties, protocol requirements, and error cases while relocating related declarations into cohesive files.

Public types that must remain source-compatible:

- `CalendarRelaySettings: Equatable, Sendable`
  - Fields: `hubCalendar: HubCalendarSettings`, `personalPrefix: String`, `syncWindowDays: Int`, `workCalendars: [WorkCalendarSettings]`
  - Validation remains delegated to `SettingsValidator.validate(_:)`.
- `HubCalendarSettings: Equatable, Sendable`
  - Field: `calendar: CalendarSelector`
- `WorkCalendarSettings: Equatable, Sendable`
  - Fields: `name: String`, `prefix: String`, `calendar: CalendarSelector`
- `SettingsValidationError: Error, Equatable, CustomStringConvertible, Sendable`
  - Preserve all cases and descriptions exactly unless tests reveal a required formatting update.
- `SettingsValidator`
  - Preserve public static function `validate(_ settings: CalendarRelaySettings) throws`.
- `CalendarStorePort: Sendable`
  - Preserve async requirements: `listCalendars`, `events(in:from:to:)`, `createEvent`, `deleteEvent`.
- `RelayCalendar: Equatable, Identifiable, Sendable`
  - Fields: `id`, `title`, `sourceTitle`, `isWritable`.
- `CalendarIdentity: Equatable, Hashable, Sendable`
  - Fields: `id`, `title`, `sourceTitle`.
- `CalendarSelector: Equatable, Sendable`
  - Fields: `sourceTitle`, `calendarTitle`.
- `CalendarEventIdentity: Equatable, Sendable`
  - Fields: `id`, `calendar`.
- `CalendarEvent: Equatable, Identifiable, Sendable`
  - Fields: `id`, `calendar`, `title`, `start`, `end`, `isAllDay`, `availability`, `status`.
  - Computed property: `identity: CalendarEventIdentity`.
- `CalendarEventProjection: Equatable, Sendable`
  - Fields: `destinationCalendar`, `title`, `start`, `end`, `isAllDay`.
- `EventAvailability: Equatable, Sendable, CustomStringConvertible`
  - Preserve cases and descriptions.
- `EventStatus: Equatable, Sendable, CustomStringConvertible`
  - Preserve cases and descriptions.
- `VisibleEventKey: Equatable, Hashable, Sendable`
  - Preserve public initializer from fields and `init(event:)` if kept public.
- `ReconciliationPlan: Equatable, Sendable`
  - Fields: `creates: [CalendarEventProjection]`, `deletes: [CalendarEvent]`.
- `EventInclusionReason: Equatable, Sendable`
  - Preserve all cases.
- `EventInclusionPolicy`
  - Preserve `includes(_:) -> Bool` and `evaluate(_:) -> EventInclusionReason`.
- `WorkCalendarProjectionTarget: Equatable, Sendable`
  - Fields: `settings: WorkCalendarSettings`, `calendar: CalendarIdentity`.
- `WorkToHubProjector`
  - Preserve `project(events:from:to:) -> [CalendarEventProjection]`.
- `HubToWorkProjector`
  - Preserve `project(hubEvents:to:personalPrefix:) -> [CalendarEventProjection]`.
- `ReconciliationPlanner`
  - Preserve both overloads of `plan`.
- `ReconcileCalendarsError: Error, Equatable, CustomStringConvertible, Sendable`
  - Preserve all cases and descriptions.
- `ReconcileCalendarsUseCase: Sendable`
  - Preserve initializer `init(calendarStore:)` and public async methods `dryRun`, `explain`, and `apply`.
- `ReconciliationExplanation` and `CandidateEventExplanation`
  - Preserve fields and initializers.

New internal/private helper type recommended:

```swift
struct ManagedEventTitlePolicy: Sendable {
    let managedPrefixes: Set<String>

    func isManagedProjection(_ event: CalendarEvent) -> Bool
    func hasAnyBracketedPrefix(_ event: CalendarEvent) -> Bool
    func isRelayedWorkBlocker(_ event: CalendarEvent) -> Bool
}
```

This type must preserve current behavior:

- Managed projections are events whose title starts with any configured work prefix or the personal prefix.
- Bracketed-prefix events are events whose title starts with `[` and contains `]` anywhere in the title.
- Relayed work blockers are events that have any bracketed prefix or are managed projections.

[Files]
The file modifications consolidate small declarations by domain concept and extract application orchestration support from the main use-case file.

New files to create:

- `Sources/CalRelayCore/Features/CalendarRelay/Domain/CalendarModel.swift`
  - Purpose: Own calendar reference and selector types.
  - Move declarations from:
    - `Domain/Entities/RelayCalendar.swift`
    - `Domain/ValueObjects/CalendarIdentity.swift`
    - `Domain/ValueObjects/CalendarSelector.swift`
    - `Domain/ValueObjects/CalendarEventIdentity.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/EventModel.swift`
  - Purpose: Own event state, event entity, projection DTO, and visible-key model.
  - Move declarations from:
    - `Domain/Entities/CalendarEvent.swift`
    - `Domain/Projections/CalendarEventProjection.swift`
    - `Domain/ValueObjects/EventAvailability.swift`
    - `Domain/ValueObjects/EventStatus.swift`
    - `Domain/ValueObjects/VisibleEventKey.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Projections/CalendarProjection.swift`
  - Purpose: Own work-to-hub and hub-to-work projection logic plus target DTO.
  - Move declarations from:
    - `Domain/Projections/WorkToHubProjector.swift`
    - `Domain/Projections/HubToWorkProjector.swift`
    - `Domain/Projections/WorkCalendarProjectionTarget.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Application/UseCases/CalendarRelayRunContext.swift`
  - Purpose: Own private/internal run-context data structures currently at the bottom of `ReconcileCalendarsUseCase.swift`.
- `Sources/CalRelayCore/Features/CalendarRelay/Application/UseCases/ManagedEventTitlePolicy.swift`
  - Purpose: Own managed-prefix and relayed-work-blocker classification logic shared by planning and reconciliation orchestration.

Existing files to modify:

- `Sources/CalRelayCore/Features/CalendarRelay/Application/UseCases/ReconcileCalendarsUseCase.swift`
  - Keep public API and high-level orchestration.
  - Remove moved private structs.
  - Replace duplicated title-prefix helper functions with `ManagedEventTitlePolicy`.
  - Optionally split implementation with private extensions for loading context, planning, and write validation if this improves readability without broadening scope.
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Planning/ReconciliationPlan.swift`
  - Keep `ReconciliationPlan`; optionally also move `ReconciliationPlanner` into this file if the resulting file remains cohesive and readable.
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Planning/ReconciliationPlanner.swift`
  - If not merged into `ReconciliationPlan.swift`, update it to use `ManagedEventTitlePolicy` or the chosen shared title-policy helper.
- `Sources/CalRelayCore/Features/CalendarRelay/Application/DTOs/CalendarRelaySettings.swift`
  - Preserve content unless formatting or minimal helper extraction is needed. Do not change validation semantics.
- `Tests/CalRelayContractTests/CalRelayContractTests.swift`
  - Avoid modifying expectations. Only update imports or test organization if required by access-control changes; preferably no test edits.

Files to delete after declarations are moved and builds pass:

- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Entities/RelayCalendar.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/ValueObjects/CalendarIdentity.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/ValueObjects/CalendarSelector.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/ValueObjects/CalendarEventIdentity.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Entities/CalendarEvent.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Projections/CalendarEventProjection.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/ValueObjects/EventAvailability.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/ValueObjects/EventStatus.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/ValueObjects/VisibleEventKey.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Projections/WorkToHubProjector.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Projections/HubToWorkProjector.swift`
- `Sources/CalRelayCore/Features/CalendarRelay/Domain/Projections/WorkCalendarProjectionTarget.swift`

Configuration file updates:

- No `Package.swift` target changes are expected because SwiftPM compiles all Swift files under `Sources/CalRelayCore`.
- No dependency manifest changes are expected.
- No README or docs updates are expected because behavior, setup, configuration, and public usage remain unchanged.

[Functions]
Function modifications should preserve public signatures and observable behavior while moving helper logic into cohesive locations.

New functions/methods:

- `ManagedEventTitlePolicy.isManagedProjection(_ event: CalendarEvent) -> Bool`
  - File: `Sources/CalRelayCore/Features/CalendarRelay/Application/UseCases/ManagedEventTitlePolicy.swift` or a domain planning file if made public/internal at domain level.
  - Purpose: Replace duplicate `managedPrefixes.contains { event.title.hasPrefix($0) }` checks.
- `ManagedEventTitlePolicy.hasAnyBracketedPrefix(_ event: CalendarEvent) -> Bool`
  - Purpose: Encapsulate current `title.hasPrefix("[") && title.contains("]")` behavior.
- `ManagedEventTitlePolicy.isRelayedWorkBlocker(_ event: CalendarEvent) -> Bool`
  - Purpose: Encapsulate the current work-blocker rule used before work-to-hub projection and for work-calendar stale deletion.
- Optional private extension methods on `ReconcileCalendarsUseCase`:
  - `loadRunContext(settings:now:) async throws -> ReconciliationRunContext`
  - `plan(settings:now:) async throws -> PlannedRun`
  - `validateWritableCalendars(for:calendarsByID:) throws`
  - `resolve(_:from:) throws -> ResolvedCalendar`
  - Keep signatures equivalent to current private methods unless extraction requires `fileprivate` or `internal` access.

Modified functions:

- `ReconcileCalendarsUseCase.plan(settings:now:)`
  - Replace inline `isRelayedWorkBlocker(event, managedPrefixes:)` calls with a local `ManagedEventTitlePolicy(managedPrefixes: context.managedPrefixes)`.
  - Preserve ordering of `expectedHubEvents`, `expectedHubCalendarEvents`, `expectedWorkEvents`, `hubPlan`, `workPlan`, and combined `ReconciliationPlan`.
- `ReconcileCalendarsUseCase.loadRunContext(settings:now:)`
  - May move to a private extension or helper file.
  - Preserve validation before calendar listing, cancellation checks after listing and between per-calendar event loads, sync-window calculation, and calendar resolution semantics.
- `ReconcileCalendarsUseCase.apply(settings:now:)`
  - Preserve write validation before mutation.
  - Preserve create loop before delete loop and cancellation checks inside both loops.
- `ReconciliationPlanner.plan(expected:existing:managedPrefixes:)`
  - May delegate to `ManagedEventTitlePolicy.isManagedProjection` or keep local helper if making policy application-layer-only is cleaner.
  - Preserve create/delete calculation and ordering.
- `HubToWorkProjector.project(hubEvents:to:personalPrefix:)`
  - Move file only; preserve projection semantics exactly.
- `WorkToHubProjector.project(events:from:to:)`
  - Move file only; preserve projection semantics exactly.
- `SettingsValidator.validate(_:)`
  - No semantic change. If touched, preserve validation order because thrown errors are observable.

Removed functions:

- `ReconcileCalendarsUseCase.isRelayedWorkBlocker(_:managedPrefixes:)`
  - Replacement: `ManagedEventTitlePolicy.isRelayedWorkBlocker(_:)`.
- `ReconcileCalendarsUseCase.hasBracketedPrefix(_:)`
  - Replacement: `ManagedEventTitlePolicy.hasAnyBracketedPrefix(_:)`.
- `ReconcileCalendarsUseCase.isManagedProjection(_:managedPrefixes:)`
  - Replacement: `ManagedEventTitlePolicy.isManagedProjection(_:)`.
- `ReconciliationPlanner.isManaged(_:by:)`
  - Replacement: either `ManagedEventTitlePolicy.isManagedProjection(_:)` or a renamed private helper if policy cannot be shared without violating layer boundaries.

[Classes]
There are no Swift classes in `CalRelayCore`; this plan modifies structs, enums, protocols, and static helper enums only.

New classes:

- None.

Modified classes:

- None.

Removed classes:

- None.

[Dependencies]
No dependency changes are required.

`CalRelayCore` should remain a pure SwiftPM target with no new package dependencies. Do not add a dependency-injection framework, formatting tool, test helper package, or runtime library. `Foundation` imports should remain only where `Date` or other Foundation types are required. No `Package.swift` or `Package.resolved` updates are expected.

[Testing]
Testing should prove behavior preservation using the existing contract suite and SwiftPM build/test checks.

Baseline and iterative validation:

- Run `swift test | cat` before editing to confirm the current suite state.
- After moving model declarations, run `swift test | cat`.
- After consolidating projection/planning declarations, run `swift test | cat`.
- After refactoring `ReconcileCalendarsUseCase`, run `swift test | cat`.
- After introducing/unifying `ManagedEventTitlePolicy`, run `swift test | cat`.
- Run final `swift build | cat` and `swift test | cat` before handoff.

Behavior specifically guarded by existing tests:

- Settings validation error cases and descriptions.
- Event inclusion/exclusion reasons.
- Visible event key distinctness for adjacent repeated-title meetings.
- Work-to-hub projection titles and filtering.
- Hub-to-work routing, remote-prefix preservation, and personal-prefix application.
- Reconciliation create/delete planning and preservation of unknown prefixes in hub calendars.
- Dry-run non-mutation behavior.
- Calendar resolution errors for missing/ambiguous selectors.
- Read-only apply validation before mutation.
- Apply create/delete ordering and identity deletion.
- Relayed work blocker handling and prevention of double-prefixing.
- Cancellation propagation.
- Explanation output content.

Do not change test expectations unless a compile-only access-control issue requires moving helper tests to public API equivalents. If a test fails after a refactor, treat it as a behavior regression until proven otherwise.

[Implementation Order]
The implementation should proceed in small validated steps to keep the consolidation reviewable and behavior-preserving.

1. Run baseline validation with `swift test | cat`.
2. Create `Domain/CalendarModel.swift`, move `RelayCalendar`, `CalendarIdentity`, `CalendarSelector`, and `CalendarEventIdentity` into it, delete the original tiny files, and run `swift test | cat`.
3. Create `Domain/EventModel.swift`, move `CalendarEvent`, `CalendarEventProjection`, `EventAvailability`, `EventStatus`, and `VisibleEventKey` into it, delete the original tiny files, and run `swift test | cat`.
4. Create `Domain/Projections/CalendarProjection.swift`, move `WorkToHubProjector`, `HubToWorkProjector`, and `WorkCalendarProjectionTarget` into it, delete the original projection files, and run `swift test | cat`.
5. Optionally merge `ReconciliationPlanner` into `Domain/Planning/ReconciliationPlan.swift` if the merged file remains readable; otherwise keep the existing planner file. Run `swift test | cat` either way after any move.
6. Extract the private run-context declarations from `ReconcileCalendarsUseCase.swift` into `Application/UseCases/CalendarRelayRunContext.swift`. Use access control (`internal` or `fileprivate`) that compiles within the target while avoiding public exposure. Run `swift test | cat`.
7. Add `Application/UseCases/ManagedEventTitlePolicy.swift` and update `ReconcileCalendarsUseCase` and, if appropriate, `ReconciliationPlanner` to use it. Preserve current prefix semantics exactly. Run `swift test | cat`.
8. Review `ReconcileCalendarsUseCase.swift` for any remaining mixed responsibilities. If readability improves, move private helper methods into same-type private extensions in additional files; avoid creating abstractions that do not reduce complexity. Run `swift test | cat`.
9. Run formatting/linting only if project commands are clear and non-invasive; otherwise rely on Swift compiler formatting compatibility. Run final `swift build | cat` and `swift test | cat`.
10. Provide handoff notes listing changed/deleted files, public API preservation, validation commands, and any intentional consolidation choices.