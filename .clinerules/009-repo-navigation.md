# Repository navigation guidelines for Swift macOS vertical-slice projects

Use these guidelines to organize and navigate Swift macOS projects that combine hexagonal architecture with vertical slices.

## Standard directory structure

### Swift Package Manager layout

Prefer a `Sources/<PackageOrAppName>/` layout for packages, command-line tools, and reusable app modules.

```text
Sources/<PackageOrAppName>/
├── Features/
│   └── <FeatureName>/
│       ├── Domain/
│       ├── Application/
│       │   ├── UseCases/
│       │   ├── Ports/
│       │   └── DTOs/
│       └── Adapters/
│           ├── Inbound/
│           │   ├── SwiftUI/
│           │   ├── AppKit/
│           │   └── CLI/
│           └── Outbound/
│               ├── Persistence/
│               ├── Networking/
│               ├── FileSystem/
│               └── SystemServices/
├── SharedKernel/
└── Bootstrap/
```

### Xcode app layout

For Xcode app projects, keep app lifecycle, assets, previews, entitlements, and signing files in the app target's documented locations. Apply the same feature-slice model inside the app target or extracted Swift packages.

```text
<AppName>/
├── App/
│   ├── <AppName>App.swift
│   ├── AppDelegate.swift
│   └── CompositionRoot.swift
├── Features/
│   └── <FeatureName>/
│       ├── Domain/
│       ├── Application/
│       └── Adapters/
├── SharedKernel/
├── Resources/
├── Assets.xcassets/
└── <AppName>.entitlements
```

If a legacy project already uses top-level `Domain/`, `Application/`, and `Adapters/`, keep changes incremental. New capabilities should move toward the feature-slice structure unless the project documents a different slice root.

### Test layout pattern

```text
Tests/
├── Unit/
│   └── Features/
│       └── <FeatureName>/
│           ├── Domain/
│           ├── Application/
│           └── Adapters/
├── Integration/
│   └── Features/
│       └── <FeatureName>/
│           └── Adapters/
└── UI/
```

Xcode app projects may use `<AppName>Tests/` and `<AppName>UITests/`. Test directories should mirror source ownership where practical. UI tests may be organized by user flow instead of strict source mirroring.

## Documentation and configuration

- `README.md`: onboarding, setup, usage, supported macOS versions, and validation commands
- `docs/`: ADRs, design docs, operations notes, permission references, and troubleshooting
- `Package.swift`: SwiftPM package, target, and dependency configuration when present
- `<ProjectName>.xcodeproj` or `<WorkspaceName>.xcworkspace`: app project/workspace configuration when present
- `*.entitlements`: sandbox and capability configuration
- `Info.plist`: app metadata and platform capability declarations when present
- `Resources/` and `Assets.xcassets/`: bundled assets and localized resources

## Search workflow

Prefer cross-platform tools such as IDE search, `rg`, and `rg --files` for local exploration.

For reusable command recipes and the step-by-step process for generating a project-specific navigation guide, use `workflows/update-repo-navigation.md`.

## Navigation principles

- **Slice discovery**: start in `Features/<FeatureName>/` to understand one business capability end to end.
- **Layer isolation**: code in a slice's `Domain/` should not import from that slice's `Application/` or `Adapters/`.
- **Port discovery**: look in the owning slice's `Application/Ports/` to understand system boundaries.
- **DTO discovery**: look in the owning slice's `Application/DTOs/` for command, query, settings, and result types.
- **UI entry points**: find app lifecycle and wiring in `App/`, `Bootstrap/`, `CompositionRoot.swift`, SwiftUI `App`, scene definitions, AppKit delegates, or project-documented equivalents.
- **Packaging clues**: start with `Package.swift`, Xcode schemes, project/workspace files, and CI configuration to identify targets, supported Swift versions, and deployment targets.
- **Test mirroring**: navigate tests using the same path as the source file or feature under test.
