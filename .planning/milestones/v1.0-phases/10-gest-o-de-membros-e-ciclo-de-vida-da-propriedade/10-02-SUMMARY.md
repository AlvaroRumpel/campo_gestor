---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 02
subsystem: database
tags: [postgres, supabase, pgtap, rls, security-definer, testing]

# Dependency graph
requires:
  - phase: "10-01"
    provides: "20260814_11_membership_lifecycle.sql (invites table, 9 RPCs, 2 helpers)"
provides:
  - "supabase/tests/10_membership_test.sql — 81-assertion pgTAP suite proving the membership lifecycle migration's contract"
affects: ["10-10 (migration apply + this suite's replay)", "10-03..10-09 (Dart layers building on the same RPC contract)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bare set_config('request.jwt.claim.sub', ...) suffices to exercise SECURITY DEFINER RPCs whose 42501/22023/23505/23514/P0002 come from manual RAISE EXCEPTION — SET ROLE authenticated is only needed where the write path is direct-table RLS (Group 8's raw INSERT into invites)"
    - "Group 8's RLS-write assertion asserts absence of mutation (fixture-scoped count(*) = 0) alongside the raised error, not the error alone — precedent from 07_expenses_test.sql's reader-UPDATE lesson"
    - "Server-generated invite ids are recovered via a scoped subquery (property_id + invited_email + status='pending') rather than captured into a session variable — pgTAP files have no cross-statement variable binding, and RETURNING can't cross a PREPARE/EXECUTE boundary"

key-files:
  created:
    - supabase/tests/10_membership_test.sql
  modified: []

key-decisions:
  - "Suite authored in full RED state against the not-yet-applied 20260814_11_membership_lifecycle.sql — same D-39/D-41 precedent as 06/07's suites; replay is plan 10-10's job, not this plan's"
  - "has_index() uses the 2-argument form exclusively per the plan's prohibition (3-arg overload is ambiguous and produced a false failure in 05_reproductive_test.sql)"
  - "Every count(*) assertion is scoped to a fixture id/email — never global table state, per the 06_sanitary_test.sql Group 8 lesson"

patterns-established:
  - "has_function_privilege('<role>', '<signature>', 'EXECUTE') pair (true for authenticated, false for anon) is the standard grant-blindage assertion shape for every client-callable SECURITY DEFINER RPC in this project going forward"

requirements-completed: [MEMB-01, MEMB-02, MEMB-03]

coverage:
  - id: D1
    description: "Group 1 proves invites' schema shape: 8 columns, both indexes, FORCE RLS, exactly 2 policies (both SELECT, zero write policies)"
    requirement: MEMB-01
    verification:
      - kind: other
        ref: "supabase/tests/10_membership_test.sql Group 1 (15 assertions) — not yet executed against a live database; execution is plan 10-10"
        status: unknown
    human_judgment: true
    rationale: "This plan authors the suite only (no local Docker/CLI stack per the plan's environment_constraint); the assertions cannot be run until plan 10-10 applies the migration and replays the file — pass/fail is unknown at authoring time."
  - id: D2
    description: "Group 2 proves all 11 functions exist and the 10 client-callable ones are granted to authenticated + revoked from anon, while assert_not_last_veterinarian has no client grant at all"
    requirement: MEMB-01
    verification:
      - kind: other
        ref: "supabase/tests/10_membership_test.sql Group 2 (32 assertions) — execution deferred to plan 10-10"
        status: unknown
    human_judgment: true
    rationale: "Authoring-only plan; suite has not been replayed against any database yet."
  - id: D3
    description: "Groups 4-6 prove create_invite/accept_invite/decline_invite/revoke_invite: role gates, email validation, email case-folding, duplicate-pending rejection, already-member rejection, wrong-email-accept rejection, double-resolution rejection"
    requirement: MEMB-02
    verification:
      - kind: other
        ref: "supabase/tests/10_membership_test.sql Groups 4-6 (20 assertions) — execution deferred to plan 10-10"
        status: unknown
    human_judgment: true
    rationale: "Authoring-only plan; suite has not been replayed against any database yet."
  - id: D4
    description: "Group 9 proves MEMB-03's last-veterinarian guard across all three paths (remove, demote, leave) plus the owner-acting-on-last-vet sub-rule and the promote-never-guards case"
    requirement: MEMB-03
    verification:
      - kind: other
        ref: "supabase/tests/10_membership_test.sql Group 9 (6 assertions, 3 expecting SQLSTATE 23514 directly plus 1 more via the owner path — 4 total 23514 expectations) — execution deferred to plan 10-10"
        status: unknown
    human_judgment: true
    rationale: "Authoring-only plan; suite has not been replayed against any database yet."
  - id: D5
    description: "Group 8 proves invites has zero write policies by attempting a direct INSERT as authenticated and asserting both the raised 42501 AND that zero rows were created (fixture-scoped count)"
    requirement: MEMB-01
    verification:
      - kind: other
        ref: "supabase/tests/10_membership_test.sql Group 8 (2 assertions) — execution deferred to plan 10-10"
        status: unknown
    human_judgment: true
    rationale: "Authoring-only plan; suite has not been replayed against any database yet."
  - id: D6
    description: "plan(81) matches the file's actual assertion count exactly, verified by the plan's own embedded grep-count verify script"
    verification:
      - kind: other
        ref: "bash -c grep -cE assertion-keyword count against supabase/tests/10_membership_test.sql — ran directly during execution, declared=81 actual=81"
        status: pass
    human_judgment: false

duration: ~25min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 02: Membership Test Suite Summary

**Authored `supabase/tests/10_membership_test.sql` — an 81-assertion pgTAP suite proving the invites schema shape, all 11 function grants, the 9 RPCs' behavior contract (case-folded email matching, role gates, duplicate/already-member rejection, double-resolution rejection), the RLS write-blindage on `invites`, and all four paths of the MEMB-03 last-veterinarian guard.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-08-14
- **Tasks:** 2
- **Files modified:** 1 (new file)

## Accomplishments
- Group 1 (15 assertions): `invites` table shape — 8 columns, both indexes (2-arg `has_index()` only), `relrowsecurity`/`relforcerowsecurity` both true, exactly 2 RLS policies and zero non-SELECT policies
- Group 2 (32 assertions): all 11 functions exist; the 10 client-callable RPCs are each proven `EXECUTE`-granted to `authenticated` and revoked from `anon`; `assert_not_last_veterinarian` proven ungranted to `authenticated` (internal-only helper)
- Group 3 (1 assertion): `trg_invites_property_id_immutable` trigger exists
- Group 4 (7 assertions): `create_invite` — vet and owner can invite (D-10-04), reader cannot (42501), invalid email rejected (22023), email case-folded to lowercase on write, duplicate pending invite rejected (23505), invite to an existing member's email rejected (23505)
- Group 5 (9 assertions): `accept_invite`/`decline_invite` — wrong-email accept rejected (42501), correct accept creates the `property_members` row with the invite's exact role and marks the invite `accepted` with `resolved_at` set, re-accept rejected (P0002), decline marks `declined` and creates no membership row
- Group 6 (4 assertions): `revoke_invite` — owner/vet can revoke their own pending invite, re-revoke rejected (P0002), reader cannot revoke (42501)
- Group 7 (5 assertions): `list_property_members` readable by any role including reader (D-10-04), rejected for a non-member (42501); `list_my_invites` returns only the caller's own pending invite with `property_name` populated
- Group 8 (2 assertions): a direct `INSERT INTO invites` as `authenticated` is rejected with 42501 AND is proven to have created zero rows (absence-of-mutation proof, not merely error-raised)
- Group 9 (6 assertions, 4 total 23514 expectations across the file): all three MEMB-03 paths (remove/demote/leave) rejected for a property's last veterinarian; a manager CAN remove a fellow (non-last) veterinarian; the same manager CANNOT then remove the now-last veterinarian; promoting a reader to veterinarian never triggers the guard
- Group 10: documented (not asserted) — the two-simultaneous-removals race is not reproducible inside a single-transaction pgTAP replay; the structural proof (`FOR UPDATE` over the full veterinarian set) lives in the migration source, with a manual two-`psql`-session verification recipe recorded for a human

## Task Commits

Both tasks landed in a single commit (the file was authored end-to-end in one pass, and both tasks' acceptance criteria were verified against the final file before committing — splitting the diff after the fact would not have produced a meaningfully different history):

1. **Task 1 + Task 2: full suite (schema/grant groups + behavior groups)** - `98436f1` (test)

**Plan metadata:** committed separately (this SUMMARY)

## Files Created/Modified
- `supabase/tests/10_membership_test.sql` - New pgTAP suite: header, 6 fixture users (5 with memberships + 1 invitee with none), 2 properties, 10 assertion groups, `plan(81)` matching exactly

## Decisions Made
- Authored both plan tasks as one atomic commit rather than two: Task 1's schema/grant groups and Task 2's behavior groups live in the same file with a single interleaved fixture block, and the plan's own Task 2 acceptance criteria (`plan(N)` == actual count) can only be satisfied once the whole file exists — splitting into two partial commits would have left an intermediate commit with a deliberately-wrong `plan()` count, which is worse than one complete commit
- `has_function_privilege('<role>', '<signature>', 'EXECUTE')` pairs (true for `authenticated`, false for `anon`) used for every client-callable RPC's grant-blindage check — no precedent existed for this exact pattern in 04-07's suites (they only asserted RPC existence via `has_function()`, not grants), so this plan establishes it
- Invite ids for `accept_invite`/`revoke_invite`/`decline_invite` calls are recovered via a scoped subquery (`property_id` + `invited_email` + `status = 'pending'`) inside each `PREPARE` body rather than captured into a variable, since pgTAP test files have no cross-statement variable binding and `RETURNING` can't cross a `PREPARE`/`EXECUTE` boundary

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance criteria were verified directly:
- Task 1's automated verify script (file exists, opens with `BEGIN;`, contains `SELECT plan(`, contains the literal `has_table('invites')`, and has zero 3-arg `has_index()` calls) — **passed**
- Task 2's automated verify script (`plan(N)` declared count equals the actual assertion-line count, file ends with `ROLLBACK;`, and at least one `23514` reference exists) — **passed**: declared=81, actual=81, 7 total `23514` references (4 assertion-relevant + 3 in comments/descriptions)

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. This suite is intentionally **not executed** against any database (no local Docker stack per this plan's `<environment_constraint>`; replay against PROD inside `BEGIN...ROLLBACK` is plan 10-10's responsibility, same as the migration's own application).

## Next Phase Readiness
- `supabase/tests/10_membership_test.sql` is ready for plan 10-10 to replay via MCP `execute_sql` inside a rolled-back transaction, once `20260814_11_membership_lifecycle.sql` is applied in the same session
- All `coverage[]` entries in this SUMMARY are `human_judgment: true` / `status: unknown` because the suite has never been run — plan 10-10 (or a subsequent verification step) must update this traceability with real pass/fail results after replay
- No blockers for this plan's own scope

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: `supabase/tests/10_membership_test.sql`
- FOUND commit `98436f1` (Task 1 + Task 2)
- Task 1 automated verify: OK
- Task 2 automated verify: declared=81 actual=81, OK
