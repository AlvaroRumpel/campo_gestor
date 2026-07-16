---
phase: 04-movements
reviewed: 2026-07-16T00:00:00Z
depth: deep
files_reviewed: 2
files_reviewed_list:
  - supabase/migrations/20260715_04_gap_move_animal_to_lot.sql
  - lib/features/animais/data/animal_repository.dart
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 4: Code Review Report — Gap Closure (move_animal_to_lot)

**Reviewed:** 2026-07-16T00:00:00Z
**Depth:** deep
**Files Reviewed:** 2
**Status:** issues_found

## Summary

This is the Phase 4 gap-closure fix for the confirmed cross-property isolation
hole in `AnimalRepository.moveAnimal` (ROADMAP SC-4 / prior CR-01, previous
`04-REVIEW.md`). The new `move_animal_to_lot` SECURITY DEFINER RPC is
internally correct: it loads the animal's `property_id` from the trusted
server row (not from client input), compares it against the destination
lot's `property_id` via a non-spoofable `EXISTS` check, gates on membership +
veterinarian role before mutating, uses correct ERRCODEs, and is properly
locked down (`REVOKE ALL … FROM public` / `GRANT EXECUTE … TO authenticated`).
The Dart rewire in `animal_repository.dart` correctly calls the RPC with the
right param names and does not swallow the thrown `PostgrestException`, so
the dialog's catch-all error SnackBar still fires on failure.

However, **the isolation hole is not actually closed at the database
boundary** — only the one Dart code path (`AnimalRepository.moveAnimal`) was
rewired to use the new RPC. The pre-existing RLS `UPDATE` policy on `animals`
(`veterinarian_can_update_active_animal`, added in
`20260514_03_lots_animals.sql`) is unchanged and its `WITH CHECK` clause never
validates that `lot_id` belongs to the animal's property. Any client that
issues a raw PostgREST `PATCH /animals?id=eq.<id>` with `{"lot_id": "<lot in
a different property>"}` — bypassing the RPC entirely — still succeeds,
because `WITH CHECK` only re-checks `is_member_of(property_id)` +
`role = veterinarian` against the (unchanged) `property_id` column, and never
references `lot_id` or the `lots` table at all. This is the same class of gap
the RPC was built to close, just left open on a second, equally reachable
door. This must be fixed before the fix can be considered to actually close
SC-4.

## Critical Issues

### CR-01: RLS still permits a direct cross-property `lot_id` UPDATE, bypassing `move_animal_to_lot` entirely

**File:** `supabase/migrations/20260514_03_lots_animals.sql:79-89` (policy left unchanged by the gap-closure migration `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql`)

**Issue:** The RPC added by this migration is a voluntary path — nothing
stops a client from writing directly to the `animals` table via PostgREST
instead of calling `move_animal_to_lot`. That direct path is still fully
live: `animals` has RLS enabled with grants to `authenticated`, and the same
`.from('animals').update(...)` pattern is used elsewhere in this very file
(`updateAnimal`, `registerBaixa`), proving the direct-table-write endpoint is
reachable with the app's own publishable key.

The `veterinarian_can_update_active_animal` policy:
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
`WITH CHECK` is evaluated against the **new** row. If a caller sends a PATCH
that only touches `lot_id` (leaving `property_id` untouched), `WITH CHECK`
re-validates membership/role on the *same, unchanged* `property_id` — it
never inspects `lot_id`, so it has no way to reject a `lot_id` that points at
a lot in a different property. A veterinarian who is a member of property A
(and, incidentally, also a member of property B) can run:

```
PATCH /rest/v1/animals?id=eq.<animalIdInPropertyA>
Authorization: Bearer <jwt for vet who is also vet on property B>
{"lot_id": "<lotIdInPropertyB>"}
```

and it succeeds — the exact bug this migration set out to fix, still open.
The gap-closure migration only re-routes the Dart client; it does not close
the underlying database-level hole, so the fix does not satisfy "server-side
check that the destination lot belongs to the same property as the animal"
for any caller other than the one Dart method that was rewired.

**Fix:** Enforce the invariant at the table level so it holds regardless of
access path (RPC, raw REST, or any future caller). A `BEFORE INSERT OR
UPDATE` trigger is the standard way to make this invariant unconditional:

```sql
CREATE OR REPLACE FUNCTION enforce_animal_lot_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.lot_id IS NOT NULL AND (
    TG_OP = 'INSERT' OR NEW.lot_id IS DISTINCT FROM OLD.lot_id
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM lots
       WHERE id = NEW.lot_id
         AND property_id = NEW.property_id
         AND deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION
        'lot % does not belong to property % or is archived',
        NEW.lot_id, NEW.property_id USING ERRCODE = '23503';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_animals_lot_same_property
  BEFORE INSERT OR UPDATE ON animals
  FOR EACH ROW
  EXECUTE FUNCTION enforce_animal_lot_same_property();
```

With this in place, `move_animal_to_lot`'s own `EXISTS` check becomes
defense-in-depth (nice for a fast, clear error message) rather than the sole
enforcement point, and the raw-REST bypass above would fail with `23503`
regardless of which endpoint the caller used. Alternatively, tighten
`WITH CHECK` on the existing policy to add the same `EXISTS` predicate — but
a trigger is preferable because it also protects `INSERT` and cannot be
forgotten by a future policy edit.

## Warnings

### WR-01: Final `UPDATE` in `move_animal_to_lot` does not re-check `deleted_at`, allowing a narrow TOCTOU on concurrent archival

**File:** `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql:73-75`

**Issue:** Step 1 loads the animal with `WHERE id = p_animal_id AND deleted_at
IS NULL`, but the final mutation is an unconditional single-row update:
```sql
UPDATE animals
   SET lot_id = p_lot_id
 WHERE id = p_animal_id;
```
There is no row lock (`FOR UPDATE`) taken in step 1 and no `deleted_at IS
NULL` re-check in the final `UPDATE`. If another transaction calls
`registerBaixa` (soft-delete) on the same animal between the validation
`SELECT` and this `UPDATE`, the lot move still silently applies to an
animal that is now archived — a small but real data-integrity gap. (The
sibling `move_lot_to_paddock` has the identical pattern, so this is not a
regression introduced here, but it is exactly the kind of TOCTOU this deep
review was asked to check, and it should be fixed in both places.)

**Fix:**
```sql
UPDATE animals
   SET lot_id = p_lot_id
 WHERE id = p_animal_id
   AND deleted_at IS NULL;

IF NOT FOUND THEN
  RAISE EXCEPTION 'animal % was archived during the move', p_animal_id
    USING ERRCODE = '23503';
END IF;
```

### WR-02: `property_id` itself is still mutable via the same RLS-only UPDATE policy — same root cause as CR-01, different column

**File:** `supabase/migrations/20260514_03_lots_animals.sql:79-89`

**Issue:** Because `WITH CHECK` never pins `property_id` to its prior value
(it only re-derives membership/role from whatever `property_id` ends up in
the new row), a veterinarian who belongs to two properties can also directly
reassign an animal's `property_id` itself via a raw PATCH — moving the whole
animal row (and, transitively, its `lot_id` reference) into a different
tenant outright. `updateAnimal`'s doc comment explicitly calls out that
`property_id`/`lot_id` are deliberately excluded from its payload as a
mass-assignment defense, but that is app-layer discipline only; it is not
enforced at the RLS boundary. Not introduced by this migration, but directly
relevant to "no new hole introduced" and worth closing alongside CR-01 (a
trigger validating `NEW.property_id = OLD.property_id` on `UPDATE`, or an
explicit `WITH CHECK (property_id = property_id_before)` pattern, would
close it).

**Fix:** Add `AND NEW.property_id IS NOT DISTINCT FROM OLD.property_id` style
enforcement (trigger, since RLS `WITH CHECK` cannot reference `OLD` directly)
alongside the CR-01 fix.

## Info

### IN-01: `moveAnimal`'s post-RPC re-fetch is dead work — its only caller discards the returned `Animal`

**File:** `lib/features/animais/data/animal_repository.dart:178-192`, caller at `lib/features/animais/presentation/mover_animal_dialog.dart:47-50`

**Issue:** `moveAnimal` does the RPC call (which returns `void`) and then a
second round trip (`SELECT ... WHERE id = id .single()`) to rebuild an
`Animal` to return. `MoverAnimalDialog._submit` awaits the call, never reads
the result, and immediately invalidates `animalByIdProvider` /
`animalListByLotProvider` / `animalListByPropertyProvider` to force a
refetch anyway. The extra query and `Animal.fromJson` construction are
unused work on every move. The sibling `LoteRepository.moveLot` returns
`Future<void>` and relies purely on provider invalidation — a more
consistent shape.

**Fix:** Either change `moveAnimal` to `Future<void>` (matching `moveLot`),
or have the RPC declare `RETURNS animals` and `RETURNING *` the updated row
so the update and the read happen in a single round trip if the return value
is genuinely needed by a future caller.

### IN-02: ERRCODE `23503` reused for "not found" business errors, not a true FK violation

**File:** `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql:38-40, 67-70`

**Issue:** `23503` (`foreign_key_violation`) is raised for "animal not found
or archived" and "lot not found/archived/cross-property" — none of these are
actual FK constraint violations at the SQL level. This matches the existing
convention in the sibling `move_lot_to_paddock` (`20260519_04_movements.sql`),
so it's not a new defect, just noted for completeness. If the project ever
wants callers to distinguish "not found" from "actual FK violation"
programmatically, a dedicated code (e.g. `P0002`/custom) would be clearer.

**Fix:** No action required unless the project wants to standardize error
codes project-wide; informational only.

---

_Reviewed: 2026-07-16T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
