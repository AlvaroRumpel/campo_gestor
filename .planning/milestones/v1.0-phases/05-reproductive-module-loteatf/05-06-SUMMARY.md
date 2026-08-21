---
phase: 05-reproductive-module-loteatf
plan: 06
subsystem: ui
tags: [flutter, riverpod, checkbox-list-tile, widget-tests]

# Dependency graph
requires:
  - phase: 05-02
    provides: eligibleAnimalsForAtfProvider, EligibleAnimal (with blockedByAtfName)
  - phase: 05-03
    provides: add_animals_to_atf and remove_animal_from_atf RPCs, wrapped by AtfRepository
  - phase: 05-04
    provides: AtfDetailScreen shell + AtfHeaderCard, the ListView this plan inserts into
provides:
  - AtfAnimalSelectionScreen — lote-base + avulsos animal picker for adding animals to an ATF
  - _CompositionSection and _RemoveAnimalConfirmDialog on AtfDetailScreen
  - Both halves of ROADMAP SC-2 proven by executable widget tests
affects: [05-08, 05-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Disabled-but-visible row for D-07-style transparency: CheckboxListTile enabled: false plus a reason suffix, never a where-clause exclusion"
    - "Defense-in-depth category filter applied at both the repository layer and the picker UI, so the client never depends solely on server-side enforcement for what it renders"
    - "_CompositionSection renders from already-resolved lists passed in by the parent (mirrors AtfHeaderCard's convention) rather than watching its own async providers — avoids an independent loading spinner per 05-UI-SPEC E5"

key-files:
  created:
    - lib/features/reproducao/presentation/atf_animal_selection_screen.dart
    - test/widget/atf_animal_selection_screen_test.dart
  modified:
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "AtfAnimalSelectionScreen pushed via Navigator.push (MaterialPageRoute), not a GoRoute — matches the plan's transient-workflow rationale."
  - "Avulsos list excludes animals already shown in the selected lot's checklist (by lotId) to avoid duplicate rows for the same animal across both sections — not explicitly specified by the plan, but the only interpretation that avoids a checkbox-state ambiguity."
  - "Both the lot checklist and the avulsos checklist independently filter to {vaca, novilha} even though the repository already restricts to those categories — defense-in-depth so a touro/terneiro can never render regardless of what the data source returns (D-09)."
  - "_CompositionSection accepts activeMemberships/dgRecords as plain lists (not its own AsyncValue.when), following AtfHeaderCard's established convention and 05-UI-SPEC E5's 'no independent spinner' requirement."

patterns-established:
  - "Confirm-then-pop-then-snackbar sequence: capture ScaffoldMessenger.of(context) before Navigator.pop so the success SnackBar still shows after the pushed screen closes."

requirements-completed: [REPR-02]

coverage:
  - id: D1
    description: "AtfAnimalSelectionScreen offers only vaca/novilha animals (lot checklist and avulsos both defense-in-depth filtered); a touro/terneiro never renders"
    requirement: "REPR-02"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_animal_selection_screen_test.dart#a touro and a terneiro in the same lot are absent from the rendered list"
        status: pass
    human_judgment: false
  - id: D2
    description: "An animal already active in a different ATF renders as a visible, disabled row carrying the blocking ATF's name — never silently filtered out"
    requirement: "REPR-02"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_animal_selection_screen_test.dart#a blocked animal renders a disabled row whose text contains the blocking ATF name"
        status: pass
      - kind: automated_ui
        ref: "test/widget/atf_animal_selection_screen_test.dart#tapping a blocked row does not change the selection count"
        status: pass
    human_judgment: false
  - id: D3
    description: "Choosing a base lot pre-checks every eligible animal of that lot (D-06); confirm calls add_animals_to_atf with exactly the checked ids and invalidates the composition/list providers"
    requirement: "REPR-02"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_animal_selection_screen_test.dart#choosing a base lot pre-checks every eligible animal of it"
        status: pass
      - kind: automated_ui
        ref: "test/widget/atf_animal_selection_screen_test.dart#confirming calls addAnimalsToAtf exactly once with the checked ids"
        status: pass
    human_judgment: false
  - id: D4
    description: "ATF composition stays editable while active: _CompositionSection lists active memberships, a remove icon is absent (not disabled) once an animal has a DG in this ATF, and the confirm dialog calls remove_animal_from_atf"
    requirement: "REPR-02"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#an animal with no DG renders a remove IconButton; one with a DG renders none"
        status: pass
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#confirming the remove dialog calls removeAnimalFromAtf once"
        status: pass
    human_judgment: false

duration: 30min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 6: Animal Selection Screen and ATF Composition Summary

**AtfAnimalSelectionScreen (lote-base pre-check + avulsos search/filter picker) and AtfDetailScreen's _CompositionSection with a remove-animal confirm flow — both halves of ROADMAP SC-2 now have an executable assertion.**

## Performance

- **Duration:** ~30 min
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- `AtfAnimalSelectionScreen`: a "Lote base" dropdown that pre-checks every eligible active vaca/novilha of the chosen lot (D-06), plus an "Avulsos" debounced search + category filter row (locked to vaca/novilha, D-09) for animals from any other lot
- An animal already active in a DIFFERENT ATF renders as a disabled `CheckboxListTile` carrying its blocking ATF's name ("já em ATF Primavera") rather than being hidden — the SC-2 "mensagem clara" requirement, proven by a widget test that asserts the row is FOUND, not absent
- Confirm calls `add_animals_to_atf`, invalidates `atfActiveMembershipsProvider`, `atfMembershipsProvider`, and `atfListByPropertyProvider`, and shows the success SnackBar; a repository throw keeps the screen mounted with the selection still staged
- `_CompositionSection` inserted into `AtfDetailScreen`'s `ListView`: one row per active membership, a role-and-active-gated "+ Animais" button opening the selection screen, and a remove `IconButton` that is absent (not disabled) once the animal has a DG in this ATF (D-08)
- `_RemoveAnimalConfirmDialog`: minimal `AlertDialog` using the default primary color (not `colorScheme.error`) since removal is a correction, not data loss
- 14 new widget tests across both files, all passing, plus the full 159-test suite green

## Task Commits

Each task was committed atomically:

1. **Task 1: AtfAnimalSelectionScreen — lote base plus avulsos picker** - `501a301` (feat)
2. **Task 2: _CompositionSection and the remove-animal flow on AtfDetailScreen** - `c4b57a3` (feat)
3. **Task 3: Widget tests for the picker and the composition section** - `fdcc437` (test)

## Files Created/Modified
- `lib/features/reproducao/presentation/atf_animal_selection_screen.dart` - new full-screen animal picker (D-06/D-07/D-09)
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - adds `_CompositionSection`, `_RemoveAnimalConfirmDialog`, and the `_canEdit` role gate
- `test/widget/atf_animal_selection_screen_test.dart` - 8 new tests covering both halves of SC-2
- `test/widget/atf_detail_screen_test.dart` - extended with a 6-test `_CompositionSection` group; two pre-existing plan-05-04 assertions scoped (see Deviations)

## Decisions Made
- Avulsos excludes animals from the currently-selected lot (already shown above) to avoid duplicate checkbox rows for the same animal.
- Both picker sections re-filter to `{vaca, novilha}` client-side even though the repository already restricts categories — defense-in-depth, not redundant given Task 3's own test caught the gap in the lot checklist before this fix.
- `_CompositionSection` takes pre-resolved lists rather than watching its own providers, matching `AtfHeaderCard`'s established convention and 05-UI-SPEC E5 ("no independent spinner").

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Disabled-row reason duplicated "ATF"**
- **Found during:** Task 3 (writing the blocked-row widget test)
- **Issue:** `blockedByAtfName` already carries the batch's full name (e.g. `"ATF Outono"`, matching how `AtfBatch.name` is used everywhere else in the codebase), but the row builder additionally prefixed a literal `"já em ATF "`, producing `"já em ATF ATF Outono"` — never matching the UI-SPEC's exact example string.
- **Fix:** Changed to `'já em ${e.blockedByAtfName}'`.
- **Files modified:** `lib/features/reproducao/presentation/atf_animal_selection_screen.dart`
- **Verification:** New widget test asserts the row text contains `"já em ATF Outono"`.
- **Committed in:** `fdcc437` (Task 3 commit)

**2. [Rule 1 - Bug] Lot checklist missing the D-09 defense-in-depth category filter**
- **Found during:** Task 3 (writing the touro/terneiro-absence widget test)
- **Issue:** The avulsos section explicitly re-filtered to `{vaca, novilha}`, but the lot-base checklist only filtered by `lotId`, relying solely on the repository never returning other categories. Task 1's own acceptance criteria required a category-value literal check on the source file, which passed, but Task 3's runtime test exposed the missing client-side guard.
- **Fix:** Both `lotAnimals` and `avulsos` now filter through the same `_eligibleCategories` (`['vaca', 'novilha']`) list.
- **Files modified:** `lib/features/reproducao/presentation/atf_animal_selection_screen.dart`
- **Verification:** Widget test with a touro and a terneiro in the same lot as an eligible vaca asserts neither renders.
- **Committed in:** `fdcc437` (Task 3 commit)

**3. [Rule 1 - Bug] Pre-existing `InkWell` assertions collided with new sibling widgets**
- **Found during:** Task 3 (running the full `atf_detail_screen_test.dart` file after adding `_CompositionSection`)
- **Issue:** Two plan-05-04 tests ("bull link…") used an unscoped `find.byType(InkWell)`. `_CompositionSection`'s `OutlinedButton`s (and `ListTile`'s own ripple) also use `InkWell` internally, so once composition rendered its "+ Animais" / "Adicionar animais" affordances, the count no longer matched what the bull-link tests expected — a pre-existing brittleness the new sibling functionality exposed, not a change in the bull-link behavior itself.
- **Fix:** Scoped both assertions to `find.descendant(of: find.byType(AtfHeaderCard), matching: find.byType(InkWell))`, preserving the original intent (bull row tappability) without depending on what else is on the screen.
- **Files modified:** `test/widget/atf_detail_screen_test.dart`
- **Verification:** Both tests pass again; the full plan-05-04 group (10 tests) and the new `_CompositionSection` group (6 tests) are all green together.
- **Committed in:** `fdcc437` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 — bugs found via the plan's own test-writing task, before any commit landed)
**Impact on plan:** All three were caught and fixed within Task 3, before that task's commit. No scope creep — no behavior was added beyond what Tasks 1 and 2 specified; these are correctness fixes to code written in the same plan.

## Issues Encountered
None beyond the three auto-fixed issues above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `AtfAnimalSelectionScreen` and `_CompositionSection` are complete and independently testable; plan 05-08 (DG section) and 05-09 (encerramento) both extend `atf_detail_screen.dart` in later waves without needing further changes here.
- ROADMAP SC-2 now has both halves proven: `test/widget/atf_animal_selection_screen_test.dart#a touro and a terneiro in the same lot are absent from the rendered list` (only vaca/novilha offered) and `#a blocked animal renders a disabled row whose text contains the blocking ATF name` (blocked animal stays visible with a clear reason).
- No blockers carried forward specific to this plan. The Supabase live-execution blocker noted in 05-03-SUMMARY.md (migrations not yet pushed) still applies to any live UAT of `add_animals_to_atf`/`remove_animal_from_atf`, unchanged by this plan.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

- FOUND: lib/features/reproducao/presentation/atf_animal_selection_screen.dart
- FOUND: lib/features/reproducao/presentation/atf_detail_screen.dart
- FOUND: test/widget/atf_animal_selection_screen_test.dart
- FOUND: test/widget/atf_detail_screen_test.dart
- FOUND: .planning/phases/05-reproductive-module-loteatf/05-06-SUMMARY.md
- FOUND commit: 501a301 (Task 1)
- FOUND commit: c4b57a3 (Task 2)
- FOUND commit: fdcc437 (Task 3)
