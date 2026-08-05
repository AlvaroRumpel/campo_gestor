-- 20260808_05_fix_baixa_observation_and_atf_dedup.sql
-- Phase 5 corrective migration — code review CR-01 + WR-02
-- References: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md#CR-01
-- References: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md#WR-02
--
-- CR-01: register_baixa's final UPDATE assigned the animal's observation with a COALESCE-style
-- expression that replaced rather than appended. Any text a vet typed into BaixaDialog's
-- "Observação" field (hint:
-- "Observações adicionais (opcional)", which promises additive behavior) silently destroyed every
-- prior general note on that animal, and the same statement sets deleted_at, so the lost text was
-- unrecoverable through the UI. Fix: replace the assignment with a CASE expression that appends
-- the new note to the existing one with a newline separator, treating NULL or empty-string
-- p_observation as a strict no-op on the existing text (the common path — the Dart caller already
-- collapses an empty field to NULL before calling this RPC). This appends into the shared
-- animals.observation column rather than introducing a dedicated baixa_observation column
-- (assumption A-OBS-SHARED-COLUMN, 05-REVIEW.md CR-01 option (a), which the reviewer preferred).
-- Consequence accepted: after a baixa, nothing mechanically distinguishes which part of the text
-- was the baixa note from the prior general note. The data-loss defect is fully closed either way;
-- a dedicated column is a presentation nicety with a schema change behind it and is deliberately
-- not built here.
--
-- WR-02: add_animals_to_atf's INSERT ... SELECT had no de-duplication, so a p_animal_ids payload
-- containing the same uuid twice attempted two active-membership rows for the same animal in one
-- statement and tripped animal_atf_memberships_active_idx's partial unique constraint, failing the
-- entire batch with a raw 23505. Fix: add DISTINCT to the feeding SELECT. De-duplication happens
-- there, not via an ON CONFLICT clause, because the partial unique index must still raise 23505
-- for an animal already in a *different* active ATF — that is REPR-02's actual guarantee, and an
-- ON CONFLICT DO NOTHING/DO UPDATE would silently swallow that genuine violation too.
--
-- Both functions are re-declared with CREATE OR REPLACE carrying their full current body, with
-- only the one defective expression changed per function. Signature, LANGUAGE plpgsql, SECURITY
-- DEFINER, and SET search_path = public are all preserved verbatim — changing any of those would
-- create a second overload (leaving the defective definition live) or reopen a search-path
-- hijack on a SECURITY DEFINER function (T-05-60). D-21's authorization guards (is_member_of,
-- veterinarian-role check) and D-19's baixa -> membership-deactivation chain (deleted_at = now(),
-- picked up by trg_animals_baixa_deactivates_atf) are unaffected by either change.

-- ============================================================
-- 1. add_animals_to_atf — de-duplicate p_animal_ids within one payload (WR-02)
-- ============================================================
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
  --
  -- WR-02: DISTINCT collapses a uuid repeated within THIS payload into one row. Duplicates
  -- across ATFs (the animal already sits in another active ATF) are still rejected by
  -- animal_atf_memberships_active_idx with 23505 — that constraint is REPR-02's actual
  -- guarantee and is deliberately not weakened by an ON CONFLICT clause here.
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, active, property_id)
  SELECT DISTINCT (elem)::uuid, p_atf_batch_id, true, v_property_id
    FROM jsonb_array_elements_text(p_animal_ids) AS elem;
END;
$$;

REVOKE ALL ON FUNCTION add_animals_to_atf(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION add_animals_to_atf(uuid, jsonb) TO authenticated;

-- ============================================================
-- 2. register_baixa — append the baixa observation instead of replacing (CR-01)
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
  --
  -- CR-01: the observation assignment below used to replace the animal's prior general note
  -- outright instead of appending to it. That destroyed any prior note (health remarks,
  -- body-condition notes) the moment a baixa carried its own note, and the row is archived in the
  -- same statement so the loss was unrecoverable through the UI. The CASE below appends the new
  -- note after the existing one, separated by a newline, and treats a NULL or empty-string
  -- p_observation as a strict no-op on the existing text.
  UPDATE animals
     SET baixa_reason = p_reason,
         baixa_date   = p_date,
         deleted_at   = now(),
         observation  = CASE
                           WHEN p_observation IS NULL OR p_observation = '' THEN observation
                           WHEN observation IS NULL OR observation = '' THEN p_observation
                           ELSE observation || E'\n' || p_observation
                         END
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
