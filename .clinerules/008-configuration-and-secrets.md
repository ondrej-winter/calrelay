# Configuration and secrets management

Use these rules to keep runtime configuration explicit, testable, and separated from the domain and application core.

## Ownership and boundaries

- **Must** keep environment variable reads, user defaults access, Info.plist lookups, entitlement checks, keychain access, secret loading, and config file parsing out of domain entities and application use cases.
- **Must** perform runtime configuration loading in adapters, app entry points, bootstrap modules, or composition-root modules.
- **Must** pass validated configuration into application services as explicit constructor arguments, settings DTOs, or port implementations rather than reading global process state inside use cases.
- **Should** keep configuration shape owned by the layer that consumes it: application-owned settings DTOs for core behavior, adapter-owned settings for infrastructure and platform concerns.
- **Should** prefer immutable settings values once startup validation has completed.

## Settings DTOs and ports

- **Must** define settings DTOs with explicit fields and types when configuration crosses an application boundary.
- **Must not** expose environment variable names, UserDefaults keys, Info.plist keys, keychain wrapper types, or SDK-specific config objects through application ports.
- **Should** name settings DTOs by intent, such as `SyncSettings`, `StorageSettings`, `RetryPolicySettings`, or `PermissionPromptSettings`, rather than by source.
- **Should** keep secret values narrowly scoped and avoid passing them through unrelated DTOs or log context.

## Environment, defaults, and app settings

- **Must** keep parsing, defaulting, normalization, migration, and validation for environment-backed or UserDefaults-backed settings inside the adapter or bootstrap path that owns the source.
- **Must** fail fast at startup or adapter construction time when required configuration is missing or invalid.
- **Should** produce clear validation errors that identify the missing or invalid setting without printing secret values.
- **Should** centralize source-specific mechanics such as environment variable names, UserDefaults keys, Info.plist keys, config file paths, and keychain item identifiers in one adapter-owned module per integration.

## Secret safety

- **Must not** commit real secrets, tokens, passwords, private keys, signing credentials, provisioning profiles containing private material, or production credentials.
- **Must not** log, trace, metric-label, signpost, print, or include raw secret values in exception messages.
- **Must** redact secrets before including configuration-derived values in diagnostics.
- **Should** use Keychain or an approved secure storage adapter for user secrets.
- **Should** use placeholders in examples, tests, fixtures, and documentation.

## macOS privacy and permissions

- **Must** treat file access, security-scoped bookmarks, accessibility permissions, automation permissions, contacts, calendars, camera, microphone, screen recording, notifications, and similar capabilities as explicit adapter/platform concerns.
- **Must** document user-visible permissions and entitlement requirements when they change.
- **Must** request permissions at user-appropriate moments and keep permission prompts out of domain/application logic.
- **Should** model permission state through application-friendly DTOs or ports rather than exposing platform APIs directly.

## Validation and testability

- **Must** validate required configuration before starting long-running workers, serving app workflows, scheduling jobs, or performing background sync.
- **Must** cover configuration parsing, migration, and validation with focused tests when defaults, coercion, or secret-source behavior is non-trivial.
- **Should** test application use cases with explicit settings DTOs or fake ports rather than mutating global process state.
- **Should** isolate UserDefaults, temporary files, keychain, and process-environment mutation in tests so state is restored after each test.

## Relationship to neighboring rules

- Use `003-architecture-guardrails.md` for dependency direction, composition-root placement, and ports/adapters boundaries.
- Use `013-logging-conventions.md` for logger structure, safe context fields, and redaction expectations.
- Use `014-apple-platform-boundaries.md` for macOS sandbox, entitlement, permission, lifecycle, and UI boundary rules.
