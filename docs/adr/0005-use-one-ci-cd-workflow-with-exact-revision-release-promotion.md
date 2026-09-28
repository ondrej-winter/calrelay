# 0005. Use One CI/CD Workflow with Exact-Revision Release Promotion

Date: 2026-09-28
Status: Accepted

## Context

ADR 0004 established the protected signed-release architecture, immutable
candidate retention, least-privilege publication, and resumable recovery. The
repository still used a release-only workflow, so ordinary CI and protected
release orchestration did not share one provider entry point. Resumption also
required a clear distinction between the original candidate source revision and
the release commit restored from the retained `source.bundle`.

Combining CI and release automation must not expose protected credentials to
pull requests or ordinary pushes, serialize unrelated CI behind publication, or
cause a protected job to rebuild or revalidate a different revision from the one
already accepted by the source-quality gate.

## Decision

CalRelay will use `.github/workflows/ci-cd.yaml` as the single GitHub Actions
entry point for pushes, pull requests, bootstrap, and retained-candidate
resumption. The workflow separates responsibility into three jobs:

- `portable-ci` runs portable tooling checks, selects release context, and
  verifies retained workflow provenance without protected credentials.
- `apple-ci` runs the complete source-quality gate on the exact selected
  revision. During resumption it restores and validates the retained release
  commit because that commit may not exist in the remote repository.
- `protected-release` receives protected credentials and joins the
  non-cancelling publication queue only for a selected release whose exact
  revision was reported as validated by `apple-ci`. It does not rerun
  `make format-check` or `make check`.

Retained candidates distinguish `source_revision`, the original candidate
source, from `validation_revision`, the restored release commit. Resume
provenance accepts the current `CI/CD` workflow identity and explicitly
allowlists the historical `Public-beta release` identity so unexpired retained
candidates survive the workflow rename.

## Consequences

### Positive

- Every push, pull request, and manual run enters one visible CI/CD graph.
- Pull requests and ordinary pushes can run the full source gate without access
  to signing, notarization, or publication credentials.
- Protected publication trusts exact-revision evidence instead of repeating
  expensive source gates after environment approval.
- Historical retained candidates remain resumable without accepting arbitrary
  workflow identities.

### Negative

- The workflow has explicit revision and provenance outputs that must remain
  synchronized across all three jobs.
- Resume validation depends on the retained source bundle because the release
  commit may never have reached the remote repository.
- The historical workflow identity must remain in the provenance allowlist until
  all candidates retained by that workflow have expired or completed.

### Neutral

- ADR 0004 remains the authority for release identity, signing, notarization,
  credential custody, immutable publication, and recovery architecture.
- Product-facing release behavior remains owned by
  `docs/specs/distribution-spec.md`.

## Alternatives considered

| Option | Reason rejected |
| --- | --- |
| Keep separate CI and release workflow files | Duplicates entry points and makes exact promotion from ordinary CI evidence harder to review. |
| Run source gates again in `protected-release` | Repeats expensive checks after approval and weakens the explicit exact-revision promotion boundary. |
| Validate only the original source revision during resumption | The retained release commit contains the prepared version and tag and is the exact source used by the immutable candidate. |
| Accept any previous workflow identity during resumption | Permits an unrelated workflow run to supply a candidate and fails the provenance requirement. |