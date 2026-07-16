---
phase: 04-movements
plan: 06
subsystem: database
tags: [postgres, plpgsql, trigger, rls, pgtap, supabase, multi-tenancy]

# Dependency graph
requires:
  - phase: 04-movements
    provides: move_animal_to_lot RPC (04-04), veterinarian_can_update_active_animal RLS policy (Phase 3)
provides:
  - "trg_animals_lot_same_property: BEFORE INSERT OR UPDATE trigger enforcing animals.lot_id ∈ property_id on every write path"
  - "WR-01 fix: move_animal_to_lot re-checks deleted_at on its final UPDATE (TOCTOU close)"
  - "pgTAP suite proving SC-4 at the trigger level (cross-property reject, same-property allow, NULL-lot_id allow)"
  - "lots.paddock_id raw-write bypass (MOV-02) documented as an accepted, deferred MVP risk"
affects: [05-reproductive-module, 06-sanitary-module]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Access-path-independent invariant enforcement via BEFORE INSERT OR UPDATE trigger (mirrors existing prevent_snapshot_mutation idiom) — used when RLS WITH CHECK cannot express a cross-column/cross-table invariant"
    - "pgTAP fixtures with fixed literal UUIDs (not gen_random_uuid()) when a test needs the same id referenced across multiple separate statements (PREPARE/EXECUTE, not a single CTE)"

key-files:
  created:
    - supabase/migrations/20260716_04_animal_lot_property_trigger.sql
    - supabase/tests/04_movements_test.sql
  modified:
    - supabase/migrations/20260715_04_gap_move_animal_to_lot.sql
    - .planning/phases/04-movements/04-CONTEXT.md

key-decisions:
  - "Trigger (not a tightened RLS WITH CHECK) chosen to close CR-01 — protects INSERT too and cannot be forgotten by a future policy edit, matching the project's existing snapshot-immutability idiom"
  - "Guard also fires on property_id change (not just lot_id change) to keep the invariant true if a raw PATCH reassigns property_id while leaving lot_id untouched (WR-02/T-4-09 lot-alignment consequence); standalone property_id-immutability remains deferred"
  - "MOV-02's identical lots.paddock_id bypass is explicitly NOT fixed this cycle — plan-locked scope (animals only); documented as accepted MVP risk in 04-CONTEXT.md Deferred Ideas with the same trigger-based remedy path"

requirements-completed: [MOV-01]

coverage:
  - id: D1
    description: "BEFORE INSERT OR UPDATE trigger trg_animals_lot_same_property rejects cross-property animals.lot_id assignment (ERRCODE 23503) on every write path, independent of RLS"
    requirement: "MOV-01"
    verification:
      - kind: other
        ref: "grep-based structural verify (this environment): CREATE TRIGGER present, ERRCODE 23503 present, NEW.lot_id IS NULL skip documented"
        status: pass
      - kind: integration
        ref: "supabase/tests/04_movements_test.sql (pgTAP, 3 assertions) — NOT YET RUN, requires supabase db push + supabase test db"
        status: unknown
    human_judgment: true
    rationale: "Live trigger behavior (the actual SC-4 proof) can only be verified by running the pgTAP suite against a pushed database. This environment's Supabase CLI is unlinked and Docker is unreachable — a human must push and run `supabase test db`, then confirm 3/3 pass, before this deliverable can be marked verified."
  - id: D2
    description: "move_animal_to_lot RPC's final UPDATE re-checks deleted_at and raises 23503 on NOT FOUND (WR-01 TOCTOU close)"
    requirement: "MOV-01"
    verification:
      - kind: other
        ref: "grep-based structural verify: 'deleted_at is null' count >= 2, 'if not found' present in 20260715_04_gap_move_animal_to_lot.sql"
        status: pass
    human_judgment: false
  - id: D3
    description: "lots.paddock_id raw-write bypass (MOV-02) is documented as an accepted, deferred MVP risk in 04-CONTEXT.md"
    verification:
      - kind: other
        ref: "grep 'paddock_id' .planning/phases/04-movements/04-CONTEXT.md — bullet present"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-07-16
status: complete
---

# Phase 4 Plan 06: Movements — SC-4 Trigger Gap Closure Summary

**BEFORE INSERT OR UPDATE trigger `trg_animals_lot_same_property` closes the CR-01 raw-PATCH bypass of `move_animal_to_lot`, access-path-independently, plus WR-01's TOCTOU fix; DB push remains BLOCKED pending manual credentials.**

## Performance

- **Duration:** ~5 min (task execution; excludes read time)
- **Started:** 2026-07-16T12:42:28Z
- **Completed:** 2026-07-16T12:47:05Z
- **Tasks:** 3 (2 fully completed, 1 blocked per plan-sanctioned escape hatch)
- **Files modified:** 4

## Accomplishments

- Closed 04-REVIEW.md CR-01 (reopened SC-4 finding): the RLS `WITH CHECK` on `animals` never inspected `lot_id`, so a multi-property veterinarian could bypass `move_animal_to_lot` with a raw PostgREST `PATCH`. A new `BEFORE INSERT OR UPDATE` trigger, `trg_animals_lot_same_property`, now enforces "lot_id must belong to the animal's own property_id" at the table level — RPC, raw PATCH, and any future write path are all covered.
- Closed WR-01 (TOCTOU): `move_animal_to_lot`'s final `UPDATE` now re-checks `deleted_at IS NULL` and raises `23503` if the animal was archived (by a concurrent `registerBaixa`) between the validation `SELECT` and the mutation.
- Authored `supabase/tests/04_movements_test.sql` (pgTAP, 3 assertions) proving the trigger's behavior at the RLS-bypassed superuser level — the exact scenario CR-01 identified as unprotected.
- Documented the parallel `lots.paddock_id` bypass (MOV-02) as an explicitly accepted, scope-locked MVP risk in `04-CONTEXT.md` Deferred Ideas, per the plan's LOCKED scope directive (animals only this cycle).
- Task 3 (`supabase db push` for all 3 unpushed Phase-4 migrations + `supabase test db`) attempted once and confirmed BLOCKED — recorded below with recovery steps. No live-DB success is claimed.

## Task Commits

1. **Task 1: Add cross-property lot trigger (SC-4 fix) + WR-01 deleted_at re-check** - `33c1af3` (fix)
2. **Task 2: Author pgTAP SC-4 test (run-on-push) + record deferred lots bypass in CONTEXT.md** - `76d5831` (test)
3. **Task 3: [BLOCKING] supabase db push + supabase test db** - BLOCKED, no code changes, no commit (see below)

**Plan metadata:** (this commit, filed after this SUMMARY)

## Files Created/Modified

- `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` - New: `enforce_animal_lot_same_property()` function + `trg_animals_lot_same_property` trigger (`BEFORE INSERT OR UPDATE ON animals`); skips when `NEW.lot_id IS NULL`; raises `23503` on cross-property/archived-lot destination; also fires on `property_id` change.
- `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` - Amended (not yet applied to any DB): final `UPDATE` now has `AND deleted_at IS NULL` + `IF NOT FOUND THEN RAISE EXCEPTION ... USING ERRCODE = '23503'`.
- `supabase/tests/04_movements_test.sql` - New pgTAP suite: fixtures (2 properties, 2 paddocks, 3 lots, 1 animal with fixed literal UUIDs), 3 assertions (cross-property `throws_ok` 23503, same-property `lives_ok`, NULL-lot_id-insert `lives_ok`).
- `.planning/phases/04-movements/04-CONTEXT.md` - Appended a Deferred Ideas bullet recording the `lots.paddock_id` bypass (MOV-02) as an accepted MVP risk with the trigger-based remedy noted for later.

## Decisions Made

- **Trigger over RLS-tightening for CR-01:** a `BEFORE INSERT OR UPDATE` trigger was chosen over adding an `EXISTS` predicate to the existing `WITH CHECK` clause because it also protects `INSERT` (not just `UPDATE`) and cannot be silently weakened by a future policy edit — matches the project's existing `prevent_snapshot_mutation` idiom exactly.
- **Guard fires on `property_id` change too, not just `lot_id` change:** keeps the "lot belongs to property" invariant true even if a raw PATCH reassigns `property_id` while leaving `lot_id` untouched (the WR-02/T-4-09 lot-alignment consequence). Full `property_id` column-immutability (blocking any `property_id` change outright) remains out of scope and deferred, per the review's own disposition (T-4-09: accept, residual bounded by RLS membership check on the target property).
- **MOV-02's identical bypass deliberately not fixed:** the plan's LOCKED scope is animals-only this cycle; the parallel `lots.paddock_id` raw-write bypass is recorded as an accepted MVP risk in `04-CONTEXT.md`, with the exact remedy (same trigger pattern applied to `lots`) noted for a future cycle.

## Deviations from Plan

None - plan executed exactly as written, including its explicit escape hatch for Task 3.

## Issues Encountered

None beyond the plan-anticipated Task 3 CLI-unlinked state (see below) — not a deviation, this is the plan's documented expected outcome for this environment.

## `[BLOCKED — manual push pending]`

Task 3 (`supabase db push` for all three unpushed Phase-4 migrations, then `supabase test db`) was attempted once with `supabase db push --dry-run`:

```
Cannot find project ref. Have you run supabase link?
```

Per the plan's escape hatch, this is NOT a plan failure — Tasks 1 and 2 (the fully-completable deliverables) are done and committed. No live-DB pass is claimed for the trigger or the pgTAP suite in this environment.

**Recovery steps for a human with dev Supabase credentials, before UAT:**

1. `supabase link --project-ref <dev-project-ref>`
2. `supabase db push` — applies, in filename order, all three unpushed Phase-4 migrations:
   - `supabase/migrations/20260519_04_movements.sql` (move_lot_to_paddock RPC)
   - `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` (move_animal_to_lot RPC, now WR-01-amended)
   - `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` (new — the SC-4 trigger, this plan)
3. `supabase test db` — executes `supabase/tests/04_movements_test.sql`; confirm 3/3 pass (cross-property `23503` rejection is the SC-4 proof).

**Manual UAT (in addition to the pgTAP run):** log in as a veterinarian who is a member of two properties, and attempt a raw `PATCH /rest/v1/animals?id=eq.<animalInPropertyA> {"lot_id":"<lotInPropertyB>"}` using the app's publishable key. Expect an HTTP error carrying SQLSTATE `23503`, confirming the bypass identified in 04-REVIEW.md CR-01 is closed at the database boundary regardless of access path.

## User Setup Required

None - no external service configuration required (the blocked push is a CLI-auth/credentials gap for this session, not a new external service).

## Next Phase Readiness

- ROADMAP Phase 4 Success Criterion 4 is closed at the code/migration level, access-path-independently. It is NOT yet closed at the live database — that requires the manual push + pgTAP run above.
- Phase 4 overall status: all 6 plans (04-01 through 04-06) are now code-complete. The single remaining blocker for Phase 4 UAT is the manual `supabase db push` covering all three unpushed migrations (unchanged in kind from prior 04-03/04-04 blockers, now consolidated to one recovery procedure covering three files).
- The MOV-02 `lots.paddock_id` bypass is a known, accepted, documented risk — not a blocker for this phase's UAT, but should be picked up in a future gap-closure cycle if/when the project's risk tolerance changes.

---
*Phase: 04-movements*
*Completed: 2026-07-16*

## Self-Check: PASSED

All 5 claimed files found on disk; both task commits (`33c1af3`, `76d5831`) found in git log.
