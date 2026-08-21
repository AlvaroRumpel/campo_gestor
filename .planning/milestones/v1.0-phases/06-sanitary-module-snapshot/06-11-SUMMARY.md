---
phase: 06-sanitary-module-snapshot
plan: 11
subsystem: ui
tags: [flutter, riverpod, navigator, dialog, material3]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-08)
    provides: AplicacaoFormDialog, SanitaryAnimalSelectionScreen (the registration flow this plan's button opens)
  - phase: 06-sanitary-module-snapshot (06-09)
    provides: LoteSanitaryHistorySection (the shared history widget this plan places)
provides:
  - "LoteDetailScreen — second footer button ('Registrar aplicação') mirroring the move-lote gate exactly, wired to AplicacaoFormDialog with lotId locked"
  - "LoteDetailScreen — LoteSanitaryHistorySection placed below the animal list, reusing the 06-09 widget verbatim"
  - "AplicacaoFormDialog.onRegistered — an optional callback hook so a caller can react to the registration flow's real outcome (animal count), since the dialog's own showDialog Future resolves to null before the downstream flow completes"
affects: [06-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two footer buttons sharing one gate condition inside a single Builder, laid out in a Wrap(alignment: WrapAlignment.end) instead of Row/Align — avoids overflow at 360px and keeps both controls appearing/disappearing atomically"
    - "Navigator.push().then((result) => callback?.call(result)) as a side-channel for a multi-step push-based flow whose intermediate dialog pops itself immediately (pop-then-push pattern) — the original showDialog await cannot observe the eventual result because the dialog's own route resolves before the pushed flow starts"

key-files:
  created: []
  modified:
    - lib/features/lotes/presentation/lote_detail_screen.dart
    - lib/features/sanitario/presentation/aplicacao_form_dialog.dart

key-decisions:
  - "Modified aplicacao_form_dialog.dart (outside this plan's declared files_modified) to add an optional onRegistered callback — see Deviations."
  - "Reused the shared LoteSanitaryHistorySection from 06-09 verbatim; no card shell, toggle, or row-format logic duplicated into lote_detail_screen.dart."
  - "Split the two independent tasks into two atomic commits within the same file by temporarily reverting Task 2's lines, committing Task 1, then reapplying — file-level task ordering preserved without a combined diff."

patterns-established: []

requirements-completed: [SANI-02, SANI-04]

coverage:
  - id: D1
    description: "Registrar aplicação footer button: absence-not-disabled gate identical to the move button (canEdit && lot active && activeCount > 0), opens AplicacaoFormDialog with lotId locked, invalidates animal list + lot application list and shows the D-24 success snackbar with the animal count on completion"
    requirement: "SANI-02"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/lotes/ lib/features/sanitario/ — 0 issues; flutter test test/ — 257/257 pass (includes existing lote_detail_screen_test.dart and aplicacao_form_dialog_test.dart, both unmodified and green)"
        status: pass
    human_judgment: true
    rationale: "No widget test exercises the full registration round trip end-to-end from the lote screen's button through onRegistered firing with a real count — the acceptance-criteria greps and repo-wide test suite confirm the code compiles, is gated correctly, and does not regress existing behavior, but the live snackbar/invalidation path is unverified by an automated test in this plan."
  - id: D2
    description: "LoteSanitaryHistorySection placed below the animal list, consuming the shared 06-09 widget with zero duplicated presentation logic in lote_detail_screen.dart"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "grep confirms exactly one LoteSanitaryHistorySection(lotId: loteId) instantiation and no card-shell/toggle/badge/row-format strings declared in lote_detail_screen.dart; flutter analyze/test as above"
        status: pass
    human_judgment: false

# Metrics
duration: ~35min
completed: 2026-08-07
status: complete
---

# Phase 6 Plan 11: Lote Screen — Registration Entry Point + Sanitary History Summary

**Second "Registrar aplicação" entry point on LoteDetailScreen (mirroring the move-lote gate) plus the shared LoteSanitaryHistorySection placed below the animal list, closing SANI-02/SANI-04's field workflow**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 completed
- **Files modified:** 2 (`lote_detail_screen.dart` — this plan's declared scope; `aplicacao_form_dialog.dart` — required deviation, see below)

## Accomplishments
- `_LoteHeaderCard` gained a second footer button, "Registrar aplicação" (`Icons.medical_services_outlined`), sharing the exact same gate `Builder` and `activeCount > 0` condition as the existing "Mover para piquete" button — both buttons appear/disappear atomically, laid out in a right-aligned `Wrap` (8px spacing) instead of the previous single-button `Align`, so neither clips at 360px.
- The button opens `AplicacaoFormDialog(lotId: loteId)` — the lote arrives pre-resolved and locked. On a successful registration, the lot's animal list provider and this lote's sanitary application list provider are invalidated and the locked success snackbar (`"Aplicação registrada — N animais"`) is shown.
- `LoteSanitaryHistorySection(lotId: loteId)` is appended below `_AnimalList` with a 16px gap — the 06-09 shared widget consumed as-is, contributing zero new card-shell/toggle/badge/row-format logic to this file.
- `flutter analyze lib/features/lotes/ lib/features/sanitario/` reports 0 issues; `flutter test test/` is 257/257 green, including the pre-existing `lote_detail_screen_test.dart` (all 4 "Mover para piquete" gate assertions unchanged) and `aplicacao_form_dialog_test.dart` (all 4 tests, including the one asserting the dialog is gone from the tree immediately after "Continuar").

## Task Commits

Each task was committed atomically:

1. **Task 1: Registrar aplicação footer button on the lote header card** - `1821a1e` (feat)
2. **Task 2: Sanitary history section below the animal list** - `9f7004f` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified
- `lib/features/lotes/presentation/lote_detail_screen.dart` - Second footer button + callback wiring, `LoteSanitaryHistorySection` placement
- `lib/features/sanitario/presentation/aplicacao_form_dialog.dart` - Added optional `onRegistered` callback (deviation, see below)

## Decisions Made
- Laid out the two footer buttons in a `Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8)` rather than the plan-literal "Row that would clip" — matches the plan's explicit instruction, replacing the prior single-button `Align`.
- Reused `activeCount` and the existing gate `Builder` verbatim rather than introducing a second derivation — `grep -c "activeCount > 0"` is 1, confirming both buttons cannot drift apart.
- Split the two tasks' edits into two atomic commits despite both touching the same file, by temporarily reverting Task 2's two-line addition, committing Task 1 alone (verified green in isolation), then reapplying Task 2's lines and committing separately.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `AplicacaoFormDialog` discarded the registration flow's final result, making "when the flow returns an animal count" unreachable from any caller**
- **Found during:** Task 1 (wiring the registration button's success handler)
- **Issue:** `AplicacaoFormDialog._continue` (built in 06-08) calls `navigator.pop()` synchronously — closing the dialog and resolving *any* caller's `await showDialog(...)` to `null` — and only *then* calls `navigator.push(SanitaryAnimalSelectionScreen)`, whose eventual pop value (the registered animal count, set by `ResumoAplicacaoDialog` deep in the chain) was never captured or returned anywhere. Confirmed empirically: 06-08's own widget test asserts `find.byType(AplicacaoFormDialog)` is `findsNothing` immediately after tapping "Continuar" and `pumpAndSettle()` — proving the dialog's route is fully popped (not just hidden) before the downstream flow even starts, so the original `showDialog` await could never observe the final outcome. This directly contradicts 06-UI-SPEC.md's explicit D-24 contract ("dialog + selection screen both pop back to the origin... SnackBar: the caller's responsibility"), which both this plan (LoteDetailScreen) and sibling plan 06-10 (SanitarioScreen FAB) depend on to show the success snackbar with the registered count.
- **Fix:** Added an optional `onRegistered: ValueChanged<int>?` callback parameter to `AplicacaoFormDialog` (default `null`, fully backward-compatible). `_continue` now calls `.then((count) { if (count != null) onRegistered?.call(count); })` on the previously-discarded `navigator.push()` Future, without changing the existing pop-then-push timing — 06-08's test asserting immediate dialog removal still passes unmodified.
- **Files modified:** `lib/features/sanitario/presentation/aplicacao_form_dialog.dart` (outside this plan's declared `files_modified: [lib/features/lotes/presentation/lote_detail_screen.dart]`)
- **Verification:** `flutter analyze lib/features/sanitario/` 0 issues; `flutter test test/widget/aplicacao_form_dialog_test.dart` and the full repo suite (257/257) unchanged and green.
- **Committed in:** `1821a1e` (Task 1 commit)
- **Risk noted:** sibling plan 06-10 (parallel worktree, same wave) also opens `AplicacaoFormDialog` from `SanitarioScreen`'s FAB and needs this identical fix per its own plan text ("on a returned animal count it invalidates..."). If 06-10 independently modifies the same file, the orchestrator's wave merge may need to reconcile two similar diffs to the same `_continue`/constructor — flagged here for the orchestrator's attention.

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug fix, blocking)
**Impact on plan:** Necessary for Task 1's explicit acceptance criteria ("When the flow returns an animal count...") to be reachable at all. No scope creep beyond the minimal additive fix — no other behavior in `aplicacao_form_dialog.dart` changed.

## Issues Encountered
- `dart format` (project default) reformatted the entire file to a different line-wrapping style than the file's existing on-disk formatting (likely a `dart_style` version mismatch), producing ~90 lines of unrelated diff noise. Reverted to HEAD and reapplied only the targeted `Edit` calls without a full-file format pass, keeping the diff to exactly the lines this plan's tasks touch. `flutter analyze` (which is the plan's verification gate, not `dart format --set-exit-if-changed`) reports 0 issues either way.
- No generated `.freezed.dart`/`.g.dart`/`.riverpod.dart` files existed in the fresh worktree (gitignored) — ran `dart run build_runner build` once before the first `flutter analyze`, per the parallel-execution setup note.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- The lote screen's field workflow closes end-to-end: from `LoteDetailScreen`, a veterinarian opens `AplicacaoFormDialog` with the lote resolved, completes the checklist and confirmation, and lands back with a snackbar and refreshed history — assuming 06-10's FAB wiring resolves the same discarded-Future issue on the module screen (flagged above).
- `AplicacaoFormDialog.onRegistered` is now a stable, optional, public hook — 06-10 can adopt it directly instead of re-solving the same problem, if its own worktree hasn't already diverged on this file.
- Did not touch `sanitario_screen.dart` or any file owned by sibling plan 06-10, per this plan's sibling-awareness boundary.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-07*

## Self-Check: PASSED

Both modified files verified present on disk. Both task commit hashes (`1821a1e`, `9f7004f`) verified present in `git log --oneline --all`.
