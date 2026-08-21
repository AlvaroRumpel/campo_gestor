---
phase: 04-movements
plan: 01
subsystem: testing
tags: [flutter, riverpod, mocktail, tdd, wave0]

requires:
  - phase: 03-lots-animals
    provides: AnimalRepository, LoteRepository, PaddockRepository, AnimalDetailScreen, LoteDetailScreen, BaixaDialog pattern
provides:
  - 6 Wave 0 (red) test files gating Plan 04-02 (MoverAnimalDialog + AnimalRepository.moveAnimal) and Plan 04-03 (MoverLoteDialog + LoteRepository.moveLot)
  - Contract tests for AnimalRepository.moveAnimal and LoteRepository.moveLot
  - Widget test scaffolds for MoverAnimalDialog and MoverLoteDialog
  - Button-gate widget tests for AnimalDetailScreen ('Mover animal') and LoteDetailScreen ('Mover para piquete')
affects: [04-movements plan 02, 04-movements plan 03]

tech-stack:
  added: []
  patterns:
    - "Nyquist red scaffolding: tests reference symbols that don't exist yet, so compilation failure itself proves the test gates the missing implementation"
    - "currentPropertyProvider resolved indirectly via memberPropertiesProvider override (single membership auto-selected by CurrentPropertyNotifier.build()) rather than overriding the AsyncNotifierProvider directly"

key-files:
  created:
    - test/features/animais/animal_repository_test.dart
    - test/widget/mover_animal_dialog_test.dart
    - test/widget/mover_lote_dialog_test.dart
    - test/widget/animal_detail_screen_test.dart
    - test/widget/lote_detail_screen_test.dart
  modified:
    - test/features/lotes/lote_repository_test.dart

key-decisions:
  - "memberPropertiesProvider override (not currentPropertyProvider directly) drives canEdit gate tests — matches production CurrentPropertyNotifier logic for single-membership resolution"
  - "Added initializeDateFormatting('pt_BR') setUpAll to animal_detail_screen_test.dart — AnimalInfoCard formats dates with the pt_BR locale and crashes without it, which would mask the intended Nyquist red signal"

patterns-established:
  - "Wave 0 scaffold plans: create failing-but-compiling (or compile-failing) test files before implementation plans land, so implementation plans have automated verification commands from task 1"

requirements-completed: [MOV-01, MOV-02]

coverage:
  - id: D1
    description: "AnimalRepository.moveAnimal contract test scaffold (Wave 0 red)"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "flutter test test/features/animais/animal_repository_test.dart — expected non-zero exit (compile error on repo.moveAnimal)"
        status: pass
    human_judgment: false
  - id: D2
    description: "LoteRepository.moveLot contract test added to existing PROP-03 file (Wave 0 red)"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "flutter test test/features/lotes/lote_repository_test.dart — expected non-zero exit (compile error on repo.moveLot)"
        status: pass
    human_judgment: false
  - id: D3
    description: "MoverAnimalDialog widget test scaffold — 4 tests (Wave 0 red)"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "flutter test test/widget/mover_animal_dialog_test.dart — expected non-zero exit (compile error on MoverAnimalDialog / loteListByPropertyProvider)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MoverLoteDialog widget test scaffold — 4 tests (Wave 0 red)"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "flutter test test/widget/mover_lote_dialog_test.dart — expected non-zero exit (compile error on MoverLoteDialog)"
        status: pass
    human_judgment: false
  - id: D5
    description: "AnimalDetailScreen 'Mover animal' button gate — 3 tests (Wave 0 red, 1/3 failing on missing button)"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "flutter test test/widget/animal_detail_screen_test.dart — expected non-zero exit, 1 test failing on missing OutlinedButton 'Mover animal'"
        status: pass
    human_judgment: false
  - id: D6
    description: "LoteDetailScreen 'Mover para piquete' button gate — 4 tests (Wave 0 red, 1/4 failing on missing button)"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "flutter test test/widget/lote_detail_screen_test.dart — expected non-zero exit, 1 test failing on missing OutlinedButton 'Mover para piquete'"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-07-15
status: complete
---

# Phase 4 Plan 01: Wave 0 Test Scaffolds Summary

**6 failing-by-design test files (5 new + 1 extended) gating MOV-01/MOV-02 symbols that Plans 04-02 and 04-03 will implement, mirroring the Phase 3 baixa_dialog_test.dart pattern.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-15T21:34:00Z
- **Completed:** 2026-07-15T21:59:28Z
- **Tasks:** 6
- **Files modified:** 6 (5 created, 1 extended)

## Accomplishments
- Contract test for `AnimalRepository.moveAnimal` (new file, mirrors `lote_repository_test.dart` mocktail pattern) + a regression-guard `Animal.fromJson` test
- Contract test for `LoteRepository.moveLot` appended to the existing `lote_repository_test.dart`, preserving all 4 PROP-03 tests and 2 Lot-model tests
- Widget test scaffold for `MoverAnimalDialog` (4 tests: title, buttons, disabled-confirm, current-lot exclusion) — references the not-yet-existing `loteListByPropertyProvider`
- Widget test scaffold for `MoverLoteDialog` (4 tests: title, animal-count info text, disabled-confirm, current-paddock exclusion)
- Button-gate tests for `AnimalDetailScreen` ("Mover animal", 3 tests: canEdit, reader-hidden, archived-hidden)
- Button-gate tests for `LoteDetailScreen` ("Mover para piquete", 4 tests: canEdit+animals>0, reader-hidden, zero-animals-hidden, archived-hidden)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create animal repository contract test for moveAnimal** - `adc9b55` (test)
2. **Task 2: Extend lote repository test with moveLot contract test** - `7372fb4` (test)
3. **Task 3: Create mover_animal_dialog widget test scaffold** - `166fd12` (test)
4. **Task 4: Create mover_lote_dialog widget test scaffold** - `511dc3b` (test)
5. **Task 5: Create animal_detail_screen widget test scaffold** - `3417153` (test)
6. **Task 6: Create lote_detail_screen widget test scaffold** - `304ec28` (test)

_Note: All tasks are `type="auto"` with `tdd` not applicable — these ARE the Wave 0 red tests themselves, not RED/GREEN/REFACTOR cycles._

## Files Created/Modified
- `test/features/animais/animal_repository_test.dart` - Contract test for `moveAnimal` (compile-fails on missing symbol)
- `test/features/lotes/lote_repository_test.dart` - Extended with `moveLot` contract test (compile-fails on missing symbol)
- `test/widget/mover_animal_dialog_test.dart` - 4 widget tests for the future `MoverAnimalDialog` (compile-fails)
- `test/widget/mover_lote_dialog_test.dart` - 4 widget tests for the future `MoverLoteDialog` (compile-fails)
- `test/widget/animal_detail_screen_test.dart` - 3 gate tests for the future "Mover animal" button (compiles, 1/3 fails)
- `test/widget/lote_detail_screen_test.dart` - 4 gate tests for the future "Mover para piquete" button (compiles, 1/4 fails)

## Decisions Made
- **memberPropertiesProvider override instead of currentPropertyProvider override:** `currentPropertyProvider` is an `AsyncNotifierProvider`; rather than writing a fake `CurrentPropertyNotifier` subclass, the tests override `memberPropertiesProvider` with a single-membership list. `CurrentPropertyNotifier.build()` already auto-selects the sole membership's property when the list has exactly one entry — reusing that production logic keeps the test setup simpler and verifies the real selection path.
- **initializeDateFormatting('pt_BR') added to animal_detail_screen_test.dart:** `AnimalInfoCard` calls `DateFormat('dd/MM/yyyy', 'pt_BR')`. Without locale data initialization, pumping the widget throws a `LocaleDataException` that would mask the intended Nyquist red signal (missing "Mover animal" button) behind an unrelated crash. Added `setUpAll(() async => initializeDateFormatting('pt_BR', null))`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added locale data initialization to animal_detail_screen_test.dart**
- **Found during:** Task 5 (AnimalDetailScreen widget test scaffold)
- **Issue:** `AnimalInfoCard.build()` calls `DateFormat('dd/MM/yyyy', 'pt_BR')` to format `createdAt`/`baixaDate`. Pumping the widget without calling `initializeDateFormatting('pt_BR', null)` first throws `LocaleDataException`, which fails all 3 tests with an unrelated crash instead of the intended "missing 'Mover animal' button" assertion failure — this would have satisfied the letter of "test must fail" but broken the spirit of Nyquist red (the failure must name the missing symbol/button, per the plan's own acceptance criteria).
- **Fix:** Imported `package:intl/date_symbol_data_local.dart` and added `setUpAll(() async => initializeDateFormatting('pt_BR', null))`.
- **Files modified:** test/widget/animal_detail_screen_test.dart
- **Verification:** Re-ran `flutter test test/widget/animal_detail_screen_test.dart` — result changed from a locale exception on all 3 tests to `+2 -1`, with the single failure correctly citing the missing `OutlinedButton` "Mover animal".
- **Committed in:** 3417153 (Task 5 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to make the RED failure signal correctly point at the missing symbol per the plan's own acceptance criteria. No scope creep — no production code touched.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 04-02 can now implement `AnimalRepository.moveAnimal`, `MoverAnimalDialog`, `loteListByPropertyProvider`, and the "Mover animal" button in `AnimalInfoCard` — each has an automated verification command (`flutter test <file>`) that currently fails and will flip to green once the implementation lands.
- Plan 04-03 can now implement `LoteRepository.moveLot`, `MoverLoteDialog`, and the "Mover para piquete" button in `_LoteHeaderCard` — same automated-red-to-green setup.
- Regression guard confirmed: `flutter test test/features/animais/animal_model_test.dart test/features/animais/ua_calculation_test.dart test/widget/baixa_dialog_test.dart` exits 0 (13/13 passing).
- No blockers.

---
*Phase: 04-movements*
*Completed: 2026-07-15*

## Self-Check: PASSED

All 6 test files + SUMMARY.md verified present on disk. All 6 task commit hashes (adc9b55, 7372fb4, 166fd12, 511dc3b, 3417153, 304ec28) verified present in git log.
