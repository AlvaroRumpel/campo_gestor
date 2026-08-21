---
phase: 07-expenses-by-paddock
plan: 06
subsystem: ui
tags: [flutter, riverpod, go_router, gastos]

# Dependency graph
requires:
  - phase: 07-expenses-by-paddock
    provides: "07-02 (Expense model, ExpenseListItem sealed union, ExpensePeriodPreset/rangeForPreset/ExpenseDateRange), 07-03 (canManageExpenses gate, AppRoutes.gastosById), 07-04 (unifiedExpenseListByPaddockProvider/unifiedExpenseListWithDeletedByPaddockProvider/paddockMonthExpenseTotalProvider), 07-05 (ExpenseFormDialog, confirmDeleteExpense)"
provides:
  - "ExpenseListItemCard: renders both ExpenseListItem union variants (manual, read-only sanitary) with the correct affordances per canManage"
  - "GastosScreen: the /gastos/:paddockId screen — filter row (5 presets + category + Mostrar excluídos), always-visible total header, unified list, two contextual empty states, role-gated FAB"
  - "GoRoute(path: AppRoutes.gastosById) registered root-level, outside the shell"
  - "Widget half of D-36's two-role FAB gate coverage in role_gates_test.dart"
affects: [07-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DateTimeRange (showDateRangePicker) -> ExpenseDateRange conversion happens at the screen's _effectiveRange getter — the only boundary crossing point between Flutter's date-range type and the Flutter-free calculation module (07-02 deviation)"
    - "switch expression returning nullable VoidCallback (onDelete) per union variant, instead of an is-check in the list builder"

key-files:
  created:
    - lib/features/gastos/presentation/_expense_list_item_card.dart
    - lib/features/gastos/presentation/gastos_screen.dart
  modified:
    - lib/core/router/router.dart
    - test/features/gastos/role_gates_test.dart

key-decisions:
  - "Hardcoded the literal 'Sanitário' badge string in _expense_list_item_card.dart rather than importing kSanitaryPseudoCategoryLabel from expense_constants.dart — matches the plan's acceptance criterion literally ('the string Sanitário appears... as a badge label') and keeps the badge copy independent of the filter-category constant's lifecycle."
  - "FAB onPressed is additionally guarded by propertyId.isEmpty (disabled, not absent) while currentPropertyProvider is still resolving — mirrors PaddockDetailScreen's identical 'Novo lote' FAB precedent. The role-gate absence (canManage ? FAB : null) is the one the plan's acceptance criteria target; this second guard is a pre-existing codebase idiom for async-not-yet-ready state, not a role gate."

patterns-established: []

requirements-completed: [GAST-01, GAST-02]

coverage:
  - id: D1
    description: "ExpenseListItemCard switches on the sealed ExpenseListItem union (no is-checks); manual rows get category icon/label, delete IconButton gated by canManage, and an Excluído badge + strikethrough value when soft-deleted; sanitary rows are read-only under any canManage value, show the Sanitário badge, and render em-dash for a NULL totalCost"
    requirement: GAST-02
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/gastos/presentation/_expense_list_item_card.dart (0 issues); grep -c \"Colors\\.\" == 0; grep -c \"is ManualExpenseItem|is SanitaryExpenseItem\" == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "GastosScreen renders the 5-preset filter chip row (D-16), category dropdown, Mostrar excluídos toggle, an always-visible total header excluding soft-deleted rows from the sum, the unified date-descending list, two contextual empty states, and a role-gated FAB"
    requirement: GAST-02
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/gastos/ (0 issues); flutter test test/features/gastos/ (43/43 pass)"
        status: pass
    human_judgment: false
  - id: D3
    description: "/gastos/:paddockId resolves to GastosScreen as a root-level GoRoute outside the shell; the FAB is present for owner and veterinarian and absent (not disabled) for reader"
    requirement: GAST-01
    verification:
      - kind: automated_ui
        ref: "test/features/gastos/role_gates_test.dart#GastosScreen FAB role gate (GAST-01, D-23, D-36) — 3/3 pass"
        status: pass
      - kind: unit
        ref: "flutter test test/widget/app_shell_test.dart — 3/3 pass (shell nav-count assertions unaffected)"
        status: pass
    human_judgment: false

# Metrics
duration: 55min
completed: 2026-08-11
status: complete
---

# Phase 7 Plan 06: Gastos Screen, List Card & Route Summary

**The `/gastos/:paddockId` screen (`GastosScreen`) with a 5-preset date filter, category filter, always-visible R$ total header, a unified date-descending list card (`ExpenseListItemCard`) merging manual and read-only sanitary rows, two contextual empty states, and a `canManageExpenses`-gated FAB — registered as a root-level `GoRoute` and proven by a 3-case widget test.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-08-11 (session)
- **Completed:** 2026-08-11
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- `ExpenseListItemCard`: switches on the sealed `ExpenseListItem` union — manual rows (category icon/label, delete affordance gated by `canManage`, Excluído badge + strikethrough on soft-deleted rows) and read-only sanitary rows (Sanitário badge, em-dash for a NULL `totalCost`, no edit/delete under any `canManage` value, D-32)
- `GastosScreen`: filter row with five preset `FilterChip`s (D-16) + category `DropdownButton` (D-07) + "Mostrar excluídos" toggle; `Personalizado` opens `showDateRangePicker` and converts its `DateTimeRange` into `ExpenseDateRange` at the screen boundary (07-02's documented deviation); cancelling the picker is a strict no-op
- Total header always renders (even at zero items), summing only non-deleted rows via `Intl.plural` pt-BR count
- Two contextual empty states (never-had-expenses vs filtered-to-zero, with a "Limpar filtro" action on the latter) and a "Novo gasto" FAB present only for `canManageExpenses` (owner + veterinarian), never `PaddockDetailScreen._canEdit` (vet-only)
- `GoRoute(path: AppRoutes.gastosById)` registered root-level, outside `StatefulShellRoute.indexedStack`, mirroring `loteById`/`atfById`/`aplicacaoById`
- Extended `test/features/gastos/role_gates_test.dart` (not a new file) with the widget half of D-36's two-role gate coverage: owner and veterinarian see the FAB, reader sees none

## Task Commits

Each task was committed atomically:

1. **Task 1: ExpenseListItemCard rendering both union variants** - `4249872` (feat)
2. **Task 2: GastosScreen — filters, total header, unified list, FAB** - `eda487e` (feat)
3. **Task 3: Register the route and prove the FAB role gate** - `12770a7` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/features/gastos/presentation/_expense_list_item_card.dart` - `ExpenseListItemCard`, one `_Badge` private widget
- `lib/features/gastos/presentation/gastos_screen.dart` - `GastosScreen`, `_EmptyState` private widget
- `lib/core/router/router.dart` - imports `GastosScreen`; adds the `GoRoute(path: AppRoutes.gastosById, ...)` registration
- `test/features/gastos/role_gates_test.dart` - extended with a `GastosScreen FAB role gate` group (3 widget test cases); existing 7 pure-function cases untouched

## Decisions Made
- **Hardcoded the literal `'Sanitário'` badge string** in `_expense_list_item_card.dart` instead of importing `kSanitaryPseudoCategoryLabel` — matches the plan's acceptance criterion literally and keeps the read-only badge's copy independent from the filter-category constant it happens to share a value with.
- **FAB `onPressed` guarded by `propertyId.isEmpty` in addition to the role gate** — mirrors `PaddockDetailScreen`'s existing "Novo lote" FAB precedent for the async-not-yet-ready window before `currentPropertyProvider` resolves. The role-gate absence (`canManage ? FloatingActionButton(...) : null`) is what the plan's acceptance criteria and D-23 target; this is a pre-existing codebase idiom layered on top, not a second role check.
- **`currentPropertyProvider` not overridden directly in the new widget test group** — with exactly one membership in the override, `CurrentPropertyNotifier.build()` resolves it as the active property without touching `SharedPreferences`, the same pattern `lote_detail_screen_test.dart` already establishes.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None. A pre-existing `unintended_html_in_doc_comment` info in `lib/core/config/app_config.dart` (out of scope, logged by 07-03) was not touched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `/gastos/:paddockId` is fully wired: `PaddockDetailScreen`'s `PaddockExpenseSummaryCard` (07-07) already routes into it, and it in turn routes read-only sanitary rows to `/aplicacoes/:id`.
- Full test suite: 305/305 pass (302 baseline + 3 new `GastosScreen` role-gate cases). `flutter analyze lib/features/gastos/ lib/core/router/` — 0 issues. `git diff --quiet -- lib/features/sanitario/` — clean (Phase 6 sources untouched).
- 07-08 (migration apply + UAT, human-gated) can proceed — this plan introduces no new schema surface.

---
*Phase: 07-expenses-by-paddock*
*Completed: 2026-08-11*

## Self-Check: PASSED

- FOUND: lib/features/gastos/presentation/_expense_list_item_card.dart
- FOUND: lib/features/gastos/presentation/gastos_screen.dart
- FOUND commits: 4249872, eda487e, 12770a7
