---
phase: 04-movements
plan: 07
subsystem: database
tags: [postgres, plpgsql, trigger, rls, pgtap, supabase, multi-tenancy]

# Dependency graph
requires:
  - phase: 04-movements
    provides: trg_animals_lot_same_property (04-06, gap cycle #2 template), move_lot_to_paddock RPC (04-03), veterinarian_can_update_active_lot RLS policy (Phase 3)
provides:
  - "trg_lots_paddock_same_property: BEFORE INSERT OR UPDATE trigger enforcing lots.paddock_id ∈ property_id on every write path"
  - "pgTAP suite extended (plan 5) proving MOV-02 lots cross-property rejection + same-property success"
  - "lots.paddock_id bypass (MOV-02) flipped from accepted-deferred to CLOSED in 04-CONTEXT.md"
affects: [05-reproductive-module, 06-sanitary-module]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Access-path-independent invariant enforcement via BEFORE INSERT OR UPDATE trigger, mirrored from an existing sibling trigger (trg_animals_lot_same_property) onto a second table with the same shape (lots/paddocks vs animals/lots)"

key-files:
  created:
    - supabase/migrations/20260717_04_lot_paddock_property_trigger.sql
  modified:
    - supabase/tests/04_movements_test.sql
    - .planning/phases/04-movements/04-CONTEXT.md

key-decisions:
  - "Mirrored trg_animals_lot_same_property verbatim (animals→lots, lots→paddocks, lot_id→paddock_id) rather than designing a new approach — identical bug class (WR-02/CR-01-parallel), identical fix"
  - "Kept the NEW.paddock_id IS NOT NULL guard for structural symmetry with the animals trigger even though lots.paddock_id is NOT NULL (branch is unreachable but documented as such) — makes future template diffs trivial to eyeball"
  - "Scope reversal (accept → mitigate, T-4-08) executed per explicit user decision 2026-07-16, recorded in both 04-CONTEXT.md and the plan's threat register — not a unilateral executor decision"

requirements-completed: [MOV-02]

coverage:
  - id: D1
    description: "BEFORE INSERT OR UPDATE trigger trg_lots_paddock_same_property rejects cross-property lots.paddock_id assignment (ERRCODE 23503) on every write path, independent of RLS"
    requirement: "MOV-02"
    verification:
      - kind: other
        ref: "grep-based structural verify (this environment): CREATE TRIGGER trg_lots_paddock_same_property present, CREATE OR REPLACE FUNCTION enforce_lot_paddock_same_property present, ERRCODE 23503 present, NEW.paddock_id IS NOT NULL guard present"
        status: pass
      - kind: integration
        ref: "supabase/tests/04_movements_test.sql (pgTAP, plan 5 — 2 new lots assertions: cross-property throws_ok 23503, same-property lives_ok) — NOT YET RUN, requires supabase db push + supabase test db"
        status: unknown
    human_judgment: true
    rationale: "Live trigger behavior (the actual MOV-02 proof) can only be verified by running the pgTAP suite against a pushed database. This environment's Supabase CLI is unlinked (confirmed via supabase db push --dry-run) — a human must push and run `supabase test db`, then confirm 5/5 pass, before this deliverable can be marked verified."
  - id: D2
    description: "lots.paddock_id bypass (MOV-02) risk disposition reversed from accepted-deferred to CLOSED in 04-CONTEXT.md Deferred Ideas, naming the new trigger + migration"
    verification:
      - kind: other
        ref: "grep 'trg_lots_paddock_same_property' .planning/phases/04-movements/04-CONTEXT.md — bullet present and rewritten"
        status: pass
    human_judgment: false
  - id: D3
    description: "All four unpushed Phase-4 migrations applied to the dev Supabase project and supabase test db green (5/5)"
    verification: []
    human_judgment: true
    rationale: "This session's Supabase CLI is unlinked/unauthenticated (supabase db push --dry-run → 'Cannot find project ref. Have you run supabase link?'). Per the plan's escape hatch, this is BLOCKED not failed — a human with dev credentials must push and run supabase test db before MOV-02's live enforcement and the raw-PATCH-on-lots UAT can be confirmed."

duration: 8min
completed: 2026-07-16
status: complete
---

# Phase 4 Plan 07: Movements — MOV-02 Lots Trigger Gap Closure Summary

**BEFORE INSERT OR UPDATE trigger `trg_lots_paddock_same_property` closes the WR-02/CR-01-parallel raw-PATCH bypass of `move_lot_to_paddock` on `lots.paddock_id`, mirroring the 04-06 animals trigger exactly; DB push remains BLOCKED pending manual credentials, now covering four migrations.**

## Performance

- **Duration:** ~8 min (task execution; excludes read time)
- **Started:** 2026-07-16T13:33:15Z
- **Completed:** 2026-07-16T13:41:41Z
- **Tasks:** 3 (2 fully completed, 1 blocked per plan-sanctioned escape hatch)
- **Files modified:** 3

## Accomplishments

- Closed the reversed-scope MOV-02 finding from 04-REVIEW.md (WR-02/CR-01-parallel): the RLS `veterinarian_can_update_active_lot` `WITH CHECK` on `lots` never inspects `paddock_id`, so a veterinarian who is a member of two properties could bypass `move_lot_to_paddock` with a raw PostgREST `PATCH`. A new `BEFORE INSERT OR UPDATE` trigger, `trg_lots_paddock_same_property`, now enforces "paddock_id must belong to the lot's own property_id" at the table level — RPC, raw PATCH, and any future write path are all covered.
- Extended `supabase/tests/04_movements_test.sql` (pgTAP, `plan(5)`) with a `Paddock A2` fixture in property A and two new assertions: cross-property `paddock_id` UPDATE on `lots` → `23503` (`throws_ok`), same-property `paddock_id` UPDATE → `lives_ok`. Suite now proves both the animals (SC-4) and lots (MOV-02) invariants in one harness.
- Flipped the `lots.paddock_id` bypass entry in `.planning/phases/04-movements/04-CONTEXT.md` Deferred Ideas from "aceito como risco MVP" to "FECHADO no gap cycle #3", naming the new trigger and migration, per the explicit user decision to reverse scope (2026-07-16).
- Task 3 (`supabase db push` for all four unpushed Phase-4 migrations + `supabase test db`) attempted once via `supabase db push --dry-run` and confirmed BLOCKED (`Cannot find project ref. Have you run supabase link?`) — recorded below with recovery steps. No live-DB success is claimed.

## Task Commits

1. **Task 1: Add cross-property paddock trigger on lots (MOV-02 fix)** - `6dfc2e5` (fix)
2. **Task 2: Add lots assertions to pgTAP suite + mark lots bypass CLOSED in CONTEXT.md** - `0580a34` (test)
3. **Task 3: [BLOCKING] supabase db push (4 migrations) + supabase test db** - BLOCKED, no code changes, no commit (see below)

**Plan metadata:** (this commit, filed after this SUMMARY)

## Files Created/Modified

- `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` - New: `enforce_lot_paddock_same_property()` function + `trg_lots_paddock_same_property` trigger (`BEFORE INSERT OR UPDATE ON lots`); raises `23503` on cross-property/archived-paddock destination; also fires on `property_id` change; mirrors `trg_animals_lot_same_property` (animals→lots, lots→paddocks, lot_id→paddock_id).
- `supabase/tests/04_movements_test.sql` - Extended: `Paddock A2` fixture (`99999999-…` in property A), `plan(5)` (was 3), two new assertions (lots cross-property `throws_ok` 23503, lots same-property `lives_ok`), header comment updated to describe both gap cycles.
- `.planning/phases/04-movements/04-CONTEXT.md` - Deferred Ideas bullet for `lots.paddock_id` rewritten: "aceito como risco MVP" → "FECHADO no gap cycle #3 (plan 04-07)", naming `trg_lots_paddock_same_property` + the new migration.

## Decisions Made

- **Mirrored the animals trigger verbatim rather than redesigning:** same bug class (WR-02/CR-01-parallel is the lots-side twin of CR-01/animals), same fix shape — reduces review surface and keeps the two triggers trivially diffable against each other for future maintenance.
- **Kept the `NEW.paddock_id IS NOT NULL` guard even though it is structurally unreachable** (`lots.paddock_id` is `NOT NULL`, unlike `animals.lot_id`) — documented inline as unreachable-by-design, preserving byte-for-byte structural symmetry with the template trigger.
- **Extended the existing pgTAP file rather than creating a sibling** — one suite, one harness, one `supabase test db` invocation covers both SC-4 (animals) and MOV-02 (lots) with a single fixture set reused across assertions.

## Deviations from Plan

None - plan executed exactly as written, including its explicit escape hatch for Task 3.

## Issues Encountered

None beyond the plan-anticipated Task 3 CLI-unlinked state (see below) — not a deviation, this is the plan's documented expected outcome for this environment.

## `[BLOCKED — manual push pending]`

Task 3 (`supabase db push` for all four unpushed Phase-4 migrations, then `supabase test db`) was attempted once with `supabase db push --dry-run`:

```
Cannot find project ref. Have you run supabase link?
```

Per the plan's escape hatch, this is NOT a plan failure — Tasks 1 and 2 (the fully-completable deliverables) are done and committed. No live-DB pass is claimed for the trigger or the pgTAP suite in this environment.

**Recovery steps for a human with dev Supabase credentials, before UAT:**

1. `supabase link --project-ref <dev-project-ref>`
2. `supabase db push` — applies, in filename order, all four unpushed Phase-4 migrations:
   - `supabase/migrations/20260519_04_movements.sql` (move_lot_to_paddock RPC)
   - `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` (move_animal_to_lot RPC, WR-01-amended)
   - `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` (trg_animals_lot_same_property — SC-4 trigger, gap cycle #2)
   - `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` (new — trg_lots_paddock_same_property, this plan)
3. `supabase test db` — executes `supabase/tests/04_movements_test.sql`; confirm 5/5 pass (both the animals cross-property `23503` rejection and the new lots cross-property `23503` rejection are the SC-4 + MOV-02 proofs).

**Manual UAT (in addition to the pgTAP run):** log in as a veterinarian who is a member of two properties, and attempt a raw `PATCH /rest/v1/lots?id=eq.<lotInPropertyA> {"paddock_id":"<paddockInPropertyB>"}` using the app's publishable key. Expect an HTTP error carrying SQLSTATE `23503`, confirming the bypass identified in 04-REVIEW.md WR-02/CR-01-parallel is closed at the database boundary regardless of access path.

## User Setup Required

None - no external service configuration required (the blocked push is a CLI-auth/credentials gap for this session, not a new external service).

## Next Phase Readiness

- The MOV-02 `lots.paddock_id` bypass is now closed at the code/migration level, access-path-independently. It is NOT yet closed at the live database — that requires the manual push + pgTAP run above.
- Phase 4 overall status: all 7 plans (04-01 through 04-07) are now code-complete. The single remaining blocker for Phase 4 UAT is the manual `supabase db push` covering all four unpushed migrations (unchanged in kind from prior blockers, now consolidated to one recovery procedure covering four files).
- T-4-08 threat register disposition moved from `accept` (04-06) to `mitigate` (this plan) — the risk register now reflects the closed state pending live verification.

---
*Phase: 04-movements*
*Completed: 2026-07-16*

## Self-Check: PASSED

All 3 claimed files found on disk; both task commits (`6dfc2e5`, `0580a34`) found in git log.
