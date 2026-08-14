---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 01
subsystem: database
tags: [postgres, supabase, rls, security-definer, migration]

# Dependency graph
requires:
  - phase: 01-auth-multitenancy-core
    provides: role_enum, properties, property_members, is_member_of()
  - phase: 02-property-paddock-structure
    provides: get_role(), properties.deleted_at
  - phase: "09 (quick 260814-f2v)"
    provides: enforce_property_id_immutable() trigger function reused for invites.property_id
provides:
  - "invites table (FORCE RLS, 2 SELECT-only policies, zero write policies)"
  - "current_user_email() and assert_not_last_veterinarian() helpers"
  - "9 SECURITY DEFINER RPCs: create_invite, revoke_invite, accept_invite, decline_invite, list_my_invites, list_property_members, remove_member, update_member_role, leave_property"
affects: [10-02 (pgTAP tests), 10-03 (Dart data layer), 10-04..10-09 (Dart UI), 10-10 (migration apply)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Membership writes route exclusively through SECURITY DEFINER RPCs — property_members and invites keep FORCE RLS with zero write policies"
    - "Lock-then-count guard pattern (assert_not_last_veterinarian): PERFORM ... FOR UPDATE locks the full row set before a separate SELECT count(*), because Postgres rejects count() combined with FOR UPDATE in one statement, and locking only the target row is racy under concurrent removals"
    - "Identity derived server-side via current_user_email() — RPCs accepting an invite id never accept an email parameter, closing the invite-hijack vector"

key-files:
  created:
    - supabase/migrations/20260814_11_membership_lifecycle.sql
  modified: []

key-decisions:
  - "assert_not_last_veterinarian has no SECURITY DEFINER — it only runs inside another SECURITY DEFINER function and inherits that elevated context"
  - "create_invite/revoke_invite require role IN (veterinarian, owner), not vet-only like most other RPCs in this project (D-10-04)"
  - "leave_property has no actor role check — any member may leave (D-10-05); only the last-veterinarian guard can block it"

patterns-established:
  - "list_property_members returns a server-computed is_self boolean so the UI never needs a separate identity lookup to decide Remove vs Leave"

requirements-completed: [MEMB-01, MEMB-02, MEMB-03]

coverage:
  - id: D1
    description: "invites table with FORCE RLS, exactly 2 SELECT-only policies, zero write policies"
    requirement: MEMB-01
    verification:
      - kind: other
        ref: "grep -c 'CREATE POLICY' supabase/migrations/20260814_11_membership_lifecycle.sql == 2; grep FORCE ROW LEVEL SECURITY present"
        status: pass
    human_judgment: false
  - id: D2
    description: "11 new functions authored; 10 client-callable RPCs carry the REVOKE ALL / GRANT EXECUTE TO authenticated / REVOKE EXECUTE FROM anon,PUBLIC footer"
    requirement: MEMB-01
    verification:
      - kind: other
        ref: "grep -c 'FROM anon, PUBLIC' == 10; grep -c 'SET search_path' == 11"
        status: pass
    human_judgment: false
  - id: D3
    description: "assert_not_last_veterinarian locks the full veterinarian row set with FOR UPDATE before counting (lock-then-count), guarding MEMB-03 across remove_member/update_member_role/leave_property"
    requirement: MEMB-03
    verification:
      - kind: other
        ref: "manual code read: PERFORM ... FOR UPDATE precedes SELECT count(*) in assert_not_last_veterinarian body"
        status: pass
    human_judgment: false
  - id: D4
    description: "accept_invite/decline_invite derive identity via current_user_email(), never from a client-supplied email parameter"
    requirement: MEMB-02
    verification:
      - kind: other
        ref: "manual code read: both function signatures take only p_invite_id; body calls current_user_email()"
        status: pass
    human_judgment: false
  - id: D5
    description: "Migration is a genuinely new forward-only file — no prior migration edited, and the migration itself was not applied to any database"
    verification:
      - kind: other
        ref: "git diff --stat ad5dfc4 HEAD -- supabase/migrations/ shows only the new file, 551 insertions"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 01: Membership Lifecycle Migration Summary

**Authored (not applied) `20260814_11_membership_lifecycle.sql` — an `invites` table plus 11 functions (2 internal helpers + 9 SECURITY DEFINER RPCs) that become the sole write/broad-read path for `property_members`, closing the gap where no gestor could list, add, or remove members.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-08-14
- **Tasks:** 3
- **Files modified:** 1 (new file)

## Accomplishments
- `invites` table: FORCE RLS, 2 SELECT-only policies (`invitee_can_read_own_invites`, `managers_can_read_property_invites`), zero write policies — writes only via RPC
- `current_user_email()` and `assert_not_last_veterinarian()` helpers; the latter uses lock-then-count (`PERFORM ... FOR UPDATE` on the full veterinarian row set, then a separate `count(*)`) to close the last-veterinarian race under concurrent removals
- 5 invite RPCs: `create_invite` (email normalized via `lower(trim(...))`, role vet-or-owner), `revoke_invite`, `accept_invite` (identity from `current_user_email()`, never a parameter), `decline_invite`, `list_my_invites` (joins `properties.name`, filters archived farms)
- 4 member RPCs: `list_property_members` (server-computed `is_self`), `remove_member`, `update_member_role` (guard fires only when demoting the last veterinarian; `SET` touches only `role`), `leave_property` (no actor-role check, any member may leave — D-10-05)

## Task Commits

Each task was committed atomically:

1. **Task 1: Tabela invites, RLS, trigger e os dois helpers** - `4cc9c1c` (feat)
2. **Task 2: RPCs de convite — create/revoke/accept/decline/list_my_invites** - `5c4e7ac` (feat)
3. **Task 3: RPCs de membro — list/remove/update_role/leave com a guarda MEMB-03** - `fa50729` (feat)

**Plan metadata:** committed separately below (docs commit)

## Files Created/Modified
- `supabase/migrations/20260814_11_membership_lifecycle.sql` - New forward-only migration: 1 table, 2 indexes, 2 RLS policies, 1 trigger, 11 functions

## Decisions Made
- `assert_not_last_veterinarian` intentionally has no `SECURITY DEFINER` and no client grant — it only runs inside `remove_member`/`update_member_role`/`leave_property`, which are themselves `SECURITY DEFINER`
- `create_invite`/`revoke_invite` check `role IN ('veterinarian', 'owner')`, diverging from the vet-only pattern used by most other RPCs in this codebase, per D-10-04
- `leave_property` has zero actor-role checks by design (D-10-05) — the only gate is the last-veterinarian guard

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written for all three tasks' `<action>` blocks.

### Note on Task 3's embedded automated verify script

Task 3's `<verify><automated>` grep script asserts `grep -c 'assert_not_last_veterinarian' == 4` (1 definition + 3 call sites, comments excluded). The actual non-comment count is **5**, because Task 1's own `<action>` explicitly mandates a footer line `REVOKE ALL ON FUNCTION assert_not_last_veterinarian(uuid, uuid) FROM public;` (to keep the function un-callable by the client), and that footer line also contains the function name. This is an off-by-one in the plan's own verify script, not a defect in the SQL: the security-relevant assertions — no `GRANT EXECUTE ... TO authenticated` on this function, lock-then-count ordering, and exactly 3 call sites (`remove_member`, `update_member_role`, `leave_property`) — all hold and were verified directly. Every other automated/manual acceptance criterion across all 3 tasks passed as specified (2 policies, FORCE RLS, 10 `FROM anon, PUBLIC` footers, 11 `SET search_path`, `lower(trim(` in `create_invite`, `IF NOT FOUND` + `P0002` in the three status-transition RPCs, `is_self` as the 5th column of `list_property_members`, no `get_role(...) NOT IN` in `leave_property`, `UPDATE property_members SET` touching only `role`).

---

**Total deviations:** 0 auto-fixed. 1 documented discrepancy in the plan's own embedded verify script (see above) — no code change made in response, since fixing it would mean dropping a footer line the plan's own Task 1 action explicitly requires.
**Impact on plan:** None. All substantive acceptance criteria pass.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. This migration is intentionally **not applied** to any database (local Docker is dead, CLI is unlinked with no TTY per the plan's `<environment_constraint>`); application to PROD is owned by plan 10-10.

## Next Phase Readiness
- `supabase/migrations/20260814_11_membership_lifecycle.sql` is ready for plan 10-02 (pgTAP tests, file `supabase/tests/10_membership_test.sql`) to write positive/negative RLS and RPC assertions against it, and for plan 10-03 to build the Dart repository layer against the 9 client-callable RPCs
- Migration is not yet applied anywhere — plan 10-10 must run `apply_migration` (or `supabase db push`) before any of 10-02's pgTAP or 10-03..10-09's Dart layers can be exercised against a live database
- No blockers for this plan's own scope

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: `supabase/migrations/20260814_11_membership_lifecycle.sql`
- FOUND: `.planning/phases/10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade/10-01-SUMMARY.md`
- FOUND commit `4cc9c1c` (Task 1)
- FOUND commit `5c4e7ac` (Task 2)
- FOUND commit `fa50729` (Task 3)
