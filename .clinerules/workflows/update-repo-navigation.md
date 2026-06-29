# Workflow: update repo navigation

Use this workflow when adapting the reusable Swift macOS hexagonal vertical-slice rules to a specific project.

## Goal

Produce a short, project-specific navigation guide outside `.clinerules/` so contributors can quickly find package roots, app targets, feature slices, entry points, adapters, platform resources, and tests.

When documenting reusable navigation workflows, prefer cross-platform examples based on IDE search or `rg` and `rg --files`.

## Recommended output location

- `docs/repo-navigation.md`
- or another discoverable project-owned path near the main developer docs

## Steps

1. Identify package roots, app targets, and module boundaries such as `Sources/<PackageName>/`, `<AppName>/`, or project-documented equivalents.
2. Locate entry points and composition-root/bootstrap files such as SwiftUI `App`, AppKit delegates, scene setup, `CompositionRoot.swift`, and CLI entry points.
3. Map Xcode project, workspace, schemes, SwiftPM targets, app extensions, helper tools, and test targets.
4. Map the feature slices under the documented slice root, commonly `Features/`.
5. For each important slice, map the hexagonal layers it owns:
   - `Domain/`
   - `Application/UseCases/`
   - `Application/Ports/`
   - `Application/DTOs/`
   - `Adapters/Inbound/`
   - `Adapters/Outbound/`
6. Map shared kernel, composition-root, adapter-only infrastructure, resources, assets, entitlements, Info.plist files, and configuration files.
7. Map the test layout, including unit, integration, UI, snapshot, preview, and contract tests when present.
8. Record the most useful project-specific search commands for slices, ports, adapters, entry points, resources, entitlements, and tests.
9. Save the navigation guide outside `.clinerules/` and update it whenever the structure changes significantly.

## Suggested template

```md
# Project navigation

## Package roots and app targets

- `Sources/<PackageName>/`
- `<AppName>/`

## Entry points and composition root

- `<AppName>/<AppName>App.swift`
- `<AppName>/App/CompositionRoot.swift`
- `<AppName>/App/AppDelegate.swift`

## Feature slices

- `<AppName>/Features/<FeatureName>/`
  - `Domain/`
  - `Application/UseCases/`
  - `Application/Ports/`
  - `Application/DTOs/`
  - `Adapters/Inbound/`
  - `Adapters/Outbound/`

## Shared kernel and bootstrap

- `<AppName>/SharedKernel/`
- `<AppName>/App/`
- `<AppName>/Bootstrap/`

## Platform resources

- `<AppName>/Assets.xcassets/`
- `<AppName>/<AppName>.entitlements`
- `<AppName>/Info.plist`

## Tests

- Unit: `<AppName>Tests/` or `Tests/Unit/`
- Integration: `Tests/Integration/`
- UI: `<AppName>UITests/` or `Tests/UI/`

## Useful search commands

- `rg --files | rg '(^|/)Features/'`
- `rg 'protocol .*Port|UseCase|Command|Query|Result'`
- `rg --files | rg 'Application/(Ports|DTOs|UseCases)'`
- `rg --files | rg 'Adapters/(Inbound|Outbound)'`
- `rg --files -g 'Package.swift' -g '*.xcodeproj' -g '*.xcworkspace'`
- `rg --files | rg '(App|AppDelegate|CompositionRoot)\.swift$'`
- `rg --files | rg '\.(entitlements|plist)$'`
```
