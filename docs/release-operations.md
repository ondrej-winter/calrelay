# CalRelay release operations

This runbook is for maintainers operating the protected public-beta release
workflow. It complements the accepted
[distribution specification](specs/distribution-spec.md) and
[ADR 0004](adr/0004-automate-signed-public-beta-releases.md); it does not replace
their product or security contracts.

> **Availability:** As of September 27, 2026, the public channel is not live. The
> dedicated GitHub App is installed and its protected credential roles are
> configured. Protected token minting for both `ondrej-winter/calrelay` and
> `ondrej-winter/homebrew-tap` with effective `contents: write` access, the preview
> hosted-runner release lane, production signing/notarization evidence, and initial
> `v1.0.0` publication remain to be exercised or validated.

## Invariants

- Release only from protected `master` through `.github/workflows/release.yml`.
- Keep the source repository and `ondrej-winter/homebrew-tap` protected against
  force-push replacement.
- Use the dedicated least-privilege GitHub App, never a personal access token.
- Keep release tags, assets, checksums, retained candidates, and tap content
  immutable for a version.
- Do not move or replace same-version tags or assets.
- Do not put secret values, raw configuration, calendar names, event titles, or
  EventKit identifiers in logs, artifacts, documentation, or handoffs.
- Use no real Calendar data in the required release gate.

## Protected configuration

Configure these roles in the protected `public-beta-release` environment without
recording their values in repository files:

| Role | Custody and use |
| --- | --- |
| `CALRELAY_DEVELOPER_ID_P12` | Protected secret containing the Developer ID certificate export. Imported only into the ephemeral release keychain. |
| `CALRELAY_DEVELOPER_ID_P12_PASSWORD` | Protected secret used only to import that certificate. |
| `CALRELAY_NOTARY_API_KEY_P8` | Protected team App Store Connect API-key material used by `notarytool`. |
| `CALRELAY_NOTARY_KEY_ID` | Protected notarization key identifier. |
| `CALRELAY_NOTARY_ISSUER_ID` | Protected notarization issuer identifier. |
| `CALRELAY_DEVELOPER_TEAM_ID` | Protected environment variable and stable, non-secret signing invariant. |
| `CALRELAY_SIGNING_CERTIFICATE_SHA1` | Protected environment secret containing the expected Developer ID Application certificate's canonical 40-character SHA-1 certificate fingerprint. It selects the imported identity without depending on its locale-sensitive display name. |
| `CALRELAY_RELEASE_GITHUB_APP_PRIVATE_KEY` | Protected secret for the dedicated source/tap publication app. |
| `CALRELAY_RELEASE_GITHUB_APP_ID` | Protected environment variable identifying that GitHub App. |
| `CALRELAY_TAP_REPOSITORY` | Protected environment variable set exactly to `ondrej-winter/homebrew-tap`. |

The release build verifies that the ephemeral keychain contains exactly one valid
Developer ID Application identity with the configured fingerprint before any
release product is compiled. The fingerprint is a non-secret identity selector;
the certificate export and its password remain protected secrets.

The release job uses GitHub's standard hosted Apple Silicon `xcode-27` image. As
of September 27, 2026, that image is in public preview and provides an ephemeral
macOS 27 VM with Xcode 27, Swift 6.4, the macOS 27 SDK, Homebrew, and `gh`; the
workflow installs the pinned Node runtime explicitly and downloads the exact
official portable SwiftLint artifact recorded in `scripts/release/toolchain.json`.
It verifies the artifact SHA-256 and reported SwiftLint version before running
the source quality gate. Preview image contents and capacity may change. Before
bootstrap and after an image rollout, verify the image inventory and let the
workflow fail closed if the pinned tool or production OS, architecture, Xcode,
Swift, or SDK contract no longer matches.

## Bootstrap `v1.0.0`

Before bootstrap, verify immutable GitHub releases, protected `master` branches,
the `public-beta-release` environment, required reviewers or deployment controls,
that the protected GitHub App identity can mint one installation token for both
repositories with effective `contents: write` access, `xcode-27` availability and
toolchain compatibility, and every protected role above.

Dispatch the first release manually:

```sh
gh workflow run release.yml -f bootstrap=true
```

Do not combine `bootstrap` with `resume_run_id`. The workflow must select exactly
`1.0.0`, run source quality gates, build and verify signed/notarized products,
retain the immutable candidate, publish source and assets, redownload and verify
them, validate Homebrew lifecycle behavior, and publish formula and cask together.

Bootstrap is not complete until the documented installation commands succeed
from a clean supported Mac without a preconfigured tap. Record only privacy-safe
evidence. Do not claim the channel is live before this checkpoint completes.

## Automatic operation

After bootstrap, every qualifying push to `master` enters the one non-cancelling
release queue. A `fix` or `fix!` selects a patch within `1.x`; a `feat` or `feat!`
selects a minor within `1.x`. Other commits do not publish. Breaking markers add
release context but never select `2.0.0`.

The unprivileged analysis job decides whether a release is needed. Signing and
publication credentials are available only in the protected release job. Remote
source advancement, candidate mismatch, tag or asset mismatch, partial tap state,
or failed evidence must stop publication rather than repair immutable state in
place.

## Credential rotation

Rotate credentials through the protected environment and provider controls; do
not place old or new values in commits, issue comments, shell traces, artifacts,
or task handoffs.

1. Rotate the provider credential and update its matching protected secret or
   variable.
2. Keep related roles synchronized: rotate the Developer ID export and import
   password together; rotate the App Store Connect key material with its key ID
   and issuer metadata; rotate the GitHub App private key without changing its
   least-privilege installation scope.
3. Verify repository and environment access controls before dispatching a
   protected release.
4. Let the complete release gate prove signing, notarization, GitHub publication,
   Homebrew validation, and cleanup. Do not add a credential-printing diagnostic.

Changing `CALRELAY_DEVELOPER_TEAM_ID`, the production bundle identity, or the
expected signing team is a distribution migration, not routine rotation. Stop and
obtain an accepted specification revision before making that change.

## Resume an incomplete release

The workflow retains the exact source-bound `release-candidate` Actions artifact
for 30 days. Use the original protected workflow run ID:

```sh
gh workflow run release.yml -f resume_run_id=123456789
```

Do not rebuild the same version. Resumption downloads the retained candidate,
verifies workflow provenance and exact artifact/source bytes, restores the
release commit and tag from `source.bundle`, reruns source gates, and continues
from the persisted stage. Matching published state is accepted; mismatched state
fails closed.

If the retained Actions artifact is missing or expired, do not reconstruct or
replace its tag or assets. Investigate the incomplete release. Resume only when
the immutable identity can still be proved; otherwise use the higher-patch
correction path when applicable.

`scripts/release/release-state.mjs` is the repository-owned state authority. Its
`resume` and `advance` operations must observe the exact retained candidate rather
than a rebuilt substitute.

## Correct a defective release

If the defect is found before the tap is updated, keep the tap on the previous
known-good version and resume the incomplete candidate only when all immutable
identity checks pass.

If the defective version is already tap-published, correct it with a higher patch
version containing new artifacts and checksums. Never perform a same-version
correction, move the old tag, replace old assets, or automatically reverse any
calendar mutations from an earlier CalRelay run.

The repository policy check for a proposed correction is:

```sh
node scripts/release/release-state.mjs corrective --defective-version 1.2.3 --next-version 1.2.4
```

The command validates the version transition; the ordinary protected release
workflow publishes the corrective version.

## Respond to a compromised artifact

Treat a compromised artifact as an incident, not an ordinary defect. Preserve
evidence without exposing sensitive content, revoke affected credentials, and
prevent further installation of the compromised artifact through protected
source, release, or tap controls. A retained candidate can be marked disabled
with the `disable` operation of `scripts/release/release-state.mjs`.

Document the compromised artifact, affected version, disablement action, and
credential rotations in the approved incident system. If the affected version is
current in the tap, remove or disable its installability through a reviewed
forward change, keeping formula/cask state consistent. Publish any safe
replacement only as a new higher patch version. Never retain a known-compromised
artifact as installable merely for downgrade convenience.

## Runner recovery

Each `xcode-27` job receives a fresh GitHub-hosted VM that GitHub disposes after
the job. If a runner fails, do not copy or reuse its workspace. Confirm cleanup
steps ran where logs are available, rotate any credential that may have been
exposed, and resume from the retained workflow candidate on a fresh GitHub-hosted
VM; do not rebuild the same version.

Because `xcode-27` is a public preview image, treat image drift, unavailability,
or sustained queueing as a provider dependency failure. Recheck the official
runner-image announcement and inventory, and update the workflow and toolchain
contract only through a reviewed change. Do not bypass production preflight or
switch runner labels ad hoc during an immutable release.

If failure occurred before a candidate was retained, no immutable release exists
and a fresh protected run may prepare the selected version only after remote
source state is re-evaluated. If any source publication occurred, use the normal
resumption checks instead.

## Tap recovery

If the tap is unavailable, pause publication before the tap stage and retain the
previous known-good packages. Restore protected `master`, the GitHub App
installation, and the expected `Formula/` and `Casks/` paths before resuming.

The tap must contain both CalRelay packages or neither at a version. Never expose
only one new package, force-push rewritten history, or edit a published version in
place. If unrelated commits advance protected tap `master`, resumption may proceed
only when the recorded package commit remains an ancestor and the formula/cask
bytes match the retained candidate. Resolve compromised or defective content
through the dedicated incident or higher-patch procedures above.

## Validation and evidence

Repository changes to release tooling use the commands in
[Development workflow](development.md). Real Developer ID signing, notarization,
stapler, Gatekeeper, live Homebrew, protected concurrency, GitHub App, bootstrap,
and automatic-publication evidence must come from the protected release lane.
Keep those checkpoints open until that environment actually runs them.