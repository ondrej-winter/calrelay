# 0004. Automate Signed Public-Beta Releases

Date: 2026-09-26
Status: Accepted

## Context

CalRelay needs one public-beta release identity for its command-line and graphical
products, immutable prebuilt artifacts, and independent Homebrew formula and cask
installation. The accepted distribution contract requires Apple Silicon release
builds, Developer ID signing, notarization, an upstream public tap, automatic
qualifying releases, and resumable recovery without replacing published content.

The existing `make app` path is a local development convenience. It assembles an
ad-hoc-signed app outside file-provider workspaces as established by ADR 0002.
Production distribution has stronger toolchain, identity, hardened-runtime,
timestamp, notarization, artifact-retention, and publication requirements. Reusing
the local path for production would blur credential custody and make release
verification difficult to enforce.

Release automation also crosses the source repository, Apple services, and the
`ondrej-winter/homebrew-tap` repository. Those boundaries require explicit
least-privilege identities, protected credentials, serialized publication, and
fail-closed handling of stale or mismatched immutable state.

## Decision

CalRelay will use a protected, automated public-beta release pipeline with these
boundaries:

- The root `VERSION`, one release commit, and its immutable `vX.Y.Z` tag define
  the shared CLI and app release identity.
- The public channel bootstraps explicitly at `v1.0.0`. Automatic releases are
  limited to patch and minor transitions within `1.x`; `2.0.0` requires a later
  explicit product decision and accepted release-policy revision.
- The repository-owned prepare plugin creates the exact version-only release
  commit. The pinned semantic-release 25.0.9 prepare pipeline then re-reads Git
  HEAD and tags that commit, as defined by its versioned
  [`prepare` pipeline](https://github.com/semantic-release/semantic-release/blob/v25.0.9/lib/definitions/plugins.js).
- The protected release job uses GitHub's standard hosted Apple Silicon
  `xcode-27` image. Its ephemeral environment with Xcode 27, Swift 6.4, and the
  macOS 27 SDK builds the exact macOS 26-compatible candidate artifacts.
- Production CLI and app packaging use separate release entry points from the
  local ad-hoc `make app` workflow. Local packaging never imports production
  signing or publication credentials.
- The CLI executable and app use Developer ID Application signing, hardened
  runtime, and secure timestamps. Both are notarized; the app is stapled and
  assessed by Gatekeeper before publication.
- Signing material is imported only into an ephemeral CI keychain and removed on
  every exit path. The Developer Team identifier is a stable, non-secret release
  invariant verified before publication.
- Notarization uses a protected team App Store Connect API key.
- Source and tap publication use one dedicated least-privilege GitHub App. A
  personal access token is not an accepted automated publication credential.
- Release executions share one non-cancelling concurrency queue. The captured
  source revision is checked against remote `master` immediately before source
  publication.
- Signed and notarized candidate bytes are retained across retries. Existing tags,
  assets, checksums, and tap content are accepted only when they match the
  expected immutable state.
- GitHub release assets are published and reverified before the formula and cask
  are updated together in one tap commit.

## External prerequisites

The release pipeline requires the following provisioned resources. Names identify
roles only and do not contain credential values.

### Repositories and branch policy

- Public source repository `ondrej-winter/calrelay`, with protected `master` and
  GitHub immutable releases enabled before bootstrap so published release tags
  and assets cannot be replaced or deleted.
- Public tap repository `ondrej-winter/homebrew-tap`, with a protected default
  branch, no force-push publication, and GitHub App write access.
- A protected `public-beta-release` environment for credential-bearing jobs and
  manual bootstrap or recovery controls.

### Runners

- GitHub's standard hosted Apple Silicon `xcode-27` image, which is in public
  preview as of September 27, 2026. Each job receives an ephemeral VM providing
  macOS 27, Xcode 27, Swift 6.4, the macOS 27 SDK, Homebrew, secure secret
  injection, and ephemeral keychain support; the workflow installs the pinned
  Node runtime explicitly.
- The workflow and production packaging preflight fail closed if the hosted
  image no longer satisfies the required OS, architecture, Xcode, Swift, or SDK
  contract. Preview image drift, capacity, and availability remain external
  release risks that require validation before bootstrap and after image updates.
- A clean Apple Silicon package-test environment for formula/cask install,
  coexistence, upgrade, and ordinary uninstall checks. It may use the release
  runner only when isolation and cleanup are demonstrably equivalent.

### Protected secrets

- `CALRELAY_DEVELOPER_ID_P12` and
  `CALRELAY_DEVELOPER_ID_P12_PASSWORD`.
- `CALRELAY_NOTARY_API_KEY_P8`, `CALRELAY_NOTARY_KEY_ID`, and
  `CALRELAY_NOTARY_ISSUER_ID`.
- `CALRELAY_RELEASE_GITHUB_APP_PRIVATE_KEY`.

### Repository or environment variables

- `CALRELAY_DEVELOPER_TEAM_ID` and `CALRELAY_SIGNING_IDENTITY`.
- `CALRELAY_RELEASE_GITHUB_APP_ID`.
- `CALRELAY_TAP_REPOSITORY`, fixed to `ondrej-winter/homebrew-tap` for the initial
  public beta.

The GitHub App is installed only on the source and tap repositories and receives
only the metadata, contents, and release permissions needed by the authorized
publication stages. The workflow resolves installation scope from the fixed
repository owner and repository names rather than retaining installation IDs as
configuration. Non-qualifying analysis jobs receive none of the protected
signing, notarization, or publication credentials.

## Consequences

### Positive

- Users receive immutable, prebuilt, signed and notarized products rather than
  source builds or locally signed bundles.
- Formula and cask publication cannot diverge at a new version.
- Interrupted releases can resume safely without rebuilding or replacing content.
- Local development remains credential-free and continues to use `make app`.

### Negative

- Public releases depend on GitHub's hosted `xcode-27` preview capacity and image
  compatibility, Apple signing and notarization services, the public tap, and the
  dedicated GitHub App.
- Credential rotation, hosted-runner failure recovery, incomplete-release
  resumption, and compromised-artifact response require maintained operator
  procedures.
- Release automation is intentionally more complex than the local build because it
  must preserve immutable bytes and cross-repository state.

### Neutral

- The app remains unsandboxed while direct canonical configuration-file access is
  required.
- Official Homebrew inclusion and closed-app execution remain separate future
  decisions.
- This ADR records architecture and credential custody; product behavior remains
  owned by `docs/specs/distribution-spec.md`.

## Alternatives considered

| Option | Reason rejected |
| --- | --- |
| Build from source during Homebrew installation | Conflicts with the accepted prebuilt artifact and no-SwiftPM installation contract. |
| Reuse local ad-hoc app packaging for releases | Does not provide Developer ID identity, notarization, secure timestamps, or protected credential handling. |
| Require a dedicated self-hosted Apple Silicon runner | Adds long-lived runner provisioning, isolation, patching, and cleanup responsibilities when the standard hosted `xcode-27` image satisfies the release contract with a fresh VM per job. |
| Publish the formula and cask independently | Can expose a partial release and violate the shared-version contract. |
| Use a personal access token for publication | Provides the wrong custody and least-privilege model for automated cross-repository writes. |
| Rebuild artifacts when retrying a release | Risks different signed bytes under one immutable version. |
| Use a `0.x` main release line with pinned semantic-release 25.0.9 | Its normal main release branch starts at `1.0.0`; representing `master` as `0.x` would classify it as a maintenance branch and require a separate main release branch. |