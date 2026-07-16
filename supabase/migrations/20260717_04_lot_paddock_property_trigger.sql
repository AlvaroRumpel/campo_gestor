-- 20260717_04_lot_paddock_property_trigger.sql
-- Phase 4 — Movements (gap closure #3)
-- References: MOV-02, T-4-08
--
-- Mirrors trg_animals_lot_same_property (20260716_04_animal_lot_property_trigger.sql,
-- gap cycle #2) onto lots: access-path-independent enforcement of
-- "lots.paddock_id must belong to the lot's own property_id".
--
-- 04-REVIEW.md WR-02/CR-01-parallel found the identical bug class on lots:
-- the RLS veterinarian_can_update_active_lot policy's WITH CHECK
-- (20260514_03_lots_animals.sql:40-50) never inspects paddock_id, so a
-- veterinarian who is a member of two properties can bypass the
-- move_lot_to_paddock RPC (20260519_04_movements.sql) entirely with a raw
-- PostgREST `PATCH /lots?id=eq.<id> {"paddock_id":"<paddock in a different
-- property>"}` — WITH CHECK passes (property_id unchanged, vet is a member)
-- and the lot is pointed at a foreign-property paddock.
--
-- Previously DOCUMENTED-DEFERRED as an accepted MVP risk in 04-CONTEXT.md
-- (gap cycle #2); per user decision (2026-07-16) the scope is reversed and
-- this closes the lots.paddock_id raw-PATCH bypass of move_lot_to_paddock.
--
-- No new tables, no new columns, no new RLS policies.

-- ============================================================
-- 1. enforce_lot_paddock_same_property — BEFORE INSERT OR UPDATE trigger
-- ============================================================
CREATE OR REPLACE FUNCTION enforce_lot_paddock_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- NEW.paddock_id IS NULL never occurs because lots.paddock_id is NOT NULL;
  -- the IS NOT NULL guard is kept to mirror the animals trigger exactly.
  -- Fires on INSERT, on a paddock_id change, or on a property_id change
  -- (keeps the invariant true if a raw PATCH reassigns property_id while
  -- paddock_id is left untouched — the same lot-alignment reasoning as the
  -- animals trigger; full property_id-immutability remains out of scope,
  -- bounded by RLS membership on the target property).
  IF NEW.paddock_id IS NOT NULL AND (
    TG_OP = 'INSERT'
    OR NEW.paddock_id IS DISTINCT FROM OLD.paddock_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM paddocks
       WHERE id = NEW.paddock_id
         AND property_id = NEW.property_id
         AND deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION
        'paddock % does not belong to property % or is archived',
        NEW.paddock_id, NEW.property_id USING ERRCODE = '23503';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- paddock_id-only (plus property_id) guard is deliberate: softDeleteLot
-- updates deleted_at but never touches paddock_id/property_id, so it does
-- not re-trigger this validation and cannot false-positive on an archival.
CREATE TRIGGER trg_lots_paddock_same_property
  BEFORE INSERT OR UPDATE ON lots
  FOR EACH ROW
  EXECUTE FUNCTION enforce_lot_paddock_same_property();
