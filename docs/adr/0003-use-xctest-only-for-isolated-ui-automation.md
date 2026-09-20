# 0003. Use XCTest Only for Isolated UI Automation

Date: 2026-09-20
Status: Accepted

## Context

CalRelay's existing test gate is a deterministic SwiftPM executable that covers
domain, application, adapter-boundary, CLI-support, and contract behavior without
XCTest or live macOS services. Replacing that runner with XCTest would add a broad
toolchain migration without improving its isolation or product coverage.

Some repetitive macOS control-panel workflows are nevertheless most credible when
driven through the accessibility hierarchy. XCUITest requires an Xcode test bundle
and application host, while real Calendar permission, EventKit provider behavior,
login/wake lifecycle, notifications, and provider convergence remain dependent on
local macOS state and cannot become deterministic automated checks.

The production app bundle identifier is also the Calendar permission identity.
Using it for fake UI automation would risk permission prompts, shared persistence,
login-item registration, notifications, or real calendar mutation.

## Decision

Keep `Package.swift` authoritative and retain the custom SwiftPM executable as the
primary logic gate. Use XCTest/XCUITest only for a separate fake-backed macOS UI
smoke lane implemented by `CalRelayUITests.xcodeproj`.

The UI tests launch an ad-hoc-signed host with bundle identifier
`dev.owinter.CalRelay.UITestHost`. An explicit launch argument selects deterministic
in-memory settings, authorization, calendar, and automation-state adapters and a
test-only window presentation seam. In this mode, configuration observation,
EventKit, Calendar permission requests, notifications, launch-at-login, wake/timer
triggers, automatic mutation attempts, and production persistence are disabled.
Unknown or missing scenario values fail closed to the missing-configuration state
rather than falling back to live composition.

`make ui-test` remains separate from `make check` until the Xcode lane has proved
stable enough for an explicit pre-merge or default-gate decision. Real macOS and
EventKit integration continue to be validated through `docs/manual-validation.md`.

## Consequences

### Positive

- Critical control-panel states, accessibility identifiers, review sheets,
  cancellation, and pause/resume workflows receive repeatable end-to-end coverage.
- The production Calendar permission identity and local calendars are never used
  by automated UI tests.
- SwiftPM remains the source of truth for application products, reusable targets,
  dependencies, and the fast deterministic gate.
- Manual validation can focus on real TCC, EventKit, provider, notification, and
  lifecycle behavior instead of repeating deterministic presentation checks.

### Negative

- Full Xcode is required for the slower UI lane, and the repository carries a
  minimal Xcode project in addition to `Package.swift`.
- The isolated host needs explicit test-only composition and AppKit window wiring
  that production launch paths must not use.
- XCUITest execution is slower and more environment-sensitive than the SwiftPM
  executable test runner, so it is not yet part of `make check`.

### Neutral

- The Xcode project owns only the UI-test bundle and scheme; it does not define a
  second application target graph.
- UI-test bundles and DerivedData use workspace-keyed directories under
  `~/Library/Caches/dev.owinter.CalRelay` to avoid file-provider signing failures,
  following the constraint recorded in [ADR 0002](./0002-build-local-app-bundles-outside-file-provider-workspaces.md).
- Real Calendar mutation, recurring-event behavior, provider propagation, and
  login/wake/notification behavior remain manual acceptance evidence.

## Alternatives considered

| Option | Reason rejected |
| --- | --- |
| Migrate all tests to XCTest or Swift Testing | Broadly replaces a working deterministic gate and adds no value for non-UI logic. |
| Build a complete Xcode app target alongside SwiftPM | Duplicates target, dependency, and build configuration sources of truth. |
| Run UI tests against `dev.owinter.CalRelay` | Risks production permission state, persistence, login items, notifications, and real calendars. |
| Automate real EventKit and TCC acceptance | Depends on mutable machine state and can prompt for permission or mutate personal data. |
| Keep every GUI workflow manual | Repeats deterministic state and review checks and leaves accessibility regressions uncovered. |