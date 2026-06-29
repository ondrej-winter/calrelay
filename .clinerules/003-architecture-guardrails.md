# Hexagonal architecture with vertical slices doctrine for Swift macOS

Use this doctrine as the default architecture standard for the codebase. Organize business capabilities as vertical slices while preserving hexagonal dependency direction inside each slice. Any deviation must be explicitly documented.

## Core principles (non-negotiable)

- **Dependency direction**: All dependencies point inward toward the domain and application core.
- **Vertical slice ownership**: Business capabilities are grouped by feature or use case first, then by hexagonal layer inside that slice.
- **Business logic isolation**: Domain models are pure Swift and independent of UI frameworks, I/O, persistence, networking, and OS services.
- **Explicit boundaries**: Interaction between layers happens only through application-owned protocols and DTOs.
- **Replaceable adapters**: UI, persistence, file system, networking, keychain, notifications, and other OS integrations are swappable without changing the core.

## Vocabulary

- **Domain**: Entities, value objects, domain services, domain events, and domain errors. No UI, I/O, persistence, or infrastructure concerns.
- **Application**: Orchestrates use cases. Defines inbound and outbound ports, coordinates domain behavior, authorization, transactions, and side-effect ordering.
- **Ports**: Application-owned Swift protocols that isolate the core from infrastructure. Inbound ports describe use case entry points; outbound ports describe dependencies such as persistence, file access, notifications, and external APIs.
- **DTOs**: Application boundary types, usually `struct`s, used for commands, queries, results, and settings that cross use-case boundaries.
- **Adapters**: Implement ports at the system edge, including SwiftUI/AppKit UI, command-line entry points, persistence, networking, keychain, file system, and OS services.
- **Composition root**: App startup and dependency wiring. It may live in app entry points, bootstrap modules, or scene/application lifecycle adapters.
- **Feature slice**: A directory or module that owns one business capability or closely related use-case family, including local domain, application, ports, DTOs, adapters, and tests.
- **Shared kernel**: A small optional module for pure domain concepts genuinely reused by multiple slices. It must not become a dumping ground for convenience utilities.

## Dependency rules

Allowed:

- Domain to domain within the same slice or shared kernel.
- Application to its slice domain and shared-kernel domain types.
- Adapters to their slice application ports plus approved domain/application boundary types exposed by those ports.
- Cross-slice collaboration only through another slice's explicit inbound port, published application API, or events handled through application-owned ports.
- Shared kernel to shared kernel only.

Forbidden:

- Domain importing SwiftUI, AppKit, Combine, Core Data, SwiftData, URLSession-specific networking clients, keychain wrappers, logging frameworks, dependency-injection containers, or app lifecycle types.
- Domain depending on application, adapters, infrastructure, or UI code.
- Application depending on adapters, UI frameworks, persistence frameworks, network clients, or OS service SDKs.
- Adapters calling other adapters directly instead of going through application ports.
- SwiftUI views, AppKit controllers, commands, menu handlers, delegates, or notification callbacks orchestrating business workflows directly.
- One slice importing another slice's private domain, application service, DTO, repository, view model, or adapter implementation directly.
- Shared kernel importing from feature slices, application layers, adapters, UI frameworks, or infrastructure.

## Layer responsibilities

### Domain

- Own pure business rules and invariants.
- Use Swift value types, enums, and small domain services where they fit the model.
- Avoid framework imports beyond Swift standard library and Foundation types that are true domain values.
- Expose domain errors and value objects.
- Keep mutation intentional and constrained so invariants remain enforceable.

### Application

- Orchestrate use cases and coordinate domain behavior.
- Define inbound and outbound port protocols.
- Define DTOs for command, query, result, and settings boundaries.
- Own authorization, transaction boundaries, cancellation policy, and side-effect sequencing when they are use-case concerns.
- Keep business invariants in the domain; application validation should focus on command shape, orchestration, permissions, and coordination.

### Adapters

- Implement ports for UI, persistence, networking, file system, keychain, notifications, system APIs, and external SDKs.
- Translate between framework-specific types and application DTOs.
- Own serialization, persistence schemas, view models, controllers, delegate bridges, environment lookups, entitlements, and permission prompts.
- Keep adapter failures translated into application-meaningful errors.

## Composition root and framework isolation

- **Must** keep dependency wiring, service construction, app lifecycle setup, and framework bootstrapping in entry points or dedicated bootstrap/composition-root modules.
- **Must** keep SwiftUI `App`, `Scene`, `View`, AppKit `NSApplicationDelegate`, `NSViewController`, menu command handlers, and notification callbacks at the edge.
- **Must** keep environment/config lookups, secret loading, entitlement assumptions, and permission prompts in adapters or bootstrap modules rather than scattering them through the core.
- **Must not** let dependency-injection containers or service locators leak into domain entities or application use cases.
- **Should** keep `@MainActor` in UI and presentation adapters unless application semantics truly require main-actor isolation.

## Transactions and side effects

- Coordinate transactions, persistence saves, file writes, notifications, and message publication in application use cases or adapter-owned infrastructure boundaries.
- Do not hide persistence saves, network retries, notifications, or file writes inside domain entities.
- Domain events may be modeled in the core, but publication and delivery belong behind outbound ports/adapters.

## Naming conventions

- Use `Ports/` for protocols.
- Use `Adapters/Inbound/` and `Adapters/Outbound/` for adapter implementations.
- Use DTO names by intent: `CreateInvoiceCommand`, `ListInvoicesQuery`, `CreateInvoiceResult`, `StorageSettings`.
- Name port protocols by capability, such as `InvoiceRepositoryPort`, `FileBookmarkStorePort`, or `NotificationSchedulerPort`.

## No-go examples

- Importing SwiftUI or AppKit in `Domain/` or `Application/`.
- Core use cases receiving `NSManagedObject`, SwiftData `ModelContext`, `URLRequest`, `NSImage`, `FileWrapper`, or security-scoped bookmark APIs directly.
- SwiftUI views creating repositories, URL sessions, database contexts, or file-system clients directly.
- Inbound adapters importing domain services and running workflows directly.
- A feature slice importing another slice's repository implementation or view model directly.
- A top-level `Common/`, `Utilities/`, or `Services/` directory accumulating mixed domain, application, UI, and infrastructure behavior.
