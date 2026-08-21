---
phase: 05-reproductive-module-loteatf
plan: 10
subsystem: database
tags: [supabase, postgres, migrations, rls, plpgsql, security-definer, pgtap]

requires:
  - phase: 05-01
    provides: the reproductive schema migration (atf_batches, dg_records, triggers, RLS policies)
  - phase: 05-03
    provides: the five SECURITY DEFINER RPCs that form the module's entire write surface
  - phase: 05-09
    provides: the completed Flutter surface whose .rpc() calls resolve only after this push
provides:
  - Both Phase 5 migrations applied to live Supabase project wrdwzychjhlpwpivfhhq
  - Live-verified schema objects (2 tables, 1 altered table, 5 indexes, 4 RLS policies, 3 triggers, 5 RPCs)
  - Recorded pgTAP execution status (unrun — no local Docker stack)
affects: [06-sanitary-module, 08-animal-dossier, uat, secure-phase]

tech-stack:
  added: []
  patterns:
    - "Remote migration application via Supabase MCP apply_migration when the CLI is unlinked (second use; established Phase 4)"
    - "Post-apply object verification by querying the catalog rather than trusting a command exit code"

key-files:
  created:
    - .planning/phases/05-reproductive-module-loteatf/05-10-SUMMARY.md
  modified:
    - .planning/STATE.md

key-decisions:
  - "Applied via Supabase MCP apply_migration, not the CLI — the CLI is authenticated but unlinked, and no TTY exists for a database password prompt. This is the same path that resolved the identical Phase 4 blocker on 2026-08-04."
  - "Verified A-SCHEMA-01 empirically before applying: animal_atf_memberships had 0 rows, so the ADD COLUMN property_id NOT NULL needed no backfill and the plan's split-ALTER fallback was not required."
  - "Did NOT patch the anon-EXECUTE finding in production — it is pre-existing across Phases 1-4, outside this plan's empty files_modified scope, and a user decision. Routed to /gsd-secure-phase."

patterns-established:
  - "Pre-apply prerequisite probe: query for referenced functions, columns and types before applying a migration that depends on them"

requirements-completed: [REPR-01, REPR-02, REPR-03, REPR-04, REPR-05]

coverage:
  - id: D1
    description: "Both Phase 5 migrations applied to the live Supabase project and recorded in the migration ledger"
    verification:
      - kind: integration
        ref: "mcp supabase list_migrations wrdwzychjhlpwpivfhhq -> 20260804202014 reproductive_module, 20260804202055 atf_rpcs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Live schema objects confirmed present by catalog query: atf_batches, dg_records, animal_atf_memberships.property_id + 2 named FKs, animal_atf_memberships_active_idx preserved, 3 enabled triggers, 5 RPCs with EXECUTE granted to authenticated, 4 SELECT-only RLS policies, and zero write policies on dg_records/animal_atf_memberships"
    verification:
      - kind: integration
        ref: "mcp supabase execute_sql — information_schema/pg_trigger/pg_proc/pg_policies verification query"
        status: pass
    human_judgment: false
  - id: D3
    description: "pgTAP suite in supabase/tests/05_reproductive_test.sql executed"
    verification:
      - kind: integration
        ref: "supabase test db"
        status: unknown
    human_judgment: true
    rationale: "NOT RUN. Docker is unavailable on this machine (`docker info` fails; `supabase status` cannot reach the Docker named pipe), so the local stack required by `supabase test db` cannot start. The suite is authored and committed (26 assertions across plans 05-01 and 05-03) but unexecuted. Must be run before Phase 5 is considered database-verified."
  - id: D4
    description: "Twelve-step live UAT of the reproductive module against the real project"
    verification: []
    human_judgment: true
    rationale: "Blocking human checkpoint by design (Task 3, gate=blocking). Requires a browser, two signed-in roles, and visual confirmation. It is the only coverage the 42501 role guards get, since pgTAP runs as superuser with no JWT to impersonate (A-PGTAP-ROLE)."

duration: 12min
completed: 2026-08-04
status: complete
---

# Phase 05 Plan 10: Live Schema Push Summary

**Both Phase 5 migrations applied to live Supabase project `wrdwzychjhlpwpivfhhq` via MCP `apply_migration`, with every schema object confirmed by catalog query — pgTAP left unrun for lack of a local Docker stack, and the twelve-step UAT still open.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-08-04
- **Tasks:** 2 of 3 complete (Task 3 is the open blocking human checkpoint)
- **Files modified:** 0 source files (`files_modified: []` by design — this plan changes the database, not the repo)

## Accomplishments

- Applied `20260804_05_reproductive_module.sql` then `20260805_05_atf_rpcs.sql`, in that order, to the live project. The ledger now shows 10 migrations, up from 8.
- Verified every object landed by querying the catalog rather than trusting exit codes (threat T-05-55): `atf_batches` and `dg_records` exist; `animal_atf_memberships` gained `property_id` plus both named FKs; `animal_atf_memberships_active_idx` survived the ALTER; all three triggers exist and are enabled; all five RPCs exist with `EXECUTE` granted to `authenticated`.
- Confirmed the D-21 invariant holds in production: **zero** INSERT/UPDATE/DELETE policies on `dg_records` and `animal_atf_memberships`, so the SECURITY DEFINER RPCs really are the only write path.
- Confirmed assumption **A-SCHEMA-01** before applying: `animal_atf_memberships` held 0 rows, so the `NOT NULL` column needed no backfill.

## Task Commits

This plan modifies no source files; its only artifact is this summary plus the STATE.md blocker update.

1. **Task 1: Apply both migrations** — no repo commit (database-side change; recorded in the Supabase migration ledger as `20260804202014` and `20260804202055`)
2. **Task 2: Run pgTAP and record result** — recorded below and in STATE.md Blockers
3. **Task 3: Human verification** — OPEN

## Decisions Made

- **MCP over CLI.** `supabase projects list` succeeded (so the CLI's stored auth is valid and the target project is visible) but `supabase migration list` failed with "Cannot find project ref. Have you run supabase link?", and no TTY exists for the database password. The MCP `apply_migration` path — the one that resolved the identical Phase 4 blocker — was used instead. A-CLI-BLOCKED was therefore correct.
- **No production patch for the anon-EXECUTE finding.** See Issues below.

## Deviations from Plan

None — the plan anticipated both the CLI blockage (A-CLI-BLOCKED) and the pgTAP stack risk (A-PGTAP-STACK), and both materialized exactly as written. No migration was edited to make anything succeed.

## Issues Encountered

**1. pgTAP suite could not be executed.**
`docker info` fails and `supabase status` cannot reach the Docker named pipe, so the local stack `supabase test db` requires cannot start. Per the plan's explicit instruction this is recorded, not silently skipped: the 26-assertion suite is authored and committed but **unproven**. It is on the manual verification list (coverage D3). The Phase 4 suite `04_movements_test.sql` remains unrun for the same reason.

**2. `anon` can execute the SECURITY DEFINER RPCs despite `REVOKE ALL … FROM public`.**
Surfaced by `get_advisors` and then confirmed empirically with `has_function_privilege('anon', …)` — which returns `true` for all five new RPCs *and* for Phase 4's `move_animal_to_lot`. Cause: Supabase grants EXECUTE to `anon`/`authenticated` through `ALTER DEFAULT PRIVILEGES`; revoking from the `PUBLIC` pseudo-role does not remove that explicit grant.

Impact is bounded — each function's `is_member_of()` guard returns false when `auth.uid()` is NULL, so an anon call fails closed with `42501`. The residual weakness is a **UUID-existence oracle**: the `property_id` row lookup precedes the membership check, so an anon caller can distinguish a real batch/animal id (`42501`) from a non-existent one (`23503`). Low severity given 122-bit v4 UUIDs.

Not fixed here: it is pre-existing across Phases 1-4, outside this plan's `files_modified: []` scope, and a policy decision for the developer. Routed to `/gsd-secure-phase`.

**3. Pre-existing advisor findings, untouched (all predate Phase 5):**
- `sanitary_applications` has RLS enabled with no policies (INFO) — Phase 6 territory.
- `prevent_snapshot_mutation` has a mutable `search_path` (WARN) — Phase 6 function. All five new Phase 5 functions correctly set `search_path = public` and are not flagged.
- Leaked-password protection disabled in Auth (WARN) — unrelated project config.

## User Setup Required

Two items remain the developer's, both recorded in STATE.md Blockers:

1. **Run the pgTAP suite** once a Docker/Supabase local stack is available: `supabase test db`. Any failure is a real defect in the 05-01 or 05-03 migrations — fix the migration and re-apply, never weaken an assertion.
2. **Supabase Auth Site URL** is still `http://localhost:3000` (carried over, A-AUTH-URL). It does not block Phase 5 UAT if you sign in with an already-confirmed account, but it will bite a fresh signup.

## Next Phase Readiness

The live schema now matches the committed migrations, so every `.rpc()` call in `atf_repository.dart` and `animal_repository.dart` resolves. Phase 5 is ready for its twelve-step UAT.

**Phase 5 must NOT be marked verified until the Task 3 checkpoint is approved** — 204 green Flutter tests alone are a false positive, since Dart types come from source rather than from the live schema (threat T-05-58).

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*
