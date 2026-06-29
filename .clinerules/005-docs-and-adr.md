# Documentation rules: README updates, ADRs, changelog notes, API docs

Use these rules to keep documentation consistent and architectural decisions traceable.

## README updates

- **Must** update `README.md` when behavior, configuration, setup, supported macOS versions, signing requirements, entitlements, permissions, or usage changes.
- **Should** add short usage examples when new command-line flags, app workflows, automation hooks, or extension points are introduced.
- **Must** document new configuration keys, environment variables, defaults, permissions, entitlements, and required user consent flows.
- **Must** link from the main README to the canonical settings reference under `docs/` when the project has an explicit runtime settings model.
- **Should** document Xcode version, Swift version, macOS deployment target, package manager workflow, and local quality gate commands when they are project-relevant.
- In-code comment and documentation standards are covered in `012-documentation-standards.md`.

## Configuration and permission references

- **Must** maintain a dedicated settings or operations reference under `docs/` when runtime settings, permissions, entitlements, or signing requirements are non-trivial.
- **Must** list every setting with its source, field name, type or format, required/default behavior, safe example value, secret/redaction status, and runtime usage.
- **Must** document required macOS permissions and entitlements with safe explanations of why the app needs them.
- **Must** keep configuration docs, examples, settings model fields, entitlements, and tests synchronized.
- **Should** keep README configuration content brief and link to dedicated references instead of duplicating full settings tables.

## ADRs

- **Must** create an ADR when a decision materially affects architecture, dependencies, persistence, platform APIs, entitlements, signing, sandboxing, or boundaries.
- Put architectural rationale in ADRs rather than source comments.
- **Should** record alternatives considered when choosing between SwiftUI, AppKit, SwiftData, Core Data, external dependencies, helper tools, agents, or system extensions.

## Changelog notes

- **Must** call out breaking changes explicitly.
- **Must** record release-facing changes in `CHANGELOG.md` when that file exists.
- **Should** include a concise changelog-style summary in PR notes when `CHANGELOG.md` is not maintained.

## API and user-facing docs

- **Should** document public ports, command-line interfaces, automation interfaces, URL schemes, file formats, and plugin extension points.
- **Must** keep DTO field meanings aligned with domain terminology.
- **Should** document caller-visible error semantics, idempotency, retry expectations, cancellation behavior, and privacy implications for external interfaces when relevant.
