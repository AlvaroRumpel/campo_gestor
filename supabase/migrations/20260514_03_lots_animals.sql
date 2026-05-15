-- 20260514_03_lots_animals.sql
-- Phase 3 — Lots & Animals (Operational Core)
-- References: PROP-03, PROP-04, PROP-05, ANIM-01, ANIM-02, ANIM-04, ANIM-05, ANIM-06
-- Decisions: D-05 (numbering global per property), D-07 (number override allowed),
--            D-08 (advisory lock per property), D-09 ("Iniciar do número" skip-active),
--            D-12 (lot edit = name only), D-17 (baixa enum: sale|death|discard)

-- ============================================================
-- 1. lots table
-- ============================================================
CREATE TABLE lots (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  paddock_id  uuid NOT NULL REFERENCES paddocks(id),
  name        text NOT NULL CHECK (length(trim(name)) > 0),
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE INDEX lots_paddock_active_idx
  ON lots (paddock_id) WHERE deleted_at IS NULL;
CREATE INDEX lots_property_active_idx
  ON lots (property_id) WHERE deleted_at IS NULL;

ALTER TABLE lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE lots FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_lots"
  ON lots FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "veterinarian_can_insert_lot"
  ON lots FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );

-- D-12: lot edit = name only. Block UPDATE on archived rows.
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

-- No DELETE policy — soft-delete via UPDATE deleted_at.

-- ============================================================
-- 2. animals — extend skeleton with full column set
-- ============================================================
ALTER TABLE animals
  ADD COLUMN lot_id          uuid REFERENCES lots(id),
  ADD COLUMN breed           text,
  ADD COLUMN body_condition  integer CHECK (body_condition BETWEEN 1 AND 5),
  ADD COLUMN observation     text,
  ADD COLUMN baixa_reason    text CHECK (baixa_reason IN ('sale', 'death', 'discard')),
  ADD COLUMN baixa_date      date;

CREATE INDEX animals_lot_active_idx
  ON animals (lot_id) WHERE deleted_at IS NULL;

-- Animals INSERT (was missing in Phase 2)
CREATE POLICY "veterinarian_can_insert_animal"
  ON animals FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );

-- Animals UPDATE: veterinarian only, AND target row must be active (deleted_at IS NULL).
-- The active filter in USING blocks updates to already-archived rows (T-3-05).
-- The WITH CHECK still allows the UPDATE itself to set deleted_at (transition active→archived).
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

-- ============================================================
-- 3. Fix generate_animal_number — global per property (D-05)
-- ============================================================
DROP FUNCTION IF EXISTS generate_animal_number(uuid, text);

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
  -- Mass-assignment defense: caller must be a member of the property
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  v_lock_key := hashtextextended(p_property_id::text, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX(number), 0) + 1
    INTO v_next
    FROM animals
   WHERE property_id = p_property_id;

  RETURN v_next;
END;
$$;

REVOKE ALL ON FUNCTION generate_animal_number(uuid) FROM public;
GRANT EXECUTE ON FUNCTION generate_animal_number(uuid) TO authenticated;

-- ============================================================
-- 4. create_lot_with_animals — atomic batch RPC (D-08, D-09)
-- ============================================================
CREATE OR REPLACE FUNCTION create_lot_with_animals(
  p_property_id     uuid,
  p_paddock_id      uuid,
  p_name            text,
  p_category_qtys   jsonb,                 -- {"vaca": 10, "terneiro": 8}
  p_category_breeds jsonb,                 -- {"vaca": "Nelore", "terneiro": null}
  p_start_number    integer DEFAULT NULL
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
  v_total     integer;
BEGIN
  -- Mass-assignment defense (T-3-02): caller must be a veterinarian on the property
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;
  IF get_role(p_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can create lots'
      USING ERRCODE = '42501';
  END IF;

  -- Validate paddock belongs to property (defense in depth, T-3-06)
  IF NOT EXISTS (
    SELECT 1 FROM paddocks
     WHERE id = p_paddock_id AND property_id = p_property_id AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'paddock % does not belong to property % or is archived',
      p_paddock_id, p_property_id USING ERRCODE = '23503';
  END IF;

  -- Validate composition: at least 1 animal across all categories (D-11)
  SELECT COALESCE(SUM(value::integer), 0) INTO v_total
    FROM jsonb_each_text(p_category_qtys);
  IF v_total <= 0 THEN
    RAISE EXCEPTION 'composition must include at least 1 animal'
      USING ERRCODE = '23514';
  END IF;

  -- Advisory lock — prevents concurrent batches generating duplicate numbers (D-08, T-3-08)
  v_lock_key := hashtextextended(p_property_id::text, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Create the lot
  INSERT INTO lots (property_id, paddock_id, name)
  VALUES (p_property_id, p_paddock_id, trim(p_name))
  RETURNING id INTO v_lot_id;

  -- Determine starting number (D-09)
  IF p_start_number IS NOT NULL THEN
    IF p_start_number <= 0 THEN
      RAISE EXCEPTION 'p_start_number must be > 0' USING ERRCODE = '22023';
    END IF;
    v_next_num := p_start_number;
  ELSE
    SELECT COALESCE(MAX(number), 0) + 1 INTO v_next_num
      FROM animals WHERE property_id = p_property_id;
  END IF;

  -- Insert animals per category, skipping numbers already active
  FOR v_cat, v_qty IN
    SELECT key, value::integer FROM jsonb_each_text(p_category_qtys)
  LOOP
    IF v_qty < 0 THEN
      RAISE EXCEPTION 'category quantity must be >= 0 (got % for %)', v_qty, v_cat
        USING ERRCODE = '22023';
    END IF;
    IF v_qty = 0 THEN CONTINUE; END IF;

    v_breed := p_category_breeds ->> v_cat;
    v_count := 0;
    WHILE v_count < v_qty LOOP
      -- Skip numbers already taken by an active animal (D-07 + D-09 path)
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

  RETURN (SELECT to_jsonb(l) FROM lots l WHERE l.id = v_lot_id);
END;
$$;

REVOKE ALL ON FUNCTION create_lot_with_animals(uuid, uuid, text, jsonb, jsonb, integer) FROM public;
GRANT EXECUTE ON FUNCTION create_lot_with_animals(uuid, uuid, text, jsonb, jsonb, integer) TO authenticated;
