---
phase: 05-reproductive-module-loteatf
plan: 13
subsystem: ui
tags: [flutter, riverpod, widget-test, gap-closure]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf
    provides: AtfFormDialog (plan 05-04), AtfHeaderCard (plan 05-04), the D-05 hybrid bull field contract
provides:
  - Single-source bull-label function (`_bullLabel`) shared by AtfFormDialog's dropdown and its create call
  - AtfHeaderCard hardened so no branch ever renders a raw database uuid as user-facing text
affects: [05-REVIEW.md#WR-01, 05-VERIFICATION.md baseline]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single label-producing function consumed by both the UI builder and the persistence call, to prevent display/write drift"
    - "Read-path fallback hardened to a copy placeholder ('Ver touro') instead of an internal identifier, for legacy rows the write-path fix cannot retroactively fix"

key-files:
  created: []
  modified:
    - lib/features/reproducao/presentation/atf_form_dialog.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_form_dialog_test.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "bullAnimalId stays the InkWell navigation target only; bullName (or the 'Ver touro' placeholder) is the only value ever passed as Text, per D-05's hybrid FK-or-free-text contract."
  - "No AtfRepository join added (A-NO-READ-PATH-JOIN carried from the plan) — the label is captured once at create time via _bullLabel, avoiding a per-render animals join."
  - "Pre-existing atf_batches rows (bullAnimalId set, bullName null) are not backfilled (A-LEGACY-ROWS-NOT-BACKFILLED) — they render the 'Ver touro' placeholder instead of a migration."

requirements-completed: [REPR-01]

coverage:
  - id: D1
    description: "Real-touro ATF creation persists a readable bullName ('#<numero>' or '#<numero> — <raça>') alongside bullAnimalId, sourced from one shared _bullLabel function used by both the dropdown and the create call."
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/widget/atf_form_dialog_test.dart#valid submission with a real touro persists a readable bullName (WR-01)"
        status: pass
      - kind: unit
        ref: "test/widget/atf_form_dialog_test.dart#valid submission with a real touro with breed persists \"#num — breed\" (WR-01)"
        status: pass
    human_judgment: false
  - id: D2
    description: "AtfHeaderCard never renders atf.bullAnimalId as Text; a legacy row (bullAnimalId set, bullName null) shows the 'Ver touro' placeholder and stays a tappable link to the animal's ficha."
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#bull link: legacy row (bullAnimalId set, bullName null) never renders the raw uuid (WR-01)"
        status: pass
    human_judgment: false

# Metrics
duration: 22min
completed: 2026-08-05
status: complete
---

# Phase 05 Plan 13: WR-01 Bull-Label Gap Closure Summary

**Shared `_bullLabel` function closes the write/display drift that left real-touro ATF headers showing a raw animal uuid instead of the dropdown's `#<numero> — <raça>` label.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-05T04:24:00Z
- **Completed:** 2026-08-05T04:46:29Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Extracted `String _bullLabel(AnimalWithContext aw)` in `atf_form_dialog.dart` as the single source of the bull display label; both the dropdown item builder and `_submit()`'s `createAtf` call now route through it, so the label shown at selection time and the label persisted to `bull_name` can never diverge again.
- Selecting a real touro now sends `bullName: '#<numero>'` (no breed) or `bullName: '#<numero> — <raça>'` (with breed) alongside `bullAnimalId`, closing WR-01's root cause on the write path.
- Hardened `AtfHeaderCard._buildBullValue` in `atf_detail_screen.dart`: the `Text` child fallback is now `atf.bullName ?? 'Ver touro'` instead of `atf.bullName ?? atf.bullAnimalId!` — no code path in the header can render a raw uuid as text, including for `atf_batches` rows created before this fix. `bullAnimalId` remains the `InkWell`'s navigation target only.
- Closed the test coverage gap the reviewer identified: added a widget test built on the actual production fixture shape (`bullAnimalId` set, `bullName` null) asserting the uuid literal is absent from the tree (`findsNothing`) and that `'Ver touro'` renders with the row still tappable.

## Task Commits

Each task was committed atomically:

1. **Task 1: One shared bull-label function, used by both the dropdown and the create call** - `dea6bf4` (fix)
2. **Task 2: AtfHeaderCard never renders a raw UUID, and the coverage gap the reviewer named is closed** - `5618c46` (fix)
3. **Task 3: Full-suite regression gate** - no commit (verification-only task; no files modified)

**Plan metadata:** pending (this SUMMARY commit)

_Note: TDD tasks here were verification-driven (tests updated alongside production code within the same task commit), not RED→GREEN→REFACTOR-staged — each task's test-file and source-file edits landed together since both files are in the plan's declared `files_modified` for that task._

## Files Created/Modified

- `lib/features/reproducao/presentation/atf_form_dialog.dart` - Added `_bullLabel(AnimalWithContext)`; dropdown items and `_submit()`'s `bullName:` argument both call it; added `animal_model.dart` import for the `AnimalWithContext` type.
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - `_buildBullValue`'s `Text` child fallback changed from `atf.bullAnimalId!` to `'Ver touro'`; navigation `onTap` target unchanged.
- `test/widget/atf_form_dialog_test.dart` - Added a with-breed `AnimalWithContext` fixture (`_touroComBreed`, `#13 — Nelore`); renamed and reasserted the real-touro submission test (`bullName` now `'#12'`, not `isNull`); added a new test for the with-breed label branch.
- `test/widget/atf_detail_screen_test.dart` - Added a test using a uuid-shaped `bullAnimalId` (`'11111111-2222-3333-4444-555555555555'`) with `bullName` null, asserting the uuid never appears as text, `'Ver touro'` renders, and the row stays tappable.

## Decisions Made

- Kept the em-dash (`—`, U+2014) byte-for-byte identical between the production label and the test assertions — verified via `cat -A` on both files to rule out a look-alike hyphen silently passing a wrong assertion.
- `_submit()` resolves the selected touro via `ref.read(animalListByPropertyProvider).asData?.value` (the same provider `build()` watches) and a null-safe `.where(...).firstOrNull` lookup — matching the existing `firstOrNull` idiom already used elsewhere in this codebase (e.g. `atf_detail_screen.dart`, `_canEdit`) rather than introducing a new dependency.
- No repository, model, or schema change — the fix is entirely presentation-layer, matching the plan's explicit "no `AtfRepository` join" decision (A-NO-READ-PATH-JOIN).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ran `dart run build_runner build` before the first `flutter analyze`**
- **Found during:** Task 1 (initial `flutter analyze` run)
- **Issue:** This worktree's generated files (`*.freezed.dart`, `*.g.dart` — gitignored, not part of the repo) did not exist yet, so `flutter analyze` reported 11 spurious `undefined_getter` errors on `Animal`/`AtfBatch` fields that are freezed-generated. Nothing to do with this plan's edits.
- **Fix:** Ran `dart run build_runner build` to generate the missing files (18 outputs written). No source changes.
- **Files modified:** none (generated files are gitignored, not committed)
- **Verification:** `flutter analyze` and `flutter test` both ran clean afterward.
- **Committed in:** n/a (gitignored generated output, never staged)

---

**Total deviations:** 1 auto-fixed (1 blocking, environment-only)
**Impact on plan:** No scope creep — a one-time worktree setup step, not a code change.

## Issues Encountered

None beyond the build_runner deviation above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- WR-01 is closed. New ATF creations with a real touro now round-trip a readable label with zero repository changes.
- `flutter test` baseline is now **212** (was 210 in 05-VERIFICATION.md; +1 from each of Task 1 and Task 2's new tests).
- `flutter analyze` baseline unchanged: exactly the same 4 pre-existing issues (2 info in `app_config.dart`/`propriedade_repository.dart`, 2 unused-import warnings in unrelated Phase-3-era test files — `test/widget/animais_screen_test.dart` and `test/widget/lote_form_dialog_test.dart`). Zero issues in either file this plan touched.
- `git diff --name-only` across both task commits lists exactly the four `files_modified` paths declared in this plan's frontmatter — no `supabase/` path, confirming zero overlap with plan 05-12's `register_baixa` migration work.
- **A-LEGACY-ROWS-NOT-BACKFILLED carried forward as-is:** pre-existing `atf_batches` rows created before this fix (if any exist in this environment) will show the `'Ver touro'` placeholder rather than a real label, since no data migration was part of this plan's scope.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-05*
