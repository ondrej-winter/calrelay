# Spec: Calendar Relay Reconciliation

## Specification record

- **Status:** Accepted.
- **Revision:** 5 — accepted on September 16, 2026 after the projection and safety stress-test interview; logical-hub planning, cancelled managed state, replace-all duplicate handling, create-first mutation, exact occurrence targeting, and eventual-consistency boundaries were defined.
- **Canonical artifact:** `docs/specs/reconciliation-spec.md`.
- **Scope:** Pure visible-set ordinary reconciliation, deterministic cleanup planning, application behavior, and exact ordinary reconciliation explanation.

## Required outcomes

### RECON-01 — Visible-set ordinary reconciliation model

- Use visible-set reconciliation rather than provider IDs, hidden metadata, notes metadata, or a local identity mapping store.
- Treat generated events as disposable projections.
- A renamed or changed source event is not detected as a rename: delete the old projection when it is no longer expected and create the newly expected projection.
- For ordinary MVP equality, compare `calendar + title + start + end + all-day flag`.
- EventKit event and calendar IDs used by explanation are diagnostic correlation data only. They must not change visible-set equality, routing, ownership, marker parsing, or create/delete decisions.
- Every ordinary or cleanup delete action identifies the exact fetched event occurrence selected by the plan. A recurring-event deletion may target only that exact occurrence; failure to resolve it exactly stops the run without substituting another occurrence or the whole series.
- A cancelled locally managed event never satisfies an expected projection even when its visible key matches. When the projection remains expected, plan a replacement create and treat the cancelled event as stale.
- A cancelled non-local marked hub event remains preserved but does not enter the expected work-calendar blocker set.
- When exactly one non-cancelled locally managed event satisfies an expected key, retain it. When two or more locally managed events satisfy the same expected key, retain none: plan one canonical replacement create and delete every existing managed duplicate.
- Build work-calendar expectations from the reconciled logical hub state: eligible original hub events, preserved non-local non-cancelled marked hub blockers, and currently expected local work projections. Do not relay a locally owned hub projection that the same computation has classified as stale.
- Copy EventKit start/end values and the all-day flag as defined by [`projection-and-safety-spec.md`](projection-and-safety-spec.md); do not introduce separate timezone normalization.

### RECON-02 — Idempotency and testability

- A second ordinary reconciliation after a successful apply produces no changes.
- A second legacy-cleanup dry-run over an unchanged successful cleanup snapshot produces no deletions.
- Keep ordinary reconciliation and cleanup planning logic pure and unit-testable.
- Use deterministic tests with fakes for core reconciliation and cleanup rules.

### RECON-03 — Shared ordinary plan and exact explanation

- One deterministic ordinary reconciliation computation consumes one validated non-migration-pending settings value and one loaded calendar/event snapshot over the effective ordinary window defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- The separately loaded configured-calendar reads form the authoritative snapshot for that attempt. CalRelay does not claim an atomic cross-calendar snapshot, restart planning because EventKit announces a concurrent change, or require two matching complete reads; later reconciliation repairs inconsistencies caused by concurrent external changes.
- Ordinary dry-run returns the plan from that computation. Explanation annotates that same plan and computation; it must not contain a second or approximate implementation of ordinary reconciliation rules.
- For the same loaded snapshot, explanation's planned creates and deletes exactly equal the ordinary dry-run plan.
- Explanation contains two semantic sections:
  1. every input event read from every configured calendar in the effective ordinary window; and
  2. every planned create and delete with causal links to the applicable input events and reconciliation rules.
- Each input event is identified by its EventKit event ID and calendar ID for within-output correlation and receives every applicable classification in three independent dimensions:
  - **Eligibility:** reliable cancellation; current-user attendee accepted or non-accepted; no-current-user-attendee availability included, explicit free/tentative, or unsupported unknown; or marked-hub eligibility bypass.
  - **Routing/source treatment:** work-to-hub source, hub personal source, exact local-marker hub source, non-local valid-marker hub source, cancelled marked hub preservation, invalid/unmarked hub source, or feedback-suppressed marked work projection.
  - **Existing-state disposition:** whether it satisfies an expected projection or has no matching expectation, and whether it is retained, preserved as unmanaged/non-local, selected as a stale or cancelled managed deletion, or selected for replace-all managed duplicate deletion.
- The explanation reason model is a stable semantic contract. Presentation wording, headings, ordering, and row formatting are not stable contracts.
- Planned-create explanations identify a missing expected projection, cite the causal source EventKit event ID or IDs, and identify the destination EventKit calendar ID.
- Planned-delete explanations identify the exact existing occurrence selected for deletion and distinguish stale, cancelled, replace-all duplicate, and legacy-cleanup reasons.
- Explanation follows the routing rules in [`routing-spec.md`](routing-spec.md) and the eligibility, exact marker, and ownership rules in [`projection-and-safety-spec.md`](projection-and-safety-spec.md) rather than redefining them.

### RECON-04 — Deterministic legacy-cleanup plan

- One deterministic cleanup computation consumes one validated migration-pending settings value and one loaded snapshot of every configured calendar over the cleanup range defined in [`configuration-spec.md`](configuration-spec.md).
- The cleanup plan contains deletes only. It contains no creates, ordinary stale deletes, routing output, or projection generation.
- An event is selected exactly when its title has valid marked-title shape and its parsed case-sensitive marker equals one configured legacy marker.
- Cleanup dry-run returns that exact plan. Cleanup apply executes that plan after complete cleanup preflight; it must not independently rescan or approximate the deletion criteria after mutation begins.
- Cleanup preserves the exact occurrence-level delete identities produced by the shared deletion rule in `RECON-01`.
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

### RECON-06 — Ordinary mutation order and concurrency

- Ordinary apply attempts every planned create before attempting any planned delete. Partial failure therefore biases toward temporary duplicates and over-blocking rather than availability gaps.
- If any create or delete fails, stop immediately as defined by [`calendar-access-spec.md`](calendar-access-spec.md); do not attempt later creates or deletes and do not roll back confirmed mutations.
- Plan-time deletion authority remains final for that attempt. After the first mutation, apply does not re-evaluate changed title, time, all-day, or marker fields before targeting the exact planned occurrence.
- App trigger serialization does not create a cross-process lock. Concurrent app and CLI applies, or concurrent CLI applies, are allowed; they may create duplicates or delete opposing duplicate occurrences, and a later ordinary reconciliation is the recovery mechanism.

## Acceptance checks

- **RECON-AC-01:** A second ordinary reconciliation after successful apply is a no-op.
- **RECON-AC-02:** Renaming a representative source event deletes the old projection and creates the new projection.
- **RECON-AC-03:** A cancelled locally managed projection does not satisfy an expected key, so the plan creates a replacement before deleting it; a cancelled non-local marked hub event is preserved but produces no work blockers.
- **RECON-AC-04:** Two or more managed events satisfying one expected key produce one replacement create and deletion of every existing duplicate; failure of the replacement create leaves all existing duplicates untouched.
- **RECON-AC-05:** A stale local hub projection is excluded from the reconciled logical hub state so its hub and work-calendar projections can be removed in the same run.
- **RECON-AC-06:** For an identical loaded ordinary snapshot, dry-run and explanation contain exactly the same planned creates and deletes.
- **RECON-AC-07:** Explanation accounts for every ordinary input event across eligibility, exact routing/source treatment, and existing-state disposition and accounts for every planned action with the required causal IDs.
- **RECON-AC-08:** Representative explanation tests cover attendee and availability outcomes, feedback suppression, personal and exact local-marker hub routing, authoritative non-local valid-marker routing, cancelled marked preservation, already-satisfied projections, unmanaged/non-local preservation, stale and cancelled managed deletion, replace-all duplicate deletion, and missing-projection creation.
- **RECON-AC-09:** Exact duplicate visible events remain distinguishable in explanation by EventKit event ID without changing visible-set equality.
- **RECON-AC-10:** Cleanup planning selects only exact legacy-marker matches and produces deletes only; post-apply verification performs no additional deletion planning and succeeds only on an exact no-match snapshot.
- **RECON-AC-11:** An ordinary or cleanup recurring target is deleted only when its exact planned occurrence resolves; an ambiguous or missing occurrence stops mutation without deleting another occurrence or series.
- **RECON-AC-12:** A representative eventual-convergence scenario demonstrates that later recreation produces a new cleanup delete without invalidating the earlier run's local point-in-time success.
- **RECON-AC-13:** Ordinary apply attempts all creates before deletes and stops on its first mutation failure without rollback or later actions.
- **RECON-AC-14:** Deterministic tests cover ordinary planning, explanation, and cleanup without real EventKit access or a second implementation of the rules.
- **RECON-AC-15:** App ordinary and cleanup confirmation tests recompute from fresh inputs, apply only an exactly matching fresh plan, and require renewed review for changed actions even when aggregate counts are unchanged.
- **RECON-AC-16:** Automatic retry and coalesced follow-up tests compute fresh plans and never resume an earlier or partially applied mutation plan.
- **RECON-AC-17:** Concurrent or non-atomic input changes may produce a temporary duplicate, stale, or missing projection, and a later fresh reconciliation repairs the resulting visible set.

## Constraints

- Do not add persistent identity stores, hidden source IDs, or notes metadata without an explicit decision.
- Do not use EventKit IDs as reconciliation keys, selector fallbacks, ownership markers, or substitutes for visible-set equality.
- Do not derive ordinary explanation actions independently from the shared ordinary plan.
- Do not combine cleanup and ordinary reconciliation into one plan or mutation run.
- Do not treat aggregate counts, plan age alone, or a fixed expiration as a substitute for exact reviewed-plan comparison.
- Do not add a cross-process mutation lock, atomic cross-calendar snapshot claim, or EventKit-notification restart requirement without an explicit decision.
- Do not place reconciliation or cleanup orchestration in SwiftUI views, app delegates, or menu handlers.

## Compatibility and breaking changes

- Revision 5 keeps visible-key equality while making cancelled managed events unsatisfying, replaces every duplicate set rather than choosing a survivor, derives work blockers from the reconciled logical hub, and requires exact occurrence targeting for recurring deletion.
- Revision 5 also requires create-before-delete execution and explicitly accepts sequential snapshots and concurrent applies as eventually repaired rather than atomic behavior.
- Revision 4 adds app reviewed-plan freshness and automatic-attempt freshness without changing ordinary visible-set equality, cleanup selection, or CLI non-interactive apply authorization.
- Revision 3 replaces starts-with routing classifications with exact parsed-marker classifications.
- Revision 3 adds a separate deterministic delete-only cleanup plan; it does not alter ordinary visible-set equality.
- Ordinary explanation remains the only reconciliation output allowed to include EventKit IDs under [`calendar-access-spec.md`](calendar-access-spec.md); cleanup does not add an explanation mode.
