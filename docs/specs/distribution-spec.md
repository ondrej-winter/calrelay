# Spec: Release Distribution and Homebrew Installation

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — accepted on September 25, 2026; the first public release uses an upstream Homebrew tap for separate CLI formula and macOS app cask installation, with official Homebrew inclusion deferred to later promotion.
- **Acceptance basis:** The project owner explicitly approved the tap-first distribution specification on September 25, 2026.
- **Canonical artifact:** `docs/specs/distribution-spec.md`.
- **Scope:** Stable releases, release identity, upstream artifacts, Homebrew formula and cask installation, distribution signing and notarization, package coexistence, upgrades, uninstallation, release security, and recovery from a defective release.

## Required outcomes

### DIST-01 — Initial distribution channels and package identity

- Distribute the command-line product as a Homebrew formula with token `calrelay`.
- Distribute the graphical product as a Homebrew cask with token `calrelay`.
- Keep the formula and cask as separate packages that may be installed independently or together.
- Use the upstream GitHub tap `ondrej-winter/homebrew-tap`, exposed to Homebrew as `ondrej-winter/tap`, as the initial authoritative distribution channel.
- Before explicitly tapping the repository, support these installation commands:

```sh
brew install ondrej-winter/tap/calrelay
brew install --cask ondrej-winter/tap/calrelay
```

- After `brew tap ondrej-winter/tap`, support these short commands:

```sh
brew install calrelay
brew install --cask calrelay
```

- Treat untapped short installation from official `homebrew/core` and `homebrew/cask` as a future promotion target, not a requirement for the first public release.
- Official Homebrew promotion must preserve the formula token, cask token, executable name, app name, and observable installation contract unless a collision or Homebrew policy requires an explicitly documented migration.

### DIST-02 — Stable release and version identity

- Every Homebrew-distributed version is an explicitly published stable release identified by a version tag in the form `vX.Y.Z`.
- Release tags and their associated source and binary assets are immutable after publication.
- One release version identifies both the CLI and GUI products for that release.
- The release tag `vX.Y.Z`, formula version, cask version, `calrelay --version`, and `CalRelay.app` `CFBundleShortVersionString` all identify the same `X.Y.Z` release.
- `CFBundleVersion` is a monotonically increasing build identifier and need not equal `X.Y.Z`.
- The production app retains the application name `CalRelay`, bundle identifier `dev.owinter.CalRelay`, executable identity expected by its bundle, and one stable Apple Developer Team identity after the first public release.
- Changing the bundle identifier or Developer Team identity is a distribution migration because it can affect Calendar permission, persisted app state, and launch-at-login continuity.

### DIST-03 — Homebrew formula contract

- Build the `calrelay` CLI from the immutable source of the selected stable release.
- Verify every downloaded source or dependency artifact with a cryptographic checksum.
- Formula installation must not rely on a moving branch, mutable URL, or unlocked dependency resolution.
- Formula installation succeeds without downloading undeclared dependencies during the build phase.
- The committed `Package.resolved` remains authoritative for Swift package dependency versions.
- Install one executable named `calrelay` into Homebrew's executable path.
- Do not install `CalRelay.app` from the formula.
- Support only operating systems and architectures on which the packaged release is declared and validated to work.
- Formula installation and testing do not request Calendar permission, access or mutate calendars, require user configuration, launch `CalRelay.app`, or register launch-at-login.
- The installed executable supports non-EventKit smoke verification through `calrelay --version` and `calrelay --help`.
- Runtime command and safety behavior remains owned by [`cli-spec.md`](cli-spec.md).

### DIST-04 — Homebrew cask contract

- Install an upstream-produced release artifact containing `CalRelay.app`.
- Do not rebuild the application from source during cask installation.
- Sign the distributed application with a valid Developer ID Application identity, hardened runtime, and a secure signing timestamp.
- Submit the distributed application to Apple's notarization service, staple its notarization ticket when the artifact format permits it, and require it to pass strict signature verification and normal Gatekeeper assessment.
- Do not require users to bypass Gatekeeper, disable System Integrity Protection, remove quarantine manually, or use an unsigned build.
- Install `CalRelay.app` as a normal macOS application and do not install or link the `calrelay` CLI from the cask.
- Cask installation and verification do not launch the app automatically, request Calendar or notification permission, register launch-at-login, read configuration, or access or mutate calendars.
- Support every macOS version and processor architecture declared by the cask.
- An architecture-specific artifact is permitted only when the cask accurately restricts installation to that architecture.
- App behavior after an intentional user launch remains owned by [`macos-app-spec.md`](macos-app-spec.md).

### DIST-05 — Formula and cask coexistence

- A user may install both `brew install calrelay` and `brew install --cask calrelay` after configuring the owning tap or after later official promotion.
- Installing one package must not overwrite, link, remove, or claim ownership of artifacts installed by the other.
- The CLI and app continue to use the canonical configuration contract in [`configuration-spec.md`](configuration-spec.md).
- Installation order does not affect product behavior.
- Upgrading or uninstalling the formula must not modify the installed application.
- Upgrading or uninstalling the cask must not remove the formula executable.
- Neither package creates, rewrites, migrates, or deletes the user's YAML configuration as part of installation, upgrade, or uninstallation.

### DIST-06 — Upgrade and uninstallation behavior

- `brew upgrade calrelay` replaces the CLI with the selected newer stable version and leaves user configuration untouched.
- `brew upgrade --cask calrelay` replaces the application while preserving its bundle identifier and distribution-signing identity.
- An app upgrade does not automatically launch CalRelay or begin reconciliation.
- A cask upgrade preserves persisted app state that remains compatible with the new version.
- After an app upgrade, launch-at-login either remains healthy or is reported through the existing actionable launch-at-login recovery behavior.
- An upgrade must never report launch-at-login as healthy when macOS cannot launch the installed application.
- Ordinary formula and cask uninstallation remove their installed program artifacts but do not delete `~/.config/calrelay/config.yaml`, alternate user-created configuration files, calendar events, or unrelated user files.
- Uninstallation does not launch either product or perform Calendar mutation.
- The first distribution milestone does not provide an automatic destructive `zap` operation for configuration, app state, Calendar permissions, or calendar data.
- Reinstallation after ordinary uninstallation uses the same configuration location and may reuse compatible persisted app state retained by macOS.

### DIST-07 — Release publication and integrity

- Publish everything required to install both packages before updating the tap to reference a stable release.
- Published release material includes immutable source for the formula, the signed and notarized app artifact for the cask, release identity and notes, and SHA-256 checksums for Homebrew-consumed artifacts.
- The tap must not reference an asset that is unpublished, incomplete, unverified, or known to fail installation.
- Release verification confirms that downloaded artifacts match the checksums committed to the formula and cask.
- Do not replace an existing release asset under the same version. Correct an artifact through a new release version and new checksums.
- The release process may be automated or manual, but it must be reproducible and produce the same required verification evidence.

### DIST-08 — Distribution privacy and credential safety

- Homebrew installation, upgrade, audit, and uninstallation do not require access to real Calendar data.
- Default release validation uses non-EventKit checks. Manual integration validation uses only harmless, dedicated calendars under the repository's local-system safety policy.
- Release artifacts, logs, workflow output, checksums, formulae, casks, and documentation must not contain Developer ID private keys, certificate passwords, notarization credentials, App Store Connect private keys, authorization headers, repository tokens, raw CalRelay configuration, calendar names, event titles, EventKit identifiers, or EventKit object dumps.
- Supply signing and notarization credentials through an approved local or CI secret mechanism and do not commit them to either repository.
- Release workflows must not persist sensitive credentials in downloadable build artifacts or diagnostic logs.

### DIST-09 — Release failure and recovery

- Retain an identifiable previously known-good stable version until a new release has passed installation and launch verification.
- If a release is found defective before the tap is updated, keep the tap on the previous known-good version.
- If a defective release has reached the tap, recover by restoring the tap to a previous immutable known-good release or publishing a corrected newer release.
- Recovery must not silently replace a defective release artifact under its existing version.
- A package rollback or reinstall must not automatically reverse calendar mutations made by an earlier application or CLI run.
- Calendar mutation recovery remains governed by the reconciliation, cleanup, and partial-failure contracts in the existing capability specifications.
- Remove or disable a security-compromised artifact and document the action rather than retaining it as an installable version merely for downgrade convenience.

### DIST-10 — Documentation and official Homebrew promotion

- User documentation clearly distinguishes CLI formula installation, app cask installation, installing both, supported macOS versions and architectures, upgrades, ordinary uninstallation, the retained configuration location, and Calendar-permission setup through the app.
- Do not present untapped `brew install calrelay` or `brew install --cask calrelay` as globally available until official Homebrew inclusion exists or the preceding tap command is part of the documented setup.
- Promotion to `homebrew/core` or `homebrew/cask` does not require a product behavior change.
- Retain the upstream tap as the initial release channel until an explicit migration to official Homebrew is accepted and documented.
- Official Homebrew eligibility metrics and review decisions are external policy, not CalRelay product acceptance criteria.

## Implementation freedoms

- The signed app artifact may use ZIP, DMG, or another Homebrew-cask-compatible format when every signing, notarization, integrity, and installation requirement holds.
- The formula may make pinned Swift dependencies available through Homebrew resources, SwiftPM mirrors, a release source bundle, or another reproducible offline mechanism.
- Releases may be built locally or in CI.
- The tap may be updated manually or automatically after required verification succeeds.
- The app may be universal or architecture-specific when declared compatibility is accurate.
- No self-update mechanism is required. Homebrew owns updates for Homebrew-installed copies.

## Compatibility and breaking changes

- Renaming the `calrelay` executable, formula token, cask token, `CalRelay.app`, or its bundle identifier is a distribution-breaking change.
- Changing the Developer Team signing identity, canonical configuration path, release version semantics, or formula/cask coexistence is a distribution-breaking change.
- Removing support for a previously supported architecture or macOS version requires explicit compatibility documentation.
- Making Homebrew installation launch the app, request permission, mutate calendars, or delete user configuration during ordinary upgrade or uninstallation is a breaking behavioral change.
- Moving from the upstream tap to official Homebrew is not itself breaking when names, artifacts, user data, and runtime behavior remain compatible.

## Constraints and downstream decisions

- Keep release credentials and signing identities outside the repository and its generated artifacts.
- Preserve SwiftPM as the source of truth for products, targets, and dependency versions.
- Keep local ad-hoc app packaging distinct from production distribution signing and notarization.
- Before the first production-signed release, accept an ADR covering Developer ID identity ownership, hardened-runtime and notarization policy, signing credential custody, production artifact architecture, separation of local and production packaging, and immutable-release recovery.
- Do not make official Homebrew acceptance a release blocker when the upstream tap contract is satisfied.

## Validation

- Run the repository source checks required by `AGENTS.md` for implementation changes.
- Verify the CLI release build and non-EventKit process smoke checks.
- Verify production app assembly, strict code signature, notarization ticket, and Gatekeeper assessment.
- Verify Homebrew formula style, audit, build, install, upgrade, and uninstall behavior.
- Verify Homebrew cask style, audit, install, launch, upgrade, and uninstall behavior.
- Verify formula/cask coexistence and checksums against published artifacts.
- Use a clean machine or clean macOS user for manual app validation covering permission presentation and launch-at-login recovery.
- Do not use real EventKit mutation as routine release automation.

## Acceptance checks

- **DIST-AC-01:** A stable tag, formula, cask, CLI `--version`, and app short version all report the same release version.
- **DIST-AC-02:** Re-downloading every published artifact for a release produces the checksum recorded by its formula or cask, and previously published assets remain unchanged.
- **DIST-AC-03:** On a clean supported Mac, the fully qualified formula command installs `calrelay`; `calrelay --version` and `calrelay --help` succeed without configuration, Calendar access, or permission prompts.
- **DIST-AC-04:** Formula installation uses the locked dependency set and succeeds without undeclared network dependency resolution during its build phase.
- **DIST-AC-05:** On a clean supported Mac, the fully qualified cask command installs `CalRelay.app`, and the installed app passes signature, notarization, and Gatekeeper verification without security bypasses.
- **DIST-AC-06:** Installing the formula and cask in either order leaves both `calrelay` and `CalRelay.app` available and independently upgradeable and uninstallable.
- **DIST-AC-07:** Installing, upgrading, and uninstalling either package neither requests Calendar permission nor reads or mutates calendars.
- **DIST-AC-08:** Formula and cask upgrades preserve the canonical YAML configuration, and the app upgrade retains its bundle identifier and either preserves launch-at-login health or presents the existing recovery state.
- **DIST-AC-09:** Ordinary uninstallation removes the selected package but retains user configuration and leaves the other package, when installed, operational.
- **DIST-AC-10:** Release logs and artifacts contain none of the prohibited credentials, configuration, calendar data, or EventKit identifiers.
- **DIST-AC-11:** A simulated defective release can be withheld or recovered without changing an already published asset and without performing automatic calendar rollback.
- **DIST-AC-12:** Documentation installation commands work exactly as documented for users who have not previously configured the tap.
- **DIST-AC-13:** Every cask-declared operating-system and architecture combination launches successfully; unsupported combinations are rejected by metadata rather than failing after installation.
- **DIST-AC-14:** A Homebrew-installed app requests Calendar permission only through the explicit setup or recovery action defined by the calendar-access and macOS-app specifications.

## Open decisions

- None. Revision 1 selects the upstream tap as the initial release channel while leaving artifact format, release execution environment, dependency-prefetch mechanism, and universal versus architecture-specific app packaging as implementation freedoms subject to the requirements above.