# Phase 6: Sanitary Module (Snapshot) - Pattern Map

**Mapped:** 2026-08-06
**Files analyzed:** 20 (2 migration files, 1 test file, 17 Dart files)
**Analogs found:** 20 / 20

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/migrations/20260810_06_sanitary_module.sql` | migration | CRUD + immutable-ledger | `supabase/migrations/20260805_05_atf_rpcs.sql` + `20260508_02_property_paddock.sql` §9 (skeleton being extended) | exact |
| `supabase/tests/06_sanitary_test.sql` | test | SQL/pgTAP | `supabase/tests/05_reproductive_test.sql` | exact |
| `lib/features/sanitario/data/dose_model.dart` | model | CRUD | `lib/features/lotes/data/lote_model.dart` | exact |
| `lib/features/sanitario/data/dose_repository.dart` | service | CRUD (direct RLS) | `lib/features/lotes/data/lote_repository.dart` | exact |
| `lib/features/sanitario/data/sanitary_application_model.dart` | model | request-response (frozen row) | `lib/features/reproducao/data/atf_model.dart` / `dg_record_model.dart` | role-match |
| `lib/features/sanitario/data/sanitary_application_repository.dart` | service | RPC + reads | `lib/features/reproducao/data/atf_repository.dart` | exact |
| `lib/features/sanitario/data/sanitary_application_exception.dart` | utility | error-mapping | none direct in codebase (new idiom, D-35) — modeled on RPC ERRCODE mapping style already used inline in `lote_repository.dart`/`atf_repository.dart` callers | no analog (new pattern, first phase-owned exception class) |
| `lib/features/sanitario/presentation/sanitario_screen.dart` | component | request-response (tabs + lists) | `lib/features/reproducao/presentation/reproducao_screen.dart` | exact |
| `lib/features/sanitario/presentation/dose_form_dialog.dart` | component | CRUD (form dialog) | `lib/features/lotes/presentation/lote_form_dialog.dart` (create/edit dialog pattern) | exact |
| `lib/features/sanitario/presentation/aplicacao_form_dialog.dart` | component | request-response (header-only dialog, no write) | `lib/features/reproducao/presentation/atf_form_dialog.dart` | exact |
| `lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart` | component | request-response (full-screen selection) | `lib/features/reproducao/presentation/atf_animal_selection_screen.dart` | exact |
| `lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart` | component | request-response (confirm + RPC write) | `lib/features/reproducao/presentation/atf_animal_selection_screen.dart` (`_confirm`) + `AnimalInfoCard`'s `BaixaDialog` (inline-error, new for this phase) | role-match |
| `lib/features/sanitario/presentation/aplicacao_detail_screen.dart` | component | request-response (read-only detail) | `lib/features/reproducao/presentation/atf_detail_screen.dart` / `lib/features/lotes/presentation/lote_detail_screen.dart` | exact |
| `lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart` | component | request-response (destructive confirm + RPC) | `BaixaDialog` (required-reason confirmation, Phase 4/5) | exact |
| `lib/features/lotes/presentation/lote_detail_screen.dart` (modified) | component | request-response (additive section + button) | itself — `_AnimalList` section + "Mover para piquete" footer button (D-06 Phase 4) | exact (self-analog) |
| `lib/features/animais/presentation/animal_detail_screen.dart` (modified) | component | request-response (replace placeholder) | itself — `_ReproductiveHistorySection` (D-14 Phase 5) | exact (self-analog) |
| `lib/core/router/routes.dart` (modified) | route | — | `loteById`/`loteDetail`, `atfById`/`atfDetail` (same file, lines 26-35) | exact (self-analog) |
| `lib/core/router/router.dart` (modified) | route | — | root-level `GoRoute(path: '/atf/:atfId')` registration | exact |
| `lib/features/propriedades/data/propriedade_model.dart` (modified) | model | — | itself — adding `kgPerUa` field, freezed regen | exact (self-analog) |

## Pattern Assignments

### `supabase/migrations/20260810_06_sanitary_module.sql` (migration)

**Analog:** `supabase/migrations/20260805_05_atf_rpcs.sql` (RPC shape) + `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` (isolation trigger) + `supabase/migrations/20260508_02_property_paddock.sql` §8-9 (partial unique index + skeleton table being extended)

**SECURITY DEFINER RPC skeleton** (`register_baixa`, quoted verbatim in RESEARCH.md Pattern 2 from `20260805_05_atf_rpcs.sql`):
```sql
CREATE OR REPLACE FUNCTION register_baixa(...) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id FROM animals WHERE id = p_animal_id AND deleted_at IS NULL;
  IF v_property_id IS NULL THEN RAISE EXCEPTION '...' USING ERRCODE = '23503'; END IF;
  IF NOT is_member_of(v_property_id) THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
  ...
END; $$;
REVOKE ALL ON FUNCTION register_baixa(...) FROM public;
GRANT EXECUTE ON FUNCTION register_baixa(...) TO authenticated;
```
The two Phase 6 RPCs (`register_sanitary_application`, `reverse_sanitary_application`) follow this shape exactly — resolve property_id, `is_member_of`, `get_role = veterinarian`, then the entity-specific logic. Full concrete drafts (already written, ready to copy into the migration) are in `06-RESEARCH.md` Code Examples §1-5.

**Isolation trigger** (`enforce_animal_lot_same_property`, `20260716_04_animal_lot_property_trigger.sql`):
```sql
CREATE OR REPLACE FUNCTION enforce_animal_lot_same_property() RETURNS trigger ...
CREATE TRIGGER trg_animals_lot_same_property BEFORE INSERT OR UPDATE ON animals ...
```
Phase 6 mirrors with `enforce_sanitary_application_same_property` / `trg_sanitary_applications_same_property`, `BEFORE INSERT` only (no `OR UPDATE` — `trg_snapshot_immutable` from Phase 2 already blocks every UPDATE/DELETE unconditionally).

**Partial unique index** (`animal_atf_memberships_active_idx`, `20260508_02_property_paddock.sql` §8):
```sql
CREATE UNIQUE INDEX animal_atf_memberships_active_idx
  ON animal_atf_memberships (animal_id) WHERE active = true;
```
Phase 6's estorno-uniqueness index (D-31):
```sql
CREATE UNIQUE INDEX sanitary_applications_reversal_idx
  ON sanitary_applications (reverses_application_id)
  WHERE reverses_application_id IS NOT NULL;
```

**Skeleton being extended** (`sanitary_applications`, `20260508_02_property_paddock.sql` §9, ~lines 189-214): already has `id`, `composition_snapshot jsonb NOT NULL`, `created_at`, `prevent_snapshot_mutation()` function + `trg_snapshot_immutable` `BEFORE UPDATE OR DELETE` trigger, RLS enabled with zero policies. This migration only `ALTER TABLE ... ADD COLUMN` (never recreate) — full column list in RESEARCH.md Code Examples §1.

**RLS policy pattern for `doses`** (mirrors `lots`/`atf_batches` direct-write CRUD — no RPC needed):
```sql
CREATE POLICY "members_can_read_doses" ON doses FOR SELECT TO authenticated
  USING (is_member_of(property_id));
CREATE POLICY "veterinarian_can_insert_dose" ON doses FOR INSERT TO authenticated
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
```
Matches the RLS shape already used for `lots` in `20260514_03_lots_animals.sql`.

---

### `lib/features/sanitario/data/sanitary_application_repository.dart` (service, RPC + reads)

**Analog:** `lib/features/reproducao/data/atf_repository.dart` (full file read — 452 lines)

**Imports pattern** (lines 1-15):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../animais/data/animal_model.dart';
import 'atf_model.dart';
```
Repository NEVER imports supabase_flutter directly — always via `SupabaseService` (T-3-09).

**Date-only formatting** (line 20, avoids timezone off-by-one, WR-03 lesson):
```dart
final _dateOnlyFmt = DateFormat('yyyy-MM-dd');
```
Apply to `applied_at` in `register_sanitary_application`'s params.

**Read query pattern** (lines 41-51):
```dart
Future<List<AtfBatch>> fetchAtfBatchesByProperty(String propertyId) async {
  final rows = await _service.client
      .from('atf_batches')
      .select()
      .eq('property_id', propertyId)
      .isFilter('deleted_at', null)
      .order('insemination_date', ascending: false);
  return (rows as List)
      .map((r) => AtfBatch.fromJson(r as Map<String, dynamic>))
      .toList();
}
```
Direct model for `fetchApplicationsByProperty`/`fetchApplicationsByLot` (SANI-04), ordered by `applied_at DESC` instead.

**RPC-call mutation pattern** (lines 312-323, `addAnimalsToAtf` — `p_animal_ids` is JSONB not `uuid[]`):
```dart
Future<void> addAnimalsToAtf({
  required String atfBatchId,
  required List<String> animalIds,
}) async {
  await _service.client.rpc('add_animals_to_atf', params: {
    'p_atf_batch_id': atfBatchId,
    'p_animal_ids': animalIds,
  });
}
```
Directly mirrors `register_sanitary_application`'s `p_animal_ids: jsonb` param — pass a `List<String>` and let the Supabase client serialize it, same idiom.

**Provider pattern** (lines 363-425):
```dart
final atfRepositoryProvider = Provider<AtfRepository>(
  (ref) => AtfRepository(ref.watch(supabaseServiceProvider)),
);

final atfListByPropertyProvider = FutureProvider<List<AtfSummary>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchAtfSummaries(property.id);
});

final reproductiveHistoryByAnimalProvider =
    FutureProvider.family<List<ReproductiveHistoryEntry>, String>(
        (ref, animalId) async {
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchReproductiveHistory(animalId);
});
```
`sanitaryHistoryByAnimalProvider(animalId)` (D-37 contract) copies `reproductiveHistoryByAnimalProvider`'s exact family-provider shape.

**GIN containment lookup** (RESEARCH.md Code Examples §7, Dart side):
```dart
Future<List<SanitaryHistoryEntry>> fetchSanitaryHistory(String animalId) async {
  final rows = await _service.client
      .from('sanitary_applications')
      .select()
      .contains('composition_snapshot', [{'animal_id': animalId}])
      .order('applied_at', ascending: false);
  return (rows as List)
      .map((r) => SanitaryApplication.fromJson(r as Map<String, dynamic>))
      .toList();
}
```

---

### `lib/features/sanitario/data/dose_repository.dart` (service, CRUD direct RLS)

**Analog:** `lib/features/lotes/data/lote_repository.dart` (full file read, lines 1-90+)

**Direct CRUD pattern** (create/read/update/soft-delete, lines 1-90):
```dart
class LoteRepository {
  LoteRepository(this._service);
  final SupabaseService _service;

  Future<List<Lot>> fetchLotsByPaddock(String paddockId) async {
    final rows = await _service.client
        .from('lots').select()
        .eq('paddock_id', paddockId)
        .isFilter('deleted_at', null)
        .order('name');
    return (rows as List).map((r) => Lot.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Lot?> fetchLot(String id) async {
    final row = await _service.client
        .from('lots').select().eq('id', id)
        .isFilter('deleted_at', null).maybeSingle();
    if (row == null) return null;
    return Lot.fromJson(row);
  }

  Future<Lot> updateLotName({required String id, required String name}) async {
    final row = await _service.client
        .from('lots').update({'name': name}).eq('id', id).select().single();
    return Lot.fromJson(row);
  }

  Future<void> softDeleteLot(String id) async {
    await _service.client.from('lots')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
```
`DoseRepository` copies this shape 1:1: `fetchDosesByProperty`, `fetchDose`, `createDose`, `updateDose`, `softDeleteDose` — all direct `.from('doses')` calls, no RPC, since dose CRUD is single-row/single-entity and covered by RLS `WITH CHECK`.

**RPC-with-params-dict pattern** (`createLotWithAnimals`, lines 50-70) is NOT needed for dose CRUD (no atomic parent+children write here) — reference only if a future create-with-derived-fields need arises.

---

### `lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart` (component, full-screen selection)

**Analog:** `lib/features/reproducao/presentation/atf_animal_selection_screen.dart` (full file read, 342 lines)

**Discard-confirm dialog** (lines 62-85, reuse verbatim per UI-SPEC):
```dart
Future<void> _onClosePressed() async {
  if (_selectedIds.isEmpty) {
    Navigator.pop(context);
    return;
  }
  final discard = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Descartar seleção?'),
      content: const Text('A seleção de animais será perdida.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Descartar')),
      ],
    ),
  );
  if (discard == true && mounted) Navigator.pop(context);
}
```

**Checkbox toggle + live-counter state** (lines 100-108, 305-340):
```dart
void _toggle(String animalId, bool? checked) {
  setState(() {
    if (checked == true) {
      _selectedIds.add(animalId);
    } else {
      _selectedIds.remove(animalId);
    }
  });
}

Widget _buildBottomBar(ThemeData theme) {
  final count = _selectedIds.length;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: Text(count == 0 ? 'Selecione ao menos 1 animal' : '$count selecionados')),
        FilledButton(
          onPressed: (_saving || count == 0) ? null : _confirm,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Adicionar animais'),
        ),
      ]),
    ),
  );
}
```
`SanitaryAnimalSelectionScreen` is simpler (single lot, no "lote base" picker, no avulsos section, per UI-SPEC §4) — drop the `_selectedLotId`/`_onLotChanged`/avulsos-search logic entirely, keep only the `ListView.builder(CheckboxListTile)` + bottom bar + discard-confirm, with the counter text formatted per D-21 (`"N de M selecionados · X,X UA"`).

**Row rendering** (lines 290-303):
```dart
Widget _buildRow(ThemeData theme, EligibleAnimal e) {
  final catLabel = kCategoryLabels[e.animal.category] ?? e.animal.category;
  return CheckboxListTile(
    value: _selectedIds.contains(e.animal.id),
    onChanged: (checked) => _toggle(e.animal.id, checked),
    title: Text('#${e.animal.number} · $catLabel'),
  );
}
```

**On-confirm pattern** (lines 110-142 — RPC call, provider invalidation, pop+snackbar, error handling):
```dart
Future<void> _confirm() async {
  if (_selectedIds.isEmpty) return;
  setState(() => _saving = true);
  try {
    await ref.read(atfRepositoryProvider).addAnimalsToAtf(
      atfBatchId: widget.atfId, animalIds: _selectedIds.toList(),
    );
    if (!mounted) return;
    ref.invalidate(atfActiveMembershipsProvider(widget.atfId));
    ...
    final count = _selectedIds.length;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('$count animais adicionados ao ATF.')));
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro...')));
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}
```
Note: Phase 6's `_confirm` on `SanitaryAnimalSelectionScreen`'s "Continuar" does NOT call the RPC directly (UI-SPEC: pushes `ResumoAplicacaoDialog` instead) — the RPC call + this exact try/catch/finally/pop/snackbar shape belongs in `ResumoAplicacaoDialog`'s final "Registrar aplicação" handler instead, with the addition of D-32/D-35 error mapping via `SanitaryApplicationException.fromPostgrest`.

---

### `lib/features/animais/presentation/animal_detail_screen.dart` — `_SanitaryHistorySection` (SANI-05, D-25)

**Analog:** same file, `_ReproductiveHistorySection` (lines 378-443) + `_ReproductiveHistoryRow` (445-520) + `_PlaceholderSection` (525+, being replaced)

**Section shell** (lines 378-443, copy verbatim structure):
```dart
class _ReproductiveHistorySection extends ConsumerWidget {
  const _ReproductiveHistorySection({required this.animalId});
  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(reproductiveHistoryByAnimalProvider(animalId));

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico Reprodutivo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              )),
              error: (err, st) => Text('Erro ao carregar histórico reprodutivo.', ...),
              data: (entries) {
                if (entries.isEmpty) {
                  return Text('Nenhum ATF registrado para este animal.', ...);
                }
                return Column(children: [for (final e in entries) _ReproductiveHistoryRow(entry: e, ...)]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```
`_SanitaryHistorySection` (D-25, D-37 standalone widget for Phase 8 reuse) is a near-literal copy: title `"Histórico Sanitário"`, watches `sanitaryHistoryByAnimalProvider(animalId)`, empty copy `"Nenhuma aplicação sanitária registrada para este animal."`, error copy `"Erro ao carregar histórico sanitário."` — must be built as its own top-level (not private `_`-prefixed only if D-37 needs external import; check UI-SPEC — file says exported per D-37 contract) widget file or exported class so Phase 8 can import it directly.

**Row-tap navigation pattern** (line 499):
```dart
onTap: () => context.go(AppRoutes.atfDetail(entry.atfBatchId)),
```
Sanitary row: `onTap: () => context.go(AppRoutes.aplicacaoDetail(entry.applicationId))`.

**Placeholder being replaced** (lines 525+):
```dart
class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.title, required this.body});
  ...
}
```
Currently instantiated for "Histórico Sanitário" around line 106 (per RESEARCH/CONTEXT) — that instantiation is deleted and replaced with `_SanitaryHistorySection(animalId: animal.id)`.

---

### `lib/features/lotes/presentation/lote_detail_screen.dart` — `_SanitaryHistorySection` (lote variant, D-20) + registration button (D-17/D-18)

**Analog:** self — `_AnimalList` section placement and the "Mover para piquete" footer-button gate pattern (D-06 Phase 4), same outlined-card shell as `_PlaceholderSection`/`_ReproductiveHistorySection` above.

Not re-read this session (file not opened) — planner/executor should read `lote_detail_screen.dart` directly for the exact "Mover para piquete" `OutlinedButton.icon` gate condition and the `_LoteHeaderCard` footer layout before implementing D-17/D-18/D-20; the gate condition string is already given verbatim in CONTEXT.md D-18: `lot.deletedAt == null && activeAnimalCount > 0 && _canEdit`, absence not disabled.

---

### `lib/core/router/routes.dart` / `router.dart` — `/aplicacoes/:id` (D-19)

**Analog:** same file, `loteById`/`loteDetail` and `atfById`/`atfDetail` (lines 26-35):
```dart
static const loteById = '/lotes/:loteId'; // template — used by GoRoute path
static String loteDetail(String id) => '/lotes/$id';

static const atfById = '/atf/:atfId'; // template — used by GoRoute path
static String atfDetail(String id) => '/atf/$id';
```
Add:
```dart
static const aplicacaoById = '/aplicacoes/:id';
static String aplicacaoDetail(String id) => '/aplicacoes/$id';
```
`router.dart` registers the matching root-level `GoRoute(path: AppRoutes.aplicacaoById, builder: ...)` mirroring the existing `atfById`/`loteById` registrations (not re-read this session — same file, same pattern, grep `GoRoute(path: AppRoutes.atfById` to find the exact insertion point).

---

## Shared Patterns

### SECURITY DEFINER RPC with role/membership guard
**Source:** `supabase/migrations/20260805_05_atf_rpcs.sql` (`register_baixa`)
**Apply to:** `register_sanitary_application`, `reverse_sanitary_application`
```sql
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
...
IF NOT is_member_of(v_property_id) THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
...
REVOKE ALL ON FUNCTION ... FROM public;
GRANT EXECUTE ON FUNCTION ... TO authenticated;
```

### Repository access boundary
**Source:** `lib/features/reproducao/data/atf_repository.dart` header comment
**Apply to:** all Phase 6 repositories
> "All Supabase access flows through SupabaseService — widgets must NEVER import supabase_flutter directly (T-3-09)."

### Riverpod provider shape
**Source:** `atf_repository.dart` lines 363-425
**Apply to:** all Phase 6 providers
```dart
final xRepositoryProvider = Provider<XRepository>((ref) => XRepository(ref.watch(supabaseServiceProvider)));
final xListByPropertyProvider = FutureProvider<List<X>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  return ref.watch(xRepositoryProvider).fetchXByProperty(property.id);
});
final xByIdProvider = FutureProvider.family<X?, String>((ref, id) async =>
  ref.watch(xRepositoryProvider).fetchX(id));
```

### Role-gated UI (absence, not disabled)
**Source:** `06-CONTEXT.md` D-18, established since Phase 3-5
**Apply to:** FAB on `SanitarioScreen`, dose edit/archive icons, "Registrar aplicação" button, "Estornar aplicação" button — all conditionally omitted from the widget tree, not shown-disabled.

### Discard-confirmation dialog
**Source:** `atf_animal_selection_screen.dart` lines 62-85
**Apply to:** `SanitaryAnimalSelectionScreen`'s close button — reuse verbatim (same copy: "Descartar seleção?" / "A seleção de animais será perdida.")

### Success/error snackbar + pop pattern
**Source:** `atf_animal_selection_screen.dart` lines 110-142
**Apply to:** `ResumoAplicacaoDialog` (register), `EstornarAplicacaoDialog` (reverse), `DoseFormDialog` (save) — try/RPC/invalidate providers/pop/SnackBar-success; catch/inline-or-snackbar-error/finally-reset-saving-flag. Note: `ResumoAplicacaoDialog` and `EstornarAplicacaoDialog` deviate per D-36 — error renders INLINE in the dialog (not a SnackBar), SnackBar reserved for success only in those two surfaces.

### Section-shell card (outlined, rounded 12)
**Source:** `animal_detail_screen.dart` `_PlaceholderSection`/`_ReproductiveHistorySection` (lines 378-443, 525+)
**Apply to:** `_SanitaryHistorySection` in both `AnimalDetailScreen` and `LoteDetailScreen`
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
  ),
  color: theme.colorScheme.surface,
  child: Padding(padding: const EdgeInsets.all(16), child: Column(...)),
)
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/sanitario/data/sanitary_application_exception.dart` | utility | error-mapping | First phase-owned typed exception class with an enum-of-ERRCODE-reasons (D-35). No prior phase built a dedicated exception class — errors were previously handled inline per-callsite. RESEARCH.md Code Examples §8 provides a full concrete draft to use directly; no codebase analog exists to point to instead. |
| `animal_ua_weight()` SQL function | migration helper | transform | No Postgres source of truth exists yet for `kUaWeights` (RESEARCH.md Pitfall 1) — this is a genuinely new piece of schema, not a copy of an existing function. RESEARCH.md Code Examples §2 provides the concrete function body (mirrors `lib/features/animais/data/animal_constants.dart`'s `kUaWeights` map, which IS the analog on the Dart side). |

## Metadata

**Analog search scope:** `lib/features/reproducao/`, `lib/features/lotes/`, `lib/features/animais/presentation/animal_detail_screen.dart`, `lib/core/router/`, `supabase/migrations/`, `supabase/tests/`
**Files scanned:** 8 read in full/targeted (atf_repository.dart, atf_animal_selection_screen.dart, lote_repository.dart, animal_detail_screen.dart §370-550, routes.dart grep), plus RESEARCH.md's own already-verified reads of `20260508_02_property_paddock.sql`, `20260716_04_animal_lot_property_trigger.sql`, `20260805_05_atf_rpcs.sql`, `05_reproductive_test.sql`
**Pattern extraction date:** 2026-08-06
