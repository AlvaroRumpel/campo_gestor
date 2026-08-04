-- 20260805_05_atf_rpcs.sql
-- Phase 5 — Reproductive Module (LoteATF), RPC write surface
-- References: REPR-02, REPR-03
-- Decisions: D-08 (removal blocked once a DG exists — hard DELETE), D-15/D-16 (manual encerramento
--            deactivates memberships but preserves history and DG correction), D-19 (baixa
--            deactivates ATF membership via the 05-01 trigger, not a second statement here),
--            D-21 (RLS grants no write policy on animal_atf_memberships/dg_records — every mutation
--            is routed through a SECURITY DEFINER function that re-derives property_id and role
--            server side, mirroring move_animal_to_lot from Phase 4's gap closure)
--
-- Plan 05-01 deliberately left animal_atf_memberships and dg_records with SELECT-only RLS. This
-- migration is what makes the reproductive module writable: five functions are the entire write
-- surface. None of them accepts a property_id parameter — every one derives it from a server-side
-- row lookup, so a client can never pass a property it does not belong to (RESEARCH Anti-Patterns).

-- ============================================================
-- 1. add_animals_to_atf — bulk INSERT into animal_atf_memberships (REPR-02)
-- ============================================================
-- p_animal_ids is jsonb (a JSON array of uuid strings), not uuid[] — this reuses the parameter
-- type create_lot_with_animals (20260514_03_lots_animals.sql) already proves serializes correctly
-- from the Dart client, removing 05-RESEARCH.md's unverified-uuid[]-serialization assumption (A1).
CREATE OR REPLACE FUNCTION add_animals_to_atf(
  p_atf_batch_id uuid,
  p_animal_ids   jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM atf_batches
   WHERE id = p_atf_batch_id
     AND active = true
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf_batch % not found or is not active', p_atf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can compose an ATF'
      USING ERRCODE = '42501';
  END IF;

  -- Category eligibility (vaca/novilha) and cross-property alignment are NOT re-checked here —
  -- trg_atf_membership_valid (20260804_05_reproductive_module.sql) fires on this INSERT and is the
  -- single place those invariants live. Duplicating them here would be exactly the "belt and
  -- suspenders drifting out of sync" pitfall 05-RESEARCH.md warns against (Pitfall 2). No
  -- pg_advisory_xact_lock either — nothing here generates a sequence; the pre-existing partial
  -- unique index animal_atf_memberships_active_idx is the sole concurrency guard needed
  -- (RESEARCH Pitfall 3).
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, active, property_id)
  SELECT (elem)::uuid, p_atf_batch_id, true, v_property_id
    FROM jsonb_array_elements_text(p_animal_ids) AS elem;
END;
$$;

REVOKE ALL ON FUNCTION add_animals_to_atf(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION add_animals_to_atf(uuid, jsonb) TO authenticated;

-- ============================================================
-- 2. remove_animal_from_atf — hard DELETE, blocked once a DG exists (D-08)
-- ============================================================
CREATE OR REPLACE FUNCTION remove_animal_from_atf(
  p_atf_batch_id uuid,
  p_animal_id    uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM atf_batches
   WHERE id = p_atf_batch_id
     AND active = true
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf_batch % not found or is not active', p_atf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can remove an animal from an ATF'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1 FROM dg_records
     WHERE atf_batch_id = p_atf_batch_id
       AND animal_id = p_animal_id
  ) THEN
    RAISE EXCEPTION
      'animal % already has a DG record in ATF % — cannot remove; use encerramento (close_atf) to close it out instead',
      p_animal_id, p_atf_batch_id
      USING ERRCODE = '23514';
  END IF;

  -- Hard DELETE, not a soft `active = false` — deliberately, and this is the single most important
  -- distinction in this migration. save_dg_records (below) tells "removed before any DG, never
  -- accept a DG again" (D-08, this DELETE) apart from "closed, correction still allowed" (D-16,
  -- close_atf's UPDATE) purely by whether this membership row EXISTS. Do not "harmonize" this into
  -- a soft deactivation — that would silently reopen D-08's guarantee.
  DELETE FROM animal_atf_memberships
   WHERE atf_batch_id = p_atf_batch_id
     AND animal_id = p_animal_id
     AND active = true;
END;
$$;

REVOKE ALL ON FUNCTION remove_animal_from_atf(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION remove_animal_from_atf(uuid, uuid) TO authenticated;

-- ============================================================
-- 3. close_atf — manual encerramento (D-15, D-16)
-- ============================================================
CREATE OR REPLACE FUNCTION close_atf(
  p_atf_batch_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM atf_batches
   WHERE id = p_atf_batch_id
     AND active = true
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf_batch % not found or is already closed', p_atf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can close an ATF'
      USING ERRCODE = '42501';
  END IF;

  UPDATE atf_batches
     SET active = false
   WHERE id = p_atf_batch_id;

  -- Deactivating every membership of this batch is what frees each animal's slot in
  -- animal_atf_memberships_active_idx for a new cycle (D-16). The rows themselves stay — history
  -- and DG correction (save_dg_records) survive an encerramento.
  UPDATE animal_atf_memberships
     SET active = false
   WHERE atf_batch_id = p_atf_batch_id
     AND active = true;
END;
$$;

REVOKE ALL ON FUNCTION close_atf(uuid) FROM public;
GRANT EXECUTE ON FUNCTION close_atf(uuid) TO authenticated;

-- ============================================================
-- 4. save_dg_records — additive batch INSERT into dg_records (REPR-03, D-10..D-12, D-16)
-- ============================================================
CREATE OR REPLACE FUNCTION save_dg_records(
  p_atf_batch_id uuid,
  p_records      jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
  v_record      jsonb;
  v_animal_id   uuid;
  v_result      text;
  v_exam_date   date;
  v_observation text;
BEGIN
  -- Deliberately NO `active = true` filter here, unlike add_animals_to_atf/remove_animal_from_atf/
  -- close_atf above — D-16 requires DG correction to stay possible after encerramento closes the
  -- batch, so an already-closed atf_batches row must still resolve here.
  SELECT property_id
    INTO v_property_id
    FROM atf_batches
   WHERE id = p_atf_batch_id;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf_batch % not found', p_atf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can save DG records'
      USING ERRCODE = '42501';
  END IF;

  FOR v_record IN SELECT * FROM jsonb_array_elements(p_records) LOOP
    v_animal_id   := (v_record ->> 'animal_id')::uuid;
    v_result      := v_record ->> 'result';
    v_exam_date   := (v_record ->> 'exam_date')::date;
    v_observation := v_record ->> 'observation';

    IF v_result NOT IN ('pregnant', 'not_pregnant', 'doubtful') THEN
      RAISE EXCEPTION 'invalid DG result % for animal %', v_result, v_animal_id
        USING ERRCODE = '22023';
    END IF;

    -- Existence guard: check only that a membership row exists for this (atf_batch, animal) pair —
    -- deliberately NOT filtering on `active`. This single condition is what makes all three
    -- deactivation paths behave correctly: a D-08 removal hard-deleted the row so a DG is refused
    -- (23503 below), while a D-16 closure or D-19 baixa left the row present (inactive) so a
    -- correction is accepted.
    IF NOT EXISTS (
      SELECT 1 FROM animal_atf_memberships
       WHERE atf_batch_id = p_atf_batch_id
         AND animal_id = v_animal_id
    ) THEN
      RAISE EXCEPTION 'animal % is not a member of ATF %', v_animal_id, p_atf_batch_id
        USING ERRCODE = '23503';
    END IF;

    -- Only INSERT — never UPDATE or DELETE an existing dg_records row. D-12 makes the DG history
    -- additive; the most recent record wins at read time. The whole function body is one
    -- transaction, so a bad record anywhere in the batch rolls the entire batch back (the
    -- atomicity 05-UI-SPEC's DG Batch Save contract requires).
    INSERT INTO dg_records (property_id, atf_batch_id, animal_id, result, exam_date, observation)
    VALUES (v_property_id, p_atf_batch_id, v_animal_id, v_result, v_exam_date, v_observation);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION save_dg_records(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION save_dg_records(uuid, jsonb) TO authenticated;

-- ============================================================
-- 5. register_baixa — replaces the direct UPDATE on animals (ANIM-04, D-19)
-- ============================================================
CREATE OR REPLACE FUNCTION register_baixa(
  p_animal_id   uuid,
  p_reason      text,
  p_date        date,
  p_observation text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM animals
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or already archived', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register a baixa'
      USING ERRCODE = '42501';
  END IF;

  IF p_reason NOT IN ('sale', 'death', 'discard') THEN
    RAISE EXCEPTION 'invalid baixa reason %', p_reason
      USING ERRCODE = '22023';
  END IF;

  -- Guarded by deleted_at IS NULL, followed by the IF NOT FOUND re-check below — the WR-01 fix
  -- from move_animal_to_lot (20260715_04_gap_move_animal_to_lot.sql) reused here so two concurrent
  -- baixas on the same animal cannot both report success.
  UPDATE animals
     SET baixa_reason = p_reason,
         baixa_date   = p_date,
         deleted_at   = now(),
         observation  = COALESCE(p_observation, observation)
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'animal % was archived concurrently', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  -- Deliberately NO second UPDATE against animal_atf_memberships here — plan 05-01's
  -- trg_animals_baixa_deactivates_atf trigger (AFTER UPDATE OF deleted_at ON animals) fires on the
  -- UPDATE above and performs the D-19 deactivation on every access path, including a raw
  -- PostgREST PATCH that never reaches this function. This omission is deliberate, not a gap.
END;
$$;

REVOKE ALL ON FUNCTION register_baixa(uuid, text, date, text) FROM public;
GRANT EXECUTE ON FUNCTION register_baixa(uuid, text, date, text) TO authenticated;
