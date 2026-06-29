# Tooling and CI conventions

Use the project-configured Swift and macOS tooling. Discover existing commands before introducing new tools.

## Toolchain defaults

- Prefer Swift Package Manager for package structure, dependency management, and reusable modules when it fits the project.
- Use Xcode projects or workspaces when app targets, signing, entitlements, asset catalogs, Interface Builder files, previews, or UI tests require them.
- Keep supported Swift, Xcode, and macOS deployment versions documented in project configuration and README when relevant.
- Do not introduce new formatters, linters, package managers, dependency-injection frameworks, or build systems without explicit user approval.

## Local quality gate

- **Must** run focused checks while iterating and the full project-defined quality gate before handoff.
- **Should** use `swift build` and `swift test` for SwiftPM package validation.
- **Should** use `xcodebuild build` and `xcodebuild test` for Xcode app/workspace validation.
- **Should** use the project-configured formatter and linter when present, such as `swift-format` or SwiftLint.
- **Must** use non-interactive command variants suitable for automation.

## Common validation commands

Use the commands that match the host project. Examples:

```sh
swift build
swift test
xcodebuild -scheme <SchemeName> -destination 'platform=macOS' build
xcodebuild -scheme <SchemeName> -destination 'platform=macOS' test
swift-format lint --recursive .
swiftlint
```

For workspaces, include the workspace explicitly:

```sh
xcodebuild -workspace <WorkspaceName>.xcworkspace -scheme <SchemeName> -destination 'platform=macOS' test
```

## Expectations

- Generated code **must** build with the configured project or package command.
- Behavior changes **must** add or update tests and run relevant impacted suites.
- Formatting and linting **must** follow project configuration when present.
- Do not disable warnings, lint rules, strict concurrency checks, or tests unless explicitly requested; prefer fixing root causes.
- CI failures must be fixed at the root cause.

## Dependency and project hygiene

- Dependency changes **must** update the relevant manifest and lockfile together when a lockfile exists, such as `Package.swift` and `Package.resolved`.
- Xcode project, workspace, scheme, build setting, entitlement, and Info.plist changes **must** be intentional and documented when they affect build, signing, permissions, or runtime behavior.
- **Should** pin dependency versions according to the project's existing policy.
- **Must** avoid adding dependencies for small utilities that can be implemented clearly with the standard library or Foundation.

## Architecture validation

- If a change crosses layers, include tests or review evidence that verify boundary adherence, such as ports being invoked and adapters being wired correctly.
- Document any intentional rule exceptions in the PR description and handoff notes.

## CI notes

- CI should validate with a clean checkout and the documented Xcode/Swift toolchain.
- UI tests, signing-sensitive tests, or permission-sensitive tests should be isolated and documented so ordinary unit tests remain fast and reliable.
- For flaky or slow tests, document the reason and mitigation in handoff notes.
