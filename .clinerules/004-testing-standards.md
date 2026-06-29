# Testing standards for Swift macOS projects

Use these rules for automated tests to keep signal high and feedback fast.

For test directory structure and organization, see `009-repo-navigation.md`.

## Test pyramid expectations

- **Must** keep the majority of tests as fast, isolated unit tests with no real I/O.
- **Should** use integration tests sparingly for adapter boundaries that touch persistence, networking, file system, keychain, notifications, or other OS services.
- **Should** add contract tests around important ports/adapters when multiple implementations must honor the same behavior.
- **Must** avoid mixing adapter behavior into domain unit tests.
- **Should** reserve UI tests for user-critical flows, accessibility behavior, and integration that cannot be covered below the UI layer.

## Test quality defaults

- **Must** keep tests deterministic and isolated; avoid hidden reliance on wall clock time, randomness, ambient user defaults, process environment, filesystem state, notification delivery timing, or test order.
- **Should** control time, randomness, filesystem, and network behavior explicitly through fakes, fixtures, dependency injection, or temporary directories.
- **Should** prefer small builders/factories over large shared fixtures when setup starts hiding the behavior under test.
- **Must not** rely on live external services in default local or CI suites.
- **Must not** require real user documents, real keychain state, production endpoints, or developer-specific signing identities for ordinary tests.

## Swift test conventions

- Use the project's configured test framework. Prefer Swift Testing for new projects when available and use XCTest when the project already uses it or Xcode UI testing requires it.
- **Must** name tests by observable behavior, not implementation details.
- **Must** keep assertions focused on observable outcomes.
- **Should** test async behavior with native async tests rather than semaphores or arbitrary sleeps.
- **Must** avoid force unwraps in tests except narrow fixture setup where failure should abort the test immediately.
- **Should** use throwing test methods instead of `try!`.

## Mocks, stubs, and fakes

- **Must** isolate outbound ports in application tests with fakes, stubs, or mocks so orchestration stays deterministic.
- **Must** avoid mocking domain entities or value objects.
- **Should** prefer hand-written fakes for important ports when they make behavior clearer than generic mocking frameworks.
- **Should** use shared contract tests when multiple adapters implement the same important port.

## macOS adapter and UI testing

- **Should** test SwiftUI/AppKit adapters at the thinnest useful boundary, usually view models, presenters, or adapter mapping logic before UI automation.
- **Must** isolate real network, filesystem, database, and OS permission access to explicit integration or UI tests.
- **Should** use temporary directories, in-memory stores, sandbox-safe locations, and fake permission services for tests.
- **Should** keep preview-only sample data separate from production test fixtures unless it is intentionally shared.

## Coverage and regression expectations

- **Must** add or update tests when behavior changes.
- **Should** add regression tests for bugs before fixing them.
- **Should** add edge-case matrix tests when domain invariants, parsers, serializers, or state machines have a broad input space.
- **Should** keep coverage stable or improving; document intentional gaps in PR notes.

## Running tests

- Use focused tests while iterating.
- Run the project-defined full local quality gate before handoff.
- For Swift Package Manager projects, expect `swift test` to be the default unit-test command.
- For Xcode app projects, expect `xcodebuild test` with the project/workspace scheme and a macOS destination to be the authoritative validation command.
