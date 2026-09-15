# Spec: Calendar Relay Reconciliation

## Specification record

- **Status:** Accepted.
- **Revision:** 2 — accepted on September 15, 2026 after the CLI Revision 2 stress test; exact shared-plan explanation and its semantic classifications were added.
- **Canonical artifact:** `docs/specs/reconciliation-spec.md`.
- **Scope:** Pure visible-set reconciliation, deterministic application behavior, and exact reconciliation explanation.

## Required outcomes

### RECON-01 — Visible-set model

- Use visible-set reconciliation rather than provider IDs, hidden metadata, notes metadata, or a local identity mapping store.
- Treat generated events as disposable projections.
- A renamed or changed source event is not detected as a rename: delete the old projection when it is no longer expected and create the newly expected projection.
- For MVP equality, compare `calendar + title + start + end + all-day flag`.
- EventKit event and calendar IDs used by explanation are diagnostic correlation data only. They must not change visible-set equality, routing, ownership, or create/delete decisions.
- Timezone normalization may be added after EventKit behavior is tested.

### RECON-02 — Idempotency and testability

- A second reconciliation after a successful apply produces no changes.
- Keep reconciliation logic pure and unit-testable.
- Use deterministic tests with fakes for core reconciliation rules.

### RECON-03 — Shared plan and exact explanation

- One deterministic reconciliation computation consumes one validated settings value and one loaded calendar/event snapshot over the effective window defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- Dry-run returns the plan from that computation. Explanation annotates that same plan and computation; it must not contain a second or approximate implementation of the reconciliation rules.
- For the same loaded snapshot, explanation's planned creates and deletes exactly equal the dry-run plan.
- Explanation contains two semantic sections:
  1. every input event read from every configured calendar in the effective window;
  2. every planned create and delete with causal links to the applicable input events and reconciliation rules.
- Each input event is identified by its EventKit event ID and calendar ID for within-output correlation and receives every applicable classification in three independent dimensions:
  - **Eligibility:** included, all-day, cancelled, declined, tentative, or unsupported availability.
  - **Routing/source treatment:** work-to-hub source, hub personal source, recognized-prefix hub source, unknown-prefix hub source, or feedback-suppressed work projection.
  - **Existing-state disposition:** whether it satisfies an expected projection or has no matching expectation, and whether it is retained, preserved as unmanaged/unknown, selected as a stale managed deletion, or selected as a surplus managed duplicate deletion.
- The explanation reason model is a stable semantic contract. Presentation wording, headings, ordering, and row formatting are not stable contracts.
- Planned-create explanations identify a missing expected projection, cite the causal source EventKit event ID or IDs, and identify the destination EventKit calendar ID.
- Planned-delete explanations identify the exact existing EventKit event ID and distinguish a stale managed projection from a surplus managed duplicate.
- Explanation follows the routing rules in [`routing-spec.md`](routing-spec.md) and the eligibility and ownership rules in [`projection-and-safety-spec.md`](projection-and-safety-spec.md) rather than redefining them.

## Acceptance checks

- **RECON-AC-01:** A second reconciliation after successful apply is a no-op.
- **RECON-AC-02:** Renaming a representative source event deletes the old projection and creates the new projection.
- **RECON-AC-03:** For an identical loaded snapshot, dry-run and explanation contain exactly the same planned creates and deletes.
- **RECON-AC-04:** Explanation accounts for every input event across eligibility, routing/source treatment, and existing-state disposition and accounts for every planned action with the required causal IDs.
- **RECON-AC-05:** Representative explanation tests cover excluded inputs, feedback suppression, personal and prefixed hub routing, already-satisfied projections, unmanaged/unknown preservation, stale managed deletion, surplus managed duplicate deletion, and missing-projection creation.
- **RECON-AC-06:** Exact duplicate visible events remain distinguishable in explanation by EventKit event ID without changing visible-set planning equality.
- **RECON-AC-07:** Deterministic tests cover planning and explanation without real EventKit access or a second implementation of the reconciliation rules.

## Constraints

- Do not add persistent identity stores, hidden source IDs, or notes metadata without an explicit decision.
- Do not use EventKit IDs as reconciliation keys, selector fallbacks, ownership markers, or substitutes for visible-set equality.
- Do not derive explanation actions independently from the shared reconciliation plan.
- Do not place reconciliation orchestration in SwiftUI views, app delegates, or menu handlers.

## Compatibility and breaking changes

- Revision 2 replaces eligibility-only explanation with a complete explanation of every input classification and every planned create/delete.
- Explanation DTOs and formatters may require new causal and disposition data, but the visible-set planning rules are unchanged.
- EventKit IDs become visible diagnostic correlation values only in successful, explicitly requested CLI explanation as permitted by [`calendar-access-spec.md`](calendar-access-spec.md).
