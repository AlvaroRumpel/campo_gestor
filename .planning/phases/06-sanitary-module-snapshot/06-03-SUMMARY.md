---
phase: 06-sanitary-module-snapshot
plan: 03
subsystem: database
tags: [flutter, riverpod, freezed, json_serializable, supabase, dart]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-01)
    provides: sanitary_calculations.dart pure functions the DoseFormDialog (06-06) will call for live preview
  - phase: 06-sanitary-module-snapshot (06-02)
    provides: doses table DDL + RLS policies, properties.kg_per_ua column, the schema this plan types against
provides:
  - "Dose freezed model (id, propertyId, name, activeIngredient?, dosagePerKg, costPerKg?, createdAt, deletedAt?) with isArchived and displayLabel getters"
  - "Property.kgPerUa @Default(400) field for client-side live UA preview (D-12)"
  - "DoseRepository: fetchDosesByProperty (includeArchived toggle), fetchDose, createDose, updateDose, archiveDose, restoreDose — direct RLS CRUD, no RPC"
  - "doseRepositoryProvider, doseListByPropertyProvider, archivedDoseListByPropertyProvider"
affects: [06-06 (DoseFormDialog reads Property.kgPerUa and the two dose list providers), 06-10 (Sanitario screen dose list/archive toggle)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dose CRUD copies lote_repository.dart's direct-RLS shape 1:1 (fetch/fetchOne/create/update/soft-delete), no RPC — single-row single-entity writes are fully covered by RLS WITH CHECK"
    - "Two sibling FutureProviders (active/archived) instead of a family+bool param, so the 'Mostrar arquivadas' toggle is a pure provider swap"

key-files:
  created:
    - lib/features/sanitario/data/dose_model.dart
    - lib/features/sanitario/data/dose_repository.dart
  modified:
    - lib/features/propriedades/data/propriedade_model.dart

key-decisions:
  - "isArchived and displayLabel live as getters on Dose via a freezed private constructor (const Dose._();) rather than duplicated in two widgets, per the plan's explicit rationale"
  - "createDose/updateDose trim name and activeIngredient and coerce a blank activeIngredient to null — never an empty string — preserving the nullable-cost/nullable-ingredient semantics all the way to the write"

patterns-established: []

requirements-completed: [SANI-01]

coverage:
  - id: D1
    description: "Dose freezed model with nullable costPerKg/activeIngredient, numeric fields deserializing via num.toDouble(), isArchived/displayLabel getters"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/data/dose_model.dart — no issues"
        status: pass
      - kind: other
        ref: "grep -n toDouble lib/features/sanitario/data/dose_model.g.dart — matches dosage_per_kg and cost_per_kg"
        status: pass
    human_judgment: false
  - id: D2
    description: "Property.kgPerUa @Default(400) added without reordering/renaming existing fields"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "flutter test test/features/propriedades/ — 3 passed"
        status: pass
      - kind: other
        ref: "grep -n kg_per_ua lib/features/propriedades/data/propriedade_model.g.dart — fallback to 400 when key absent"
        status: pass
    human_judgment: false
  - id: D3
    description: "DoseRepository CRUD (fetchDosesByProperty w/ includeArchived toggle, fetchDose, createDose, updateDose, archiveDose, restoreDose) reaching Supabase only through SupabaseService, no direct supabase_flutter import, no .delete() call"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ — no issues"
        status: pass
      - kind: other
        ref: "node structural gate (06-03-PLAN.md Task 2 <verify>) — prints 'dose repository OK'"
        status: pass
    human_judgment: true
    rationale: "Structural/static gates confirm the method surface and import boundary on disk; actual RLS-gated read/write behavior against the doses table can only be proven once the 06-02 migration is applied by 06-12."

# Metrics
duration: 18min
completed: 2026-08-07
status: complete
---

# Phase 6 Plan 03: Dose Data Layer + Property.kgPerUa Summary

**Freezed `Dose` model with never-defaulted nullable cost, plus a direct-RLS `DoseRepository` (fetch/create/update/archive/restore) and its three Riverpod providers, mirroring the existing `lote_repository.dart` CRUD shape**

## Performance

- **Duration:** ~18 min
- **Tasks:** 2 completed
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments
- `lib/features/sanitario/data/dose_model.dart`: freezed sealed class `Dose` with nullable `activeIngredient`/`costPerKg`, `isArchived` and `displayLabel` getters, snake_case JSON via `json_serializable`'s `num.toDouble()` conversion path.
- `lib/features/propriedades/data/propriedade_model.dart`: extended with `@Default(400) double kgPerUa` (D-12), existing fields untouched.
- `lib/features/sanitario/data/dose_repository.dart`: `DoseRepository` with six methods against the `doses` table endpoint (no RPC), plus `doseRepositoryProvider`, `doseListByPropertyProvider`, `archivedDoseListByPropertyProvider`.
- Codegen regenerated (`dose_model.freezed.dart`, `dose_model.g.dart`, `propriedade_model` parts); both node structural gates and all acceptance criteria pass; `flutter analyze` clean on both changed/new files and on `lib/features/sanitario/`; full-repo `flutter test` (242 tests) and full-repo `flutter analyze` show no new issues.

## Task Commits

Each task was committed atomically:

1. **Task 1: Dose freezed model + Property.kgPerUa + codegen** - `e9fcd67` (feat)
2. **Task 2: DoseRepository + Riverpod providers** - `f02c784` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified
- `lib/features/sanitario/data/dose_model.dart` - `Dose` freezed model, `isArchived`/`displayLabel` getters
- `lib/features/sanitario/data/dose_repository.dart` - `DoseRepository` CRUD + three providers
- `lib/features/propriedades/data/propriedade_model.dart` - added `kgPerUa` field (D-12)

## Decisions Made
- Used a freezed private constructor (`const Dose._();`) to attach `isArchived`/`displayLabel` getters directly on the model, per the plan's explicit "belongs on the model rather than duplicated in two widgets" instruction — no precedent for this exact idiom existed elsewhere in the codebase's freezed models, but it is the standard freezed pattern for adding methods to a sealed factory class.
- `createDose`/`updateDose` trim `name`/`activeIngredient` and send `null` (not `''`) for a blank ingredient, matching the plan's nullable-column semantics exactly.

## Deviations from Plan

None - plan executed exactly as written. Both node/grep structural gates and all acceptance criteria in 06-03-PLAN.md passed without modification.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. This plan only adds Dart client code; the schema it types against (`supabase/migrations/20260810_06_sanitary_module.sql`) was authored in 06-02 and is still unapplied to any database, owned by 06-12.

## Next Phase Readiness
- `Dose`, `DoseRepository`, and all three providers are ready for 06-06's `DoseFormDialog` and 06-10's `SanitarioScreen` dose list/archive toggle to consume directly.
- `Property.kgPerUa` is ready for 06-06's live "Dosagem por UA (calculado)" preview field.
- No DDL was applied to any live database in this plan — dose CRUD will not be exercisable against real Supabase rows until 06-12 applies the 06-02 migration; `flutter analyze`/`flutter test` do not exercise network calls, consistent with the split established in 06-01/06-02.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-07*
