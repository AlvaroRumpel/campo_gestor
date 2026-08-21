---
phase: 07-expenses-by-paddock
plan: 01
subsystem: database
tags: [postgres, rls, pgtap, supabase, plpgsql, triggers]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot
    provides: sanitary_applications table, register_sanitary_application / reverse_sanitary_application RPCs, trg_snapshot_immutable, doses table
  - phase: 04-movements
    provides: trg_lots_paddock_same_property (the isolation-trigger template copied verbatim for expenses)
provides:
  - "expenses table with property/paddock scoping, D-23 two-role (owner+veterinarian) write gate, D-24 all-member read gate, D-26 cross-property isolation trigger, D-27 auditing trigger"
  - "sanitary_applications.paddock_id / paddock_name columns, backfilled and locked NOT NULL (D-30/D-31)"
  - "register_sanitary_application / reverse_sanitary_application forward-only edits that freeze paddock attribution at write time"
  - "07_expenses_test.sql pgTAP suite (42 assertions, deliberately red until 07-08 applies the migration)"
affects: [07-02, 07-03, 07-04, 07-05, 07-06, 07-07, 07-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SET ROLE authenticated + set_config('request.jwt.claim.sub', ...) to actually exercise direct-table RLS in pgTAP (new to this codebase — prior suites only tested RPC-internal 42501 checks, which don't require RLS enforcement)"
    - "Single migration file spanning a new table + a cross-phase ALTER + two forward-only RPC edits, kept atomic because MCP apply_migration runs one file as one transaction"

key-files:
  created:
    - supabase/migrations/20260813_07_expenses_module.sql
    - supabase/tests/07_expenses_test.sql
  modified: []

key-decisions:
  - "Migration written as one file (table + sanitary_applications ALTER + backfill + both RPC edits) per RESEARCH's resolved Open Question #1 — a half-applied state would leave the unified expense list unable to render sanitary rows"
  - "pgTAP Groups 4-7 (direct-table RLS write/read gate) use SET ROLE authenticated in addition to set_config — the established set_config-only pattern from 05/06 test suites only proves RPC-internal manual checks, not actual RLS enforcement, and supabase test db's postgres superuser session bypasses RLS unconditionally otherwise"

patterns-established:
  - "SET ROLE authenticated for pgTAP tests of direct-table RLS policies (see 07_expenses_test.sql header comment) — future direct-table-CRUD phases should reuse this instead of relying on set_config alone"

requirements-completed: [GAST-01, GAST-02]

coverage:
  - id: D1
    description: "expenses table, RLS policies (D-23 two-role write, D-24 all-member read), and the D-26 cross-property isolation trigger"
    requirement: "GAST-01"
    verification:
      - kind: integration
        ref: "supabase/tests/07_expenses_test.sql Groups 3-5 (isolation trigger, write gate, read gate)"
        status: unknown
    human_judgment: true
    rationale: "pgTAP suite is authored but not executed — no local Docker/Supabase CLI stack available this session (environment_constraint). Verification is deferred to 07-08's blocking apply + replay task; this plan only proves the SQL is syntactically coherent and internally consistent via targeted grep checks against the plan's acceptance criteria."
  - id: D2
    description: "sanitary_applications.paddock_id/paddock_name freeze (D-30) with backfill of the 2 pre-existing PROD rows (D-31) and forward-only RPC edits"
    requirement: "GAST-02"
    verification:
      - kind: integration
        ref: "supabase/tests/07_expenses_test.sql Group 8 (structural checks + live register_sanitary_application call)"
        status: unknown
    human_judgment: true
    rationale: "Same as D1 — authored, not executed. 07-08 owns the apply and the pgTAP replay against live/rolled-back state."

# Metrics
duration: 15min
completed: 2026-08-11
status: complete
---

# Phase 7 Plan 01: Database Layer (expenses + sanitary paddock freeze) Summary

**Single migration authoring the `expenses` table (D-23 owner+veterinarian write gate, D-24 all-member read, D-26 cross-property isolation trigger), the `sanitary_applications.paddock_id`/`paddock_name` freeze with a DISABLE/ENABLE-scoped backfill of 2 live PROD rows, forward-only edits to both sanitary RPCs, and a 42-assertion pgTAP suite — nothing applied to the live database.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-11T14:05:00-03:00 (approx, research/read phase)
- **Completed:** 2026-08-11T14:20:07-03:00
- **Tasks:** 3
- **Files modified:** 2 (both new)

## Accomplishments
- `expenses` table with property/paddock scoping, 3 RLS policies, 2 triggers, 2 indexes, no DELETE policy — all on disk in `20260813_07_expenses_module.sql`
- `sanitary_applications.paddock_id`/`paddock_name` added, backfilled (approximate, documented), and locked NOT NULL inside a `DISABLE TRIGGER`/`ENABLE TRIGGER` window around `trg_snapshot_immutable`
- `register_sanitary_application` and `reverse_sanitary_application` replaced forward-only (`CREATE OR REPLACE FUNCTION`, unchanged signatures) to freeze `paddock_id`/`paddock_name` at write time — `20260811_06_sanitary_rpcs.sql` on disk untouched
- `07_expenses_test.sql` — 42 pgTAP assertions covering structure, both triggers, the isolation trigger with RLS out of the picture, the two-role write gate, the all-member read gate, the G-06-2 restore regression, D-27 auditing, and the D-30 sanitary freeze including a live `register_sanitary_application` call

## Task Commits

Each task was committed atomically:

1. **Task 1: Author the expenses table, RLS policies and triggers** - `a7e1d6f` (feat)
2. **Task 2: Freeze paddock attribution on sanitary_applications and backfill** - `51971ef` (feat)
3. **Task 3: Author the 07_expenses pgTAP suite** - `e04140c` (test)

**Plan metadata:** (this commit, in worktree mode STATE.md/ROADMAP.md are excluded — see below)

## Files Created/Modified
- `supabase/migrations/20260813_07_expenses_module.sql` - `expenses` table + RLS + triggers (task 1); `sanitary_applications` ALTER + backfill + RPC forward-only edits (task 2)
- `supabase/tests/07_expenses_test.sql` - pgTAP suite, 42 assertions, authored red (task 3)

## Decisions Made
- Split the migration into two commits (task 1: `expenses` table; task 2: `sanitary_applications` freeze + RPCs) even though both append to the same file, to keep each task's automated verification checks scoped to the file state the PLAN.md actually describes for that task (the `deleted_at IS NULL` occurrence-count check in task 1's acceptance criteria only holds before task 2's RPC bodies — which reuse that phrase verbatim from the original RPCs — are appended).
- pgTAP Groups 4-7 add `SET ROLE authenticated;` before impersonating owner/veterinarian/reader via `set_config('request.jwt.claim.sub', ...)`. Prior suites (05/06) only test RPC-internal manual 42501 checks, which work under the `postgres` superuser session because `auth.uid()` just reads a session GUC. `expenses` is direct-table CRUD (D-25) — its write gate is real Postgres RLS, and `supabase test db`'s `postgres` session bypasses RLS unconditionally regardless of role impersonation via `set_config` alone. `SET ROLE authenticated` (Supabase's own documented pgTAP RLS-testing technique) is required for the Group 4/6/7 assertions to actually exercise the policies instead of vacuously passing. This is new to the codebase — flagged in `tech-stack.patterns` for future direct-table-CRUD phases to reuse.
- Assertion count landed at 42, not the 41 originally estimated while drafting — `plan(42)` set to the actual count via `grep -c` against the finished file rather than a hand-tally.

## Deviations from Plan

None — plan executed exactly as written. The task-1/task-2 commit split and the `SET ROLE authenticated` addition are execution-detail decisions within the plan's own instructions (task 2 explicitly says "Append to the same file"; the plan's task 3 acceptance criteria require actual 42501 rejection for a reader on direct-table INSERT/UPDATE, which is only achievable with real RLS enforcement), not deviations from scope.

## Issues Encountered
- Initial `plan(41)` assertion count didn't match the actual 42 `SELECT` assertion statements once the file was complete — corrected via `grep -c` against the finished file before committing task 3, per the plan's own acceptance criterion ("N equals the number of assertions in the file").

## User Setup Required

None - no external service configuration required. The migration is authored on disk only; applying it to the live Supabase project is 07-08's dedicated blocking task per D-37 (this plan's `environment_constraint` explicitly forbids `apply_migration`/`execute_sql` here — no local Docker/Supabase CLI stack is available this session).

## Next Phase Readiness
- `expenses` table, its RLS/triggers, and the `sanitary_applications` paddock freeze are fully authored and internally consistent (verified via the plan's own grep-based acceptance criteria) — ready for 07-08 to apply and replay the pgTAP suite against live/rolled-back state.
- Downstream plans in this wave (07-02 Dart data layer) can reference the finalized column/table/policy names (`expenses.paddock_id`, `expenses.category`, etc.) since this migration is the locked schema contract, even though it is not yet applied to the database.
- Blocker carried forward (not introduced by this plan): no local Docker/Supabase CLI stack — 07-08 will need the same MCP `apply_migration`/`execute_sql` workaround used for every prior phase's push (Phases 3-6).

---
*Phase: 07-expenses-by-paddock*
*Completed: 2026-08-11*
