---
phase: 04-movements
reviewed: 2026-07-15T00:00:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/features/animais/data/animal_repository.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - lib/features/animais/presentation/mover_animal_dialog.dart
  - lib/features/lotes/data/lote_repository.dart
  - lib/features/lotes/presentation/lote_detail_screen.dart
  - lib/features/lotes/presentation/mover_lote_dialog.dart
  - supabase/migrations/20260519_04_movements.sql
  - test/features/animais/animal_repository_test.dart
  - test/features/lotes/lote_repository_test.dart
  - test/widget/animal_detail_screen_test.dart
  - test/widget/lote_detail_screen_test.dart
  - test/widget/mover_animal_dialog_test.dart
  - test/widget/mover_lote_dialog_test.dart
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-07-15T00:00:00Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

MOV-02 (`move_lot_to_paddock` RPC) is well-built: role/membership checks are duplicated server-side for defense-in-depth, destination paddock is validated to belong to the same property, source==destination is rejected, and the whole move is atomic. That RPC is a good model.

MOV-01 (`AnimalRepository.moveAnimal`) is the weak point: it's a direct PostgREST `UPDATE` on `animals.lot_id` with **no server-side check that the destination lot belongs to the same property as the animal**. The RLS policy it relies on (`veterinarian_can_update_active_animal`) only checks the animal row's own `property_id`, never the target lot's. The code comments call this an "accepted MVP gap," but the picker that is supposed to be the only safety net (`loteListByPropertyProvider`) is scoped to `currentPropertyProvider` (the globally-selected active property), not to `widget.animal.propertyId` — and nothing in the router or screen guards against viewing an animal from a property other than the currently-selected one. That turns a theoretical "malicious direct API call" into a realistic UI-triggerable cross-tenant data-integrity bug. See CR-01.

Beyond that, the `MoverLoteDialog` success path is missing two provider invalidations that other mutations in this codebase reliably perform (`animalListByPropertyProvider`, `loteListByPropertyProvider`), leaving stale paddock information visible elsewhere in the app after a lot move (WR-01, WR-02). Both `MoverAnimalDialog._submit` and `MoverLoteDialog._submit` invalidate providers via `ref` before checking `mounted`, which can throw/mask a successful move as a failure if the dialog is disposed mid-await (WR-03). There's a pt-BR singular/plural grammar bug in the lot-move confirmation copy (WR-04).

## Critical Issues

### CR-01: `moveAnimal` allows an animal's lot to be reassigned across properties — no server-side property check

**File:** `lib/features/animais/data/animal_repository.dart:182-193`
**Issue:**
`moveAnimal` performs a bare `UPDATE animals SET lot_id = :newLotId WHERE id = :id`. The RLS policy that gates this write (`veterinarian_can_update_active_animal`, `supabase/migrations/20260514_03_lots_animals.sql:79-89`) only checks `is_member_of(property_id) AND get_role(property_id)='veterinarian' AND deleted_at IS NULL` on the **animal's own row** — it never verifies that `newLotId` (the target `lots.id`) belongs to the same `property_id`. There is also no `CHECK` constraint or trigger enforcing `lots.property_id = animals.property_id`.

The only thing standing between this and a cross-tenant data-integrity break is the UI: `MoverAnimalDialog`'s picker (`lib/features/animais/presentation/mover_animal_dialog.dart:144`) is populated from `loteListByPropertyProvider` (`lib/features/lotes/data/lote_repository.dart:200-206`), which is scoped to **`currentPropertyProvider`** (the globally selected "active property"), **not** to `widget.animal.propertyId`. Nothing in the router (`lib/core/router/router.dart`) or in `AnimalDetailScreen` verifies that the animal being viewed belongs to the currently-selected property before rendering the "Mover animal" action.

Concretely: a veterinarian who is a member of two properties, has property B selected as "active" (e.g. via `PropertySelector`), but navigates directly to `/animais/:id` for an animal that belongs to property A (bookmark, deep link, or just switching the selector in another tab/session while this screen stays mounted) will see a lot picker full of property-B lots. Selecting one and confirming calls `moveAnimal(id: <property-A animal>, newLotId: <property-B lot>)`. RLS permits it (the animal's own `property_id` is A, and the caller is a vet on A), and the write succeeds — silently pointing a property-A animal's `lot_id` at a property-B lot. This corrupts the tenant boundary that the rest of the schema (RLS on `lots`, `paddocks`, joins used by `fetchAnimalsByProperty`) assumes holds.

This is exactly the class of bug this phase's own code comments call out as an accepted gap, but the review explicitly asks to verify RLS/RPC cross-property checks, and the gap is reachable without any malicious API tooling — just a stale active-property selection.

**Fix:** Mirror the MOV-02 pattern. Replace the raw `.update()` with a `SECURITY DEFINER` RPC (e.g. `move_animal_to_lot(p_animal_id uuid, p_lot_id uuid)`) that:
1. Loads the animal's `property_id` (and confirms `deleted_at IS NULL`).
2. Checks `is_member_of` + `get_role(...) = 'veterinarian'`.
3. Validates the destination lot belongs to the same `property_id` and is active, exactly like `move_lot_to_paddock` validates the destination paddock (`supabase/migrations/20260519_04_movements.sql:61-71`).
4. Performs the `UPDATE`.

```sql
CREATE OR REPLACE FUNCTION move_animal_to_lot(
  p_animal_id uuid,
  p_lot_id    uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id
    FROM animals
   WHERE id = p_animal_id AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or is archived', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can move animals'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM lots
     WHERE id = p_lot_id AND property_id = v_property_id AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'lot % not found, archived, or belongs to a different property',
      p_lot_id USING ERRCODE = '23503';
  END IF;

  UPDATE animals SET lot_id = p_lot_id WHERE id = p_animal_id;
END;
$$;
```
and update `AnimalRepository.moveAnimal` to call `.rpc('move_animal_to_lot', ...)` instead of `.from('animals').update(...)`. Until this lands, at minimum scope `loteListByPropertyProvider`'s query (or the picker) to `widget.animal.propertyId` rather than `currentPropertyProvider`, to close the accidental-trigger path — though that still leaves the direct-API vector open.

## Warnings

### WR-01: `MoverLoteDialog` success path never invalidates `animalListByPropertyProvider`

**File:** `lib/features/lotes/presentation/mover_lote_dialog.dart:49-59`
**Issue:** Moving a lot to a new paddock changes the effective paddock of every animal in that lot. `AnimaisScreen` (`lib/features/animais/presentation/animais_screen.dart:46`) watches `animalListByPropertyProvider`, which embeds `paddocks!inner(id, name)` per animal (`lib/features/animais/data/animal_repository.dart:229-235`). Every other mutation that can change an animal's effective paddock/lot (`animal_edit_dialog.dart:55`, `baixa_dialog.dart:85`, `animal_form_dialog.dart:104`, and `MoverAnimalDialog` itself at `mover_animal_dialog.dart:55`) invalidates this provider — `MoverLoteDialog._submit` is the one mutation site that changes an animal's paddock context and does not. Because `animalListByPropertyProvider` is a plain (non-`autoDispose`) `FutureProvider`, the stale paddock name/id persists in the cache until some unrelated action happens to invalidate it — potentially showing a vet the wrong paddock for animals they're trying to locate in the field.
**Fix:**
```dart
// mover_lote_dialog.dart, in _submit(), alongside the existing invalidations:
ref.invalidate(loteByIdProvider(widget.lot.id));
ref.invalidate(loteListByPaddockProvider(oldPaddockId));
ref.invalidate(loteListByPaddockProvider(paddockId));
ref.invalidate(animalListByPropertyProvider); // add this
```

### WR-02: `MoverLoteDialog` success path never invalidates `loteListByPropertyProvider`

**File:** `lib/features/lotes/presentation/mover_lote_dialog.dart:49-59`
**Issue:** `loteListByPropertyProvider` (`lib/features/lotes/data/lote_repository.dart:200-206`) is the sole data source for `MoverAnimalDialog`'s lot picker (`lib/features/animais/presentation/mover_animal_dialog.dart:144`), which shows each lot's paddock name via `paddockByIdProvider(lot.paddockId)` using the cached `Lot.paddockId`. Since `MoverLoteDialog._submit` never invalidates `loteListByPropertyProvider`, after moving a lot to a new paddock, the animal-move picker will keep showing that lot under its **old** paddock name until something unrelated (e.g. creating a new lot) refreshes the cache.
**Fix:** add `ref.invalidate(loteListByPropertyProvider);` to the same block referenced in WR-01.

### WR-03: `ref.invalidate(...)` runs before the `mounted` guard in both move dialogs' success path

**File:** `lib/features/animais/presentation/mover_animal_dialog.dart:47-56`, `lib/features/lotes/presentation/mover_lote_dialog.dart:49-59`
**Issue:** Both `_submit()` methods do:
```dart
await ref.read(...).moveAnimal(/* moveLot */...);
ref.invalidate(providerA);   // no mounted check yet
ref.invalidate(providerB);
...
if (mounted) Navigator.pop(context, {...});
```
If the widget is disposed during the `await` (barrier-dismissed dialog, or the host route popped e.g. via back navigation), `ref` on a disposed `ConsumerStatefulWidget` throws when used. That throw is caught by the surrounding `catch (_)`, which shows "Erro ao mover. Tente novamente." (or, since `mounted` is now false, silently does nothing) — even though the move already **succeeded** on the server. Whichever invalidations were queued after the throwing one never run, leaving provider caches stale on top of the misleading (or silently swallowed) failure signal.
**Fix:** check `mounted` immediately after the awaited call succeeds, before touching `ref`:
```dart
await ref.read(animalRepositoryProvider).moveAnimal(id: widget.animal.id, newLotId: lotId);
if (!mounted) return;
ref.invalidate(animalByIdProvider(widget.animal.id));
ref.invalidate(animalListByLotProvider(oldLotId));
ref.invalidate(animalListByLotProvider(lotId));
ref.invalidate(animalListByPropertyProvider);
Navigator.pop(context, {'lotName': selectedName});
```
(mirror the same reordering in `mover_lote_dialog.dart`).

### WR-04: pt-BR singular/plural grammar bug in lot-move confirmation text

**File:** `lib/features/lotes/presentation/mover_lote_dialog.dart:86`
**Issue:** `'${widget.activeAnimalCount} animais serão transferidos para o novo piquete. ...'` is always plural. When `activeAnimalCount == 1` (a valid state — the "Mover para piquete" button only requires `activeCount > 0`, see `lote_detail_screen.dart:216-221`), this renders "1 animais serão transferidos", which is ungrammatical Portuguese ("1 animal será transferido" is correct).
**Fix:**
```dart
Text(
  widget.activeAnimalCount == 1
      ? '1 animal será transferido para o novo piquete. A operação é atômica — ou todos movem ou nenhum.'
      : '${widget.activeAnimalCount} animais serão transferidos para o novo piquete. A operação é atômica — ou todos movem ou nenhum.',
  style: theme.textTheme.bodyMedium,
),
```

## Info

### IN-01: Move-dialog "happy path" and invalidation logic are untested

**File:** `test/widget/mover_animal_dialog_test.dart`, `test/widget/mover_lote_dialog_test.dart`, `test/features/animais/animal_repository_test.dart`, `test/features/lotes/lote_repository_test.dart`
**Issue:** The widget tests only assert static rendering (title text, button enable/disable, picker exclusion) — none of them tap "Confirmar movimentação" and await the result, so `_submit()`'s success/error branches, the `mounted`-ordering issue (WR-03), and the missing invalidations (WR-01/WR-02) are all unexercised. Similarly, `animal_repository_test.dart`/`lote_repository_test.dart` only assert `expect(repo.moveAnimal, isA<Function>())` (a compile-time shape check), never verifying the actual payload sent (e.g., that `moveAnimal` sends only `lot_id` and nothing else, which matters given CR-01).
**Fix:** Add at least one test per dialog that fakes a successful `moveAnimal`/`moveLot`, taps Confirm, pumps, and asserts `Navigator.pop` was called with the expected result map; and a repository-level test asserting the exact update/RPC-params payload.

### IN-02: `_canEdit` role-check helper duplicated verbatim

**File:** `lib/features/animais/presentation/animal_detail_screen.dart:117-127`, `lib/features/lotes/presentation/lote_detail_screen.dart:113-123`
**Issue:** Both screens define an identical private `_canEdit(SelectedProperty?, List<PropertyMembership>?)` method. Minor maintainability nit — a future change to the "who can edit" rule (e.g., adding an "owner" role) requires touching both copies in lockstep.
**Fix:** Extract to a shared helper (e.g. `bool canEditProperty(SelectedProperty? current, List<PropertyMembership>? members)` in a `core/` or `auth/` utility file) and reuse from both screens.

---

_Reviewed: 2026-07-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
