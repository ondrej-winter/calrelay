# CalRelay agent instructions

This file is the canonical repository policy for coding agents working on
CalRelay. Paths and commands below are relative to the repository root.
Keep repository-specific policy here, Cline-specific execution mechanics in
`.clinerules/`, and task procedures in `.agents/skills/`.

CalRelay-specific architecture, product safety, toolchain, and project-state
constraints here take precedence over generic defaults in reusable skills.

## Repository and project state

- CalRelay is a local macOS Swift CLI and app that relays availability
  blockers across Apple Calendar/EventKit-visible calendars.
- The package requires macOS 26+ and Swift 6.2+ and is managed with Swift
  Package Manager. Use the repository `Makefile` as the canonical local
  tooling entrypoint.
- `Package.swift` is the source of truth for products, targets, supported
  platforms, and dependencies. Keep `Package.resolved` committed and update
  it only with intentional dependency resolution changes.
- Start behavioral changes at `docs/specs/README.md`. Its capability-owned
  specifications are the accepted product contracts. The older umbrella
  specifications are compatibility stubs, not authority for new behavior.
- The project is an EventKit MVP. Do not add direct provider APIs, OAuth,
  persistent identity mapping, hidden metadata, or broader automation
  without an explicitly accepted design change.

## Working discipline

- Inspect Git status before editing and preserve existing staged, unstaged,
  and untracked work. Re-read affected files if the workspace changes.
- Read relevant sources, the owning accepted specification, and adjacent
  tests before editing.
- Search for the closest existing implementation pattern before introducing a
  new abstraction, package shape, or convention.
- Make the smallest change that fully satisfies the request. Do not mix
  unrelated cleanup into the same change.
- State material assumptions and resolve conflicting requirements rather
  than silently guessing.
- Preserve generated or synchronized artifacts by editing their source of
  truth.
- During read-only reviews or planning, do not run commands that resolve
  dependencies, build products, format files, mutate calendars, or otherwise
  change local state.
- Validate narrowly while iterating, then run the complete repository
  gate before handoff for code or tooling changes.
- Do not claim a pass for a check that was not run. Report skipped or blocked
  validation and its reason.

## Repository map

- `Sources/CalRelayKit/Features/CalendarRelay/`: the shared calendar relay
  capability, organized as a vertical slice with `Domain/`, `Application/`,
  and `Adapters/`.
- `Sources/CalRelayKit/.../Domain/`: pure models, policies, projections,
  and reconciliation plans.
- `Sources/CalRelayKit/.../Application/`: use cases, ports, DTOs, validation,
  cancellation, and side-effect ordering.
- `Sources/CalRelayKit/.../Adapters/Inbound/`: reusable CLI handlers and
  formatters, configuration selection, and YAML loading.
- `Sources/CalRelayKit/.../Adapters/Outbound/EventKit/`: the EventKit
  calendar store and platform type mapping.
- `Sources/CalRelayCLI/`: the thin ArgumentParser executable wrapper and
  composition edge.
- `Sources/CalRelayApp/`: the SwiftUI macOS app, UI, lifecycle, and app
  composition edge.
- `Tests/CalRelayKitTests/`: the consolidated deterministic executable
  test runner and fake-backed tests.
- `Resources/CalRelayApp/`: app bundle metadata, including the Calendar
  usage description.
- `docs/specs/`: accepted behavior contracts. Start with the index.
- `docs/configuration.md`, `docs/development.md`,
  `docs/repository-layout.md`, and `docs/manual-validation.md`: user and
  maintainer references.
- `scripts/`: app-bundle build scripts.

## Architecture

CalRelay uses hexagonal architecture within feature-owned vertical slices.

- Dependencies point inward toward the domain and application core.
- Domain code remains deterministic and does not import EventKit, SwiftUI,
  AppKit, ArgumentParser, Yams, filesystem mechanics, or live OS services.
- Application code orchestrates use cases and owns ports and boundary DTOs.
  It does not construct or import concrete adapters.
- Port signatures use domain or application types, not `EKKevent`,
  `EKEventStore`, SwiftUI views, ArgumentParser types, or Yams decoding
  models.
- Inbound adapters validate and normalize external input, map it to
  application types, call the application boundary, and translate the result.
- Outbound adapters implement application-owned ports and own EventKit,
  filesystem, serialization, permission, and integration-specific failures.
- Keep `CalRelayKit` as the reusable integration point. CLI and app targets
  should be thin wrappers for option parsing, presentation, UI, lifecycle,
  and dependency wiring.
- SwiftUI views, menu handlers, app lifecycle callbacks, and notification
  callbacks remain thin and do not orchestrate reconciliation directly.
- Keep `@MainActor` close to UI and presentation code. Do not block the
  main actor with EventKit, filesystem, parsing, or other potentially slow work.
- Cross-slice collaboration uses published application boundaries, not another
  slice's private use cases or adapters.
- Avoid broad `Common`, `Utilities`, or `Services` directories that obscure
  feature ownership.

## Product and mutation safety

- Reconciliation is dry-run by default. Calendar creates and deletes occur
  only for a user-initiated run with the explicit `--apply` flag.
- Validate settings, calendar resolution, and all target calendars
  required by the plan before the first mutation. Fail safely when
  permission is unavailable or a target is read-only.
- Never delete or mutate an unprefixed original work/client event.
  Deletion is limited to stale prefixed projections selected by the
  accepted reconciliation rules.
- Preserve unknown prefixed hub events by default; they may be remote
  blockers from another machine.
- Treat generated events as disposable projections. Keep visible-set
  reconciliation, idempotency, and the accepted equality and routing rules
  unless the owning specification is explicitly revised.
- Do not create, migrate, modify, or overwrite user configuration
  silently. Do not search arbitrary directories for configuration. The
  default is `~/.config/calrelay/config.yaml`; `--config` is the explicit
  override.
- Preserve the bundle identifier `dev.owinter.CalRelay` unless an explicit
  migration is approved.
- Do not add automatic reconciliation, EventKit listening, login items,
  helpers, LaunchAgents, signing/entitlement changes, or background-only
  behavior without the approval and ADR gates in `docs/specs/macos-app-spec.md`.

## Swift conventions

- Use `UpperCamelCase` for types and `lowerCamelCase` for functions,
  methods, properties, parameters, and enum cases.
- Name files for their primary type or responsibility. Name behavioral tests
  with `test<behavior>()`-style method names when practical.
- Prefer `struct` value types for DTOs, settings, results, and domain values
  unless reference identity is required. Use protocols for ports and
  application-owned contracts.
- Keep public boundaries explicitly typed. Avoid `Any`, unchecked casts,
  force casts, and force unwraps except in narrow, deliberate adapter shims
  or test fixture setup.
- Use async/await for asynchronous boundaries. Preserve and test
  cancellation when work may continue across EventKit or other OS calls.
- Raise layer-appropriate errors and translate framework errors at adapter
  boundaries when the caller should not depend on the framework type.
- Use the repository `.swift-format` configuration and `.swiftlint.yml`. Do not
  weaken lint rules, concurrency safety, or warnings just to make a change
  pass.

## Configuration, privacy, and secrets

- Keep filesystem path resolution, environment access, YAML parsing,
  UserDefaults, platform permissions, and signing concerns in adapters or
  composition edges. Pass validated immutable values or DTOs inward.
- Do not commit, print, log, trace, or metric-label real credentials,
  tokens, private keys, signing material, authorization headers, raw YAML,
  calendar content, or EventKit object dumps.
- Treat calendar names and event titles as personal data. Explicit
  user-framing `dry-run` and `--explain` output may show them locally, but
  they should not be added to persistent logs, telemetry, fixtures, or docs.
- Keep permission prompts and EventKit authorization state at the
  platform edge. Fail safely when access is denied, restricted,
  write-only, revoked, or otherwise unavailable.
- Use safe placeholders in documentation and tests. Use harmless, dedicated
  local calendars for explicit Mac manual validation.

## Tests

- Use the repository's custom SwiftPM executable test runner. `make test`
  runs `swift run CalRelayKitTests`. Do not substitute `swift test`,
  XCTest, or Swift Testing without an explicit request to migrate the test
  infrastructure.
- New test suites must provide a `runAll()` style entry point and be wired into
  `Tests/CalRelayKitTests/Main.swift`; the runner does not auto-discover
  tests.
- Keep default tests fast, deterministic, isolated, offline, and independent
  of real EventKit access, Calendar permission, real calendars, wall-clock
  time, and shared developer state.
- Use hand-written fakes for application ports. Do not mock domain values
  or put live OS behavior in domain/application tests.
- Add or update tests when behavior changes. Add a regression test before
  or alongside a bug fix when practical.
- Focus a suite with `swift run CalRelayKitTests <SuiteName>` when iterating.
- Reserve real EventKit, app bundle, and permission checks for explicit,
  user-authorized manual validation with harmless test calendars. Do not
  run `swift run calrelay reconcile --apply` or any other calendar-mutating
  workflow as ordinary automated validation.

## Documentation

- Update the capability-owned accepted specification when product behavior
  changes. If a request conflicts with an accepted specification or requires
  resolving an open decision, stop and obtain explicit approval before
  implementation.
- Update `README.md` and the owning reference under `docs/` when usage,
  configuration, permissions, supported versions, operations, build, or
  developer workflows change.
- Keep `README.md` brief and link to canonical details in `docs/` instead of
  duplicating long references.
- Use an ADR for durable architecture, dependency, persistence, security,
  signing, entitlement, or lifecycle decisions. The macOS app specification
  explicitly requires an ADR before closed-app operation.
  Preserve historical decisions by superseding them rather than deleting.
- Keep rationale in ADRs, usage in project docs, contracts in
  specifications, and implementation details in code.
- Call out breaking changes explicitly.

## Validation

Install or select a toolchain that satisfies `docs/development.md`. The
repository does not provide a dependency installer.

Focus checks while iterating, for example:

```sh
swift run CalRelayKitTests CalRelayContractTests
swift run calrelay --help
swift run calrelay reconcile --help
```

For Swift source, test, package, script, or tooling changes, run the local
gate:

```sh
make format-check
make check
```

`make check` runs strict SwiftLint, `swift build`, the deterministic
test runner, and a `calrelay --help` smoke check. It does not run
`format-check`. `make format` modifies Swift files in place; inspect the
diff and rerun the checks after using it.

Run `make app` when app sources, `Resources/CalRelayApp/`, or the bundle
script change. Building the app is not a substitute for user-authorized
manual EventKit validation.

For documentation-only changes, verify referenced paths and commands, and run:

```sh
git --no-pager diff --check
```

Run a configured Markdown formatter if the repository adds one. There is no
Markdown formatter configured at the time this policy was written.

Real EventKit checks, `CalRelay.app` permission flows, and calendar mutation
are opt-in manual validation. They require explicit user authorization and
harmless, dedicated test calendars. Follow `docs/manual-validation.md`.

Do not disable lint rules, weaken warnings, skip test suites, or add ad hoc
flags to conceal failures. Fix root causes or report unrelated pre-existing
failures clearly.

## Command and Git safety

- Do not run commands that modify Git's index, refs, or history, including
  `git add`, `git restore --staged`, `git commit`, and `git reset`, unless the
  user explicitly requests that exact operation. Leave agent-created changes
  unstaged.
- Do not run `swift package resolve`, `make resolve`, or other network-backed
  dependency updates unless the task requires a dependency change.
- Do not pipe remote downloads directly into a shell or interpreter.
- Treat paths, refs, branch names, and interpolated search text as untrusted;
  quote or validate them and never use `eval`-style command construction.
- Preview or dry-run destructive actions where practical and scope them to
  explicit targets. Never use hard reset or discard unrelated user work.

## Task procedures

Task-specific procedures live under `.agents/skills/`. Before starting a task,
identify and follow the most specific matching `SKILL.md`. This file
remains the authority when a generic procedure conflicts with CalRelay.

- Use `.agents/skills/using-agnostic-software-development-skills/SKILL.md` for
  skill discovery.
