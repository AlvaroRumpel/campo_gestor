# Phase 7: Expenses by Paddock - Pattern Map

**Mapped:** 2026-08-11
**Files analyzed:** 13 (new/modified)
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/migrations/20260813_07_expenses_module.sql` | migration | CRUD + schema-extend | `supabase/migrations/20260810_06_sanitary_module.sql` (table+RLS shape) + `20260717_04_lot_paddock_property_trigger.sql` (isolation trigger) | exact (composite) |
| `supabase/tests/07_expenses_test.sql` | test (pgTAP) | request-response | `supabase/tests/06_sanitary_test.sql` (RLS/role groups) + `supabase/tests/04_movements_test.sql` (`*_same_property` trigger asserts) | exact (composite) |
| `lib/features/gastos/data/expense_model.dart` | model | CRUD | `lib/features/sanitario/data/dose_model.dart` (freezed CRUD model); `sanitary_application_repository.dart`'s `SanitaryApplication` for the sealed-union half | role-match |
| `lib/features/gastos/data/expense_constants.dart` | config/constant | transform | `lib/features/animais/data/animal_constants.dart` (`kBreeds`) | exact |
| `lib/features/gastos/data/expense_repository.dart` | service (repository) | CRUD | `lib/features/sanitario/data/dose_repository.dart` | exact |
| `lib/features/gastos/data/expense_calculations.dart` | utility (pure) | transform | `lib/features/sanitario/data/sanitary_calculations.dart` | exact |
| `lib/core/auth/role_gates.dart` | utility | transform | `PaddockDetailScreen._canEdit` (private method being extracted to shared, role-check shape) | role-match |
| `lib/features/gastos/presentation/gastos_screen.dart` | component (screen) | request-response | `lib/features/sanitario/presentation/sanitario_screen.dart` (filters + empty state + toggle) | exact |
| `lib/features/gastos/presentation/expense_form_dialog.dart` | component (dialog/form) | request-response | `lib/features/sanitario/presentation/dose_form_dialog.dart` | exact |
| `lib/features/gastos/presentation/_expense_list_item_card.dart` | component | request-response | `piquetes_screen.dart`'s `_PaddockCard` + `sanitario_screen.dart`'s `_AplicacaoCard`/`_DoseCard` | role-match |
| `lib/features/piquetes/presentation/paddock_detail_screen.dart` (modified) | component (screen) | request-response | itself (existing file — add summary card + second gate) | exact |
| `lib/core/router/routes.dart` (modified) | route | request-response | existing `atfById`/`aplicacaoById` block in same file | exact |
| `lib/core/router/router.dart` (modified) | route | request-response | existing `GoRoute(path: AppRoutes.aplicacaoById, ...)` registration in same file | exact |

## Pattern Assignments

### `supabase/migrations/20260813_07_expenses_module.sql` (migration, CRUD + schema-extend)

**Analogs:** `supabase/migrations/20260810_06_sanitary_module.sql`, `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql`, `supabase/migrations/20260812_06_fix_dose_update_policy.sql`

**Table + RLS + isolation trigger** — full text already produced in RESEARCH.md `## Code Examples` (lines 578-641+) and MUST be copied verbatim as the starting point:
- `expenses` table DDL (property_id/paddock_id/category/amount/expense_date/description/created_by/updated_by/timestamps/deleted_at)
- Indexes: `expenses_property_idx`, `expenses_paddock_date_idx (paddock_id, expense_date DESC)`
- RLS: `members_can_read_expenses` (SELECT, `is_member_of`), `owner_vet_can_insert_expense` / `owner_vet_can_update_expense` (`get_role(property_id) IN ('owner','veterinarian')`) — **no `deleted_at` predicate in USING/WITH CHECK** (Pitfall 3 / G-06-2 regression class, fixed once already in `20260812_06_fix_dose_update_policy.sql`)
- `set_expenses_updated_by()` trigger (mirrors auditing shape, new — no direct precedent, first `updated_by` column in the schema)
- `enforce_expenses_paddock_same_property()` / `trg_expenses_paddock_same_property` — copy `trg_lots_paddock_same_property` body literally, substituting `expenses`/`paddocks` for `lots`/`paddocks` (RESEARCH.md Pattern 2, full SQL provided)

**`sanitary_applications` ALTER + backfill (D-30/D-31, Pitfall 1)** — the trigger-disable pattern is mandatory, not optional:
```sql
ALTER TABLE sanitary_applications
  ADD COLUMN paddock_id   uuid REFERENCES paddocks(id),
  ADD COLUMN paddock_name text;

ALTER TABLE sanitary_applications DISABLE TRIGGER trg_snapshot_immutable;

UPDATE sanitary_applications sa
   SET paddock_id   = l.paddock_id,
       paddock_name = p.name
  FROM lots l
  JOIN paddocks p ON p.id = l.paddock_id
 WHERE sa.lot_id = l.id AND sa.paddock_id IS NULL;

ALTER TABLE sanitary_applications ENABLE TRIGGER trg_snapshot_immutable;

ALTER TABLE sanitary_applications
  ALTER COLUMN paddock_id   SET NOT NULL,
  ALTER COLUMN paddock_name SET NOT NULL;
```
Document in the migration header that the 2 backfilled PROD rows have approximate (not frozen) attribution (D-31).

**RPC edit (Pitfall 4)** — `register_sanitary_application` / `reverse_sanitary_application` in `supabase/migrations/20260811_06_sanitary_rpcs.sql` need `CREATE OR REPLACE FUNCTION` forward-only edits (same technique used in `20260806_05`/`20260807_05`/`20260808_05`/`20260809_05` — never edit the original file on disk):
```sql
SELECT l.property_id, l.name, p.id, p.name
  INTO v_property_id, v_lot_name, v_paddock_id, v_paddock_name
  FROM lots l JOIN paddocks p ON p.id = l.paddock_id
 WHERE l.id = p_lot_id AND l.deleted_at IS NULL;
-- add v_paddock_id, v_paddock_name to the INSERT column list + VALUES tuple
```
`reverse_sanitary_application` needs the parallel copy: `v_orig.paddock_id, v_orig.paddock_name` alongside its existing `v_orig.lot_id, v_orig.lot_name` copy.

**Positivity check (Pitfall 5, research recommendation, flag for confirmation):** `CHECK (amount > 0)` on `expenses.amount`, mirroring `doses.dosage_per_kg > 0`.

---

### `supabase/tests/07_expenses_test.sql` (test, pgTAP)

**Analogs:** `supabase/tests/06_sanitary_test.sql` (role/RLS group structure), `supabase/tests/04_movements_test.sql` (isolation-trigger assertions)

Structure to mirror: numbered assertion groups — cross-property isolation trigger rejects mismatched `paddock_id`/`property_id` (mirror `04_movements_test.sql`'s `trg_lots_paddock_same_property` group), `reader` role rejected on INSERT/UPDATE, `owner` **and** `veterinarian` both accepted on INSERT/UPDATE (the two-role novelty — no existing test group covers two accepted roles, write fresh but structurally identical to the single-role groups in `06_sanitary_test.sql`), SELECT allowed for all three roles, soft-delete + restore round-trip (Pitfall 3 case: restore-while-archived must affect exactly 1 row, not 0 — same shape as `06_sanitary_test.sql`'s Group 12 assertions added after G-06-2).

---

### `lib/features/gastos/data/expense_repository.dart` (service, CRUD)

**Analog:** `lib/features/sanitario/data/dose_repository.dart` (full file read, 152 lines)

**Full CRUD shape to copy** (imports, class shape, provider wiring):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'expense_model.dart';

class ExpenseRepository {
  ExpenseRepository(this._service);
  final SupabaseService _service;

  Future<List<Expense>> fetchExpensesByPaddock(
    String paddockId, {
    bool includeArchived = false,
  }) async {
    var query = _service.client
        .from('expenses')
        .select()
        .eq('paddock_id', paddockId);
    if (!includeArchived) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query.order('expense_date', ascending: false);
    return (rows as List)
        .map((r) => Expense.fromJson(r as Map<String, dynamic>))
        .toList();
  }
```

**Insert (do NOT send `created_by`/`updated_by` from the client — DB defaults/trigger own them, D-27):**
```dart
  Future<Expense> createExpense({
    required String propertyId,
    required String paddockId,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    final trimmedDescription = description?.trim();
    final row = await _service.client.from('expenses').insert({
      'property_id': propertyId,
      'paddock_id': paddockId,
      'category': category,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String().split('T').first,
      'description':
          (trimmedDescription == null || trimmedDescription.isEmpty)
              ? null
              : trimmedDescription,
    }).select().single();
    return Expense.fromJson(row);
  }
```

**`.select().single()` on every write — mandatory idiom, verbatim comment to keep** (`dose_repository.dart:100-114`):
```dart
  /// `.select().single()` forces a thrown error when RLS or a stale/wrong id
  /// silently matches zero rows — PostgREST otherwise answers 2xx on a 0-row
  /// UPDATE, the exact silent no-op class fixed server-side for the dose
  /// UPDATE policy in `20260812_06_fix_dose_update_policy.sql` (G-06-2).
  Future<void> archiveExpense(String id) async {
    await _service.client
        .from('expenses')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
  }

  Future<void> restoreExpense(String id) async {
    await _service.client
        .from('expenses')
        .update({'deleted_at': null})
        .eq('id', id)
        .select()
        .single();
  }
}
```

**Provider wiring** — sibling-provider toggle for archived (`dose_repository.dart:127-152`), same shape, but keyed on paddock, not property (this repo is `fetchExpensesByPaddock`, not `...ByProperty`):
```dart
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(supabaseServiceProvider)),
);

final expenseListByPaddockProvider =
    FutureProvider.family<List<Expense>, String>((ref, paddockId) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.fetchExpensesByPaddock(paddockId);
});

final archivedExpenseListByPaddockProvider =
    FutureProvider.family<List<Expense>, String>((ref, paddockId) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.fetchExpensesByPaddock(paddockId, includeArchived: true);
});
```

---

### `lib/features/gastos/data/expense_constants.dart` (config, transform)

**Analog:** `lib/features/animais/data/animal_constants.dart` (`kBreeds`, full file read, 102 lines)

Copy the `kBreeds` shape exactly — plain `const List<String>`, no CHECK constraint, no DB round-trip:
```dart
const List<String> kExpenseCategories = <String>[
  'racao_suplementacao',
  'sanidade_medicamentos',
  'mao_de_obra',
  'manutencao',
  'pastagem_adubacao',
  'combustivel',
  'arrendamento',
  'outros',
];

const Map<String, String> kExpenseCategoryLabels = <String, String>{
  'racao_suplementacao': 'Ração/Suplementação',
  'sanidade_medicamentos': 'Sanidade/Medicamentos',
  'mao_de_obra': 'Mão de obra',
  'manutencao': 'Manutenção',
  'pastagem_adubacao': 'Pastagem/Adubação',
  'combustivel': 'Combustível',
  'arrendamento': 'Arrendamento',
  'outros': 'Outros',
};

const Map<String, IconData> kExpenseCategoryIcons = <String, IconData>{
  // one entry per key above (D-05) — needs `flutter/material.dart` import,
  // unlike animal_constants.dart which has none
};
```
Note: this file needs `import 'package:flutter/material.dart';` for `IconData`, unlike `animal_constants.dart` which is pure Dart — the one structural deviation from the analog.

---

### `lib/features/gastos/data/expense_calculations.dart` (utility, pure/transform)

**Analog:** `lib/features/sanitario/data/sanitary_calculations.dart` (full file read, 61 lines) — copy the "zero Flutter/Riverpod/Supabase imports" constraint and the currency formatter verbatim (do not recreate `NumberFormat.currency`, D-18 note in RESEARCH.md explicitly says import `formatCurrencyBrl` rather than duplicate):
```dart
import 'package:intl/intl.dart';

/// D-18 ceiling: sum runs over the already-loaded list. If the list becomes
/// paginated, this total silently becomes "total of this page" — upgrade to
/// a server-side SUM()/RPC at that point, not before.
double totalAmount(Iterable<ExpenseListItem> items) =>
    items.fold(0.0, (sum, item) => sum + amountOf(item));

int itemCount(Iterable<ExpenseListItem> items) => items.length;
```
Reuse `formatCurrencyBrl` from `sanitary_calculations.dart` directly (import it) rather than redefining — same BRL-no-NBSP rationale documented at `sanitary_calculations.dart:56-59`.

---

### `lib/core/auth/role_gates.dart` (utility, transform — new file, no direct precedent)

**Analog (shape only):** `PaddockDetailScreen._canEdit` (`paddock_detail_screen.dart:84-94`) — same member-lookup shape, but this is the first **two-role** gate in the project. Full recommended body already in RESEARCH.md Pattern 5:
```dart
bool canManageExpenses(
  SelectedProperty? current,
  List<PropertyMembership>? members,
) {
  if (current == null || members == null) return false;
  final role = members
      .where((m) => m.property.id == current.id)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian' || role == 'owner';
}
```
**Pitfall 2 (explicit anti-pattern):** do NOT copy-paste `_canEdit` and forget to add `'owner'` — this is called out in RESEARCH.md as "the single most likely mistake in this phase."

---

### `lib/features/gastos/presentation/gastos_screen.dart` (component, request-response)

**Analog:** `lib/features/sanitario/presentation/sanitario_screen.dart` (807 lines — filter row + date-range picker + toggle read via targeted excerpt, lines 283-378)

**Filter row + date-range picker** (`sanitario_screen.dart:283-377`, copy the `showDateRangePicker` call verbatim, substitute dropdown-by-lot/dose for the D-16 preset-chip row + D-07 category dropdown):
```dart
Future<void> _pickDateRange() async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    initialDateRange: _dateRangeFilter,
    locale: const Locale('pt', 'BR'),
  );
  if (picked != null && mounted) {
    setState(() => _dateRangeFilter = picked);
  }
}
```
`SingleChildScrollView(scrollDirection: Axis.horizontal, ...)` wrapping a `Row` of filter controls is the exact horizontal-filter-row idiom (`sanitario_screen.dart:296-352`) — reuse for D-16's five preset chips + category dropdown + "Mostrar excluídos" toggle (label text at `sanitario_screen.dart:240`/`392`, `"Mostrar estornadas"`/`"Mostrar arquivadas"` → this phase's `"Mostrar excluídos"`).

**Empty state (two variants, D-13):** `piquetes_screen.dart`'s `_EmptyState` (lines 122-143+) is the shape to copy — `Center` → `Padding(32)` → `Column` → `Icon(size: 64, color: onSurface@0.3)` → `SizedBox(16)` → `Text(titleMedium)`. Build two instances (never-had vs filtered-to-zero) per the Copywriting Contract table in `07-UI-SPEC.md`.

**AppBar with explicit back button (D-14):** standard `AppBar(title: Text('Gastos — ${paddock.name}'))` — GoRouter default back button already appears on root-level routes reached by push; verify against `AplicacaoDetailScreen`'s AppBar for the exact idiom (same root-level-route class, D-08).

---

### `lib/features/gastos/presentation/expense_form_dialog.dart` (component, dialog/form)

**Analog:** `lib/features/sanitario/presentation/dose_form_dialog.dart` (full file read, 292 lines)

**Full dialog shape to copy** — `AlertDialog` with `title` swapping to `LinearProgressIndicator` while saving, `SizedBox(width: 480)` content, `Form` + `SingleChildScrollView`, `_saving`/`_errorMessage` state, `Navigator.pop(context, true/false)` on submit/cancel:
```dart
return AlertDialog(
  title: _saving
      ? const LinearProgressIndicator()
      : Text(_isEditing ? 'Editar gasto' : 'Novo gasto'),
  content: SizedBox(
    width: 480,
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ /* category dropdown, amount field, date picker, description */ ],
        ),
      ),
    ),
  ),
  actions: [
    if (_errorMessage != null)
      Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
    TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
    FilledButton(
      onPressed: _saving ? null : _submit,
      child: _saving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Salvar gasto'),
    ),
  ],
);
```

**Currency field (D-20)** — copy `_parseDouble` and the amount `TextFormField` verbatim (`dose_form_dialog.dart:82-88, 232-251`):
```dart
double? _parseDouble(String v) {
  final normalized = v.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
// TextFormField with:
keyboardType: const TextInputType.numberWithOptions(decimal: true),
inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
```
Unlike `costCtrl` (optional), `amount` is **required** — validator must reject empty/zero/negative (mirrors `_dosageCtrl`'s required-field validator at `dose_form_dialog.dart:207-219`, not `_costCtrl`'s optional one).

**Category dropdown (D-06):** mirrors `AnimalFormDialog`'s breed dropdown — starts `null`/empty, fixed order from `kExpenseCategories`, required validator. (Not excerpted here — same `DropdownButtonFormField` idiom as `sanitario_screen.dart`'s filter dropdowns at lines 301-314, but required and inside a `Form`.)

**Submit + provider invalidation + error mapping** (`dose_form_dialog.dart:90-146`) — copy the try/catch/finally shape; `ExpenseRepository` writes are direct-table (no RPC), so the `asSanitaryException` mapper is Phase 6-specific — write a plain try/catch instead, invalidating `expenseListByPaddockProvider(paddockId)` and `archivedExpenseListByPaddockProvider(paddockId)` on success (both list providers, mirroring the dual-invalidate at `dose_form_dialog.dart:132-133`).

**Delete confirmation dialog (D-28)** — new `AlertDialog`, title `'Excluir gasto de R\$ ${valor} de ${dd/MM}?'`, actions `'Cancelar'` / `'Excluir'` (error-colored `FilledButton`) — no direct file precedent cited by name in CONTEXT.md beyond "mirrors the piquete-delete `AlertDialog` pattern exactly"; check `piquetes_screen.dart`'s `_confirmDelete` (referenced at line 47) for the exact structure to copy.

---

### `lib/features/gastos/presentation/_expense_list_item_card.dart` (component, request-response)

**Analogs:** `piquetes_screen.dart`'s `_PaddockCard`, `sanitario_screen.dart`'s `_AplicacaoCard`/`_DoseCard`

Card shape: `theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)` for the primary label (category name / dose name — per UI-SPEC Typography table), `maxLines: 1` + `TextOverflow.ellipsis` on every title (established on every card title in the codebase per UI-SPEC "long-text" rows). Two render branches via `switch` on the `ExpenseListItem` sealed union (Pattern 4 in RESEARCH.md) — manual rows get edit/delete affordances, sanitary rows render read-only with a `"Sanitário"` badge and navigate to `AppRoutes.aplicacaoDetail(id)` on tap (D-32).

---

### `lib/features/piquetes/presentation/paddock_detail_screen.dart` (modified)

**Analog:** itself. Current file fully read (124 lines). Two changes required:
1. Add expense-summary card (D-09) below `_PaddockInfoCard` (currently at line 42-43) — a `Card` with title "Gastos", subtitle from a new `FutureProvider.family` scoped to current-month, `onTap` → `context.push(AppRoutes.gastosPorPiquete(paddockId))`.
2. **Do not extend `_canEdit`** (line 84-94, vet-only, gates "Novo lote" FAB) — call `canManageExpenses()` from `lib/core/auth/role_gates.dart` separately for the new card's visibility/tap-affordance, per D-23 ("dois gates diferentes convivendo"). This is the single highest-risk copy-paste mistake in the phase (Pitfall 2).

---

### `lib/core/router/routes.dart` / `lib/core/router/router.dart` (modified)

**Analog:** the existing `aplicacaoById` block in both files (`routes.dart:37-41`, `router.dart:146-153`) — same root-level-outside-shell pattern as D-08 requires.

**`routes.dart` addition** (mirror lines 37-41 exactly):
```dart
// Phase 7 detail route — root-level (outside shell, D-08): the expense
// list needs deep-link + back-button context of its own paddock, mirroring
// loteById/atfById/aplicacaoById above.
static const gastosById = '/gastos/:paddockId'; // template — used by GoRoute path
static String gastosPorPiquete(String id) => '/gastos/$id';
```

**`router.dart` addition** (mirror lines 149-153 exactly):
```dart
GoRoute(
  path: AppRoutes.gastosById,
  builder: (ctx, state) =>
      GastosScreen(paddockId: state.pathParameters['paddockId']!),
),
```
Note: existing precedents use `state.pathParameters['id']` (`aplicacaoById`) or `['atfId']`/`['loteId']` — this phase's constant should be named `paddockId` to stay self-documenting; the router `path:` template's segment name (`:paddockId`) must match this key exactly.

## Shared Patterns

### `.select().single()` on every UPDATE (silent no-op prevention)
**Source:** `lib/features/sanitario/data/dose_repository.dart:107-114`
**Apply to:** `expense_repository.dart` — every `update()` call (create/update/archive/restore), no exceptions. This is the G-06-2 regression class fixed once already; skipping it on any single write path reopens the bug class.

### RLS UPDATE policy must never restate `deleted_at IS NULL`
**Source:** `supabase/migrations/20260812_06_fix_dose_update_policy.sql` (the fix itself)
**Apply to:** `expenses` UPDATE policy in the Phase 7 migration — `USING`/`WITH CHECK` check only `is_member_of(property_id) AND get_role(property_id) IN ('owner','veterinarian')`, nothing about `deleted_at`.

### Cross-table isolation trigger (`BEFORE INSERT OR UPDATE`, `IS DISTINCT FROM OLD.*` guard)
**Source:** `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql`
**Apply to:** `trg_expenses_paddock_same_property` — copy the function body verbatim, substituting table/column names (full SQL in RESEARCH.md Pattern 2).

### Currency display — `formatCurrencyBrl`, not `NumberFormat.currency`
**Source:** `lib/features/sanitario/data/sanitary_calculations.dart:56-61`
**Apply to:** `expense_calculations.dart` (import, don't redefine), `_expense_list_item_card.dart`, `expense_form_dialog.dart` display of computed values. Do NOT introduce `NumberFormat.currency(locale: 'pt_BR')` (CONTEXT.md D-20 mentions it in passing, but RESEARCH.md flags the NBSP test-fragility issue the existing helper already avoids).

### Role gate: UI absence, not disabled control
**Source:** established project principle (RESEARCH.md, restated from every prior phase's `_canEdit` usage)
**Apply to:** `gastos_screen.dart` FAB, `expense_form_dialog.dart` edit affordance on sanitary rows (must never render edit/delete on sanitary rows — D-32 read-only), `paddock_detail_screen.dart`'s new expense card.

### Property/paddock-scoped provider resolving `currentPropertyProvider` internally
**Source:** `lib/features/sanitario/data/dose_repository.dart:136-152`
**Apply to:** all `expense_*` `FutureProvider`/`FutureProvider.family` — consuming widgets never pass a property id explicitly.

## No Analog Found

None — every file in the phase's scope has at least a role-match analog; the two genuinely novel pieces (`role_gates.dart`'s two-role gate, and the `ExpenseListItem` sealed-union merge) have documented recommended shapes in RESEARCH.md Patterns 4-5 even though no prior file in the codebase does exactly this.

## Metadata

**Analog search scope:** `lib/features/sanitario/`, `lib/features/piquetes/`, `lib/features/animais/`, `lib/core/router/`, `supabase/migrations/`, `supabase/tests/`
**Files scanned:** 11 Dart files (full or targeted reads) + 3 migration/test files referenced via RESEARCH.md excerpts (not re-read — already extracted verbatim in `07-RESEARCH.md`'s `## Code Examples` / `## Common Pitfalls` sections)
**Pattern extraction date:** 2026-08-11
