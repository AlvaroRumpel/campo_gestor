---
phase: 05-reproductive-module-loteatf
plan: 14
subsystem: reproducao
tags: [flutter, dart, tie-breaker, gap-closure, dg-records]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf
    provides: dg_summary.dart, atf_repository.dart, atf_detail_screen.dart (05-02, 05-06, 05-08)
provides:
  - "isLaterDg(candidate, current): the single shared exam-date-primary / created-at-secondary DG tie-break comparison"
  - "All three former independent tie-break sites (summarizeDg, fetchReproductiveHistory, _DgSectionState._mostRecentDg) converted to isLaterDg"
affects: [reproducao, 05-UAT, phase-8-animal-dossier]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single shared comparison function for a rule with multiple call sites, instead of one loop-condition copy per site"

key-files:
  created: []
  modified:
    - lib/features/reproducao/data/dg_summary.dart
    - lib/features/reproducao/data/atf_repository.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/features/reproducao/dg_summary_test.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "isLaterDg lives in dg_summary.dart (already imported by all three consumers) rather than a new shared module, per plan's key_links constraint of zero new imports"
  - "No new test added for atf_repository.dart's fetchReproductiveHistory site — atf_repository_test.dart is contract-only by documented convention (Supabase query-builder mocking is brittle); the moved logic (isLaterDg) is already covered directly by dg_summary_test.dart"

requirements-completed: [REPR-03, REPR-04, REPR-05]

coverage:
  - id: D1
    description: "isLaterDg shared comparison function: exam_date primary, created_at secondary tie-break"
    requirement: "REPR-04"
    verification:
      - kind: unit
        ref: "test/features/reproducao/dg_summary_test.dart#isLaterDg (A-DG-ORDER, G-05-4)"
        status: pass
    human_judgment: false
  - id: D2
    description: "summarizeDg (% prenhez) routes through isLaterDg — greater-examDate record wins even when inserted first"
    requirement: "REPR-04"
    verification:
      - kind: unit
        ref: "test/features/reproducao/dg_summary_test.dart#summarizeDg regression: greater-examDate record wins even when it was inserted first (G-05-4)"
        status: pass
    human_judgment: false
  - id: D3
    description: "AtfRepository.fetchReproductiveHistory's lastDgByAtf loop routes through isLaterDg (REPR-05 ficha last-DG display)"
    requirement: "REPR-05"
    verification: []
    human_judgment: true
    rationale: "atf_repository_test.dart is contract-only by documented project convention (mocking the Supabase query-builder chain is brittle); the moved comparison logic is unit-tested directly via isLaterDg, but the call site itself has no automated test — needs a human/manual check against a live ATF with two DGs to confirm lastDgDate/lastDgResult agree."
  - id: D4
    description: "_DgSectionState._mostRecentDg drives DG chip preselection AND the save_dg_records payload carry-forward, both via isLaterDg"
    requirement: "REPR-03"
    verification:
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#G-05-4: DG chip preselection follows examDate, not insertion order"
        status: pass
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#G-05-4: with no chip touched, an observation-only save carries forward the greater-examDate result"
        status: pass
    human_judgment: false

# Metrics
duration: 34min
completed: 2026-08-05
status: complete
---

# Phase 5 Plan 14: Fix DG tie-breaker to use exam_date, not created_at (G-05-4) Summary

**Closed G-05-4 by adding one shared `isLaterDg` comparison (exam-date primary, created-at secondary) and routing all three previously-independent DG "latest wins" loops through it.**

## Performance

- **Duration:** 34 min
- **Started:** 2026-08-05T16:31:00-03:00
- **Completed:** 2026-08-05T17:05:03-03:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added `isLaterDg(candidate, current)` to `dg_summary.dart`: primary comparison on `examDate.compareTo`, secondary tie-break on `createdAt.isAfter` for exact same-date exams
- Rewired `summarizeDg`'s reduction loop (% prenhez) through `isLaterDg`, replacing the old `createdAt`-only comparison
- Rewired `AtfRepository.fetchReproductiveHistory`'s per-ATF `lastDgByAtf` loop (REPR-05 ficha) through `isLaterDg`
- Rewired `_DgSectionState._mostRecentDg` (DG chip preselection AND the `save_dg_records` carry-forward payload for observation-only rows) through `isLaterDg` — the highest-stakes of the three sites, since it affects what gets written, not only what gets displayed
- Removed the stale, overruled A-DG-ORDER rationale ("createdAt wins because examDate is untrustworthy") from all four doc comments that carried it
- Added 4 new unit tests in `dg_summary_test.dart` (3 direct `isLaterDg` tests + 1 `summarizeDg` regression) and 2 new widget tests in `atf_detail_screen_test.dart` proving the chip-preselection and save-payload behavior

## Task Commits

Each task was committed atomically:

1. **Task 1: One shared DG comparison in dg_summary.dart, used by summarizeDg (G-05-4)** - `1ac7936` (feat)
2. **Task 2: Convert the other two tie-breaker sites to isLaterDg (G-05-4)** - `a9e753e` (fix)

_No separate plan-metadata commit in worktree mode — the orchestrator commits SUMMARY.md/STATE.md/ROADMAP.md centrally after the wave merges._

## Files Created/Modified
- `lib/features/reproducao/data/dg_summary.dart` - Added `isLaterDg`; rewired `summarizeDg`; fixed doc comment
- `lib/features/reproducao/data/atf_repository.dart` - Rewired `fetchReproductiveHistory`'s `lastDgByAtf` loop; fixed doc comments
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - Rewired `_DgSectionState._mostRecentDg`; fixed doc comment
- `test/features/reproducao/dg_summary_test.dart` - Widened `_dg` helper with optional `examDate`; renamed D-12 test; added `isLaterDg` group (3 tests) + 1 `summarizeDg` regression test
- `test/widget/atf_detail_screen_test.dart` - Widened `_dg` helper with optional `examDate`/`createdAt`/`id`; added 2 G-05-4 tests (preselection + observation-only save payload)

## Decisions Made
- `isLaterDg` placed in `dg_summary.dart` (not a new file) — all three consumers already import it, satisfying the plan's "no new imports at any of the three sites" constraint
- No new automated test for the `atf_repository.dart` site (Site A) — the file's test suite is documented as contract-only because mocking Supabase's query-builder chain is brittle; the underlying logic is fully covered by `isLaterDg`'s direct unit tests. Recorded as `human_judgment: true` in the coverage block (D3) so a verifier can flag it for manual/live confirmation rather than silently treating it as proven.

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched their `<action>` and `<done>` specifications; all grep gates and `flutter analyze`/`flutter test` checks passed on the first attempt with no auto-fixes required.

## Issues Encountered

**Generated freezed/json_serializable files were missing in this worktree.** `flutter test` initially failed with "Type '_$DgRecord' not found" because `*.g.dart`/`*.freezed.dart` are gitignored and this is a fresh git worktree that had never run codegen. Ran `flutter pub get` then `dart run build_runner build` once at the start of execution to generate them — not a plan deviation, just worktree environment setup, and no plan file was touched to resolve it.

## Next Phase Readiness

- G-05-4 fully closed: `isLaterDg` is the sole tie-break implementation, all three call sites route through it, and the overruled A-DG-ORDER rationale is gone from every doc comment.
- No database change and no migration was needed — `exam_date`/`created_at` were already both stored on every `dg_records` row.
- Full-suite regression (`flutter analyze`, `flutter test`) is green: 223/223 tests pass, 0 analyzer issues in files touched by this plan (4 pre-existing, unrelated info/warning-level issues remain elsewhere in the codebase, untouched by this plan).
- `AtfRepository.fetchReproductiveHistory`'s new behavior (Site A / REPR-05 ficha) has no direct automated test per the file's documented contract-only test convention — flagged in the coverage block (D3) for a human/manual UAT pass if one is desired before considering REPR-05 fully closed.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-05*

## Self-Check: PASSED

- FOUND: lib/features/reproducao/data/dg_summary.dart
- FOUND: lib/features/reproducao/data/atf_repository.dart
- FOUND: lib/features/reproducao/presentation/atf_detail_screen.dart
- FOUND: test/features/reproducao/dg_summary_test.dart
- FOUND: test/widget/atf_detail_screen_test.dart
- FOUND commit: 1ac7936
- FOUND commit: a9e753e
