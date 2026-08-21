# Phase 4: Movements — Research

**Researched:** 2026-05-19
**Domain:** Flutter dialog UX + Supabase PostgREST UPDATE + plpgsql RPC (atomic lot move)
**Confidence:** HIGH — all findings drawn from codebase inspection and existing migration patterns

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**MOV-01 — Move individual animal:**
- D-01: Entry point in `AnimalDetailScreen` — 3rd action button after "Editar" and "Dar baixa", role-gated veterinarian. Button absent for archived animals (deletedAt != null).
- D-02: Picker dialog showing all active lots of the property. Current lot excluded. New provider: `loteListByPropertyProvider` (FutureProvider.family by propertyId).
- D-03: Picker item format: lot name + parent paddock name + active animal count. Example: `"Lote Bravo — Piquete Norte (32 animais)"`.
- D-04: Implementation: `UPDATE animals SET lot_id = :target WHERE id = :id` via PostgREST with RLS (no RPC needed).
- D-05: Post-move: stay on `AnimalDetailScreen`. Invalidate providers. SnackBar: `"Animal movido para [nome do lote destino]"`.

**MOV-02 — Move entire lot:**
- D-06: Entry point in `LoteDetailScreen` header card. Button absent when lot archived OR 0 active animals.
- D-07: Confirmation dialog with paddock picker (active paddocks, current paddock excluded) + info text `"X animais serão transferidos."`.
- D-08: Implementation: RPC `move_lot_to_paddock(p_lot_id, p_paddock_id)` in plpgsql. Validates: destination paddock belongs to same property, lot active, paddock active, role = veterinarian.
- D-09: Current paddock excluded from picker.
- D-10: Post-move: stay on `LoteDetailScreen`. Invalidate providers. SnackBar: `"Lote movido para [nome do piquete destino]"`.

**Provider Invalidation:**
- D-11 (move animal): `animalListByLotProvider(oldLotId)`, `animalListByLotProvider(newLotId)`, `animalByIdProvider(animalId)`, `animalListByPropertyProvider`
- D-12 (move lot): `loteListByPaddockProvider(oldPaddockId)`, `loteListByPaddockProvider(newPaddockId)`, `loteByIdProvider(lotId)`

### Claude's Discretion

- Layout details of lot picker dialog (height, separator, scroll behavior).
- Whether `loteListByPropertyProvider` uses JOIN with paddock name or separate query.
- Internal structure of RPC `move_lot_to_paddock` (SECURITY DEFINER vs INVOKER).
- Animation/loading during atomic operation.

### Deferred Ideas (OUT OF SCOPE)

- Movement audit history (who moved what, when) — requires events table, post-MVP.
- Move multiple individually-selected animals at once — MOV-02 lot-level move covers bulk; individual multi-select is a new feature.
- Move animal to a lot from a different property — explicitly out of scope (RLS/RPC enforces same-property).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MOV-01 | Usuário pode mover animal individual para outro lote da mesma propriedade | D-04: direct PostgREST UPDATE on `animals.lot_id`; existing RLS UPDATE policy covers lot_id field; new `loteListByPropertyProvider` + `MoverAnimalDialog` |
| MOV-02 | Usuário pode mover lote inteiro para outro piquete; todos os animais movem atomicamente via RPC | D-08: new `move_lot_to_paddock` RPC in plpgsql SECURITY DEFINER following existing migration pattern; `paddockListProvider` already exists for picker |
</phase_requirements>

---

## Summary

Phase 4 is a focused UI-plus-database phase. It introduces two user flows (move individual animal, move entire lot) and one new database migration (the `move_lot_to_paddock` RPC). There is no new data model — only `animals.lot_id` and `lots.paddock_id` change values. The existing schema, RLS policies, and provider patterns are largely sufficient, with targeted additions.

The critical database question — whether the existing `veterinarian_can_update_active_animal` policy on `animals` already permits `lot_id` changes — is confirmed YES by reading the migration: the policy allows UPDATE on any column of active animals for veterinarians, with no column-level restriction. The PostgREST UPDATE for MOV-01 requires no new migration.

MOV-02 requires a new migration containing the `move_lot_to_paddock` RPC. The RPC only updates `lots.paddock_id` — animals have no `paddock_id` column (they inherit location via JOIN through `lot.paddock_id`). The existing `veterinarian_can_update_active_lot` policy on `lots` also permits any column update, so the RPC can execute the UPDATE via SECURITY DEFINER without needing new RLS.

On the Flutter side, both operations reuse the `BaixaDialog` pattern (ConsumerStatefulWidget, AlertDialog, LinearProgressIndicator title during save, FilledButton/TextButton action pair). The primary new Flutter work is two dialog files and two screen modifications plus one new provider.

**Primary recommendation:** Implement MOV-01 via direct PostgREST UPDATE (no migration needed). Implement MOV-02 via a single new migration file containing the `move_lot_to_paddock` RPC following the `create_lot_with_animals` SECURITY DEFINER template. Both dialogs replicate the `BaixaDialog` structure exactly.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 4 |
|-----------|-------------------|
| State management: Riverpod 3.x (not 2.x) | New providers use `FutureProvider.family`, not `@riverpod` codegen unless the codebase already does so consistently |
| Navigation: GoRouter | No new routes needed — dialogs are shown over existing routes |
| HTTP: supabase_flutter only (no dio) | Both operations use `_service.client.from().update()` or `.rpc()` |
| Data classes: freezed + json_serializable | No new domain model needed — reuse `Lot` and `Animal` |
| No new packages | UI-SPEC.md confirms zero new pub.dev packages |
| Repository never imports Supabase SDK directly | All DB calls go through `SupabaseService` |
| Exception pattern: typed exception class | New `LotMoveException` or reuse pattern from `AnimalNumberConflictException` |
| Soft delete, never hard delete | Not applicable — this phase does not delete |
| Migration via `supabase migration new` + CLI | New migration file required for MOV-02 RPC only |
| All schema changes through migrations, never web SQL editor | One new migration file for the RPC |
| Riverpod 3.x upgrade note from STATE.md | Use `ref.invalidate()` not `ref.refresh()` |

---

## Standard Stack

### Core (already installed — zero new dependencies)

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| flutter_riverpod | ^3.x (project-installed) | State, providers, invalidation | Existing pattern |
| supabase_flutter | ^2.5+ (project-installed) | PostgREST UPDATE + RPC calls | Existing pattern |
| freezed_annotation | ^2.4.4 (project-installed) | No new models needed | — |
| intl | ^0.19.0 (project-installed) | pt-BR formatting in dialogs | Existing pattern |

**Installation:** No new packages. Phase 4 adds zero dependencies. [VERIFIED: 04-UI-SPEC.md "Registry Safety" section confirms this explicitly]

---

## Architecture Patterns

### Recommended File Structure

```
lib/features/
├── animais/
│   ├── data/
│   │   └── animal_repository.dart     MODIFY: add moveAnimal() method + loteListByPropertyProvider
│   └── presentation/
│       ├── animal_detail_screen.dart  MODIFY: add 3rd button + onMover callback
│       └── mover_animal_dialog.dart   NEW: MoverAnimalDialog
├── lotes/
│   ├── data/
│   │   └── lote_repository.dart      MODIFY: add moveLot() RPC call method
│   └── presentation/
│       ├── lote_detail_screen.dart   MODIFY: add "Mover para piquete" button
│       └── mover_lote_dialog.dart    NEW: MoverLoteDialog

supabase/migrations/
└── 20260519_04_movements.sql          NEW: move_lot_to_paddock RPC
```

### Pattern 1: PostgREST field-specific UPDATE (MOV-01)

The existing `updateAnimal()` method sends only specific fields. The new `moveAnimal()` follows the same pattern but changes only `lot_id`.

**Key insight from codebase:** `animal_repository.dart` line 147 already documents the design decision: "Only sends provided non-null fields — never touches category, number, property_id, or lot_id (T-3-12 mass-assignment mitigation)." Phase 4 intentionally breaks this comment — `lot_id` is the ONLY field `moveAnimal()` touches. Update the comment accordingly. [VERIFIED: animal_repository.dart lines 146–166]

```dart
// Source: animal_repository.dart updateAnimal() pattern (adapted)
Future<Animal> moveAnimal({
  required String id,
  required String newLotId,
}) async {
  final row = await _service.client
      .from('animals')
      .update({'lot_id': newLotId})
      .eq('id', id)
      .select()
      .single();
  return Animal.fromJson(row);
}
```

**RLS coverage:** The existing `veterinarian_can_update_active_animal` policy (migration line 79–89) uses `USING (is_member_of(property_id) AND get_role(...) = 'veterinarian' AND deleted_at IS NULL)` with no column-level restriction. An UPDATE setting only `lot_id` on an active animal is covered. Cross-property protection: if `newLotId` belongs to a different property, the UPDATE will succeed at the RLS check on the source animal (same property), but the `lot_id` FK references `lots(id)` — if the target lot is in another property the FK still resolves (it's a global UUID). The RLS does NOT enforce that the target lot is in the same property. [VERIFIED: migration 20260514_03_lots_animals.sql]

**CRITICAL PITFALL — Cross-property lot assignment:** RLS on `animals` validates the animal's own `property_id`, not the target lot's `property_id`. A malicious client could set `lot_id` to a lot belonging to another property. This must be caught at the application layer (filter `loteListByPropertyProvider` to the active property) or via a database trigger/check constraint. SC-4 from the roadmap requires this to "be rejected with a clear error." The simplest approach: the picker only shows lots from the active property (provider is scoped to `propertyId`) — the cross-property scenario is only reachable via direct API call, not the UI. For defense-in-depth, an RPC could be used instead of raw UPDATE — but D-04 explicitly chose raw UPDATE. The planner should add a note about this: either add a CHECK CONSTRAINT or accept that RLS only prevents cross-property reads, not cross-property lot_id assignment. [ASSUMED — no existing CHECK CONSTRAINT on animals.lot_id → lots(property_id) alignment verified absent from migration]

### Pattern 2: RPC call from Dart (MOV-02)

Follows the `createLotWithAnimals` pattern exactly. [VERIFIED: lote_repository.dart lines 57–68]

```dart
// Source: lote_repository.dart createLotWithAnimals() pattern (adapted)
Future<void> moveLot({
  required String lotId,
  required String newPaddockId,
}) async {
  await _service.client.rpc(
    'move_lot_to_paddock',
    params: {
      'p_lot_id': lotId,
      'p_paddock_id': newPaddockId,
    },
  );
}
```

### Pattern 3: BaixaDialog as dialog template

`BaixaDialog` is the canonical dialog pattern. Both new dialogs are structural replicas. [VERIFIED: baixa_dialog.dart]

Key structural elements to replicate:

```dart
// Source: baixa_dialog.dart lines 100–188 (structural template)
AlertDialog(
  title: _saving
      ? const LinearProgressIndicator()          // replaces title during save
      : Text('Dialog title'),
  content: SizedBox(
    width: 480,                                  // fixed width — DO NOT CHANGE
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, ...),
    ),
  ),
  actions: [
    TextButton(
      onPressed: _saving ? null : () => Navigator.pop(context, false),
      child: const Text('Cancelar'),
    ),
    FilledButton(
      onPressed: _saving ? null : _submit,       // disabled during save
      child: const Text('Confirmar movimentação'),
    ),
  ],
)
```

Differences from BaixaDialog in new movement dialogs:
1. FilledButton uses default `colorScheme.primary` (not `colorScheme.error`) — movements are not destructive
2. Content area has a scrollable picker list (ListTile items) instead of form fields
3. Submit disabled until a picker item is selected (gate: `_selectedId != null`)

### Pattern 4: plpgsql RPC SECURITY DEFINER (MOV-02 migration)

Follows `create_lot_with_animals` template exactly. [VERIFIED: 20260514_03_lots_animals.sql lines 130–235]

```sql
-- Source: 20260514_03_lots_animals.sql pattern
CREATE OR REPLACE FUNCTION move_lot_to_paddock(
  p_lot_id     uuid,
  p_paddock_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  -- Role check: veterinarian only
  SELECT property_id INTO v_property_id
    FROM lots WHERE id = p_lot_id AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'lot % not found or is archived', p_lot_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can move lots'
      USING ERRCODE = '42501';
  END IF;

  -- Validate destination paddock belongs to same property and is active
  IF NOT EXISTS (
    SELECT 1 FROM paddocks
     WHERE id = p_paddock_id
       AND property_id = v_property_id
       AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'paddock % not found, archived, or belongs to a different property',
      p_paddock_id USING ERRCODE = '23503';
  END IF;

  -- Atomic update
  UPDATE lots SET paddock_id = p_paddock_id WHERE id = p_lot_id;
END;
$$;

REVOKE ALL ON FUNCTION move_lot_to_paddock(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION move_lot_to_paddock(uuid, uuid) TO authenticated;
```

**Why SECURITY DEFINER:** The `create_lot_with_animals` RPC uses SECURITY DEFINER for the same reason — the RLS on `lots` allows veterinarian UPDATE, and the RPC concentrates validation logic in one auditable place. For MOV-02, SECURITY DEFINER is not strictly required since the calling user IS a veterinarian with UPDATE rights — but using it makes the validation ordering explicit and matches the established project pattern. [ASSUMED — either INVOKER or DEFINER would work; DEFINER matches project convention]

### Pattern 5: New provider `loteListByPropertyProvider`

Needed for MOV-01 picker. The existing `loteListByPaddockProvider` is family by paddockId; this new provider is family by propertyId and requires a JOIN to get paddock name + animal count for D-03 display format. [VERIFIED: lote_repository.dart — no `fetchLotsByProperty` method exists]

The D-03 display format `"Lote Bravo — Piquete Norte (32 animais)"` requires either:

**Option A:** Single JOIN query — `lots.*`, paddock name via embedded select, COUNT of active animals via embedded select. PostgREST syntax: `select=*, paddocks(name), animals(count)` with `animals.deleted_at=is.null` filter. Returns a flat row that needs a dedicated DTO.

**Option B:** Two queries — fetch active lots for property, then fetch active animal counts per lot (or animal list and count in Dart). Simpler code, two round-trips.

**Recommendation:** Option A is idiomatic Supabase and avoids N+1, but the PostgREST embedded count syntax requires verification. Option B is safer given the project's current pattern (all other queries are single-table). Given this phase is small, use Option B: fetch lots by property, fetch animal counts via a GROUP BY query or reuse `animalListByLotProvider` data in the dialog. [ASSUMED — need to validate PostgREST embedded COUNT syntax against live Supabase]

**Simplest safe implementation for `loteListByPropertyProvider`:**

```dart
// Source: lote_repository.dart pattern adapted
// DTO for picker display
class LotWithCount {
  const LotWithCount({required this.lot, required this.paddockName, required this.activeAnimalCount});
  final Lot lot;
  final String paddockName;
  final int activeAnimalCount;
}

// In LoteRepository:
Future<List<LotWithCount>> fetchLotsWithCountByProperty(String propertyId) async {
  // Query lots with embedded paddock name
  final rows = await _service.client
      .from('lots')
      .select('*, paddocks!inner(name)')
      .eq('property_id', propertyId)
      .isFilter('deleted_at', null)
      .order('name');
  // For each lot, count active animals
  // ... (second query or Dart-side count from animalsAsync)
}
```

**Alternative without second query:** The MoverAnimalDialog already has access to `animalListByLotProvider` for the current lot. For picker items it can display paddock name + a simple count query. Given Phase 4's simplicity, the planner may choose to load all active animals by property (reusing `animalListByPropertyProvider`) and group by lot_id in Dart. This avoids any new SQL. [ASSUMED — both approaches are valid; planner decides]

### Pattern 6: `_canEdit` role gate

Both screens already implement `_canEdit` identically: [VERIFIED: animal_detail_screen.dart lines 103–113, lote_detail_screen.dart lines 88–98]

```dart
bool _canEdit(SelectedProperty? current, List<PropertyMembership>? members) {
  if (current == null || members == null) return false;
  final role = members
      .where((m) => m.property.id == current.id)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian';
}
```

The "Mover animal" and "Mover para piquete" buttons use the same `canEdit` value already computed in their respective screens. No new role-checking logic.

### Pattern 7: `paddockListProvider` — already exists for MOV-02 picker

`paddockListProvider` in `piquete_repository.dart` fetches all active paddocks for the current active property. [VERIFIED: piquete_repository.dart lines 98–103] This is exactly what `MoverLoteDialog` needs — the dialog simply filters out the current paddock.

No new provider needed for the paddock picker. The dialog consumes `paddockListProvider` directly.

### Anti-Patterns to Avoid

- **Importing supabase_flutter directly in widgets:** Always go through `SupabaseService`. This is enforced in all 3 repositories verified. [VERIFIED: animal_repository.dart line 6 imports only `PostgrestException` type]
- **Using `ref.refresh()` instead of `ref.invalidate()`:** The codebase uses `ref.invalidate()` consistently (e.g., `baixa_dialog.dart` lines 84–85). Riverpod 3.x docs confirm `invalidate` is preferred.
- **Submitting dialog without disabling the button:** `BaixaDialog` sets `onPressed: _saving ? null : _submit` on both action buttons. Replicate exactly — double-submit is a real issue with async ops.
- **Forgetting to invalidate both affected lots after move animal:** D-11 requires invalidating BOTH the old and new lot's `animalListByLotProvider`. Missing one leaves stale UI.
- **`FilledButton` with error color for non-destructive actions:** Movement is NOT destructive — use default primary color (no explicit `backgroundColor`), unlike `BaixaDialog` which sets `colorScheme.error`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic lot paddock move | Custom Dart transaction | plpgsql RPC | Network can fail mid-flight; DB transaction is the only atomicity guarantee |
| Cross-property lot validation | Dart-side property_id check before UPDATE | DB-level: picker scoped to property + RLS membership check | Client can be bypassed; validation must be defense-in-depth |
| Dialog loading state | Custom overlay or separate loading screen | `LinearProgressIndicator()` replacing `title` | BaixaDialog pattern already established; consistency matters |
| Role check | Calling a new auth endpoint | `_canEdit()` with `memberPropertiesProvider` | Same pattern as both existing screens |

**Key insight:** The `move_lot_to_paddock` RPC is a single-row UPDATE on `lots` — it feels too simple to need an RPC. The RPC is required because: (1) it's the only place to validate cross-entity constraints (paddock must belong to same property as lot), (2) the business rule "atômico via RPC" is explicit in REQUIREMENTS.md, and (3) it matches the project's established pattern for guarded writes.

---

## Common Pitfalls

### Pitfall 1: Stale lot display after move animal
**What goes wrong:** User moves animal from Lot A to Lot B. `AnimalInfoCard` still shows "Lote atual: Lot A". SnackBar says moved, but the screen is inconsistent.
**Why it happens:** `animalByIdProvider(animalId)` is invalidated but `loteByIdProvider` is not — the card re-fetches the animal (now with new lot_id) but the lot name display is already cached.
**How to avoid:** `animalByIdProvider(animalId)` invalidation triggers a re-watch; `AnimalInfoCard` re-reads `loteByIdProvider(animal.lotId)` — after invalidation the animal's `lotId` is the new one. This cascade works IF `animalByIdProvider` is invalidated before the dialog pops. The existing dialog-pops-then-parent-invalidates pattern in `AnimalDetailScreen` (lines 73–74) is safe. [VERIFIED: animal_detail_screen.dart lines 66–84]
**Warning signs:** SnackBar shows "movido para X" but `AnimalInfoCard` still shows old lot name.

### Pitfall 2: Provider invalidation order — old lot ID lost after move
**What goes wrong:** `moveAnimal()` returns the updated Animal (with `newLotId`). By the time you try to invalidate `animalListByLotProvider(oldLotId)`, you've already overwritten your reference to `oldLotId` with the new one.
**Why it happens:** Code like `final animal = await moveAnimal(...); ref.invalidate(animalListByLotProvider(animal.lotId))` only invalidates the NEW lot.
**How to avoid:** Capture `oldLotId` BEFORE calling `moveAnimal()`. Pattern:
```dart
final oldLotId = widget.animal.lotId;     // capture before async call
await repo.moveAnimal(id: ..., newLotId: _selectedLotId!);
ref.invalidate(animalListByLotProvider(oldLotId));       // old lot
ref.invalidate(animalListByLotProvider(_selectedLotId!)); // new lot
ref.invalidate(animalByIdProvider(widget.animal.id));
ref.invalidate(animalListByPropertyProvider);
```

### Pitfall 3: `paddockListProvider` includes the current paddock — dialog must filter
**What goes wrong:** MoverLoteDialog shows the current paddock in the picker, user selects it, RPC executes a no-op UPDATE (same paddock). No error but no useful action.
**Why it happens:** `paddockListProvider` fetches all active paddocks — it does not know which is "current".
**How to avoid:** In `MoverLoteDialog`, filter out `lot.paddockId` from the list in the `build` method:
```dart
final allPaddocks = paddocksAsync.asData?.value ?? [];
final available = allPaddocks.where((p) => p.id != widget.lot.paddockId).toList();
```
The RPC should also validate that source != destination and RAISE EXCEPTION if equal — defense in depth.

### Pitfall 4: `loteListByPropertyProvider` picker must exclude archived lots
**What goes wrong:** Picker shows a lot with `deleted_at != null`. User moves animal there. Lot is archived but now has an active animal — broken invariant.
**Why it happens:** New provider query omits `isFilter('deleted_at', null)`.
**How to avoid:** Always add `.isFilter('deleted_at', null)` to any lot fetch used for picker. Mirror the existing `fetchLotsByPaddock` pattern.

### Pitfall 5: AnimalInfoCard signature change breaks existing call site
**What goes wrong:** Adding `onMover` parameter to `AnimalInfoCard` without updating the constructor call in `AnimalDetailScreen` causes a compile error.
**Why it happens:** `AnimalInfoCard` is a named constructor widget — adding required parameters is a breaking change.
**How to avoid:** Add `onMover` as a required parameter. Update `AnimalDetailScreen` to pass the callback simultaneously. Both files change in the same task.

### Pitfall 6: `_LoteHeaderCard` needs `canEdit` and `lot.paddockId` but is a private widget
**What goes wrong:** `_LoteHeaderCard` is a private `ConsumerWidget` that receives `lot` and `animalsAsync`. To add the "Mover para piquete" button, it also needs `canEdit` and the active animal count. The active animal count can be derived from `animalsAsync.asData?.value` — already available.
**Why it happens:** The button gate requires `lot.deletedAt == null && activeAnimalCount > 0 && canEdit` — but `canEdit` is computed in `LoteDetailScreen`, not `_LoteHeaderCard`.
**How to avoid:** Pass `canEdit` as a constructor parameter to `_LoteHeaderCard`, or move the button to `LoteDetailScreen`'s body and pass the dialog callback down. Passing `canEdit` is simpler. The callback `onMoverLote` can also be passed in, keeping `_LoteHeaderCard` stateless.

---

## RLS Policy Analysis

### MOV-01: Direct UPDATE on `animals.lot_id`

The existing `veterinarian_can_update_active_animal` policy: [VERIFIED: 20260514_03_lots_animals.sql lines 79–89]

```sql
CREATE POLICY "veterinarian_can_update_active_animal"
  ON animals FOR UPDATE TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
    AND deleted_at IS NULL
  )
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );
```

This policy allows UPDATE of ANY column on active animals for veterinarians — including `lot_id`. **No new migration is needed for MOV-01.** [VERIFIED]

The `WITH CHECK` validates the animal's `property_id` after the update, but NOT the target lot's `property_id`. This is the cross-property gap described in Pitfall above. The application-layer defense (provider scoped to active property) is sufficient for MVP given the business rule that this is explicitly out of scope.

### MOV-02: `lots.paddock_id` UPDATE via RPC

The existing `veterinarian_can_update_active_lot` policy: [VERIFIED: 20260514_03_lots_animals.sql lines 39–51]

```sql
CREATE POLICY "veterinarian_can_update_active_lot"
  ON lots FOR UPDATE TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
    AND deleted_at IS NULL
  )
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );
```

This permits UPDATE of `paddock_id` for veterinarians. The RPC (SECURITY DEFINER) will execute as the function owner — which typically bypasses RLS. The RPC contains its own explicit role checks via `is_member_of()` and `get_role()`, matching the pattern of `create_lot_with_animals`. [VERIFIED: 20260514_03_lots_animals.sql lines 152–160]

**No additional RLS policies needed.** The new migration only adds the RPC function.

---

## Migration Design

### New file: `supabase/migrations/20260519_04_movements.sql`

Contents:
1. `move_lot_to_paddock(p_lot_id uuid, p_paddock_id uuid) RETURNS void` — SECURITY DEFINER RPC
2. REVOKE/GRANT pattern matching existing RPCs

The RPC body needs to:
1. Fetch `property_id` from the lot (validates lot exists and is active)
2. Check `is_member_of(property_id)` — 42501 if not
3. Check `get_role(property_id) = 'veterinarian'` — 42501 if not
4. Validate destination paddock belongs to same property and is active — 23503 if not
5. Validate source != destination (optional but good UX) — custom ERRCODE
6. `UPDATE lots SET paddock_id = p_paddock_id WHERE id = p_lot_id`

Return type `void` is simplest — Dart caller does not need the updated row (it invalidates `loteByIdProvider` which re-fetches).

### No migration needed for MOV-01

The existing `animals` UPDATE policy covers `lot_id`. The only DB change is the application calling `UPDATE animals SET lot_id = $1 WHERE id = $2`. [VERIFIED]

---

## Validation Architecture

Nyquist validation enabled (`nyquist_validation: true` in config.json). [VERIFIED: .planning/config.json]

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + mocktail |
| Config file | none (flutter standard test runner) |
| Quick run command | `flutter test test/features/animais/ test/features/lotes/ test/widget/mover_animal_dialog_test.dart test/widget/mover_lote_dialog_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MOV-01 | `moveAnimal()` method exists in AnimalRepository | unit | `flutter test test/features/animais/animal_repository_test.dart` | ❌ Wave 0 |
| MOV-01 | MoverAnimalDialog renders lot picker and confirm button | widget | `flutter test test/widget/mover_animal_dialog_test.dart` | ❌ Wave 0 |
| MOV-01 | MoverAnimalDialog confirm disabled until lot selected | widget | `flutter test test/widget/mover_animal_dialog_test.dart` | ❌ Wave 0 |
| MOV-01 | AnimalDetailScreen shows "Mover animal" button when `isActive && canEdit` | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ Wave 0 |
| MOV-02 | `moveLot()` method exists in LoteRepository | unit | `flutter test test/features/lotes/lote_repository_test.dart` | ✅ (extend existing) |
| MOV-02 | MoverLoteDialog renders paddock picker and confirm button | widget | `flutter test test/widget/mover_lote_dialog_test.dart` | ❌ Wave 0 |
| MOV-02 | MoverLoteDialog confirm disabled until paddock selected | widget | `flutter test test/widget/mover_lote_dialog_test.dart` | ❌ Wave 0 |
| MOV-02 | LoteDetailScreen shows "Mover para piquete" when lot active + animals > 0 + canEdit | widget | `flutter test test/widget/lote_detail_screen_test.dart` | ❌ Wave 0 |
| SC-3 | "Mover animal" button absent when canEdit=false | widget | included in animal_detail_screen_test | ❌ Wave 0 |
| SC-3 | "Mover para piquete" button absent when canEdit=false | widget | included in lote_detail_screen_test | ❌ Wave 0 |

### Wave 0 Gaps

- [ ] `test/features/animais/animal_repository_test.dart` — new file; covers MOV-01 `moveAnimal()` contract test (mirrors `lote_repository_test.dart` structure)
- [ ] `test/widget/mover_animal_dialog_test.dart` — new file; covers MOV-01 dialog rendering + picker interaction (mirrors `baixa_dialog_test.dart` structure)
- [ ] `test/widget/mover_lote_dialog_test.dart` — new file; covers MOV-02 dialog rendering + picker interaction
- [ ] `test/widget/animal_detail_screen_test.dart` — new file; covers 3rd button presence/absence
- [ ] `test/widget/lote_detail_screen_test.dart` — new file; covers "Mover para piquete" button gate
- [ ] `test/features/lotes/lote_repository_test.dart` — EXTEND existing; add `moveLot` contract test

### Sampling Rate

- **Per task commit:** `flutter test test/features/ test/widget/mover_animal_dialog_test.dart test/widget/mover_lote_dialog_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Test Patterns from Existing Codebase

**Contract test pattern** (from `lote_repository_test.dart`): [VERIFIED]
```dart
test('moveLot moves lot to new paddock via RPC', () {
  expect(repo.moveLot, isA<Function>());
});
```

**Dialog widget test pattern** (from `baixa_dialog_test.dart`): [VERIFIED]
```dart
// Fake repo subclass — no real Supabase connection
class _FakeAnimalRepo extends AnimalRepository {
  _FakeAnimalRepo() : super(SupabaseService());
  @override
  Future<Animal> moveAnimal({...}) async => /* fake animal */;
}
// ProviderScope with overrides for repo + affected providers
```

---

## Security Domain

`security_enforcement` not set to false — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Supabase JWT handles auth — unchanged |
| V3 Session Management | no | Unchanged |
| V4 Access Control | yes | RLS `is_member_of()` + `get_role()` + veterinarian gate in RPC; picker scoped to active property |
| V5 Input Validation | yes | RPC validates lot active, paddock active, same property, role; picker constrains UI choices |
| V6 Cryptography | no | No new crypto |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-property lot assignment (animal moved to lot in different property) | Tampering | Provider scoped to active property (UI-layer); `is_member_of()` validates membership but not cross-property FK alignment — accept for MVP, document |
| Privilege escalation (leitor role calling move) | Elevation of Privilege | `get_role() = 'veterinarian'` check in RPC; `canEdit` gate hides button in UI |
| Move archived animal | Tampering | RLS `USING (deleted_at IS NULL)` blocks UPDATE on archived animals — verified in migration |
| Move to archived lot | Tampering | `fetchLotsWithCountByProperty` must filter `deleted_at IS NULL` (pitfall 4 above) |
| Move to archived paddock | Tampering | RPC validates `paddocks.deleted_at IS NULL` in destination check |
| Move lot to same paddock (no-op) | — | RPC optionally raises exception; picker filters current paddock |

---

## Environment Availability

Step 2.6: SKIPPED — Phase 4 is purely application code + one new migration. No new external tools, services, or runtimes beyond what Phase 3 used. Supabase CLI and Flutter SDK confirmed available from prior phases.

---

## Runtime State Inventory

Step 2.5: SKIPPED — Phase 4 is not a rename/refactor/migration phase. No stored state, service config, OS registrations, secrets, or build artifacts reference "movements" as a string to be renamed or replaced.

---

## Open Questions

1. **Cross-property lot assignment enforcement level**
   - What we know: RLS on `animals` validates the animal's own `property_id`, not the target `lot.property_id`. The picker is scoped to the active property, preventing UI-layer abuse.
   - What's unclear: Should the planner add a DB CHECK CONSTRAINT `animals.lot_id → lots.property_id = animals.property_id` for defense-in-depth, or accept the application-layer mitigation for MVP?
   - Recommendation: Accept for MVP. The requirement (SC-4) says "rejected by RLS/RPC with a clear error" — the UI never presents cross-property lots. A DB constraint can be added in a hardening phase. The planner should document this as a known gap.

2. **`loteListByPropertyProvider` query shape**
   - What we know: Must return lot name + paddock name + active animal count for picker display (D-03). No existing method covers this.
   - What's unclear: Whether to use a single JOIN query (PostgREST embedded select with aggregate) or two queries (lots by property + animal counts grouped by lot_id).
   - Recommendation: Two queries (or Dart-side grouping from `animalListByPropertyProvider`). PostgREST embedded COUNT syntax requires `.select('*, animals(count)')` — needs live verification. Use the simpler path for MVP. [ASSUMED — embedded count syntax may differ between Supabase Dart SDK versions]

3. **RPC return type**
   - What we know: `moveLot()` in Dart currently planned to return `void`. The updated Lot is re-fetched via `loteByIdProvider` invalidation.
   - What's unclear: Some teams return the updated row from RPCs to avoid the extra round-trip.
   - Recommendation: Return `void`. Matches `registerBaixa()` pattern; the screen re-fetches via provider invalidation. [ASSUMED — both approaches valid; VOID simpler]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Cross-property lot assignment is not caught by RLS — only by UI scoping | RLS Policy Analysis | If wrong (a constraint exists), MOV-01 may return a clear DB error for cross-property attempts — better than assumed |
| A2 | SECURITY DEFINER vs INVOKER for `move_lot_to_paddock` — project convention is DEFINER | Architecture Pattern 4 | If INVOKER used instead, the RPC still works since the calling user IS a veterinarian. Zero risk. |
| A3 | PostgREST embedded COUNT syntax needs live verification | Open Question 2 | If the syntax differs, embedded query fails; fallback to two-query approach resolves this with 30min of work |
| A4 | `moveLot()` Dart method should return void (re-fetch via provider invalidation) | Architecture Pattern 2 | If wrong, the screen shows stale data for one render frame before invalidation resolves. Zero functional risk. |

---

## Sources

### Primary (HIGH confidence)
- `supabase/migrations/20260514_03_lots_animals.sql` — RLS policy text, RPC SECURITY DEFINER pattern, REVOKE/GRANT convention, `create_lot_with_animals` template
- `lib/features/animais/data/animal_repository.dart` — `updateAnimal()` pattern, field-specific UPDATE, `AnimalNumberConflictException`, provider declarations
- `lib/features/lotes/data/lote_repository.dart` — `.rpc()` call pattern, `loteListByPaddockProvider`, `loteByIdProvider`
- `lib/features/piquetes/data/piquete_repository.dart` — `paddockListProvider` (confirmed available for MOV-02 picker), `paddockByIdProvider`
- `lib/features/animais/presentation/baixa_dialog.dart` — dialog structural template, ConsumerStatefulWidget pattern, `LinearProgressIndicator` title, `_saving` flag, SnackBar pattern
- `lib/features/animais/presentation/animal_detail_screen.dart` — `_canEdit()` implementation, `AnimalInfoCard` constructor, action button row, existing invalidation on dialog close
- `lib/features/lotes/presentation/lote_detail_screen.dart` — `_LoteHeaderCard` structure, `canEdit` usage, `FloatingActionButton` role gate
- `.planning/phases/04-movements/04-CONTEXT.md` — all locked decisions D-01 through D-12
- `.planning/phases/04-movements/04-UI-SPEC.md` — dialog layout, copywriting, button placement, zero new packages confirmed
- `test/widget/baixa_dialog_test.dart` — Wave 0 test pattern, FakeRepo subclass approach, ProviderScope override structure
- `test/features/lotes/lote_repository_test.dart` — contract test pattern

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Riverpod 3.x upgrade confirmed, `ref.invalidate()` as preferred invalidation method

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new packages, all existing
- Architecture (Flutter dialogs): HIGH — direct code reading of BaixaDialog template
- Architecture (DB migration): HIGH — direct code reading of create_lot_with_animals RPC pattern
- RLS coverage analysis: HIGH — policy text read from migration file
- Provider shape for `loteListByPropertyProvider`: MEDIUM — query shape unverified against live Supabase (PostgREST embedded count syntax)
- Cross-property enforcement: MEDIUM — absence of CHECK CONSTRAINT confirmed from migration; assumption that PostgREST does not add implicit FK-alignment validation

**Research date:** 2026-05-19
**Valid until:** 2026-06-19 (stable domain; only at risk if Supabase Dart SDK major version changes)
