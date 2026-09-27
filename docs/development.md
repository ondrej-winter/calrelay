# CalRelay development workflow

This page is the canonical local development reference for requirements, build commands, tests, formatting, linting, and package hygiene.

## Requirements

- macOS 26+
- Swift 6.4+
- Xcode 27+ for macOS UI tests
- `make` for the canonical local development commands
- `swift-format` for formatting checks
- SwiftLint for lint checks
- `uvx` for the Fabrica-assisted commit workflow
- Full Calendar access for `CalRelay.app` when prompted by macOS
- Writable Apple Calendar/EventKit calendars for any calendar that CalRelay should mutate

## Build and test

Use the `Makefile` as the canonical local tooling entrypoint:

```sh
make help
make check
make ui-test
make app
make commit
```

`make check` runs linting, a SwiftPM build, the deterministic SwiftPM executable test runner, a synchronized version smoke, and help smoke checks for the root command, calendar inventory, configuration readiness, and reconciliation. The underlying commands remain ordinary SwiftPM commands and can still be run directly when debugging a specific step:

```sh
make format-check
make format
make lint
make build
make test
swift run calrelay --version
swift run calrelay --help
swift run calrelay calendars --help
swift run calrelay config check --help
swift run calrelay reconcile --help
```

`make format-check` and `make format` use the repository `swift-format` configuration. The formatter is available as a separate target so a future formatting-only change can adopt it without mixing mechanical formatting churn into feature work.

`make test` is the local deterministic test gate. It runs `swift run CalRelayKitTests` and does not require real EventKit access, real calendars, `CalRelay.app`, Swift Testing, XCTest, or a separately selected full Xcode toolchain.

`make ui-test` is a separate fake-backed macOS UI smoke lane. It requires full
Xcode at `XCODE_DEVELOPER_DIR` (default:
`/Applications/Xcode.app/Contents/Developer`) and runs the shared
`CalRelayUITests` scheme. The command builds an ad-hoc-signed host with the
separate bundle identifier `dev.owinter.CalRelay.UITestHost`, launches only
explicit deterministic scenarios, and never uses EventKit, requests Calendar or
notification permission, registers launch-at-login, starts wake/timer triggers,
or reads production persistence. The suite covers:

- missing configuration;
- Calendar access unavailable;
- ready-state inventory and ordinary dry run;
- manual-sync review and cancellation;
- migration-cleanup review and cancellation; and
- scheduled-sync authorization with pause/resume.

UI tests intentionally remain outside `make check`. Run them when app sources,
accessibility contracts, fake UI composition, or the UI-test harness changes.
The external DerivedData cache lives under
`~/Library/Caches/dev.owinter.CalRelay/xcode-ui-tests`; the isolated app bundle
lives under `~/Library/Caches/dev.owinter.CalRelay/ui-test-builds` and is linked
at `.build/CalRelayUITestHost.app`. The latest result bundle is
`.build/CalRelayUITests.xcresult`. These caches are disposable and are not
removed by `make clean`.

The package manifest (`Package.swift`) is the source of truth for products, targets, and dependencies. Keep `Package.resolved` committed with intentional dependency resolution updates.
`CalRelayUITests.xcodeproj` owns only the XCTest UI-test bundle and shared scheme;
it does not replace or duplicate the SwiftPM app and library target graph. See
[ADR 0003](adr/0003-use-xctest-only-for-isolated-ui-automation.md).

Run `make commit` to create a Conventional Commit with Fabrica using the repository skill root and configured model. Review the staged changes before invoking it because the command starts a Git commit workflow.

## App bundle

Build the app bundle with:

```sh
make app
```

The signed bundle lives in a workspace-specific directory under
`~/Library/Caches/dev.owinter.CalRelay/builds`; `.build/CalRelay.app` is a symlink.
This keeps file-provider metadata from breaking code signing while preserving
the usual launch path. `make app` recreates the cached bundle and verifies its
signature strictly. `make clean` removes SwiftPM products, not this external
cache. See [ADR 0002](adr/0002-build-local-app-bundles-outside-file-provider-workspaces.md).

Open the built app when you need macOS Calendar permission and EventKit visibility checks:

```sh
open .build/CalRelay.app
```

Real EventKit validation is explicit local work. Use only harmless, dedicated test calendars and never treat live calendar mutation as an ordinary automated check.

## Release policy tooling

The checked-in `0.0.0` version is an unreleased bootstrap baseline. The first
public-beta release is explicitly prepared as `1.0.0`; later automatic releases
are limited to patch and minor transitions within `1.x`. Releasing `2.0.0`
requires an accepted product-policy revision.

Run the deterministic repository-owned policy against the current Git history:

```sh
node scripts/release/release-policy.mjs select
node scripts/release/release-policy.mjs notes
```

The standalone policy helper can model the exact bootstrap in a disposable or
otherwise controlled repository. Its `prepare` command creates a release commit
and tag, so it is for deterministic policy verification rather than a step to run
before semantic-release:

```sh
node scripts/release/release-policy.mjs select --bootstrap
node scripts/release/release-policy.mjs prepare --bootstrap
```

Ordinary semantic-release execution uses the exact Node and semantic-release
versions recorded in `scripts/release/toolchain.json` through
`scripts/release/run-semantic-release.sh`. `.releaserc.json` is the sole
semantic-release configuration artifact; do not add a Node package manifest or
lockfile solely for release automation.

The protected production bootstrap runs semantic-release itself with the
explicit bootstrap flag, from a clean checkout with no release tags:

```sh
scripts/release/run-semantic-release.sh --bootstrap
```

The runner consumes `--bootstrap` and exposes it only to the repository-owned
plugins. It is not forwarded as an unsupported semantic-release CLI option.

## Production release artifacts and resumable state

Local `make app` remains an ad-hoc development build and never reads production
signing credentials. The separate protected production entry point is:

```sh
make release-artifacts
```

It requires the protected credential and identity roles named in ADR 0004:
`CALRELAY_DEVELOPER_ID_P12`, `CALRELAY_DEVELOPER_ID_P12_PASSWORD`,
`CALRELAY_NOTARY_API_KEY_P8`, `CALRELAY_NOTARY_KEY_ID`,
`CALRELAY_NOTARY_ISSUER_ID`, `CALRELAY_DEVELOPER_TEAM_ID`, and
`CALRELAY_SIGNING_IDENTITY`. Do not place their values in repository files, shell
traces, caches, or task handoffs. The command validates the release toolchain,
builds arm64 macOS 26-compatible products, uses an ephemeral keychain, signs and
notarizes both products, staples and assesses the app, and writes immutable
versioned archives plus `candidate-manifest.json` under
`.build/release-artifacts/`. Existing final artifacts are never replaced.

`scripts/release/release-state.mjs` owns deterministic state transitions for a
staged release. Its `create`, `resume`, `advance`, `disable`, and `corrective`
commands preserve exact artifact and source-bundle digests, bind the prepared
release commit to the captured source revision, reject stale or mismatched remote
state, require formula and cask publication together, retain the prior known-good
version until completion, and permit defective-release correction only through a
higher patch. Release-state schema 3 is the source-bound retained-candidate format
that also seals the exact production manifest and release notes; candidate
manifests remain schema 1.

## Homebrew and release workflow validation

Generate formula and cask content only through the repository generator. It
requires the production `candidate-manifest.json` and verifies the artifact bytes
before writing both packages atomically:

```sh
node scripts/release/generate-homebrew-packages.mjs \
  --manifest .build/release-artifacts/candidate-manifest.json \
  --artifacts-directory .build/release-artifacts \
  --output-directory .build/homebrew-packages
```

The protected release workflow runs real Homebrew `style`, `audit`, `fetch`,
install, test, upgrade, reinstall, coexistence, and ordinary uninstall checks on
the clean Apple Silicon release environment. The deterministic local equivalents
and release orchestration fixtures run with:

```sh
swift run CalRelayKitTests \
  DistributionHomebrewPackageTests \
  DistributionReleaseStateTests \
  DistributionReleaseWorkflowTests \
  DistributionReleasePolicyTests
```

When changing release JavaScript or the workflow, also run:

```sh
node --check scripts/release/generate-homebrew-packages.mjs
node --check scripts/release/validate-homebrew-packages.mjs
node --check scripts/release/verify-release-source.mjs
node --check scripts/release/stage-release-candidate.mjs
node --check scripts/release/publish-release.mjs
actionlint .github/workflows/release.yml
```

`actionlint` is an additional provider-aware check and must run in a configured
developer or CI environment; it is not currently a repository-managed dependency.

## Protected release workflow setup and operation

Before the first bootstrap, configure all of the following:

1. Enable GitHub immutable releases for `ondrej-winter/calrelay`, protect
   `master`, and disallow force-push replacement of release history.
2. Keep `ondrej-winter/homebrew-tap` public with protected `master`, no
   force-push publication, and the expected `Formula/` and `Casks/` paths.
3. Create the protected `public-beta-release` environment with required review or
   deployment controls.
4. Provide an ephemeral self-hosted runner labeled `macOS`, `ARM64`, and
   `calrelay-release`, with macOS 27+, Xcode 27, Swift 6.4, Homebrew, `gh`, and
   the pinned Node runtime available.
5. Install the dedicated release GitHub App only on `ondrej-winter/calrelay` and
   `ondrej-winter/homebrew-tap`. Grant only repository contents/release access
   needed for source refs, release assets, and the tap commit.
6. Configure protected secret `CALRELAY_RELEASE_GITHUB_APP_PRIVATE_KEY`; configure
   variable `CALRELAY_RELEASE_GITHUB_APP_ID`; and set
   `CALRELAY_TAP_REPOSITORY` exactly to `ondrej-winter/homebrew-tap`.
7. Configure the signing/notarization secrets and identity variables listed above.

The workflow has one non-cancelling concurrency group. Non-qualifying pushes stop
after the unprivileged analysis job and cannot access signing or publication
credentials. Bootstrap `v1.0.0` manually with:

```sh
gh workflow run release.yml -f bootstrap=true
```

The workflow retains the exact source-bound candidate as the
`release-candidate` Actions artifact for 30 days. To resume an interrupted run,
use the original workflow run ID and do not set `bootstrap`:

```sh
gh workflow run release.yml -f resume_run_id=123456789
```

Resumption never rebuilds the same version. It downloads the retained candidate,
verifies that its source revision and artifact came from the named completed
release workflow run on `ondrej-winter/calrelay` `master`, checks out that captured
revision, and restores the prepared release commit and tag from `source.bundle`.
It then reruns source quality gates and verifies the manifest, artifact digests,
checksums, generated packages, source bundle, and remote state before continuing.
This also permits recovery when interruption happened before the release commit
was published to GitHub. After source publication, a later descendant of `master`
is accepted only when the immutable release tag still identifies the retained
release commit. Mismatched workflow provenance, tags, assets, tap content, or
candidate bytes fail closed. If the Actions artifact has expired or is missing,
do not rebuild the same version; investigate and use the accepted higher-patch
corrective path where applicable.

Real Developer ID, notarization, stapler, and Gatekeeper evidence requires the
protected release environment. The default deterministic suite uses fake tools and
no production credentials or Calendar data.
