-- 20260715_04_gap_move_animal_to_lot.sql
-- Phase 4 — Movements (gap closure)
-- References: MOV-01, ROADMAP Phase 4 Success Criterion 4, T-4-01 (cross-property isolation)
-- Supersedes D-04: the earlier decision to route animal moves through a bare
-- PostgREST UPDATE gated only by veterinarian_can_update_active_animal was
-- found (04-VERIFICATION.md, 04-REVIEW.md CR-01) to NOT enforce that the
-- destination lot belongs to the same property as the animal — RLS only
-- validates the animal's own property, never the destination lot's. This RPC
-- concentrates that missing validation, mirroring move_lot_to_paddock
-- (20260519_04_movements.sql) adapted animals-to-lots.
--
-- No new tables, no new columns, no new RLS policies.

-- ============================================================
-- 1. move_animal_to_lot — atomic single-row UPDATE with cross-entity validation
-- ============================================================

CREATE OR REPLACE FUNCTION move_animal_to_lot(
  p_animal_id uuid,
  p_lot_id    uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id  uuid;
  v_current_lot  uuid;
BEGIN
  -- 1. Load the animal's property_id + current lot_id (also validates animal exists + active)
  SELECT property_id, lot_id
    INTO v_property_id, v_current_lot
    FROM animals
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or is archived', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  -- 2. Membership check (T-4-05: defense-in-depth)
  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  -- 3. Role check — veterinarian only (T-4-02)
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can move animals'
      USING ERRCODE = '42501';
  END IF;

  -- 4. Source != destination guard (T-4-06: no-op rejection)
  IF v_current_lot = p_lot_id THEN
    RAISE EXCEPTION 'animal is already in lot %', p_lot_id
      USING ERRCODE = '23514';
  END IF;

  -- 5. Destination lot must belong to the same property and be active (T-4-01, SC-4 fix)
  IF NOT EXISTS (
    SELECT 1 FROM lots
     WHERE id = p_lot_id
       AND property_id = v_property_id
       AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION
      'lot % not found, archived, or belongs to a different property',
      p_lot_id USING ERRCODE = '23503';
  END IF;

  -- 6. Atomic single-row UPDATE
  UPDATE animals
     SET lot_id = p_lot_id
   WHERE id = p_animal_id;
END;
$$;

REVOKE ALL ON FUNCTION move_animal_to_lot(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION move_animal_to_lot(uuid, uuid) TO authenticated;
