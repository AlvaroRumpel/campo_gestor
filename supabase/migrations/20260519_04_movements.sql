-- 20260519_04_movements.sql
-- Phase 4 — Movements
-- References: MOV-02 (atomic lot-to-paddock move via RPC)
-- Decisions: D-08 (RPC name + arg shape), D-09 (current paddock excluded by RPC validation)
--            T-4-06 (source != destination), T-4-07 (role check duplicated in RPC for defense-in-depth)
--
-- No new tables, no new columns, no new RLS policies. MOV-01 reuses the
-- existing veterinarian_can_update_active_animal policy for direct UPDATE on
-- animals.lot_id (analyzed in 04-RESEARCH.md, lines 405–425).

-- ============================================================
-- 1. move_lot_to_paddock — atomic single-row UPDATE with cross-entity validation
-- ============================================================
-- The lot/paddock UPDATE itself is a single statement and would already be
-- atomic at the row level. The RPC concentrates validation (cross-property
-- FK alignment, role check, destination active, source != destination) in
-- one auditable place and matches the project pattern for guarded writes.

CREATE OR REPLACE FUNCTION move_lot_to_paddock(
  p_lot_id     uuid,
  p_paddock_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id      uuid;
  v_current_paddock  uuid;
BEGIN
  -- 1. Load the lot's property_id + current paddock_id (also validates lot exists + active)
  SELECT property_id, paddock_id
    INTO v_property_id, v_current_paddock
    FROM lots
   WHERE id = p_lot_id
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'lot % not found or is archived', p_lot_id
      USING ERRCODE = '23503';
  END IF;

  -- 2. Membership check (T-4-07: defense-in-depth)
  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  -- 3. Role check — veterinarian only (T-4-02)
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can move lots'
      USING ERRCODE = '42501';
  END IF;

  -- 4. Source != destination guard (T-4-06: no-op rejection)
  IF v_current_paddock = p_paddock_id THEN
    RAISE EXCEPTION 'lot is already in paddock %', p_paddock_id
      USING ERRCODE = '23514';
  END IF;

  -- 5. Destination paddock must belong to the same property and be active (T-4-04)
  IF NOT EXISTS (
    SELECT 1 FROM paddocks
     WHERE id = p_paddock_id
       AND property_id = v_property_id
       AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION
      'paddock % not found, archived, or belongs to a different property',
      p_paddock_id USING ERRCODE = '23503';
  END IF;

  -- 6. Atomic single-row UPDATE
  UPDATE lots
     SET paddock_id = p_paddock_id
   WHERE id = p_lot_id;
END;
$$;

REVOKE ALL ON FUNCTION move_lot_to_paddock(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION move_lot_to_paddock(uuid, uuid) TO authenticated;
