# CalRelay agent instructions

This file is the canonical repository operating policy for coding agents working
on CalRelay. Paths and commands are relative to the repository root.

Keep product contracts in `docs/specs/`, project references in `docs/`, reusable
task procedures in `.agents/skills/`, and Cline-specific mechanics in
`.clinerules/`. Do not duplicate those sources here.

## Authority and context loading

- Always read this file before working in the repository.
- Product behavior is defined by the accepted capability specifications indexed
  in `docs/specs/README.md`; implementation does not override those contracts.
- For a feature, behavioral bug fix, behavior-preserving review, or product
  documentation change, read the specification index and the owning
  specification before planning or editing.
- When a task crosses capability boundaries, read each affected owning
  specification. Do not load unrelated specifications by default.
- Purely mechanical changes do not require product specifications unless
  inspection reveals a possible behavioral impact.
- If a request conflicts with an accepted specification or requires an open
  product decision, surface the conflict and obtain explicit approval before
  changing the contract and implementation.
- Repository-specific rules here take precedence over generic reusable skills.
  Follow `.clinerules/` for Cline-only execution mechanics.
- Use `docs/development.md` for toolchain and commands,
  `docs/repository-layout.md` for navigation, and `docs/configuration.md` for
  user configuration.

## Working discipline

- Inspect Git status before editing. Preserve existing staged, unstaged, and
  untracked work, and leave agent-created changes unstaged unless the user asks
  for an exact Git operation.
- Re-read affected files and Git status when the workspace changes during a task.
  Do not overwrite or restore concurrent work you do not own.
- Read relevant sources, adjacent tests, and established patterns before
  introducing a new abstraction, package shape, or convention.
- Make the smallest change that fully satisfies the request. Do not mix
  unrelated cleanup into the same change.
- State material assumptions and resolve conflicting requirements rather
  than silently guessing.
- Edit generated or synchronized artifacts through their source of truth when
  one exists.
- During read-only reviews or planning, do not run commands that resolve
  dependencies, build products, format files, mutate calendars, or otherwise
  change local state.
- Validate narrowly while iterating, then run the complete repository
  gate before handoff for code or tooling changes.
- Do not claim a pass for a check that was not run. Report skipped or blocked
  validation and its reason.

## Stable architecture boundaries

CalRelay uses hexagonal architecture within feature-owned vertical slices.
See `docs/repository-layout.md` and the cross-slice rules in
`docs/specs/README.md` for the canonical map and product-facing boundaries.

- Dependencies point inward toward the domain and application core.
- Domain code remains deterministic and does not import EventKit, SwiftUI,
  AppKit, ArgumentParser, Yams, filesystem mechanics, or live OS services.
- Application code orchestrates use cases and owns ports and boundary DTOs.
  It does not construct or import concrete adapters.
- Adapter and composition code owns framework types, I/O mechanics, platform
  permissions, external format mapping, and integration-specific failures.
- Port signatures use domain or application types rather than EventKit, UI,
  command-parser, serialization-library, or other adapter-specific types.
- Keep `CalRelayKit` as the reusable integration point. CLI and app targets
  should be thin wrappers for option parsing, presentation, UI, lifecycle,
  and dependency wiring.
- SwiftUI views, menu handlers, app lifecycle callbacks, and notification
  callbacks remain thin and do not orchestrate reconciliation directly.
- Keep `@MainActor` close to UI and presentation code. Do not block the
  main actor with EventKit, filesystem, parsing, or other potentially slow work.
- Cross-slice collaboration uses published application boundaries, not another
  slice's private use cases or adapters.

## Privacy and local-system safety

- Exact mutation, ownership, permission, configuration, and lifecycle behavior
  belongs to the owning accepted specification; do not add competing rules here.
- Treat credentials, tokens, private keys, signing material, authorization
  headers, raw configuration, calendar content, and EventKit object dumps as
  sensitive. Do not include them in committed artifacts, persistent logs,
  telemetry, metrics, fixtures, documentation, or task handoffs.
- Treat calendar names and event titles as personal data. Use safe placeholders
  in tests, examples, and documentation.
- Keep permission prompts and platform authorization state at adapter or
  composition boundaries.
- Use harmless, dedicated local calendars for explicit Mac manual validation.

## Tests and Swift quality

- Use the repository's custom SwiftPM executable test runner. `make test`
  runs `swift run CalRelayKitTests`; do not substitute `swift test`, XCTest, or
  Swift Testing without an explicit migration request.
- New suites provide a `runAll()` entry point and are registered in
  `Tests/CalRelayKitTests/Main.swift`; tests are not auto-discovered.
- When focusing a suite, use an exact suite name registered in
  `Tests/CalRelayKitTests/Main.swift`.
- Keep default tests fast, deterministic, isolated, offline, fake-backed, and
  independent of EventKit, real calendars, wall-clock time, and shared developer
  state.
- Add or update tests for behavior changes and regression fixes when practical.
- Follow the repository `.swift-format` and `.swiftlint.yml` configuration. Do
  not weaken checks, concurrency safety, or warnings to make a change pass.

## Documentation and decisions

- Update the owning accepted specification when product behavior changes, and
  update the relevant project reference when usage, configuration, permissions,
  supported versions, build, or operational workflows change.
- Keep `README.md` brief and link to canonical detail under `docs/`.
- Use an ADR for durable architecture, dependency, persistence, security,
  signing, entitlement, or lifecycle decisions. Supersede historical decisions
  rather than deleting them.
- Keep rationale in ADRs, usage in project docs, contracts in
  specifications, and implementation details in code.
- Call out breaking changes explicitly.

## Validation

- Use `docs/development.md` and the `Makefile` as the canonical validation guide.
- For Swift source, tests, package, scripts, or tooling changes, run:

```sh
make format-check
make check
```

- Run `make app` when app sources, `Resources/CalRelayApp/`, or the app-bundle
  script changes.
- For documentation-only changes, verify referenced paths and commands, then
  run:

```sh
git --no-pager diff HEAD --check
```

- There is currently no configured Markdown formatter.
- Do not use real EventKit or calendar mutation as an ordinary automated check.
- Fix validation failures at their cause or report unrelated pre-existing
  failures clearly; do not conceal them with ad hoc flags or skipped suites.

## Command and Git safety

- Do not run commands that modify Git's index, refs, or history, including
  `git add`, `git restore --staged`, `git commit`, and `git reset`, unless the
  user explicitly requests that exact operation.
- Do not run `swift package resolve`, `make resolve`, or other network-backed
  dependency updates unless the task requires an intentional dependency change.
- Do not pipe remote downloads directly into a shell or interpreter.
- Treat paths, refs, branch names, and interpolated search text as untrusted;
  quote or validate them and never use `eval`-style command construction.
- Preview destructive operations where practical, scope them to explicit
  targets, and never discard unrelated user work.

## Task procedures

- Before starting a task, identify and follow the most specific matching
  procedure under `.agents/skills/`.
- Use `.agents/skills/using-agnostic-software-development-skills/SKILL.md` for
  skill discovery.
- This file remains authoritative when a generic procedure conflicts with
  CalRelay repository policy.
