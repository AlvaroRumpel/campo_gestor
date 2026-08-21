---
phase: 05-reproductive-module-loteatf
plan: 12
subsystem: database
tags: [postgres, plpgsql, security-definer, pgtap, supabase, migration]

requires:
  - phase: 05-reproductive-module-loteatf
    provides: "register_baixa and add_animals_to_atf RPCs (20260805_05_atf_rpcs.sql), the D-19 baixa->membership-deactivation trigger chain, and the pgTAP suite skeleton (05_reproductive_test.sql) all plans in this phase extend"
provides:
  - "20260808_05_fix_baixa_observation_and_atf_dedup.sql — forward-only corrective migration re-declaring register_baixa (CASE-based observation append, CR-01) and add_animals_to_atf (SELECT DISTINCT payload dedup, WR-02)"
  - "Six new pgTAP assertions (28-33) proving the append/no-op/dedup behaviors, authored and committed but NOT executed (A-PGTAP-NODOCKER)"
affects: [05-reproductive-module-loteatf]

tech-stack:
  added: []
  patterns:
    - "Forward-only corrective migration: CREATE OR REPLACE FUNCTION carrying the full current body verbatim, with exactly one expression changed per function — third instance of this phase's convention (20260806, 20260807, now 20260808)"

key-files:
  created:
    - supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql
  modified:
    - supabase/tests/05_reproductive_test.sql

key-decisions:
  - "A-OBS-SHARED-COLUMN carried from the plan: appended into the shared animals.observation column rather than adding a dedicated baixa_observation column. Data-loss defect fully closed either way; a dedicated column is deferred as a presentation nicety, not built here."
  - "Task 3 (applying the migration to the live wrdwzychjhlpwpivfhhq project) explicitly out of scope for this worktree-isolated executor per the orchestrator's task3_scope_restriction — no Supabase MCP tool was called, no supabase db push was run. Returned as a blocking-human checkpoint instead of attempted."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "register_baixa re-declared: observation assignment changed from a COALESCE-style replace to a CASE-based append (NULL/empty p_observation is a no-op; non-empty appends after a newline). All prior guards (is_member_of, veterinarian role, search_path, deleted_at archival, IF NOT FOUND re-check) preserved verbatim."
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "Task 1 automated acceptance gate — grep-based structural check over the migration file (0 COALESCE(p_observation, 1 CASE-append literal, 2x search_path pin, 2x is_member_of guard, 2x GRANT EXECUTE, IF NOT FOUND present)"
        status: pass
    human_judgment: true
    rationale: "The migration file is structurally verified on disk but NOT applied to any live Postgres instance in this session (Task 3 explicitly out of scope for this executor). A human must apply it via Task 3's CLI/MCP ladder and read back pg_proc before this deliverable is behaviorally proven live."
  - id: D2
    description: "add_animals_to_atf re-declared: feeding SELECT gains DISTINCT so a payload uuid repeated once no longer trips the partial unique index and fails the whole batch with 23505. Cross-ATF duplicates (animal already in a different active ATF) still raise 23505 — no ON CONFLICT was added."
    requirement: "REPR-02"
    verification:
      - kind: other
        ref: "Task 1 automated acceptance gate — grep-based structural check (1x SELECT DISTINCT, 0x ON CONFLICT)"
        status: pass
    human_judgment: true
    rationale: "Same as D1 — structurally verified, not yet applied live."
  - id: D3
    description: "Six new pgTAP assertions (28-33): two proving a baixa observation appends to a prior general observation, two proving a NULL baixa observation is a strict no-op, two proving a duplicated uuid in one add_animals_to_atf payload yields exactly one membership row."
    verification:
      - kind: other
        ref: "Task 2 automated acceptance gate — plan(33) declared, 33 actual assertion calls counted, all three new PREPARE names and fixture uuids present, file still rolls back"
        status: pass
    human_judgment: true
    rationale: "A-PGTAP-NODOCKER — no Docker/local Supabase stack exists on this machine, so the assertions are authored and structurally verified but NOT executed. A human must run `supabase test db` to prove they pass (or catch a regression)."
  - id: D4
    description: "Apply the corrective migration to the live wrdwzychjhlpwpivfhhq Supabase project and confirm both function bodies read back correctly, then round-trip a real baixa with and without a note through the UI"
    verification: []
    human_judgment: true
    rationale: "Task 3 is gate=\"blocking\" / gate=\"blocking-human\" in the plan and explicitly out of scope for this worktree-isolated executor (task3_scope_restriction) — no Supabase MCP call and no supabase db push were made. This is a live-production write requiring human authorization, not something an automated executor should self-approve."

duration: ~12min
completed: 2026-08-05
status: gaps_found
---

# Phase 5 Plan 12: Corrective Migration for CR-01 (Baixa Observation Data Loss) + WR-02 Summary

**Forward-only migration replacing `register_baixa`'s COALESCE-style observation replace with a CASE-based append, and `add_animals_to_atf`'s feeding SELECT with a DISTINCT dedup, plus six new pgTAP assertions — Tasks 1-2 complete and committed; Task 3 (live apply) intentionally NOT attempted, held for human-authorized production access.**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2/3 completed (Task 3 deferred to human — see below)
- **Files modified:** 2

## Accomplishments

- New migration `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql` re-declares `register_baixa` and `add_animals_to_atf` with exactly one expression changed per function, full bodies otherwise byte-preserved from `20260805_05_atf_rpcs.sql`.
- `register_baixa`'s observation assignment is now `CASE WHEN p_observation IS NULL OR p_observation = '' THEN observation WHEN observation IS NULL OR observation = '' THEN p_observation ELSE observation || E'\n' || p_observation END` — a baixa note appends after any prior general note instead of replacing it; a NULL/blank baixa note is a strict no-op.
- `add_animals_to_atf`'s feeding `SELECT` gained `DISTINCT`, so a payload with the same animal uuid twice now inserts exactly one active-membership row instead of failing the whole batch with a raw `23505`. `ON CONFLICT` was deliberately not used anywhere — the partial unique index `animal_atf_memberships_active_idx` still raises `23505` when the animal is already in a *different* active ATF (REPR-02's real guarantee, unweakened).
- `supabase/tests/05_reproductive_test.sql` plan count moved 27 → 33. Six new assertions (28-33) and three new fixture animals (9009-9011, two seeded with a prior `observation`) cover both fixes.
- **Task 3 (applying the migration to the live `wrdwzychjhlpwpivfhhq` project) was intentionally NOT attempted** by this executor. Per this session's explicit scope restriction, no Supabase MCP tool was invoked and no `supabase db push`/equivalent command was run. The live database still runs the defective `register_baixa`/`add_animals_to_atf` until a human applies this migration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Corrective migration — append baixa observation (CR-01) + de-duplicate ATF payload (WR-02)** - `c444b0e` (feat)
2. **Task 2: pgTAP coverage for the append behavior and the payload de-duplication** - `a3ad6d8` (test)
3. **Task 3: [BLOCKING] Apply the corrective migration to the live Supabase project** - **NOT ATTEMPTED — human-authorized production access required** (no commit; see below)

## Task 3 Status: NOT ATTEMPTED — awaiting human-authorized production access

This plan's Task 3 applies a corrective SQL migration to the **live production** Supabase project `wrdwzychjhlpwpivfhhq` and requires a manual browser UI round-trip. Per this execution session's explicit instructions, this worktree-isolated executor did not call any Supabase MCP tool (`apply_migration`, `execute_sql`, or otherwise) and did not run `supabase db push` or any other command touching the live database. This is a human-authorized action outside this session's scope.

**Required next steps (unchanged from the plan's Task 3):**
1. Apply `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql` to project `wrdwzychjhlpwpivfhhq`, via `supabase db push` (with `SUPABASE_ACCESS_TOKEN` set, never written to a file) or the Supabase MCP `apply_migration` tool if the CLI is unlinked/unauthenticated (the path that resolved the identical blocker for Phase 4 and for 05-10, per `STATE.md`'s A-CLI-BLOCKED note).
2. Read back both function definitions from `pg_proc` (e.g. `SELECT prosrc FROM pg_proc WHERE proname IN ('register_baixa','add_animals_to_atf')` or `pg_get_functiondef`) and confirm: the `CASE`-based observation expression is present and the old `COALESCE`-based one is gone; `add_animals_to_atf`'s body contains `SELECT DISTINCT`; both still show `SECURITY DEFINER` + a pinned `search_path` + `EXECUTE` granted to `authenticated`; each function name resolves to exactly one `pg_proc` row (no accidental overload).
3. Live round trip: open an animal that already has text in "Observação", register a baixa with its own "Observação" note, reopen the animal (include archived), confirm BOTH notes are present separated by a line break.
4. Live round trip: register a second baixa on a different animal with a prior observation, leaving the baixa note blank, confirm the prior observation is byte-unchanged.
5. Once a Docker/local Supabase stack becomes available, run `supabase test db` and confirm all 33 pgTAP assertions pass (A-PGTAP-NODOCKER, unresolved since 05-10).

## Files Created/Modified

- `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql` - New forward-only corrective migration; re-declares `register_baixa` (CASE-append) and `add_animals_to_atf` (SELECT DISTINCT)
- `supabase/tests/05_reproductive_test.sql` - `plan(27)` → `plan(33)`; three new fixture animals (9009-9011); six new assertions (28-33) covering the append, no-op, and dedup behaviors

## Decisions Made

- Appended into the shared `animals.observation` column rather than adding a dedicated `baixa_observation` column (A-OBS-SHARED-COLUMN, carried from the plan's own flagged assumption — the reviewer's preferred option). The data-loss defect is fully closed either way; a dedicated column is deferred.
- De-duplication for WR-02 was implemented via `SELECT DISTINCT` in the feeding query, never via `ON CONFLICT`, so the partial unique index still raises `23505` for a cross-ATF conflict — verified by the acceptance gate's `ON CONFLICT` count of zero.
- Task 3 was not attempted in this session — treated as a hard scope boundary (production database write), not an oversight. No CLI or MCP command touching the live project was run.

## Deviations from Plan

**One process deviation, not a code deviation:** during initial authoring of the migration file, the header/inline comments briefly quoted the literal `COALESCE(p_observation, observation)` expression being replaced — which the plan explicitly prohibits (Task 1's acceptance criteria requires zero occurrences of that literal, even in comments, once comment lines are stripped for the code-body check; the two comment lines describing the defect were still literal text matches). Caught by re-running the Task 1 acceptance gate before committing; both comments were rewritten to describe the defect in words ("replaced rather than appended... outright instead of appending") without quoting the removed expression. No functional code was affected — this was caught and fixed before the Task 1 commit, so no separate fix commit was needed.

None of the deviation rules (1-4) were triggered otherwise — the plan's action blocks were followed as specified for both completed tasks.

**Total deviations:** 0 auto-fixed (the one comment-wording issue was corrected pre-commit, not a post-verification fix)
**Impact on plan:** None — Tasks 1 and 2 match the plan's acceptance criteria exactly as gated.

## Issues Encountered

None for Tasks 1-2. Task 3 could not be attempted in this session by design (see "Task 3 Status" above) — this is an accepted, scope-sanctioned outcome, not an unresolved issue.

## User Setup Required

**Manual production migration apply + live round-trip verification required.** No `USER-SETUP.md` was generated (single blocking step, documented inline above under "Task 3 Status"):
1. Apply `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql` to `wrdwzychjhlpwpivfhhq` via CLI or Supabase MCP `apply_migration`.
2. Read back `pg_proc` for both functions and confirm the corrected bodies, `SECURITY DEFINER`, `search_path`, and grants.
3. Perform the two live round trips described above (with-note append, blank-note no-op).
4. Reply "approved" per the plan's `<resume-signal>`, or report what failed.

## Next Phase Readiness

- CR-01 and WR-02 are closed **in the repository** — the corrective migration and its pgTAP coverage are committed. The phase remains blocked on `gaps_found` until Task 3's live apply and round-trip are confirmed by a human, per A-REVERIFY-STILL-HUMAN (carried from the plan).
- The pgTAP suite's assertion count (33) and structure are verified by the automated acceptance gates but the suite itself remains unexecuted pending a Docker/local Supabase stack (A-PGTAP-NODOCKER, unchanged since 05-10).
- No Dart source or test file was touched by this plan (`git diff --name-only` for these two commits lists only the two `files_modified` paths) — WR-01 remains owned by plan 05-13 as scoped.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-05 (Tasks 1-2 only; Task 3 pending human action)*

## Self-Check: PASSED

Both created/modified files verified present on disk (`supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql`, `supabase/tests/05_reproductive_test.sql`). Both task commit hashes (`c444b0e`, `a3ad6d8`) verified present in `git log`.
