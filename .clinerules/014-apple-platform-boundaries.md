# Apple platform boundaries for macOS apps

Use these rules for macOS-specific UI, lifecycle, permissions, entitlements, sandboxing, and OS integration concerns.

## UI boundaries

- **Must** keep SwiftUI `View`, AppKit view/controller, menu command, scene, and delegate code as inbound adapters.
- **Must not** put business rules or workflow orchestration directly in SwiftUI views, `NSViewController`, `NSWindowController`, app delegates, menu handlers, or notification callbacks.
- **Should** keep presentation state in view models, presenters, or adapter-local state that calls application inbound ports.
- **Must** map UI inputs into application commands/queries before calling use cases.
- **Must** map application results and errors into user-facing UI states at the adapter boundary.

## Main actor and threading

- **Must** perform UI state updates on the main actor.
- **Must not** block the main actor with file I/O, networking, persistence, parsing, indexing, cryptography, or CPU-heavy work.
- **Should** keep `@MainActor` annotations close to UI and presentation adapters unless core semantics truly require main-actor isolation.
- **Should** make cross-actor calls explicit and test important cancellation behavior.

## App lifecycle and composition root

- **Must** keep app startup, scene creation, delegate callbacks, command registration, dependency wiring, and long-lived task startup in app entry points or bootstrap/composition-root modules.
- **Must** keep lifecycle callbacks thin. They should delegate to application ports or adapter services.
- **Should** manage background tasks, timers, file watchers, distributed notifications, and observers with explicit lifecycle ownership and cleanup.
- **Must** avoid unbounded long-lived tasks without cancellation and ownership.

## Sandboxing, entitlements, and permissions

- **Must** treat sandboxing, entitlements, hardened runtime, signing, notarization, and user permissions as explicit platform concerns.
- **Must** document entitlement and permission changes.
- **Must** keep permission prompts and entitlement checks in adapters or bootstrap code.
- **Should** expose permission state to the application layer through ports and DTOs rather than platform APIs.
- **Must** fail safely when permissions are denied, revoked, or unavailable.

## File access and security-scoped resources

- **Must** keep security-scoped bookmark creation, resolution, renewal, and access lifetime management inside file-system adapters.
- **Must** balance calls that start and stop access to security-scoped resources.
- **Must not** pass security-scoped bookmark implementation details into domain entities or use cases.
- **Should** model user-selected files and folders with application-friendly value types.
- **Must** avoid logging full file paths or file contents unless explicitly approved.

## Secrets, keychain, and credentials

- **Must** keep Keychain, Secure Enclave, credential storage, and token refresh mechanics inside outbound adapters.
- **Must** pass only the minimum necessary secret material across boundaries.
- **Must** redact secrets in logs, errors, diagnostics, metrics, and support bundles.
- **Should** prefer token handles, credential IDs, or scoped DTOs over raw secrets when possible.

## Persistence and data migration

- **Must** keep Core Data, SwiftData, SQLite, file formats, cloud sync SDKs, and persistence schemas inside outbound persistence adapters.
- **Must** translate persistence models into domain/application types at adapter boundaries.
- **Should** test migrations with representative data when schema changes can affect users.
- **Must** document migration and rollback implications when persistence changes are user-visible or hard to reverse.

## Notifications, automation, and system services

- **Must** isolate UserNotifications, NotificationCenter, DistributedNotificationCenter, accessibility APIs, Apple events, pasteboard, launch services, login items, agents, helpers, and other OS services behind adapters.
- **Must** avoid placing domain behavior directly in notification observers, delegates, callbacks, or event handlers.
- **Should** unregister observers and invalidate resources with clear lifecycle ownership.
- **Must** validate and sanitize data received from pasteboard, automation, URL schemes, files, or other untrusted system inputs.

## Previews and sample data

- **Must** keep SwiftUI previews and sample data from becoming production dependencies.
- **Should** use fake application ports or preview-specific composition roots for previews.
- **Must not** embed real secrets, private endpoints, personal data, or proprietary user data in previews, fixtures, or sample resources.
