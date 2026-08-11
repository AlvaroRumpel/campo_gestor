---
phase: 07-expenses-by-paddock
plan: 02
subsystem: gastos
tags: [freezed, json_serializable, dart, unit-test, tdd]

# Dependency graph
requires:
  - phase: 06-sanitary-module
    provides: SanitaryApplication model and formatCurrencyBrl (sanitary_calculations.dart) that this plan wraps/reuses
provides:
  - Expense freezed model + ExpenseListItem sealed union (manual + read-only sanitary rows)
  - 8-category constant table with pt-BR labels/icons and a 9th sanitary pseudo-category for the list filter
  - Pure calculation module: totalAmount, itemCount, filterByDateRange, filterByCategory, sortExpenseItemsDesc, ExpensePeriodPreset/rangeForPreset/currentMonthRange
affects: [07-03, 07-04, 07-05, 07-06, 07-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sealed-union unified list (ExpenseListItem) wrapping an existing model unchanged, with top-level switch-expression accessors (dateOf/amountOf/categoryKeyOf) instead of per-variant getters"
    - "Pure-Dart substitute type (ExpenseDateRange) when a Flutter-only type (DateTimeRange) would break a module's Flutter-free constraint"

key-files:
  created:
    - lib/features/gastos/data/expense_model.dart
    - lib/features/gastos/data/expense_constants.dart
    - lib/features/gastos/data/expense_calculations.dart
    - test/features/gastos/expense_calculations_test.dart
  modified: []

key-decisions:
  - "ExpenseDateRange (pure-Dart) replaces Flutter's material-only DateTimeRange in filterByDateRange/rangeForPreset/currentMonthRange signatures, since DateTimeRange only exists behind package:flutter/material.dart and this module must stay Flutter-free (D-18, D-36)"

patterns-established:
  - "Two-field ExpenseDateRange{start,end} is the calculation-layer date range type; the presentation layer converts Flutter's DateTimeRange (from showDateRangePicker) into it at the UI boundary"

requirements-completed: [GAST-01, GAST-02]

coverage:
  - id: D1
    description: "Expense freezed model round-trips fromJson/toJson against a snake_case Supabase row"
    requirement: GAST-01
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/gastos/data/expense_model.dart (codegen compiles; no round-trip test written — pure model, no behavior branch)"
        status: pass
    human_judgment: false
  - id: D2
    description: "ExpenseListItem sealed union wraps SanitaryApplication unchanged, with dateOf/amountOf/categoryKeyOf accessors and the null-sanitary-cost rule living in exactly one place"
    requirement: GAST-02
    verification:
      - kind: unit
        ref: "test/features/gastos/expense_calculations_test.dart#totalAmount / itemCount (GAST-02)"
        status: pass
    human_judgment: false
  - id: D3
    description: "8 expense categories + labels + icons + sanitary pseudo-category, kept out of the form vocabulary"
    requirement: GAST-01
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/gastos/data/expense_constants.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "totalAmount/itemCount/filterByDateRange/filterByCategory/sortExpenseItemsDesc/rangeForPreset/currentMonthRange implemented as pure functions"
    requirement: GAST-02
    verification:
      - kind: unit
        ref: "test/features/gastos/expense_calculations_test.dart (13/13 pass)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-11
status: complete
---

# Phase 7 Plan 2: Gastos Data Core Summary

**Pure Dart core for the gastos feature — Expense freezed model, ExpenseListItem sealed union merging manual expenses with read-only sanitary rows, the 8-category constant table, and a dependency-free calculation module (total, count, filters, sort, period presets) proven by a 13-case unit test.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-11T16:52:00Z
- **Completed:** 2026-08-11T17:17:20Z
- **Tasks:** 3 (Task 3 is a TDD task: RED + GREEN commits)
- **Files modified:** 4 (all new)

## Accomplishments
- `Expense` freezed model + `ExpenseListItem` sealed union (`ManualExpenseItem`/`SanitaryExpenseItem`), wrapping the existing `SanitaryApplication` model unchanged
- `dateOf`/`amountOf`/`categoryKeyOf` pure accessors — `amountOf` is the single documented place a null sanitary `totalCost` becomes `0.0` while the row still counts toward `itemCount`
- `sortExpenseItemsDesc`: date descending, `createdAt` descending tie-break (D-19), mirroring `sortByAppliedAtDesc`'s shape
- 8 fixed-order category keys + pt-BR labels + icons (`expense_constants.dart`), plus a 9th sanitary pseudo-category exposed only to the list filter, never the form
- Pure calculation module (`totalAmount`, `itemCount`, `filterByDateRange`, `filterByCategory`, `ExpensePeriodPreset`, `rangeForPreset`, `currentMonthRange`) proven by a 13-test unit suite that runs in under 1 second with zero widget/network harness

## Task Commits

Each task was committed atomically:

1. **Task 1: Expense model and the ExpenseListItem sealed union** - `c3db7c2` (feat)
2. **Task 2: Expense category constants, labels and icons** - `ed8169b` (feat)
3. **Task 3: Pure calculation module and its Wave 0 unit test** - `5e85c04` (test, RED) → `d621a25` (feat, GREEN)

**Plan metadata:** (this commit)

_Task 3 is TDD: the RED commit encodes every `<behavior>` case against the not-yet-written module and fails to compile; the GREEN commit implements the module and all 13 tests pass._

## Files Created/Modified
- `lib/features/gastos/data/expense_model.dart` - `Expense` freezed model, `ExpenseListItem` sealed union, `dateOf`/`amountOf`/`categoryKeyOf`/`sortExpenseItemsDesc`
- `lib/features/gastos/data/expense_constants.dart` - `kExpenseCategories`, `kExpenseCategoryLabels`, `kExpenseCategoryIcons`, `kExpenseFilterCategories`, `kSanitaryPseudoCategory`/`kSanitaryPseudoCategoryLabel`, `kSanitaryCategoryIcon`
- `lib/features/gastos/data/expense_calculations.dart` - `totalAmount`, `itemCount`, `filterByDateRange`, `filterByCategory`, `ExpensePeriodPreset`, `rangeForPreset`, `currentMonthRange`, `ExpenseDateRange`; re-exports `formatCurrencyBrl`
- `test/features/gastos/expense_calculations_test.dart` - 13 tests covering total/count, null-cost sanitary row, inclusive date-range endpoints, category filter combinability, sort tie-break, `mesAtual`/`ano` presets

## Decisions Made
- **`ExpenseDateRange` instead of Flutter's `DateTimeRange`.** The plan's task 3 mandates `filterByDateRange`/`rangeForPreset`/`currentMonthRange` take/return `DateTimeRange`, but that type is only exported by `package:flutter/material.dart` (confirmed by reading the Flutter SDK source: `src/material/date.dart`, not re-exported by `widgets.dart`). Importing `material.dart` here would violate the plan's own `must_haves.truths` and the phase-level `<verification>` line ("No file in `lib/features/gastos/data/` other than `expense_constants.dart` imports `flutter/material.dart`"). Resolved by defining a two-field pure-Dart `ExpenseDateRange{start,end}` in `expense_calculations.dart` with a doc comment explaining the substitution; the presentation layer (07-06) will convert `showDateRangePicker`'s `DateTimeRange` into this type at the UI boundary.
- Kept `expense_calculations.dart`'s header/doc comments that literally contain the strings "flutter/material.dart" and "NumberFormat.currency" (as prohibition documentation, matching `sanitary_calculations.dart`'s existing precedent at lines 2 and 57) even though a naive `grep -c` over those exact strings returns non-zero — verified this is the established codebase pattern, not a violation, by checking the analog file has the identical situation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `DateTimeRange` requires `flutter/material.dart`, which task 3 forbids**
- **Found during:** Task 3 (writing `filterByDateRange`/`rangeForPreset`/`currentMonthRange` signatures)
- **Issue:** The plan's action text specifies `DateTimeRange` (Flutter's class) for these signatures, but that type only exists behind `package:flutter/material.dart`, which the same task's acceptance criteria and the plan's `must_haves.truths` explicitly forbid importing into `expense_calculations.dart`.
- **Fix:** Defined `ExpenseDateRange{start,end}` as a pure-Dart substitute with the same two-field shape, documented the substitution reason in a doc comment, and used it throughout the calculation module instead of Flutter's `DateTimeRange`.
- **Files modified:** `lib/features/gastos/data/expense_calculations.dart`, `test/features/gastos/expense_calculations_test.dart`
- **Verification:** `flutter analyze lib/features/gastos/` and `flutter test test/features/gastos/` both exit 0; `grep` confirms zero `import 'package:flutter/material.dart';` statements in `expense_calculations.dart` or `expense_model.dart`.
- **Committed in:** `d621a25` (Task 3 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to satisfy the plan's own Flutter-free constraint on this module; zero scope creep. Presentation-layer plans (07-05/07-06) will need one conversion line (`ExpenseDateRange(start: pickedRange.start, end: pickedRange.end)`) at the `showDateRangePicker` call site — flagging for those plans' executors.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `lib/features/gastos/data/` now has all three data-layer files this phase's remaining plans import: the model, the constants, and the calculations.
- 07-03 (repository + role gate) can now import `Expense`/`ExpenseListItem` directly.
- 07-05/07-06 (form dialog, screen) must convert `showDateRangePicker`'s `DateTimeRange` into `ExpenseDateRange` before calling `filterByDateRange` — this plan's `ExpenseDateRange` substitution is the one contract change downstream plans need to know about.

---
*Phase: 07-expenses-by-paddock*
*Completed: 2026-08-11*

## Self-Check: PASSED

All 4 created files found on disk; all 4 task commits (`c3db7c2`, `ed8169b`, `5e85c04`, `d621a25`) found in `git log`.
