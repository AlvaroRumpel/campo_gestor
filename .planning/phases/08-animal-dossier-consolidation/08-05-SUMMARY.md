---
phase: 08-animal-dossier-consolidation
plan: 05
subsystem: frontend
tags: [flutter, expansiontile, reproducao, d-04, d-08, d-09]

# Dependency graph
requires:
  - phase: 08-animal-dossier-consolidation
    provides: "08-01 — ReproductiveHistoryEntry.dgRecords/bullName/implantationDate"
  - phase: 08-animal-dossier-consolidation
    provides: "08-02 — AnimalReproductiveHistorySection extracted as a standalone public widget"
  - phase: 08-animal-dossier-consolidation
    provides: "08-03 — the sanitary block's retry-button shape this plan mirrors"
provides:
  - "AnimalReproductiveHistorySection ATF rows show bull name, implantation date, and (when an ATF has 2+ DGs) an ExpansionTile revealing every DG (SC-2)"
  - "Reproductive block error state gains a scoped 'Tentar novamente' retry action (D-04)"
  - "First ExpansionTile usage in the project — copyable pattern for future phases"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ExpansionTile (Material 3 stdlib) with the existing tap-to-navigate InkWell nested inside `title` — inner recognizer wins taps on the summary text, outer tile handles taps on the trailing chevron, no extra state needed"
    - "Shared result→color helper function extracted once and reused by both the collapsed-row chip and the DG sub-row chip, preventing the switch from drifting between two call sites"
    - "Long free-text (DG observation) rendered as a Column sibling of a Wrap, not a Wrap member, so it inherits a bounded width and wraps across lines instead of overflowing"

key-files:
  created:
    - test/widget/animal_reproductive_history_section_test.dart
  modified:
    - lib/features/reproducao/presentation/animal_reproductive_history_section.dart

key-decisions:
  - "DG sub-row date uses a separate dd/MM/yyyy formatter (full year) distinct from the row's own dd/MM short formatter — a DG sub-row has no other context to imply which year, unlike the parent row's insemination/implantation dates read next to each other"
  - "DgRecord.result parsed with a non-null assertion (DgResult.fromDb(dg.result)!) rather than a fallback default, to avoid a second literal occurrence of any DgResult enum value name colliding with the acceptance criterion's single-occurrence grep on the shared color-mapping switch"
  - "Reused entry.dgRecords as delivered by the repository (already sorted most-recent-first via isLaterDg, per 08-01) — no re-sort in the presentation layer, keeping the single ordering rule at its one canonical site (G-05-4)"

patterns-established:
  - "First ExpansionTile in the codebase: nest the existing tappable summary widget directly as `title`, set `tilePadding: EdgeInsets.zero` to avoid a height jump versus rows with no chevron, and never pass `trailing` — the default chevron is the affordance itself"

requirements-completed: [ANIM-03]

coverage:
  - id: D1
    description: "ATF row shows bull name (when present) and implantation date; 0/1-DG ATFs render the unchanged collapsed row; 2+-DG ATFs gain an ExpansionTile revealing all DGs desc-sorted by exam date, each with date/chip/observation, observation wrapping (not truncating) at 360px"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_reproductive_history_section_test.dart — DG expansion + bull/implantation groups, 7/7 tests pass"
        status: pass
      - kind: automated_ui
        ref: "test/widget/animal_reproductive_history_section_test.dart — 360px width backstop test, tester.takeException() isNull"
        status: pass
      - kind: unit
        ref: "flutter analyze lib/features/reproducao — 0 issues"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tap on the ATF name text navigates to /atf/:atfId with or without the expand chevron present; tap on the chevron expands and does not navigate"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_reproductive_history_section_test.dart — navigation vs expansion coexist group, 2/2 tests pass"
        status: pass
    human_judgment: false
  - id: D3
    description: "Reproductive block error state renders the unchanged error copy plus a 'Tentar novamente' TextButton that invalidates only reproductiveHistoryByAnimalProvider(animalId); regression tests for the existing error/read-only assertions in animal_detail_screen_test.dart stay green"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_reproductive_history_section_test.dart — error and retry group, 3/3 tests pass"
        status: pass
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart — 14/14 tests pass, including 'error:' and 'read-only: the section renders no ChoiceChip and no button (D-13)'"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-11
status: complete
---

# Phase 8 Plan 5: DG Expansion, Bull/Implantation Fields, and Reproductive Retry Summary

**Closed SC-2 by giving `AnimalReproductiveHistorySection`'s ATF rows an `ExpansionTile` — the project's first use of the widget — that reveals every DG per ATF (not just the latest) when there are 2 or more, plus bull name/implantation date on the summary line and a scoped "Tentar novamente" retry on error, matching the sanitary block's 08-03 shape.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-08-11T21:15:00Z (approx.)
- **Completed:** 2026-08-11T21:50:00Z (approx.)
- **Tasks:** 3
- **Files modified:** 2 (1 existing, 1 new test file)

## Accomplishments
- `_ReproductiveHistoryRow`'s summary line now includes the ATF's implantation date (same short `dd/MM` formatter as insemination) and bull name (rendered only when non-null/non-blank — no dangling "touro: —"), sourced from the fields 08-01 already added to `ReproductiveHistoryEntry`.
- Introduced `entry.dgRecords.length > 1` as the sole gate for the expand affordance: 0- or 1-DG ATFs render byte-identical to before (verified by the full `animal_detail_screen_test.dart` regression, whose fixtures all carry `dgRecords: const []`); 2+-DG ATFs wrap the existing summary (InkWell included) as `ExpansionTile.title`, with a new private `_DgSubRow` per DG as `children`.
- Extracted `_dgResultColors(colorScheme, result)` — the collapsed row's chip and every DG sub-row's chip now share one switch statement instead of two independently-maintained copies.
- `_DgSubRow`'s observation text is a `Column` sibling of the date/chip `Wrap`, not a `Wrap` member — this is what makes a long observation actually wrap across lines at 360px instead of silently overflowing past the visible width (Wrap gives its children unconstrained main-axis width, so an unwrapped `Text` inside one would render on a single very-wide line; a `Column` child gets the ancestor's bounded width and wraps normally).
- Reproductive block's `error:` branch now matches the sanitary block's 08-03 shape exactly: unchanged error `Text` plus a `TextButton('Tentar novamente')` invalidating the family instance (`reproductiveHistoryByAnimalProvider(animalId)`), never the bare family.
- New `test/widget/animal_reproductive_history_section_test.dart` (16 tests) mounts `AnimalReproductiveHistorySection` directly — expansion visibility and SC-3 ordering (by Y-coordinate), bull/implantation field rendering, the navigate-vs-expand tap-target split (two independent tests, per this plan's explicit requirement not to assume one covers the other), retry behavior mirroring 08-03's induced-failure pattern, D-06/D-19 content-state guards, and the 360px observation-wrap backstop.

## Task Commits

Each task was committed atomically:

1. **Task 1: Linha de ATF com touro, data de implantação e expansão de todos os DGs (D-08, D-09, SC-2)** - `61705ec` (feat)
2. **Task 2: Ação de recarregar no bloco reprodutivo (D-04)** - `b6f8d8b` (feat)
3. **Task 3: Testes de widget da seção reprodutiva isolada (D-23, SC-2, SC-3, D-04)** - `3d63692` (test)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` - Added `_dgDateFmt`/`_dgResultColors` module-level helpers, enriched `_ReproductiveHistoryRow`'s summary with implantation date/bull name, added the `ExpansionTile` branch (≥2 DGs) with a new private `_DgSubRow` widget, and added the D-04 retry `TextButton` to the `error:` branch.
- `test/widget/animal_reproductive_history_section_test.dart` - NEW. 16 tests across 6 groups covering DG expansion, bull/implantation fields, navigation-vs-expansion tap-target split, retry, content states (D-06/D-19), and the 360px overflow backstop.

## Decisions Made
- None beyond what's captured in `key-decisions` above — the plan's action blocks were followed as written, including the explicit "reuse `entry.dgRecords` as delivered" instruction (no re-sort) and the "extract, don't duplicate" instruction for the color mapping.

## Deviations from Plan

None — plan executed exactly as written. All acceptance-criteria greps and behavior assertions passed on first run; no auto-fixes were needed.

## Issues Encountered

- Both Task 1 and Task 2's edits landed in the same single file (`animal_reproductive_history_section.dart`), which is unavoidable given both tasks touch that file per the plan's own `<files>` declaration. To keep the required one-commit-per-task discipline, the Task 2 hunk (the retry `TextButton`) was written, then temporarily reverted, Task 1 committed on its own, then the Task 2 hunk reapplied and committed separately — both intermediate states were independently verified (`flutter analyze` + `flutter test test/widget/animal_detail_screen_test.dart`) before each commit, so neither commit contains unverified code.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SC-2 (all ATFs with all their DGs, not just the latest) has automated proof for the first time; SC-3 (DG descending order) has a coordinate-comparison proof inside the expansion, matching the plan's existing pattern for the collapsed-row ordering guard.
- D-04 is now closed for both history blocks on the ficha (sanitary in 08-03, reproductive in this plan) — both invalidate only their own family instance, both render the same error+retry shape.
- The project has its first `ExpansionTile` usage, documented and copyable: nest the tappable summary as `title`, set `tilePadding: EdgeInsets.zero`, never pass `trailing`.
- `lib/features/sanitario/presentation/sanitary_history_section.dart` and `lib/features/animais/presentation/animal_detail_screen.dart` do not appear in this plan's diff — the D-37 boundary and the 08-02/08-04 territory split both held (confirmed via `git diff --stat` against both files).
- No blockers. Full test suite (337 tests) passes; `flutter analyze` on the touched feature directory (`lib/features/reproducao`) returns 0 issues. Repo-wide `flutter analyze` still exits 1 due to the same 4 pre-existing unrelated info/warning issues documented in 08-01/08-02/08-03 (none in files this plan touched) — not a regression introduced here.

---
*Phase: 08-animal-dossier-consolidation*
*Completed: 2026-08-11*

## Self-Check: PASSED
All created/modified files confirmed present on disk; all three task commits (61705ec, b6f8d8b, 3d63692) confirmed in git log.
