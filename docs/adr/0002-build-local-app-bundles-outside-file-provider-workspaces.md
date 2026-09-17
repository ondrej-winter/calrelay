# 0002. Build Local App Bundles Outside File-Provider Workspaces

Date: 2026-09-17
Status: Accepted

## Context

Manual validation reproduced a `make app` failure: the workspace's file provider
reattaches `com.apple.FinderInfo` to the generated app bundle, including during
signing after the build script strips extended attributes. Strict code-signature
verification rejects that metadata. A metadata-free copy outside the workspace
passed signing, delayed strict verification, and launch.

## Decision

Assemble and sign local development app bundles under a workspace-keyed directory
in the current user's `Library/Caches/dev.owinter.CalRelay/builds`. Keep
`.build/CalRelay.app` as a symlink to that bundle so the documented launch command
remains unchanged. Preserve `dev.owinter.CalRelay`, ad-hoc signing, attribute
cleanup, and strict verification; do not retry away or suppress signing errors.

## Consequences

- Generated bundles no longer depend on the workspace's file-provider metadata
  behavior. Source, SwiftPM products, and dependencies remain in their existing
  locations.
- Each workspace has its own stable development-bundle location. The workspace
  key is derived from its absolute path, not configuration or Calendar content.
- The cache is disposable: `make app` recreates the current workspace's bundle.
  Removing SwiftPM products does not remove the external cached bundle; deleting
  a workspace can leave its cached bundle behind.
- If the local cache is itself managed by a metadata-reattaching provider, signing
  still fails visibly. No signature-validation bypass is introduced.
- This changes development packaging only, not permission ownership, distribution
  signing, scheduled execution, or the closed-app lifecycle boundary.

## Alternatives considered

| Option | Reason rejected |
| --- | --- |
| Strip attributes repeatedly inside the workspace | Already failed during signing; races with the file provider. |
| Disable strict verification | Hides a broken bundle instead of fixing packaging. |
| Use a new temporary location on every build | Loses a stable development launch location and accumulates copies. |
| Move the repository | Unnecessary disruption to the user's source workspace. |