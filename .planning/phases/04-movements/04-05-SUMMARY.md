---
phase: 04-movements
plan: 05
subsystem: ui
tags: [flutter, riverpod, widget-testing, pt-br]

# Dependency graph
requires:
  - phase: 04-movements
    provides: MoverAnimalDialog and MoverLoteDialog (plans 04-02/04-03), move_animal_to_lot RPC (plan 04-04)
provides:
  - MoverLoteDialog invalidates animalListByPropertyProvider + loteListByPropertyProvider on success (WR-01/WR-02)
  - Both move dialogs check `mounted` before touching `ref` post-await (WR-03)
  - Grammatically-correct pt-BR singular/plural info text in MoverLoteDialog (WR-04)
  - Tap-to-Confirm submit-flow widget tests for both dialogs, including an invalidation-regression-sensitive test (IN-01)
affects: [04-movements verification, future phases touching animal/lot provider invalidation patterns]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Widget-test host mirrors the real parent screen's showDialog + SnackBar flow (not just pumping the dialog in isolation) to exercise the full tap-confirm-mutate-invalidate-pop-snackbar path"
    - "Probe Consumer that ref.watch()es a provider under test so ref.invalidate() in the widget under test actually triggers a countable refetch — proves invalidation calls are present, not just declared"

key-files:
  created: []
  modified:
    - lib/features/lotes/presentation/mover_lote_dialog.dart
    - lib/features/animais/presentation/mover_animal_dialog.dart
    - test/widget/mover_lote_dialog_test.dart
    - test/widget/mover_animal_dialog_test.dart

key-decisions:
  - "Reordered both dialogs' _submit success path: `if (!mounted) return;` immediately after the awaited mutation, before any ref.invalidate — Navigator.pop is now unconditional after that guard"
  - "Proved the WR-01/WR-02 invalidations with counting-fake providers + a probe Consumer (not a ProviderObserver), since the probe is what makes the invalidate actually trigger a refetch to count"

requirements-completed: [MOV-01, MOV-02]

coverage:
  - id: D1
    description: "MoverLoteDialog invalidates animalListByPropertyProvider AND loteListByPropertyProvider on a successful lot move (WR-01, WR-02)"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "test/widget/mover_lote_dialog_test.dart#tapping Confirmar movimentação submits the move, invalidates animalListByPropertyProvider + loteListByPropertyProvider, and shows the success SnackBar (IN-01, proves WR-01/WR-02)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both move dialogs check `mounted` immediately after the awaited mutation, before touching `ref` (WR-03)"
    verification:
      - kind: unit
        ref: "test/widget/mover_lote_dialog_test.dart and test/widget/mover_animal_dialog_test.dart — full suite green post-reorder"
        status: pass
    human_judgment: false
  - id: D3
    description: "MoverLoteDialog info text is singular ('1 animal será transferido') when activeAnimalCount == 1, plural otherwise (WR-04)"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "test/widget/mover_lote_dialog_test.dart#renders singular info text when activeAnimalCount is 1 (WR-04)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Submit-flow behavior test for both dialogs: tap Confirm asserts the mutation fires with expected params, the dialog closes, and the success SnackBar shows (IN-01)"
    verification:
      - kind: unit
        ref: "test/widget/mover_animal_dialog_test.dart#tapping Confirmar movimentação submits the move and shows the success SnackBar (IN-01)"
        status: pass
      - kind: unit
        ref: "test/widget/mover_lote_dialog_test.dart#tapping Confirmar movimentação submits the move, invalidates animalListByPropertyProvider + loteListByPropertyProvider, and shows the success SnackBar (IN-01, proves WR-01/WR-02)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-07-16
status: complete
---

# Phase 4 Plan 05: Movement Dialog Gap Closure Summary

**Closed all four 04-REVIEW.md warnings (WR-01..04) and the untested-submit-flow info finding (IN-01) in MoverLoteDialog/MoverAnimalDialog — no RPC changes, UI-layer only.**

## Performance

- **Duration:** 25 min
- **Tasks:** 3 completed
- **Files modified:** 4 (2 source, 2 test)

## Accomplishments
- `MoverLoteDialog._submit` now invalidates all five relevant providers on success (3 existing lot/paddock providers + `animalListByPropertyProvider` + `loteListByPropertyProvider`), closing the stale-cache gap that left `AnimaisScreen` and the animal-move lot picker showing outdated paddock/lot data after a lot move.
- Both `MoverLoteDialog` and `MoverAnimalDialog` now check `mounted` immediately after their awaited mutation and before any `ref` use, so a dialog disposed mid-await can never throw and mislabel a succeeded move as a failure.
- `MoverLoteDialog`'s confirmation text is now grammatically correct in pt-BR for both singular (`"1 animal será transferido..."`) and plural (`"N animais serão transferidos..."`) counts.
- Both dialogs now have a real tap-to-Confirm widget test (not just static-render assertions): the lote-dialog test additionally proves the WR-01/WR-02 invalidations fire by watching both providers through a probe `Consumer` and counting refetches — confirmed locally to fail if either `ref.invalidate` call is removed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix MoverLoteDialog — invalidations (WR-01/WR-02), mounted guard (WR-03), plural (WR-04)** - `ad68434` (fix)
2. **Task 2: Fix MoverAnimalDialog — mounted guard (WR-03)** - `f17ec35` (fix)
3. **Task 3: Submit-flow behavior tests for both dialogs (IN-01)** - `fe35842` (test)

## Files Created/Modified
- `lib/features/lotes/presentation/mover_lote_dialog.dart` - added animal_repository import, mounted-before-invalidate reorder, 2 new invalidations, singular/plural info text
- `lib/features/animais/presentation/mover_animal_dialog.dart` - mounted-before-invalidate reorder, Navigator.pop unconditional after the guard
- `test/widget/mover_lote_dialog_test.dart` - fake repo now captures call args; added `_buildHost` (showDialog + SnackBar host with a provider-fetch-counting probe); added WR-04 singular test and the submit-flow/invalidation-proof test
- `test/widget/mover_animal_dialog_test.dart` - fake repo now captures call args; added `_buildHost` (showDialog + SnackBar host); added submit-flow test

## Decisions Made
- Used counting-fake provider overrides + a probe `Consumer` (rather than a `ProviderObserver`) to prove invalidation, per the plan's explicit guidance that a `ProviderObserver` is only acceptable if a probe first establishes an active listener — the probe-and-count approach was simpler to wire directly.
- Kept `MoverAnimalDialog`'s invalidation set unchanged (per plan) — WR-01/WR-02 only applied to the lot dialog, since the animal dialog already invalidated `animalListByPropertyProvider` correctly.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Manually verified the lote-dialog invalidation test's regression sensitivity by temporarily deleting the `animalListByPropertyProvider` invalidate call, confirming the test failed (`Expected: <2> Actual: <1>`), then restoring the file via `git checkout --` before the Task 3 commit.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All four reviewer warnings (WR-01..04) and the IN-01 automatable behavior gap from 04-REVIEW.md are closed.
- `flutter analyze` clean on both touched dialog files; full `flutter test` suite green (96/96).
- The remaining CR-01 (cross-property `moveAnimal` RPC hardening) and the RPC-live UAT item are owned by plan 04-04 and are unaffected by this plan.

---
*Phase: 04-movements*
*Completed: 2026-07-16*

## Self-Check: PASSED
