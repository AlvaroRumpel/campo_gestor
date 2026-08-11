---
phase: 08-animal-dossier-consolidation
plan: 01
subsystem: database
tags: [flutter, riverpod, supabase, postgrest, dart]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf
    provides: atf_batches, dg_records, isLaterDg ordering rule
  - phase: 02-property-paddock-structure
    provides: lots/paddocks tables and RLS
provides:
  - "LoteRepository.fetchLotWithPaddockName + loteWithPaddockByIdProvider — single-query lot+paddock read"
  - "ReproductiveHistoryEntry.dgRecords/bullName/implantationDate — full per-ATF DG list, sourced from the existing query"
affects: [08-04, 08-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Plain wrapper class (not @freezed) for PostgREST embedded-select results — LotWithPaddockName mirrors LotWithPaddockCount/AtfMembershipView"
    - "Additive in-memory grouping pass over an already-fetched list (dgsByAtf) instead of a second query"
    - "Reuse isLaterDg as a sort comparator instead of re-deriving the examDate/createdAt tie-break rule"

key-files:
  created: []
  modified:
    - lib/features/lotes/data/lote_repository.dart
    - lib/features/reproducao/data/atf_model.dart
    - lib/features/reproducao/data/atf_repository.dart
    - test/features/lotes/lote_repository_test.dart
    - test/features/reproducao/atf_repository_test.dart
    - test/widget/animal_detail_screen_test.dart
    - test/widget/lote_form_dialog_test.dart

key-decisions:
  - "LotWithPaddockName is a plain const-constructor class, not @freezed — matches the project's existing convention for embedded-select wrapper types"
  - "loteWithPaddockByIdProvider is a plain FutureProvider.family with no keepAlive, per D-03 — reopening the ficha always refetches"
  - "dgRecords sort uses a two-call isLaterDg comparator (never a hand-written examDate comparison) to keep the DG ordering rule in the single canonical location (G-05-4)"

patterns-established:
  - "New embedded-select repository reads should add a provider next to the existing family, never replace it, when other screens still consume the original single-entity provider"

requirements-completed: [ANIM-03]

coverage:
  - id: D1
    description: "LoteRepository.fetchLotWithPaddockName + loteWithPaddockByIdProvider resolve lot and paddock name in one PostgREST embedded select, with the old loteByIdProvider left intact for its existing consumers"
    requirement: "ANIM-03"
    verification:
      - kind: unit
        ref: "test/features/lotes/lote_repository_test.dart#fetchLotWithPaddockName exists and is callable (D-01 contract)"
        status: pass
    human_judgment: false
  - id: D2
    description: "ReproductiveHistoryEntry carries the full ordered dgRecords list per ATF plus bullName/implantationDate, with lastDgResult/lastDgDate summary unchanged, sourced from the existing fetchReproductiveHistory query with zero extra requests"
    requirement: "ANIM-03"
    verification:
      - kind: unit
        ref: "test/features/reproducao/atf_repository_test.dart#fetchReproductiveHistory exists and is callable (REPR-05, D-09/D-10)"
        status: pass
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart#populated: renders one row per entry, in the order supplied (insemination date descending)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-11
status: complete
---

# Phase 8 Plan 1: Data-Layer Closure for Ficha Consolidada Summary

**Single-query lot+paddock read via `LotWithPaddockName`, and full per-ATF DG history (with bull name / implantation date) added to `fetchReproductiveHistory` — both additive, zero new requests, no screens touched.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-11T20:55:22Z
- **Completed:** 2026-08-11T21:01:36Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Killed the lote → piquete waterfall at the data layer: `LoteRepository.fetchLotWithPaddockName` does one PostgREST embedded select (`paddocks!inner(name)`) instead of the two sequential requests `AnimalInfoCard` currently makes; exposed via a new auto-dispose `loteWithPaddockByIdProvider` family, with the old `loteByIdProvider`/`fetchLot` left untouched for `LoteDetailScreen` and the move dialog.
- `ReproductiveHistoryEntry` now carries the complete ordered DG list per ATF (`dgRecords`), the resolved bull name, and the implantation date — all read from the same `atf_batches`/`dg_records` queries `fetchReproductiveHistory` already ran, via one additive `dgsByAtf` grouping pass (`putIfAbsent`) and a per-entry sort that reuses `isLaterDg` as the comparator rather than re-deriving the ordering rule.
- `lastDgResult`/`lastDgDate` (the collapsed-row summary) are unchanged — the new list is additive, not a replacement.

## Task Commits

Each task was committed atomically:

1. **Task 1: Leitura única lote + piquete (D-01)** - `3122527` (feat)
2. **Task 2: DGs completos, touro e data de implantação no histórico reprodutivo (D-09, D-10)** - `a1a5c51` (feat)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `lib/features/lotes/data/lote_repository.dart` - new `LotWithPaddockName` wrapper class, `fetchLotWithPaddockName` method, `loteWithPaddockByIdProvider` family
- `lib/features/reproducao/data/atf_model.dart` - `ReproductiveHistoryEntry` gains `dgRecords`, `bullName`, `implantationDate`
- `lib/features/reproducao/data/atf_repository.dart` - `fetchReproductiveHistory` extends the `atf_batches` embed select and adds the `dgsByAtf` grouping + sort
- `test/features/lotes/lote_repository_test.dart` - contract test for `fetchLotWithPaddockName`
- `test/features/reproducao/atf_repository_test.dart` - updated contract-test description for D-09/D-10
- `test/widget/animal_detail_screen_test.dart` - fixtures updated with `dgRecords`/`implantationDate` for the three sample entries
- `test/widget/lote_form_dialog_test.dart` - `_FakeLoteRepository` stub override for the new interface method (see Deviations)

## Decisions Made
- None beyond what's captured in `key-decisions` above — plan's action blocks were followed as written, including the explicit warning to copy `dgsByAtf[...] ?? const []` into a growable list before sorting.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `_FakeLoteRepository` missing override for the new interface method**
- **Found during:** Task 2 verification (repo-wide `flutter analyze`, required by the plan's overall `<verification>` block)
- **Issue:** `test/widget/lote_form_dialog_test.dart` declares `class _FakeLoteRepository implements LoteRepository`. Adding a new concrete method to `LoteRepository` in Task 1 makes that `implements` clause require a matching override, or the whole test file fails to compile — a known recurring tax on `LoteRepository`'s public surface (already flagged in STATE.md from Phase 04).
- **Fix:** Added `Future<LotWithPaddockName?> fetchLotWithPaddockName(String id) async => null;` to `_FakeLoteRepository`.
- **Files modified:** test/widget/lote_form_dialog_test.dart
- **Verification:** `flutter analyze` (whole repo) returns to 4 pre-existing unrelated issues, 0 errors; `flutter test` full suite 313/313 passing.
- **Committed in:** a1a5c51 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for repo-wide `flutter analyze` to pass per the plan's own `<verification>` section. No scope creep — single-line stub addition.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 08-04 has `loteWithPaddockByIdProvider` ready to swap into `AnimalInfoCard` in place of the chained `loteByIdProvider`/`paddockByIdProvider` watches.
- Plan 08-05 has `ReproductiveHistoryEntry.dgRecords` (already sorted, already de-duplicated per animal/ATF) ready to drive the `ExpansionTile` DG expansion — no repository work remains for that plan.
- No blockers. Full test suite (313 tests) and repo-wide `flutter analyze` both green.

---
*Phase: 08-animal-dossier-consolidation*
*Completed: 2026-08-11*

## Self-Check: PASSED
All created/modified files confirmed present on disk; both task commits (3122527, a1a5c51) confirmed in git log.
