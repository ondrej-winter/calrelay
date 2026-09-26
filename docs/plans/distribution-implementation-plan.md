# Distribution implementation plan

## Plan record

- **Status:** Ready for repository implementation. External release rollout is
  blocked until the required public tap, runners, credentials, signing identity,
  and GitHub App are provisioned.
- **Prepared:** September 26, 2026.
- **Canonical requirements:**
  [`../specs/distribution-spec.md`](../specs/distribution-spec.md), revision 3,
  accepted September 26, 2026.
- **Related accepted contracts:**
  [`../specs/cli-spec.md`](../specs/cli-spec.md),
  [`../specs/macos-app-spec.md`](../specs/macos-app-spec.md),
  [`../specs/calendar-access-spec.md`](../specs/calendar-access-spec.md), and
  [`../specs/configuration-spec.md`](../specs/configuration-spec.md).
- **Plan scope:** Version identity, release policy, production artifacts,
  signing and notarization, Homebrew packages, release automation, recovery,
  security, documentation, and public-beta rollout.

## Outcome

Implement the accepted public-beta distribution contract so CalRelay can:

1. derive one release identity for the CLI, app, source tag, formula, and cask;
2. publish immutable Apple Silicon CLI and app artifacts built with the required
   toolchain and macOS 26 deployment target;
3. sign and notarize both products, with a stapled app ticket and normal
   Gatekeeper verification;
4. install the CLI and app independently or together through the public
   `ondrej-winter/tap` Homebrew tap;
5. select and publish qualifying `1.x` releases automatically and atomically;
6. resume interrupted releases without replacing immutable content; and
7. bootstrap `v1.0.0` manually, then prove a later qualifying `master` push
   releases automatically through the same gate.

## Current-state basis

- The repository has no root `VERSION`, release tags, `.releaserc.json`, GitHub
  Actions workflows, production release scripts, or Homebrew definitions.
- `calrelay --version` is not implemented.
- `Resources/CalRelayApp/Info.plist` hard-codes short version `0.1.0` and bundle
  version `1`.
- `Package.swift` declares Swift tools 6.2 rather than the required 6.4.
- `scripts/build-calrelay-app.sh` builds an ad-hoc-signed local development app;
  it does not create a Developer ID signed and notarized distribution artifact.
- The local environment provides Apple Silicon, macOS 27, Xcode 27, Swift 6.4,
  and the macOS 27 SDK.
- The accepted distribution specification references
  `docs/adr/0004-automate-signed-public-beta-releases.md`, but that ADR and its
  index entry are absent.
- The public `ondrej-winter/homebrew-tap` URL currently returns 404. It may be
  absent or non-public; authenticated repository state was not available during
  planning.
- Local and remote tag inspection found no published version tags.

## Scope boundaries

### In scope

- Root release version and deterministic app build version.
- CLI `--version` behavior.
- Semantic-release selection and release-note generation.
- Resumable and immutable release-state handling.
- Production CLI and app packaging, signing, notarization, and verification.
- Formula and cask generation, validation, coexistence, upgrades, and ordinary
  uninstallation.
- Secure GitHub Actions orchestration and cross-repository tap publication.
- Deterministic release-policy, failure, privacy, and recovery tests.
- User installation and release-operator documentation.
- Manual `v1.0.0` bootstrap and evidence from one later automatic release.

### Out of scope

- Official `homebrew/core` or `homebrew/cask` inclusion.
- Intel or universal artifacts.
- Source-built Homebrew installation.
- Explicit `brew tap` plus short installation commands.
- App Sandbox adoption while direct canonical configuration access is required.
- A self-update mechanism.
- A destructive cask `zap` operation.
- Automatic reversal of calendar mutations after a package rollback or
  corrective release.
- Real Calendar data or EventKit mutation in routine release automation.

## Implementation constraints and assumptions

1. SwiftPM remains the product and dependency source of truth.
2. `.releaserc.json` remains the only semantic-release configuration artifact;
   no `package.json`, JavaScript lockfile, or `CHANGELOG.md` is introduced solely
   for release automation.
3. Repository-owned release logic is implemented in locally testable tools;
   GitHub Actions remains a thin orchestrator.
4. Local ad-hoc app packaging remains separate from production Developer ID
   signing and notarization.
5. An unreleased pre-bootstrap version, recommended as `0.0.0`, may be used so
   the `v1.0.0` release commit records the first public version transition. The
   implementation must document and test the selected bootstrap mechanism.
6. Once signing or publication begins, retries reuse the exact verified artifact
   bytes. They do not rebuild an artifact under the same version.
7. Cross-repository writes use the dedicated least-privilege GitHub App required
   by `DIST-08`, not a personal access token.
8. The stable production Developer Team identifier is treated as a non-secret
   release invariant after bootstrap.

## Requirements traceability

| Requirements | Primary tasks |
| --- | --- |
| `DIST-01` | `DIST-P06`, `DIST-P07`, `DIST-P09`, `DIST-P10` |
| `DIST-02` | `DIST-P02`, `DIST-P03`, `DIST-P05`, `DIST-P10` |
| `DIST-03` | `DIST-P02`, `DIST-P05`, `DIST-P06`, `DIST-P08` |
| `DIST-04` | `DIST-P02`, `DIST-P05`, `DIST-P06`, `DIST-P08` |
| `DIST-05` | `DIST-P06`, `DIST-P08`, `DIST-P10`, `DIST-P11` |
| `DIST-06` | `DIST-P06`, `DIST-P08`, `DIST-P09`, `DIST-P11` |
| `DIST-07` | `DIST-P03`, `DIST-P04`, `DIST-P07`, `DIST-P08`, `DIST-P10`, `DIST-P11` |
| `DIST-08` | `DIST-P05`, `DIST-P07`, `DIST-P08`, `DIST-P09` |
| `DIST-09` | `DIST-P04`, `DIST-P08`, `DIST-P09`, `DIST-P11` |
| `DIST-10` | `DIST-P09`, `DIST-P10` |

## Execution order

`DIST-P01` establishes the missing decision record, baseline, and external
prerequisites. `DIST-P02` and `DIST-P03` may then proceed in parallel.
`DIST-P04` depends on the release policy, while `DIST-P05` depends on version
identity. `DIST-P06` can begin with fixture artifacts after version identity is
known, but production validation requires `DIST-P05`. `DIST-P07` integrates the
release-policy, state, artifact, and Homebrew work. `DIST-P08` closes deterministic
and protected-CI evidence, and `DIST-P09` closes documentation and repository
validation. `DIST-P10` and `DIST-P11` are external rollout checkpoints.

## Detailed tasks

### DIST-P01 — Restore the decision record and establish prerequisites

**Requirements:** Planning prerequisite for all distribution requirements.

**Dependencies:** None.

**Likely files:**

- `docs/adr/0004-automate-signed-public-beta-releases.md`
- `docs/adr/README.md`
- this plan

**Work:**

- Restore ADR 0004 from decisions already accepted in distribution-spec revision
  2. Do not introduce new product behavior.
- Record the separation between local ad-hoc packaging and production
  distribution packaging.
- Inventory the required public tap, release and package-test runners, stable
  Developer ID identity, App Store Connect API key, GitHub App installations,
  repository variables, protected secrets, environments, and branch policies.
- Select exact reviewed Node, semantic-release, plugin, and GitHub Action
  versions during implementation; do not use floating production versions.
- Run and record the pre-change source and local app baseline before production
  edits.

- [x] **DIST-P01:** The accepted decision and prerequisite baseline is complete.
- [x] **DIST-P01-AC1:** ADR 0004 records only architecture and credential-custody
  decisions already accepted by the owning specification.
- [x] **DIST-P01-AC2:** Every external repository, runner, credential class,
  variable, permission, and branch-policy prerequisite is named without exposing
  a secret value.
- [x] **DIST-P01-AC3:** Local and production packaging entry points remain
  explicitly separate.
- [x] **DIST-P01-V1:** Pre-change `make format-check`, `make check`, and `make app`
  results are recorded accurately.
- [x] **DIST-P01-V2:** The production build environment proves Apple Silicon,
  Xcode 27, Swift 6.4, the macOS 27 SDK, and a macOS 26 deployment target.

**Implementation evidence (September 26, 2026):** ADR 0004 records the accepted
architecture and external prerequisite inventory. Before production edits,
`make format-check`, `make check`, and `make app` all passed at source revision
`a1d1619`. The verified local release-capable environment is Apple Silicon on
macOS 27.0 with Xcode 27.0 (build 27A266a), Swift 6.4, and the macOS 27 SDK;
`Package.swift` retains macOS 26 as the deployment minimum. The public source
repository is available, no release tags exist, and the required public tap is
not yet provisioned, so external rollout remains blocked without affecting
repository implementation.

### DIST-P02 — Establish release version identity

**Requirements:** `DIST-02`, `CLI-06`, `DIST-AC-01`, and `DIST-AC-16`.

**Dependencies:** `DIST-P01`.

**Likely files:**

- `VERSION`
- `Package.swift`
- `Sources/CalRelayCLI/Main.swift`
- `Resources/CalRelayApp/Info.plist`
- `scripts/build-calrelay-app.sh`
- version and bundle-metadata tests under `Tests/CalRelayKitTests/`

**Work:**

- Add the root `VERSION` source of truth and strict `X.Y.Z` validation.
- Update the package to Swift tools 6.4 while retaining macOS 26 as the minimum.
- Generate or inject the release version into the CLI and register it with
  ArgumentParser.
- Make app assembly derive `CFBundleShortVersionString` from `VERSION`.
- Define and document a deterministic Apple-valid `CFBundleVersion` mapping that
  strictly increases for every permitted later release.
- Preserve `CalRelay`, `CalRelayApp`, `dev.owinter.CalRelay`, the deployment
  target, and unsandboxed production behavior.
- Add drift tests across source version, CLI output, app metadata, tag, formula,
  and cask inputs.

- [x] **DIST-P02:** Shared release version identity is implemented.
- [x] **DIST-P02-AC1:** `VERSION` contains exactly one valid `X.Y.Z` value without
  a leading `v` or surrounding content.
- [x] **DIST-P02-AC2:** `calrelay --version` reports the synchronized version on
  standard output with status zero and performs no configuration or EventKit
  access.
- [x] **DIST-P02-AC3:** Built app short and bundle versions derive from the same
  root version.
- [x] **DIST-P02-AC4:** The bundle-version mapping is deterministic, Apple-valid,
  and strictly monotonic for all accepted version transitions.
- [x] **DIST-P02-AC5:** Production app name, executable, bundle identifier,
  deployment target, and sandbox state remain compatible.
- [x] **DIST-P02-V1:** Focused CLI version and app bundle-metadata suites pass
  through the custom test runner.
- [x] **DIST-P02-V2:** `swift run calrelay --version`, the existing help smokes,
  and `make app` pass locally.

**Implementation evidence (September 26, 2026):** Root `VERSION` is initialized
to the unreleased value `0.0.0` and is mirrored in the checked-in CLI version
source. The package now requires Swift tools 6.4 while retaining macOS 26. App
assembly strictly validates `VERSION`, injects it into both
`CFBundleShortVersionString` and `CFBundleVersion`, and preserves the production
name, executable, identifier, deployment minimum, and unsandboxed local bundle.
The direct `X.Y.Z` bundle-version mapping is deterministic and lexicographically
monotonic by numeric component for every accepted semantic-version transition.
Focused distribution, CLI smoke, and app-metadata suites pass; `make check` and
`make app` report the synchronized `0.0.0` identity.

### DIST-P03 — Implement release selection and preparation

**Requirements:** `DIST-07`, `DIST-AC-11`, and the bootstrap-selection portion
of `DIST-AC-18`.

**Dependencies:** `DIST-P01`; may run in parallel with `DIST-P02`.

**Likely files:**

- `.releaserc.json`
- repository-owned plugins or helpers under `scripts/release/`
- release-policy tests under `Tests/CalRelayKitTests/`

**Work:**

- Configure semantic-release only through `.releaserc.json`.
- Implement the accepted `1.x` policy: `fix` and `fix!` select patch; `feat` and
  `feat!` select minor; breaking markers contribute notes but never select major;
  all other commit types select no release.
- Reject every automatic path outside `1.x`, including `2.0.0`.
- Implement the explicit no-tag bootstrap path for `1.0.0`.
- Generate privacy-safe release notes.
- Prepare exactly one `chore(release): vX.Y.Z` source commit that synchronizes
  version artifacts, and tag that exact commit.
- Exercise the policy against temporary Git histories rather than only parsing
  isolated commit strings.

- [x] **DIST-P03:** Release selection and preparation are implemented.
- [x] **DIST-P03-AC1:** The full qualifying and non-qualifying commit matrix
  produces the required bump or no-release result.
- [x] **DIST-P03-AC2:** No ordinary tested history, including breaking-marked
  commits, selects `2.0.0`; pre-`1.0.0` and `2.x` histories fail closed.
- [x] **DIST-P03-AC3:** Bootstrap selects only `1.0.0` and only before a public
  release exists.
- [x] **DIST-P03-AC4:** A selected release prepares one exact release commit and
  tag without unrelated source changes.
- [x] **DIST-P03-AC5:** Node, semantic-release, plugin, and action versions are
  explicitly pinned without a Node package manifest.
- [x] **DIST-P03-V1:** Temporary-history tests cover `fix`, `fix!`, `feat`,
  `feat!`, breaking-only, non-qualifying, release-commit, and forbidden-major
  histories.
- [x] **DIST-P03-V2:** Repository checks prove `.releaserc.json` is the only
  semantic-release configuration artifact.

**Implementation evidence (September 26, 2026):** `.releaserc.json` is the sole
semantic-release configuration and delegates analysis, aggregate privacy-safe
notes, and source preparation to repository-owned plugins. `toolchain.json` pins
Node 24.21.0, semantic-release 25.0.9, and plugin revision 1.2.0; GitHub Action
pins remain deferred to DIST-P07, where workflows first exist. The explicit
repository helper handles no-tag `1.0.0` bootstrap, while ordinary automation is
limited to patch/minor transitions within `1.x`. Temporary Git histories prove
the complete selection matrix, unsupported-release-line rejection, preparation
rejection outside `1.x`, one exact
`chore(release): vX.Y.Z` commit, exact tag target, and version-artifact-only
preparation. The explicit bootstrap is propagated through the pinned
semantic-release runner, and semantic-release 25.0.9's prepare pipeline re-reads
Git HEAD after the prepare plugin creates the release commit so that exact commit
is tagged. No Node package manifest or lockfile was added.

### DIST-P04 — Implement resumable immutable release state

**Requirements:** `DIST-07`, `DIST-09`, `DIST-AC-02`, and `DIST-AC-12` through
`DIST-AC-14`.

**Dependencies:** `DIST-P03`.

**Likely files:**

- release-state and publication tools under `scripts/release/`
- release-state fixtures and tests under `Tests/CalRelayKitTests/`

**Work:**

- Define state covering the captured source revision, selected version, release
  commit, tag, artifact names and digests, release assets, tap content, tap
  commit, and publication stage.
- Implement durable staging that preserves exact signed and notarized artifact
  bytes across workflow retries.
- Resume an incomplete version before analyzing later commits.
- Inspect existing source, `VERSION`, tag, GitHub release, assets, checksums, and
  tap state on every retry.
- Treat matching existing state as complete and reject mismatched immutable
  state.
- Fail before source publication when remote `master` differs from the captured
  source revision.
- Update the formula and cask together only after both artifacts are published
  and verified.
- Preserve the prior known-good version until the atomic tap commit succeeds.
- Model defective tap-published versions as higher-patch roll-forward only.

- [ ] **DIST-P04:** Release publication is resumable and immutable.
- [ ] **DIST-P04-AC1:** Exact artifact bytes and digests survive retries without
  same-version rebuilding.
- [ ] **DIST-P04-AC2:** Every publication stage accepts matching state and fails
  closed on mismatching state.
- [ ] **DIST-P04-AC3:** Remote `master` advancement aborts before release commit
  or tag publication.
- [ ] **DIST-P04-AC4:** Incomplete releases resume the same version before later
  commits are considered.
- [ ] **DIST-P04-AC5:** The tap cannot expose only one package at the new version.
- [ ] **DIST-P04-AC6:** A defective published version can only be corrected by a
  higher patch release and never triggers calendar rollback.
- [ ] **DIST-P04-V1:** Fault-injection tests cover interruption after every
  publication stage.
- [ ] **DIST-P04-V2:** Tests cover matching retries, mismatches, stale source,
  partial assets, partial tap state, defective releases, and compromised-artifact
  handling.

### DIST-P05 — Build, sign, notarize, and verify artifacts

**Requirements:** `DIST-03`, `DIST-04`, `DIST-08`, `DIST-AC-02`, `DIST-AC-03`,
`DIST-AC-05`, `DIST-AC-10`, and `DIST-AC-16`.

**Dependencies:** `DIST-P02`.

**Likely files:**

- `scripts/build-calrelay-app.sh`
- production packaging tools under `scripts/release/`
- `Makefile`
- packaging tests under `Tests/CalRelayKitTests/`

**Work:**

- Preserve `make app` as an ad-hoc development build.
- Add separate production artifact entry points that validate toolchain,
  architecture, SDK, and deployment target.
- Build Apple Silicon release executables.
- Import the Developer ID certificate into an ephemeral CI keychain and remove
  it on every exit path.
- Sign the CLI and app with Developer ID Application, hardened runtime, and a
  secure timestamp.
- Verify the expected stable Team ID, app bundle identifier, architecture,
  deployment target, and absence of App Sandbox entitlements.
- Submit the signed CLI through an Apple-supported notarization container, then
  package the accepted executable in the final versioned `.tar.gz`.
- Notarize the app, staple and validate its ticket, and only then create the
  final versioned `.zip`.
- Verify strict signatures, notarization acceptance, app Gatekeeper assessment,
  versions, archive contents, and SHA-256 digests.
- Prevent credentials, configuration, Calendar data, identifiers, and diagnostic
  dumps from entering artifacts, caches, or logs.

- [ ] **DIST-P05:** Production CLI and app artifacts are generated safely.
- [ ] **DIST-P05-AC1:** The CLI archive contains exactly one executable named
  `calrelay`.
- [ ] **DIST-P05-AC2:** The app archive contains the correctly named and
  identified `CalRelay.app`.
- [ ] **DIST-P05-AC3:** Both products are Apple Silicon, macOS 26 compatible,
  Developer ID signed, hardened, securely timestamped, and notarization accepted.
- [ ] **DIST-P05-AC4:** The app additionally has a valid stapled ticket and
  passes normal Gatekeeper assessment.
- [ ] **DIST-P05-AC5:** Checksums are computed only after all byte-changing
  signing, stapling, and packaging operations.
- [ ] **DIST-P05-AC6:** The production app remains unsandboxed and retains
  canonical configuration-path compatibility.
- [ ] **DIST-P05-AC7:** Signing material exists only in the ephemeral keychain
  and is cleaned up on success and failure.
- [ ] **DIST-P05-V1:** Fake-tool process tests cover malformed versions,
  toolchain mismatch, wrong architecture or Team ID, signing failure,
  notarization failure, stapling failure, and cleanup.
- [ ] **DIST-P05-V2:** The protected release lane passes real signature,
  notarization, stapler, Gatekeeper, metadata, and checksum checks.

### DIST-P06 — Generate and validate the formula and cask

**Requirements:** `DIST-01`, `DIST-03` through `DIST-06`, and `DIST-AC-03`
through `DIST-AC-09` and `DIST-AC-15`.

**Dependencies:** `DIST-P02`; production validation also depends on `DIST-P05`.

**Likely source-repository files:**

- Homebrew templates or generator inputs under `packaging/homebrew/`
- Homebrew generation and test tools under `scripts/release/`

**Expected tap outputs:**

- `Formula/calrelay.rb`
- `Casks/calrelay.rb`

The tap's own repository instructions must be inspected before finalizing its
paths or modifying it.

**Work:**

- Render both packages from one verified candidate manifest.
- Make the formula consume the immutable CLI archive and checksum, support only
  arm64 macOS 26+, install only `calrelay`, invoke no Swift build, and test
  `--version` and `--help`.
- Make the cask consume the immutable app archive and checksum, support only
  arm64 macOS 26+, install only `CalRelay.app`, launch nothing, and define no
  destructive `zap`.
- Verify package versions and checksums against the same release manifest.
- Test a temporary local tap before remote publication.
- Test both installation orders, independent upgrades, and independent ordinary
  uninstallation.
- Use sentinel configuration and app-state fixtures to prove package operations
  do not rewrite or delete user data.
- Verify package operations do not launch either product, request permission,
  access calendars, or register launch-at-login.

- [ ] **DIST-P06:** Formula and cask satisfy the installation contract.
- [ ] **DIST-P06-AC1:** Both packages use token `calrelay` and coexist without
  ownership collisions.
- [ ] **DIST-P06-AC2:** The formula installs the prebuilt CLI without SwiftPM or
  build-dependency downloads.
- [ ] **DIST-P06-AC3:** The cask installs only the app and contains no destructive
  `zap`.
- [ ] **DIST-P06-AC4:** Unsupported architecture and operating systems are
  rejected through package metadata.
- [ ] **DIST-P06-AC5:** Installation order does not affect either product.
- [ ] **DIST-P06-AC6:** Upgrades and uninstallation preserve configuration and
  do not remove the other package.
- [ ] **DIST-P06-AC7:** Formula and cask are emitted together from the same
  verified release manifest.
- [ ] **DIST-P06-V1:** Homebrew style, audit, fetch, install, test, upgrade,
  uninstall, and coexistence checks pass in CI.
- [ ] **DIST-P06-V2:** Re-downloaded production artifacts match committed package
  checksums exactly.

### DIST-P07 — Add secure GitHub Actions release orchestration

**Requirements:** `DIST-07`, `DIST-08`, `DIST-AC-12`, `DIST-AC-17`, and
`DIST-AC-18`.

**Dependencies:** `DIST-P03` through `DIST-P06` and the runner strategy from
`DIST-P01`.

**Likely files:**

- `.github/workflows/release.yml`
- supporting tools under `scripts/release/`

**Work:**

- Trigger the workflow through `workflow_dispatch` for bootstrap and resumption,
  and through pushes to `master` after bootstrap.
- Configure one release concurrency group with in-progress cancellation disabled.
- Keep non-qualifying analysis free of signing and publication secrets.
- Pin every external action to an immutable reviewed commit.
- Use minimum workflow token permissions and generate the dedicated GitHub App
  installation token only for authorized publication steps.
- Check remote source freshness immediately before release commit and tag push.
- Build and retain exact candidate artifacts, publish immutable release assets,
  then update formula and cask together in one tap commit.
- Redownload and verify published artifacts after publication.
- Make release-commit-triggered runs converge to completed/no-op or same-version
  resumption rather than selecting another release.
- Always clean up temporary credentials and keychains.

- [ ] **DIST-P07:** CI securely orchestrates complete releases.
- [ ] **DIST-P07-AC1:** Manual bootstrap and automatic `master` pushes use the
  same release gate.
- [ ] **DIST-P07-AC2:** Concurrent releases queue and never cancel active
  publication.
- [ ] **DIST-P07-AC3:** Non-qualifying pushes publish nothing and cannot access
  signing or publication secrets.
- [ ] **DIST-P07-AC4:** Remote source advancement fails before source
  publication.
- [ ] **DIST-P07-AC5:** Cross-repository writes use only the dedicated GitHub App
  with least privilege.
- [ ] **DIST-P07-AC6:** The complete release gate requires no real Calendar data
  or Calendar mutation.
- [ ] **DIST-P07-V1:** Workflow syntax, permissions, and pinned-action policy
  checks pass.
- [ ] **DIST-P07-V2:** A controlled dry run or disposable-repository exercise
  proves trigger, concurrency, token, source-check, and publication ordering.

### DIST-P08 — Close acceptance, recovery, and security evidence

**Requirements:** `DIST-AC-01` through `DIST-AC-18`.

**Dependencies:** `DIST-P02` through `DIST-P07`.

**Likely files:**

- distribution suites under `Tests/CalRelayKitTests/`
- `Tests/CalRelayKitTests/Main.swift`
- `Makefile`

**Work:**

- Add focused deterministic suites and register each suite explicitly in the
  custom test runner.
- Cover version equality and monotonicity, release-policy selection, stale-source
  rejection, interruption and retry, immutable mismatch rejection, atomic tap
  publication, higher-patch correction, configuration retention, package
  coexistence, and privacy boundaries.
- Use fake Apple, GitHub, and Homebrew boundaries where real protected services
  are unnecessary.
- Keep real signing, notarization, Gatekeeper, and publication checks in the
  protected release lane.
- Scan generated output, logs, caches, manifests, and archives for injected
  credential, configuration, calendar-name, event-title, and EventKit-ID
  sentinels.
- Reuse existing no-prompt, configuration-path, bundle-identity, and
  launch-at-login recovery evidence instead of duplicating those behaviors.

- [ ] **DIST-P08:** Required acceptance evidence is complete.
- [ ] **DIST-P08-AC1:** Every distribution acceptance check maps to an automated
  test, protected CI check, or external rollout checkpoint.
- [ ] **DIST-P08-AC2:** Fault injection covers every publication transition and
  cleanup path.
- [ ] **DIST-P08-AC3:** Sentinel tests prove prohibited values do not appear in
  outputs, logs, caches, or artifacts.
- [ ] **DIST-P08-AC4:** Existing no-prompt, app identity, configuration-path, and
  launch-at-login recovery tests remain passing.
- [ ] **DIST-P08-V1:** All focused distribution suites pass.
- [ ] **DIST-P08-V2:** The complete deterministic test runner passes without
  EventKit access or real calendars.

### DIST-P09 — Document installation, operation, and recovery

**Requirements:** `DIST-01`, `DIST-06`, `DIST-09`, `DIST-10`, and `DIST-AC-15`.

**Dependencies:** Stable interfaces from `DIST-P02` through `DIST-P08`.

**Likely files:**

- `README.md`
- `docs/development.md`
- `docs/repository-layout.md`
- new user distribution documentation under `docs/`
- new release-operator documentation under `docs/`

**Work:**

- Document exactly the fully qualified formula and cask installation commands.
- Distinguish CLI-only, app-only, and combined installations.
- Document Apple Silicon and macOS 26+ support, upgrades, ordinary
  uninstallation, configuration retention, and permission setup through the
  intentionally launched app.
- Do not present an explicit tap plus short command or official Homebrew
  installation as supported.
- Document bootstrap, automatic operation, credential rotation, incomplete
  release resumption, defective release roll-forward, compromised artifact
  disablement, and runner or tap recovery.
- Name commands and secret roles without recording secret values.

- [ ] **DIST-P09:** Distribution documentation is complete.
- [ ] **DIST-P09-AC1:** User documentation contains exactly the two supported
  fully qualified installation commands.
- [ ] **DIST-P09-AC2:** Support, coexistence, upgrades, ordinary uninstallation,
  configuration retention, and permission setup are described accurately.
- [ ] **DIST-P09-AC3:** Operator documentation covers bootstrap, automation,
  rotation, resumption, roll-forward, compromise response, and recovery.
- [ ] **DIST-P09-AC4:** No unsupported short-installation or official-Homebrew
  claim appears.
- [ ] **DIST-P09-V1:** Every documented repository path and command is verified.
- [ ] **DIST-P09-V2:** `git --no-pager diff HEAD --check`, `make format-check`,
  `make check`, and `make app` pass.

### DIST-P10 — Provision infrastructure and bootstrap `v1.0.0`

**Requirements:** `DIST-01`, `DIST-02`, `DIST-07`, `DIST-08`, `DIST-AC-01`
through `DIST-AC-10`, and `DIST-AC-15` through `DIST-AC-18`.

**Dependencies:** `DIST-P01` through `DIST-P09` and all external prerequisites.

**External prerequisites:**

- public `ondrej-winter/homebrew-tap` repository;
- approved Apple Silicon Xcode 27 build runner and supported package-test runners;
- stable Developer ID Application identity and Team ID;
- team App Store Connect API key;
- dedicated GitHub App installed on the source and tap repositories;
- protected repository secrets, variables, environments, and branch policies.

**Work:**

- Provision the tap, runners, GitHub App, Apple credentials, release environment,
  and non-secret Team ID invariant.
- Dispatch the bootstrap workflow for `1.0.0`.
- Verify the release commit, tag, immutable assets, checksums, and one atomic tap
  update.
- Install both packages using the fully qualified commands from a clean untapped
  supported environment.
- Record privacy-safe bootstrap evidence.

- [ ] **DIST-P10:** The public `v1.0.0` bootstrap is complete.
- [ ] **DIST-P10-AC1:** The release commit is `chore(release): v1.0.0`, contains
  synchronized version state, and is tagged `v1.0.0`.
- [ ] **DIST-P10-AC2:** Published assets pass checksum, signature, notarization,
  stapler, Gatekeeper, architecture, deployment-target, and version checks.
- [ ] **DIST-P10-AC3:** Formula and cask are published together at `1.0.0`.
- [ ] **DIST-P10-AC4:** Both documented installation commands succeed without a
  preconfigured tap.
- [ ] **DIST-P10-AC5:** Installation and ordinary uninstallation leave user
  configuration and Calendar state untouched.
- [ ] **DIST-P10-V1:** Post-publication redownload and checksum verification
  passes.
- [ ] **DIST-P10-V2:** Bootstrap evidence is retained without credentials or
  private calendar data.

### DIST-P11 — Prove later automatic release and upgrade behavior

**Requirements:** The automatic portion of `DIST-AC-18`, plus `DIST-AC-06`,
`DIST-AC-08`, `DIST-AC-12`, and `DIST-AC-14`.

**Dependencies:** `DIST-P10` and a later qualifying `master` push.

**Work:**

- Allow the next genuine qualifying push, or an explicitly approved bounded
  release probe, to trigger publication automatically.
- Verify the selected patch or minor version matches the qualifying history and
  requires no manual dispatch.
- Verify a non-qualifying push publishes nothing.
- Exercise real formula and cask upgrades from `1.0.0` while preserving
  configuration, app identity, and independent package operation.
- Retain simulated defective-release evidence from `DIST-P08`; do not
  intentionally publish a defective release.

- [ ] **DIST-P11:** Automatic post-bootstrap release behavior is proven.
- [ ] **DIST-P11-AC1:** A qualifying `master` push publishes the policy-selected
  version automatically.
- [ ] **DIST-P11-AC2:** A non-qualifying push completes without publication.
- [ ] **DIST-P11-AC3:** Formula and cask upgrades retain configuration and stable
  app identity.
- [ ] **DIST-P11-AC4:** Queued concurrency and non-cancellation behavior is
  evidenced.
- [ ] **DIST-P11-V1:** Post-release redownload, checksum, installation,
  coexistence, upgrade, and uninstallation checks pass.
- [ ] **DIST-P11-V2:** This plan records final evidence for every
  `DIST-AC-01` through `DIST-AC-18` acceptance check.

## Validation strategy

### Focused iteration

- Version and app bundle-metadata suites.
- CLI process smoke checks, including `calrelay --version`.
- Semantic-release temporary-history tests.
- Release-state and fault-injection suites.
- Packaging tests with fake signing, notarization, Homebrew, and publication
  boundaries.
- Temporary local-tap formula and cask tests.
- Workflow syntax, permissions, and pinned-dependency checks.

### Repository handoff gate

```sh
make format-check
make check
make app
```

If implementation adds a dedicated offline distribution target, run it as well
and document whether it is included in `make check`.

### Protected release gate

- Exact toolchain, architecture, SDK, and deployment-target checks.
- Release CLI and app builds.
- Deterministic source tests and non-EventKit smoke checks.
- Developer ID, hardened-runtime, secure-timestamp, and Team ID verification.
- Notarization acceptance, app ticket stapling, and Gatekeeper assessment.
- Archive and checksum verification.
- Formula and cask style, audit, installation, testing, coexistence, upgrade, and
  ordinary uninstallation.
- Atomic publication and post-publication redownload verification.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Required Apple Silicon Xcode 27 runner is unavailable | Provision a dedicated ephemeral runner before workflow integration; do not weaken the toolchain requirement. |
| A retry rebuilds different signed bytes | Persist and reuse exact verified artifacts once signing begins. |
| A release commit retriggers the workflow | Serialize runs and make state inspection converge to no-op completion or same-version resumption. |
| The tap exposes only one package | Generate both definitions from one manifest and publish them in one commit after both artifacts are verified. |
| Developer Team identity changes silently | Verify an expected non-secret Team ID before publication and fail as a migration. |
| Production credentials leak into local packaging | Preserve separate local ad-hoc and production release entry points. |
| Secrets or private data enter logs, caches, or artifacts | Avoid secret tracing, use ephemeral keychains, disable sensitive caching, add sentinel scans, and clean up on every exit path. |
| Homebrew behavior changes | Validate with the pinned release environment and current style and audit commands before every tap update. |
| Bootstrap races with a newer `master` push | Use one non-cancelling release queue and the immediate pre-publication remote revision check. |
| Missing ADR 0004 causes competing rationale | Restore the accepted record first from the canonical specification. |

## Readiness and next action

Repository implementation is ready to begin with `DIST-P01`. After that task,
`DIST-P02` and `DIST-P03` are the next parallelizable slices. `DIST-P10` and
`DIST-P11` remain externally blocked until their listed infrastructure and
credential prerequisites exist.