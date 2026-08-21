---
phase: 03-lots-animals-operational-core
fixed_at: 2026-05-19T00:00:00Z
review_path: .planning/phases/03-lots-animals-operational-core/03-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-05-19T00:00:00Z
**Source review:** 03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### WR-01: TextEditingController leak in BaixaDialog date field

**Files modified:** `lib/features/animais/presentation/baixa_dialog.dart`
**Commit:** `51c801f`
**Applied fix:** Promoted date controller to a `late final TextEditingController _dateCtrl` field. Added `initState` to initialize it, added `_dateCtrl.dispose()` in `dispose` before `super.dispose()`, updated `_pickDate` to assign `_dateCtrl.text = _dateFmt.format(picked)` inside the `setState` block, and replaced the inline `TextEditingController(text: ...)` in `build` with `controller: _dateCtrl`.

---

### WR-02: Silent swallow of `generateAnimalNumber` failure leaves field empty

**Files modified:** `lib/features/animais/presentation/animal_form_dialog.dart`
**Commit:** `e9f73b7`
**Applied fix:** Added a `ScaffoldMessenger.of(context).showSnackBar(...)` call in the `_fetchAutoNumber` catch block after `setState(() => _loadingNumber = false)`, informing the user that auto-generation failed and asking them to enter a number manually.

---

### WR-03: Empty-state logic bug in AnimaisScreen produces wrong widget

**Files modified:** `lib/features/animais/presentation/animais_screen.dart`
**Commit:** `ce69272`
**Applied fix:** Replaced the redundant three-arm conditional (with unreachable final arm) with a clean two-arm ternary: `filtered.isEmpty ? (animals.isEmpty ? _EmptyAllState : _EmptyFilterState) : ListView.builder(...)`.

---

### WR-04: `ref.read` inside `FutureProvider.family` — missing reactivity

**Files modified:** `lib/features/animais/data/animal_repository.dart`, `lib/features/lotes/data/lote_repository.dart`
**Commit:** `ba722b4`
**Applied fix:** Replaced all `ref.read(animalRepositoryProvider)` calls with `ref.watch(animalRepositoryProvider)` in `animalListByLotProvider`, `animalListByPropertyProvider`, and `animalByIdProvider`. Applied the same replacement for `ref.read(loteRepositoryProvider)` → `ref.watch(loteRepositoryProvider)` in `loteListByPaddockProvider` and `loteByIdProvider`.

---

### WR-05: `LotsSection._openEditDialog` does not await dialog result

**Files modified:** `lib/features/lotes/presentation/_lots_section.dart`
**Commit:** `cb94199`
**Applied fix:** Changed `_openEditDialog` from `void` to `Future<void> async`, added `await` on `showDialog<bool>`, and added `if (ok == true) ref.invalidate(loteListByPaddockProvider(paddockId))` after the dialog closes to ensure cache is invalidated from the component that holds `ref`.

---

## Skipped Issues

None — all 5 warnings were fixable without breaking API surface.

## Info Items

IN-01 through IN-04 are out of scope for this fix pass (Info severity, not Warning/Critical).

## Remaining Issues

- **IN-01:** Hardcoded paddock navigation string — tracked for Phase 4 routing cleanup
- **IN-02:** Missing SQL comment on `generate_animal_number` MAX query — documentation-only fix, low priority
- **IN-03:** `lote_repository_test.dart` contract tests only verify method existence — acknowledged tech debt
- **IN-04:** `_canEdit` logic duplicated across 3 screens — refactor candidate post-MVP

## Note on `flutter analyze`

`flutter analyze` reports pre-existing errors throughout the codebase caused by missing code-generated files (`animal_model.freezed.dart`, `animal_model.g.dart`, `lote_model.freezed.dart`, `lote_model.g.dart`). These are not regressions from this fix pass — they existed before and require `dart run build_runner build` to resolve. None of the errors reference the 5 files modified in this pass.

---

_Fixed: 2026-05-19T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
