# Phase 5: Reproductive Module (LoteATF) - Pattern Map

**Mapped:** 2026-08-04
**Files analyzed:** 18 (2 migrations + 1 modified migration table + 16 Dart files)
**Analogs found:** 18 / 18 (this phase is pure pattern-replication — RESEARCH.md confirms every building block already exists)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/migrations/20260804_05_reproductive_module.sql` (new tables `atf_batches`, `dg_records`; extend `animal_atf_memberships`) | migration | CRUD + event-driven (triggers) | `supabase/migrations/20260508_02_property_paddock.sql` (table+RLS shape) | exact |
| — `add_animals_to_atf` RPC | service (SQL RPC) | batch/event-driven | `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` (`move_animal_to_lot`) | exact |
| — `remove_animal_from_atf` RPC | service (SQL RPC) | request-response | `move_animal_to_lot` (guard shape) | role-match |
| — `save_dg_records` RPC | service (SQL RPC) | batch | `supabase/migrations/20260514_03_lots_animals.sql` `create_lot_with_animals` (jsonb loop) | exact |
| — `close_atf` RPC | service (SQL RPC) | batch | `move_animal_to_lot` | role-match |
| — `enforce_atf_membership_valid` trigger | middleware (DB trigger) | event-driven | `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` (`enforce_animal_lot_same_property`) | exact |
| — `trg_dg_records_same_property` trigger | middleware (DB trigger) | event-driven | same as above | exact |
| `lib/features/reproducao/data/atf_model.dart` | model | CRUD | `lib/features/lotes/data/lote_model.dart` | exact |
| `lib/features/reproducao/data/dg_record_model.dart` | model | CRUD | `lib/features/lotes/data/lote_model.dart` | exact |
| `lib/features/reproducao/data/atf_repository.dart` | service (repository) | CRUD + RPC | `lib/features/lotes/data/lote_repository.dart` (createLotWithAnimals/RPC shape) + `lib/features/animais/data/animal_repository.dart` (moveAnimal RPC-then-refetch shape) | exact |
| `lib/features/reproducao/presentation/reproducao_screen.dart` | component (list screen) | request-response | `lib/features/animais/presentation/animais_screen.dart` (toggle + in-memory filter) | exact |
| `lib/features/reproducao/presentation/atf_form_dialog.dart` | component (form dialog) | request-response | `lib/features/lotes/presentation/lote_form_dialog.dart` | exact |
| `lib/features/reproducao/presentation/atf_detail_screen.dart` | component (detail screen) | request-response | `lib/features/animais/presentation/animal_detail_screen.dart` (`AnimalInfoCard`/`_KvRow`) | exact |
| — `_DgChipRow` (inline in atf_detail_screen.dart) | component | request-response | `lib/features/animais/presentation/animal_edit_dialog.dart` (EC `ChoiceChip` `Wrap`) | exact |
| `lib/features/reproducao/presentation/atf_animal_selection_screen.dart` | component (picker screen) | request-response | `lib/features/animais/presentation/mover_animal_dialog.dart` (`_LotPickerList`) + `animais_screen.dart` (search/filter) | role-match |
| `lib/features/reproducao/presentation/encerrar_atf_dialog.dart` | component (confirm dialog) | request-response | `lib/features/animais/presentation/baixa_dialog.dart` | exact |
| `lib/features/animais/presentation/animal_detail_screen.dart` (modify `_PlaceholderSection` → `_ReproductiveHistorySection`) | component | request-response | same file's existing `_PlaceholderSection`/`AnimalInfoCard` pattern | exact |
| `lib/features/animais/data/animal_repository.dart` (`registerBaixa`: UPDATE → RPC) | service (repository) | request-response | `moveAnimal` in the same file (RPC-call shape) | exact |
| `lib/core/router/routes.dart` (add `atfById`/`atfDetail`) | config | — | `loteById`/`loteDetail` in same file | exact |
| `lib/core/router/router.dart` (register root-level `/atf/:atfId`) | route | — | root-level `GoRoute(path: AppRoutes.loteById, ...)` (router.dart:134-139) | exact |

## Pattern Assignments

### `supabase/migrations/20260804_05_reproductive_module.sql`

**Analogs:** `supabase/migrations/20260508_02_property_paddock.sql` (table+RLS shell), `20260715_04_gap_move_animal_to_lot.sql` + `20260716_04_animal_lot_property_trigger.sql` (RPC+trigger pair), `20260514_03_lots_animals.sql` (jsonb-array RPC loop).

**Table + RLS shape** (mirror `paddocks`, lines 70-111 of `20260508_02_property_paddock.sql`):
```sql
CREATE TABLE paddocks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  ...
  deleted_at  timestamptz
);
ALTER TABLE paddocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE paddocks FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_paddocks"
  ON paddocks FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "veterinarian_can_insert_paddock"
  ON paddocks FOR INSERT TO authenticated
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
```
Apply this exact shape to `atf_batches` (direct INSERT/SELECT policy, no UPDATE policy per Assumption A3). For `animal_atf_memberships`/`dg_records`, apply **SELECT-only** — no INSERT/UPDATE/DELETE policy at all (RESEARCH.md Pattern 1), forcing every write through a `SECURITY DEFINER` RPC.

**Extending the Phase 2 skeleton** (must add, per Pitfall 4 — currently `animal_id`/`atf_batch_id` have NO FK):
```sql
-- animal_atf_memberships already exists (20260508_02_property_paddock.sql:174-187) with
-- id, animal_id uuid NOT NULL, atf_batch_id uuid NOT NULL, active boolean, created_at.
-- Phase 5 must:
ALTER TABLE animal_atf_memberships
  ADD COLUMN property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  ADD CONSTRAINT animal_atf_memberships_animal_fk FOREIGN KEY (animal_id) REFERENCES animals(id),
  ADD CONSTRAINT animal_atf_memberships_atf_fk FOREIGN KEY (atf_batch_id) REFERENCES atf_batches(id);
-- animal_atf_memberships_active_idx (partial unique on animal_id WHERE active=true)
-- already exists — do not recreate.
```

**RPC pattern** (`add_animals_to_atf`, `save_dg_records`, `close_atf`, `remove_animal_from_atf`) — copy verbatim shape from `move_animal_to_lot` (`supabase/migrations/20260715_04_gap_move_animal_to_lot.sql:18-88`): derive `property_id` from a row lookup (never trust a client param), `is_member_of()` + `get_role() = 'veterinarian'::role_enum` guard, `RAISE EXCEPTION ... USING ERRCODE = '...'` (42501 forbidden, 23503 not-found/FK, 23514 check), `REVOKE ALL ... FROM public; GRANT EXECUTE ... TO authenticated;` at the end. RESEARCH.md's Code Examples section already contains the full bodies for `save_dg_records`/`close_atf`/`register_baixa` — reuse those verbatim, do not re-derive.

**Property-alignment trigger pattern** — copy `enforce_animal_lot_same_property` shape exactly (`20260716_04_animal_lot_property_trigger.sql:25-63`):
```sql
CREATE OR REPLACE FUNCTION enforce_atf_membership_valid()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  -- lookup animal's category+property_id, RAISE EXCEPTION with ERRCODE '23503'/'23514'
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_atf_membership_valid
  BEFORE INSERT ON animal_atf_memberships
  FOR EACH ROW EXECUTE FUNCTION enforce_atf_membership_valid();
```

**Do NOT add** `pg_advisory_xact_lock` to any Phase 5 RPC (Pitfall 3 — no sequence generation happens here, unlike `generate_animal_number`).

---

### `lib/features/reproducao/data/atf_model.dart` / `dg_record_model.dart`

**Analog:** `lib/features/lotes/data/lote_model.dart` (full file, 21 lines).

**Freezed model pattern** — copy verbatim structure:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'atf_model.freezed.dart';
part 'atf_model.g.dart';

@freezed
sealed class AtfBatch with _$AtfBatch {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AtfBatch({
    required String id,
    required String propertyId,
    required String name,
    required DateTime implantationDate,
    required DateTime inseminationDate,
    String? bullAnimalId,
    String? bullName,
    String? observation,
    required bool active,
    required DateTime createdAt,
  }) = _AtfBatch;

  factory AtfBatch.fromJson(Map<String, dynamic> json) => _$AtfBatchFromJson(json);
}
```
Same pattern for `DgRecord` (`id`, `propertyId`, `atfBatchId`, `animalId`, `result`, `examDate`, `observation`, `createdAt`).

---

### `lib/features/reproducao/data/atf_repository.dart`

**Analogs:** `lib/features/lotes/data/lote_repository.dart` (full file — RPC-with-params-dict, provider declarations), `lib/features/animais/data/animal_repository.dart` (`moveAnimal`, lines 178-192 — RPC-call-then-refetch shape).

**Imports pattern** (lote_repository.dart:1-6):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'lote_model.dart';
```

**Plain select-with-join pattern** (lote_repository.dart:134-171, `fetchLotsWithCountByProperty` — 2-query-and-group-in-Dart idiom, RESEARCH.md's recommended shape for `% prenhez` computation and for `fetchAtfBatchesByProperty`):
```dart
Future<List<LotWithPaddockCount>> fetchLotsWithCountByProperty(String propertyId) async {
  final lotRows = await _service.client
      .from('lots')
      .select('*, paddocks!inner(name)')
      .eq('property_id', propertyId)
      .isFilter('deleted_at', null)
      .order('name');
  final animalRows = await _service.client
      .from('animals')
      .select('lot_id')
      .eq('property_id', propertyId)
      .isFilter('deleted_at', null);
  // ... group in Dart, no SQL view
}
```

**RPC-with-params-dict pattern** (lote_repository.dart:50-70, `createLotWithAnimals` — analog for `createAtf`/`addAnimalsToAtf`/`saveDgRecords`/`closeAtf`):
```dart
Future<Lot> createLotWithAnimals({...}) async {
  final result = await _service.client.rpc(
    'create_lot_with_animals',
    params: {
      'p_property_id': propertyId,
      'p_paddock_id': paddockId,
      'p_name': name,
      'p_category_qtys': categoryQuantities,
      'p_category_breeds': categoryBreeds,
      'p_start_number': startNumber,
    },
  );
  return Lot.fromJson(result as Map<String, dynamic>);
}
```

**RPC-then-refetch pattern** (animal_repository.dart:178-192, `moveAnimal` — analog for `save_dg_records`/`close_atf` which return `void` and need a refetch):
```dart
Future<Animal> moveAnimal({required String id, required String newLotId}) async {
  await _service.client.rpc('move_animal_to_lot', params: {'p_animal_id': id, 'p_lot_id': newLotId});
  final row = await _service.client.from('animals').select().eq('id', id).single();
  return Animal.fromJson(row);
}
```

**Provider declarations** (lote_repository.dart:174-206):
```dart
final loteRepositoryProvider = Provider<LoteRepository>(
  (ref) => LoteRepository(ref.watch(supabaseServiceProvider)),
);
final loteByIdProvider = FutureProvider.family<Lot?, String>((ref, id) async {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLot(id);
});
final loteListByPropertyProvider = FutureProvider<List<Lot>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(loteRepositoryProvider);
  ...
});
```
Use this exact `FutureProvider`/`FutureProvider.family` + `currentPropertyProvider.future` watch pattern for `atfListByPropertyProvider`, `atfByIdProvider`, `dgRecordsByAtfProvider`, `reproductiveHistoryByAnimalProvider`.

---

### `lib/features/animais/data/animal_repository.dart` — `registerBaixa` (MODIFY: UPDATE → RPC)

**Current shape to replace** (animal_repository.dart:197-210):
```dart
Future<void> registerBaixa({
  required String id,
  required BaixaReason reason,
  required DateTime date,
  String? observation,
}) async {
  final payload = <String, dynamic>{
    'baixa_reason': reason.dbValue,
    'baixa_date': date.toUtc().toIso8601String().substring(0, 10),
    'deleted_at': DateTime.now().toUtc().toIso8601String(),
    if (observation != null) 'observation': observation,
  };
  await _service.client.from('animals').update(payload).eq('id', id);
}
```
**Target shape** (RESEARCH.md Code Examples, mirrors `moveAnimal`'s `.rpc()` call shape exactly — animal_repository.dart:178-192):
```dart
Future<void> registerBaixa({
  required String id,
  required BaixaReason reason,
  required DateTime date,
  String? observation,
}) async {
  await _service.client.rpc('register_baixa', params: {
    'p_animal_id': id,
    'p_reason': reason.dbValue,
    'p_date': date.toUtc().toIso8601String().substring(0, 10),
    if (observation != null) 'p_observation': observation,
  });
}
```
`BaixaDialog` (baixa_dialog.dart) needs NO changes — it already just calls `registerBaixa(...)` and invalidates providers; only the repository method body and the backing DB object (RPC vs direct UPDATE) change. `register_baixa` RPC body deactivates the ATF membership in the same transaction (D-19) — see the migration section above.

---

### `lib/features/reproducao/presentation/reproducao_screen.dart` (replacement)

**Analog:** `lib/features/animais/presentation/animais_screen.dart` (toggle + in-memory filter + debounced search, lines 1-70+).

**Toggle pattern** (animais_screen.dart:26, `_showArchived`) → same field/switch pattern for `_showEncerrados`. **AsyncValue.when scaffold** (animais_screen.dart:49-55):
```dart
return Scaffold(
  appBar: AppBar(title: const Text('Animais')),
  body: animalsAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (err, st) => const Center(child: Text('Erro ao carregar animais.')),
    data: (animals) { ... },
  ),
);
```
FAB role-gate: reuse `_canEdit` pattern from `animal_detail_screen.dart:117-127` (compares `currentPropertyProvider` + `memberPropertiesProvider` role to `'veterinarian'`).

---

### `lib/features/reproducao/presentation/atf_form_dialog.dart`

**Analog:** `lib/features/lotes/presentation/lote_form_dialog.dart` (full file, 223 lines).

**Dialog shell + save-state pattern** (lote_form_dialog.dart:139-222):
```dart
return AlertDialog(
  title: _saving ? const LinearProgressIndicator() : Text(_isEditing ? 'Editar lote' : 'Novo lote'),
  content: SizedBox(
    width: 480,
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [...]),
      ),
    ),
  ),
  actions: [
    TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
    FilledButton(
      onPressed: _saving ? null : _submit,
      child: _saving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(_isEditing ? 'Salvar' : 'Criar lote'),
    ),
  ],
);
```
**Submit try/catch/finally pattern** (lote_form_dialog.dart:61-133) — `setState(() => _saving = true)`, try RPC call, `ref.invalidate(...)`, `Navigator.pop(context, true)`, catch specific exception types first (`AnimalNumberConflictException` pattern → none needed here but keep the generic-catch-with-SnackBar fallback), `finally { if (mounted) setState(() => _saving = false); }`.

**Hybrid dropdown-with-reveal field** (D-05 touro field) — no direct analog exists; compose from `lote_form_dialog.dart`'s `DropdownButtonFormField<String?>` pattern (`_CategoryCompositionRow`, lines 325-350) + conditional reveal of a `TextFormField` when `'__other__'` is selected (same `setState`-driven conditional-child pattern already used in `AtfFormDialog`'s own dialog-level validator).

---

### `lib/features/reproducao/presentation/atf_detail_screen.dart`

**Analog:** `lib/features/animais/presentation/animal_detail_screen.dart` (`AnimalInfoCard` + `_KvRow`, lines 130-363).

**KvRow component** (animal_detail_screen.dart:335-363) — copy verbatim, reuse for `AtfHeaderCard`:
```dart
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: ...onSurface 60%)),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}
```
**Tappable cross-entity link** (animal_detail_screen.dart:216-240, lote-atual `InkWell`) — reuse for the "Touro" KvRow when `bullAnimalId` is set:
```dart
InkWell(
  onTap: () => context.go(AppRoutes.loteDetail(lot.id)),
  child: Text(lot.name, style: TextStyle(color: colorScheme.primary, decoration: TextDecoration.underline)),
)
```
**Status badge container** (animal_detail_screen.dart:279-297) — reuse shape for "Ativo"/"Encerrado" badge, swap colors per D-03/UI-SPEC (neutral, not green/red, for ATF status).

**DG chip row** — analog `animal_edit_dialog.dart`'s EC `ChoiceChip` Wrap (lines 114-129):
```dart
Wrap(
  spacing: 8,
  children: List.generate(5, (i) {
    final val = i + 1;
    return ChoiceChip(
      label: Text('$val'),
      selected: _ec == val,
      onSelected: (sel) => setState(() => _ec = sel ? val : null),
      showCheckmark: false,
    );
  }),
)
```
Adapt to 3 fixed chips (Prenha/Não-prenha/Duvidosa) with the semantic colors from UI-SPEC (`primaryContainer`/`errorContainer`/`tertiaryContainer`), `ConstrainedBox(minHeight: 48)` per chip per the mobile spacing exception.

---

### `lib/features/reproducao/presentation/atf_animal_selection_screen.dart`

**Analogs:** `lib/features/animais/presentation/mover_animal_dialog.dart` (`_LotPickerList`/`_LotPickerTile`, lines 131-218 — loading/error/empty `AsyncValue.when` + `ListView.builder` picker), `animais_screen.dart` (search debounce, lines 21-70).

**Picker list loading/error/empty pattern** (mover_animal_dialog.dart:147-178):
```dart
return lotsAsync.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Text('Erro ao carregar. Tente novamente.', style: theme.textTheme.bodyMedium),
  data: (lots) {
    final available = lots.where((l) => l.id != currentLotId).toList();
    if (available.isEmpty) { return Text('Nenhum outro lote disponível nesta propriedade.', ...); }
    return ListView.builder(shrinkWrap: true, itemCount: available.length, itemBuilder: (context, i) { ... });
  },
);
```
For disabled rows (D-07 "já em ATF [nome]"), use `CheckboxListTile(enabled: false, ...)` with trailing reason text (mirrors this file's `_LotPickerTile.selectedTileColor` convention but disabled instead of selected).

**Debounced search** (animais_screen.dart:21-42) — copy `_debounce`/`Timer`/`_onSearchChanged` verbatim for the avulsos search box.

---

### `lib/features/reproducao/presentation/encerrar_atf_dialog.dart`

**Analog:** `lib/features/animais/presentation/baixa_dialog.dart` (full file, 191 lines — near-identical structural template per UI-SPEC's explicit note).

**Confirm-dialog-with-warning-line pattern** (baixa_dialog.dart:104-189):
```dart
return AlertDialog(
  title: _saving ? const LinearProgressIndicator() : Text('Confirmar baixa do animal #${widget.animal.number}?'),
  content: SizedBox(
    width: 480, // EncerrarAtfDialog uses 400 per UI-SPEC
    child: SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Esta ação registra...', style: bodyMedium.italic),
        const SizedBox(height: 16),
        // EncerrarAtfDialog: conditional tertiary-colored warning line instead of SegmentedButton
      ],
    )),
  ),
  actions: [
    TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
    FilledButton(onPressed: _saving ? null : _submit, child: _saving ? spinner : const Text('Confirmar baixa')),
  ],
);
```
Note: `BaixaDialog`'s `FilledButton` uses `colorScheme.error` background — `EncerrarAtfDialog` must NOT copy that (UI-SPEC: "Encerrar" uses default primary color, not destructive-red).

---

### `lib/features/animais/presentation/animal_detail_screen.dart` — `_ReproductiveHistorySection` (replaces `_PlaceholderSection`)

**Analog:** the file's own `_PlaceholderSection` (lines 368-403) for the card shell, and `AnimalInfoCard`'s lot/paddock `AsyncValue.when` pattern (lines 219-240) for the loading/error/data states.

**Card shell to replace** (line ~101-104 currently instantiates):
```dart
const _PlaceholderSection(title: 'Histórico Reprodutivo', body: 'Disponível na Fase 5.'),
```
Replace with `_ReproductiveHistorySection(animalId: animal.id)` — new stateless/consumer widget using the same outlined-`Card` shell (`_PlaceholderSection`'s `RoundedRectangleBorder`/`borderRadius: 12`/`side: outline 38%` — lines 377-384) but rendering an `AsyncValue.when` list instead of static body text. The sanitary placeholder block directly below (lines 106-109) is untouched.

---

### `lib/core/router/routes.dart` / `lib/core/router/router.dart`

**Analog:** `loteById`/`loteDetail` (routes.dart:25,29) + root-level `GoRoute` registration (router.dart:133-139).

**routes.dart addition:**
```dart
static const atfById = '/atf/:atfId'; // template — root-level, mirrors loteById
static String atfDetail(String id) => '/atf/$id';
```
**router.dart addition** (same root-level block as `loteById`, router.dart:133-139):
```dart
// Phase 5 detail route — root-level, outside any shell branch (D-02, mirrors loteById)
GoRoute(
  path: AppRoutes.atfById,
  builder: (ctx, state) => AtfDetailScreen(
    atfId: state.pathParameters['atfId']!,
  ),
),
```

## Shared Patterns

### RLS + RPC isolation boundary (D-21, all backend files)
**Source:** `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` + `20260716_04_animal_lot_property_trigger.sql`
**Apply to:** every RPC and trigger in the Phase 5 migration.
```sql
-- RPC: never trust a client-supplied property_id; derive server-side, then:
IF NOT is_member_of(v_property_id) THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
-- Trigger: BEFORE INSERT OR UPDATE, access-path-independent, fires regardless of RPC vs raw PATCH.
```

### Repository — never import supabase_flutter directly
**Source:** every `*_repository.dart` file (T-3-09 rule, documented in `animal_repository.dart:28-30`)
**Apply to:** `atf_repository.dart` — only import `PostgrestException` type if needed for typed exceptions, all client calls via `_service.client` (injected `SupabaseService`).

### Dialog save-state template (AlertDialog + LinearProgressIndicator title-swap)
**Source:** `lote_form_dialog.dart`, `baixa_dialog.dart`, `animal_edit_dialog.dart`, `mover_animal_dialog.dart` (all 4 share this exact shape)
**Apply to:** `AtfFormDialog`, `EncerrarAtfDialog`, remove-animal confirm dialog.
```dart
bool _saving = false;
Future<void> _submit() async {
  setState(() => _saving = true);
  try {
    await ref.read(xRepositoryProvider).xMethod(...);
    ref.invalidate(xProvider);
    if (mounted) Navigator.pop(context, true);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao ... Tente novamente.')));
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}
```

### Date picker (pt-BR)
**Source:** `baixa_dialog.dart:51-65`
**Apply to:** `AtfFormDialog` (implantação/inseminação dates), `_DgSection` (session date + per-row override).
```dart
final _dateFmt = DateFormat('dd/MM/yyyy');
Future<void> _pickDate() async {
  final picked = await showDatePicker(
    context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now(),
    locale: const Locale('pt', 'BR'),
  );
  if (picked != null && mounted) setState(() { _date = picked; _dateCtrl.text = _dateFmt.format(picked); });
}
```

### Role gate (_canEdit)
**Source:** `animal_detail_screen.dart:117-127`
**Apply to:** FAB "Criar ATF", "+ Animais", remove-animal icon, "Encerrar ATF", "Salvar DGs" — all conditionally rendered (absence, not disabled).
```dart
bool _canEdit(SelectedProperty? current, List<PropertyMembership>? members) {
  if (current == null || members == null) return false;
  final role = members.where((m) => m.property.id == current.id).map((m) => m.role).firstOrNull;
  return role == 'veterinarian';
}
```

## No Analog Found

None — RESEARCH.md confirms this is a 100% pattern-replication phase; every file has a strong (exact or role-match) analog in Phases 2-4.

## Metadata

**Analog search scope:** `supabase/migrations/`, `lib/features/{lotes,animais,reproducao}/`, `lib/core/router/`
**Files scanned:** 12 (3 migrations, 2 models, 2 repositories, 6 presentation files) + `routes.dart`/`router.dart`
**Pattern extraction date:** 2026-08-04
