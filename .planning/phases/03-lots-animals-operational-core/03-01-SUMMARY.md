---
phase: 03-lots-animals-operational-core
plan: 01
subsystem: testing
tags:
  - testing
  - scaffolding
  - flutter
  - tdd
  - wave-0
dependency_graph:
  requires:
    - "Phase 0: flutter_test SDK (already in pubspec.yaml)"
  provides:
    - "Wave-0 RED test stubs for PROP-03, PROP-04, PROP-05, ANIM-01, ANIM-02, ANIM-04, ANIM-05, ANIM-06"
    - "Automated verify commands for all Phase 3 requirements before any implementation"
  affects:
    - "Plans 03-02 through 03-06: each plan turns some of these skipped tests green"
tech_stack:
  added: []
  patterns:
    - "testWidgets skip param uses bool (true) not String — flutter_test API constraint"
    - "Unit test skip uses String skip reason (test() accepts String?; testWidgets() only bool?)"
key_files:
  created:
    - test/features/lotes/lote_repository_test.dart
    - test/features/animais/animal_model_test.dart
    - test/features/animais/ua_calculation_test.dart
    - test/widget/lote_form_dialog_test.dart
    - test/widget/animal_edit_dialog_test.dart
    - test/widget/baixa_dialog_test.dart
    - test/widget/animais_screen_test.dart
  modified: []
decisions:
  - "testWidgets skip uses bool: true (not String) — flutter_test's testWidgets() only accepts bool? for skip parameter, unlike test() which accepts Object? (String or bool)"
metrics:
  duration_seconds: 464
  completed_date: "2026-05-14"
  tasks_completed: 2
  tasks_total: 2
  files_created: 7
  files_modified: 0
---

# Phase 3 Plan 01: Wave-0 Test Scaffolds Summary

Wave-0 test scaffolds for Phase 3 — 7 skipped test files covering 8 requirement IDs (PROP-03, PROP-04, PROP-05, ANIM-01, ANIM-02, ANIM-04, ANIM-05, ANIM-06), all compiling and exiting 0 to establish the Nyquist baseline for Wave 1–3 implementations.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Unit-test stubs: lote repo, animal model, UA calc | `8ab7daa` | test/features/lotes/lote_repository_test.dart, test/features/animais/animal_model_test.dart, test/features/animais/ua_calculation_test.dart |
| 2 | Widget-test stubs: lote form, animal edit, baixa, animais screen | `37f02ee` | test/widget/lote_form_dialog_test.dart, test/widget/animal_edit_dialog_test.dart, test/widget/baixa_dialog_test.dart, test/widget/animais_screen_test.dart |

---

## Requirement Coverage

| Requirement | Test File | Tests Stubbed | Wave Turns Green |
|-------------|-----------|---------------|------------------|
| PROP-03 | test/features/lotes/lote_repository_test.dart | 4 | Wave 1 (Plan 03) |
| ANIM-01 | test/features/animais/animal_model_test.dart | 4 | Wave 1 (Plan 03) |
| PROP-05 | test/features/animais/ua_calculation_test.dart | 4 | Wave 1 (Plan 03) |
| PROP-04 | test/widget/lote_form_dialog_test.dart | 5 | Wave 2 (Plan 04) |
| ANIM-02 | test/widget/animal_edit_dialog_test.dart | 5 | Wave 3 (Plan 06) |
| ANIM-04 | test/widget/baixa_dialog_test.dart | 5 | Wave 3 (Plan 06) |
| ANIM-05 | test/widget/animais_screen_test.dart | 3 | Wave 3 (Plan 06) |
| ANIM-06 | test/widget/animais_screen_test.dart | 7 | Wave 3 (Plan 06) |

**Total:** 37 skipped tests across 7 files. All exit 0.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] testWidgets skip parameter type mismatch**
- **Found during:** Task 2 verification
- **Issue:** The plan's sample code used `skip: 'pending Plan 04 implementation'` (String) for `testWidgets()`. The `flutter_test` SDK in this project constrains `testWidgets()` skip parameter to `bool?`, not `Object?`. Passing a String caused a compile error. The `test()` function (used in Task 1) accepts `Object?` so String skip works there.
- **Fix:** Changed all `testWidgets()` skip values to `skip: true` and moved the reason text to an inline comment above each call.
- **Files modified:** test/widget/lote_form_dialog_test.dart, test/widget/animal_edit_dialog_test.dart, test/widget/baixa_dialog_test.dart, test/widget/animais_screen_test.dart
- **Commit:** `37f02ee`

### Pre-existing Issues (Out of Scope)

The full `flutter test test/widget/` command exits non-zero due to missing freezed codegen files (`.freezed.dart`, `.g.dart`) for `piquete_model` and `propriedade_model`. These pre-exist in the worktree base (`71d028d`) and are unrelated to Wave-0 stubs. The 7 new test files all pass individually. Logged to deferred-items for the orchestrator.

---

## Verification

```
flutter test test/features/lotes/lote_repository_test.dart \
             test/features/animais/animal_model_test.dart \
             test/features/animais/ua_calculation_test.dart \
             test/widget/lote_form_dialog_test.dart \
             test/widget/animal_edit_dialog_test.dart \
             test/widget/baixa_dialog_test.dart \
             test/widget/animais_screen_test.dart
```
Result: 37 tests skipped, exit 0.

---

## Known Stubs

All 37 tests are intentional stubs — they represent the Wave-0 RED baseline. Each will be turned green by its target plan (Wave 1/2/3). No unintentional stubs.

## Threat Flags

None — this plan creates only test scaffolds with no runtime trust boundaries.

## Self-Check: PASSED

- [x] test/features/lotes/lote_repository_test.dart exists
- [x] test/features/animais/animal_model_test.dart exists
- [x] test/features/animais/ua_calculation_test.dart exists
- [x] test/widget/lote_form_dialog_test.dart exists
- [x] test/widget/animal_edit_dialog_test.dart exists
- [x] test/widget/baixa_dialog_test.dart exists
- [x] test/widget/animais_screen_test.dart exists
- [x] Commit 8ab7daa exists (Task 1)
- [x] Commit 37f02ee exists (Task 2)
- [x] All 7 files have no production-code imports
