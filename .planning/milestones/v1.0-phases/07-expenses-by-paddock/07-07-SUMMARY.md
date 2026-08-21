---
phase: 07-expenses-by-paddock
plan: 07
subsystem: ui
tags: [flutter, riverpod, go_router, gastos, piquetes]

# Dependency graph
requires:
  - phase: 07-expenses-by-paddock
    provides: "07-04 (paddockMonthExpenseTotalProvider, derived from unifiedExpenseListByPaddockProvider); 07-03 (canManageExpenses gate, AppRoutes.gastosPorPiquete)"
provides:
  - "PaddockExpenseSummaryCard: a testable, feature-owned widget showing a paddock's current-month expense total, with distinct loading/error/populated states and a tap-through to /gastos/:paddockId"
  - "PaddockDetailScreen now renders the expense card below _PaddockInfoCard, with _canEdit (vet-only, gates the Novo lote FAB) left byte-identical beside the new, broader canManageExpenses surface"
affects: [07-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AsyncValue.when<(Widget, Widget)> returning a Dart record of (subtitle, trailing) widgets — one when() call driving two slots of the same ListTile, avoiding three near-duplicate Card/ListTile branches"
    - "Override (the ProviderScope override type) must be imported from package:riverpod/misc.dart in tests — flutter_riverpod.dart does not re-export it"

key-files:
  created:
    - lib/features/gastos/presentation/paddock_expense_summary_card.dart
    - test/features/gastos/paddock_expense_card_test.dart
  modified:
    - lib/features/piquetes/presentation/paddock_detail_screen.dart

key-decisions:
  - "The card carries no role gate of its own — per the plan's explicit instruction, reading the expense total is open to every member (D-24); canManageExpenses only gates write affordances inside /gastos/:paddockId itself, not this card's visibility or tappability."
  - "Reworded the _canEdit doc comment to avoid a second literal occurrence of the string 'veterinarian' in paddock_detail_screen.dart — the plan's own acceptance criterion requires exactly one occurrence, and the first comment draft used the word twice (Rule 1, self-caught before commit)."

patterns-established: []

requirements-completed: [GAST-02]

coverage:
  - id: D1
    description: "PaddockExpenseSummaryCard renders three distinct states (loading spinner, error dash + refresh, populated formatted total) and is tappable through to /gastos/{paddockId} in every state"
    requirement: GAST-02
    verification:
      - kind: unit
        ref: "test/features/gastos/paddock_expense_card_test.dart (5/5 pass, all <behavior> cases covered)"
        status: pass
    human_judgment: false
  - id: D2
    description: "PaddockDetailScreen wires the card below _PaddockInfoCard while leaving _canEdit (vet-only Novo lote gate) byte-identical"
    requirement: GAST-02
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/piquetes/ lib/features/gastos/ (0 issues); flutter test test/widget/ (150/150 pass); grep -c \"'owner'\" paddock_detail_screen.dart == 0; grep -c veterinarian paddock_detail_screen.dart == 1"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-08-11
status: complete
---

# Phase 7 Plan 07: Paddock Expense Summary Card Summary

**`PaddockExpenseSummaryCard`, a feature-owned widget showing a paddock's current-month expense total with distinct loading/error/populated states, wired into `PaddockDetailScreen` as the app's only navigation entry point into `/gastos/:paddockId`.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-11T14:47:32-03:00 (RED commit)
- **Completed:** 2026-08-11T14:57:07-03:00
- **Tasks:** 2 (Task 1 is TDD: RED + GREEN commits)
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments
- `PaddockExpenseSummaryCard`: a `ConsumerWidget` watching `paddockMonthExpenseTotalProvider(paddockId)`, rendering a `Card`/`ListTile` with title "Gastos" and a subtitle that varies by `AsyncValue` state — a small `CircularProgressIndicator` while loading, `—` plus an `Icons.refresh` `IconButton` on error (never a formatted currency figure, T-07-28), or `formatCurrencyBrl(total) + ' este mês'` (maxLines 1, ellipsis) once populated
- The card is tappable in every state, including error, and for every role — opens `context.push(AppRoutes.gastosPorPiquete(paddockId))`
- `PaddockDetailScreen` now renders the card directly below `_PaddockInfoCard`, above the "Lotes" header (D-09); `_canEdit` (vet-only, guards the "Novo lote" FAB) is left byte-identical, with a doc comment recording that `canManageExpenses` now coexists on the same screen for the expense surface (D-23)
- 5-case TDD test suite (`paddock_expense_card_test.dart`) covering loading, error, populated-zero, populated-non-zero, and tap-through navigation, using a `GoRouter` harness mirroring `lote_detail_screen_test.dart`'s existing pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: PaddockExpenseSummaryCard with its three states** — `d7f4bf7` (test, RED) → `f5d22d8` (feat, GREEN)
2. **Task 2: Wire the card into PaddockDetailScreen beside the existing vet-only gate** — `450122a` (feat)

_Task 1 is TDD: the RED commit encodes every `<behavior>` case against the not-yet-written widget and fails to load (`PaddockExpenseSummaryCard` does not exist); the GREEN commit implements the widget and all 5 tests pass._

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/features/gastos/presentation/paddock_expense_summary_card.dart` - `PaddockExpenseSummaryCard extends ConsumerWidget`, three-state rendering via `AsyncValue.when`
- `test/features/gastos/paddock_expense_card_test.dart` - 5 widget tests covering every `<behavior>` case from the plan
- `lib/features/piquetes/presentation/paddock_detail_screen.dart` - import + card insertion + spacer + doc comment above `_canEdit`; `_canEdit`'s body untouched

## Decisions Made
- Used `totalAsync.when<(Widget, Widget)>(...)` returning a Dart record `(subtitle, trailing)` rather than three separate `Card` return branches — one `when()` call drives both slots of the same `ListTile`, matching the plan's per-state subtitle/trailing spec without duplicating the `Card`/`ListTile` shell three times.
- Imported `Override` from `package:riverpod/misc.dart` in the test file — `flutter_riverpod.dart`'s barrel export does not re-export it, and no other test in this codebase declares a typed `List<Override>` helper parameter (they all inline the override list), so this was a genuinely new import need for this file.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a second literal "veterinarian" from the `_canEdit` doc comment before commit**
- **Found during:** Task 2 (writing the doc comment above `_canEdit`)
- **Issue:** The plan's acceptance criteria require `grep -c "veterinarian" paddock_detail_screen.dart` to equal exactly 1 (the existing `role == 'veterinarian'` comparison). My first comment draft said "owner + veterinarian" while describing the coexisting `canManageExpenses` gate, which would have pushed the count to 2 and failed the plan's own verify command.
- **Fix:** Reworded the comment to reference `canManageExpenses` by name and file path without repeating the word "veterinarian" — the gate's actual role composition is already documented in `role_gates.dart` itself (07-03).
- **Files modified:** `lib/features/piquetes/presentation/paddock_detail_screen.dart`
- **Verification:** `grep -c veterinarian paddock_detail_screen.dart` → `1`; `grep -c "'owner'" paddock_detail_screen.dart` → `0`; `flutter analyze lib/features/piquetes/` → 0 issues.
- **Committed in:** `450122a` (Task 2 commit — caught and fixed before commit, not a separate correction commit)

**2. [Rule 3 - Blocking] Ran `flutter pub get` / `dart run build_runner build` in the wrong directory once, then re-ran correctly in the worktree**
- **Found during:** Pre-Task-1 environment setup
- **Issue:** A `cd F:/_geral/Projetos/campo_gestor && flutter pub get` command drifted the shell's cwd out of the worktree into the main repo (the environment's own cwd-drift hazard, #3097). The subsequent `flutter test` run against the new test file reported "Does not exist" because it was running against the main repo's `test/` tree, which does not have this plan's new file.
- **Fix:** Re-ran `pwd`/`ls` to confirm the drift, then re-ran `flutter pub get` and `dart run build_runner build` from the correct worktree path before continuing. No code was affected — this was purely a shell-state issue caught before any file was written or committed in the wrong location.
- **Files modified:** none
- **Verification:** `git log --oneline -3` inside the worktree showed the RED test commit present and correctly scoped; subsequent `flutter test` runs from the worktree path succeeded.
- **Committed in:** n/a (no code change; environment-only correction)

---

**Total deviations:** 2 auto-fixed (1 bug — self-caught pre-commit comment wording; 1 blocking — shell cwd drift caught before any file operation)
**Impact on plan:** Zero scope change. Both were self-corrections made before their respective commits; no rework, no reverted commits.

## Issues Encountered
None beyond the two deviations above, both resolved before their respective commits.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `PaddockExpenseSummaryCard` and its wiring are complete; the paddock detail screen is now the app's sole entry point into `/gastos/:paddockId`.
- 07-08 (the blocking apply/UAT plan) can proceed — this plan introduces no new schema surface and depends only on already-authored providers from 07-03/07-04.
- No blockers for downstream plans in this wave.

---
*Phase: 07-expenses-by-paddock*
*Completed: 2026-08-11*

## Self-Check: PASSED

- FOUND: lib/features/gastos/presentation/paddock_expense_summary_card.dart
- FOUND: test/features/gastos/paddock_expense_card_test.dart
- FOUND: .planning/phases/07-expenses-by-paddock/07-07-SUMMARY.md
- FOUND commits: d7f4bf7, f5d22d8, 450122a
