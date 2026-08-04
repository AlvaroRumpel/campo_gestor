---
phase: 05-reproductive-module-loteatf
plan: 01
subsystem: database
tags: [postgres, rls, plpgsql, pgtap, supabase, triggers]

# Dependency graph
requires:
  - phase: 02-property-paddock
    provides: animal_atf_memberships skeleton table (no policies, no FKs), animal_atf_memberships_active_idx partial unique index, is_member_of()/get_role() RLS helpers
  - phase: 04-movements
    provides: the access-path-independent BEFORE-trigger idiom (trg_animals_lot_same_property / trg_lots_paddock_same_property) mirrored here for ATF cross-property alignment
provides:
  - atf_batches table (REPR-01 header fields, D-05 hybrid bull constraint, date-order constraint)
  - dg_records table (REPR-03 result vocabulary CHECK, additive/no-unique history per D-12)
  - animal_atf_memberships activated with property_id + FKs to animals/atf_batches
  - trg_atf_membership_valid — rejects ineligible category (23514) and cross-property animal/ATF (23503)
  - trg_dg_records_same_property — rejects cross-property atf_batch/animal on dg_records (23503)
  - trg_animals_baixa_deactivates_atf — AFTER UPDATE OF deleted_at deactivates active ATF membership (D-19)
  - SELECT-only RLS surface on all three module tables (writes reserved for plan 05-03 RPCs)
  - pgTAP suite proving all of the above, authored but not yet executed
affects: [05-02, 05-03, 05-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Access-path-independent BEFORE INSERT/UPDATE trigger for cross-entity property alignment (continues the trg_animals_lot_same_property idiom from Phase 4)"
    - "AFTER UPDATE OF <col> ... WHEN (OLD IS NULL AND NEW IS NOT NULL) trigger for a soft-delete side effect that must hold on any write path, not just the owning RPC"

key-files:
  created:
    - supabase/migrations/20260804_05_reproductive_module.sql
    - supabase/tests/05_reproductive_test.sql
  modified: []

key-decisions:
  - "D-19's baixa-deactivates-membership rule implemented as an AFTER UPDATE OF deleted_at trigger on animals, not inside the register_baixa RPC as 05-RESEARCH.md sketched — holds on any write path including a raw PostgREST PATCH, and removes a statement from the RPC (A-BAIXA-01: today baixa is the only path that sets animals.deleted_at)."
  - "No pg_advisory_xact_lock added to enforce_atf_membership_valid — nothing here generates a sequence; the pre-existing partial unique index animal_atf_memberships_active_idx already covers the one real concurrency hazard."
  - "No INSERT/UPDATE/DELETE policy on animal_atf_memberships or dg_records, and no UPDATE policy on atf_batches — all mutation goes through the SECURITY DEFINER RPCs added in plan 05-03, per RESEARCH Pattern 1."

patterns-established:
  - "Reproductive-module trigger functions follow the exact Phase 4 shape: RETURNS trigger LANGUAGE plpgsql SET search_path = public, ERRCODE 23503 for FK-style cross-entity mismatches, ERRCODE 23514 for CHECK-style business-rule violations."

requirements-completed: [REPR-01, REPR-02, REPR-03]

coverage:
  - id: D1
    description: "atf_batches table with the five REPR-01 header fields and the D-05 hybrid bull constraint (bull_animal_id OR bull_name required)"
    requirement: "REPR-01"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql (schema created; live pgTAP execution deferred to plan 05-10 supabase db push + supabase test db)"
        status: unknown
    human_judgment: true
    rationale: "Migration is authored and internally verified (grep-based structural checks passed) but not executed against a live Postgres instance in this session — plan 05-10 owns the db push and test run."
  - id: D2
    description: "REPR-02 business rules (only vaca/novilha eligible, max 1 active ATF per animal) enforced at the database boundary via trg_atf_membership_valid and the pre-existing partial unique index, independent of access path"
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql assertions 3, 4, 6 (23514 touro rejection, 23503 cross-property rejection, 23505 duplicate-active rejection)"
        status: unknown
    human_judgment: true
    rationale: "pgTAP assertions written and internally verified (plan(9) count matches assertion calls) but not yet executed — deferred to plan 05-10."
  - id: D3
    description: "dg_records CHECK constraint restricting result to pregnant/not_pregnant/doubtful, with no unique constraint so DG history stays additive (D-12)"
    requirement: "REPR-03"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql assertion 7 (23514 invalid result rejection)"
        status: unknown
    human_judgment: true
    rationale: "Constraint authored and internally verified but not yet executed — deferred to plan 05-10."
  - id: D4
    description: "Soft-deleting an animal (baixa) deactivates its active ATF membership in the same transaction via trg_animals_baixa_deactivates_atf, on any access path"
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql assertions 8-9 (lives_ok baixa UPDATE + is() active=false check)"
        status: unknown
    human_judgment: true
    rationale: "Trigger authored and internally verified but not yet executed against a live database — deferred to plan 05-10."

duration: 22min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 1: Reproductive Module Database Foundation Summary

**atf_batches and dg_records tables plus activation of the Phase 2 animal_atf_memberships skeleton, with three access-path-independent triggers enforcing REPR-02's category/property/baixa invariants at the database boundary — a migration file and a matching pgTAP suite, no live execution yet.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-04T20:12:00Z (approx, worktree session start)
- **Completed:** 2026-08-04T20:34:00Z (approx)
- **Tasks:** 3
- **Files modified:** 2 (both new)

## Accomplishments
- Created `atf_batches` (REPR-01 header fields, D-05 hybrid bull CHECK, date-order CHECK) and `dg_records` (REPR-03 result CHECK, deliberately no unique constraint per D-12)
- Activated the Phase 2 `animal_atf_memberships` skeleton with `property_id`, both foreign keys, and two new indexes, preserving the existing `animal_atf_memberships_active_idx`
- Enabled SELECT-only RLS across all three module tables (FORCE ROW LEVEL SECURITY on the two new tables; membership table already had it), with writes reserved for plan 05-03's SECURITY DEFINER RPCs
- Added three access-path-independent triggers: `trg_atf_membership_valid` (category eligibility + cross-property alignment, ERRCODE 23514/23503), `trg_dg_records_same_property` (cross-property alignment, 23503), `trg_animals_baixa_deactivates_atf` (D-19 side effect on any `deleted_at` transition)
- Wrote a 9-assertion pgTAP suite covering both happy paths and all four rejection cases, ready to run once `supabase db push` (plan 05-10) executes

## Task Commits

Each task was committed atomically:

1. **Task 1: Create atf_batches, dg_records, and activate the animal_atf_memberships skeleton** - `ffbb083` (feat)
2. **Task 2: Access-path-independent triggers for category, property alignment, and baixa** - `71296c7` (feat)
3. **Task 3: pgTAP test file proving the REPR-02 invariants** - `c098906` (test)

_Note: Tasks 1 and 2 both append to the same migration file (`20260804_05_reproductive_module.sql`), as specified by the plan._

## Files Created/Modified
- `supabase/migrations/20260804_05_reproductive_module.sql` - atf_batches, dg_records, animal_atf_memberships activation, RLS policies, and the three trigger functions/triggers
- `supabase/tests/05_reproductive_test.sql` - pgTAP suite: 2 schema-existence assertions, 4 rejection assertions (23514 x2, 23503, 23505), 2 happy-path lives_ok, 1 post-baixa state check

## Decisions Made
- D-19's membership deactivation lives in a trigger on `animals.deleted_at`, not inside `register_baixa` — see `key-decisions` in frontmatter for full rationale (A-BAIXA-01 assumption carried forward).
- No `pg_advisory_xact_lock` in `enforce_atf_membership_valid` — the existing partial unique index is the sole concurrency guard needed (RESEARCH Pitfall 3).
- No write RLS policies on `animal_atf_memberships` / `dg_records`, no UPDATE policy on `atf_batches` — intentional, RPC-only mutation surface (plan 05-03).

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria and automated `<verify>` grep checks in the plan passed before each commit.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The migration and pgTAP file are authored on disk only; live execution (`supabase db push` + `supabase test db`) is explicitly deferred to plan 05-10 per the Supabase MCP note (no authenticated session in this worktree).

## Next Phase Readiness

- The database foundation (`atf_batches`, `dg_records`, activated `animal_atf_memberships`, all three invariant triggers) is on disk and internally self-consistent, ready for plan 05-03's SECURITY DEFINER RPCs to build on.
- Blocker carried forward: none of this SQL has run against a live Postgres instance yet. Plan 05-10 must execute `supabase db push` + `supabase test db` before any UAT that touches these tables can be trusted.
- REPR-01/02/03 requirement IDs are marked complete at the schema-design level in this plan's frontmatter; full closure (live-verified) still depends on 05-10.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*
