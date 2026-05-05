---
phase: 01-auth-multi-tenancy-core
plan: 01
subsystem: auth-schema
tags: [auth, multi-tenancy, rls, supabase, schema, migration, seed, testing]
dependency_graph:
  requires: []
  provides:
    - schema:propriedades
    - schema:property_members
    - schema:perfil_enum
    - function:is_member_of
    - rls:propriedades
    - rls:property_members
    - seed:userA_userB_alpha_beta
    - test-stubs:wave0-auth
  affects:
    - plans: [01-02, 01-03]
      reason: Plans 02 and 03 implement repositories and screens that query propriedades and property_members
tech_stack:
  added: []
  patterns:
    - FORCE ROW LEVEL SECURITY on all domain tables
    - SECURITY DEFINER helper function with SET search_path to prevent schema-shadowing
    - Deterministic UUID seeds for reproducible integration tests
    - Wave 0 RED test stubs as compile-gates for future production code
key_files:
  created:
    - supabase/migrations/20260504_01_auth_multitenancy.sql
    - supabase/seed.sql
    - test/features/auth/auth_repository_test.dart
    - test/features/auth/property_repository_test.dart
    - test/features/auth/login_screen_test.dart
    - integration_test/rls_isolation_test.dart
  modified:
    - supabase/config.toml
decisions:
  - "SECURITY DEFINER + SET search_path = public, auth on is_member_of() to prevent schema-shadow privilege escalation (T-01-02)"
  - "FORCE ROW LEVEL SECURITY on propriedades and property_members blocks superuser bypass in application context"
  - "INSERT/UPDATE/DELETE not granted in Phase 1 — only seed/service_role can write; write policies deferred to Phase 2"
  - "Wave 0 RED test stubs reference not-yet-existing production files — compile failure is the intended gate"
  - "integration_test/rls_isolation_test.dart gated by SKIP_INTEGRATION env flag so flutter test test/ does not try to run it"
  - "supabase db reset run from worktree directory so CLI finds migrations/ and seed.sql"
metrics:
  duration_seconds: 406
  completed_date: "2026-05-05"
  tasks_completed: 5
  tasks_total: 5
  files_created: 6
  files_modified: 1
---

# Phase 01 Plan 01: Auth & Multi-tenancy Schema Summary

**One-liner:** PostgreSQL schema with propriedades + property_members tables, SECURITY DEFINER RLS helper, bcrypt-seeded test users, and Wave 0 test stubs as compile-gates for Plans 02–04.

## What Was Built

### Migration: `supabase/migrations/20260504_01_auth_multitenancy.sql`

Core DDL for multi-tenant auth isolation:

- **`perfil_enum`** — Postgres ENUM: `proprietario`, `veterinario`, `leitor`
- **`propriedades`** — uuid PK, nome text, created_at. ENABLE + FORCE RLS.
- **`property_members`** — (user_id, property_id) composite PK + FK to auth.users and propriedades, perfil column, created_at. ENABLE + FORCE RLS.
- **`property_members_user_id_idx`** — index for user-scoped property listing queries
- **`is_member_of(uuid) RETURNS boolean`** — SECURITY DEFINER, STABLE, `SET search_path = public, auth`. Checks `property_members WHERE user_id = auth.uid() AND property_id = p_property_id`. REVOKE FROM public + GRANT TO authenticated.
- **RLS on propriedades**: SELECT TO authenticated USING `is_member_of(id)`
- **RLS on property_members**: SELECT TO authenticated USING `user_id = auth.uid()`
- No INSERT/UPDATE/DELETE policies in Phase 1 (only service_role/seed can write)

### Seed: `supabase/seed.sql`

Deterministic test fixtures for cross-tenant isolation testing:

| Entity | ID | Value |
|--------|----|-------|
| Fazenda Alpha | `aaaaaaaa-0000-0000-0000-000000000001` | property |
| Fazenda Beta | `bbbbbbbb-0000-0000-0000-000000000002` | property |
| userA | `aaaa1111-0000-0000-0000-000000000001` | `userA@test.com` / `senha123A` |
| userB | `bbbb2222-0000-0000-0000-000000000002` | `userB@test.com` / `senha123B` |
| membership A→Alpha | proprietario | disjoint |
| membership B→Beta | proprietario | disjoint |

- Passwords hashed with `crypt('senha123A', gen_salt('bf'))` — bcrypt cost 10
- `auth.identities` rows inserted for GoTrue email/password login compatibility
- All inserts idempotent via `ON CONFLICT DO NOTHING`

### Config: `supabase/config.toml`

```toml
additional_redirect_urls = ["https://127.0.0.1:3000", "http://127.0.0.1:3000", "http://localhost:3000"]
```

Prevents `redirect_uri_mismatch` when Flutter web (`flutter run -d edge`) serves on plain http port 3000.

### Wave 0 Test Stubs (RED state)

| File | Status | Gate |
|------|--------|------|
| `test/features/auth/auth_repository_test.dart` | Fails to compile | `lib/features/auth/data/auth_repository.dart` (Plan 02) |
| `test/features/auth/property_repository_test.dart` | Fails to compile | `lib/features/auth/data/property_repository.dart` (Plan 02) |
| `test/features/auth/login_screen_test.dart` | Fails to compile | `lib/features/auth/presentation/login_screen.dart` (Plan 03) |
| `integration_test/rls_isolation_test.dart` | Compiles, skipped | Requires `supabase db reset` + local Supabase running |

## Schema Applied to Local DB

`supabase db reset` run from the worktree directory confirmed:

- Migration `20260504_01_auth_multitenancy.sql` applied
- Seed `supabase/seed.sql` applied
- Verified: `propriedades` table exists, `property_members` table exists
- Verified: `userA@test.com` and `userB@test.com` in `auth.users`
- Verified: `count(*) FROM property_members` = 2
- Verified: `is_member_of` in `pg_proc`

## Decisions Made

1. **SECURITY DEFINER with SET search_path** — Required by T-01-02 threat. Prevents a schema-shadow attack where a malicious schema named `auth` is placed ahead of the real one in the search path.

2. **FORCE ROW LEVEL SECURITY** — Applied to both tables. Ensures RLS applies even to the table owner (postgres) when called from application context, preventing accidental superuser bypass.

3. **No write policies in Phase 1** — INSERT/UPDATE/DELETE for propriedades and property_members intentionally omitted. Only seed/service_role can write. Phase 2 (PROP-01) adds owner-write policy for propriedades.

4. **Wave 0 RED stubs compile-fail by design** — Stubs reference `AuthRepository`, `PropertyRepository`, and `LoginScreen` which don't exist yet. This is intentional — when Plans 02/03 create those production files, the tests compile and should pass.

5. **Supabase CLI from worktree** — The `supabase db reset` must be run from the worktree directory (not the main repo root) so the CLI finds `supabase/migrations/` and `supabase/seed.sql`.

## Deviations from Plan

### Auto-fixed Issues

None.

### Operational Notes

1. **Worktree branch rebase** — The worktree was created from commit `4262be2` (older than target `1cf012c`). Applied `git reset --soft 1cf012c` + `git checkout HEAD -- .` to bring the working tree to the correct base before starting work. Not a deviation — standard worktree setup correction per instructions.

2. **`supabase db execute --local` unavailable** — CLI v2.95.4 uses `supabase db query` instead of `supabase db execute --local`. Used `supabase db query` for verification queries. All queries returned expected results.

3. **Docker startup** — Docker Desktop was not running at plan start. Started it automatically. Supabase local stack was already running once Docker was available.

## Phase 0 Test Suite Status

`flutter test test/core/ test/widget/` — **8/8 tests PASSED** (no regressions from this plan's changes).

## Known Stubs

None — all files are either complete DDL artifacts or intentional RED test stubs (the RED state is the goal for Wave 0, not a deficiency).

## Threat Flags

No new security-relevant surface beyond what is documented in the plan's threat model. The migration introduces the propriedades and property_members tables with RLS enforced — this is the planned trust boundary. No new network endpoints or auth paths were added.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | `28d8148` | feat(01-01): create auth multi-tenancy migration |
| Task 2 | `bd36a51` | feat(01-01): add deterministic test seed for auth multi-tenancy |
| Task 3 | `de24ffd` | chore(01-01): add http redirect URLs to supabase config.toml |
| Task 4 | `df33711` | test(01-01): add Wave 0 RED test stubs for auth, property, login and RLS |
| Task 5 | (no files) | supabase db reset applied — schema + seed live in local Postgres |

## Self-Check: PASSED

- [x] `supabase/migrations/20260504_01_auth_multitenancy.sql` exists
- [x] `supabase/seed.sql` exists
- [x] `supabase/config.toml` contains all 3 redirect URLs
- [x] `test/features/auth/auth_repository_test.dart` exists
- [x] `test/features/auth/property_repository_test.dart` exists
- [x] `test/features/auth/login_screen_test.dart` exists
- [x] `integration_test/rls_isolation_test.dart` exists
- [x] Commits 28d8148, bd36a51, de24ffd, df33711 verified in git log
- [x] DB: propriedades and property_members tables confirmed
- [x] DB: userA@test.com and userB@test.com confirmed
- [x] DB: property_members count = 2
- [x] DB: is_member_of function confirmed
- [x] Phase 0 test suite: 8/8 PASSED
