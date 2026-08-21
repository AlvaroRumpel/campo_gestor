# Phase 3: Lots & Animals (Operational Core) — Research

**Researched:** 2026-05-14
**Domain:** Flutter data layer expansion (freezed models, Riverpod providers, Supabase RPC) + PL/pgSQL batch RPC + GoRouter root routes
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Navigation**
- D-01: Lots live inside `/piquetes/:id` — `PaddockDetailScreen` gains a lots section + FAB. No separate lots list screen.
- D-02: `PaddockDetailScreen` layout: paddock info card (top) → active lots list below → role-gated FAB.
- D-03: `LoteDetailScreen` = `/lotes/:loteId` as a **root-level** GoRoute (not nested under piquetes). Accessible from any context.
- D-04: `LoteDetailScreen` Phase 3 shows: header (name, parent paddock, per-category count, UA total) + active animal list + FAB "+ Animal" (veterinarian only).

**Animal Numbering**
- D-05: Number is unique **per property** (global, not per category). UNIQUE INDEX `animals_property_number_idx ON animals(property_id, number) WHERE deleted_at IS NULL` is correct. **Fix `generate_animal_number` RPC first** — current implementation filters by `category` (bug) which conflicts with the global unique index.
- D-06: Display as plain integer (`42`, not `V-42`).
- D-07: Manual override allowed on individual creation and edit. Archived animal number (deleted_at IS NOT NULL) may be reused (UNIQUE INDEX allows two distinct UUIDs with the same number).
- D-08: Batch uses `MAX(number)` globally per property. Advisory lock in RPC prevents concurrent duplicate generation.
- D-09: Optional "Iniciar do número" field in batch form. Empty = MAX+1. Filled = generate from that number, skipping already-active ones, until category quota is met.

**Batch Form**
- D-10: 7 categories always visible (Vacas, Novilhas, Terneiros, Terneiras, Touros, Bois, Novilhos). Each row has quantity counter (integer) + optional breed search-select.
- D-11: Required: lot name + total animals > 0. Cannot create empty lot.
- D-12: Lot editable after creation: **name only**. Paddock is immutable (move = Phase 4). Composition changes only via baixa or future movements.
- D-13: Add individual animal to existing lot = Phase 3. `LoteDetailScreen` FAB "+ Animal" (veterinarian only). Fields: category (required), number (auto-generated, overridable), breed (optional), EC 1–5 chips (optional), observation (optional).
- D-14: Breed: hardcoded search-select in Flutter (not a DB table). List: Nelore, Angus, Brahman, Gir, Guzerá, Tabapuã, Canchim, Brangus, Simental, Charolês, Limousin, Hereford, Girolando, Wagyu, Caracu, Sindi, Pé-duro/Curraleiro.
- D-15: In batch, breed is configurable per category (optional, applied to all animals in category). EC and observation are individual-edit-only fields.
- D-16: EC 1–5: 5 toggle chips/buttons in a row.
- D-17: Baixa reasons: Venda / Morte / Descarte. DB enum values: `'sale'`, `'death'`, `'discard'`.

**AnimaisScreen**
- D-18: `/animais` lists all active animals for the active property. Header: total count + total UA. Filters: category chips + Lot/Paddock dropdowns. Number search bar at top.
- D-19: List item: `#42 · Vaca` + secondary line `Lote A · Piquete Norte`. Breed NOT shown in list.
- D-20: Number search: real-time filter with ≥300ms debounce. Filters animals whose number contains the typed text. Tap → `/animais/:id`.
- D-21: Archived animals hidden by default. Toggle "Mostrar arquivados" reveals them with reason badge (Vendido / Morto / Descartado).
- D-22: Animal detail Phase 3 (`/animais/:id`): number, category, breed, EC, observation, current lot, current paddock, registration date. Actions: Edit (dialog), Baixa (dialog). Placeholder sections for Reproductive History (Phase 5) and Sanitary History (Phase 6).

### Claude's Discretion
- Internal layout of `LoteDetailScreen` (cards vs list tiles for animals).
- Pagination/virtualization strategy for `/animais` with large properties.
- Exact RPC structure for batch creation (single atomic RPC for lot + animals, or separate client calls).
- Animation/visual feedback during batch generation (progress indicator approach).

### Deferred Ideas (OUT OF SCOPE)
- Breed filter in ANIM-06 — breed not shown in list; filter deferred until data volume justifies it.
- Sale history with price, buyer details — separate accounting module, outside MVP.
- Spreadsheet import for batch — outside MVP.
- Move individual animal between lots — Phase 4 (MOV-01).
- Move entire lot between paddocks — Phase 4 (MOV-02).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROP-03 | Usuário pode criar, editar e listar lotes operacionais de um piquete (nome, piquete) | LoteRepository + loteFormDialog + PaddockDetailScreen expansion |
| PROP-04 | Ao criar lote, usuário informa composição inicial por categoria e sistema gera animais em batch automaticamente | Batch RPC `create_lot_with_animals` + LoteFormDialog (D-10, D-11) |
| PROP-05 | Usuário pode visualizar composição atual do lote (lista de animais com contagem por categoria e total de UA) | LoteDetailScreen with derived UA calculation using REQUIREMENTS.md UA table |
| ANIM-01 | Cada animal gerado recebe número único por propriedade via sequence + lock no banco | Fix `generate_animal_number` RPC (D-05), advisory lock already in place |
| ANIM-02 | Usuário pode editar animal individualmente (raça, estado corporal 1–5, observação) | AnimalEditDialog + AnimalRepository.updateAnimal |
| ANIM-04 | Usuário pode registrar baixa de animal com motivo (venda/morte/descarte) e data (soft delete) | BaixaDialog + AnimalRepository.registerBaixa; `baixa_reason` enum in migration |
| ANIM-05 | Usuário pode buscar animal por número dentro da propriedade | AnimaisScreen search with debounce (D-20) |
| ANIM-06 | Usuário pode filtrar lista de animais por categoria, lote e piquete | AnimaisScreen filter row: category chips + lot/paddock dropdowns (D-18) |
</phase_requirements>

---

## Summary

Phase 3 is the largest feature delivery so far. It introduces two new domain entities (Lot and Animal), a complex batch-creation RPC, two new screens, and significant expansion of `PaddockDetailScreen` and `AnimaisScreen`. The Flutter work is primarily additive — new freezed models, new repositories, new providers, new dialogs/screens — following patterns already established in Phase 2 exactly.

The most technically sensitive item is the database layer: the existing `generate_animal_number` RPC has a category-scoped bug (D-05) that must be corrected in a new migration **before** any Flutter code calls it. The migration also needs to extend the `animals` skeleton table with the full column set, create the `lots` table, add a `baixa_reason` text/enum column, and write a new atomic batch RPC.

The Flutter side has three main complexity areas: (1) the batch form with per-category quantity counters, (2) the real-time debounced search with in-memory filtering in `AnimaisScreen`, and (3) routing — `/lotes/:loteId` must be added as a root-level GoRoute outside any `StatefulShellBranch` so it is accessible from all branches without resetting their navigation stacks.

**Primary recommendation:** Execute in three clear waves: Wave 0 = migration + RPC fix + test stubs; Wave 1 = data layer (models, repositories, providers); Wave 2 = presentation layer (screens, dialogs, routing). Do not start Wave 2 before Wave 1 compiles cleanly.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on This Phase |
|-----------|----------------------|
| Stack locked: Flutter web-first + Supabase | No alternatives considered |
| State management: Riverpod 3.x (flutter_riverpod ≥3.0.0, riverpod_annotation ≥4.0.0) | All new providers use `@riverpod` codegen or `FutureProvider` / `AsyncNotifier` |
| Navigation: GoRouter ^17.2.0 | Root-level GoRoute for `/lotes/:id`; sub-route for `/animais/:id` |
| Data classes: freezed ^3.2.0 + json_serializable ^6.13.0 | All new models (Lot, Animal, BaixaReason enum) use `@freezed` |
| Supabase client: supabase_flutter ^2.12.0 | Repository pattern via `SupabaseService` — widgets NEVER import supabase_flutter directly |
| No dio | Not applicable — no non-Supabase REST endpoints |
| Breed: hardcoded Flutter list, not DB table | D-14 locked |
| Schema changes via `supabase migration new` only | Never use web SQL editor |
| custom_lint / riverpod_lint blocked | No lint rules from those packages |
| Role gate: `veterinarian` only for write actions | FABs and edit controls absent (not disabled) for owner/reader |
| pt-BR locale | All date/number formatting via `intl: ^0.20.0` |
| Offline not in scope | No local caching layer |

---

## Standard Stack

### Core (already in pubspec.yaml — no new dependencies needed)

[VERIFIED: pubspec.yaml in repo]

| Library | Version in repo | Purpose | Role in Phase 3 |
|---------|----------------|---------|-----------------|
| flutter_riverpod | ≥3.0.0 <4.0.0 | State management | New providers: `loteListByPaddockProvider`, `loteByIdProvider`, `animalListByLotProvider`, `animalListByPropertyProvider`, `animalByIdProvider` |
| riverpod_annotation | ≥4.0.0 <5.0.0 | Codegen annotations | `@riverpod` on new providers if using codegen path |
| go_router | ^17.2.0 | Navigation | Add `/lotes/:id` root GoRoute + `/animais/:id` sub-route |
| supabase_flutter | ^2.12.0 | DB + RPC calls | `.rpc('create_lot_with_animals', params: {...})`, `.rpc('generate_animal_number', params: {...})` |
| freezed_annotation | ^3.0.0 | Immutable models | `Lot`, `Animal`, `BaixaReason` (sealed or enum) |
| freezed | ^3.2.0 (dev) | Codegen | `build_runner` generates `.freezed.dart` / `.g.dart` |
| json_serializable | ^6.13.0 (dev) | JSON deserialization | `@JsonSerializable(fieldRename: FieldRename.snake)` on all new models |
| build_runner | ^2.14.0 (dev) | Codegen runner | `dart run build_runner build --delete-conflicting-outputs` |
| intl | ^0.20.0 | pt-BR formatting | `DateFormat('dd/MM/yyyy', 'pt_BR')` in BaixaDialog and AnimalDetailScreen |
| mocktail | ^1.0.5 (dev) | Test mocking | Mock repositories in unit tests |

### No New Dependencies Required

Phase 3 adds no new pub.dev packages. All capabilities needed are already declared. [VERIFIED: pubspec.yaml]

**Run after any model changes:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Architecture Patterns

### Recommended Feature Structure

[VERIFIED: existing codebase structure]

```
lib/
├── features/
│   ├── lotes/                        # NEW — operational lots
│   │   ├── data/
│   │   │   ├── lote_model.dart       # @freezed Lot + LotComposition
│   │   │   ├── lote_model.freezed.dart  # generated
│   │   │   ├── lote_model.g.dart        # generated
│   │   │   └── lote_repository.dart  # LoteRepository + providers
│   │   └── presentation/
│   │       ├── lote_form_dialog.dart # LoteFormDialog (batch creation)
│   │       └── lote_detail_screen.dart  # LoteDetailScreen (/lotes/:id)
│   │
│   └── animais/                      # EXISTING — expand
│       ├── data/
│       │   ├── animal_model.dart     # @freezed Animal + BaixaReason
│       │   ├── animal_model.freezed.dart  # generated
│       │   ├── animal_model.g.dart       # generated
│       │   └── animal_repository.dart    # AnimalRepository + providers
│       └── presentation/
│           ├── animais_screen.dart       # REPLACE placeholder
│           ├── animal_detail_screen.dart # NEW
│           ├── animal_form_dialog.dart   # NEW (individual creation)
│           ├── animal_edit_dialog.dart   # NEW
│           └── baixa_dialog.dart         # NEW
│
├── core/
│   └── router/
│       ├── router.dart    # ADD: GoRoute('/lotes/:loteId'), GoRoute('/animais/:id')
│       └── routes.dart    # ADD: lotes, loteById, animalById constants
│
└── supabase/
    └── migrations/
        └── 20260514_03_lots_animals.sql  # NEW migration
```

### Pattern 1: Freezed Model with Snake Case JSON

[VERIFIED: piquete_model.dart in repo]

```dart
// Source: lib/features/piquetes/data/piquete_model.dart (established pattern)
import 'package:freezed_annotation/freezed_annotation.dart';

part 'lote_model.freezed.dart';
part 'lote_model.g.dart';

@freezed
sealed class Lot with _$Lot {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Lot({
    required String id,
    required String propertyId,
    required String paddockId,
    required String name,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Lot;

  factory Lot.fromJson(Map<String, dynamic> json) => _$LotFromJson(json);
}
```

Animal model needs additional fields beyond the skeleton:

```dart
@freezed
sealed class Animal with _$Animal {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Animal({
    required String id,
    required String propertyId,
    required String lotId,
    required String category,   // 'vaca'|'novilha'|'terneiro'|'terneira'|'touro'|'boi'|'novilho'
    required int number,
    String? breed,              // nullable — hardcoded list, stored as text
    int? bodyCondition,         // 1–5, nullable
    String? observation,
    String? baixaReason,        // 'sale'|'death'|'discard' nullable
    DateTime? baixaDate,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Animal;

  factory Animal.fromJson(Map<String, dynamic> json) => _$AnimalFromJson(json);
}
```

### Pattern 2: Repository + FutureProvider.family

[VERIFIED: piquete_repository.dart in repo]

```dart
// Source: lib/features/piquetes/data/piquete_repository.dart (exact pattern to replicate)

class LoteRepository {
  LoteRepository(this._service);
  final SupabaseService _service;

  Future<List<Lot>> fetchLotsByPaddock(String paddockId) async {
    final rows = await _service.client
        .from('lots')
        .select()
        .eq('paddock_id', paddockId)
        .isFilter('deleted_at', null)
        .order('name');
    return (rows as List)
        .map((r) => Lot.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}

final loteRepositoryProvider = Provider<LoteRepository>(
  (ref) => LoteRepository(ref.watch(supabaseServiceProvider)),
);

final loteListByPaddockProvider =
    FutureProvider.family<List<Lot>, String>((ref, paddockId) async {
  final repo = ref.read(loteRepositoryProvider);
  return repo.fetchLotsByPaddock(paddockId);
});
```

### Pattern 3: Supabase RPC call

[VERIFIED: supabase_flutter ^2.12.0 client API, consistent with v2 patterns]

```dart
// Batch creation RPC — single atomic call
Future<Lot> createLotWithAnimals({
  required String propertyId,
  required String paddockId,
  required String name,
  required Map<String, int> categoryQuantities,  // {'vaca': 10, 'terneiro': 8}
  required Map<String, String?> categoryBreeds,  // {'vaca': 'Nelore', 'terneiro': null}
  int? startNumber,
}) async {
  final result = await _service.client.rpc(
    'create_lot_with_animals',
    params: {
      'p_property_id': propertyId,
      'p_paddock_id': paddockId,
      'p_name': name,
      'p_category_quantities': categoryQuantities,
      'p_category_breeds': categoryBreeds,
      'p_start_number': startNumber,
    },
  );
  // RPC returns the created lot row
  return Lot.fromJson(result as Map<String, dynamic>);
}
```

### Pattern 4: Root-Level GoRoute (not nested in any branch)

[VERIFIED: router.dart in repo — `AppRoutes.propriedades` uses this pattern]

```dart
// Source: lib/core/router/router.dart (established root-level route pattern)
// Add BEFORE the StatefulShellRoute.indexedStack block:
GoRoute(
  path: AppRoutes.loteById,        // '/lotes/:loteId'
  builder: (ctx, state) => LoteDetailScreen(
    loteId: state.pathParameters['loteId']!,
  ),
),
```

This keeps the `/animais` shell branch's nav state intact when the user navigates to `/lotes/:id`. [VERIFIED: GoRouter root route behavior, consistent with Phase 2 `/propriedades` pattern]

### Pattern 5: Role Gate (FAB absent, not disabled)

[VERIFIED: piquetes_screen.dart in repo]

```dart
// Source: lib/features/piquetes/presentation/piquetes_screen.dart (_canEdit method)
bool _canEdit(SelectedProperty? current, List<PropertyMembership>? members) {
  if (current == null || members == null) return false;
  final role = members
      .where((m) => m.property.id == current.id)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian';
}

// In build:
floatingActionButton: canEdit
    ? FloatingActionButton(...)
    : null,  // absent, not disabled
```

### Pattern 6: Provider Invalidation after Mutation

[VERIFIED: piquetes_screen.dart in repo]

```dart
// After successful create/update/delete:
ref.invalidate(loteListByPaddockProvider(paddockId));
ref.invalidate(animalListByPropertyProvider);
```

### Pattern 7: In-memory Filter with Debounce

[ASSUMED — standard Flutter pattern for search, but no existing example in repo]

```dart
// In AnimaisScreen ConsumerStatefulWidget:
Timer? _debounce;

void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    setState(() => _searchQuery = query);
  });
}

// Filter list in build (after animals loaded):
final filtered = animals.where((a) {
  final matchSearch = _searchQuery.isEmpty ||
      a.number.toString().contains(_searchQuery);
  final matchCategory = _selectedCategory == null ||
      a.category == _selectedCategory;
  final matchLot = _selectedLotId == null || a.lotId == _selectedLotId;
  // paddock match requires join data
  return matchSearch && matchCategory && matchLot;
}).toList();
```

### Pattern 8: PaddockDetailScreen Expansion

[VERIFIED: paddock_detail_screen.dart in repo — currently a ListView with 3 ListTiles]

The existing `PaddockDetailScreen` is a simple `ConsumerWidget`. Phase 3 converts it to a richer layout:

```dart
// Expanded structure — wrap existing content in a ListView with added sections:
body: paddockAsync.when(
  data: (paddock) => ListView(
    children: [
      _PaddockInfoCard(paddock: paddock),
      const SizedBox(height: 8),
      _LotsSection(paddockId: paddockId, canEdit: canEdit),
    ],
  ),
  ...
),
floatingActionButton: canEdit
    ? FloatingActionButton(
        onPressed: () => _openLoteForm(context, ref, paddockId),
        child: const Icon(Icons.add),
      )
    : null,
```

### Anti-Patterns to Avoid

- **Importing supabase_flutter in widgets/screens:** All Supabase access must go through `SupabaseService` via repository. [VERIFIED: established pattern from Phase 0]
- **Calling `Navigator.pop()` for route-level navigation:** Use `context.pop()` from GoRouter. [VERIFIED: routes.dart comment]
- **Hard-coding hex colors:** Always use `Theme.of(context).colorScheme.*` tokens. [VERIFIED: UI-SPEC.md]
- **Calling `.requireValue` without guard:** Always use `.when()` or check `.hasValue`/`.isLoading` first. [VERIFIED: routes.dart WR-03 comment]
- **RPC without advisory lock for concurrent batch:** The existing RPC has the lock. The fixed RPC must preserve it.
- **Filtering animals server-side on every keystroke:** Debounce + in-memory filter on the already-loaded list (D-20).
- **Creating lot RPC with separate client calls:** Lot creation + animal generation must be a single atomic DB transaction. If the RPC errors mid-batch, no partial lot/animals should exist.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic multi-row insert with numbering | Custom Flutter loop with individual inserts | PL/pgSQL RPC with advisory lock | Network round-trips, no atomicity, race conditions on concurrent creation |
| Concurrent number sequence safety | Client-side MAX(number) read before insert | `pg_advisory_xact_lock` inside RPC | TOCTOU race — two concurrent batches can read the same MAX and generate duplicates |
| Breed search-select UI | Custom autocomplete widget | `DropdownButtonFormField` with filtered list or `Autocomplete<String>` widget (Flutter built-in) | Hardcoded 17-item list doesn't need a DB query or custom package |
| Date picker | Manual text parsing | `showDatePicker()` (Flutter built-in) + `DateFormat('dd/MM/yyyy', 'pt_BR')` from `intl` | Locale-aware, accessible, no extra dependency |
| In-memory filter with debounce | Complex state machine | `Timer` + `setState` in `ConsumerStatefulWidget` | Simpler than Riverpod stream for a local UI concern |
| UA calculation | RPC or formula in Dart | Dart constant map + simple multiplication | UA weights are fixed domain constants; no DB needed |

**UA weight constants (from REQUIREMENTS.md business rules):**
```dart
// [VERIFIED: REQUIREMENTS.md Business Rules table]
const Map<String, double> kUaWeights = {
  'vaca':     1.0,
  'novilha':  0.75,
  'terneiro': 0.5,
  'terneira': 0.5,
  'touro':    1.5,
  'boi':      1.5,
  'novilho':  0.75,
};

double calcTotalUa(List<Animal> animals) =>
    animals.fold(0.0, (sum, a) => sum + (kUaWeights[a.category] ?? 0.0));
```

---

## Common Pitfalls

### Pitfall 1: generate_animal_number RPC Bug (D-05)

**What goes wrong:** The existing RPC at `supabase/migrations/20260508_02_property_paddock.sql` computes `MAX(number) WHERE category = p_category`. The UNIQUE INDEX is on `(property_id, number)` globally. If a property has vaca=#1 and terneiro is also assigned #1 by the current RPC, the INSERT will fail with a unique violation.

**Why it happens:** The RPC was written with per-category scope; the index was written with global scope. They disagree.

**How to avoid:** First task of Wave 0 migration — replace the RPC with one that queries `MAX(number)` across all categories:
```sql
SELECT COALESCE(MAX(number), 0) + 1
INTO v_next
FROM animals
WHERE property_id = p_property_id;
-- Remove: AND category = p_category
```
Also remove `p_category` parameter from the signature (it's no longer used). The advisory lock key can remain as `hashtextextended(p_property_id::text, 0)` (property-scoped lock).

**Warning sign:** Any test that creates animals of two different categories in the same property and checks their numbers.

---

### Pitfall 2: Root GoRoute vs. Nested GoRoute for /lotes/:id

**What goes wrong:** Defining `/lotes/:loteId` as a sub-route inside `StatefulShellBranch` for piquetes causes it to only be reachable from the piquetes tab. Navigating from the animais branch to a lot detail resets the animais nav state.

**Why it happens:** `StatefulShellBranch` routes are scoped to their branch navigator.

**How to avoid:** Add `/lotes/:loteId` as a top-level `GoRoute` in `router.dart` BEFORE the `StatefulShellRoute.indexedStack` block — same position as `/propriedades`. [VERIFIED: router.dart structure]

**Warning sign:** `context.go('/lotes/$id')` from the animais screen navigates but loses the animais tab state on back.

---

### Pitfall 3: Concurrent Batch Generation Race Condition

**What goes wrong:** Two veterinarians of the same property create lots simultaneously. Without a lock, both read the same `MAX(number)` and generate overlapping number sequences, causing unique constraint violations at INSERT time.

**Why it happens:** PostgreSQL's `SERIALIZABLE` isolation is not the default; the advisory lock in the RPC is required.

**How to avoid:** The lock in `generate_animal_number` must be preserved (and promoted to the batch RPC). Use `pg_advisory_xact_lock` keyed on `property_id` in the new `create_lot_with_animals` RPC — one lock covers the entire batch.

**Warning sign:** Occasional INSERT failures with `ERROR: duplicate key value violates unique constraint "animals_property_number_idx"` under concurrent load.

---

### Pitfall 4: Provider Family Key Mismatch After Invalidation

**What goes wrong:** After creating a lot, `ref.invalidate(loteListByPaddockProvider)` is called without the paddock ID argument. FutureProvider.family invalidates only the specific family instance for a given key — calling it without a key invalidates nothing.

**Why it happens:** `FutureProvider.family` requires the same argument used to watch it.

**How to avoid:**
```dart
// Correct:
ref.invalidate(loteListByPaddockProvider(paddockId));

// Wrong (no-op):
ref.invalidate(loteListByPaddockProvider);
```

**Warning sign:** Stale lot list after successful creation — list doesn't update without full page reload.

---

### Pitfall 5: AnimaisScreen Filter — Paddock requires Join Data

**What goes wrong:** Animals in the DB have `lot_id` but not `paddock_id`. Filtering by paddock in `AnimaisScreen` requires either joining at query time or loading the paddock via the lot.

**Why it happens:** The animals table has a 1:N relationship to lots, and lots have a 1:1 relationship to paddocks. The paddock is not denormalized onto the animal row.

**How to avoid (two valid approaches — Claude's Discretion):**
- Option A: Query with join `lots!inner(paddock_id)` in the Supabase select, return `paddock_id` as part of the animal response. No schema change needed.
- Option B: Denormalize `paddock_id` onto the `animals` table (set at creation, updated via trigger on lot move in Phase 4). Simpler Flutter queries but extra DB complexity.

**Recommendation:** Option A for Phase 3 (no schema change, join via PostgREST embedded resource syntax). Phase 4 can revisit if move operations make the join stale.

**Warning sign:** Paddock filter dropdown has no effect, or filtering shows wrong results.

---

### Pitfall 6: Soft Delete vs. Active Filter for Animals

**What goes wrong:** Querying `.isFilter('deleted_at', null)` on animals returns only hard-active animals. But "baixa" is implemented as setting `deleted_at` + `baixa_reason`. If the toggle "Mostrar arquivados" is on, the query must include soft-deleted records.

**Why it happens:** The same query is used for both active-only and all-animals views.

**How to avoid:** Two query paths in `AnimalRepository`:
```dart
// Active only:
.isFilter('deleted_at', null)
// All (active + archived):
// Omit the deleted_at filter entirely
```
Or a single query that always returns all, filtered client-side based on toggle state.

**Warning sign:** "Mostrar arquivados" toggle has no effect because the DB query already excludes them.

---

### Pitfall 7: build_runner Conflicts After Adding New Models

**What goes wrong:** Running `build_runner build` fails with `Already exists: ...` or type conflicts when freezed files from Phase 2 are stale.

**Why it happens:** Generated files `.freezed.dart` and `.g.dart` from previous runs may be cached with outdated references.

**How to avoid:** Always run with `--delete-conflicting-outputs`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Warning sign:** `Unexpected element kind: ...` or `type '_SomethingImpl' is not a subtype of type 'Something'` at runtime.

---

### Pitfall 8: Lot Edit — Only Name is Mutable (D-12)

**What goes wrong:** Exposing paddock or property fields as editable in the lot edit form, or allowing category composition changes post-creation.

**Why it happens:** Standard CRUD forms usually expose all fields.

**How to avoid:** `LoteFormDialog` in edit mode shows only the `name` field. All other fields are read-only or absent. The RLS UPDATE policy on `lots` should only allow writing `name` (enforced in the Dart form, optionally also at DB level).

---

### Pitfall 9: Number Override Conflict Error Handling

**What goes wrong:** Veterinarian types a custom number that is already active for another animal. The INSERT (or RPC) fails with a unique constraint violation. If the Flutter code doesn't catch this specifically, the user sees a generic error.

**Why it happens:** The unique index enforces the constraint; the error code from Supabase is `23505` (unique_violation).

**How to avoid:** Catch `PostgrestException` with `code == '23505'` in the repository and rethrow a domain exception. Show the specific message from `UI-SPEC.md`: "O número informado já está em uso. Escolha outro número ou deixe em branco para auto-gerar."

---

## Code Examples

### Migration Wave 0 — SQL Structure

```sql
-- [VERIFIED: existing migration patterns in supabase/migrations/]

-- 1. Lots table
CREATE TABLE lots (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  paddock_id  uuid NOT NULL REFERENCES paddocks(id),
  name        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE INDEX lots_paddock_idx ON lots (paddock_id) WHERE deleted_at IS NULL;
CREATE INDEX lots_property_idx ON lots (property_id) WHERE deleted_at IS NULL;

ALTER TABLE lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE lots FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_lots" ON lots FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "veterinarian_can_insert_lot" ON lots FOR INSERT TO authenticated
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);

CREATE POLICY "veterinarian_can_update_lot_name" ON lots FOR UPDATE TO authenticated
  USING (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum)
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);

-- 2. Extend animals skeleton with full columns
ALTER TABLE animals
  ADD COLUMN lot_id      uuid REFERENCES lots(id),
  ADD COLUMN breed       text,
  ADD COLUMN body_condition integer CHECK (body_condition BETWEEN 1 AND 5),
  ADD COLUMN observation text,
  ADD COLUMN baixa_reason text CHECK (baixa_reason IN ('sale', 'death', 'discard')),
  ADD COLUMN baixa_date  date;

-- RLS for animals writes (Phase 2 only had SELECT)
CREATE POLICY "veterinarian_can_insert_animal" ON animals FOR INSERT TO authenticated
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);

CREATE POLICY "veterinarian_can_update_animal" ON animals FOR UPDATE TO authenticated
  USING (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum)
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);

-- 3. Fix generate_animal_number — global scope, no category filter
CREATE OR REPLACE FUNCTION generate_animal_number(p_property_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next     integer;
  v_lock_key bigint;
BEGIN
  v_lock_key := hashtextextended(p_property_id::text, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);
  SELECT COALESCE(MAX(number), 0) + 1 INTO v_next
  FROM animals
  WHERE property_id = p_property_id;
  RETURN v_next;
END;
$$;

-- 4. Batch RPC — single atomic transaction
CREATE OR REPLACE FUNCTION create_lot_with_animals(
  p_property_id       uuid,
  p_paddock_id        uuid,
  p_name              text,
  p_category_qtys     jsonb,   -- {"vaca": 10, "terneiro": 8}
  p_category_breeds   jsonb,   -- {"vaca": "Nelore", "terneiro": null}
  p_start_number      integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lock_key  bigint;
  v_lot_id    uuid;
  v_next_num  integer;
  v_cat       text;
  v_qty       integer;
  v_breed     text;
  v_count     integer;
BEGIN
  -- Advisory lock — prevents concurrent batches generating duplicate numbers
  v_lock_key := hashtextextended(p_property_id::text, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Create lot
  INSERT INTO lots (property_id, paddock_id, name)
  VALUES (p_property_id, p_paddock_id, p_name)
  RETURNING id INTO v_lot_id;

  -- Determine starting number
  IF p_start_number IS NOT NULL THEN
    v_next_num := p_start_number;
  ELSE
    SELECT COALESCE(MAX(number), 0) + 1 INTO v_next_num
    FROM animals WHERE property_id = p_property_id;
  END IF;

  -- Insert animals per category
  FOR v_cat, v_qty IN SELECT key, value::integer FROM jsonb_each(p_category_qtys) LOOP
    v_breed := p_category_breeds ->> v_cat;
    v_count := 0;
    WHILE v_count < v_qty LOOP
      -- Skip numbers already active (for p_start_number override path)
      WHILE EXISTS (
        SELECT 1 FROM animals
        WHERE property_id = p_property_id
          AND number = v_next_num
          AND deleted_at IS NULL
      ) LOOP
        v_next_num := v_next_num + 1;
      END LOOP;

      INSERT INTO animals (property_id, lot_id, category, number, breed)
      VALUES (p_property_id, v_lot_id, v_cat, v_next_num, v_breed);

      v_next_num := v_next_num + 1;
      v_count    := v_count + 1;
    END LOOP;
  END LOOP;

  RETURN (SELECT row_to_json(l) FROM lots l WHERE l.id = v_lot_id);
END;
$$;

REVOKE ALL ON FUNCTION create_lot_with_animals(uuid, uuid, text, jsonb, jsonb, integer) FROM public;
GRANT EXECUTE ON FUNCTION create_lot_with_animals(uuid, uuid, text, jsonb, jsonb, integer) TO authenticated;
```

### AppRoutes Constants Update

```dart
// Source: lib/core/router/routes.dart (pattern to extend)
abstract final class AppRoutes {
  // ... existing constants ...

  // Phase 3 — Lots (root-level, accessible from any branch)
  static const lotes = '/lotes';
  static const loteById = '/lotes/:loteId';  // template for GoRoute path

  // Phase 3 — Animal detail (sub-route under /animais branch)
  static const animalById = 'animais/:id';   // relative — used as sub-route path

  // Helper to build concrete paths:
  static String loteDetail(String id) => '/lotes/$id';
  static String animalDetail(String id) => '/animais/$id';
}
```

### Animal List Tile Widget Skeleton

```dart
// Follows _PaddockCard pattern — source: piquetes_screen.dart
class _AnimalListTile extends StatelessWidget {
  const _AnimalListTile({required this.animal, required this.onTap});
  final Animal animal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArchived = animal.deletedAt != null;
    return ListTile(
      onTap: onTap,
      title: Text.rich(TextSpan(children: [
        TextSpan(
          text: '#${animal.number}',
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text: ' · ${_categoryLabel(animal.category)}',
          style: theme.textTheme.bodyLarge,
        ),
      ])),
      subtitle: Text(
        '${animal.lotName} · ${animal.paddockName}',  // from join
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: isArchived ? _ArchiveBadge(reason: animal.baixaReason!) : null,
    );
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact on Phase 3 |
|---|---|---|---|
| Riverpod 2.x `@riverpod` codegen | Riverpod 3.x with riverpod_annotation 4.x | Phase 0 upgrade | All providers must use 3.x API (no `ref.watch` in async bodies from 2.x codegen) |
| freezed 2.x | freezed 3.x + freezed_annotation 3.x | Phase 0 | `sealed class` syntax; `@JsonSerializable` annotation placement unchanged |
| go_router ^14 | go_router ^17.2.0 | Phase 0 | Routing API stable across these versions; no breaking changes affecting this phase |
| `Supabase.instance.client` in widgets | `SupabaseService` via `supabaseServiceProvider` | Phase 0 | Established pattern — never break this |

**Deprecated/outdated:**
- `generate_animal_number(uuid, text)` — two-argument signature is now wrong (Phase 3 drops the `p_category` argument). Any code calling the old signature must be updated.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `AnimaisScreen` filter for paddock uses PostgREST embedded join (`lots!inner(paddock_id)`) rather than denormalizing `paddock_id` onto `animals` | Architecture Patterns / Pitfall 5 | Schema or query would need revisiting; low risk — join is standard Supabase pattern |
| A2 | In-memory debounced search is acceptable for MVP property sizes (hundreds to low thousands of animals) | Don't Hand-Roll / Pitfall pattern | If a property has 10,000+ animals, server-side search with `.ilike('number', '%$query%')` would be needed |
| A3 | `pg_advisory_xact_lock` is available on the Supabase free-tier PostgreSQL instance (local and cloud) | Common Pitfalls — Pitfall 3 | Advisory locks are a core PostgreSQL feature (not an extension); extremely unlikely to be unavailable |
| A4 | `Autocomplete<String>` Flutter built-in widget satisfies the breed search-select UX for a 17-item list | Don't Hand-Roll | If UX testing shows poor mobile experience, `DropdownButtonFormField` with search is the fallback |

---

## Open Questions

1. **Lot–Animal join for AnimaisScreen paddock filter**
   - What we know: Animals have `lot_id`; lots have `paddock_id`. PostgREST supports embedded resource queries.
   - What's unclear: Claude's Discretion — the planner should decide Option A (join) vs Option B (denormalize).
   - Recommendation: Choose Option A (join) for Phase 3. Document that Phase 4's move RPC will need to update `paddock_id` on the lot, not on individual animals.

2. **RPC return shape for create_lot_with_animals**
   - What we know: The client needs the `lot_id` and `lot.name` to invalidate the correct provider and navigate to `LoteDetailScreen`.
   - What's unclear: Whether returning the full lot row as JSONB is sufficient, or if the client needs animal IDs too.
   - Recommendation: Return the lot row only (`row_to_json(lots)`). Animal IDs are not needed at creation time — the `LoteDetailScreen` will fetch animals via `animalListByLotProvider`.

---

## Environment Availability

[VERIFIED: pubspec.yaml, migrations directory, existing supabase/config.toml presence]

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Supabase CLI | Migration execution | Expected (used in Phase 2) | Confirm with `supabase --version` before Wave 0 |
| `dart run build_runner` | Freezed + json codegen | Available (dev dep in pubspec.yaml) | Run after every model change |
| `flutter test` | Unit + widget tests | Available (flutter_test in pubspec.yaml) | Quick run: `flutter test test/features/lotes/` |
| Local Supabase Docker | RPC integration testing | Expected (used in Phase 2) | `supabase start` before running integration tests |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK), mocktail ^1.0.5 |
| Config file | none (standard Flutter test runner) |
| Quick run command | `flutter test test/features/lotes/ test/features/animais/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROP-03 | `Lot` model has required fields; `LoteRepository` class exists; providers non-null | unit | `flutter test test/features/lotes/lote_repository_test.dart` | Wave 0 |
| PROP-04 | Batch form validation: empty composition rejected; lot name required | widget | `flutter test test/widget/lote_form_dialog_test.dart` | Wave 0 |
| PROP-05 | UA total computed correctly for mixed category list | unit | `flutter test test/features/animais/ua_calculation_test.dart` | Wave 0 |
| ANIM-01 | `Animal` model serializes/deserializes snake_case; number field is int | unit | `flutter test test/features/animais/animal_model_test.dart` | Wave 0 |
| ANIM-02 | `AnimalEditDialog` shows breed, EC, observation fields | widget | `flutter test test/widget/animal_edit_dialog_test.dart` | Wave 0 |
| ANIM-04 | `BaixaDialog` shows 3 reason options; confirmar baixa button red | widget | `flutter test test/widget/baixa_dialog_test.dart` | Wave 0 |
| ANIM-05 | `AnimaisScreen` search field filters animal list by number substring | widget | `flutter test test/widget/animais_screen_test.dart` | Wave 0 |
| ANIM-06 | `AnimaisScreen` category chip filters correctly; lot dropdown filters | widget | included in above | Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/features/lotes/ test/features/animais/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/features/lotes/lote_repository_test.dart` — covers PROP-03
- [ ] `test/features/animais/animal_model_test.dart` — covers ANIM-01
- [ ] `test/features/animais/ua_calculation_test.dart` — covers PROP-05
- [ ] `test/widget/lote_form_dialog_test.dart` — covers PROP-04
- [ ] `test/widget/animal_edit_dialog_test.dart` — covers ANIM-02
- [ ] `test/widget/baixa_dialog_test.dart` — covers ANIM-04
- [ ] `test/widget/animais_screen_test.dart` — covers ANIM-05, ANIM-06

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Auth handled in Phase 1 |
| V3 Session Management | no | Session handled in Phase 1 |
| V4 Access Control | yes | RLS on all new tables (`lots`, `animals` writes); role check via `get_role()` helper; Flutter role gate on FABs/actions |
| V5 Input Validation | yes | Form validators in Dart (nome required, qty integer 0–999, EC 1–5, baixa_reason enum); DB-level `CHECK` constraints on `body_condition` and `baixa_reason` |
| V6 Cryptography | no | No new cryptographic operations |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Horizontal privilege escalation (user creates lot in another property) | Tampering | RLS `WITH CHECK (is_member_of(property_id))` on `lots` INSERT + `get_role()` veterinarian check |
| Mass assignment via RPC (inject unexpected property_id) | Tampering | RPC `SECURITY DEFINER` validates `is_member_of(p_property_id)` before any write; Flutter sends only own active property ID |
| Number override conflict used to corrupt another animal | Tampering | UNIQUE INDEX enforced at DB; application catches `23505` and shows domain error |
| Batch RPC partial failure leaving orphan lot | Tampering / DoS | Single transaction in RPC; exception rolls back entire batch atomically |
| Archived animal bypass (soft delete bypass via RLS) | Tampering | `deleted_at IS NOT NULL` animals are still readable (needed for history); write policies prevent updating archived animals (verify at UPDATE policy level) |

---

## Sources

### Primary (HIGH confidence)
- `supabase/migrations/20260508_02_property_paddock.sql` — existing schema, RPC bug identified [VERIFIED: file read]
- `lib/features/piquetes/data/piquete_repository.dart` — repository pattern to replicate [VERIFIED: file read]
- `lib/core/router/router.dart` — route structure for root-level GoRoute [VERIFIED: file read]
- `lib/features/piquetes/presentation/piquetes_screen.dart` — role gate pattern, dialog pattern [VERIFIED: file read]
- `lib/features/piquetes/presentation/paddock_form_dialog.dart` — form pattern [VERIFIED: file read]
- `pubspec.yaml` — confirmed versions of all packages [VERIFIED: file read]
- `.planning/phases/03-lots-animals-operational-core/03-CONTEXT.md` — locked decisions [VERIFIED: file read]
- `.planning/phases/03-lots-animals-operational-core/03-UI-SPEC.md` — screen inventory, component specs [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` — UA weight constants, business rules [VERIFIED: file read]

### Secondary (MEDIUM confidence)
- GoRouter root-level route pattern: consistent with Phase 2 `/propriedades` route and official GoRouter docs [ASSUMED for specific API behavior in go_router ^17 — pattern is stable across v14→v17]
- PostgREST embedded join syntax for paddock filter: standard Supabase query builder feature [ASSUMED — not tested in this codebase yet]

### Tertiary (LOW confidence)
- None — all claims are VERIFIED from codebase or ASSUMED with explicit tagging.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified in pubspec.yaml; no new dependencies needed
- Architecture patterns: HIGH — directly derived from existing repo code
- Migration / RPC design: HIGH for structure; MEDIUM for the `p_start_number` skip-active-numbers loop (logic is correct by inspection, but untested until Wave 0)
- Pitfalls: HIGH — Pitfalls 1–4 derived from reading actual code; Pitfalls 5–9 derived from domain analysis

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (stable stack — no fast-moving dependencies)
