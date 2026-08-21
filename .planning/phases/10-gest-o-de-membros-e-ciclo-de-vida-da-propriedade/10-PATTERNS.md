# Phase 10: Gestão de Membros e Ciclo de Vida da Propriedade - Pattern Map

**Mapped:** 2026-08-14
**Files analyzed:** 16
**Analogs found:** 16 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/migrations/20260814_11_membership_lifecycle.sql` | migration | CRUD + event-driven (RPCs) | `supabase/migrations/20260814_10_medium_hardening.sql` (`move_lot_to_paddock`) | exact |
| `supabase/tests/11_membership_test.sql` | test | request-response (pgTAP) | `supabase/tests/07_expenses_test.sql` | exact |
| `lib/features/membros/data/invite_model.dart` | model | transform (freezed/json) | `lib/features/gastos/data/expense_model.dart` | exact |
| `lib/features/membros/data/member_model.dart` | model | transform (freezed/json) | `lib/features/gastos/data/expense_model.dart` | exact |
| `lib/features/membros/data/membro_repository.dart` | service | CRUD + RPC calls | `lib/features/gastos/data/expense_repository.dart` (RPC calls: `lib/features/auth/data/property_repository.dart`) | exact |
| `lib/features/membros/presentation/membros_screen.dart` | component (screen) | request-response, master-detail | `lib/features/gastos/presentation/gastos_property_screen.dart` | exact |
| `lib/features/membros/presentation/invite_form_dialog.dart` | component (dialog) | request-response | `lib/features/propriedades/presentation/property_form_dialog.dart` | exact |
| `lib/features/membros/presentation/archive_confirm_dialog.dart` | component (dialog) | request-response | `lib/features/propriedades/presentation/propriedades_screen.dart` (`_confirmDelete`) | role-match |
| `lib/features/auth/presentation/no_access_screen.dart` (MODIFIED) | component (screen) | request-response | itself (current version) + `EmptyState`/`WarningBanner` in `ui.dart` | exact |
| `lib/features/dashboard/presentation/dashboard_screen.dart` (MODIFIED) | component | event-driven (banner) | existing `_AlertsBanner`-style pattern in same file | exact |
| `lib/features/propriedades/presentation/propriedades_screen.dart` (MODIFIED) | component (screen) | CRUD, toggle/tab | itself (current version, `_PropertyCard`) | exact |
| `lib/features/propriedades/data/propriedade_repository.dart` (MODIFIED) | service | CRUD | itself (current version, `fetchProperties`/`softDeleteProperty`) | exact |
| `lib/core/auth/role_gates.dart` (MODIFIED) | utility | transform (predicate) | itself (`canManageExpenses`) | exact |
| `lib/core/router/routes.dart` (MODIFIED) | route | request-response | existing `loteById`-style template | exact |
| `lib/core/router/router.dart` (MODIFIED) | route | request-response | existing `loteById` registration | exact |
| `test/widget/membros_screen_test.dart` | test | request-response (widget) | `test/widget/gastos_property_screen_test.dart` | exact |

## Pattern Assignments

### `supabase/migrations/20260814_11_membership_lifecycle.sql` (migration, CRUD/event-driven)

**Analog:** `supabase/migrations/20260814_10_medium_hardening.sql` (function `move_lot_to_paddock`, lines 85-153) and `20260504_01_auth_multitenancy.sql` (`is_member_of`/`get_role`/`property_members`)

**RPC skeleton to copy** (lines 85-153 of 20260814_10):
```sql
CREATE OR REPLACE FUNCTION move_lot_to_paddock(...)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Load target row, validate exists/active
  -- 2. IF NOT is_member_of(...) THEN RAISE 42501
  -- 3. IF get_role(...) NOT IN (...) THEN RAISE 42501
  -- 4. business validation (23514/22023/23503)
  -- 5. UPDATE/INSERT/DELETE ... WHERE ... AND deleted_at IS NULL
  -- 6. IF NOT FOUND THEN RAISE 23503/P0002 (closes TOCTOU)
END;
$$;

REVOKE ALL ON FUNCTION move_lot_to_paddock(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION move_lot_to_paddock(uuid, uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION move_lot_to_paddock(uuid, uuid) FROM anon, PUBLIC;
```
Apply this exact shape to `create_invite`, `revoke_invite`, `accept_invite`, `decline_invite`, `remove_member`, `update_member_role`, `leave_property`. The REVOKE/GRANT footer (3 lines) is mandatory for every new function — recurring project gap called out in RESEARCH.md Security Domain table.

**Trigger-reuse pattern** (property_id immutability) — reuse `enforce_property_id_immutable()` verbatim on the new `invites` table (per CONTEXT.md, do not write a new trigger function), mirroring how `20260814_09` attached it to `property_members`.

**FORCE RLS + zero write policies** — new `invites` table must ship `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` and only SELECT policies, matching `dg_records`/`property_members` (see `20260814_09_multitenant_hardening.sql` for the precedent of dropping a write policy, and `20260504_01_auth_multitenancy.sql` for the original `property_members` table shape as the DDL analog).

**Concurrency lock-then-count pattern** — RESEARCH.md's Pattern 3 (`assert_not_last_veterinarian`) is itself the concrete code to use verbatim; it has no existing precedent function in the codebase (first of its kind) but follows the same `PERFORM ... FOR UPDATE` + separate `SELECT count(*)` two-statement shape already established for TOCTOU-closing in `move_lot_to_paddock` step 6.

---

### `lib/features/membros/data/invite_model.dart` / `member_model.dart` (model, transform)

**Analog:** `lib/features/gastos/data/expense_model.dart` (lines 1-32)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'invite_model.freezed.dart';
part 'invite_model.g.dart';

@freezed
sealed class Invite with _$Invite {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Invite({
    required String id,
    required String propertyId,
    required String invitedEmail,
    required String role,
    required String status,
    required String invitedBy,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _Invite;

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);
}
```
`@JsonSerializable(fieldRename: FieldRename.snake)` bridges Postgres snake_case → Dart camelCase — copy this exact annotation pair (freezed_annotation + json_serializable) for both new models.

---

### `lib/features/membros/data/membro_repository.dart` (service, CRUD/RPC)

**Analog:** `lib/features/gastos/data/expense_repository.dart` (class shape, provider) + `lib/features/auth/data/property_repository.dart` lines 38-50 (`.rpc()` call shape)

**Imports pattern:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
```

**RPC call pattern** (property_repository.dart lines 38-50):
```dart
Future<Property> createPropertyWithMembership({required String name, String? owner}) async {
  final result = await _service.client.rpc(
    'create_property_with_membership',
    params: {'p_name': name, if (owner != null) 'p_owner': owner},
  );
  return Property.fromJson(result as Map<String, dynamic>);
}
```
Use this exact `.rpc(name, params: {...})` shape for `createInvite`, `acceptInvite`, `declineInvite`, `revokeInvite`, `removeMember`, `updateMemberRole`, `leaveProperty` — all return `void` (`Future<void> => _service.client.rpc(...)`), no `Model.fromJson` needed since RPCs return void per RESEARCH.md.

**Read pattern** (expense_repository.dart lines 26-43, `fetchExpensesByPaddock`):
```dart
Future<List<Expense>> fetchExpensesByPaddock(String paddockId) async {
  final rows = await _service.client.from('expenses').select().eq('paddock_id', paddockId);
  return (rows as List).map((r) => Expense.fromJson(r as Map<String, dynamic>)).toList();
}
```
Use for `fetchMembers(propertyId)` and `fetchInvites(propertyId)` (`.from('invites').select().eq('property_id', ...)`).

**Provider footer:**
```dart
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(supabaseServiceProvider)),
);
```

---

### `lib/features/propriedades/data/propriedade_repository.dart` (MODIFIED — add `fetchArchivedProperties`/`restoreProperty`)

**Analog:** itself, `fetchProperties`/`softDeleteProperty` (lines 17-26, 71-76) and `expense_repository.dart`'s `restoreExpense` (lines 139-146)

```dart
// fetchArchivedProperties — mirror of fetchProperties but INVERTED filter
Future<List<Property>> fetchArchivedProperties() async {
  final rows = await _service.client
      .from('properties')
      .select()
      .not('deleted_at', 'is', null)
      .order('name');
  return (rows as List).map((r) => Property.fromJson(r as Map<String, dynamic>)).toList();
}

// restoreProperty — mirror of expense_repository.dart:139-146 restoreExpense
Future<void> restoreProperty(String id) async {
  await _service.client.from('properties').update({'deleted_at': null}).eq('id', id);
}
```
No new RLS/migration needed (Pitfall 4 in RESEARCH.md) — pure Dart addition.

---

### `lib/features/membros/presentation/membros_screen.dart` (component, master-detail)

**Analog:** `lib/features/gastos/presentation/gastos_property_screen.dart`

**Desktop panel pattern** (lines 428-448, `_buildPanel`):
```dart
Widget _buildPanel(...) {
  return Container(
    key: const ValueKey('gastos-painel'),
    width: 380,
    decoration: const BoxDecoration(
      color: AppColors.background,
      border: Border(left: BorderSide(color: AppColors.divider)),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ SectionCard(...), const SizedBox(height: 10), ... ],
      ),
    ),
  );
}
```
Reuse verbatim for the Membros desktop right panel ("Convidar membro" `SectionCard` CTA + "Convites pendentes" `SectionCard` list), per UI-SPEC's explicit instruction to clone `_buildPanel`.

**Breakpoint switch** (line 129): `final isDesktop = constraints.maxWidth >= Breakpoints.rail;` — copy this exact condition to branch mobile ListView vs desktop table+panel.

---

### `lib/features/membros/presentation/invite_form_dialog.dart` (component, dialog)

**Analog:** `lib/features/propriedades/presentation/property_form_dialog.dart` (full file, 1-152)

Copy the whole shape: `ConsumerStatefulWidget` + `GlobalKey<FormState>` + `_saving` bool + `_submit()` try/catch/finally + `SafeArea > Padding(EdgeInsets.fromLTRB(20,18,20,16)) > Form > Column` with title (20/700), fields, `SizedBox(height:20)`, footer `Row` of `Expanded(flex:10, OutlinedButton "Cancelar")` + `SizedBox(width:10)` + `Expanded(flex:14, FilledButton)`. For Membros, add a `DropdownButtonFormField<String>` for role (Veterinário/Proprietário/Leitor) instead of the second `TextFormField`, and call `membroRepository.createInvite(...)` in `_submit` instead of `createPropertyWithMembership`.

**Error handling pattern** (lines 58-65):
```dart
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erro ao salvar fazenda: $e')),
  );
} finally {
  if (mounted) setState(() => _saving = false);
}
```

---

### `lib/features/membros/presentation/archive_confirm_dialog.dart` (component, dialog)

**Analog:** `lib/features/propriedades/presentation/propriedades_screen.dart` (`_confirmDelete`, lines 119-173)

```dart
Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Property property) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.delete_outline, size: 21, color: AppColors.danger),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Remover fazenda')),
      ]),
      content: Text('Tem certeza...'),
      actions: [OutlinedButton(...'Cancelar'), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: AppColors.onDanger), ...'Remover')],
    ),
  );
}
```
For "Arquivar fazenda" this becomes a `showAdaptiveForm` (`FormWidth.confirm`, 440px) instead of plain `AlertDialog` (per UI-SPEC), with a `TextFormField` for the typed farm-name and `onPressed: null` until exact match — the icon container / danger color styling above is still the pattern to copy for the icon block.

---

### `lib/core/auth/role_gates.dart` (MODIFIED — add `canManageMembers`)

**Analog:** itself, `canManageExpenses` (lines 18-28)

```dart
bool canManageMembers(
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
Copy verbatim, rename only — same predicate shape as `canManageExpenses` (vet+owner), per CONTEXT.md's explicit instruction ("`canManageExpenses` em role_gates.dart mostra o padrão... criar gate análogo `canManageMembers`").

---

### `lib/features/auth/presentation/no_access_screen.dart` (MODIFIED)

**Analog:** itself (current file, full 1-43) — restructure `EmptyState`'s `message`/`action` per UI-SPEC's new copy, add invite list fetch/accept/decline using the same `ref.read`/`ConsumerWidget` shape already present (lines 10-42). `WarningBanner` widget (referenced in UI-SPEC, lives in `lib/core/widgets/ui.dart`) is the widget to use for surfacing pending invites, not a new bespoke banner.

---

### `test/widget/membros_screen_test.dart` (test)

**Analog:** `test/widget/gastos_property_screen_test.dart` — mirror its structure (`testWidgets`, mock repository via Riverpod `overrides`, `pumpWidget` + `pumpAndSettle`, assertions on rendered `Text`/`Finder`s for role-gated buttons).

---

## Shared Patterns

### RPC skeleton (is_member_of → get_role → business check → atomic write → REVOKE/GRANT)
**Source:** `supabase/migrations/20260814_10_medium_hardening.sql` lines 85-153 (`move_lot_to_paddock`)
**Apply to:** All 7 new RPCs in `20260814_11_membership_lifecycle.sql`

### Role gate — control absent, never disabled
**Source:** `lib/core/auth/role_gates.dart` (`canManageExpenses`), enforced in `propriedades_screen.dart` (`canEdit ? FloatingActionButton... : null`)
**Apply to:** `membros_screen.dart` (Convidar FAB/button, popup menu items), `propriedades_screen.dart`'s archive/restore controls — the one designed exception is the archive-confirm dialog's typed-name submit button, which uses `onPressed: null` for form-validity, not role-gating.

### showAdaptiveForm dialog shell (title 20/700, footer flex 10/14 buttons, EdgeInsets.fromLTRB(20,18,20,16))
**Source:** `lib/features/propriedades/presentation/property_form_dialog.dart` (full file)
**Apply to:** `invite_form_dialog.dart`, `archive_confirm_dialog.dart`

### Desktop master-detail 380px panel
**Source:** `lib/features/gastos/presentation/gastos_property_screen.dart` lines 428-448 (`_buildPanel`) + line 129 (`Breakpoints.rail` switch)
**Apply to:** `membros_screen.dart` desktop layout

### Repository provider + Supabase-only-through-service rule
**Source:** `lib/features/gastos/data/expense_repository.dart` lines 18-21, 180-182 (class + `Provider<T>`)
**Apply to:** `membro_repository.dart` — never import `supabase_flutter` directly in widgets; all access via `SupabaseService`.

### Invalidate memberPropertiesProvider after membership mutation
**Source:** `lib/features/propriedades/presentation/propriedades_screen.dart` lines 111-112, 170-171 (`ref.invalidate(propertyListProvider); ref.invalidate(memberPropertiesProvider);`)
**Apply to:** `acceptInvite`/`removeMember`/`updateMemberRole`/`leaveProperty` success handlers — this is also what drives the router's `/sem-acesso` redirect re-evaluation (RESEARCH.md "Don't Hand-Roll" table).

## No Analog Found

None — every file in scope has a strong (exact or role-match) precedent already in the codebase; this phase is explicitly "apply the established idiom to a new table/screen," confirmed by RESEARCH.md's own framing.

## Metadata

**Analog search scope:** `supabase/migrations/`, `supabase/tests/`, `lib/features/gastos/`, `lib/features/propriedades/`, `lib/features/auth/`, `lib/core/auth/`, `lib/core/providers/`, `test/widget/`
**Files scanned:** ~20 (migrations, repositories, screens, dialogs, gates, providers, tests)
**Pattern extraction date:** 2026-08-14
