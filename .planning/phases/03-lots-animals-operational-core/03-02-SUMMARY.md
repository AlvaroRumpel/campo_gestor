---
phase: "03"
plan: "02"
subsystem: database
tags:
  - migration
  - rls
  - rpc
  - postgres
  - supabase
  - lots
  - animals
dependency_graph:
  requires:
    - "03-01 (Wave-0 test scaffold — parallel)"
    - "20260508_02_property_paddock.sql (animals skeleton, is_member_of, get_role)"
    - "20260504_01_auth_multitenancy.sql (role_enum, properties, property_members)"
  provides:
    - "lots table with RLS"
    - "animals full column set (lot_id, breed, body_condition, observation, baixa_reason, baixa_date)"
    - "generate_animal_number(uuid) — global per-property, advisory lock"
    - "create_lot_with_animals RPC — atomic batch with skip-active-numbers"
  affects:
    - "03-03 (Flutter data layer — LoteRepository, AnimalRepository)"
    - "03-04 (LoteDetailScreen, LoteFormDialog)"
    - "03-05 (AnimaisScreen, AnimalDetailScreen)"
tech_stack:
  added: []
  patterns:
    - "PL/pgSQL SECURITY DEFINER RPC with pg_advisory_xact_lock"
    - "jsonb_each_text for per-category iteration in batch RPC"
    - "WHILE loop skip-active-numbers for p_start_number override path"
    - "to_jsonb() for typed JSONB return from RPC"
key_files:
  created:
    - supabase/migrations/20260514_03_lots_animals.sql
  modified: []
decisions:
  - "D-05: generate_animal_number fixed to global per-property scope — removed p_category filter that conflicted with UNIQUE INDEX"
  - "D-07: Manual number override allowed; archived animal numbers reusable (UNIQUE INDEX WHERE deleted_at IS NULL)"
  - "D-08: Advisory lock pg_advisory_xact_lock(hashtextextended(property_id::text, 0)) serializes concurrent batches per property"
  - "D-09: p_start_number optional in create_lot_with_animals; skip-while-active-numbers loop handles gaps"
  - "D-12: veterinarian_can_update_active_lot only; archived lots blocked in USING clause"
  - "D-17: baixa_reason CHECK IN ('sale', 'death', 'discard') — enum as text with constraint"
metrics:
  duration_minutes: 15
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_modified: 1
---

# Phase 03 Plan 02: Phase 3 Migration — Lots, Animals, RPC Fix Summary

**One-liner:** Phase 3 DB delta delivered: `lots` table + `animals` full column extension + global-scope `generate_animal_number` RPC fix + atomic `create_lot_with_animals` batch RPC + RLS write policies, all verified via `supabase db reset` replay and local smoke probe.

## What Was Built

### Migration: `supabase/migrations/20260514_03_lots_animals.sql`

Four sections in execution order:

**1. `lots` table**
- `id`, `property_id` (FK properties), `paddock_id` (FK paddocks), `name` (NOT NULL + length check), `created_at`, `deleted_at`
- Indexes: `lots_paddock_active_idx`, `lots_property_active_idx` (both partial WHERE deleted_at IS NULL)
- RLS: ENABLE + FORCE ROW LEVEL SECURITY
- Policies: `members_can_read_lots` (SELECT), `veterinarian_can_insert_lot` (INSERT), `veterinarian_can_update_active_lot` (UPDATE — USING includes `AND deleted_at IS NULL` to block archived rows)

**2. `animals` — column extension**
- Added: `lot_id` (FK lots), `breed` (text), `body_condition` (integer CHECK 1–5), `observation` (text), `baixa_reason` (text CHECK IN sale/death/discard), `baixa_date` (date)
- Index: `animals_lot_active_idx` (partial WHERE deleted_at IS NULL)
- New RLS policies: `veterinarian_can_insert_animal` (INSERT), `veterinarian_can_update_active_animal` (UPDATE — USING includes `AND deleted_at IS NULL`)

**3. `generate_animal_number(p_property_id uuid)` — Bug Fix**
- Dropped old 2-arg signature `generate_animal_number(uuid, text)` that queried `WHERE category = p_category`
- New 1-arg function queries `MAX(number)` across all categories for the property
- Added member check (`is_member_of(p_property_id)`) as mass-assignment defense
- Advisory lock key: `hashtextextended(p_property_id::text, 0)` — property-scoped serialization

**4. `create_lot_with_animals` — Atomic Batch RPC**
- Security: checks `is_member_of` + `get_role = 'veterinarian'` before any write
- Paddock validation: checks paddock belongs to property and is not archived (T-3-06)
- Composition validation: rejects empty batches (total qty ≤ 0)
- Advisory lock: same property-scoped lock prevents concurrent duplicate number generation
- `p_start_number` optional: empty = MAX+1 globally; filled = start from given number, skip already-active numbers
- Returns: `to_jsonb(l)` of the created lot row
- Per-category iteration via `jsonb_each_text(p_category_qtys)`

## Verification Results

### supabase db reset
```
Resetting local database...
Applying migration 20260504_01_auth_multitenancy.sql... OK
Applying migration 20260508_02_property_paddock.sql... OK
Applying migration 20260509_03_create_property_rpc.sql... OK
Applying migration 20260514_03_lots_animals.sql... OK
Finished supabase db reset on branch main.
```

**Result:** Clean replay — no errors, no out-of-order dependency failures.

### supabase db push
Not applicable — no remote project linked. The local dev DB (Docker) is the target environment for MVP development. Migration applied via `supabase db reset`.

### Smoke Probe
```sql
SELECT
  EXISTS(...lots...) AS lots_exists,
  EXISTS(...animals lot_id...) AS animals_lot_id_exists,
  EXISTS(...animals baixa_reason...) AS animals_baixa_reason_exists,
  EXISTS(...create_lot_with_animals...) AS batch_rpc_exists,
  COUNT(*) AS gen_num_count  -- from pg_proc WHERE proname='generate_animal_number'
```

**Result:**
```json
{
  "lots_exists": true,
  "animals_lot_id_exists": true,
  "animals_baixa_reason_exists": true,
  "batch_rpc_exists": true,
  "gen_num_count": 1
}
```

`gen_num_count = 1` confirms only the 1-arg signature `(p_property_id uuid)` exists — the 2-arg `(uuid, text)` was dropped.

### RLS Policy Verification
```
animals: members_can_read_animals, veterinarian_can_insert_animal, veterinarian_can_update_active_animal
lots: members_can_read_lots, veterinarian_can_insert_lot, veterinarian_can_update_active_lot
```

All 6 policies confirmed present.

## Decision References

| Decision | Implementation |
|----------|----------------|
| D-05: Number unique per property (global) | `generate_animal_number` fixed — `MAX(number)` across all categories; 2-arg dropped |
| D-07: Number override + archived reuse | UNIQUE INDEX allows same number on deleted animal; RPC skip-while-active handles conflicts |
| D-08: Advisory lock per property | `pg_advisory_xact_lock(hashtextextended(property_id::text, 0))` in both RPCs |
| D-09: "Iniciar do número" optional | `p_start_number DEFAULT NULL`; WHILE loop skips active numbers on override path |
| D-12: Lot edit = name only | `veterinarian_can_update_active_lot` UPDATE policy + `deleted_at IS NULL` in USING |
| D-17: Baixa enum values | `CHECK (baixa_reason IN ('sale', 'death', 'discard'))` on animals column |

## Threat Mitigations Applied

| Threat | Mitigation | Location |
|--------|-----------|----------|
| T-3-01: Cross-tenant lot INSERT | RLS WITH CHECK is_member_of + get_role='veterinarian' | veterinarian_can_insert_lot |
| T-3-02: Mass assignment via RPC property_id | is_member_of + get_role check at RPC start, ERRCODE 42501 | create_lot_with_animals body |
| T-3-03: Duplicate number conflict | UNIQUE INDEX animals_property_number_idx enforces at DB | Phase 2 index (unchanged) |
| T-3-04: Partial batch failure orphan | Single implicit transaction — RAISE rolls back lot + all animals | create_lot_with_animals |
| T-3-05: Update archived animal | USING includes `AND deleted_at IS NULL` on UPDATE policies | Both lots and animals |
| T-3-06: Cross-property paddock | EXISTS check in RPC before INSERT | create_lot_with_animals |
| T-3-07: Read other property's data | members_can_read_lots + members_can_read_animals SELECT policies | Both tables |
| T-3-08: Concurrent batch race | pg_advisory_xact_lock serializes per property | Both RPCs |

## Deviations from Plan

None — plan executed exactly as written. The only note is that `supabase db push` was skipped because no remote project is linked (local Docker is the dev target). This was anticipated by the plan's fallback condition.

## Known Stubs

None — this plan delivers only database schema/RPC. No Flutter stubs.

## Self-Check: PASSED

- [x] `supabase/migrations/20260514_03_lots_animals.sql` exists
- [x] `supabase db reset` replayed cleanly
- [x] Smoke probe: all 5 columns/objects confirmed present
- [x] `gen_num_count = 1` (old 2-arg signature dropped)
- [x] 6 RLS policies confirmed on lots + animals
- [x] Commit `e980795` exists in git log
---
*Plan: 03-02 | Phase: 03-lots-animals-operational-core | Completed: 2026-05-14*
