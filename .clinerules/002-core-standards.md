# Swift coding standards: naming, typing, errors, concurrency, logging

Use these rules for all Swift code in the project to keep behavior predictable and reviews lightweight.

## Naming

- **Types, protocols, actors, enums, structs, and classes**: `UpperCamelCase` nouns or noun phrases.
- **Functions and methods**: `lowerCamelCase` verbs or verb phrases.
- **Properties, variables, constants, enum cases, and parameters**: `lowerCamelCase`.
- **Files**: use the primary type or responsibility name, such as `CreateInvoiceUseCase.swift` or `InvoiceRepositoryPort.swift`.
- **Feature directories**: use `UpperCamelCase` business capability names such as `InvoiceCapture/`.
- **Tests**: name test methods for behavior, such as `testCreatesInvoiceWhenCommandIsValid()`.

## Formatting

- Use the project-configured formatter when present, such as `swift-format` or an Xcode formatting workflow.
- Use SwiftLint only when the project already configures it or the user explicitly asks to introduce it.
- Prefer explicit, readable code over clever one-liners.
- Keep access control explicit where it clarifies API boundaries.

## Typing and API contracts

- Public types, public methods, ports, DTOs, and application/domain boundary types **must** have clear explicit signatures.
- Prefer `struct` value types for DTOs, commands, queries, results, and value objects unless reference identity is required.
- Prefer protocols for ports and application-owned contracts.
- Keep transport schemas, SwiftUI/AppKit types, persistence models, and external SDK types inside adapters.
- Avoid `Any`, `AnyObject`, unchecked casts, force casts, and force unwraps outside narrow adapter shims or test setup.
- Prefer precise optionals over sentinel values. `nil` must mean legitimate absence, not an unmodeled error.
- Prefer enums with associated values for closed sets and state machines.

## Swift-specific defaults

- Prefer immutable `let` bindings over `var` when mutation is not needed.
- Prefer value semantics for domain concepts unless reference semantics model real identity or lifecycle.
- Keep initializers explicit about invariants and invalid states.
- Use `Result` only when it improves composition; prefer throwing functions for ordinary failure propagation.
- Avoid global mutable state. If shared mutable state is required, isolate it behind an actor, dependency-injected service, or adapter boundary.
- Do not hide side effects in computed properties.
- Avoid adding dependencies for functionality that Swift, Foundation, or platform frameworks already provide adequately.

## Concurrency

- Use Swift structured concurrency (`async`/`await`, `TaskGroup`, actors) for new asynchronous code unless a framework requires callbacks, delegates, Combine, or Operation queues.
- **Must** handle cancellation deliberately in long-running tasks and I/O workflows.
- **Must not** block the main actor with disk, network, database, or CPU-heavy work.
- **Must** isolate UI updates on the main actor.
- **Should** keep actor isolation and sendability clear at application and adapter boundaries.
- Avoid unstructured `Task {}` creation except at explicit boundaries such as UI events, app lifecycle hooks, or adapter bridging.

## Boundary behavior

- Validate and normalize external inputs at adapter boundaries before calling application ports.
- Keep mapping between external schemas and application DTOs or port-approved domain types inside adapters.
- Do not leak SwiftUI `View`, AppKit view/controller, Core Data, SwiftData, URLSession, keychain, or file-permission types into domain/application APIs.
- For broader boundary doctrine, see `003-architecture-guardrails.md` and `014-apple-platform-boundaries.md`.

## Error handling

- Use layer-appropriate `Error` types rather than generic `NSError` or stringly typed failures.
- In `Domain/` and `Application/`, define domain/application-specific errors.
- In adapters, translate framework and SDK errors into application-meaningful failures at the boundary.
- Preserve context without exposing secrets, raw file contents, or private user data.
- Do not use `try!`, force unwraps, or `fatalError` in production code except for impossible states with a documented invariant.
- Do not swallow cancellation errors or task cancellation signals during cleanup.

## Logging

- Use the project-configured logging mechanism instead of `print()` in production code.
- Prefer Apple's `Logger` from `os` for app/runtime logs when no other logging stack is configured.
- Never log secrets, tokens, private file contents, personal data, or raw user documents.
- Keep logging setup centralized.
- For logger naming, privacy, levels, and implementation mechanics, see `013-logging-conventions.md`.
