---
phase: 05-reproductive-module-loteatf
plan: 09
subsystem: ui
tags: [flutter, riverpod, confirm-dialog, banner, encerramento]

# Dependency graph
requires:
  - phase: 05-02
    provides: atfByIdProvider, atfActiveMembershipsProvider, atfMembershipsProvider, atfListByPropertyProvider, DgSummary.pending
  - phase: 05-03
    provides: close_atf RPC (role/active guard, atomic membership deactivation), wrapped by AtfRepository.closeAtf
  - phase: 05-08
    provides: AtfDetailScreen's ListView with AtfHeaderCard/_CompositionSection/_DgSection, the canEdit role gate
provides:
  - EncerrarAtfDialog — the manual encerramento confirmation dialog (D-15)
  - AtfDetailScreen's AppBar "Encerrar ATF" action and _EncerrarBanner
  - The completed encerramento affordance set: closure is reachable, role-gated, confirmed, and never automatic
affects: [05-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Non-optimistic close: closeAtf is awaited, then all 4 provider invalidations run, then the dialog pops(true) — mirrors BaixaDialog's ordering but the pop moves after the invalidations, not before, since D-16 correction depends on those providers being fresh the instant the caller's SnackBar fires"
    - "Banner ownership split: the parent screen computes and gates the show/hide condition (active && canEdit && composition non-empty && pending==0); the banner widget itself only owns its own session-local dismissal bool — keeps the D-15 business rule in one place instead of duplicating it into the dismissible widget"

key-files:
  created:
    - lib/features/reproducao/presentation/encerrar_atf_dialog.dart
  modified:
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "The pending-DG warning line uses a real pt-BR singular/plural conditional ('1 animal sem DG' / 'N animais sem DG') rather than the literal '(is)' shorthand appearing in the plan/UI-SPEC copy text — matches the actual established Phase 4 pattern (WR-04, MoverLoteDialog) the plan referenced, not a literal parenthesized string."
  - "AtfDetailScreen shows a 'ATF encerrado.' SnackBar itself after the dialog pops true, in a small shared _showEncerrarDialog helper used by both the AppBar action and the banner — the dialog's own Task 1 scope stops at invalidate+pop per the plan text, so the success confirmation named in 05-UI-SPEC section 5 lives at the call site instead."

patterns-established: []

requirements-completed: [REPR-03, REPR-04]

coverage:
  - id: D1
    description: "EncerrarAtfDialog renders the fixed body prose in a 400px-wide content area, matching 05-UI-SPEC section 5"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#body prose renders and the dialog content is 400 wide"
        status: pass
    human_judgment: false
  - id: D2
    description: "The pending-DG warning line renders only when pendingCount > 0, carrying the count"
    requirement: "REPR-04"
    verification:
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#pending count above zero renders the warning line with the count"
        status: pass
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#zero pending count renders no warning line"
        status: pass
    human_judgment: false
  - id: D3
    description: "Confirming calls closeAtf exactly once with the correct atfId and pops the dialog with true"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#tapping \"Encerrar\" calls closeAtf exactly once and pops with true"
        status: pass
    human_judgment: false
  - id: D4
    description: "The dialog does not dismiss optimistically — while closeAtf is in flight the confirm control is replaced by a spinner and the dialog stays mounted (T-05-50)"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#while the repository call is in flight the confirm button is disabled and the dialog stays mounted (no optimistic dismissal)"
        status: pass
    human_judgment: false
  - id: D5
    description: "A closeAtf throw leaves the dialog mounted with the ATF untouched and renders the encerramento-failure copy inline"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#a repository throw leaves the dialog mounted and renders the encerramento-failure copy"
        status: pass
    human_judgment: false
  - id: D6
    description: "A very long ATF name renders on one line (TextOverflow.ellipsis) without a layout overflow error"
    requirement: "REPR-04"
    verification:
      - kind: automated_ui
        ref: "test/widget/encerrar_atf_dialog_test.dart#a very long ATF name renders on one line without a layout overflow error"
        status: pass
    human_judgment: false
  - id: D7
    description: "The all-DGs-recorded banner renders only when the ATF is active, the viewer is a veterinarian, the composition is non-empty, and DgSummary.pending is zero — and not otherwise (single pending animal, non-vet, or closed ATF)"
    requirement: "REPR-04"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#the banner renders when the composition is non-empty and every animal has a DG"
        status: pass
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#the banner does not render when even one animal is pending"
        status: pass
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#the banner does not render for a non-veterinarian override, nor for a closed ATF"
        status: pass
    human_judgment: false
  - id: D8
    description: "Dismissing the banner hides it for the session (session-local widget state, not persisted)"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#tapping the banner's dismiss icon hides it for the session"
        status: pass
    human_judgment: false
  - id: D9
    description: "The AppBar 'Encerrar ATF' action is absent for a closed ATF and for a non-veterinarian override — the action stays reachable even when DGs are pending, since it is gated on active+role only, never on the banner's own condition"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#the AppBar encerrar action is absent for a closed ATF and for a non-veterinarian override"
        status: pass
    human_judgment: false
  - id: D10
    description: "The single most important D-16 assertion: for a closed ATF, '+ Animais', the composition remove icons, the banner, and the AppBar encerrar action are all absent, while the DG chips stay present and interactive"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#for a closed ATF: \"+ Animais\", the remove icons, the banner, and the AppBar encerrar action are all absent, while the DG chips stay present and interactive (D-16)"
        status: pass
    human_judgment: false
  - id: D11
    description: "close_atf is manual only — no code path in this plan calls AtfRepository.closeAtf without an explicit user tap on the dialog's confirm button (T-05-53), and the RPC itself re-checks the veterinarian role and active-only precondition server-side (T-05-49/T-05-50)"
    verification: []
    human_judgment: true
    rationale: "The absence of an automatic call site is verifiable by inspection (grep for closeAtf( call sites in lib/, only encerrar_atf_dialog.dart's _submit calls it) but a widget test cannot prove a negative across the whole codebase's future evolution; the RPC-side guards were verified in 05-03's SQL and are unchanged here. Structural, not behaviorally executable in this plan's scope."

duration: 20min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 9: Manual Encerramento (Dialog, AppBar Action, Banner) Summary

**EncerrarAtfDialog (400px, non-destructive confirm, non-optimistic close) plus AtfDetailScreen's role-gated AppBar action and session-dismissible all-DGs-recorded banner — closing an ATF stays a deliberate, manual, confirmed action per D-15, and D-16 correction survives it.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `EncerrarAtfDialog`: `BaixaDialog`-template confirm dialog at 400px (not 480px), default-primary `FilledButton` (not `colorScheme.error` — encerramento is routine, not data loss), inline pt-BR singular/plural pending-DG warning, and a non-optimistic submit that awaits `closeAtf`, invalidates 4 providers, then pops `true`; a throw renders the failure copy inline and leaves the ATF untouched
- `AtfDetailScreen`: AppBar "Encerrar ATF" `IconButton` gated on `atf.active && canEdit`, wired to a shared `_showEncerrarDialog` helper that also shows the "ATF encerrado." success `SnackBar`
- `_EncerrarBanner`: `tertiaryContainer` banner between the header and composition sections, rendered by the parent only when active + veterinarian + non-empty composition + zero pending DGs; owns only its own session-local dismissal state, not the business condition
- Verified and left unchanged: the DG section's render condition (memberships-empty only, no `active` check) and its role-only `canEdit` gate — D-16 correction was already correct from plan 05-08, this plan only added a regression test proving it under the new sibling widgets
- 15 new widget tests (7 dialog, 8 screen) plus one pre-existing 05-08 test repaired for an off-screen tap caused by the new banner; full suite (204 tests) green

## Task Commits

Each task was committed atomically:

1. **Task 1: EncerrarAtfDialog** - `3cc16ae` (feat)
2. **Task 2: Encerrar AppBar action and the all-DGs-recorded banner** - `638b467` (feat)
3. **Task 3: Widget tests for encerramento** - `d3eddc8` (test)

## Files Created/Modified
- `lib/features/reproducao/presentation/encerrar_atf_dialog.dart` - new `EncerrarAtfDialog`
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - adds the AppBar action, `_showEncerrarDialog` helper, and `_EncerrarBanner`; wires both into the header's live `DgSummary`
- `test/widget/atf_detail_screen_test.dart` - adds an 8-test `encerramento` group; repairs one pre-existing 05-08 test's off-screen tap

## Decisions Made
- Pending-DG warning uses a real singular/plural conditional (matching Phase 4's established `WR-04` pattern) rather than a literal `"(is)"` string, since the plan's own reference to "the animal(is) plural shorthand established in Phase 4" points at that conditional pattern, not a literal parenthesis.
- The "ATF encerrado." success `SnackBar` (05-UI-SPEC section 5) is shown by `AtfDetailScreen`'s shared dialog-opening helper, not by the dialog itself — keeps `EncerrarAtfDialog`'s own responsibility limited to what Task 1 specified (invalidate + pop), matching the split already established between `_CompositionSection`'s remove flow and its confirm dialog.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] A pre-existing 05-08 test's tap target fell off-screen once this plan's banner rendered in the same scenario**
- **Found during:** Task 3, first full run of `test/widget/atf_detail_screen_test.dart`
- **Issue:** `_DgSection`'s `'tapping a different chip on an animal with an existing DG stages exactly one changed row'` test (05-08) builds a scenario with one composed animal that already has a DG — composition fully covered, so `pending == 0`. This plan's new `_EncerrarBanner` now renders in exactly that scenario, pushing the DG chip row below the fixed 800×600 test viewport; `tester.tap()` computed an off-screen offset and missed, surfacing as a downstream `null` assertion rather than a clear tap-miss error. Same class of brittleness the 05-08 summary already documented for sibling-widget growth (unscoped/unpositioned finders breaking when new content is added alongside, not a behavior change in the test's own target).
- **Fix:** Added `tester.ensureVisible(chipFinder)` before the tap, matching the established pattern already used elsewhere in the same file for controls that can fall below the fold. No assertion changed.
- **Files modified:** `test/widget/atf_detail_screen_test.dart`
- **Verification:** The test passes again; full 204-test suite green.
- **Committed in:** `d3eddc8` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1, test-positioning bug exposed by new sibling widget)
**Impact on plan:** Test-file-only fix needed to make plan's own acceptance criteria ("groups from 05-04/05-06/05-08 still pass unchanged") executable; no production code changed beyond what Tasks 1–2 specified. No scope creep.

## Issues Encountered
None beyond the one auto-fixed issue above.

## User Setup Required
None - no external service configuration required. The Supabase migrations-not-yet-pushed blocker noted since 05-03-SUMMARY.md still applies to any LIVE exercise of `close_atf`, unchanged by this plan (widget tests use a fake repository).

## Next Phase Readiness
- The full Phase 5 UI surface named in this plan's frontmatter is now built: creation, composition, DG mass-entry, and encerramento are all present and cross-tested on `AtfDetailScreen`.
- Every closure code path in `lib/` runs through `EncerrarAtfDialog._submit`, which itself only fires from an explicit user tap — no automatic-closure code path exists (D-15).
- Only the live schema push named in plan 05-10 remains before this phase's Supabase-backed UAT can run end-to-end; unrelated to this plan's scope.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

- FOUND: lib/features/reproducao/presentation/encerrar_atf_dialog.dart
- FOUND: lib/features/reproducao/presentation/atf_detail_screen.dart
- FOUND: test/widget/encerrar_atf_dialog_test.dart
- FOUND: test/widget/atf_detail_screen_test.dart
- FOUND commit: 3cc16ae (Task 1)
- FOUND commit: 638b467 (Task 2)
- FOUND commit: d3eddc8 (Task 3)
