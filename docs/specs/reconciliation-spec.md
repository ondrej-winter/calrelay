# Spec: Calendar Relay Reconciliation

## Specification record

- **Status:** Accepted.
- **Revision:** 6 — accepted on September 16, 2026 after the reconciliation stress-test interview; delete-first ordered plans, exact reviewed-action identity, local ordinary success, and authorization-sensitive execution order were defined.
- **Canonical artifact:** `docs/specs/reconciliation-spec.md`.
- **Scope:** Pure visible-set ordinary reconciliation, deterministic cleanup planning, application behavior, and exact ordinary reconciliation explanation.

## Required outcomes

### RECON-01 — Visible-set ordinary reconciliation model

- Use visible-set reconciliation rather than provider IDs, hidden metadata, notes metadata, or a local identity mapping store.
- Treat generated events as disposable projections.
- A renamed or changed source event is not detected as a rename: delete the old projection when it is no longer expected and create the newly expected projection.
- For ordinary MVP equality, compare `calendar + title + start + end + all-day flag`.
- EventKit event and calendar IDs used by explanation are diagnostic correlation data only. They must not change visible-set equality, routing, ownership, marker parsing, expected projections, or create/delete selection. Exact occurrence identity may identify an already-selected delete, break an execution-order tie between already-selected exact duplicates, and participate in exact reviewed-action identity.
- Every ordinary or cleanup delete action identifies the exact fetched event occurrence selected by the plan. A recurring-event deletion may target only that exact occurrence; failure to resolve it exactly stops the run without substituting another occurrence or the whole series.
- A cancelled locally managed event never satisfies an expected projection even when its visible key matches. When the projection remains expected, plan a replacement create and treat the cancelled event as stale.
- A cancelled non-local marked hub event remains preserved but does not enter the expected work-calendar blocker set.
- When exactly one non-cancelled locally managed event satisfies an expected key, retain it. When two or more locally managed events satisfy the same expected key, retain none: plan one canonical replacement create and delete every existing managed duplicate.
- When two or more causal source occurrences produce the same destination visible key, expected projections retain set semantics: plan one expected projection and retain causal links to every contributing source occurrence for explanation.
- Build work-calendar expectations from the reconciled logical hub state: eligible original hub events, preserved non-local non-cancelled marked hub blockers, and currently expected local work projections. Do not relay a locally owned hub projection that the same computation has classified as stale.
- Copy EventKit start/end values and the all-day flag as defined by [`projection-and-safety-spec.md`](projection-and-safety-spec.md); do not introduce separate timezone normalization, timestamp rounding, or temporal tolerance.

### RECON-02 — Planner idempotency, provider convergence, and testability

- Ordinary planner idempotency is defined over visible snapshots: when a loaded snapshot reflects every confirmed action from a successful ordinary apply and no other relevant change occurred, the next ordinary plan is empty.
- Ordinary apply success means every executable action in the ordered plan received mutation confirmation. Ordinary apply does not perform a post-mutation verification read and does not guarantee that an immediate provider read reflects those mutations.
- A ready ordinary run with a successfully loaded snapshot and an empty plan is successful and may update app freshness and last-success state without mutation.
- Every later run trusts its own fresh loaded snapshot. Provider read-after-write lag may repeat recently confirmed creates or target already-absent deletes; CalRelay does not add a cooldown, in-memory mutation overlay, recent-plan suppression, or automatic post-apply verification. Later fresh reconciliation remains the recovery mechanism.
- A second legacy-cleanup dry-run over an unchanged successful cleanup snapshot produces no deletions.
- Keep ordinary reconciliation and cleanup planning logic pure and unit-testable.
- Use deterministic tests with fakes for core reconciliation and cleanup rules.

### RECON-03 — Shared ordinary plan and exact explanation

- One deterministic ordinary reconciliation computation consumes one validated non-migration-pending settings value and one loaded calendar/event snapshot over the effective ordinary window defined in [`projection-and-safety-spec.md`](projection-and-safety-spec.md).
- The separately loaded configured-calendar reads form the authoritative snapshot for that attempt. Their hub-first and work-calendar declaration order is defined by [`calendar-access-spec.md`](calendar-access-spec.md). CalRelay does not claim an atomic cross-calendar snapshot, restart planning because EventKit announces a concurrent change, or require two matching complete reads; later reconciliation repairs inconsistencies caused by concurrent external changes.
- The ordinary plan is one ordered executable-action sequence. Its deterministic order is defined by `RECON-06`; plan identity is not an unordered create/delete set.
- Ordinary dry-run returns the plan from that computation. Explanation annotates that same plan and computation; it must not contain a second or approximate implementation of ordinary reconciliation rules.
- For the same loaded snapshot, explanation's planned-action section exactly equals the ordinary dry-run's ordered executable-action sequence.
- Explanation contains two semantic sections:
  1. every input event read from every configured calendar in the effective ordinary window; and
  2. every planned create and delete with causal links to the applicable input events and reconciliation rules.
- Each input event is identified by its EventKit event ID and calendar ID for within-output correlation and receives every applicable classification in three independent dimensions:
  - **Eligibility:** reliable cancellation; current-user attendee accepted or non-accepted; no-current-user-attendee availability included, explicit free/tentative, or unsupported unknown; or marked-hub eligibility bypass.
  - **Routing/source treatment:** work-to-hub source, hub personal source, exact local-marker hub source, non-local valid-marker hub source, cancelled marked hub preservation, invalid/unmarked hub source, or feedback-suppressed marked work projection.
  - **Existing-state disposition:** whether it satisfies an expected projection or has no matching expectation, and whether it is retained, preserved as unmanaged/non-local, selected as a stale or cancelled managed deletion, or selected for replace-all managed duplicate deletion.
- The explanation reason model is a stable semantic contract. Planned-action rows follow execution order. Input-event row order, presentation wording, headings, and row formatting are not stable contracts.
- Planned-create explanations identify a missing expected projection, cite the causal source EventKit event ID or IDs, and identify the destination EventKit calendar ID.
- Planned-delete explanations identify the exact existing occurrence selected for deletion and distinguish stale, cancelled, replace-all duplicate, and legacy-cleanup reasons.
- Explanation follows the routing rules in [`routing-spec.md`](routing-spec.md) and the eligibility, exact marker, and ownership rules in [`projection-and-safety-spec.md`](projection-and-safety-spec.md) rather than redefining them.

### RECON-04 — Deterministic legacy-cleanup plan

- One deterministic cleanup computation consumes one validated migration-pending settings value and one loaded snapshot of every configured calendar over the cleanup range defined in [`configuration-spec.md`](configuration-spec.md).
- The cleanup plan is one ordered executable sequence containing deletes only. It contains no creates, ordinary stale deletes, routing output, or projection generation.
- An event is selected exactly when its title has valid marked-title shape and its parsed case-sensitive marker equals one configured legacy marker.
- Cleanup dry-run returns that exact plan. Cleanup apply executes that plan after complete cleanup preflight; it must not independently rescan or approximate the deletion criteria after mutation begins.
- Cleanup preserves the exact occurrence-level delete identities produced by the shared deletion rule in `RECON-01`.
- Cleanup delete order is hub first, then work calendars in declaration order. Within each calendar, it uses the action order and exact-occurrence tie-breaker defined by `RECON-06`.
- The required post-apply verification is a fresh read and exact no-match postcondition check, not a second cleanup plan. It does not authorize additional unplanned deletions in the same run.
- Duplicate legacy-marker entries and collisions with current markers cannot reach cleanup planning because structural validation rejects them.
- Cleanup-result semantics are local and point-in-time. Plan completion does not prove global retirement and does not prevent another computer from recreating matching events.

### RECON-05 — Reviewed app plans and fresh automatic plans

- A plan presented by the app for manual ordinary apply or legacy-cleanup apply is a reviewed plan, not authority to mutate indefinitely from that old snapshot.
- Immediately before a reviewed app apply begins mutation, the app loads fresh validated configuration and a fresh applicable calendar snapshot, repeats the complete applicable preflight, and computes a fresh plan with the same deterministic ordinary or cleanup computation.
- The reviewed and fresh plans match only when they contain exactly the same ordered executable-action sequence. A create action's identity includes the visible projection fields from `RECON-01` and the resolved physical destination calendar. A delete action's identity includes the resolved physical calendar and exact existing occurrence so that one duplicate occurrence cannot substitute for another.
- Changed causal-source links, eligibility classifications, or delete-reason classifications do not invalidate confirmation when the ordered executable actions remain identical.
- EventKit occurrence-identity churn, resolved physical-calendar identity change, or any action-order change makes the fresh plan different even when visible fields or aggregate counts are unchanged.
- If the fresh plan differs, the app performs no mutation and presents the fresh plan for a new review and confirmation. It does not apply a same-count or same-visible-summary but executably different plan under the earlier confirmation.
- If the plans match, apply executes the fresh loaded plan. Once its first mutation begins, it does not independently rescan, re-plan, or append actions; mutation-time failure behavior remains defined by [`calendar-access-spec.md`](calendar-access-spec.md).
- Every automatic ordinary attempt, including retry and a coalesced follow-up, independently loads fresh configuration and calendar state and computes one fresh plan. It never resumes or reuses a plan from an earlier attempt or partially applied run.

### RECON-06 — Ordered mutation, plan authority, and concurrency

- Ordinary apply executes four global phases in this exact order:
  1. hub-calendar deletes;
  2. work-calendar deletes, visiting work calendars in configuration declaration order;
  3. hub-calendar creates; and
  4. work-calendar creates, visiting work calendars in configuration declaration order.
- Within one calendar and action kind, order actions by ascending start, ascending end, timed before all-day, and exact title lexicographically by Unicode scalar sequence without locale collation, case folding, or additional normalization. When already-selected delete actions remain tied, use exact occurrence identity, including EventKit event ID when needed, only as the final total-order tie-breaker.
- If any delete or create fails, stop immediately as defined by [`calendar-access-spec.md`](calendar-access-spec.md); do not attempt later actions and do not roll back confirmed mutations. A hub-phase failure therefore prevents every later work-calendar action, including otherwise independent actions.
- Delete-first execution intentionally prefers removing stale or duplicate over-blocking over uninterrupted blocker coverage. A later create failure may leave an expected blocker missing until a later successful reconciliation.
- Replace-all duplicate planning remains unchanged: delete every managed duplicate before attempting the one canonical replacement create. Do not retain a survivor by provider identity.
- The whole ordered plan remains authoritative after its first mutation. Apply does not re-evaluate changed deletion fields, changed or disappeared causal sources, reliable cancellation, or other visible state before later actions, and it does not rescan, re-plan, or append actions.
- Failure to resolve an exact planned delete occurrence, including because it is absent after a concurrent deletion or identifier churn, stops the run. Absence is not treated as idempotent deletion success.
- App trigger serialization does not create a cross-process lock. Concurrent app and CLI applies, or concurrent CLI applies, are allowed; they may create duplicates or delete opposing duplicate occurrences, and a later ordinary reconciliation is the recovery mechanism.

## Acceptance checks

- **RECON-AC-01:** Planner-idempotency tests produce an empty plan when the loaded snapshot reflects every confirmed ordinary mutation; provider-lag tests allow a later fresh snapshot to repeat actions without adding a cooldown, overlay, or false verification claim.
- **RECON-AC-02:** Renaming a representative source event deletes the old projection and creates the new projection.
- **RECON-AC-03:** A cancelled locally managed projection does not satisfy an expected key, so the ordered plan deletes it before attempting its replacement create; a cancelled non-local marked hub event is preserved but produces no work blockers.
- **RECON-AC-04:** Two or more managed events satisfying one expected key produce deletion of every existing duplicate before one replacement create; replacement-create failure may leave no blocker until later reconciliation.
- **RECON-AC-05:** A stale local hub projection is excluded from the reconciled logical hub state so its hub and work-calendar projections can be removed in the same run.
- **RECON-AC-06:** For an identical loaded ordinary snapshot, dry-run and explanation contain exactly the same ordered executable-action sequence.
- **RECON-AC-07:** Explanation accounts for every ordinary input event across eligibility, exact routing/source treatment, and existing-state disposition and accounts for every planned action with the required causal IDs.
- **RECON-AC-08:** Representative explanation tests cover attendee and availability outcomes, feedback suppression, personal and exact local-marker hub routing, authoritative non-local valid-marker routing, cancelled marked preservation, already-satisfied projections, unmanaged/non-local preservation, stale and cancelled managed deletion, replace-all duplicate deletion, and missing-projection creation.
- **RECON-AC-09:** Exact duplicate visible events remain distinguishable in explanation by EventKit event ID; exact identity provides only the final order among already-selected tied deletes and does not change visible-set equality or the selected action set.
- **RECON-AC-10:** Cleanup planning selects only exact legacy-marker matches, produces ordered hub-first then declaration-ordered work-calendar deletes, and performs no additional deletion planning during post-apply verification; success requires an exact no-match snapshot.
- **RECON-AC-11:** An ordinary or cleanup recurring target is deleted only when its exact planned occurrence resolves; an ambiguous or missing occurrence stops mutation without deleting another occurrence or series.
- **RECON-AC-12:** A representative eventual-convergence scenario demonstrates that later recreation produces a new cleanup delete without invalidating the earlier run's local point-in-time success.
- **RECON-AC-13:** Ordinary apply executes hub deletes, declaration-ordered work deletes, hub creates, and declaration-ordered work creates; within-calendar action order follows the exact temporal, all-day, Unicode-scalar title, and occurrence-identity rules; the first failure stops every later action without rollback.
- **RECON-AC-14:** Deterministic tests cover ordinary planning, explanation, and cleanup without real EventKit access or a second implementation of the rules.
- **RECON-AC-15:** App ordinary and cleanup confirmation tests recompute from fresh inputs, compare exact ordered executable actions including resolved calendar and delete-occurrence identity, tolerate rationale-only changes, and require renewed review for executable or order changes even when aggregate summaries are unchanged.
- **RECON-AC-16:** Automatic retry and coalesced follow-up tests compute fresh plans and never resume an earlier or partially applied mutation plan.
- **RECON-AC-17:** Concurrent or non-atomic input changes may produce a temporary duplicate, stale, or missing projection, and a later fresh reconciliation repairs the resulting visible set.
- **RECON-AC-18:** Multiple causal source occurrences producing one destination visible key create one expectation whose explanation retains every causal source link.
- **RECON-AC-19:** A ready empty ordinary plan and an ordinary apply whose every ordered action is confirmed are successful without a post-apply verification read; cleanup retains its stronger no-match verification requirement.

## Constraints

- Do not add persistent identity stores, hidden source IDs, or notes metadata without an explicit decision.
- Do not use EventKit IDs as reconciliation keys, selector fallbacks, ownership markers, survivor selectors, or substitutes for visible-set equality. Their narrow exact-target, exact reviewed-action identity, and already-selected duplicate-ordering roles do not broaden deletion ownership or action selection.
- Do not derive ordinary explanation actions independently from the shared ordinary plan.
- Do not combine cleanup and ordinary reconciliation into one plan or mutation run.
- Do not treat aggregate counts, plan age alone, or a fixed expiration as a substitute for exact reviewed-plan comparison.
- Do not add a cross-process mutation lock, atomic cross-calendar snapshot claim, or EventKit-notification restart requirement without an explicit decision.
- Do not place reconciliation or cleanup orchestration in SwiftUI views, app delegates, or menu handlers.

## Compatibility and breaking changes

- Revision 6 reverses ordinary mutation from create-first to delete-first and makes hub/work phase order, work-calendar declaration order, within-calendar action order, and exact action identity stable product contracts. Partial failure now deliberately risks a temporary missing blocker rather than preserving stale over-blocking.
- Revision 6 makes ordinary and cleanup plans ordered executable sequences, narrows the presentation-order freedom for detailed action rows, and distinguishes local ordinary mutation completion from cleanup's verified no-match success.
- Revision 6 replaces immediate live no-op guarantees with planner idempotency after confirmed mutations become visible, while retaining fresh-snapshot trust and eventual repair under provider lag or concurrent applies.
- Revision 5 keeps visible-key equality while making cancelled managed events unsatisfying, replaces every duplicate set rather than choosing a survivor, derives work blockers from the reconciled logical hub, and requires exact occurrence targeting for recurring deletion.
- Revision 5 also requires create-before-delete execution and explicitly accepts sequential snapshots and concurrent applies as eventually repaired rather than atomic behavior.
- Revision 4 adds app reviewed-plan freshness and automatic-attempt freshness without changing ordinary visible-set equality, cleanup selection, or CLI non-interactive apply authorization.
- Revision 3 replaces starts-with routing classifications with exact parsed-marker classifications.
- Revision 3 adds a separate deterministic delete-only cleanup plan; it does not alter ordinary visible-set equality.
- Ordinary explanation remains the only reconciliation output allowed to include EventKit IDs under [`calendar-access-spec.md`](calendar-access-spec.md); cleanup does not add an explanation mode.
