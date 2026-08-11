---
phase: 08-animal-dossier-consolidation
plan: 03
subsystem: frontend
tags: [flutter, riverpod, error-recovery, filter, d-04, d-17]

# Dependency graph
requires:
  - phase: 08-animal-dossier-consolidation
    provides: "08-02 — AnimalReproductiveHistorySection (public widget used as the sibling in the invalidation-scope test)"
  - phase: 06-sanitary-module-snapshot
    provides: "sanitary_history_section.dart — the D-37-locked file this plan adds a retry action into"
provides:
  - "Per-block retry action on both AnimalSanitaryHistorySection and LoteSanitaryHistorySection error states (D-04)"
  - "Exact-number-match bypass of the archived toggle in AnimaisScreen's in-memory filter (D-17)"
affects: [08-04, 08-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Riverpod family-instance ref.invalidate() triggered from a TextButton inside an error: branch — first in-repo instance of a manual retry affordance (previously only app-wide auto-retry via providerRetryPolicy existed)"
    - "ProviderScope(retry: (retryCount, error) => null) in widget tests that assert manual-retry behavior — disables Riverpod 3.x's built-in default retry/backoff so it cannot race the test's own invalidate() call"

key-files:
  created:
    - test/widget/sanitary_history_section_test.dart
  modified:
    - lib/features/sanitario/presentation/sanitary_history_section.dart
    - lib/features/animais/presentation/animais_screen.dart
    - test/widget/animais_screen_test.dart

key-decisions:
  - "Task 1 test file disables the ProviderScope's default retry policy (Riverpod 3.x's ProviderContainer.defaultRetry, ~200ms backoff) — without it, the app-wide auto-retry (main.dart's providerRetryPolicy) raced the manual-tap assertions and made the test flaky/wrong, since it would silently resolve the induced failure before the test's own tap fired"
  - "D-17's exact-match test needed a second archived animal with a multi-digit number (#125) because a single-digit archived animal (#5) has no non-empty proper substring to prove the partial-match-still-respects-toggle branch"

patterns-established: []

requirements-completed: [ANIM-03]

coverage:
  - id: D1
    description: "Sanitary block error state (both animal and lote variants) renders the unchanged error copy plus a 'Tentar novamente' TextButton that invalidates only that block's own family instance"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/sanitary_history_section_test.dart — 4/4 tests pass, including the invalidation-scope test proving the sibling reproductive provider's call count stays at 1"
        status: pass
      - kind: unit
        ref: "grep -c 'Tentar novamente' == 2; grep for both ref.invalidate(...) family-instance calls present"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-37 boundary held: the diff to sanitary_history_section.dart touches only the two error: branches; sanitary_application_repository.dart absent from the diff"
    requirement: "ANIM-03"
    verification:
      - kind: unit
        ref: "git diff --unified=0 -- lib/features/sanitario/presentation/sanitary_history_section.dart — confirmed the two hunks are contained in the error: branches; grep confirms both untouched copy strings still occur exactly once"
        status: pass
    human_judgment: false
  - id: D3
    description: "AnimaisScreen search by exact animal number finds an archived animal with the 'Mostrar arquivados' toggle off; a partial/substring match still respects the toggle; every archived animal shown always carries its baixa-reason badge"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animais_screen_test.dart — D-17 group, 4/4 tests pass (exact match found, partial match hidden, empty search hidden, badge present)"
        status: pass
      - kind: unit
        ref: "flutter analyze lib/features/animais/presentation/animais_screen.dart — 0 issues (no unused-parameter warning after removing showArchived)"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-11
status: complete
---

# Phase 8 Plan 3: Sanitary Block Retry (D-04) and Archived-Animal Number Search (D-17) Summary

**Added a scoped "Tentar novamente" retry action to both sanitary-history error branches without touching anything else in the D-37-locked file, and made AnimaisScreen's exact-number search bypass the archived toggle so a sold/dead animal's dossier stays reachable — coupling in the fix that keeps its badge from silently disappearing.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-11T18:09:00Z (approx.)
- **Completed:** 2026-08-11T18:24:01Z
- **Tasks:** 2
- **Files modified:** 4 (1 new test file, 3 existing files)

## Accomplishments
- `sanitary_history_section.dart`: both `_AnimalSanitaryHistorySectionState.build()` and `_LoteSanitaryHistorySectionState.build()` error branches now wrap their unchanged `_SectionMessage` in a `Column` alongside a `TextButton('Tentar novamente')` whose `onPressed` invalidates only that block's own family instance (`sanitaryHistoryByAnimalProvider(widget.animalId)` / `sanitaryApplicationsByLotProvider(widget.lotId)`) — verified mechanically via `git diff --unified=0` that no other line in the file changed.
- New `test/widget/sanitary_history_section_test.dart` mounts `AnimalSanitaryHistorySection` directly (not the whole ficha) and covers: error+button render, retry-success transition, invalidation scope (the sibling `AnimalReproductiveHistorySection`'s provider call count stays at 1 after the sanitary retry), and no-button-on-success.
- `animais_screen.dart`: the in-memory `.where(...)` filter now computes `isExactNumberMatch` (query non-empty AND equal, not `contains`, to the animal's number) and only excludes an archived animal when the toggle is off **and** it isn't an exact match — a partial/substring query still respects the toggle.
- Coupled fix (plan-mandated, not scope creep): `_AnimalListTile`'s archived badge was gated on `isArchived && showArchived`, which would have rendered a sold/dead animal surfaced by the D-17 bypass with no badge. The badge now depends only on `isArchived`; the now-unused `showArchived` parameter/field was removed from `_AnimalListTile`.
- New D-17 test group in `test/widget/animais_screen_test.dart` (4 tests) using a second archived animal with a multi-digit number (#125) to exercise a genuinely partial (non-equal) search query, since the original single-digit archived fixture (#5) has no proper non-empty substring.

## Task Commits

Each task was committed atomically:

1. **Task 1: Ação de recarregar no bloco sanitário (D-04)** - `13e10e3` (feat)
2. **Task 2: Busca por número exato encontra animal com baixa (D-17)** - `4756540` (fix)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `lib/features/sanitario/presentation/sanitary_history_section.dart` - Added the retry `TextButton` to both `error:` branches only. `_buildAnimalRow`, `_buildLoteRow`, `visibleApplications`, `reversedApplicationIds`, `_SanitaryHistoryCardShell`, `_HistoryRowShell`, `_VerTodasButton`, `_badgeLabel`, and both `loading:`/`data:` branches are byte-identical to before (D-37 held).
- `test/widget/sanitary_history_section_test.dart` - NEW. 4 widget tests covering the D-04 retry behavior and its D-37-adjacent invalidation-scope guarantee.
- `lib/features/animais/presentation/animais_screen.dart` - Added the D-17 exact-match bypass to the archived-exclusion condition; removed `_AnimalListTile.showArchived` and its now-unconditional badge gate.
- `test/widget/animais_screen_test.dart` - Added a 4-test D-17 group.

## Decisions Made
- Disabled `ProviderScope`'s default retry (Riverpod 3.x auto-retry with backoff) in the new sanitary retry tests — see `key-decisions` above; without it the app-wide `providerRetryPolicy` from `main.dart` raced the manual-tap assertions and produced flaky/incorrect results (the induced failure would silently self-heal via auto-retry before the test's own tap).
- Used a second, multi-digit archived fixture animal (#125) for the D-17 partial-match test rather than reusing the existing #5 fixture, because a single-digit number has no non-empty proper substring to search on.

## Deviations from Plan
None — plan executed exactly as written, including the mandated coupled badge fix in Task 2's `<action>` block (not treated as scope creep, per the plan's own framing).

## Issues Encountered
- Riverpod 3.x's `ProviderContainer.defaultRetry` (min 200ms backoff, applied to any provider unless explicitly disabled) auto-retried the induced test failure in the sanitary retry tests before the manual tap fired, causing two of the four new tests to fail non-deterministically until `retry: (retryCount, error) => null` was added to those tests' `ProviderScope`. Resolved inline (test-only change, not a Rule 1-3 deviation against the plan's library code — it only affects the test harness).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- D-04 and D-17 are both closed; the sanitary-history D-37 boundary remains intact and mechanically re-verifiable (grep + `git diff --unified=0`) for any future phase touching this file.
- `AnimalSanitaryHistorySection` now has its own standalone widget test file (`test/widget/sanitary_history_section_test.dart`), giving future D-37-adjacent work a fast, isolated place to add coverage without going through the whole ficha.
- No blockers. Full test suite (321 tests) and repo-wide `flutter analyze` (0 errors; the same 4 pre-existing unrelated info/warning issues from 08-01/08-02, none in files this plan touched) both green.

---
*Phase: 08-animal-dossier-consolidation*
*Completed: 2026-08-11*

## Self-Check: PASSED
All created/modified files confirmed present on disk; both task commits (13e10e3, 4756540) confirmed in git log.
