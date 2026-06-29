# Module structure and file organization

Use these rules to keep files focused, navigable, and easy to maintain in a Swift macOS codebase organized by vertical slices.

## File size heuristics

- Treat line counts as review heuristics, not goals.
- **Should** consider splitting a file once it grows beyond about 300 lines or carries more than one clear responsibility.
- Files above about 500 lines **should** have an intentional reason to remain whole.
- Files above about 700 lines **should usually** be split or accompanied by a documented justification.

## Organization principles

- **Should** prefer cohesion and clear ownership over arbitrary file-count targets.
- **Should** use directories or SwiftPM targets when a concept has multiple responsibilities or is likely to expand.
- **Must** group feature behavior by business capability or use case before introducing broad global layer folders.
- **Should** group related types by responsibility inside the owning slice, not by type alone.
- **Should** keep one primary responsibility per file when splitting code.
- **Must** keep import side effects minimal; importing a module should not perform I/O, start tasks, register global handlers, or perform heavyweight initialization.
- Adapter-specific structure should satisfy the architectural consistency expectations in `003-architecture-guardrails.md`.

## Feature slice mechanics

- **Must** put new business capability code under `Features/<FeatureName>/` or the host project's documented equivalent.
- **Must** keep hexagonal responsibilities visible inside each slice with local `Domain/`, `Application/`, and `Adapters/` directories when the slice needs those responsibilities.
- **Should** omit empty layer directories in very small slices until they are needed, but do not move behavior into the wrong layer just to avoid a directory.
- **Must** keep slice-private types internal by default unless they are intentionally published through an inbound port, application API, domain event, or shared-kernel type.
- **Should** keep cross-slice shared domain concepts in `SharedKernel/` only when at least two slices genuinely need the same concept.
- **Must not** place mixed business behavior in top-level `Common/`, `Utilities/`, `Helpers/`, or `Services/` directories.

## Swift access control and module boundaries

- **Should** use `internal` as the default visibility and expose `public` only for intentional module APIs.
- **Must** keep `public` APIs stable, documented when non-obvious, and covered by tests when behavior matters.
- **Should** use SwiftPM targets or Xcode targets to enforce boundaries when a project is large enough to benefit from physical module separation.
- **Must not** use broad `@testable import` access as a substitute for designing clear public or internal seams.
- **Should** prefer protocol-based seams for ports over exposing concrete adapter implementations.

## File naming conventions

- Feature slice directory: `UpperCamelCase/` named by business capability, such as `InvoiceCapture/`.
- Layer directories: `Domain/`, `Application/`, `Adapters/`.
- Application subdirectories: `UseCases/`, `Ports/`, `DTOs/`.
- Adapter subdirectories: `Inbound/`, `Outbound/`, then specific technology or channel directories such as `SwiftUI/`, `AppKit/`, `Persistence/`, `Networking/`, `FileSystem/`, or `SystemServices/`.
- Main files should use the primary type or purpose, such as `CreateInvoiceUseCase.swift`, `InvoiceRepositoryPort.swift`, `InvoiceListView.swift`, or `CoreDataInvoiceRepository.swift`.
- Avoid catch-all files such as `Utils.swift`, `Helpers.swift`, or `Extensions.swift` unless the scope is intentionally tiny and local to a package.

## Extensions

- **Should** keep extensions close to the type or feature they support.
- **Must** avoid global extensions that add surprising behavior to standard-library, Foundation, SwiftUI, or AppKit types.
- **Should** split large extensions by protocol conformance or responsibility.
- **Must** keep test-only helpers out of production sources.

## Splitting strategies

- When a split is warranted, separate files by responsibility, domain concept, slice ownership, adapter concern, or protocol conformance rather than arbitrary file-count targets.
- Preserve public APIs only when they are intentionally stable.
- Document compatibility surfaces when moving public types between modules or targets.

## When not to split

- Files under 200 lines that are cohesive and focused can remain as-is.
- Simple value objects, enums, or DTOs can be grouped when they form one clear concept family.
- Tightly coupled logic that would be harder to understand when separated can remain together.
- Stable leaf files with a single clear responsibility and no growth pressure can remain whole even if they are not tiny.
