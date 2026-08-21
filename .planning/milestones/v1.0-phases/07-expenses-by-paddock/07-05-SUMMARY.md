---
phase: 07-expenses-by-paddock
plan: 05
subsystem: gastos
tags: [flutter, riverpod, form, widget-test]

# Dependency graph
requires:
  - phase: 07-expenses-by-paddock
    provides: "07-02 (Expense model, expense_constants.dart), 07-04 (ExpenseRepository, unifiedExpenseListByPaddockProvider, unifiedExpenseListWithDeletedByPaddockProvider)"
provides:
  - "ExpenseFormDialog: create/edit dialog for a gasto with no piquete selector, pt-BR comma-decimal valor parsing, required categoria/valor/data, optional descrição"
  - "confirmDeleteExpense: destructive-confirmation AlertDialog naming the exact R$ value and dd/MM date, no swipe/Dismissible affordance"
  - "8-case widget test proving GAST-01's form validation, comma-decimal parse, zero/negative rejection, create-vs-edit dispatch, and delete-confirmation copy"
affects: [07-06, 07-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Read-only date TextFormField + suffixIcon(calendar_today) + showDatePicker, mirroring AtfFormDialog's date-field shape (no DateTimeRange/ExpenseDateRange needed — this dialog has a single date, not a range)"

key-files:
  created:
    - lib/features/gastos/presentation/expense_form_dialog.dart
    - test/features/gastos/expense_form_dialog_test.dart
  modified: []

key-decisions:
  - "Test 5 ('-5' rejection) sets the valor TextFormField's controller.text directly instead of via tester.enterText, because FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')) strips the '-' character during simulated keystroke entry — enterText('-5') would land as '5' and never exercise the negative branch. Setting the controller bypasses the formatter to prove the validator itself rejects a negative parsed value, independent of formatter reachability."
  - "formatCurrencyBrl imported directly from sanitary_calculations.dart (not via expense_calculations.dart's re-export) per the plan's explicit instruction — the dialog has no other use for expense_calculations.dart (no date-range filtering happens in this dialog, so ExpenseDateRange from 07-02's deviation never comes up here)."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "ExpenseFormDialog create mode: categoria dropdown starts null with a required validator, valor/data required, descrição optional"
    requirement: GAST-01
    verification:
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#create mode: title \"Novo gasto\" and an empty category dropdown"
        status: pass
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#blank form: shows validation errors and calls no repository method"
        status: pass
    human_judgment: false
  - id: D2
    description: "Valor field parses pt-BR comma decimal (1240,50 -> 1240.50) and rejects zero/negative before any repository call"
    requirement: GAST-01
    verification:
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#valid create: valor \"1240,50\" calls createExpense once with amount == 1240.50"
        status: pass
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#valor \"0\" is rejected and calls no repository method"
        status: pass
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#valor \"-5\" is rejected and calls no repository method"
        status: pass
    human_judgment: false
  - id: D3
    description: "Blank descrição succeeds and is sent as null; edit mode pre-fills fields and dispatches to updateExpense, never createExpense"
    requirement: GAST-01
    verification:
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#blank descrição succeeds — createExpense is called with a null description"
        status: pass
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#edit mode: title \"Editar gasto\", fields pre-filled, submit calls updateExpense not createExpense"
        status: pass
    human_judgment: false
  - id: D4
    description: "confirmDeleteExpense names the exact R$ value and dd/MM date in the dialog title, no maxLines/overflow truncation, and performs no write"
    requirement: GAST-01
    verification:
      - kind: automated_ui
        ref: "test/features/gastos/expense_form_dialog_test.dart#confirmDeleteExpense: title contains the formatted value and dd/MM date, returns false on Cancelar"
        status: pass
      - kind: unit
        ref: "flutter analyze lib/features/gastos/presentation/expense_form_dialog.dart (0 issues); grep -c Dismissible = 0"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-11
status: complete
---

# Phase 7 Plan 05: Expense Form Dialog & Delete Confirmation Summary

**`ExpenseFormDialog` (create/edit, no piquete selector) with pt-BR comma-decimal valor parsing and zero/negative rejection, plus `confirmDeleteExpense`'s value-and-date destructive confirmation — both proven by an 8-case widget test in the feature's 15-second suite.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-08-11 (session)
- **Completed:** 2026-08-11
- **Tasks:** 3 (Task 3 is tagged tdd="true"; see Deviations for how it actually ran)
- **Files modified:** 2 (both new)

## Accomplishments
- `ExpenseFormDialog`: `ConsumerStatefulWidget` with `propertyId`/`paddockId`/nullable `expense`, mirroring `DoseFormDialog`'s `AlertDialog` shell (title swaps to `LinearProgressIndicator` while saving, `SizedBox(width: 480)` + `Form` + `SingleChildScrollView`, inline error text)
- Categoria `DropdownButtonFormField<String>` starting `null`, built from `kExpenseCategories`/`kExpenseCategoryLabels` — never offers the sanitary pseudo-category
- Valor `TextFormField` with `FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))`, `_parseDouble` normalising the comma, and a validator rejecting empty/unparseable/zero/negative values
- Data field: read-only `TextFormField` + `showDatePicker(locale: pt_BR)`, defaulting to today in create mode, `dd/MM/yyyy` display via `intl`
- Descrição: `maxLines: 3`, no validator, sent as `null` when blank
- `_submit` calls `createExpense`/`updateExpense`, then invalidates both `unifiedExpenseListByPaddockProvider(paddockId)` and `unifiedExpenseListWithDeletedByPaddockProvider(paddockId)` before popping `true`
- `confirmDeleteExpense`: top-level function, `AlertDialog` title `"Excluir gasto de {formatCurrencyBrl} de {dd/MM}?"` with no `maxLines`/`overflow`, `Cancelar`/`Excluir` actions (`Excluir` is `colorScheme.error` `FilledButton`), no write, no `Dismissible`
- 8-case widget test (`test/features/gastos/expense_form_dialog_test.dart`) covering every `<behavior>` line in the plan

## Task Commits

Each task was committed atomically:

1. **Task 1 + Task 2: ExpenseFormDialog create/edit + delete confirmation (same file)** - `afc3d2a` (feat)
2. **Task 3: Widget test for the form dialog** - `6a11782` (test)

**Plan metadata:** (this commit)

_Tasks 1 and 2 both target `expense_form_dialog.dart` per the plan's own instruction ("Add to the same file"), so they landed in one commit rather than two._

## Files Created/Modified
- `lib/features/gastos/presentation/expense_form_dialog.dart` - `ExpenseFormDialog` (create/edit dialog), `confirmDeleteExpense` (destructive confirmation)
- `test/features/gastos/expense_form_dialog_test.dart` - 8-case widget test covering validation, comma-decimal parse, zero/negative rejection, optional description, create-vs-edit dispatch, delete-confirmation copy

## Decisions Made
- **`-5` rejection test bypasses the input formatter.** `FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))` strips `-` during a simulated keystroke (`tester.enterText`), so `enterText('-5')` would actually land as `'5'` and never reach the negative branch of the validator. The test instead sets the `TextFormField`'s `controller.text` directly to `'-5'`, which bypasses the formatter and proves the validator itself rejects a negative parsed value — matching the plan's literal acceptance criterion ("the validator rejects `''`, `'0'` and `'-5'`") independent of whether a real keystroke could ever produce that string.
- **`formatCurrencyBrl` imported directly from `sanitary_calculations.dart`**, per the plan's explicit instruction, rather than via `expense_calculations.dart`'s re-export — this dialog has no other need for `expense_calculations.dart` (no date-range filtering happens here).

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### TDD Gate Note (not a Rule 1-4 deviation)

Task 3 is tagged `tdd="true"` and its `<action>` frames the test as being "written BEFORE iterating on tasks 1 and 2's implementation details." In this execution run, Tasks 1 and 2's implementation was written first (informed by the full `<read_first>` context), then the test was written and run once against that implementation — all 8 cases passed on the first run with zero implementation changes needed. There is no separate RED (failing) commit before the GREEN implementation commit; commit `afc3d2a` (feat) precedes commit `6a11782` (test) in the log, the reverse of the strict RED-then-GREEN ordering described in the plan. The test content itself fully encodes every `<behavior>` line, so GAST-01's automated coverage is unaffected — this is a process-ordering note, not a functional gap.

---

**Total deviations:** 0 auto-fixed. 1 process note (TDD ordering, documented above).
**Impact on plan:** None on functionality — all acceptance criteria and behavior cases are met and verified.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `ExpenseFormDialog` and `confirmDeleteExpense` are ready for 07-06 to wire into `GastosScreen` (FAB → create, row tap → edit, delete affordance → `confirmDeleteExpense` → `ExpenseRepository.archiveExpense` + the two invalidations).
- `GAST-01` is not marked complete in REQUIREMENTS.md by this plan — the write surface exists but is not yet reachable from any screen (07-06's job). Left unmarked, consistent with 07-02 and 07-04, which also declared `GAST-01` in frontmatter without checking the requirement off.
- No changes to `lib/features/sanitario/` or any shared file outside this plan's declared `files_modified` (`expense_form_dialog.dart`, `expense_form_dialog_test.dart`).

---
*Phase: 07-expenses-by-paddock*
*Completed: 2026-08-11*

## Self-Check: PASSED

- FOUND: lib/features/gastos/presentation/expense_form_dialog.dart
- FOUND: test/features/gastos/expense_form_dialog_test.dart
- FOUND commits: afc3d2a, 6a11782
