-- 20260716_04_animal_lot_property_trigger.sql
-- Phase 4 — Movements (gap closure #2)
-- References: MOV-01, ROADMAP Phase 4 Success Criterion 4, T-4-01
--
-- 04-REVIEW.md CR-01 (deep review of 20260715_04_gap_move_animal_to_lot.sql)
-- found that the move_animal_to_lot RPC is a VOLUNTARY path: the RLS
-- veterinarian_can_update_active_animal policy's WITH CHECK never inspects
-- lot_id, so a veterinarian who is a member of two properties can bypass the
-- RPC entirely with a raw PostgREST `PATCH /animals?id=eq.<id>
-- {"lot_id":"<lot in a different property>"}` and succeed. SC-4 was not
-- actually closed at the database boundary.
--
-- This migration SUPERSEDES D-04's RLS-only approach with an
-- access-path-independent BEFORE INSERT OR UPDATE trigger — the project's
-- existing idiom for unconditional invariants (see prevent_snapshot_mutation
-- / trg_snapshot_immutable, 20260508_02_property_paddock.sql:198-210). The
-- trigger fires on every write path (RPC, raw PATCH, any future caller); the
-- RPC's own EXISTS check becomes defense-in-depth for a fast, clear error.
--
-- No new tables, no new columns, no new RLS policies.

-- ============================================================
-- 1. enforce_animal_lot_same_property — BEFORE INSERT OR UPDATE trigger
-- ============================================================
CREATE OR REPLACE FUNCTION enforce_animal_lot_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- CRITICAL: when NEW.lot_id IS NULL the guard is skipped and NEW is
  -- returned unchanged — unassigned animals are a valid physical state and
  -- must not raise. Fires on INSERT, on a lot_id change, or on a
  -- property_id change (keeps the invariant true if a raw PATCH reassigns
  -- property_id while lot_id is left untouched — the WR-02/T-4-09
  -- lot-alignment consequence; full property_id-immutability is deferred).
  IF NEW.lot_id IS NOT NULL AND (
    TG_OP = 'INSERT'
    OR NEW.lot_id IS DISTINCT FROM OLD.lot_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
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

-- lot_id-only (plus property_id) guard is deliberate: registerBaixa updates
-- deleted_at but never touches lot_id/property_id, so it does not
-- re-trigger this validation and cannot false-positive on an archival.
CREATE TRIGGER trg_animals_lot_same_property
  BEFORE INSERT OR UPDATE ON animals
  FOR EACH ROW
  EXECUTE FUNCTION enforce_animal_lot_same_property();
