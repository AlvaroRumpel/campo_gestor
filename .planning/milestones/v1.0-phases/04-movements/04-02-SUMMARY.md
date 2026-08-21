---
phase: 04-movements
plan: 02
subsystem: ui
tags: [flutter, riverpod, dialog, movements, postgrest]

requires:
  - phase: 04-movements
    provides: "Wave 0 red test scaffolds (animal_repository_test.dart, mover_animal_dialog_test.dart, animal_detail_screen_test.dart) gating this plan's implementation"
provides:
  - "AnimalRepository.moveAnimal — single UPDATE lot_id, no RPC"
  - "LoteRepository.fetchLotsWithCountByProperty + LotWithPaddockCount DTO"
  - "loteListByPropertyProvider — active-property lot list for the move picker"
  - "MoverAnimalDialog widget (480w, 320h picker, excludes current lot)"
  - "'Mover animal' OutlinedButton.icon on AnimalDetailScreen, gated isActive && canEdit"
affects: [04-movements plan 03, 05-reproductive-module, 08-animal-dossier]

tech-stack:
  added: []
  patterns:
    - "MoverAnimalDialog returns Map<String,String> ({'lotName': ...}) on success instead of bool — lets the parent screen show a SnackBar naming the destination lot (D-05), a deliberate departure from BaixaDialog's bool-return template"
    - "Property-scoped list providers that don't take a family arg resolve the active property internally via currentPropertyProvider.future (mirrors animalListByPropertyProvider) rather than requiring the caller to pass propertyId"
    - "Per-row enrichment (paddock name, active animal count) resolved via existing paddockByIdProvider/animalListByLotProvider family providers inside picker list items, instead of a single wide join query, to keep the top-level list provider's return type simple and directly testable"

key-files:
  created:
    - lib/features/animais/presentation/mover_animal_dialog.dart
  modified:
    - lib/features/animais/data/animal_repository.dart
    - lib/features/lotes/data/lote_repository.dart
    - lib/features/animais/presentation/animal_detail_screen.dart

key-decisions:
  - "loteListByPropertyProvider implemented as a plain (non-family) FutureProvider<List<Lot>> rather than the family FutureProvider<List<LotWithPaddockCount>, String> the plan's action block specified — required to compile against the already-committed Wave 0 widget test contract (see Deviations)."

requirements-completed: [MOV-01]

coverage:
  - id: D1
    description: "AnimalRepository.moveAnimal — single UPDATE lot_id (no RPC), returns updated Animal"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "test/features/animais/animal_repository_test.dart — AnimalRepository (MOV-01) group, 4 tests"
        status: pass
    human_judgment: false
  - id: D2
    description: "LoteRepository.fetchLotsWithCountByProperty + LotWithPaddockCount DTO + loteListByPropertyProvider, excluding archived lots"
    requirement: "MOV-01"
    verification:
      - kind: other
        ref: "flutter analyze lib/features/lotes/data/lote_repository.dart — no issues"
        status: pass
    human_judgment: false
  - id: D3
    description: "MoverAnimalDialog: title with animal number, Cancelar/Confirmar movimentação buttons, confirm disabled until lot selected, current lot excluded from picker"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "test/widget/mover_animal_dialog_test.dart — MoverAnimalDialog (MOV-01) group, 4 tests"
        status: pass
    human_judgment: false
  - id: D4
    description: "'Mover animal' button gate on AnimalDetailScreen: visible for veterinarian on active animal, hidden for reader, hidden when archived"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "test/widget/animal_detail_screen_test.dart — AnimalDetailScreen Mover animal button group, 3 tests"
        status: pass
    human_judgment: false
  - id: D5
    description: "End-to-end move flow (confirm → PostgREST UPDATE → provider invalidation → SnackBar with destination lot name) and the accepted T-4-01 cross-property gap"
    verification: []
    human_judgment: true
    rationale: "Requires a live Supabase dev project with a veterinarian session and 2+ lots to observe the SnackBar copy, old/new lot list refresh, and RLS-driven rejection paths — not exercisable from widget-level mocktail/Riverpod-override tests."

duration: 21min
completed: 2026-07-15
status: complete
---

# Phase 4 Plan 02: Move Animal to Another Lot Summary

**AnimalRepository.moveAnimal (single lot_id UPDATE, no RPC) wired through a new MoverAnimalDialog picker and a 3rd AnimalDetailScreen action button, gated to active animals owned by veterinarians.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-07-15T21:57:00Z (approx, continuing directly after 04-01)
- **Completed:** 2026-07-15T22:18:41Z
- **Tasks:** 4
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments
- `AnimalRepository.moveAnimal({id, newLotId})` — single-column PostgREST UPDATE, relies on the existing `veterinarian_can_update_active_animal` RLS policy for authorization; doc comment cross-links from `updateAnimal` to explain why `moveAnimal` intentionally bypasses the mass-assignment guard.
- `LoteRepository.fetchLotsWithCountByProperty` + `LotWithPaddockCount` DTO — two-query pattern (lots+paddock join, then a property-wide animal count grouped in Dart) avoiding PostgREST embedded-aggregate ambiguity; excludes archived lots.
- `loteListByPropertyProvider` — resolves the active property internally (same pattern as `animalListByPropertyProvider`) and returns a plain `List<Lot>`.
- `MoverAnimalDialog` — 480px-wide AlertDialog, 320px-max-height scrollable picker excluding the animal's current lot, confirm disabled until a lot is picked, per-row paddock name + active animal count resolved via existing `paddockByIdProvider`/`animalListByLotProvider`. On success invalidates `animalByIdProvider`, both old and new `animalListByLotProvider`, and `animalListByPropertyProvider`, then returns `{'lotName': ...}` for the parent's SnackBar.
- `AnimalDetailScreen` / `AnimalInfoCard` — new `OutlinedButton.icon` "Mover animal" (swap_horiz icon) after "Dar baixa", gated `isActive && canEdit`; on dialog success shows `SnackBar('Animal movido para {lotName}')`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add AnimalRepository.moveAnimal method** - `ee9b063` (feat)
2. **Task 2: Add LoteRepository.fetchLotsWithCountByProperty + loteListByPropertyProvider** - `aafb18c` (feat)
2b. **Fix: loteListByPropertyProvider signature correction** - `5a7ed31` (fix, same task scope — see Deviations)
3. **Task 3: Create MoverAnimalDialog widget** - `8534563` (feat)
4. **Task 4: Wire 'Mover animal' button into AnimalDetailScreen / AnimalInfoCard** - `7070b92` (feat)

_Note: all tasks are `type="auto" tdd="true"` against pre-existing Wave 0 RED tests — no separate test/feat/refactor commits were needed since the tests already existed from Plan 04-01._

## Files Created/Modified
- `lib/features/animais/data/animal_repository.dart` - `moveAnimal({id, newLotId})` method; doc comment cross-link on `updateAnimal`
- `lib/features/lotes/data/lote_repository.dart` - `fetchLotsWithCountByProperty`, `LotWithPaddockCount` DTO, `loteListByPropertyProvider`
- `lib/features/animais/presentation/mover_animal_dialog.dart` - New `MoverAnimalDialog` + `_LotPickerList` + `_LotPickerTile` widgets
- `lib/features/animais/presentation/animal_detail_screen.dart` - `onMover` callback on `AnimalInfoCard`, 3rd action button, SnackBar wiring

## Decisions Made
- **`loteListByPropertyProvider` is a plain provider, not a family** — see Deviations below for the full reasoning; recorded here because it affects how future plans (04-03's `MoverLoteDialog`/paddock picker) should model similar property-scoped pickers if they hit the same test-override convention.
- **Per-row enrichment over a single wide provider** — paddock name and active animal count are resolved per picker row via the existing `paddockByIdProvider`/`animalListByLotProvider` family providers rather than folding them into `loteListByPropertyProvider`'s return type. This keeps the top-level provider's type (`List<Lot>`) simple and matches what the Wave 0 test overrides, at the cost of N+1 provider watches for the picker list (acceptable — property lot counts are small in this domain).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `loteListByPropertyProvider` changed from family+DTO to plain `List<Lot>` provider**
- **Found during:** Task 3 (MoverAnimalDialog widget implementation)
- **Issue:** The plan's Task 2 action block specified `loteListByPropertyProvider` as `FutureProvider.family<List<LotWithPaddockCount>, String>`. The already-committed Wave 0 test (`test/widget/mover_animal_dialog_test.dart`, written in Plan 04-01) overrides it with `loteListByPropertyProvider.overrideWith((ref) async => [_sampleLotCurrent, _sampleLotTarget])` — a 1-argument callback returning `List<Lot>` directly. Every other family provider override in the same test file (and in `animal_detail_screen_test.dart`, `lote_detail_screen_test.dart`) uses the 2-argument `(ref, arg)` form, confirming this specific provider was authored as a non-family provider in the Wave 0 contract. Additionally, `currentPropertyProvider` is not overridden in that test, so gating the picker on a resolved `propertyId` (as the plan's Task 3 code sample does via `ref.watch(currentPropertyProvider)`) would leave the picker permanently on its loading state and the "excludes current lot" test would never find `'Lote Destino'`.
- **Fix:** Changed `loteListByPropertyProvider` to `FutureProvider<List<Lot>>` that resolves the active property internally via `ref.watch(currentPropertyProvider.future)` (mirroring `animalListByPropertyProvider`'s existing pattern) and unwraps `fetchLotsWithCountByProperty`'s DTO list down to `List<Lot>`. Rewrote `MoverAnimalDialog`/`_LotPickerList` to watch the provider directly (no family arg, no propertyId gating) and moved paddock name + animal count resolution into a new `_LotPickerTile` widget that watches `paddockByIdProvider`/`animalListByLotProvider` per row.
- **Files modified:** lib/features/lotes/data/lote_repository.dart, lib/features/animais/presentation/mover_animal_dialog.dart
- **Verification:** `flutter test test/widget/mover_animal_dialog_test.dart` — all 4 tests pass; `flutter analyze` clean on both files.
- **Committed in:** `5a7ed31` (fix, between Task 2 and Task 3 commits) and `8534563` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to compile against the Wave 0 test contract that gates this plan (per the executor's explicit mandate to turn those tests green). `LotWithPaddockCount`/`fetchLotsWithCountByProperty` were kept intact in the repository layer (still exercised by the provider internally); only the public provider's shape changed. No scope creep — repository method signatures, dialog copy, and gate logic all match the plan's intent.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 04-03 (MoverLoteDialog + LoteRepository.moveLot) can proceed; `test/features/lotes/lote_repository_test.dart` still fails to compile on the missing `moveLot` method, as expected — that plan will add it.
- If Plan 04-03 needs a property-scoped picker for paddocks, note the `loteListByPropertyProvider` plain-provider pattern established here (internal `currentPropertyProvider` resolution, no family arg) in case its Wave 0 test scaffold follows the same override convention.
- Regression confirmed: `flutter test test/widget/baixa_dialog_test.dart test/widget/animal_edit_dialog_test.dart test/widget/animais_screen_test.dart` — 20/20 passing.
- No blockers.

---
*Phase: 04-movements*
*Completed: 2026-07-15*

## Self-Check: PASSED

All 4 code files + SUMMARY.md verified present on disk. All 5 task commit hashes (ee9b063, aafb18c, 5a7ed31, 8534563, 7070b92) verified present in git log.
