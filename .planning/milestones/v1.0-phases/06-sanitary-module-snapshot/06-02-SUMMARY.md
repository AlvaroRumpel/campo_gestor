---
phase: 06-sanitary-module-snapshot
plan: 02
subsystem: database
tags: [postgres, supabase, rls, security-definer, jsonb, plpgsql]

# Dependency graph
requires:
  - phase: 02-property-paddock-structure
    provides: sanitary_applications skeleton (id, composition_snapshot jsonb, created_at) + trg_snapshot_immutable
  - phase: 05-reproductive-module-loteatf
    provides: is_member_of()/get_role() RPC pattern, isolation-trigger idiom, SECURITY DEFINER footer convention
provides:
  - doses table (property-scoped RLS CRUD, soft delete)
  - properties.kg_per_ua column (D-12)
  - animal_ua_weight() SQL helper mirroring Dart kUaWeights
  - sanitary_applications header columns, indexes, one SELECT policy, isolation trigger
  - register_sanitary_application() and reverse_sanitary_application() SECURITY DEFINER RPCs
affects: [06-03, 06-04, 06-05, 06-06, 06-07, 06-08, 06-09, 06-10, 06-11, 06-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SECURITY DEFINER RPC as sole write surface for an immutable-snapshot table, zero write RLS policies (mirrors register_baixa/add_animals_to_atf)"
    - "Access-path-independent BEFORE INSERT isolation trigger, separate concern from RPC role/membership checks"
    - "Partial unique index as the real concurrency guarantee, RPC pre-check only for a legible error"
    - "GIN jsonb_path_ops containment index for per-element array lookup"

key-files:
  created:
    - supabase/migrations/20260810_06_sanitary_module.sql
    - supabase/migrations/20260811_06_sanitary_rpcs.sql
  modified: []

key-decisions:
  - "Both migrations authored on disk only — not applied to any database. 06-12 owns the push per the plan's critical_scope_note."
  - "sanitary_applications extended via ALTER TABLE only, never dropped/recreated — Phase 2's trg_snapshot_immutable and composition_snapshot column survive untouched."
  - "Reversal sign convention locked per 06-VALIDATION.md: negate all four numeric totals (animal_count, total_ua, total_volume, total_cost), leave composition_snapshot un-negated, set applied_at = current_date on the reversal row."

patterns-established:
  - "animal_ua_weight() is the single Postgres source of truth mirroring lib/features/animais/data/animal_constants.dart's kUaWeights — a pre-existing Dart/Postgres duplication documented with a two-place-edit warning comment, not newly introduced by this phase."

requirements-completed: [SANI-01, SANI-02, SANI-03, SANI-04, SANI-05]

coverage:
  - id: D1
    description: "doses table with dosage_per_kg required, cost_per_kg nullable, property-scoped RLS CRUD, soft delete"
    requirement: "SANI-01"
    verification:
      - kind: other
        ref: "node structural gate (06-02-PLAN.md Task 1 <verify>) — schema migration OK"
        status: pass
    human_judgment: true
    rationale: "Structural gate confirms the DDL exists on disk with required clauses; actual RLS/constraint behavior can only be proven once the migration is applied and pgTAP runs in the 06-12 blocking wave."
  - id: D2
    description: "properties.kg_per_ua numeric NOT NULL DEFAULT 400 with positive check, no UI this phase"
    requirement: "SANI-01"
    verification:
      - kind: other
        ref: "node structural gate (06-02-PLAN.md Task 1 <verify>) — schema migration OK"
        status: pass
    human_judgment: false
  - id: D3
    description: "register_sanitary_application recomputes total_ua/total_volume/total_cost/dosage_per_ua/cost_per_ua server-side; client submits no numeric total"
    requirement: "SANI-02"
    verification:
      - kind: other
        ref: "node structural gate (06-02-PLAN.md Task 2 <verify>) — rpc migration OK"
        status: pass
    human_judgment: true
    rationale: "Static gate confirms the function shape and ERRCODEs on disk; correctness of the computed totals against real animal/dose/property rows requires the pgTAP suite in the 06-12 blocking wave."
  - id: D4
    description: "D-32 concurrency abort — mismatched animal selection raises P0002 and aborts the whole transaction"
    requirement: "SANI-03"
    verification:
      - kind: other
        ref: "node structural gate (06-02-PLAN.md Task 2 <verify>) — rpc migration OK"
        status: pass
    human_judgment: true
    rationale: "Requires a live transaction race (soft-delete between load and confirm) to prove — scheduled as a pgTAP assertion in the 06-12 blocking wave, not executable from disk alone."
  - id: D5
    description: "reverse_sanitary_application blocks reversal-of-reversal (23514), blank reason (22023), and double reversal via unique index + P0003 pre-check"
    requirement: "SANI-02"
    verification:
      - kind: other
        ref: "node structural gate (06-02-PLAN.md Task 2 <verify>) — rpc migration OK"
        status: pass
    human_judgment: true
    rationale: "Concurrency/uniqueness guarantees require the unique index enforced by a live database; deferred to the 06-12 pgTAP wave."
  - id: D6
    description: "sanitary_applications_composition_gin_idx (jsonb_path_ops) accelerates the SANI-05 per-animal containment lookup"
    requirement: "SANI-05"
    verification:
      - kind: other
        ref: "grep -n \"USING GIN (composition_snapshot jsonb_path_ops)\" supabase/migrations/20260810_06_sanitary_module.sql"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-08-06
status: complete
---

# Phase 6 Plan 02: Sanitary Module Schema + RPC Migrations Summary

**Authored both Phase 6 migrations on disk — `doses` cadastro, the ALTER-only `sanitary_applications` header extension with `properties.kg_per_ua`, GIN/reversal indexes, isolation trigger, plus `register_sanitary_application`/`reverse_sanitary_application` SECURITY DEFINER RPCs — neither applied to any database.**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2 completed
- **Files modified:** 2 (both new)

## Accomplishments
- `supabase/migrations/20260810_06_sanitary_module.sql`: `doses` table (property-scoped RLS CRUD, soft delete), `properties.kg_per_ua`, `animal_ua_weight()` helper, ALTER-only extension of the Phase 2 `sanitary_applications` skeleton (18 new columns), 5 new indexes (including the D-31 reversal partial-unique index and the D-38 GIN containment index), one SELECT-only RLS policy, and the D-10 cross-table isolation trigger.
- `supabase/migrations/20260811_06_sanitary_rpcs.sql`: `register_sanitary_application` (server-authoritative totals, D-32 concurrency-abort revalidation, payload dedup) and `reverse_sanitary_application` (D-30 reversal-of-reversal block, D-31 pre-check, locked sign convention).
- Both node structural gates pass; all plan-level acceptance criteria (policy count, index shapes, UA weight table, unedited Phase 2 file, REVOKE/GRANT counts) verified directly.

## Task Commits

Each task was committed atomically:

1. **Task 1: Schema migration — doses, sanitary_applications header, kg_per_ua, indexes, policies, isolation trigger, UA helper** - `d263fa8` (feat)
2. **Task 2: RPC migration — register_sanitary_application and reverse_sanitary_application** - `aa411c3` (feat)

## Files Created/Modified
- `supabase/migrations/20260810_06_sanitary_module.sql` - schema migration: doses, properties.kg_per_ua, animal_ua_weight(), sanitary_applications header extension, indexes, RLS policy, isolation trigger
- `supabase/migrations/20260811_06_sanitary_rpcs.sql` - RPC migration: register_sanitary_application, reverse_sanitary_application

## Decisions Made
- Followed 06-RESEARCH.md § Code Examples §1–§5 verbatim for DDL/RPC shape — no deviation from the ready-to-use drafts.
- Applied the 06-VALIDATION.md § Locked Convention for the reversal sign rule (negate all four totals, `applied_at = current_date`, `composition_snapshot` unchanged) rather than re-deriving it.
- 06-PATTERNS.md was listed in this plan's `<execution_context>` but does not exist in this worktree (likely produced by a sibling Wave-1 plan in a parallel worktree not yet merged). Proceeded using 06-RESEARCH.md and 06-CONTEXT.md, which contain the complete concrete SQL drafts and locked decisions this task needed — no gap in coverage resulted.

## Deviations from Plan

None - plan executed exactly as written. Both node verification gates and all acceptance criteria in 06-02-PLAN.md passed without modification.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Both migration files are authored on disk only; applying them to the live Supabase project (`wrdwzychjhlpwpivfhhq`) is explicitly out of scope for this plan and is owned by the blocking plan 06-12.

## Next Phase Readiness
- Both migration files exist on disk, are internally consistent with each other (RPCs reference exactly the columns/functions Task 1 created), and are ready for 06-12 to apply via MCP `apply_migration` and run the `06_sanitary_test.sql` pgTAP suite.
- No DDL was applied to any live database in this plan — `flutter analyze`/`flutter test` will not exercise these RPCs until 06-12 runs, which is the intended split (06-RESEARCH.md Environment Availability).
- Downstream Dart plans (06-03 onward) can safely reference the exact column/function names and ERRCODEs (`P0002`, `P0003`, `42501`, `22023`, `23514`, `23503`) established here for `SanitaryApplicationException.fromPostgrest`.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*
