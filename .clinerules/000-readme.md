# How this Swift macOS ruleset is structured

## Structure and ordering

- Files in `.clinerules/` are **active** rules.
- This ruleset is an **opinionated reusable profile** for Swift macOS projects using hexagonal architecture with vertical slices and Cline.
- Rule files use sortable three-digit prefixes to keep the reading order stable.
- Each file should focus on a single theme such as core standards, architecture, testing, tooling, or platform boundaries.

## Opinionated defaults

- Prefer Swift Package Manager for packages, shared modules, and command-line tooling.
- Use Xcode projects or workspaces when app targets, signing, entitlements, assets, previews, or UI tests require them.
- Use Swift's native type system, value semantics, protocol-oriented boundaries, and structured concurrency deliberately.
- Prefer SwiftUI for new UI when it fits the product and deployment target; use AppKit where macOS-specific control, lifecycle, or interoperability requires it.
- Keep UI frameworks, persistence frameworks, network clients, keychain access, file-system permissions, and OS services inside adapters or bootstrap code.
- Follow hexagonal architecture with vertical feature slices, inward-pointing dependencies, and explicit protocol-based ports/adapters boundaries.

## Rule precedence and conflict resolution

- Treat rules marked as **hard constraints** or **non-negotiable** as highest priority within `.clinerules/`.
- Explicit overrides beat implicit interpretation. When a later module intentionally sharpens an earlier rule, it should say so directly.
- More specific rules take precedence over broader rules on the same topic.
- **Must** statements take precedence over **Should** statements.
- If two rules with the same strength and scope still conflict, use file order only as a last-resort tiebreaker, then update the ruleset to make precedence explicit.
- Any intentional deviation must be documented in ADR/PR notes.

## Reusable-asset portability

- Keep this ruleset copyable into another repository without assuming a specific local folder workflow beyond `.clinerules/` itself.
- Do not require repository-specific maintenance conventions such as sibling archive folders inside reusable rule content.
- If a host repository wants local enable/disable mechanics, document them in repo-specific maintainer docs rather than in the reusable rules themselves.

## Adding or updating rules

- Prefer small, focused rule files rather than large monoliths.
- Use **Must/Should** language for clarity and consistency.
- When adding a new module, update this README and keep the sortable prefix order obvious and stable.

## Rule authoring standards

- Keep each module focused on one primary topic with a clearly implied owner.
- Avoid restating requirements owned by another module unless the later module adds stricter or more specific constraints.
- Prefer one requirement per bullet so review discussions can reference a single rule precisely.
- Use **Must** only for review-blocking requirements.
- Use **Should** for strong defaults that may allow justified exceptions.
- When step-by-step guidance already exists in a skill, keep the rule focused on policy and reference the skill by name.
- When a later module intentionally overrides or sharpens an earlier rule, make that override explicit.

## Scope

These rules apply to Swift macOS apps, utilities, and supporting packages using hexagonal architecture with vertical slices unless explicitly stated otherwise.

## Project-specific customization

For project-specific navigation and structure details:

1. Use the workflow in `workflows/update-repo-navigation.md` to generate a current map, or follow the same steps manually if the workflow file is not bundled.
2. Store project-specific documentation in `docs/` or the project root.
3. Keep `.clinerules/` generic and portable across projects.

## Enforcement and automation matrix

Use this map to keep "Must" rules enforceable rather than merely advisory.

| Rule area                        | Primary enforcement                                              | Secondary enforcement                  |
| -------------------------------- | ---------------------------------------------------------------- | -------------------------------------- |
| Naming, formatting, style        | Project-configured formatter, SwiftLint, Swift compiler warnings | PR review                              |
| Type contracts and API drift     | `swift build`, `swift test`, or `xcodebuild build/test`          | PR review                              |
| Behavior changes and regressions | Unit, integration, and UI tests                                  | Targeted regression and contract tests |
| Architecture boundaries          | Review-enforced against `003-architecture-guardrails.md`         | Optional boundary audit scripts        |
| macOS platform boundaries        | Review-enforced against `014-apple-platform-boundaries.md`       | Manual app behavior checks             |
| Configuration and secrets        | Review-enforced against `008-configuration-and-secrets.md`       | Focused config tests                   |
| Docs/ADR/changelog updates       | Review-enforced via PR checklist                                 | Release checklist                      |
| Logging conventions              | Review-enforced against `013-logging-conventions.md`             | Runtime log sampling                   |
| Command execution safety         | Process-enforced via `999-command-execution-safety.md`           | PR review                              |
