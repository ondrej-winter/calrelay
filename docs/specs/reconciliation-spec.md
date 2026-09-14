# Spec: Calendar Relay Reconciliation

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — split from the accepted EventKit MVP specification on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/reconciliation-spec.md`.
- **Scope:** Pure visible-set reconciliation and deterministic application behavior.

## Required outcomes

### RECON-01 — Visible-set model

- Use visible-set reconciliation rather than provider IDs, hidden metadata, notes metadata, or a local identity mapping store.
- Treat generated events as disposable projections.
- A renamed or changed source event is not detected as a rename: delete the old projection when it is no longer expected and create the newly expected projection.
- For MVP equality, compare `calendar + title + start + end + all-day flag`.
- Timezone normalization may be added after EventKit behavior is tested.

### RECON-02 — Idempotency and testability

- A second reconciliation after a successful apply produces no changes.
- Keep reconciliation logic pure and unit-testable.
- Use deterministic tests with fakes for core reconciliation rules.

## Acceptance checks

- **RECON-AC-01:** A second reconciliation after successful apply is a no-op.
- **RECON-AC-02:** Renaming a representative source event deletes the old projection and creates the new projection.
- **RECON-AC-03:** Deterministic tests cover the reconciliation rules without real EventKit access.

## Constraints

- Do not add persistent identity stores, hidden source IDs, or notes metadata without an explicit decision.
- Do not place reconciliation orchestration in SwiftUI views, app delegates, or menu handlers.