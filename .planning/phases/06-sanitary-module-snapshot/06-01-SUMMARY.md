---
phase: 06-sanitary-module-snapshot
plan: 01
subsystem: testing
tags: [flutter_test, pgtap, tdd, dart, postgres, intl]

# Dependency graph
requires:
  - phase: 05-reproductive-module
    provides: kUaWeights UA-weight table (lib/features/animais/data/animal_constants.dart), the pgTAP + set_config role-impersonation test idiom (05_reproductive_test.sql)
provides:
  - "sanitary_calculations.dart — 8 pure Dart functions Phase 6's widgets/RPC-preview fields will call"
  - "supabase/tests/06_sanitary_test.sql — the full Wave 0 pgTAP contract 06-12 replays against the live migration"
affects: [06-02 (schema/RPC migration must match every object name this suite asserts), 06-03..06-11 (Dart data/presentation layers import sanitary_calculations.dart), 06-12 (blocking wave that finally executes this pgTAP suite)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-calculation module with zero flutter/material.dart or supabase_flutter import (D-40) — flutter_test runs it with no widget/network setup"
    - "pgTAP has_index() two-argument form + pg_indexes.indexdef like() assertion for partial-predicate/operator-class checks, avoiding the ambiguous three-argument has_index() overload"

key-files:
  created:
    - lib/features/sanitario/data/sanitary_calculations.dart
    - test/features/sanitario/dose_calculations_test.dart
    - test/features/sanitario/sanitary_calculations_test.dart
    - supabase/tests/06_sanitary_test.sql
  modified: []

key-decisions:
  - "formatCurrencyBrl concatenates an explicit 'R$ ' symbol with a pattern-formatted NumberFormat('#,##0.00','pt_BR') rather than NumberFormat.currency, per the plan's exact-string-vs-non-breaking-space rationale"
  - "Immutability fixture row in the pgTAP suite lives in Lot A2 (not Lot A1/Dose A) so it never collides with the totals/reversal section's lot_id+dose_id+reverses_application_id IS NULL uniqueness assumption"
  - "GIN containment test reuses one of the registration-set animals (moved to Lot A2 after freeze) instead of a fresh fixture, since the frozen application row already exists from the role/tenancy happy-path call"

patterns-established:
  - "Pattern: total_x helpers take totalUa (already summed) rather than re-deriving it, so callers compute totalUaForCategories once and pass it into totalVolumeMl/totalCost — avoids double iteration over the animal list"

requirements-completed: [SANI-01, SANI-02, SANI-03, SANI-04, SANI-05]

coverage:
  - id: D1
    description: "Pure sanitary calculation module (dosagePerUa, costPerUa, totalUaForCategories, totalVolumeMl, totalCost, formatUa, formatVolumeMl, formatCurrencyBrl) with two Dart test files covering all 12 documented behaviors"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "test/features/sanitario/dose_calculations_test.dart"
        status: pass
      - kind: unit
        ref: "test/features/sanitario/sanitary_calculations_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Wave 0 pgTAP suite (74 assertions) encoding every database-only guarantee in 06-VALIDATION.md's Per-Task Verification Map — schema shape, animal_ua_weight, immutability, write surface, indexes, role/tenancy rejection, server-authoritative totals, concurrency abort, reversal lifecycle, reversal zero-sum, GIN containment"
    requirement: "SANI-02"
    verification: []
    human_judgment: true
    rationale: "Suite is deliberately NOT executed this plan (D-39/D-41) — it cannot pass until 06-12 applies the migration authored in 06-02. Structural correctness was verified via the plan's node gate (plan()/finish()/rollback present, 74 assertions >= 25 minimum, both has_index() calls use exactly 2 arguments, all 7 required object names and all 6 required SQLSTATEs present) but the SQL itself has not run against Postgres."

# Metrics
duration: 45min
completed: 2026-08-06
status: complete
---

# Phase 6 Plan 1: Wave 0 Validation Surface Summary

**Pure Dart UA/dose calculation module with 15 passing unit tests, plus a 74-assertion pgTAP suite (deliberately unexecuted, Wave 0 red) encoding every database guarantee the Phase 6 migration must satisfy**

## Performance

- **Duration:** 45 min
- **Started:** 2026-08-06T00:00:00Z (approx, worktree session)
- **Completed:** 2026-08-06
- **Tasks:** 2
- **Files modified:** 4 (3 created Dart, 1 created SQL)

## Accomplishments
- `lib/features/sanitario/data/sanitary_calculations.dart` — 8 dependency-free pure functions (dose conversion, UA/volume/cost totals, pt-BR display formatting) that every later Phase 6 widget and RPC-preview field will call
- `test/features/sanitario/dose_calculations_test.dart` + `sanitary_calculations_test.dart` — 15 passing tests (RED confirmed before the module existed, GREEN after), `flutter analyze` clean
- `supabase/tests/06_sanitary_test.sql` — full Wave 0 pgTAP contract (74 assertions) covering schema shape, the `animal_ua_weight` server-side UA table, immutability, write-surface lockdown, reversal/GIN indexes, role/tenancy rejection, server-authoritative totals, D-32 concurrency abort, D-27..D-31 reversal lifecycle, the locked zero-sum convention, and D-38 GIN containment — structurally validated via the plan's node gate, intentionally left unexecuted until 06-12

## Task Commits

Each task was committed atomically (Task 1 followed TDD RED → GREEN):

1. **Task 1a (RED): failing tests for sanitary calculation helpers** - `4b6d89c` (test)
2. **Task 1b (GREEN): implement pure sanitary calculation helpers** - `71ca0e1` (feat)
3. **Task 2: Wave 0 pgTAP suite for Phase 6 database guarantees** - `63452fe` (test)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

_Note: Task 1 is `tdd="true"`; no REFACTOR commit was needed — the GREEN implementation was already clean (`flutter analyze` reported zero issues on first pass)._

## Files Created/Modified
- `lib/features/sanitario/data/sanitary_calculations.dart` - 8 pure functions: dosagePerUa, costPerUa, totalUaForCategories, totalVolumeMl, totalCost, formatUa, formatVolumeMl, formatCurrencyBrl
- `test/features/sanitario/dose_calculations_test.dart` - 6 tests, SANI-01 dose conversion + currency formatting
- `test/features/sanitario/sanitary_calculations_test.dart` - 9 tests, SANI-02/03 UA/volume/cost totals + display formatting
- `supabase/tests/06_sanitary_test.sql` - 74-assertion pgTAP suite (unexecuted, Wave 0 red by design)

## Decisions Made
- `formatCurrencyBrl` builds the string as `'R\$ ' + NumberFormat('#,##0.00','pt_BR').format(value)` instead of `NumberFormat.currency`, per the plan's explicit rationale (currency constructor's non-breaking space would make exact-string assertions environment-dependent)
- pgTAP suite structured with the immutability fixture row in a *different* lot (Lot A2) from the RPC-registration flow's lot (Lot A1), so every totals/reversal-section subquery filtered by `lot_id + dose_id + reverses_application_id IS NULL` deterministically resolves to exactly one row
- `plan(74)` set to the exact count of pgTAP-test-producing `SELECT` statements written (73 caught by the plan's own regex-based node gate + 1 `has_trigger` call the gate's pattern doesn't enumerate but which still consumes a pgTAP test slot)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ran `dart run build_runner build` — freezed/json_serializable generated files were missing**
- **Found during:** Task 1 (running `flutter test test/features/sanitario/` for the GREEN phase)
- **Issue:** `lib/features/animais/data/animal_model.dart` (a transitive import via `animal_constants.dart`) references `part 'animal_model.freezed.dart'` and `part 'animal_model.g.dart'`, neither of which existed on disk in this fresh worktree checkout (both are gitignored generated files) — every test run failed at compile time with "Type '_$Animal' not found"
- **Fix:** Ran `dart run build_runner build` (18 outputs generated across the codebase's freezed/riverpod/json_serializable models); this is a pre-existing codebase-wide build step, not specific to this plan's new files
- **Files modified:** none tracked (generated `.freezed.dart`/`.g.dart` files are `.gitignore`d, confirmed via `.gitignore` lines 54-55)
- **Verification:** `flutter test test/features/sanitario/` passed 15/15 after the build; `flutter analyze` clean
- **Committed in:** not committed (gitignored build artifacts, correctly excluded)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to run any Dart test in this worktree at all — unrelated to this plan's own code, no scope creep.

## Issues Encountered
None beyond the build_runner gap above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `sanitary_calculations.dart`'s 8 functions are ready for 06-03's `DoseFormDialog` live preview and 06-08's `ResumoAplicacaoDialog` totals to import directly — no further scaffolding needed
- `06_sanitary_test.sql` is structurally complete and object-name-locked against `06-RESEARCH.md`'s exact schema; 06-02 must create every object this suite names verbatim (`doses`, `animal_ua_weight`, `register_sanitary_application`, `reverse_sanitary_application`, `sanitary_applications_reversal_idx`, `sanitary_applications_composition_gin_idx`, `trg_sanitary_applications_same_property`) or the suite will fail for a naming reason rather than a logic reason when 06-12 finally runs it
- `sanitary_calculations_test.dart` has an explicit placeholder comment marking where 06-04 appends reversal-visibility/ordering test cases once `SanitaryApplication` exists — no empty group was stubbed (D-40 compliance)

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*

## Self-Check: PASSED

All created files verified present on disk (`sanitary_calculations.dart`, `dose_calculations_test.dart`, `sanitary_calculations_test.dart`, `06_sanitary_test.sql`, this SUMMARY). All four commit hashes (`4b6d89c`, `71ca0e1`, `63452fe`, `8e8224d`) verified present in `git log --oneline --all`.
