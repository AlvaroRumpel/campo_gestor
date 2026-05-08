---
phase: 02-property-paddock-structure
plan: 01
subsystem: database-schema
tags: [schema, pgtap, migrations, rls, test-stubs, wave-0]
requirements: [PROP-01, PROP-02]
dependency_graph:
  requires: [20260504_01_auth_multitenancy.sql, Phase 1 schema]
  provides: [piquetes table, animais skeleton, animais_lote_atf skeleton, aplicacoes_sanitarias skeleton, get_perfil() helper, gerar_numero_animal RPC, snapshot trigger, ATF partial unique index]
  affects: [Phase 3 data layer, Phase 5 ATF module, Phase 6 sanitary module]
tech_stack:
  added: []
  patterns: [pgTAP via supabase test db, SECURITY DEFINER helpers, advisory lock RPC, partial unique index, BEFORE trigger immutability]
key_files:
  created:
    - supabase/migrations/20260508_02_property_paddock.sql
    - supabase/tests/02_property_paddock_test.sql
    - test/features/propriedades/propriedade_repository_test.dart
    - test/features/piquetes/piquete_repository_test.dart
    - test/widget/propriedades_screen_test.dart
    - test/widget/piquetes_screen_test.dart
  modified:
    - supabase/config.toml (attempted [db.test] section, reverted — invalid key in CLI v2.95.4)
decisions:
  - supabase test db takes path arg directly in CLI v2.95.4; [db.test] config key is invalid
  - throws_ok errmsg arg must be NULL or exact match; P0001 used for RAISE EXCEPTION trigger tests
  - db push --local flag required when project is not linked to remote
metrics:
  duration: ~30min
  completed_date: 2026-05-08
  tasks_completed: 2/2 auto + 1 checkpoint reached
  files_created: 6
  files_modified: 1
---

# Phase 02 Plan 01: Wave 0 Foundation (Schema + RED Stubs) Summary

Wave 0 foundation: 4 RED Flutter test stubs for propriedades/piquetes feature modules plus the full Phase 2 schema migration with all 9 sections and a green 11-assertion pgTAP test suite applied to local Supabase.

## What Was Built

### Task 1 — Wave 0 RED Flutter Test Stubs

4 files created that fail RED with import-not-found errors because the implementations do not exist yet:

- `test/features/propriedades/propriedade_repository_test.dart` — compile-asserts `Propriedade` model (5 fields: id, nome, proprietario, createdAt, deletedAt) and `PropriedadeRepository` type exist. Turns green when Plan 02 creates them.
- `test/features/piquetes/piquete_repository_test.dart` — compile-asserts `Piquete` model (7 fields) and `PiqueteRepository` type exist. Turns green when Plan 03 creates them.
- `test/widget/propriedades_screen_test.dart` — widget stub pumps `PropriedadesScreen` with empty list override and asserts `'Nenhuma fazenda cadastrada'` and full copywriting text. Turns green when Plan 04 creates the screen.
- `test/widget/piquetes_screen_test.dart` — widget stub pumps `PiquetesScreen` with empty list override and asserts `'Nenhum piquete cadastrado'` and full copywriting text. Turns green when Plan 05 creates the screen.

### Task 2 — Phase 2 Schema Migration + pgTAP Suite

`supabase/migrations/20260508_02_property_paddock.sql` — 9 sections:

1. `ALTER TABLE propriedades` — adds `proprietario text` (D-05) and `deleted_at timestamptz` (D-11) + active partial index
2. `get_perfil(uuid)` — SECURITY DEFINER helper returning `perfil_enum` for RLS policy checks (D-08)
3. Propriedades owner-write RLS — INSERT (any authenticated), UPDATE (veterinario only via `get_perfil`)
4. `property_members` self-INSERT policy — `WITH CHECK (user_id = auth.uid())` anti-spoofing (T-02-07)
5. `piquetes` table — `area_ha numeric(8,2)`, `capacidade_ua numeric(8,2)`, `deleted_at`, RLS (members read, veterinario insert/update)
6. `animais` skeleton — id, propriedade_id, categoria, numero, deleted_at, created_at + partial unique index on (propriedade_id, numero)
7. `gerar_numero_animal(uuid, text)` RPC — PL/pgSQL with `pg_advisory_xact_lock` serializing per (propriedade, categoria) (D-20)
8. `animais_lote_atf` skeleton — partial unique index `WHERE ativo = true` on animal_id (D-22)
9. `aplicacoes_sanitarias` skeleton — `composicao_snapshot jsonb` + `BEFORE UPDATE OR DELETE` trigger raising `P0001` exception (D-21)

### Task 3 — Schema Applied + pgTAP Green

`supabase db push --local` applied migration cleanly. `supabase test db supabase/tests/02_property_paddock_test.sql` reports:

```
# Looks like you ran 11 tests
All tests successful.
Files=1, Tests=11
Result: PASS
```

11 assertions cover: 4 table existence checks, 2 column checks on propriedades, 2 function existence checks, 1 ATF unique violation (23505), 1 snapshot UPDATE block (P0001), 1 snapshot DELETE block (P0001).

## pgTAP Results

```
/_geral/Projetos/campo_gestor/.claude/worktrees/agent-ac8c2b9dc9ae6d51d/supabase/tests/02_property_paddock_test.sql .. ok
All tests successful.
Files=1, Tests=11,  0 wallclock secs
Result: PASS
```

## Manual pgbench Command for D-20 Concurrency Proof

For posterity — pgTAP runs serially so true parallel concurrency cannot be tested in a single transaction:

```bash
# Create a test propriedade_id first, then:
echo "SELECT gerar_numero_animal('<propriedade_id_here>', 'vaca');" > /tmp/g.sql
pgbench -c 10 -j 10 -t 5 -n -f /tmp/g.sql "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
```

Expected: 50 sequential integers, no duplicates in the `animais` table after using the RPC for inserts.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pgTAP `throws_ok` argument mismatch**
- **Found during:** Task 3 (pgTAP run)
- **Issue:** `throws_ok` 3-arg call treated the description string as the expected error message, causing exact-match failure. Trigger tests used partial message `'snapshot is immutable'` instead of the full `P0001` error code.
- **Fix:** Changed ATF test to `throws_ok(sql, '23505', NULL, description)` and trigger tests to `throws_ok(sql, 'P0001', NULL, description)` — checks error code only, NULL skips message matching.
- **Files modified:** `supabase/tests/02_property_paddock_test.sql`
- **Commit:** 90b3491

**2. [Rule 3 - Blocking] Reverted invalid `[db.test]` config.toml section**
- **Found during:** Task 3 (`supabase status` failed)
- **Issue:** Supabase CLI v2.95.4 does not support the `[db.test]` configuration key — `supabase status` reported `'db' has invalid keys: test`.
- **Fix:** Removed the `[db.test]` section. The CLI accepts test file paths as positional arguments: `supabase test db supabase/tests/02_property_paddock_test.sql`.
- **Files modified:** `supabase/config.toml`
- **Commit:** 90b3491

**3. [Rule 3 - Blocking] Used `--local` flag for `supabase db push`**
- **Found during:** Task 3 (`supabase db push` failed)
- **Issue:** `supabase db push` without flags requires a linked remote project (`supabase link`). Local dev needs `--local`.
- **Fix:** Used `supabase db push --local` — applies migration to local Docker Postgres.
- **No file change** — operational note for downstream agents.

## Known Stubs

The 4 Flutter test files are intentional stubs (Wave 0 RED):

| File | Stub Type | Resolved By |
|------|-----------|-------------|
| `test/features/propriedades/propriedade_repository_test.dart` | Missing implementation imports | Plan 02 |
| `test/features/piquetes/piquete_repository_test.dart` | Missing implementation imports | Plan 03 |
| `test/widget/propriedades_screen_test.dart` | Missing screen + provider imports | Plan 04 |
| `test/widget/piquetes_screen_test.dart` | Missing screen + provider imports | Plan 05 |

These are intentional — the plan's objective is RED stubs, not green tests.

## Threat Flags

No new trust boundaries introduced beyond those documented in the plan's threat model. All T-02-* mitigations from the threat register are implemented:

- T-02-01: `members_can_read_piquetes` RLS using `is_member_of`
- T-02-02: `veterinario_can_insert/update_piquete` using `get_perfil`
- T-02-03: `trg_snapshot_immutable` trigger blocks UPDATE/DELETE (pgTAP verified)
- T-02-04: `pg_advisory_xact_lock` + partial unique index on animais
- T-02-05: `animais_lote_atf_ativo_idx` partial unique index (pgTAP verified)
- T-02-06: `deleted_at` column added (repository will filter; documented)
- T-02-07: `self_insert_membership` WITH CHECK `user_id = auth.uid()`
- T-02-08: `get_perfil()` declared SECURITY DEFINER

## Self-Check: PASSED

All files verified present on disk:
- FOUND: test/features/propriedades/propriedade_repository_test.dart
- FOUND: test/features/piquetes/piquete_repository_test.dart
- FOUND: test/widget/propriedades_screen_test.dart
- FOUND: test/widget/piquetes_screen_test.dart
- FOUND: supabase/migrations/20260508_02_property_paddock.sql
- FOUND: supabase/tests/02_property_paddock_test.sql
- FOUND: .planning/phases/02-property-paddock-structure/02-01-SUMMARY.md

All commits verified in git log:
- FOUND: 6b29e4b test(02-01): add Wave 0 RED stubs for propriedades + piquetes
- FOUND: 560aac2 feat(02-01): Phase 2 schema migration + pgTAP test suite
- FOUND: 90b3491 fix(02-01): pgTAP throws_ok arg fix + revert invalid db.test config
