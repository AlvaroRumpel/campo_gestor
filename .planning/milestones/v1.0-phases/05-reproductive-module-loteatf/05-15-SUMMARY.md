---
phase: 05-reproductive-module-loteatf
plan: 15
subsystem: ui
tags: [flutter, riverpod, atf, dg, reproductive-module, gap-closure]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf
    provides: "05-14's isLaterDg tie-breaker and the full AtfDetailScreen/atf_repository surface this plan edits"
provides:
  - "AtfMembershipView.animalDeleted, sourced from a new deleted_at column in fetchMemberships's embedded animals select"
  - "_DgSection row filter that hides baixa'd (archived) animals from Registrar DG while still rendering closed-ATF (D-16) rows"
  - "A single hoisted dgAnimalIds/pendingMembers derivation in AtfDetailScreen.build shared by the encerrar banner gate, the AppBar pendingCount, the banner's own dialog, and _CompositionSection's per-row hasDg check"
affects: [05-reproductive-module-loteatf, 05-UAT]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hoist one derived Set/count in the parent build method and pass it down as a plain field, instead of letting each child widget re-derive its own copy from raw records — the four-consumer G-05-3 fix is this pattern applied to atf_detail_screen.dart."

key-files:
  created: []
  modified:
    - lib/features/reproducao/data/atf_model.dart
    - lib/features/reproducao/data/atf_repository.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "dg_summary.dart is untouched by user decision (2026-08-05) — D-20's historical DG total stays correct for the % prenhez header; both gaps were misuse of that function at call sites, not defects inside it (verified via a zero-line git diff on the file)."
  - "AtfMembershipView.animalDeleted is required, not defaulted, so a future construction site cannot silently reintroduce the G-05-2 bug without a compile error."

patterns-established:
  - "A membership's `active` flag means two different things (ATF closed vs. animal baixa'd) with no Dart-side signal to tell them apart before this plan — animalDeleted is now the disambiguating signal; do not filter DG rows on `active` alone."

requirements-completed: [REPR-02, REPR-03, REPR-04]

coverage:
  - id: D1
    description: "A baixa'd animal's membership no longer renders as an editable row in Registrar DG, while a closed-but-not-baixa'd ATF still renders every row for D-16 correction (G-05-2)."
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#G-05-2: a membership whose animal was archived by a baixa renders no row, while a normal member still renders its 3 chips"
        status: pass
      - kind: automated_ui
        ref: 'test/widget/atf_detail_screen_test.dart#G-05-2: "Registrar DG" is hidden entirely when every membership is an archived animal'
        status: pass
      - kind: automated_ui
        ref: 'test/widget/atf_detail_screen_test.dart#the DG chips are tappable for a CLOSED ATF while "+ Animais" stays absent (D-16)'
        status: pass
    human_judgment: false
  - id: D2
    description: "The encerrar banner and its own confirm dialog agree on the pending count, computed from current composition members rather than the historical DG total (G-05-3)."
    requirement: "REPR-04"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#G-05-3: the banner does not render when composition churn leaves the historical DG total at the composition count but none of the CURRENT members are covered"
        status: pass
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#G-05-3: the AppBar encerrar dialog reports the same churn-case pending count as the banner, never a contradicting zero"
        status: pass
    human_judgment: false
  - id: D3
    description: "dg_summary.dart's D-20 historical-total behavior for the % prenhez header is unchanged (zero-line diff)."
    verification:
      - kind: other
        ref: "git diff --stat lib/features/reproducao/data/dg_summary.dart (empty)"
        status: pass
    human_judgment: false

duration: ~30min
completed: 2026-08-06
status: complete
---

# Phase 05 Plan 15: AtfDetailScreen Rendering/Gating Gap Closure Summary

**Added `AtfMembershipView.animalDeleted` (from a new `deleted_at` column in `fetchMemberships`) to hide baixa'd animals from Registrar DG, and hoisted a single `dgAnimalIds`/`pendingMembers` derivation so the encerrar banner, its AppBar action, its confirm dialog, and the composition remove-gate can never disagree again.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-08-06
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- G-05-2: a baixa'd animal's membership no longer renders as an editable "Registrar DG" row; closed-ATF (not baixa'd) memberships still render their full roster for D-16 correction.
- G-05-3: the encerrar banner now gates on a live "every CURRENT member has a DG" check instead of `summarizeDg(...).pending`'s historical total, so a churned composition can no longer show a false "all done" banner that its own confirm dialog contradicts.
- The banner's gate, the AppBar `IconButton`'s `pendingCount`, `_EncerrarBanner`'s own dialog call, and `_CompositionSection`'s per-row `hasDg` check now all read from one hoisted `dgAnimalIds`/`pendingMembers` pair computed once in `AtfDetailScreen.build`.
- `dg_summary.dart` has a confirmed zero-line diff — the % prenhez math (D-20) is untouched, per the user's 2026-08-05 decision.

## Task Commits

Each task was committed atomically:

1. **Task 1: Hide baixa'd animals from the Registrar DG list (G-05-2)** - `1d2827b` (fix)
2. **Task 2: Gate the encerrar banner on current members, not the historical DG total (G-05-3)** - `e8fc841` (fix)

_Both tasks were `tdd="true"`; the RED (failing-first) tests are the two G-05-2 tests and two G-05-3 tests listed under Coverage above, added in the same commit as their corresponding production fix since the plan called for combined test+implementation commits per task rather than separate RED/GREEN commits._

## Files Created/Modified
- `lib/features/reproducao/data/atf_model.dart` - `AtfMembershipView` gained a required `animalDeleted` field.
- `lib/features/reproducao/data/atf_repository.dart` - `fetchMemberships` now selects `animals(number, category, deleted_at)` and populates `animalDeleted`.
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - `_DgSectionState.build` filters archived rows; `AtfDetailScreen.build` hoists `dgAnimalIds`/`pendingMembers`; `_EncerrarBanner` and `_CompositionSection` now take those derived values instead of re-deriving or hardcoding them.
- `test/widget/atf_detail_screen_test.dart` - `_membership` helper gained `animalDeleted`; four new regression tests (two per gap).

## Decisions Made
- Kept `dg_summary.dart` completely untouched, per the explicit user decision recorded in the plan's objective — both gaps were misuse of `summarizeDg` at call sites, not defects in the function itself.
- Made `animalDeleted` a required constructor parameter (not defaulted to `false`) so a future construction site can't silently reintroduce the G-05-2 bug.

## Deviations from Plan

None — plan executed exactly as written. One environment note, not a plan deviation: the worktree had no generated `*.g.dart`/`*.freezed.dart` files (gitignored, never built in this checkout); ran `dart run build_runner build` once before the first test run to generate them. This is standard Flutter/freezed project setup, not a code change, and produced no diff in tracked files.

## Issues Encountered
None beyond the build_runner generation step noted above.

## User Setup Required
None - no external service configuration required. No database change and no migration — `animals.deleted_at` already existed and is already populated by `register_baixa`; this plan only started selecting it.

## Next Phase Readiness
- This was the last incomplete plan in Phase 05 (05-01 through 05-15 now all complete).
- `gap_ids: [G-05-2, G-05-3]` links this SUMMARY to `05-UAT.md` test 3 so `/gsd-verify-work 05` can reconcile both gaps against this plan instead of re-diagnosing them.
- Live re-verification of the two user-reported symptoms (step 9's DG list, step 11's banner) remains 05-UAT.md test 3's job — this plan closed the code-level gap and added regression tests, but did not re-run the original manual UAT script.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-06*

## Self-Check: PASSED

All 4 modified files found on disk, SUMMARY.md found on disk, and both task
commits (`1d2827b`, `e8fc841`) found in `git log`.
