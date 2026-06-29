# PR and commit hygiene

Use these rules to keep reviews fast, changesets focused, and CI reliable.

## PR size limits

- **Should** keep PRs under about 400 changed lines when practical.
- **Must** split large refactors into sequenced PRs unless explicitly approved.
- **Should** include a concise summary and test evidence in the PR description.
- **Should** call out rollout, migration, rollback, data migration, signing, entitlement, permission, or feature-flag considerations when operational or user risk is meaningful.

## Commit message style

- **Must** use imperative, present tense, such as "Add invoice repository adapter".
- **Should** include a scope prefix when useful, such as `docs:`, `tests:`, `adapters:`, or `ui:`.
- **Must** keep commits focused; avoid mixing unrelated changes.
- **Must not** leave `WIP`, `fixup!`, or `squash!` commits in shared history unless the team workflow explicitly relies on autosquash later.

## Review checklist

- **Must** verify boundary compliance between domain, application, adapters, UI, and platform APIs.
- **Must** ensure tests are updated for behavior changes.
- **Should** confirm docs are updated when configuration, permissions, entitlements, setup, or usage changes.
- **Should** check logging and observability coverage on new I/O paths and long-running workflows.
- **Should** verify dependency, package, project, workspace, scheme, and lockfile changes are intentional and explained.
- **Must** check that secrets, signing credentials, provisioning profiles with private material, private endpoints, personal data, and unnecessary sensitive artifacts are not introduced.

## CI expectations

- **Must** run the local quality gate before handoff. See `011-tooling-and-ci.md`.
- **Must** fix CI failures at the root cause instead of bypassing checks.
- **Should** document any validation that could not be run locally, including missing Xcode versions, unavailable simulators/devices, signing constraints, or unavailable macOS capabilities.
