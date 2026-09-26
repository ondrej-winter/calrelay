# Spec: Public-Beta Release Distribution and Homebrew Installation

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 26, 2026; replaces the source-built, partly manual stable-release contract with an automated, prebuilt, signed and notarized `0.x` public-beta channel.
- **Acceptance basis:** The project owner completed and approved the public-beta distribution interview on September 26, 2026, including release automation, versioning, packaging, credential, recovery, and Homebrew channel decisions.
- **Canonical artifact:** `docs/specs/distribution-spec.md`.
- **Scope:** Public-beta releases, release identity, upstream binary artifacts, Homebrew formula and cask installation, distribution signing and notarization, package coexistence, upgrades, uninstallation, release automation and security, and recovery from incomplete or defective releases.

## Required outcomes

### DIST-01 — Initial distribution channels and package identity

- Distribute the command-line product as a Homebrew formula with token `calrelay`.
- Distribute the graphical product as a Homebrew cask with token `calrelay`.
- Keep the formula and cask as separate packages that may be installed independently or together.
- Use the public upstream GitHub tap `ondrej-winter/homebrew-tap`, exposed to Homebrew as `ondrej-winter/tap`, as the initial authoritative distribution channel.
- The supported installation commands are exactly the fully qualified commands:

```sh
brew install ondrej-winter/tap/calrelay
brew install --cask ondrej-winter/tap/calrelay
```

- Do not document or claim support for an explicit `brew tap` followed by a short install command, or for untapped short installation from `homebrew/core` or `homebrew/cask`, during the initial public beta.
- Treat official Homebrew inclusion as a future promotion target requiring a later accepted distribution revision.
- A future promotion must preserve the formula token, cask token, executable name, app name, and observable installation contract unless a collision or Homebrew policy requires an explicitly documented migration.

### DIST-02 — Public-beta release and version identity

- Every Homebrew-distributed version is an explicitly published public-beta release identified by a version tag in the form `vX.Y.Z`.
- The root `VERSION` file is the repository source of truth and contains the corresponding `X.Y.Z` without a leading `v` or surrounding content.
- Release tags and their associated source and binary assets are immutable after publication.
- One release version identifies both the CLI and GUI products for that release.
- The root `VERSION`, release tag, formula version, cask version, `calrelay --version`, and `CalRelay.app` `CFBundleShortVersionString` all identify the same `X.Y.Z` release.
- `CFBundleVersion` is derived deterministically from `X.Y.Z`, is valid Apple bundle metadata, and increases monotonically for every later release.
- Bootstrap the public channel manually at `v0.1.0`. Later qualifying pushes to `master` are released automatically under `DIST-07`.
- The production app retains the application name `CalRelay`, bundle identifier `dev.owinter.CalRelay`, executable identity expected by its bundle, and one stable Apple Developer Team identity after the first public release.
- Changing the bundle identifier or Developer Team identity is a distribution migration because it can affect Calendar permission, persisted app state, and launch-at-login continuity.

### DIST-03 — Prebuilt CLI artifact and Homebrew formula contract

- Build the release CLI for Apple Silicon on macOS with Xcode 27, Swift 6.4, Swift tools 6.4, and the macOS 27 SDK while retaining macOS 26 as the minimum deployment target.
- Publish a versioned `.tar.gz` containing the prebuilt `calrelay` executable rather than building Swift source during Homebrew installation.
- Sign the executable with the release's Developer ID Application identity, hardened runtime, and a secure signing timestamp, and submit it to Apple's notarization service before publication.
- Publish a SHA-256 checksum for the exact immutable `.tar.gz` consumed by Homebrew.
- The formula downloads only that versioned artifact, verifies its checksum, installs one executable named `calrelay` into Homebrew's executable path, and does not invoke SwiftPM or download build dependencies.
- Do not install `CalRelay.app` from the formula.
- The initial formula supports only Apple Silicon on macOS 26 or later; unsupported operating systems or architectures are rejected by package metadata.
- Formula installation and testing do not request Calendar permission, access or mutate calendars, require user configuration, launch `CalRelay.app`, or register launch-at-login.
- The installed executable supports non-EventKit smoke verification through `calrelay --version` and `calrelay --help`.
- Runtime command and safety behavior remains owned by [`cli-spec.md`](cli-spec.md).

### DIST-04 — Prebuilt app artifact and Homebrew cask contract

- Build the release app for Apple Silicon on macOS with Xcode 27, Swift 6.4, Swift tools 6.4, and the macOS 27 SDK while retaining macOS 26 as the minimum deployment target.
- Publish a versioned `.zip` containing `CalRelay.app`; do not rebuild the application from source during cask installation.
- Sign the distributed application with the release's Developer ID Application identity, hardened runtime, and a secure signing timestamp.
- Submit the distributed application to Apple's notarization service, staple its notarization ticket before archiving, and require the extracted app to pass strict signature verification and normal Gatekeeper assessment.
- Keep the production app unsandboxed so it retains direct read access to the canonical `~/.config/calrelay/config.yaml` contract. Hardened runtime remains required.
- Do not require users to bypass Gatekeeper, disable System Integrity Protection, remove quarantine manually, or use an unsigned build.
- Publish a SHA-256 checksum for the exact immutable `.zip` consumed by Homebrew.
- Install `CalRelay.app` as a normal macOS application and do not install or link the `calrelay` CLI from the cask.
- Cask installation and verification do not launch the app automatically, request Calendar or notification permission, register launch-at-login, read configuration, or access or mutate calendars.
- The initial cask supports only Apple Silicon on macOS 26 or later; unsupported operating systems or architectures are rejected by package metadata.
- App behavior after an intentional user launch remains owned by [`macos-app-spec.md`](macos-app-spec.md).

### DIST-05 — Formula and cask coexistence

- A user may install both fully qualified packages from `ondrej-winter/tap`.
- Installing one package must not overwrite, link, remove, or claim ownership of artifacts installed by the other.
- The CLI and app continue to use the canonical configuration contract in [`configuration-spec.md`](configuration-spec.md).
- Installation order does not affect product behavior.
- Upgrading or uninstalling the formula must not modify the installed application.
- Upgrading or uninstalling the cask must not remove the formula executable.
- Neither package creates, rewrites, migrates, or deletes the user's YAML configuration as part of installation, upgrade, or uninstallation.

### DIST-06 — Upgrade and uninstallation behavior

- A formula upgrade replaces the CLI with the selected newer public-beta version and leaves user configuration untouched.
- A cask upgrade replaces the application while preserving its bundle identifier and distribution-signing identity.
- An app upgrade does not automatically launch CalRelay or begin reconciliation.
- A cask upgrade preserves persisted app state that remains compatible with the new version.
- After an app upgrade, launch-at-login either remains healthy or is reported through the existing actionable launch-at-login recovery behavior.
- An upgrade must never report launch-at-login as healthy when macOS cannot launch the installed application.
- Ordinary formula and cask uninstallation remove their installed program artifacts but do not delete `~/.config/calrelay/config.yaml`, alternate user-created configuration files, calendar events, or unrelated user files.
- Uninstallation does not launch either product or perform Calendar mutation.
- The public-beta channel does not provide an automatic destructive `zap` operation for configuration, app state, Calendar permissions, or calendar data.
- Reinstallation after ordinary uninstallation uses the same configuration location and may reuse compatible persisted app state retained by macOS.

### DIST-07 — Automated release policy and atomic publication

- The manually initiated `v0.1.0` bootstrap passes the same build, signing, notarization, verification, and publication gates as later automated releases.
- After bootstrap, every qualifying push to `master` starts the release workflow. Non-qualifying pushes complete without publishing a release.
- Configure semantic-release only through a root `.releaserc.json`. Do not add a `package.json`, JavaScript lockfile, or `CHANGELOG.md` solely for release automation.
- Pin the Node runtime, semantic-release, every semantic-release plugin, and every GitHub Action to explicit reviewed versions or immutable commit identifiers in the workflow.
- While the current version is `0.x`, `fix` and `fix!` commits select a patch release, while `feat` and `feat!` commits select a minor release. A breaking marker contributes a release warning or note but never changes the selected `0.x` bump by itself. Other commit types do not select a release unless a later accepted revision says otherwise.
- Releasing `1.0.0` requires an explicit product decision and a revised release rule; automation must not infer `1.0.0` from a breaking marker.
- For a selected release, create one source commit with subject `chore(release): vX.Y.Z` that records the new root `VERSION`; tag that commit `vX.Y.Z`.
- Serialize release executions without cancelling an in-progress release. A newer queued push must not supersede or interrupt the run currently publishing.
- Capture the intended source revision and fail closed before source publication if remote `master` has advanced. Do not tag or publish a different source revision under the computed version.
- The CI workflow is the complete required release gate: source checks, release builds, non-EventKit smoke checks, signing, notarization, checksums, Homebrew validation, coexistence checks, and publication checks must pass there. Real-Mac manual validation may supplement the gate but is not required for release acceptance.
- Publish the immutable CLI `.tar.gz`, app `.zip`, checksums, and release notes before updating the tap.
- Publish the formula and cask together in one tap commit after both artifacts and all required evidence exist. The authoritative tap must never expose only one package at the new version.
- The tap must not reference an asset that is unpublished, incomplete, unverified, or known to fail installation.
- Release verification confirms that downloaded artifacts match the checksums committed to the formula and cask.

### DIST-08 — Distribution privacy and credential safety

- Homebrew installation, upgrade, audit, and uninstallation do not require access to real Calendar data.
- Default release validation uses non-EventKit checks. Optional manual integration validation uses only harmless, dedicated calendars under the repository's local-system safety policy.
- Release artifacts, logs, workflow output, checksums, formulae, casks, and documentation must not contain Developer ID private keys, certificate passwords, notarization credentials, App Store Connect private keys, authorization headers, GitHub App private keys or tokens, raw CalRelay configuration, calendar names, event titles, EventKit identifiers, or EventKit object dumps.
- Use one dedicated, least-privilege GitHub App installed only where needed to update the source and tap repositories. Do not use a personal access token for automated publication.
- Use a team App Store Connect API key for notarization.
- Keep the Developer ID certificate export, its password, the App Store Connect key, and the GitHub App private key in protected CI secrets. Import signing material only into an ephemeral CI keychain and remove it before the job ends.
- Release workflows must not persist sensitive credentials in downloadable build artifacts, caches, or diagnostic logs.

### DIST-09 — Incomplete release and defective-release recovery

- Treat release progress as resumable state. A retry inspects the source commit, `VERSION`, tag, GitHub release assets, checksums, and tap state and continues the same `X.Y.Z` instead of selecting a new version when publication is incomplete.
- Every publication stage is idempotent or fails closed when an existing object does not match the expected immutable content.
- Retain an identifiable previously known-good public-beta version until the new version has passed the complete CI release gate and the atomic tap update succeeds.
- If a release is found defective before the tap is updated, keep the tap on the previous known-good version and resume or repair the incomplete release only when its immutable identity can be preserved safely.
- Do not replace an existing tag or release asset under the same version.
- If a defective version has been published through the tap, correct it by publishing a higher patch version with new artifacts and checksums. Do not silently move the published version tag, replace its assets, or make a same-version correction.
- A package rollback, reinstall, or corrective release must not automatically reverse calendar mutations made by an earlier application or CLI run.
- Calendar mutation recovery remains governed by the reconciliation, cleanup, and partial-failure contracts in the existing capability specifications.
- Remove or disable a security-compromised artifact and document the action rather than retaining it as an installable version merely for downgrade convenience.

### DIST-10 — Documentation and future Homebrew promotion

- User documentation clearly distinguishes CLI formula installation, app cask installation, installing both, supported macOS versions and architecture, upgrades, ordinary uninstallation, the retained configuration location, and Calendar-permission setup through the app.
- Document only the fully qualified installation commands from `DIST-01` during the public beta.
- Keep release-operator documentation for bootstrap, automated operation, credential rotation, incomplete-release resumption, and defective-release correction without exposing secret values.
- Retain the upstream tap as the release channel until an explicit migration to official Homebrew is accepted and documented.
- Official Homebrew eligibility metrics and review decisions are external policy, not CalRelay public-beta acceptance criteria.

## Implementation freedoms

- Release scripts and local semantic-release plugins may be implemented in repository-owned files when `.releaserc.json` remains the only semantic-release configuration artifact and no Node package manifest or lockfile is introduced.
- CI may use a GitHub-hosted or dedicated runner when it demonstrably provides Apple Silicon, Xcode 27, Swift 6.4, the macOS 27 SDK, protected-secret handling, and every required signing and Homebrew validation capability.
- The exact deterministic `CFBundleVersion` derivation and resumable release-state implementation are implementation choices when they satisfy `DIST-02` and `DIST-09` for every accepted version transition.
- No self-update mechanism is required. Homebrew owns updates for Homebrew-installed copies.

## Compatibility and breaking changes

- Revision 2 intentionally removes the Revision 1 contract for source-built formula installation, explicitly tapped short installation commands, optional artifact formats, optional release execution environments, and partly manual release publication.
- Renaming the `calrelay` executable, formula token, cask token, `CalRelay.app`, or its bundle identifier is a distribution-breaking change.
- Changing the Developer Team signing identity, canonical configuration path, release version semantics, supported fully qualified installation commands, or formula/cask coexistence is a distribution-breaking change.
- Removing support for Apple Silicon or macOS 26 requires explicit compatibility documentation and an accepted specification revision.
- Making Homebrew installation launch the app, request permission, mutate calendars, or delete user configuration during ordinary upgrade or uninstallation is a breaking behavioral change.
- Moving from the upstream tap to official Homebrew requires an accepted distribution revision even when product names, artifacts, user data, and runtime behavior remain compatible.

## Constraints and downstream decisions

- Keep release credentials and signing identities outside the repository and its generated artifacts.
- Preserve SwiftPM as the source of truth for products, targets, and dependency versions.
- Keep local ad-hoc app packaging distinct from production distribution signing and notarization.
- The accepted production distribution architecture and credential-custody decision is recorded in [`../adr/0004-automate-signed-public-beta-releases.md`](../adr/0004-automate-signed-public-beta-releases.md).
- App Sandbox remains disabled for the production app while direct access to `~/.config/calrelay/config.yaml` is required. Enabling App Sandbox requires a revised configuration and distribution contract.
- Do not make official Homebrew acceptance a public-beta release blocker when the upstream tap contract is satisfied.

## Validation

- Run the repository source checks required by `AGENTS.md`.
- Verify the Apple Silicon CLI and app release builds use Xcode 27, Swift 6.4, Swift tools 6.4, the macOS 27 SDK, and a macOS 26 deployment target.
- Verify CLI and app signatures, hardened runtime, secure timestamps, notarization acceptance, and privacy-safe logs; additionally verify the app's stapled ticket and Gatekeeper assessment.
- Verify the CLI release archive and non-EventKit process smoke checks.
- Verify Homebrew formula and cask style, audit, install, upgrade, uninstall, architecture, and minimum-operating-system behavior in CI.
- Verify formula/cask coexistence, atomic tap publication, version equality, and checksums against re-downloaded published artifacts.
- Verify semantic-release selection for qualifying, non-qualifying, breaking-marked `0.x`, and forbidden automatic `1.0.0` histories.
- Verify interruption and retry at each publication boundary resumes the same version without replacing immutable content.
- Do not use real EventKit mutation as routine release automation. Optional manual validation does not substitute for a failed or missing CI gate.

## Acceptance checks

- **DIST-AC-01:** The root `VERSION`, public-beta tag, formula, cask, CLI `--version`, app short version, and deterministic increasing app bundle version satisfy `DIST-02` for the same release.
- **DIST-AC-02:** Re-downloading every published artifact for a release produces the checksum recorded by its formula or cask, and previously published tags and assets remain unchanged.
- **DIST-AC-03:** On a clean supported Apple Silicon Mac, the fully qualified formula command installs the prebuilt `calrelay`; `calrelay --version` and `calrelay --help` succeed without configuration, Calendar access, or permission prompts.
- **DIST-AC-04:** Formula installation neither invokes SwiftPM nor downloads build dependencies, and it rejects unsupported operating systems or architectures through metadata.
- **DIST-AC-05:** On a clean supported Apple Silicon Mac, the fully qualified cask command installs the prebuilt `CalRelay.app`, and the installed app passes signature, notarization-ticket, hardened-runtime, and Gatekeeper verification without security bypasses.
- **DIST-AC-06:** Installing the formula and cask in either order leaves both `calrelay` and `CalRelay.app` available and independently upgradeable and uninstallable.
- **DIST-AC-07:** Installing, upgrading, and uninstalling either package neither requests Calendar permission nor reads or mutates calendars.
- **DIST-AC-08:** Formula and cask upgrades preserve the canonical YAML configuration, and the app upgrade retains its bundle identifier and Developer Team identity and either preserves launch-at-login health or presents the existing recovery state.
- **DIST-AC-09:** Ordinary uninstallation removes the selected package but retains user configuration and leaves the other package, when installed, operational.
- **DIST-AC-10:** Release logs, caches, and artifacts contain none of the prohibited credentials, configuration, calendar data, or EventKit identifiers.
- **DIST-AC-11:** The release-policy test matrix proves `fix`/`fix!` produce a patch, `feat`/`feat!` produce a minor, breaking markers alone do not produce a major, non-qualifying commits publish nothing, and no history automatically selects `1.0.0`.
- **DIST-AC-12:** Concurrent qualifying pushes are queued without cancelling the active release, and a release fails before source publication when remote `master` no longer matches its captured source revision.
- **DIST-AC-13:** A simulated interruption after each publication stage resumes the same version, accepts matching immutable state, rejects mismatched state, and updates the formula and cask together only after both artifacts are verified.
- **DIST-AC-14:** A simulated defective tap-published release is corrected only through a higher patch version and performs no automatic calendar rollback.
- **DIST-AC-15:** Documentation installation commands work exactly as documented for users who have not previously configured the tap, and unsupported short installation forms are not presented as supported.
- **DIST-AC-16:** The production app remains unsandboxed, reads the canonical configuration path after intentional launch, and requests Calendar permission only through the explicit setup or recovery action defined by the calendar-access and macOS-app specifications.
- **DIST-AC-17:** The CI release gate can produce all required acceptance evidence without real Calendar data or mandatory manual real-Mac validation.
- **DIST-AC-18:** `v0.1.0` is bootstrapped manually through the complete release gate, and a later qualifying `master` push publishes automatically through the same gate.

## Open decisions

- None. Revision 2 fixes the first public-beta architecture, release policy, artifact formats, toolchain, platform, credential classes, automation boundary, and recovery behavior. Implementation details explicitly listed as freedoms do not block planning.