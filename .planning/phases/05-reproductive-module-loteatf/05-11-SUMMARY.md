---
phase: 05-reproductive-module-loteatf
plan: 11
subsystem: ui
tags: [flutter, riverpod, go_router, widget-tests]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf
    provides: BaixaDialog (ANIM-04/D-17), AtfDetailScreen (05-04/05-06/05-08/05-09), atf_repository.dart provider families
provides:
  - BaixaDialog invalidates the whole atfActiveMembershipsProvider / atfMembershipsProvider / atfListByPropertyProvider families on a successful baixa
  - AtfDetailScreen renders a BackButton in all four AppBar states with a context.canPop()/pop() + AppRoutes.reproducao fallback
affects: [05-UAT tests 2/3/4 (gated on test 1), gsd-verify-work 05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Whole-family ref.invalidate() when a caller only has an entity id and no way to learn the parent id it would need for a per-id invalidation (documented inline as a deliberate deviation from the per-id idiom used elsewhere in the same feature)."
    - "Shared _backButton(context) helper referenced by every AppBar branch of a multi-state ConsumerWidget, rather than repeating the same leading: closure four times."

key-files:
  created: []
  modified:
    - lib/features/animais/presentation/baixa_dialog.dart
    - test/widget/baixa_dialog_test.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "BaixaDialog invalidates atfActiveMembershipsProvider/atfMembershipsProvider/atfListByPropertyProvider as bare families (no id argument) because it only knows the animal, not its atfBatchId — the one place in the reproducao feature that deviates from the per-id invalidation idiom used by encerrar_atf_dialog.dart and atf_animal_selection_screen.dart."
  - "AtfDetailScreen's back-button fallback is a single flat AppRoutes.reproducao target (no parent-entity reconstruction like lote_detail_screen.dart's paddock fallback) because /atf/:atfId has no parent route to return to — the ATF list lives at the reproducao shell branch."

requirements-completed: [REPR-01, REPR-02, REPR-05]

coverage:
  - id: D1
    description: "BaixaDialog._submit() invalidates atfActiveMembershipsProvider, atfMembershipsProvider, and atfListByPropertyProvider on the success path, so the ATF detail screen stops serving a stale post-baixa composition (G-05-1)."
    requirement: "REPR-02"
    verification:
      - kind: unit
        ref: "test/widget/baixa_dialog_test.dart#G-05-1: BaixaDialog invalidates ATF composition providers a successful baixa rebuilds atfActiveMembershipsProvider, atfMembershipsProvider, and atfListByPropertyProvider once each"
        status: pass
    human_judgment: false
  - id: D2
    description: "AtfDetailScreen renders a BackButton in every AppBar state (loading/error/null-data/loaded-data), falling back to /reproducao when there is no navigation history (G-05-1-nav)."
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#back control (G-05-1-nav) loading state renders a BackButton"
        status: pass
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#back control (G-05-1-nav) error state renders a BackButton"
        status: pass
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#back control (G-05-1-nav) null-ATF state renders a BackButton"
        status: pass
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#back control (G-05-1-nav) loaded-data state renders a BackButton"
        status: pass
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#back control (G-05-1-nav) tapping the back control with no navigation history lands on /reproducao"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-05
status: complete
---

# Phase 5 Plan 11: Gap Closure — ATF Composition Cache Invalidation + Detail-Screen Back Control Summary

**Closed both 05-UAT test-1 blockers: BaixaDialog now invalidates the ATF composition provider family on success (G-05-1), and AtfDetailScreen's AppBar always renders a working back control (G-05-1-nav).**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2/2 completed
- **Files modified:** 4 (2 production, 2 test)

## Accomplishments

- `BaixaDialog._submit()` now invalidates `atfActiveMembershipsProvider`, `atfMembershipsProvider`, and `atfListByPropertyProvider` (whole families, no id — BaixaDialog has no way to learn the animal's `atfBatchId`) immediately after the existing `reproductiveHistoryByAnimalProvider(...)` invalidation on the success path. A regression test using a real `ProviderContainer` proves each provider rebuilds exactly once post-baixa.
- `AtfDetailScreen` gained a shared `_backButton(context)` helper (`context.canPop()` → `context.pop()`, else `context.go(AppRoutes.reproducao)`) wired into all four `AppBar` instances (loading, error, null-ATF, loaded-data). A routed widget-test harness with a real `GoRouter` proves the no-history fallback lands on `/reproducao`; four presence assertions cover every AppBar state.
- Full regression suite green: 210/210 tests pass, `flutter analyze` clean (only pre-existing, out-of-scope info/warning lints remain in files this plan did not touch).

## Task Commits

Each task was committed atomically:

1. **Task 1: BaixaDialog invalidates the ATF composition providers (G-05-1)** - `e4a84cd` (feat)
2. **Task 2: Back control on every AtfDetailScreen AppBar state (G-05-1-nav)** - `c9e6303` (feat)
3. **Follow-up lint fix (Task 1 scope, discovered while confirming the full-suite `flutter analyze` gate)** - `9de0267` (fix)

**Plan metadata:** committed together with this SUMMARY (worktree mode — STATE.md/ROADMAP.md updates deferred to the orchestrator).

## Files Created/Modified

- `lib/features/animais/presentation/baixa_dialog.dart` - `_submit()` now invalidates the three ATF composition providers on success; class doc comment updated to list all invalidations.
- `test/widget/baixa_dialog_test.dart` - New `ProviderContainer`-based harness (`_buildDialogWithContainer`) plus a G-05-1 regression group asserting each of the three providers rebuilds exactly once.
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - Added `_backButton(context)` helper; wired into all four `AppBar` `leading:` slots; class doc comment updated to mention the 05-11 addition.
- `test/widget/atf_detail_screen_test.dart` - New `_buildRoutedScreen` GoRouter harness plus a `back control (G-05-1-nav)` group: four AppBar-state presence assertions and one routed no-history-fallback behavioral test.

## Decisions Made

- Whole-family (no-id) `ref.invalidate()` in `BaixaDialog` is deliberate and documented inline — the only place in the reproducao feature that departs from the per-id invalidation idiom used by `encerrar_atf_dialog.dart` and `atf_animal_selection_screen.dart`, because `BaixaDialog` is only ever given an `Animal`, never an ATF id.
- `AtfDetailScreen`'s back-button fallback target is a single flat `AppRoutes.reproducao`, not a reconstructed parent-entity path like `lote_detail_screen.dart`'s paddock fallback — `/atf/:atfId` has no parent route; the ATF list lives at the `reproducao` shell branch.
- Did not invalidate `atfByIdProvider` from `BaixaDialog` per the plan's explicit instruction — baixa changes membership rows, not the `atf_batches` row itself, and the header's %-prenhez recomputes from the memberships/DG providers that are already invalidated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing generated freezed/json_serializable files in the worktree**
- **Found during:** Task 1 (first `flutter test` attempt)
- **Issue:** This git worktree had no `*.g.dart` / `*.freezed.dart` files checked out (they are gitignored, generated locally), so every model using `@freezed`/`@JsonSerializable` failed to compile (`AtfBatch`, `DgRecord`, `Animal`, etc.) — a whole-repo compile blocker unrelated to this plan's edits but blocking every test run in this environment.
- **Fix:** Ran `dart run build_runner build` in the worktree to regenerate the missing files.
- **Files modified:** none tracked by git (generated files are gitignored, not committed).
- **Verification:** `flutter test` compiled and ran successfully afterward.

**2. [Rule 1 - Bug] `unnecessary_underscores` lint on new no-op listener callbacks**
- **Found during:** Full-suite `flutter analyze` verification (plan's overall `<verification>` step, after both tasks were committed)
- **Issue:** The G-05-1 regression test's `container.listen(...)` no-op callbacks used `(_, __) {}`, which `flutter analyze` flags under Dart 3's wildcard-variable rules (repeated distinct underscore names are unnecessary).
- **Fix:** Changed all three callbacks to `(_, _) {}`.
- **Files modified:** `test/widget/baixa_dialog_test.dart`
- **Verification:** `flutter test test/widget/baixa_dialog_test.dart` (6/6 pass) and `flutter analyze test/widget/baixa_dialog_test.dart` (no issues) re-run after the fix; committed separately as `9de0267` since Task 1's commit (`e4a84cd`) had already landed.

---

**Total deviations:** 2 auto-fixed (1 blocking environment fix, 1 lint bug)
**Impact on plan:** Neither affected plan scope or the shipped behavior. The build_runner run only regenerated gitignored derived files (no diff to commit); the lint fix is a 3-line change to the test added in this same plan.

## Issues Encountered

- **Directory-drift near-miss:** an early verification attempt ran `cd F:/_geral/Projetos/campo_gestor && flutter test ...` (the plan's literal verify command), which executed against the main repo checkout instead of this worktree — silently running the OLD, unmodified test file and reporting a stale "all tests passed" result with the wrong test count. Caught by noticing the new G-05-1 test never appeared in the run output. All subsequent verification commands were run with the worktree's own absolute path as the explicit `cd` target.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both G-05-1 (blocker) and G-05-1-nav (minor) gaps from 05-UAT.md test 1 are closed at the code level. `flutter analyze` is clean and the full `flutter test` suite is green (210/210).
- Per the plan's `<verification>` note, live confirmation of D-19 end-to-end is intentionally NOT duplicated here — re-run `/gsd-verify-work 05` next; the `gap_ids: [G-05-1, G-05-1-nav]` frontmatter links this plan's SUMMARY to those UAT findings so they reconcile instead of re-diagnosing, and 05-UAT.md tests 2, 3, and 4 (gated on test 1) can proceed from there.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-05*

## Self-Check: PASSED

All 4 modified source/test files and all 4 commits (`e4a84cd`, `c9e6303`, `9de0267`, and this SUMMARY's own commit `4223851`) verified present on disk / in `git log --oneline --all`.
