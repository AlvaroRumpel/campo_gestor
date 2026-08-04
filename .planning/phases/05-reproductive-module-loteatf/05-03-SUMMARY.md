---
phase: 05-reproductive-module-loteatf
plan: 03
subsystem: database
tags: [postgres, plpgsql, security-definer, rpc, pgtap, supabase]

# Dependency graph
requires:
  - phase: 05-01
    provides: atf_batches/dg_records tables, activated animal_atf_memberships, and the three
      access-path-independent triggers (trg_atf_membership_valid, trg_dg_records_same_property,
      trg_animals_baixa_deactivates_atf) these RPCs write against and rely on
provides:
  - add_animals_to_atf(uuid, jsonb) — bulk membership INSERT, category/property validation left to
    trg_atf_membership_valid
  - remove_animal_from_atf(uuid, uuid) — hard DELETE, blocked with 23514 once a DG exists (D-08)
  - close_atf(uuid) — deactivates the batch and every active membership in one transaction (D-16)
  - save_dg_records(uuid, jsonb) — additive batch INSERT into dg_records, membership-existence
    guard without an active filter so D-08/D-16/D-19 states behave correctly (REPR-03)
  - register_baixa(uuid, text, date, text) — replaces the direct UPDATE 05-07 will wire up
  - pgTAP suite extended from plan(9) to plan(26) with RPC-level assertions and JWT impersonation
    fixture (auth.users + property_members + set_config) needed to exercise SECURITY DEFINER code
affects: [05-02, 05-07, 05-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SECURITY DEFINER RPC as the sole write path per table (RLS grants SELECT only), mirroring
      move_animal_to_lot's shape: server-side property_id lookup, is_member_of + get_role guards,
      RAISE EXCEPTION ... USING ERRCODE, REVOKE ALL / GRANT EXECUTE TO authenticated pair"
    - "Existence-without-active-filter as a three-way state distinguisher: whether a membership row
      exists at all (not whether it's active) tells D-08 removal (row gone) apart from D-16 closure
      or D-19 baixa (row present, inactive) — one boolean check replaces three separate code paths"
    - "pgTAP JWT impersonation via INSERT INTO auth.users + property_members + set_config('request.jwt.claim.sub', ..., true) to exercise SECURITY DEFINER RPCs from a superuser test session that would otherwise fail every call with 42501"

key-files:
  created:
    - supabase/migrations/20260805_05_atf_rpcs.sql
  modified:
    - supabase/tests/05_reproductive_test.sql

key-decisions:
  - "p_animal_ids and p_records are jsonb, not uuid[]/jsonb[] — reuses the parameter type create_lot_with_animals already proves serializes correctly from the Dart client, removing 05-RESEARCH.md's unverified uuid[] serialization assumption (A1, A-RPC-PARAM)."
  - "remove_animal_from_atf hard-DELETEs the membership row instead of soft-deactivating it — this is the single distinction save_dg_records relies on to tell a D-08 removal (row gone, DG refused) apart from a D-16 closure or D-19 baixa (row present, DG correction accepted)."
  - "save_dg_records's atf_batches lookup and membership existence guard both omit the active filter that add_animals_to_atf/remove_animal_from_atf/close_atf apply — deliberate, required by D-16's 'correção de digitação segue possível' guarantee after encerramento."
  - "The pgTAP suite impersonates a JWT (INSERT INTO auth.users + property_members + set_config('request.jwt.claim.sub', ...)) to exercise the five RPCs at all under supabase test db's superuser session; the 42501 role-guard rejections themselves are not asserted (A-PGTAP-ROLE) and are covered by UAT instead."

patterns-established:
  - "Reproductive-module RPCs follow move_animal_to_lot's exact shape: LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, server-side property_id derivation (never a parameter), is_member_of + get_role guards raising 42501, REVOKE ALL / GRANT EXECUTE TO authenticated closing pair."

requirements-completed: [REPR-02, REPR-03]

coverage:
  - id: D1
    description: "Five SECURITY DEFINER RPCs (add_animals_to_atf, remove_animal_from_atf, save_dg_records, close_atf, register_baixa) form the entire write surface of the reproductive module; each derives property_id from a server-side row lookup and rejects a non-veterinarian caller with SQLSTATE 42501"
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql (has_function assertions + structural grep checks in 05-03-PLAN.md <verify> blocks, all passed pre-commit); live pgTAP execution deferred to plan 05-10 (supabase db push + supabase test db)"
        status: unknown
    human_judgment: true
    rationale: "Migration and pgTAP additions are authored and internally verified (grep-based structural checks + manual trace of the impersonation fixture) but not executed against a live Postgres instance in this session — plan 05-10 owns the db push and test run."
  - id: D2
    description: "remove_animal_from_atf rejects removal once a DG exists (D-08, SQLSTATE 23514) via a hard DELETE, distinguishing this state from D-16 closure and D-19 baixa which leave the membership row present"
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql throws_ok('EXECUTE remove_animal_with_dg', '23514', ...) and the post-removal is(count) = 0 assertion"
        status: unknown
    human_judgment: true
    rationale: "Assertion authored and traced by hand against the RPC's control flow but not executed — deferred to plan 05-10."
  - id: D3
    description: "save_dg_records is additive-only (INSERT, never UPDATE/DELETE dg_records), validates the three-value result vocabulary (SQLSTATE 22023), and accepts a correction after close_atf on the same ATF (D-16)"
    requirement: "REPR-03"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql throws_ok('EXECUTE dg_invalid_result', '22023', ...) and lives_ok('EXECUTE dg_after_close', ...) run immediately after close_atf_a2"
        status: unknown
    human_judgment: true
    rationale: "Assertion authored and traced by hand but not executed against a live database — deferred to plan 05-10."
  - id: D4
    description: "close_atf deactivates the atf_batches row and every active membership of that batch in one transaction, freeing each animal's slot in the partial unique index for a new cycle"
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "supabase/tests/05_reproductive_test.sql is(atf_batches.active, false) + is(count of active memberships, 0) after close_atf_a2, plus lives_ok('EXECUTE readd_removed_animal', ...) proving a freed slot accepts a new membership"
        status: unknown
    human_judgment: true
    rationale: "Assertion authored and traced by hand but not executed — deferred to plan 05-10."

duration: 40min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 3: Reproductive Module RPC Write Surface Summary

**Five SECURITY DEFINER functions (add_animals_to_atf, remove_animal_from_atf, save_dg_records, close_atf, register_baixa) as the entire write surface of the reproductive module, plus a pgTAP suite extended from 9 to 26 assertions using JWT impersonation to exercise them under `supabase test db`'s superuser session.**

## Performance

- **Duration:** ~40 min
- **Tasks:** 3
- **Files modified:** 2 (1 new migration, 1 modified test file)

## Accomplishments
- `add_animals_to_atf`, `remove_animal_from_atf`, `close_atf` — the ATF composition RPCs. All three derive `property_id` from a row lookup, re-check `is_member_of`/veterinarian role, and leave category/property validation to plan 05-01's `trg_atf_membership_valid` rather than duplicating it
- `remove_animal_from_atf` hard-DELETEs the membership row (not a soft deactivation) and is blocked with SQLSTATE 23514 once a DG record exists for that pair (D-08)
- `close_atf` deactivates the batch and every active membership of it in one transaction, freeing each animal's slot in the partial unique index while preserving history (D-16)
- `save_dg_records` — additive batch INSERT into `dg_records`, validates the three-value result vocabulary (22023), and guards on membership *existence* without an `active` filter, which is what lets a D-16 closure or D-19 baixa still accept a DG correction while a D-08 removal correctly refuses one
- `register_baixa` — replaces the direct `animals` UPDATE (wiring deferred to plan 05-07), reuses the `move_animal_to_lot` WR-01 `IF NOT FOUND` re-check, and deliberately does not touch `animal_atf_memberships` since plan 05-01's trigger handles D-19 on every access path
- Extended `05_reproductive_test.sql` from `plan(9)` to `plan(26)`: 5 `has_function` checks, an auth.users/property_members/`set_config` impersonation fixture that makes the SECURITY DEFINER RPCs callable from a superuser pgTAP session, and 12 assertions proving D-08 removal, D-16 closure + post-closure DG correction, the non-member 23503 guard, the 22023 result-vocabulary guard, and slot-freeing after a hard delete

## Task Commits

Each task was committed atomically:

1. **Task 1: ATF composition RPCs — add_animals_to_atf, remove_animal_from_atf, close_atf** - `a69dea7` (feat)
2. **Task 2: DG and baixa RPCs — save_dg_records, register_baixa** - `bcf1462` (feat)
3. **Task 3: Extend the pgTAP file with RPC guard assertions** - `b35ad95` (test)

_Note: Tasks 1 and 2 both append to the same migration file (`20260805_05_atf_rpcs.sql`), matching the plan's grouping and the same pattern plan 05-01 used._

## Files Created/Modified
- `supabase/migrations/20260805_05_atf_rpcs.sql` - the five SECURITY DEFINER RPCs that form the reproductive module's entire write surface
- `supabase/tests/05_reproductive_test.sql` - extended with the impersonation fixture and 17 new assertions (5 `has_function` + 12 behavioral) against those RPCs

## Decisions Made
- `p_animal_ids`/`p_records` use `jsonb` rather than `uuid[]`/an array of jsonb, reusing `create_lot_with_animals`'s already-proven client serialization path (see `key-decisions` in frontmatter, A-RPC-PARAM).
- `remove_animal_from_atf` is a hard DELETE, not a soft deactivation — the single condition `save_dg_records` relies on to distinguish D-08 (row gone, DG refused) from D-16/D-19 (row present, DG accepted). Documented inline as a "do not harmonize into a soft deactivation" comment.
- pgTAP tests impersonate a JWT via `set_config('request.jwt.claim.sub', ...)` after inserting a test `auth.users` row and a `veterinarian` `property_members` row, because `supabase test db` runs as the postgres superuser with `auth.uid()` returning NULL — every RPC call would otherwise raise 42501 before reaching its business logic. The 42501 rejection path itself stays unasserted (A-PGTAP-ROLE, called out in the plan) and is covered by UAT instead.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria and automated `<verify>` grep checks in the plan passed before each commit. The pgTAP impersonation fixture (auth.users + property_members + `set_config`) was implicitly required by the plan's Task 3 instruction to call the RPCs by name from pgTAP — without it every RPC call would fail with 42501 before reaching the business logic the assertions target — so it is additive test infrastructure, not a deviation from the plan's intent.

## Issues Encountered

None. The `supabase/config.toml` `[db.seed]` block confirmed `seed.sql` runs before `supabase test db` executes pgTAP files, but the pgTAP fixture does not depend on that seed data — it creates its own `auth.users` row so `05_reproductive_test.sql` stays self-contained, matching the file's existing fixture style from plan 05-01.

## User Setup Required

None - no external service configuration required. The migration and pgTAP additions are authored on disk only; live execution (`supabase db push` + `supabase test db`) is explicitly deferred to plan 05-10 per the Supabase MCP note (no authenticated session in this worktree).

## Next Phase Readiness

- The reproductive module's entire write surface (five RPCs) is on disk and internally self-consistent, ready for plan 05-02's `AtfRepository` (already committed, parameter names verified to match exactly) and plan 05-07's `AnimalRepository.registerBaixa` rewiring to call it.
- Blocker carried forward: none of this SQL has run against a live Postgres instance yet. Plan 05-10 must execute `supabase db push` + `supabase test db` before any UAT that touches these RPCs can be trusted — this now covers two migrations (`20260804_05_reproductive_module.sql`, `20260805_05_atf_rpcs.sql`) and the extended pgTAP suite.
- REPR-02/REPR-03 requirement IDs are marked complete at the RPC-design level in this plan's frontmatter; full closure (live-verified) still depends on 05-10.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

- FOUND: supabase/migrations/20260805_05_atf_rpcs.sql
- FOUND: supabase/tests/05_reproductive_test.sql
- FOUND: .planning/phases/05-reproductive-module-loteatf/05-03-SUMMARY.md
- FOUND commit: a69dea7 (Task 1)
- FOUND commit: bcf1462 (Task 2)
- FOUND commit: b35ad95 (Task 3)
- FOUND commit: 680d091 (SUMMARY.md)
