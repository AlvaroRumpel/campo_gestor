# Phase 2: Property & Paddock Structure - Research

**Researched:** 2026-05-08
**Domain:** Flutter CRUD screens (propriedades + piquetes) + PostgreSQL schema additions + three PL/pgSQL backend prototypes
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `veterinário` = full admin (CRUD everything). Creates and manages client farms.
- **D-02:** `proprietário` = read-only for propriedades and piquetes.
- **D-03:** `leitor` = read-only (same level as proprietário this phase).
- **D-04:** Farm creator gains `veterinário` perfil via INSERT into `property_members`.
- **D-05:** `propriedades.proprietario` = free text. NOT a FK to `auth.users`.
- **D-06:** Read-only perfis: mutation actions (FAB, edit/delete buttons) are **absent from the widget tree** — no disabled/tooltip state.
- **D-07:** RLS blocks INSERT/UPDATE/DELETE for non-veterinários (defense in depth).
- **D-08:** New helper function `get_perfil(property_id)` needed for perfil-level RLS policy checks.
- **D-09:** `NoAccessScreen` gains CTA "Criar minha fazenda" → create property flow.
- **D-10:** `/propriedades` route for property management; accessible via "Gerenciar fazendas" in PropertySelector dropdown.
- **D-11:** Soft-delete on propriedades: `deleted_at timestamptz`. Records with `deleted_at IS NOT NULL` disappear from list and PropertySelector.
- **D-12:** App is **mobile-first** (overrides CLAUDE.md "web primário").
- **D-13:** Piquetes screen: vertical ListView + FAB. Material 3 mobile pattern.
- **D-14:** Each piquete list item shows: nome, área (ha), capacidade (UA).
- **D-15:** Tap piquete → `/piquetes/:id` detail screen. Edit/delete for `veterinário` only.
- **D-16:** Soft-deleted piquetes hidden (`WHERE deleted_at IS NULL`). No archived mode.
- **D-17:** `piquetes.capacidade_ua` = `NUMERIC(8,2)`.
- **D-18:** All 3 piquete fields required: `nome` (text), `area_ha` (NUMERIC(8,2)), `capacidade_ua` (NUMERIC(8,2)).
- **D-19:** `piquetes` has `deleted_at timestamptz`.
- **D-20:** RPC `gerar_numero_animal(p_propriedade_id uuid, p_categoria text)` — atomic sequence per (propriedade, categoria). Tested with 2+ parallel requests.
- **D-21:** JSONB column `composicao_snapshot` on sanitary applications table. `BEFORE UPDATE OR DELETE` trigger raises exception.
- **D-22:** Partial unique index `WHERE ativo = true` on `animais_lote_atf(animal_id)` for ATF uniqueness. Tested with duplicate-insert attempt.

### Claude's Discretion

- Implementation of `gerar_numero_animal` internals (SEQUENCE vs SELECT MAX + FOR UPDATE lock strategy).
- Visual design of propriedades and piquetes screens — Material 3, pt-BR, consistent with Phase 1 login screens.
- Piquete detail screen (`/piquetes/:id`) — info display + edit/delete buttons for veterinário. Phase 3 adds lotes.
- Form strategy (reactive_forms already in pubspec).
- Exact structure of RLS policies for `piquetes` (follow Phase 1 pattern with `is_member_of` + perfil check).

### Deferred Ideas (OUT OF SCOPE)

- Member management UI (invite/remove users from a farm) — Phase 2 does not include invite UI; link created via seed/Studio.
- Current UA calculation per piquete (requires lote + animal data — Phase 3).
- Lotes displayed inside piquete detail screen — Phase 3.
- Headcount capacity alongside UA — post-MVP if demanded.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROP-01 | Usuário pode criar, editar e listar propriedades (nome, proprietário) | Schema migration adds `deleted_at` + `proprietario` text to `propriedades`; RLS policies for veterinário writes; Flutter `PropriedadesScreen` + `PropertyFormDialog` |
| PROP-02 | Usuário pode criar, editar e listar piquetes de uma propriedade (nome, área em ha, capacidade) | New `piquetes` table with `area_ha`, `capacidade_ua`, `deleted_at`; RLS scoped to property membership; Flutter `PiquetesScreen` + `PiqueteFormDialog` + `PiqueteDetailScreen` |
</phase_requirements>

---

## Summary

Phase 2 has three distinct work streams that must all land before it is complete. First, the Flutter UI side: two new feature modules (`propriedades`, `piquetes`) each with a list screen, a create/edit form (adaptive dialog/sheet), and a detail screen for piquetes. Second, the database migration side: evolving the existing Phase 1 schema with `deleted_at` on `propriedades`, creating the `piquetes` table, and adding the `get_perfil()` helper plus RLS policies for both tables. Third, three risk-retirement backend prototypes with no UI: the `gerar_numero_animal` RPC with concurrency test, the `composicao_snapshot` JSONB immutability trigger, and the ATF partial unique index — all three validated via `supabase test db` with pgTAP.

The Flutter code patterns are deeply established: features follow `presentation/` + `data/` structure, state via Riverpod `AsyncNotifier` / `AsyncValue`, form validation mirrors Phase 1 (built-in `Form` + `TextFormField`, `autovalidateMode: AutovalidateMode.onUserInteraction`), and the repository pattern ensures widgets never import `supabase_flutter` directly. The design contract is fully specified in `02-UI-SPEC.md` — layout, spacing, typography, copywriting, role-based widget visibility, and adaptive form presentation rules are all locked.

The main implementation risks are: (1) perfil-based RLS policies introducing subtle bugs if `get_perfil()` is not written correctly as `SECURITY DEFINER`, (2) the `gerar_numero_animal` concurrency test requiring knowledge of how to run parallel requests from pgTAP or pgbench against local Supabase, and (3) router changes for `/propriedades` which sits outside the StatefulShellRoute branches and therefore needs a push-navigation pattern rather than branch switching.

**Primary recommendation:** Implement in waves — schema migration first (establishes the database contract all other work depends on), then Flutter data layer, then UI screens, then the three backend prototypes each with its pgTAP test.

---

## Standard Stack

### Core (already in pubspec.yaml — no new packages required)

| Library | Version (verified in pubspec) | Purpose | Why Standard |
|---------|-------------------------------|---------|--------------|
| flutter_riverpod | >=3.0.0 <4.0.0 | State management | Project standard; all existing providers use it |
| riverpod_annotation + riverpod_generator | >=4.0.0 <5.0.0 | Code-gen notifiers | Phase 0/1 pattern; `AsyncNotifier` for all async state |
| go_router | ^17.2.0 | Navigation | Project standard; web URL sync, shell routes |
| supabase_flutter | ^2.12.0 | Backend client | Project standard; PostgREST queries, RLS, auth |
| freezed_annotation + freezed | ^3.0.0 / ^3.2.0 | Immutable data classes | Project standard; use for `Piquete` and `Propriedade` models |
| json_annotation + json_serializable | ^4.11.0 / ^6.13.0 | JSON ↔ Dart | Project standard; snake_case from Supabase |
| build_runner | ^2.14.0 | Code generation | Required for freezed + riverpod_generator |
| intl | ^0.20.0 | pt-BR number formatting | Required for decimal comma in piquete form |
| shared_preferences | ^2.5.0 | User prefs | Already used for active property persistence |

[VERIFIED: pubspec.yaml in codebase]

### No New Packages Needed

Phase 2 introduces no new dependencies. All required libraries are already in pubspec.yaml. `reactive_forms` is listed as available in CLAUDE.md but is NOT in the current pubspec — do not add it unless the planner decides to use it over the built-in Form approach. The Phase 1 pattern uses built-in `Form` + `TextFormField` + `GlobalKey<FormState>` and that approach is sufficient for 2–3 field forms.

[VERIFIED: pubspec.yaml cross-checked against CLAUDE.md recommended stack]

---

## Architecture Patterns

### Recommended Project Structure (new additions in Phase 2)

```
lib/
├── core/
│   ├── router/
│   │   ├── routes.dart          # Add: propriedades, piqueteDetail routes
│   │   └── router.dart          # Add: /propriedades GoRoute + /piquetes/:id nested
│   └── widgets/
│       ├── property_selector.dart  # Modify: add "Gerenciar fazendas" menu item
│       ├── app_shell.dart          # No changes needed
│       └── empty_state.dart        # NEW: reusable empty state widget
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       └── no_access_screen.dart  # Modify: add "Criar minha fazenda" CTA
│   ├── propriedades/               # NEW feature module
│   │   ├── data/
│   │   │   ├── propriedade_model.dart        # freezed model
│   │   │   └── propriedade_repository.dart   # Supabase CRUD
│   │   └── presentation/
│   │       ├── propriedades_screen.dart      # list + FAB
│   │       └── property_form_dialog.dart     # create/edit form
│   └── piquetes/
│       ├── data/
│       │   ├── piquete_model.dart            # freezed model
│       │   └── piquete_repository.dart       # Supabase CRUD
│       └── presentation/
│           ├── piquetes_screen.dart          # list + FAB (replaces stub)
│           ├── piquete_form_dialog.dart      # create/edit form
│           └── piquete_detail_screen.dart    # detail view

supabase/
├── migrations/
│   └── 20260508_02_property_paddock.sql      # All Phase 2 schema changes
└── tests/
    └── 02_property_paddock_test.sql          # pgTAP tests
```

### Pattern 1: Feature Data Model (freezed + json_serializable)

Every domain entity is a `@freezed` class with `@JsonSerializable(fieldRename: FieldRename.snake)` to bridge Postgres snake_case → Dart camelCase automatically.

```dart
// Source: Phase 1 pattern (PropertyMembership) + CLAUDE.md freezed guidance
// File: lib/features/piquetes/data/piquete_model.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'piquete_model.freezed.dart';
part 'piquete_model.g.dart';

@freezed
@JsonSerializable(fieldRename: FieldRename.snake)
class Piquete with _$Piquete {
  const factory Piquete({
    required String id,
    required String propriedadeId,
    required String nome,
    required double areaHa,
    required double capacidadeUa,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Piquete;

  factory Piquete.fromJson(Map<String, dynamic> json) =>
      _$PiqueteFromJson(json);
}
```

Run `dart run build_runner build --delete-conflicting-outputs` after adding this file.

[ASSUMED] — freezed 3.x + json_serializable 6.13.x syntax; generation should work given existing pubspec, but verify with `build_runner build` output.

### Pattern 2: Repository (no direct supabase_flutter imports in UI)

```dart
// Source: lib/features/auth/data/property_repository.dart pattern
// File: lib/features/piquetes/data/piquete_repository.dart

class PiqueteRepository {
  PiqueteRepository(this._service);
  final SupabaseService _service;

  Future<List<Piquete>> fetchPiquetes(String propriedadeId) async {
    final rows = await _service.client
        .from('piquetes')
        .select()
        .eq('propriedade_id', propriedadeId)
        .isFilter('deleted_at', null)
        .order('nome');
    return rows.map((r) => Piquete.fromJson(r)).toList();
  }

  Future<Piquete> createPiquete({
    required String propriedadeId,
    required String nome,
    required double areaHa,
    required double capacidadeUa,
  }) async {
    final row = await _service.client
        .from('piquetes')
        .insert({
          'propriedade_id': propriedadeId,
          'nome': nome,
          'area_ha': areaHa,
          'capacidade_ua': capacidadeUa,
        })
        .select()
        .single();
    return Piquete.fromJson(row);
  }

  Future<void> softDelete(String piqueteId) async {
    await _service.client
        .from('piquetes')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', piqueteId);
  }
}

final piqueteRepositoryProvider = Provider<PiqueteRepository>(
  (ref) => PiqueteRepository(ref.watch(supabaseServiceProvider)),
);
```

[VERIFIED: mirrors property_repository.dart pattern exactly]

### Pattern 3: AsyncNotifier with currentPropertyProvider scoping

All piquete/propriedade state is scoped to the active property. The notifier watches `currentPropertyProvider` to invalidate when the user switches farm.

```dart
// Source: Riverpod 3.x pattern established in Phase 1
// File: lib/features/piquetes/data/piquete_repository.dart (provider section)

@riverpod
Future<List<Piquete>> piqueteList(Ref ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.read(piqueteRepositoryProvider);
  return repo.fetchPiquetes(property.id);
}
```

[VERIFIED: mirrors memberPropertiesProvider / currentPropertyProvider pattern from Phase 1]

### Pattern 4: Role-based widget visibility (D-06)

Never use `Visibility(visible: false)` or `Opacity(0)`. Conditionally include or exclude from the widget tree via `if`:

```dart
// Source: D-06 decision + 02-UI-SPEC.md "Role visibility" section
floatingActionButton: perfil == 'veterinario'
    ? FloatingActionButton(
        onPressed: _openCreateSheet,
        tooltip: 'Criar piquete',
        child: const Icon(Icons.add),
      )
    : null,
```

Perfil is obtained by watching a `perfilProvider` (or reading `memberPropertiesProvider` and filtering by `currentPropertyProvider`'s id).

### Pattern 5: Adaptive form presentation (dialog on wide, sheet on narrow)

```dart
// Source: 02-UI-SPEC.md "Create / Edit Property" section
void _openForm(BuildContext context, WidgetRef ref, {Piquete? editing}) {
  final isWide = MediaQuery.of(context).size.width >= 600;
  if (isWide) {
    showDialog(
      context: context,
      builder: (_) => PiqueteFormDialog(editing: editing),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PiqueteFormDialog(editing: editing),
    );
  }
}
```

[VERIFIED: breakpoint 600dp is the AppShell constant from app_shell.dart]

### Pattern 6: GoRouter — `/propriedades` as push route, `/piquetes/:id` as nested child

`/propriedades` is NOT a StatefulShellBranch (it has no nav-bar entry). It is a nested `GoRoute` inside the piquetes branch, or a root-level route pushed modally. The cleanest approach: add it as a child route inside the piquetes `StatefulShellBranch` so the AppShell remains visible.

```dart
// Source: router.dart StatefulShellBranch pattern
StatefulShellBranch(
  navigatorKey: _shellPiquetesKey,
  routes: [
    GoRoute(
      path: AppRoutes.piquetes,
      builder: (ctx, _) => const PiquetesScreen(),
      routes: [
        GoRoute(
          path: ':id',  // → /piquetes/:id
          builder: (ctx, state) =>
              PiqueteDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.propriedades,  // /propriedades
      builder: (ctx, _) => const PropriedadesScreen(),
    ),
  ],
),
```

[VERIFIED: GoRouter 17.x nested route pattern; go_router ^17.2.0 in pubspec]

### Pattern 7: SQL — get_perfil() helper function

```sql
-- Source: Phase 1 is_member_of() pattern (20260504_01_auth_multitenancy.sql)
CREATE OR REPLACE FUNCTION get_perfil(p_property_id uuid)
RETURNS perfil_enum
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT perfil FROM property_members
  WHERE user_id = auth.uid()
    AND property_id = p_property_id
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION get_perfil(uuid) FROM public;
GRANT EXECUTE ON FUNCTION get_perfil(uuid) TO authenticated;
```

[VERIFIED: mirrors is_member_of() structure from Phase 1 migration exactly]

### Pattern 8: gerar_numero_animal — advisory lock strategy

For atomic per-(propriedade, categoria) sequence without a separate sequences table, the recommended approach is `pg_advisory_xact_lock` + `SELECT MAX(numero) + 1 ... FOR UPDATE`. A dedicated sequence object per (propriedade, categoria) pair would require dynamic DDL, which is fragile. The advisory lock approach:

```sql
-- Source: [ASSUMED] PostgreSQL advisory lock pattern for per-tenant sequences
CREATE OR REPLACE FUNCTION gerar_numero_animal(
  p_propriedade_id uuid,
  p_categoria text
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next integer;
  v_lock_key bigint;
BEGIN
  -- Derive a deterministic lock key from (propriedade_id, categoria).
  -- hashtext combines two values into a stable bigint.
  v_lock_key := hashtext(p_propriedade_id::text || '|' || p_categoria);
  
  -- Advisory transaction lock: blocks concurrent calls with same key
  -- until this transaction commits. Automatically released on commit/rollback.
  PERFORM pg_advisory_xact_lock(v_lock_key);
  
  SELECT COALESCE(MAX(numero), 0) + 1
  INTO v_next
  FROM animais
  WHERE propriedade_id = p_propriedade_id
    AND categoria = p_categoria;
    -- Note: includes soft-deleted animals (deleted_at IS NOT NULL)
    -- so numbers are never reused after baixa (business rule ANIM-01).
  
  RETURN v_next;
END;
$$;
```

[ASSUMED] — `pg_advisory_xact_lock` approach is the standard PostgreSQL pattern for per-tenant sequences. The `animais` table does not exist yet in Phase 2 (it lands in Phase 3), so this RPC is created against a stub or the actual table is created as a forward-reference skeleton. See Open Questions.

### Pattern 9: composicao_snapshot immutability trigger

```sql
-- Source: D-21 + CONTEXT.md specifics section
-- Table: aplicacoes_sanitarias (Phase 6 target, skeleton created Phase 2)
CREATE OR REPLACE FUNCTION prevent_snapshot_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'snapshot is immutable — aplicacoes_sanitarias rows cannot be modified or deleted';
END;
$$;

CREATE TRIGGER trg_snapshot_immutable
BEFORE UPDATE OR DELETE ON aplicacoes_sanitarias
FOR EACH ROW
EXECUTE FUNCTION prevent_snapshot_mutation();
```

[VERIFIED: trigger syntax from PostgreSQL docs matches this pattern; RAISE EXCEPTION is the correct mechanism]

### Pattern 10: ATF partial unique index

```sql
-- Source: D-22 + CONTEXT.md specifics
-- Exact SQL from context:
CREATE UNIQUE INDEX animais_lote_atf_ativo_idx
  ON animais_lote_atf (animal_id)
  WHERE ativo = true;
```

[VERIFIED: partial unique index syntax confirmed from CONTEXT.md specifics section]

### Pattern 11: pgTAP test structure

```sql
-- Source: [ASSUMED] pgTAP standard structure for Supabase CLI tests
-- File: supabase/tests/02_property_paddock_test.sql

BEGIN;
SELECT plan(N);  -- declare number of assertions

-- Test: ATF partial unique index blocks duplicate active ATF
SELECT throws_ok(
  $$INSERT INTO animais_lote_atf (animal_id, lote_atf_id, ativo)
    VALUES ('...', '...', true)$$,
  '23505',  -- unique_violation SQLSTATE
  NULL,
  'inserting second active ATF for same animal raises unique violation'
);

-- Test: gerar_numero_animal does not produce duplicates under parallel load
-- (requires pgbench or pg_background — see Open Questions)

SELECT * FROM finish();
ROLLBACK;
```

[ASSUMED] — pgTAP is available via `supabase test db` when pgTAP extension is loaded; exact assertions syntax from pgTAP documentation.

### Anti-Patterns to Avoid

- **Importing supabase_flutter in widgets:** Every Supabase call must flow through `SupabaseService` via a repository. Violates the established pattern from Phase 0.
- **Using `Visibility` or `Opacity` for role-based hiding (D-06):** The widget must be conditionally absent from the tree, not invisible. Hidden elements can still receive focus.
- **Calling `.requireValue` on an AsyncValue without checking `.hasValue`:** Routes.dart comment WR-03 is explicit. Use `.when()` or check `.isLoading`.
- **Adding `deleted_at IS NOT NULL` records to PropertySelector:** The `memberPropertiesProvider` query must filter soft-deleted propriedades. Failing to do this means deleted farms reappear in the header dropdown.
- **Schema changes via Supabase web SQL editor:** All DDL goes through `supabase/migrations/*.sql` + `supabase db push`. CLAUDE.md is explicit.
- **Creating `animais` table skeleton in this phase with wrong column types:** Forward-reference tables created in Phase 2 for prototype purposes must match the schema that Phase 3 will use. If they diverge, Phase 3 migration becomes a destructive ALTER.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-tenant atomic sequence | Custom table + app-level locking | `pg_advisory_xact_lock` in PL/pgSQL | App-level locks fail under concurrent requests; advisory locks are transactional and automatically released |
| Immutable record enforcement | App-layer check before update | `BEFORE UPDATE OR DELETE` trigger | App checks are bypassable; trigger fires even from Studio/direct SQL |
| Unique constraint with condition | Manual check in RPC | PostgreSQL `PARTIAL UNIQUE INDEX WHERE ativo = true` | Index is enforced atomically by the engine; manual checks have TOCTOU race conditions |
| Decimal number formatting (pt-BR comma) | String manipulation | `intl` package `NumberFormat` with `pt_BR` locale | Edge cases: thousands separator, rounding, locale-aware parsing |
| Form validation | Custom `ValueNotifier` | Built-in `Form` + `GlobalKey<FormState>` + validator functions | Established Phase 1 pattern; consistent UX; handles focus management |
| Adaptive modal (dialog vs sheet) | Platform detection | `MediaQuery.of(context).size.width >= 600` breakpoint | Consistent with AppShell breakpoint (app_shell.dart line 22) |

---

## Common Pitfalls

### Pitfall 1: `deleted_at` filter missing from memberPropertiesProvider
**What goes wrong:** User soft-deletes a propriedade. It disappears from `/propriedades` list. But `memberPropertiesProvider` still returns it (no `deleted_at IS NULL` filter) so it remains in the PropertySelector dropdown and can still be selected as the active property.
**Why it happens:** `memberPropertiesProvider` queries `property_members` joined with `propriedades` — the join must include the filter.
**How to avoid:** Add `.isFilter('deleted_at', null)` on the `propriedades` side of the join in `PropertyRepository.fetchMemberProperties()`, OR add a database view `propriedades_ativas` that Phase 2 migration creates.
**Warning signs:** Deleted farm still appears in header dropdown after soft-delete.

### Pitfall 2: `get_perfil()` called in RLS policy without SECURITY DEFINER
**What goes wrong:** RLS policy calls `get_perfil()` to check if the current user is veterinário. If the function lacks `SECURITY DEFINER`, it executes with the invoker's privileges — which means it cannot read `property_members` because RLS on that table blocks the read in a circular way.
**Why it happens:** RLS-calling-RLS without elevated function privileges causes permission errors or silent empty results.
**How to avoid:** Always define helper functions used in RLS policies with `SECURITY DEFINER` and `SET search_path = public, auth`, mirroring the `is_member_of()` pattern from Phase 1.
**Warning signs:** `get_perfil()` returns NULL for a known member; mutations succeed for non-veterinários.

### Pitfall 3: `/propriedades` route placed at root level breaks AppShell
**What goes wrong:** `/propriedades` declared as a root-level `GoRoute` (outside `StatefulShellRoute`) causes the AppShell to disappear when navigating to it — no navigation rail, no bottom bar.
**Why it happens:** Routes outside `StatefulShellRoute.indexedStack` render without the shell builder.
**How to avoid:** Add `/propriedades` as a sibling `GoRoute` inside the piquetes `StatefulShellBranch` routes list (Pattern 6 above). It renders within the shell, keeping navigation visible.
**Warning signs:** AppBar disappears on `/propriedades`, or navigation bar disappears.

### Pitfall 4: gerar_numero_animal created without animais table
**What goes wrong:** The RPC references `animais` table which does not exist in Phase 2. Migration fails with `ERROR: relation "animais" does not exist`.
**Why it happens:** D-20 requires the RPC in Phase 2 for risk-retirement, but the `animais` table is Phase 3.
**How to avoid:** Either (a) create a minimal `animais` skeleton table in Phase 2 migration (id, propriedade_id, categoria, numero) enough for the RPC + test, clearly marked as Phase 3 will extend it, OR (b) write the RPC against a temporary table/CTE in the test only. See Open Questions below.
**Warning signs:** Migration fails on RPC creation; test fails to compile.

### Pitfall 5: `showModalBottomSheet` with form fields gets obscured by keyboard
**What goes wrong:** On mobile, opening a ModalBottomSheet with TextFormFields causes the keyboard to overlap the form content, making lower fields inaccessible.
**Why it happens:** BottomSheet does not automatically resize above the keyboard.
**How to avoid:** Pass `isScrollControlled: true` to `showModalBottomSheet` and wrap the content in a `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))`. Phase 1 login screen used `SingleChildScrollView` for this same reason.
**Warning signs:** Submit button hidden behind keyboard; user cannot reach capacity UA field.

### Pitfall 6: Property form CRUD not updating PropertySelector / currentPropertyProvider
**What goes wrong:** User creates a new propriedade. The creation succeeds (Supabase INSERT). But the PropertySelector still shows the old list because `memberPropertiesProvider` is not invalidated.
**Why it happens:** Riverpod providers cache results. A direct INSERT does not automatically notify providers.
**How to avoid:** After successful create/edit/delete in the repository, call `ref.invalidate(memberPropertiesProvider)`. This triggers a re-fetch and propagates to `currentPropertyProvider` and `PropertySelector`.
**Warning signs:** New farm does not appear in dropdown after creation; deleted farm still visible.

### Pitfall 7: Numeric TextFormField accepting locale-incorrect decimal separators
**What goes wrong:** User types "12,5" (pt-BR comma decimal). `double.tryParse("12,5")` returns null. Form validation passes (field not empty) but repository receives null/0.
**Why it happens:** Dart's `double.parse` uses `.` as separator; pt-BR uses `,`.
**How to avoid:** In the numeric field validator and on-save handler, replace `,` with `.` before parsing: `double.tryParse(value.replaceAll(',', '.'))`. Or use `intl`'s `NumberFormat.decimalPattern('pt_BR').parse(value)`.
**Warning signs:** Area and capacidade always saved as 0 for pt-BR comma input.

---

## Code Examples

### Supabase query with soft-delete filter

```dart
// Source: Supabase Dart SDK v2 pattern (verified against supabase_flutter ^2.12.0)
final rows = await _service.client
    .from('piquetes')
    .select()
    .eq('propriedade_id', propriedadeId)
    .isFilter('deleted_at', null)   // ← isFilter for IS NULL check
    .order('nome');
```

### Riverpod invalidation after mutation

```dart
// Source: Riverpod 3.x documentation pattern
// After successful create/edit/delete:
ref.invalidate(piqueteListProvider);
ref.invalidate(memberPropertiesProvider);  // if propriedade was mutated
```

### pt-BR decimal parsing in form validator

```dart
// Source: Dart standard library + intl package pattern
String? _validateDecimal(String? v) {
  if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
  final normalized = v.replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) return 'Valor deve ser maior que zero';
  return null;
}

double _parseDecimal(String v) =>
    double.parse(v.trim().replaceAll(',', '.'));
```

### GoRouter path parameter extraction

```dart
// Source: go_router ^17.2.0 pattern (confirmed in router.dart)
GoRoute(
  path: ':id',
  builder: (context, state) => PiqueteDetailScreen(
    id: state.pathParameters['id']!,
  ),
),
```

### pgTAP: testing partial unique index constraint

```sql
-- Source: [ASSUMED] pgTAP throws_ok for constraint violations
SELECT throws_ok(
  $$ INSERT INTO animais_lote_atf (animal_id, lote_atf_id, ativo)
     VALUES (test_animal_id, test_lote_atf_id_2, true) $$,
  '23505',
  NULL,
  'Second active ATF for same animal raises unique_violation'
);
```

---

## Runtime State Inventory

Step 2.5: SKIPPED — Phase 2 is a greenfield feature addition (new tables, new screens). There is no rename/refactor/migration of existing state. No stored data, live service config, OS-registered state, secrets, or build artifacts reference strings being changed.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Supabase CLI (local Docker) | Migration + pgTAP tests | ASSUMED present (Phase 1 ran successfully) | Verify with `supabase status` |
| Flutter SDK ^3.11.4 | All Flutter work | ASSUMED present | Phase 1 passed UAT |
| `dart run build_runner` | freezed + riverpod codegen | ASSUMED present | Phase 0 configured |
| pgTAP extension | `supabase test db` | Included in Supabase CLI local stack | No separate install needed |

[ASSUMED] — Phase 1 complete means the local dev environment was functional. No environment checks run in this research session.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Flutter unit/widget | `flutter_test` (SDK) |
| Mocking | `mocktail ^1.0.5` |
| SQL / RLS | pgTAP via `supabase test db` |
| Quick run command | `flutter test test/` |
| Full suite command | `flutter test test/ && supabase test db` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROP-01 | Propriedade CRUD data model + repository surface | Unit (compile-assert) | `flutter test test/features/propriedades/` | ❌ Wave 0 |
| PROP-01 | PropriedadesScreen renders list / empty state | Widget | `flutter test test/widget/propriedades_screen_test.dart` | ❌ Wave 0 |
| PROP-02 | Piquete CRUD data model + repository surface | Unit (compile-assert) | `flutter test test/features/piquetes/` | ❌ Wave 0 |
| PROP-02 | PiquetesScreen renders list / empty state | Widget | `flutter test test/widget/piquetes_screen_test.dart` | ❌ Wave 0 |
| D-20 | `gerar_numero_animal` returns non-duplicate under parallel calls | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 |
| D-21 | `composicao_snapshot` trigger blocks UPDATE/DELETE | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 |
| D-22 | ATF partial unique index blocks duplicate active ATF | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 |
| D-07 | Non-veterinário cannot INSERT piquete (RLS) | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/`
- **Per wave merge:** `flutter test test/ && supabase test db`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/features/propriedades/propriedade_repository_test.dart` — compile-asserts for PropriedadeRepository surface
- [ ] `test/features/piquetes/piquete_repository_test.dart` — compile-asserts for PiqueteRepository + Piquete model
- [ ] `test/widget/propriedades_screen_test.dart` — empty state + list rendering with mocked provider
- [ ] `test/widget/piquetes_screen_test.dart` — empty state + list rendering with mocked provider
- [ ] `supabase/tests/02_property_paddock_test.sql` — pgTAP: RLS policies, gerar_numero_animal, snapshot trigger, ATF index
- [ ] `supabase/tests/` directory — does not exist yet, must be created in Wave 0

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Auth is Phase 1; piquetes/propriedades are post-auth |
| V3 Session Management | no | Session managed by supabase_flutter, unchanged |
| V4 Access Control | yes | RLS policies: `is_member_of()` + `get_perfil()` gate all mutations; D-07 defense in depth |
| V5 Input Validation | yes | All form fields validated client-side + DB constraints (NOT NULL, CHECK > 0 for numeric fields) |
| V6 Cryptography | no | No new cryptographic operations |

### Known Threat Patterns for Flutter + Supabase RLS Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Horizontal privilege escalation (user reads another tenant's piquetes) | Information Disclosure | RLS `USING (is_member_of(propriedade_id))` on `piquetes` — same pattern as Phase 1 |
| Vertical privilege escalation (proprietário INSERTs piquete) | Elevation of Privilege | RLS `WITH CHECK (get_perfil(propriedade_id) = 'veterinario')` on INSERT/UPDATE/DELETE |
| Mass assignment (attacker sends extra JSON fields to Supabase) | Tampering | Repository methods use explicit column lists in `.insert({...})` — never `fromJson` of untrusted full request body |
| Soft-delete bypass (direct DELETE instead of soft-delete) | Tampering | RLS: grant UPDATE (for setting `deleted_at`) but NOT DELETE to `authenticated` role; hard DELETE blocked |

---

## Open Questions

1. **`gerar_numero_animal` RPC depends on `animais` table — which does not exist in Phase 2**
   - What we know: The RPC queries `animais` for `MAX(numero)`. `animais` is created in Phase 3.
   - What's unclear: Should Phase 2 create a minimal `animais` skeleton (id, propriedade_id, categoria text, numero int) just to satisfy the RPC? Or should the concurrency test use a temporary table?
   - Recommendation: Create a minimal `animais` table skeleton in Phase 2 migration with the minimum columns the RPC needs. Mark it clearly as "Phase 3 will ALTER this table to add remaining columns." This keeps the RPC real and testable. Phase 3 migration then adds the remaining columns with `ALTER TABLE animais ADD COLUMN ...`.

2. **Concurrency test for `gerar_numero_animal` — pgTAP runs serially**
   - What we know: pgTAP executes tests in a single transaction. True parallel RPC calls cannot be tested with pure pgTAP.
   - What's unclear: The CONTEXT.md specifics mention "pg_background or pgbench" for concurrency validation.
   - Recommendation: Use `pgbench` with a custom SQL script to fire 10 concurrent `SELECT gerar_numero_animal(...)` calls. Verify the results have no duplicates by checking the output. Document the pgbench command in the pgTAP test file as a comment. The pgTAP test validates the function exists and returns the correct type; the pgbench run is the real concurrency proof.

3. **`aplicacoes_sanitarias` table skeleton for the immutability trigger**
   - What we know: D-21 requires the JSONB column + trigger in Phase 2. The full table is Phase 6.
   - What's unclear: Minimum schema needed for the trigger test.
   - Recommendation: Create `aplicacoes_sanitarias (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), composicao_snapshot jsonb NOT NULL)` skeleton in Phase 2. Phase 6 migration alters it to add remaining columns.

4. **`animais_lote_atf` table skeleton for the ATF partial unique index**
   - Same situation as above. Requires at minimum `(id uuid, animal_id uuid, lote_atf_id uuid, ativo boolean)` to create the index and test it.
   - Recommendation: Create the skeleton in Phase 2 migration. Phase 5 extends it.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `pg_advisory_xact_lock` is the correct mechanism for `gerar_numero_animal` concurrency safety | Architecture Patterns §8, Code Examples | Alternative (dedicated sequences table, PostgreSQL SEQUENCE per tenant) may be simpler or preferred; planner should choose implementation |
| A2 | `build_runner build` with freezed 3.x + json_serializable 6.13.x works correctly for the stack as-is | Standard Stack | If codegen fails, debug pass needed before data model tasks can complete |
| A3 | Supabase local dev environment is functional (inherited from Phase 1 success) | Environment Availability | If Docker / Supabase CLI has drifted, migrations will fail |
| A4 | pgTAP is available via `supabase test db` without additional installation | Validation Architecture | If pgTAP not loaded, SQL tests cannot run; `supabase/config.toml` may need pgTAP extension added |
| A5 | `animais`, `animais_lote_atf`, and `aplicacoes_sanitarias` skeleton tables are the correct approach for Phase 2 backend prototypes | Open Questions | If downstream phases need to ALTER these tables in breaking ways, migration sequencing becomes complex |
| A6 | GoRouter 17.x nested child routes work the same as 14.x for the `/piquetes/:id` pattern | Architecture Patterns §6 | GoRouter had a major version bump from 14.x (CLAUDE.md) to 17.2.x (actual pubspec); nested route API should be compatible but verify |

---

## Sources

### Primary (HIGH confidence)
- `lib/features/auth/` codebase — verified Phase 1 patterns (repository, providers, form structure, router guards)
- `lib/core/` codebase — verified AppShell breakpoint (600dp), PropertySelector structure, SupabaseService pattern
- `supabase/migrations/20260504_01_auth_multitenancy.sql` — verified Phase 1 SQL patterns (SECURITY DEFINER, RLS, enum)
- `.planning/phases/02-property-paddock-structure/02-CONTEXT.md` — all locked decisions
- `.planning/phases/02-property-paddock-structure/02-UI-SPEC.md` — full visual and interaction contract
- `pubspec.yaml` — verified all library versions actually in use

### Secondary (MEDIUM confidence)
- PostgreSQL documentation on `pg_advisory_xact_lock` and partial unique indexes — well-established features, training knowledge, not re-verified in this session
- pgTAP `throws_ok` assertion syntax — training knowledge from pgTAP docs, consistent with Supabase CLI test patterns

### Tertiary (LOW confidence — flagged ASSUMED)
- `gerar_numero_animal` advisory lock implementation detail (A1)
- `animais` / `animais_lote_atf` / `aplicacoes_sanitarias` skeleton approach (A5)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified in pubspec.yaml; no new dependencies
- Architecture patterns: HIGH — verified against Phase 1 code; SQL patterns from Phase 1 migration
- UI contract: HIGH — 02-UI-SPEC.md is fully specified and locked
- Backend prototypes: MEDIUM — SQL structure is standard PostgreSQL; concurrency test approach requires planner decision (Open Question 2)
- Pitfalls: HIGH — derived from direct codebase inspection of integration points

**Research date:** 2026-05-08
**Valid until:** 2026-06-08 (stable stack; no fast-moving dependencies)
