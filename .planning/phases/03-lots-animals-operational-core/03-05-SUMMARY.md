---
phase: 03-lots-animals-operational-core
plan: "05"
subsystem: ui
tags: [flutter, riverpod, go_router, material3, role-gate, dialog, animal-creation]

requires:
  - phase: "03-04"
    provides: "LoteDetailScreen stub, AppRoutes.loteDetail/animalDetail, LoteFormDialog, LotsSection"
  - phase: "03-03"
    provides: "AnimalRepository (generateAnimalNumber, createAnimal, AnimalNumberConflictException), animalListByLotProvider, animalListByPropertyProvider, animal_constants (kCategories, kBreeds, calcTotalUa, kUaWeights)"

provides:
  - "Full LoteDetailScreen: header card with paddock name + per-category chips + total UA, animal list sorted by number, FAB role-gated to veterinarian"
  - "AnimalFormDialog: auto-filled number via generateAnimalNumber RPC, overridable, categoria dropdown (7 options), raça dropdown (kBreeds), 5 EC ChoiceChips, observacao multi-line, AnimalNumberConflictException SnackBar"
  - "_LotsSection _LotCard subtitle upgraded from static text to real composition via animalListByLotProvider Consumer + _composeSummary (top-2 categories + UA total)"

affects:
  - "03-06 — PaddockDetailScreen now shows accurate lot composition; LoteDetailScreen is the primary animal management surface"
  - "Phase 5 (Reproductive) — LoteDetailScreen animal list is the entry point for ATF operations"

tech-stack:
  added: []
  patterns:
    - "Consumer widget per row for per-item async data (lot card subtitle pattern)"
    - "_canEdit helper: SelectedProperty + List<PropertyMembership> → bool (role == veterinarian)"
    - "AnimalFormDialog auto-fill via initState → generateAnimalNumber RPC, user-overridable TextFormField"
    - "DropdownButtonFormField with initialValue (not deprecated value:) for nullable String? fields"

key-files:
  created:
    - lib/features/animais/presentation/animal_form_dialog.dart
  modified:
    - lib/features/lotes/presentation/lote_detail_screen.dart
    - lib/features/lotes/presentation/_lots_section.dart

key-decisions:
  - "D-04: LoteDetailScreen header shows paddock name (via paddockByIdProvider), per-category chips (count + UA each), and total UA chip — matches UI-SPEC Screen 3"
  - "D-07: Auto-numbering via generateAnimalNumber RPC on dialog open; field is user-overridable; AnimalNumberConflictException surfaces clean user message via SnackBar"
  - "D-13: FAB 'Novo animal' (tooltip) is role-gated: visible only when _canEdit returns true (role == veterinarian)"
  - "D-14: kBreeds dropdown in AnimalFormDialog — hardcoded constant list, not DB-stored"
  - "D-16: 5 EC ChoiceChips labeled 1..5; deselect supported (tap same chip again to set bodyCondition = null)"
  - "SC-1 verifiable: Phase 3 success criterion (system generates animals, lot shows composition) is now end-to-end testable once Supabase RPC create_lot_with_animals runs"

patterns-established:
  - "Consumer-per-row for per-item providers (avoids rebuilding entire list on single item change)"
  - "Error callback uses (e, _) not (_, __) — avoids unnecessary_underscores lint warning"
  - "initialValue: over value: for DropdownButtonFormField (Flutter 3.33+ API)"

requirements-completed:
  - PROP-03
  - PROP-04
  - PROP-05
  - ANIM-01

duration: 35min
completed: "2026-05-14"
---

# Phase 03 Plan 05: LoteDetailScreen + AnimalFormDialog + Real Lot Composition Summary

**Full LoteDetailScreen with header composition chips + role-gated FAB, AnimalFormDialog with auto-numbered individual animal creation, and live lot-card subtitles in _LotsSection**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-05-14T22:10:00Z
- **Completed:** 2026-05-14T22:45:00Z
- **Tasks:** 2 (committed as one atomic unit due to import dependency)
- **Files modified:** 3

## Accomplishments

- Replaced Plan 04 LoteDetailScreen stub with full implementation: header card (paddock name, per-category animal count + UA chips, total UA), sorted animal list (primary `#N · Category`, secondary `Breed · EC N`), empty state with `pets_outlined` icon
- Built AnimalFormDialog with auto-filled número via `generateAnimalNumber` RPC (overridable), categoria dropdown (7 kCategories), raça dropdown (kBreeds), 5 EC ChoiceChips, observação multi-line, `AnimalNumberConflictException` handled via SnackBar
- Upgraded `_LotsSection` lot-card subtitle from static `'Toque para ver composição'` to live `_composeSummary` via `Consumer` per card — shows top-2 categories + total UA (e.g. `8 Vacas · 5 Terneiros · 10,5 UA`)
- FAB `'Novo animal'` is role-gated: uses same `_canEdit(SelectedProperty?, List<PropertyMembership>?)` pattern from PaddockDetailScreen; non-veterinarians see no FAB
- `flutter analyze` reports zero issues; full test suite (52 tests) passes GREEN

## Task Commits

Both tasks committed atomically (Task 1 imports Task 2's AnimalFormDialog):

1. **Task 1 + 2: LoteDetailScreen + AnimalFormDialog + _LotsSection subtitles** - `2e59478` (feat)

## Files Created/Modified

- `lib/features/lotes/presentation/lote_detail_screen.dart` — Full implementation replacing Plan 04 stub (9,738 bytes, 282 lines)
- `lib/features/animais/presentation/animal_form_dialog.dart` — New individual animal creation dialog (created, 214 lines)
- `lib/features/lotes/presentation/_lots_section.dart` — Lot-card subtitle upgraded with Consumer + `_composeSummary`

## Decisions Made

- Tasks 1 and 2 committed as a single atomic commit because `lote_detail_screen.dart` imports `animal_form_dialog.dart` — two separate commits would have left the build broken between them
- Used `initialValue:` (not deprecated `value:`) for `DropdownButtonFormField` in Flutter 3.33+
- Error callbacks use `(e, _)` pattern (not `(_, __)`) to satisfy `unnecessary_underscores` lint
- `build_runner` run required to generate `lote_model.freezed.dart` / `lote_model.g.dart` / `animal_model.freezed.dart` / `animal_model.g.dart` — these are gitignored and must be regenerated per machine

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Run build_runner to generate missing freezed/json files**
- **Found during:** Task 1 (flutter analyze after writing LoteDetailScreen)
- **Issue:** `lote_model.freezed.dart`, `lote_model.g.dart`, `animal_model.freezed.dart`, `animal_model.g.dart` are gitignored and not present in the worktree. Analyzer reported 20+ errors on `Lot` and `Animal` fields.
- **Fix:** Ran `dart run build_runner build` — generated 12 output files in 46s
- **Files modified:** Generated files (gitignored, not committed)
- **Verification:** `flutter analyze` showed zero model-related errors after generation
- **Committed in:** Not committed (gitignored outputs)

**2. [Rule 1 - Bug] Fixed `unnecessary_underscores` lint warnings in error callbacks**
- **Found during:** Task 1 and 2 verification (flutter analyze)
- **Issue:** Plan template used `(_, __)` double-underscore pattern; analyzer reports `unnecessary_underscores` info warning
- **Fix:** Changed all error callbacks from `(_, __)` to `(e, _)` pattern
- **Files modified:** `lote_detail_screen.dart`, `_lots_section.dart`
- **Committed in:** `2e59478`

**3. [Rule 1 - Bug] Replaced deprecated `value:` with `initialValue:` in DropdownButtonFormField**
- **Found during:** Task 2 verification (flutter analyze)
- **Issue:** Flutter 3.33+ deprecates `value:` on `DropdownButtonFormField` — use `initialValue:` instead
- **Fix:** Changed both `DropdownButtonFormField` usages in `animal_form_dialog.dart` to `initialValue:`
- **Files modified:** `lib/features/animais/presentation/animal_form_dialog.dart`
- **Committed in:** `2e59478`

---

**Total deviations:** 3 auto-fixed (1 blocking — missing codegen, 2 lint/deprecation bugs)
**Impact on plan:** All fixes necessary for zero-warning build. No scope creep.

## Issues Encountered

- Worktree was initially at commit `0c2c28d` (pre-Phase-2 base) instead of `ecc4bd9` (post-03-04). Resolved via `git reset --soft ecc4bd9` followed by `git checkout HEAD -- .` to restore the working tree to the correct base. This is a worktree initialization quirk — the staged-but-uncommitted delta from the main repo was present in the index but not the working tree.

## Next Phase Readiness

- LoteDetailScreen is complete and reachable from PaddockDetailScreen → lot card tap
- AnimalFormDialog handles individual animal creation end-to-end (requires live Supabase for RPC calls)
- SC-1 (Phase 3 success criterion) is now fully verifiable: batch-create lot via LoteFormDialog, then open LoteDetailScreen and confirm composition chips + animal list
- Plan 06 (AnimaisScreen filters, AnimalDetailScreen, BaixaDialog) can proceed — all provider dependencies are in place

---
*Phase: 03-lots-animals-operational-core*
*Completed: 2026-05-14*

## Self-Check: PASSED

- FOUND: lib/features/lotes/presentation/lote_detail_screen.dart
- FOUND: lib/features/animais/presentation/animal_form_dialog.dart
- FOUND: lib/features/lotes/presentation/_lots_section.dart
- FOUND: .planning/phases/03-lots-animals-operational-core/03-05-SUMMARY.md
- FOUND: commit 2e59478
