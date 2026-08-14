---
phase: quick-260813-x4f
plan: 01
subsystem: ui
tags: [flutter, riverpod, go_router, gastos, dashboard]

requires:
  - phase: 07-expenses-by-paddock
    provides: ExpenseRepository, ExpenseListItem, GastosScreen (/gastos/:paddockId)
  - phase: 09-redesign
    provides: shell adaptativo (rail/drawer), Breakpoints, ui.dart primitives (SectionCard, StackedBar, EmptyState)
provides:
  - unifiedExpenseListByPropertyProvider (property-wide unified expense list)
  - lastMonthsTotals / MonthTotal (pure 6-month aggregation helper)
  - GastosPropertyScreen at /gastos (6a shell branch, desktop table + panel, mobile card list)
  - "Gastos" nav item in rail (600-1439) and drawer (>=1440)
affects: [gastos, dashboard, router, app-shell]

tech-stack:
  added: []
  patterns:
    - "Property-wide provider twin pattern (unifiedExpenseListByPaddockProvider -> unifiedExpenseListByPropertyProvider), same D-18 client-side-sum ceiling"
    - "Chained showAdaptiveForm flow (picker sheet -> existing form dialog) to add a selector in front of a dialog whose signature must not change"

key-files:
  created:
    - lib/features/gastos/presentation/gastos_property_screen.dart
    - test/widget/gastos_property_screen_test.dart
  modified:
    - lib/features/gastos/data/expense_repository.dart
    - lib/features/gastos/data/expense_calculations.dart
    - lib/features/dashboard/data/dashboard_providers.dart
    - lib/core/router/routes.dart
    - lib/core/router/router.dart
    - lib/core/widgets/app_shell.dart
    - test/features/gastos/expense_calculations_test.dart
    - test/core/router_test.dart
    - test/widget/app_shell_test.dart

key-decisions:
  - "Reverted the Phase 7 decision against a 6th shell branch (explicit user approval 2026-08-13) — /gastos is now GastosPropertyScreen (property-wide), /gastos/:paddockId stays as GastosScreen (per-paddock deep link)"
  - "R$/UA and the category/6-month breakdowns are property-level metrics with no per-row equivalent in ExpenseListItem — kept entirely in the 330px panel, not added as table columns"
  - "'Novo gasto' has no piquete selector of its own (D-10, Phase 7) — chained a piquete picker sheet in front of the unchanged ExpenseFormDialog rather than adding a paddockId-optional mode to it"

requirements-completed: [GAST-01, GAST-02]

coverage:
  - id: D1
    description: "unifiedExpenseListByPropertyProvider + lastMonthsTotals, with monthExpensesProvider (Início card) refactored to reuse the shared provider"
    requirement: GAST-01
    verification:
      - kind: unit
        ref: "test/features/gastos/expense_calculations_test.dart#lastMonthsTotals (redesign, gastos consolidados)"
        status: pass
    human_judgment: false
  - id: D2
    description: "GastosPropertyScreen: desktop table (DATA/CATEGORIA/DESCRIÇÃO/PIQUETE/VALOR) + rodapé TOTAL + painel 330px (total do mês, R$/UA, por categoria, últimos 6 meses); mobile ExpenseListItemCard list; both empty states"
    requirement: GAST-02
    verification:
      - kind: automated_ui
        ref: "test/widget/gastos_property_screen_test.dart#GastosPropertyScreen — /gastos consolidado (260813-x4f)"
        status: pass
    human_judgment: false
  - id: D3
    description: "6a StatefulShellBranch /gastos, 'Gastos' item in rail/drawer, mobile bottom nav clamped to 5 destinations"
    verification:
      - kind: unit
        ref: "test/core/router_test.dart#AppRoutes contains 6 top-level paths"
        status: pass
      - kind: automated_ui
        ref: "test/widget/app_shell_test.dart"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-08-14
status: complete
---

# Quick Task 260813-x4f: Gastos consolidados da propriedade Summary

**GastosPropertyScreen at the new `/gastos` shell branch — property-wide expense table (desktop) + 330px summary panel (total do mês, R$/UA, por categoria, últimos 6 meses), reverting Phase 7's "no 6th branch" decision by explicit user approval.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3/3 completed
- **Files modified:** 9 (2 created, 7 modified)

## Accomplishments

- `unifiedExpenseListByPropertyProvider` — property-wide twin of the existing per-paddock provider, feeding both the new screen and the Início dashboard card from a single source
- `lastMonthsTotals`/`MonthTotal` — pure, Flutter-free 6-month aggregation helper, tested including a year-boundary case (February crossing into the prior year)
- `GastosPropertyScreen` — dense table + 330px summary panel at >=1024px, `ExpenseListItemCard` list at <1024px, both wired to the same filtered data so the table footer total and header subtitle can never drift apart
- 6th `StatefulShellBranch` (`/gastos`) with a "Gastos" rail/drawer nav item, positioned last to match `AppShell._navItems`' 6th slot; mobile `NavigationBar` stays clamped at 5 destinations

## Task Commits

1. **Task 1: Provider property-wide + agregação mensal pura, dashboard reusando** - `636192b` (feat)
2. **Task 2: GastosPropertyScreen — tabela + painel 330px em >=1024, lista em <1024** - `02346a6` (feat)
3. **Task 3: 6a branch do shell, item "Gastos" no rail/drawer, testes de rota e shell atualizados** - `c77ff58` (feat)

_Note: no separate metadata commit — `commit_docs: false` per this project's quick-task convention; this SUMMARY.md is written to disk without a git commit._

## Files Created/Modified

- `lib/features/gastos/data/expense_repository.dart` - added `unifiedExpenseListByPropertyProvider`
- `lib/features/gastos/data/expense_calculations.dart` - added `MonthTotal` + `lastMonthsTotals`
- `lib/features/dashboard/data/dashboard_providers.dart` - `monthExpensesProvider` now reads the shared property-wide provider instead of remounting the list inline
- `lib/features/gastos/presentation/gastos_property_screen.dart` - new consolidated screen (desktop table + panel, mobile card list, chained "Novo gasto" piquete picker)
- `lib/core/router/routes.dart` - `AppRoutes.gastos`, `AppRoutes.all` now 6 entries, dated reversion note replacing the Phase 7 "rejected 6th branch" comment
- `lib/core/router/router.dart` - 6th `StatefulShellBranch` serving `GastosPropertyScreen`
- `lib/core/widgets/app_shell.dart` - 6th `_NavItem`, mobile nav clamp, icon rail made scrollable
- `test/features/gastos/expense_calculations_test.dart` - `lastMonthsTotals` test group
- `test/widget/gastos_property_screen_test.dart` - new widget test (4 cases)
- `test/core/router_test.dart` - 5->6 counts, new `gastosById`/`gastos` coexistence test
- `test/widget/app_shell_test.dart` - 5->6 shell branches in the test router, drawer "Gastos" assertion, mobile NavigationBar destination-count assertion

## Decisions Made

- Reverted the Phase 7 "no 6th shell branch" decision (user-approved 2026-08-13) — see the dated comment now in `routes.dart` in place of the old rejection note
- `R$/UA` and the category/6-month breakdowns live only in the 330px panel — there is no per-row equivalent in `ExpenseListItem`, so they were never candidates for table columns
- "Novo gasto" chains a piquete-picker sheet in front of the existing `ExpenseFormDialog` rather than giving that dialog an optional paddock-picker mode, per the plan's explicit prohibition on changing its signature

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Icon rail (600-1439px) overflowed by 12px with the 6th nav item at short viewports**
- **Found during:** Task 3, running `flutter test test/widget/app_shell_test.dart` at 800x600
- **Issue:** `_IconRail`'s `Column` laid out all 6 nav items plus the logo/property-selector/Sair block at fixed heights with a `Spacer()`; a 6th item pushed the fixed content past the available height on a short window, throwing a `RenderFlex overflowed` assertion
- **Fix:** Wrapped the nav-items loop in `Expanded(child: SingleChildScrollView(...))`, replacing the `Spacer()` — "Sair" stays pinned at the bottom when there's room and the nav items scroll instead of overflowing when there isn't
- **Files modified:** `lib/core/widgets/app_shell.dart`
- **Verification:** `test/widget/app_shell_test.dart` at 360x800, 800x600, 1024x768, 1440x900 all pass; full `flutter test` suite green (421/421)
- **Committed in:** `c77ff58` (Task 3 commit)

**2. [Rule 1 - Bug] `invalid_null_aware_operator` on `DashboardKpis.totalUa?.` in `GastosPropertyScreen.build`**
- **Found during:** Task 2, `flutter analyze --no-fatal-infos`
- **Issue:** `ref.watch(dashboardKpisProvider).asData?.value?.totalUa` used a null-aware `?.` on `.value.totalUa`, but `totalUa` is a non-nullable `required double` field — only `.value` itself can be null, making the second `?.` invalid
- **Fix:** Changed to `.asData?.value.totalUa` (single null-aware access, on `value`)
- **Files modified:** `lib/features/gastos/presentation/gastos_property_screen.dart`
- **Verification:** `flutter analyze --no-fatal-infos lib/features/gastos` clean (only a pre-existing unrelated info remains)
- **Committed in:** `02346a6` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs, both introduced by this task's own changes and caught by this task's own verification steps)
**Impact on plan:** Both fixes are corrections to code written in this same plan — no scope creep, no pre-existing issues touched.

## Issues Encountered

- The widget test's original fixtures used a fixed "day 15" date for the current-month items; early in the month this landed *after* the test's real `DateTime.now()`, so `rangeForPreset(mesAtual, now)` (whose `end` is `now`) filtered every fixture out as "future". Fixed by using today's actual date (`DateTime(_now.year, _now.month, _now.day)`) instead of a fixed day.
- `DateFormat('MMM', 'pt_BR')` (used by the "Últimos 6 meses" panel block) threw `LocaleDataException` in the widget test until `setUpAll(() => initializeDateFormatting('pt_BR'))` was added, mirroring the existing pattern in `test/widget/dashboard_screen_test.dart`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `/gastos` is live end-to-end: navigable from rail/drawer, renders the property-wide table + panel on desktop and the card list on mobile, and `/gastos/:paddockId` continues to work unchanged as the per-paddock deep link.
- Deploy + visual UAT of this quick task (like the rest of the Phase 9 redesign series) is still pending the user, per `STATE.md`'s existing note that Phase 9's deploy/UAT is outstanding.
- No blockers for subsequent work.

---
*Quick task: 260813-x4f*
*Completed: 2026-08-14*

## Self-Check: PASSED

All created/modified files verified present on disk; all 3 task commit hashes (636192b, 02346a6, c77ff58) verified present in git log.
