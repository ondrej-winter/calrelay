# Spec: Calendar Relay Reconciliation

## Specification record

- **Status:** Accepted.
- **Revision:** 4 — accepted on September 16, 2026 after the macOS automation stress test; reviewed-plan freshness and fresh automatic-run planning were defined without changing reconciliation rules.
- **Canonical artifact:** `docs/specs/reconciliation-spec.md`.
- **Scope:** Pure visible-set ordinary reconciliation, deterministic cleanup planning, application behavior, and exact ordinary reconciliation explanation.

## Required outcomes

### RECON-01 — Visible-set ordinary reconciliation model

- Use visible-set reconciliation rather than provider IDs, hidden metadata, notes metadata, or a local identity mapping store.
- Treat generated events as disposable projections.
- A renamed or changed source event is not detected as a rename: delete the old projection when it is no longer expected and create the newly expected projection.
- For ordinary MVP equality, compare `calendar + title + start + end + all-day flag`.
- EventKit event and calendar IDs used by explanation are diagnostic correlation data only. They must not change visible-set equality, routing, ownership, marker parsing, or create/delete decisions.
- Timezone normalization may be added after EventKit behavior is tested.

### RECON-02 — Idempotency and testability

- A second ordinary reconciliation after a successful apply produces no changes.
- A second legacy-cleanup dry-run over an unchanged successful cleanup snapshot produces no deletions.
- Keep ordinary reconciliation and cleanup planning logic pure and unit-testable.
- Use deterministic tests with fakes for core reconciliation and cleanup rules.

### RECON-03 — Shared ordinary plan and exact explanation

- One deterministic ordinary reconciliation computation consumes one validated non-migration-pending settings value and one loaded calendar/event snapshot over the effective ordinary window defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- Ordinary dry-run returns the plan from that computation. Explanation annotates that same plan and computation; it must not contain a second or approximate implementation of ordinary reconciliation rules.
- For the same loaded snapshot, explanation's planned creates and deletes exactly equal the ordinary dry-run plan.
- Explanation contains two semantic sections:
  1. every input event read from every configured calendar in the effective ordinary window; and
  2. every planned create and delete with causal links to the applicable input events and reconciliation rules.
- Each input event is identified by its EventKit event ID and calendar ID for within-output correlation and receives every applicable classification in three independent dimensions:
  - **Eligibility:** included, all-day, cancelled, declined, tentative, or unsupported availability.
  - **Routing/source treatment:** work-to-hub source, hub personal source, exact local-marker hub source, non-local valid-marker hub source, invalid/unmarked hub source, or feedback-suppressed marked work projection.
  - **Existing-state disposition:** whether it satisfies an expected projection or has no matching expectation, and whether it is retained, preserved as unmanaged/non-local, selected as a stale managed deletion, or selected as a surplus managed duplicate deletion.
- The explanation reason model is a stable semantic contract. Presentation wording, headings, ordering, and row formatting are not stable contracts.
- Planned-create explanations identify a missing expected projection, cite the causal source EventKit event ID or IDs, and identify the destination EventKit calendar ID.
- Planned-delete explanations identify the exact existing EventKit event ID and distinguish a stale managed projection from a surplus managed duplicate.
- Explanation follows the routing rules in [`routing-spec.md`](routing-spec.md) and the eligibility, exact marker, and ownership rules in [`projection-and-safety-spec.md`](projection-and-safety-spec.md) rather than redefining them.

### RECON-04 — Deterministic legacy-cleanup plan

- One deterministic cleanup computation consumes one validated migration-pending settings value and one loaded snapshot of every configured calendar over the cleanup range defined in [`configuration-spec.md`](configuration-spec.md).
- The cleanup plan contains deletes only. It contains no creates, ordinary stale deletes, routing output, or projection generation.
- An event is selected exactly when its title has valid marked-title shape and its parsed case-sensitive marker equals one configured legacy marker.
- Cleanup dry-run returns that exact plan. Cleanup apply executes that plan after complete cleanup preflight; it must not independently rescan or approximate the deletion criteria after mutation begins.
- The required post-apply verification is a fresh read and exact no-match postcondition check, not a second cleanup plan. It does not authorize additional unplanned deletions in the same run.
- Duplicate legacy-marker entries and collisions with current markers cannot reach cleanup planning because structural validation rejects them.
- Cleanup-result semantics are local and point-in-time. Plan completion does not prove global retirement and does not prevent another computer from recreating matching events.

### RECON-05 — Reviewed app plans and fresh automatic plans

- A plan presented by the app for manual ordinary apply or legacy-cleanup apply is a reviewed plan, not authority to mutate indefinitely from that old snapshot.
- Immediately before a reviewed app apply begins mutation, the app loads fresh validated configuration and a fresh applicable calendar snapshot, repeats the complete applicable preflight, and computes a fresh plan with the same deterministic ordinary or cleanup computation.
- The reviewed and fresh plans match only when they contain exactly the same create and delete actions. Ordinary create identity uses the visible projection fields from `RECON-01`; delete identity includes the exact existing event selected for deletion so that one duplicate occurrence cannot substitute for another.
- If the fresh plan differs, the app performs no mutation and presents the fresh plan for a new review and confirmation. It does not apply a same-count but semantically different plan under the earlier confirmation.
- If the plans match, apply executes the fresh loaded plan. Once its first mutation begins, it does not independently rescan, re-plan, or append actions; mutation-time failure behavior remains defined by [`calendar-access-spec.md`](calendar-access-spec.md).
- Every automatic ordinary attempt, including retry and a coalesced follow-up, independently loads fresh configuration and calendar state and computes one fresh plan. It never resumes or reuses a plan from an earlier attempt or partially applied run.

## Acceptance checks

- **RECON-AC-01:** A second ordinary reconciliation after successful apply is a no-op.
- **RECON-AC-02:** Renaming a representative source event deletes the old projection and creates the new projection.
- **RECON-AC-03:** For an identical loaded ordinary snapshot, dry-run and explanation contain exactly the same planned creates and deletes.
- **RECON-AC-04:** Explanation accounts for every ordinary input event across eligibility, exact routing/source treatment, and existing-state disposition and accounts for every planned action with the required causal IDs.
- **RECON-AC-05:** Representative explanation tests cover excluded inputs, feedback suppression, personal and exact local-marker hub routing, non-local valid-marker routing, already-satisfied projections, unmanaged/non-local preservation, stale managed deletion, surplus managed duplicate deletion, and missing-projection creation.
- **RECON-AC-06:** Exact duplicate visible events remain distinguishable in explanation by EventKit event ID without changing visible-set planning equality.
- **RECON-AC-07:** Cleanup planning selects only exact legacy-marker matches and produces deletes only; post-apply verification performs no additional deletion planning and succeeds only on an exact no-match snapshot.
- **RECON-AC-08:** A representative eventual-convergence scenario demonstrates that later recreation produces a new cleanup delete without invalidating the earlier run's local point-in-time success.
- **RECON-AC-09:** Deterministic tests cover ordinary planning, explanation, and cleanup without real EventKit access or a second implementation of the rules.
- **RECON-AC-10:** App ordinary and cleanup confirmation tests recompute from fresh inputs, apply only an exactly matching fresh plan, and require renewed review for changed actions even when aggregate counts are unchanged.
- **RECON-AC-11:** Automatic retry and coalesced follow-up tests compute fresh plans and never resume an earlier or partially applied mutation plan.

## Constraints

- Do not add persistent identity stores, hidden source IDs, or notes metadata without an explicit decision.
- Do not use EventKit IDs as reconciliation keys, selector fallbacks, ownership markers, or substitutes for visible-set equality.
- Do not derive ordinary explanation actions independently from the shared ordinary plan.
- Do not combine cleanup and ordinary reconciliation into one plan or mutation run.
- Do not treat aggregate counts, plan age alone, or a fixed expiration as a substitute for exact reviewed-plan comparison.
- Do not place reconciliation or cleanup orchestration in SwiftUI views, app delegates, or menu handlers.

## Compatibility and breaking changes

- Revision 4 adds app reviewed-plan freshness and automatic-attempt freshness without changing ordinary visible-set equality, cleanup selection, or CLI non-interactive apply authorization.
- Revision 3 replaces starts-with routing classifications with exact parsed-marker classifications.
- Revision 3 adds a separate deterministic delete-only cleanup plan; it does not alter ordinary visible-set equality.
- Ordinary explanation remains the only reconciliation output allowed to include EventKit IDs under [`calendar-access-spec.md`](calendar-access-spec.md); cleanup does not add an explanation mode.
