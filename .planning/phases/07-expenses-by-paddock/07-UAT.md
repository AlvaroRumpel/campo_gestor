---
status: complete
status_was: passed
phase: 07-expenses-by-paddock
source: [07-08-PLAN.md task 3]
started: 2026-08-11
updated: 2026-08-11
---

<!-- 2026-08-11: status normalized `passed` → `complete` at milestone v1.0 close.
     Same terminal meaning (7/7 pass, 0 pending scenarios); `passed` is not in the
     audit tool's terminal set (`complete` | `resolved`), so it read as an open gap. -->


## Current Test

number: —
name: UAT complete
expected: |
  All 7 checks green. One real gap (G-07-2) found and fixed; G-07-1 was a
  reporting artifact, not a defect.
awaiting: nothing

## Tests

### 1. Lançar gasto (categoria, valor com vírgula, data, descrição)
expected: form saves; row appears in the list
result: passed

### 2. Total do período reage ao filtro
expected: header total and "N lançamentos" update on preset/range change; "Ano" = 1 Jan → today
result: passed

### 3. Lista unificada (manual + sanitário read-only)
expected: sanitary row renders read-only; tapping it does not open the edit dialog
result: passed

### 4. Excluir gasto
expected: confirmation names exact R$ value and dd/MM date; row soft-deletes; total drops
result: passed

### 5. Role gate (reader)
expected: FAB and write affordances absent for a reader
result: passed

### 6. Card de gastos no piquete + navegação
expected: "Gastos" card on paddock detail routes into /gastos/:paddockId
result: passed — "abre certinho, como deve abrir" (user, 2026-08-11)

### 7. Restaurar gasto excluído
expected: an archived expense can be un-archived from the UI
result: issue — no restore affordance existed (G-07-2)

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

(1 real gap found and fixed during UAT: G-07-2.)

## Gaps

### G-07-1 — "/gastos/:paddockId reachable only by URL"
status: not-a-defect
severity: none

**Resolution (user, 2026-08-11):** *"ele abre certinho, como deve abrir; o
problema é que a URL que você passou acessava a mesma tela, mas não tem um
fluxo específico para chegar naquela URL — não é um problema."* The
Piquetes → piquete → "Gastos" card flow works as designed. The report was an
artifact of the UAT script handing over a direct URL, not a missing entry
point. **No production code was changed for this.**

Recorded here rather than deleted because the investigation produced two
artifacts worth keeping (below), and because a future reader should not
re-litigate it.

**Investigation — nothing was wrong.** Verified in HEAD:

- `PaddockExpenseSummaryCard` IS imported and rendered unconditionally in
  `paddock_detail_screen.dart:45`, between `_PaddockInfoCard` and the lots
  section (not below any fold, not behind a role gate — the card carries no
  role gate by design, D-24).
- The card IS tappable in every async state
  (`paddock_expense_summary_card.dart:65`).
- `/piquetes/:id` builds `PaddockDetailScreen` (`router.dart:185-190`) and the
  paddock list navigates there (`piquetes_screen.dart:183`).
- `/gastos/:paddockId` is registered at root level (`router.dart:159`).

**A hypothesis was raised and DISPROVED, not shipped:** that `context.push` to
a root-level route from inside a `StatefulShellRoute` branch fails to navigate
(every sibling detail route — loteDetail, atfDetail, aplicacaoDetail,
animalDetail — uses `context.go`). A test harness was rebuilt to reproduce the
real shell nesting and the tap-through assertion **still passed with `push`**.
The navigation-idiom change was therefore reverted rather than committed as a
fix for a cause that was not the cause.

**Two artifacts kept from the investigation** (both stand on their own merits,
independent of the non-defect):

1. `test/widget/paddock_detail_gastos_entry_test.dart` — mounts the real
   `PaddockDetailScreen` and asserts the card is present in the loaded,
   loading and error states. 07-07's own test mounted the card **standalone**,
   so it would have passed even if the card had never been added to the detail
   screen. That blind spot is real and is now closed.
2. An explicit `BackButton` on `GastosScreen` with a
   `canPop()`→`/piquetes/:id` fallback. `/gastos/:paddockId` is a documented
   deep-link target (D-08); entered that way it has no Navigator history, so
   Material's automatic back button is absent and the user is stranded. Same
   idiom as `aplicacao_detail_screen.dart`'s `_backButton`.

### G-07-2 — archived expenses could not be restored
status: resolved
severity: medium
commit: 36b200b

**Root cause (confirmed):** `ExpenseRepository.restoreExpense` existed and was
fully supported by the schema — the `owner_vet_can_update_expense` RLS policy
was deliberately written without a `deleted_at` predicate so an archived row
can be un-archived (the G-06-2 lesson), and `07_expenses_test.sql` asserts the
archive→restore round-trip passes at the DB level. But the method had **no
caller** anywhere in `lib/`, and `_expense_list_item_card.dart` rendered the
*delete* icon unconditionally — so an already-archived row offered "delete"
(a silent no-op) instead of "restore".

**Fix:** `ExpenseListItemCard` gained an `onRestore` callback and now swaps the
delete icon for `Icons.restore_from_trash_outlined` when
`expense.deletedAt != null`; `GastosScreen._restoreExpense` calls
`restoreExpense` and invalidates the three providers. No confirmation dialog —
restoring is non-destructive, unlike deletion.

**Tests:** `test/features/gastos/expense_restore_test.dart` — 4 cases: active
row offers delete not restore; archived row offers restore not delete; tapping
restore fires `onRestore` once; a reader sees neither affordance.
