---
phase: 03-lots-animals-operational-core
reviewed: 2026-05-15T00:00:00Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - lib/core/router/router.dart
  - lib/core/router/routes.dart
  - lib/features/animais/data/animal_constants.dart
  - lib/features/animais/data/animal_model.dart
  - lib/features/animais/data/animal_repository.dart
  - lib/features/animais/presentation/animais_screen.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - lib/features/animais/presentation/animal_edit_dialog.dart
  - lib/features/animais/presentation/animal_form_dialog.dart
  - lib/features/animais/presentation/baixa_dialog.dart
  - lib/features/lotes/data/lote_model.dart
  - lib/features/lotes/data/lote_repository.dart
  - lib/features/lotes/presentation/_lots_section.dart
  - lib/features/lotes/presentation/lote_detail_screen.dart
  - lib/features/lotes/presentation/lote_form_dialog.dart
  - lib/features/piquetes/presentation/paddock_detail_screen.dart
  - supabase/migrations/20260514_03_lots_animals.sql
  - test/features/animais/animal_model_test.dart
  - test/features/animais/ua_calculation_test.dart
  - test/features/lotes/lote_repository_test.dart
  - test/widget/animais_screen_test.dart
  - test/widget/animal_edit_dialog_test.dart
  - test/widget/baixa_dialog_test.dart
  - test/widget/lote_form_dialog_test.dart
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-15T00:00:00Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

Phase 3 delivers the operational core: the `lots` table, the `animals` column extension, two atomic RPCs (`generate_animal_number`, `create_lot_with_animals`), and the full Flutter surface (AnimaisScreen, AnimalDetailScreen, LoteDetailScreen, BaixaDialog, etc.). The architecture is sound — SECURITY DEFINER RPCs enforce role checks server-side, RLS policies are consistent with Phase 2 patterns, and the Dart layer correctly layers repositories behind providers.

No critical issues were found. Five warnings were identified, all of which are correctness risks rather than style preferences: a controller-leak in BaixaDialog, a silent number-generation failure in AnimalFormDialog, an empty-state logic bug in AnimaisScreen, a `ref.read` inside a `FutureProvider.family` body (missing reactivity), and a missing cache-invalidation in LotsSection after a lot is edited. Four informational items are also listed.

---

## Warnings

### WR-01: TextEditingController leak in BaixaDialog date field

**File:** `lib/features/animais/presentation/baixa_dialog.dart:139`

**Issue:** The date `TextFormField` is rendered with `controller: TextEditingController(text: _dateFmt.format(_date))` created inline inside `build()`. A new `TextEditingController` is allocated on every rebuild and is never disposed. On every call to `setState(() => _date = picked)` the old controller leaks. Flutter's `dispose()` method of the surrounding state (`_BaixaDialogState`) only disposes `_obsCtrl` (line 39), not this controller.

**Fix:** Promote the date controller to a field and dispose it alongside `_obsCtrl`:
```dart
// In _BaixaDialogState — add field:
late final TextEditingController _dateCtrl;

@override
void initState() {
  super.initState();
  _dateCtrl = TextEditingController(text: _dateFmt.format(_date));
}

@override
void dispose() {
  _obsCtrl.dispose();
  _dateCtrl.dispose();
  super.dispose();
}

// In _pickDate — update the controller after state is set:
Future<void> _pickDate() async {
  final picked = await showDatePicker(...);
  if (picked != null && mounted) {
    setState(() {
      _date = picked;
      _dateCtrl.text = _dateFmt.format(picked);
    });
  }
}

// In build — use the field:
TextFormField(
  readOnly: true,
  controller: _dateCtrl,
  ...
)
```

---

### WR-02: Silent swallow of `generateAnimalNumber` failure leaves field empty

**File:** `lib/features/animais/presentation/animal_form_dialog.dart:54-57`

**Issue:** In `_fetchAutoNumber`, the `catch (_)` block silently sets `_loadingNumber = false` without populating `_numberCtrl.text`. The hint text changes from "Carregando…" to "Auto-gerado", but the field remains empty. The `_submit()` validator at line 157-163 will then reject the form with "Informe o número", leaving the user with no number and no explanation of why the auto-generation failed. A network error or RPC permission error produces a confusing empty + invalid state.

**Fix:** Show a SnackBar explaining that auto-generation failed and ask the user to enter a number manually:
```dart
} catch (_) {
  if (!mounted) return;
  setState(() => _loadingNumber = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Não foi possível gerar o número automaticamente. Informe um número manualmente.',
      ),
    ),
  );
}
```

---

### WR-03: Empty-state logic bug in AnimaisScreen produces wrong widget

**File:** `lib/features/animais/presentation/animais_screen.dart:189-196`

**Issue:** The empty-state branch at line 189 evaluates a compound condition that has a logical error:

```dart
(animals.where((aw) =>
    _showArchived || aw.animal.deletedAt == null)
  .isEmpty &&
  animals.isEmpty)
  ? const _EmptyAllState()
  : filtered.isEmpty && animals.isNotEmpty
      ? const _EmptyFilterState()
      : const _EmptyAllState()
```

The first branch `(...isEmpty && animals.isEmpty)` can only be true if `animals` is empty — in which case both conditions collapse to `animals.isEmpty`. The outer `animals.where(...)` clause is redundant and the logic tree reduces to:
- If `animals.isEmpty` → `_EmptyAllState` (correct)
- Else if `filtered.isEmpty && animals.isNotEmpty` → `_EmptyFilterState` (correct)
- Else → `_EmptyAllState` (unreachable when `filtered.isEmpty` is the enclosing condition, because we only enter this block when `filtered.isEmpty`)

The final `else` branch is unreachable: we are already inside the `filtered.isEmpty` guard, and `animals.isNotEmpty` has already been handled by the previous arm. The intent was correct but the boolean nesting is confusing and fragile. The correct simplification is:

```dart
child: filtered.isEmpty
    ? animals.isEmpty
        ? const _EmptyAllState()
        : const _EmptyFilterState()
    : ListView.builder(...)
```

---

### WR-04: `ref.read` inside `FutureProvider.family` — missing reactivity

**File:** `lib/features/animais/data/animal_repository.dart:195-197`

**Issue:** Both `animalListByLotProvider` and `loteListByPaddockProvider` use `ref.read(animalRepositoryProvider)` (and `loteRepositoryProvider`) inside their `FutureProvider.family` bodies:

```dart
final animalListByLotProvider =
    FutureProvider.family<List<Animal>, String>((ref, lotId) async {
  final repo = ref.read(animalRepositoryProvider);  // ← ref.read
  return repo.fetchAnimalsByLot(lotId);
});
```

`ref.read` inside a provider does not create a dependency. If `animalRepositoryProvider` were ever rebuilt (e.g. due to a `SupabaseService` restart or override in tests), `animalListByLotProvider` would not re-run. The correct idiom is `ref.watch`. While `animalRepositoryProvider` is a simple `Provider<AnimalRepository>` that rarely changes, using `ref.read` in a provider body is an established Riverpod anti-pattern and risks subtle failures in tests that override `animalRepositoryProvider`. The same issue exists in `loteListByPaddockProvider` and `loteByIdProvider` in `lote_repository.dart` (lines 101, 108).

**Fix:** Replace `ref.read` with `ref.watch` in all `FutureProvider`/`FutureProvider.family` bodies:
```dart
final animalListByLotProvider =
    FutureProvider.family<List<Animal>, String>((ref, lotId) async {
  final repo = ref.watch(animalRepositoryProvider);  // ← ref.watch
  return repo.fetchAnimalsByLot(lotId);
});
```

---

### WR-05: `LotsSection._openEditDialog` does not await dialog result — cache not invalidated on successful lot rename

**File:** `lib/features/lotes/presentation/_lots_section.dart:67-76`

**Issue:** `_openEditDialog` calls `showDialog<bool>` but does not `await` the result and never invalidates `loteListByPaddockProvider` when the user saves a name change:

```dart
void _openEditDialog(BuildContext context, WidgetRef ref, Lot lot) {
  showDialog<bool>(          // ← not awaited; result discarded
    context: context,
    builder: (_) => LoteFormDialog(...),
  );
}
```

`LoteFormDialog` in edit mode (`existing != null`) calls `ref.invalidate(loteListByPaddockProvider(widget.paddockId))` itself (line 87 of `lote_form_dialog.dart`) — so the list does refresh. However, the dialog builder captures `_` from a `StatelessWidget` context (`_LotCard`) and cannot call `ref.invalidate`. The invalidation in `LoteFormDialog` happens on a separate `WidgetRef` and only works as long as that provider is actively watched. If the calling component has been unmounted by the time the dialog closes, the invalidation may silently no-op. Awaiting the result and calling invalidation from `LotsSection` (which holds `ref`) is the safer pattern:

```dart
Future<void> _openEditDialog(
    BuildContext context, WidgetRef ref, Lot lot) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => LoteFormDialog(
      paddockId: paddockId,
      propertyId: propertyId,
      existing: lot,
    ),
  );
  if (ok == true) {
    ref.invalidate(loteListByPaddockProvider(paddockId));
  }
}
```

---

## Info

### IN-01: Hardcoded paddock navigation string `/piquetes/${paddock.id}`

**File:** `lib/features/animais/presentation/animal_detail_screen.dart:241`

**Issue:** The paddock tap handler uses an inline string interpolation `/piquetes/${paddock.id}` instead of an `AppRoutes` helper:

```dart
onTap: () => context.go('/piquetes/${paddock.id}'),
```

All other navigation in the codebase routes through `AppRoutes` constants (e.g., `AppRoutes.loteDetail(lot.id)`, `AppRoutes.animalDetail(a.id)`). If the paddock detail path ever changes, this hardcoded string would be a silent miss.

**Fix:**
```dart
onTap: () => context.go('/piquetes/${paddock.id}'),
// → add AppRoutes.paddockDetail() helper or use existing path constant
onTap: () => context.go('${AppRoutes.piquetes}/${paddock.id}'),
```

---

### IN-02: `generate_animal_number` does not include soft-deleted animals in MAX computation

**File:** `supabase/migrations/20260514_03_lots_animals.sql:115-118`

**Issue:** The function computes `MAX(number)` across all animals for the property without excluding `deleted_at IS NOT NULL` rows:

```sql
SELECT COALESCE(MAX(number), 0) + 1
  INTO v_next
  FROM animals
 WHERE property_id = p_property_id;
```

This is intentional and correct — a soft-deleted animal's number should not be reused (D-05). However, the comment at line 115 does not document this design intent, which could cause a future maintainer to add `AND deleted_at IS NULL` erroneously. The same applies to the `create_lot_with_animals` MAX query at line 196.

**Fix (documentation only):** Add an inline comment:
```sql
SELECT COALESCE(MAX(number), 0) + 1
  INTO v_next
  FROM animals
 WHERE property_id = p_property_id;
 -- Intentionally includes soft-deleted animals: numbers are never reused (D-05)
```

---

### IN-03: `lote_repository_test.dart` contract tests only verify method existence

**File:** `test/features/lotes/lote_repository_test.dart:27-47`

**Issue:** The three repository contract tests (`fetchLotsByPaddock`, `createLotWithAnimals`, `updateLotName`) only assert `isA<Function>()` — they do not call the methods or verify behavior. This means the tests would pass even if the method signatures changed incompatibly. The comment in the file acknowledges this limitation ("contract tests verify method existence and Lot model correctness, which is sufficient for Wave 1"), which is acceptable for the stated scope but worth tracking.

**Fix:** No immediate action required — acknowledged technical debt. Consider upgrading to behavior tests when integration testing is added (noted in the test file comments as future work).

---

### IN-04: `_canEdit` logic duplicated across three screens

**File:** `lib/features/animais/presentation/animal_detail_screen.dart:103-113`, `lib/features/lotes/presentation/lote_detail_screen.dart:88-98`, `lib/features/piquetes/presentation/paddock_detail_screen.dart:84-94`

**Issue:** The identical `_canEdit(SelectedProperty?, List<PropertyMembership>?)` method body is copy-pasted verbatim across three screens. All three check `role == 'veterinarian'`. If the role name or membership model changes, all three need to be updated in sync.

**Fix:** Extract to a shared utility function or a Riverpod provider:
```dart
// In a shared auth_guards.dart or current_property_provider.dart
bool canEditForCurrentProperty(
  SelectedProperty? current,
  List<PropertyMembership>? members,
) {
  if (current == null || members == null) return false;
  final role = members
      .where((m) => m.property.id == current.id)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian';
}
```

---

_Reviewed: 2026-05-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
