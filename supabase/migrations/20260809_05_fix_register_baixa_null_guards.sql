-- 20260809_05_fix_register_baixa_null_guards.sql
-- Phase 5 corrective migration — code review WR-01
-- References: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md#WR-01
--
-- WR-01: register_baixa's reason check was `IF p_reason NOT IN ('sale', 'death', 'discard') THEN`.
-- In SQL, `NULL NOT IN (...)` evaluates to NULL, not TRUE, and `IF NULL THEN ... END IF` takes the
-- false branch — so p_reason => NULL silently skipped the validation this IF exists to enforce,
-- and the subsequent UPDATE archived the animal with baixa_reason = NULL. p_date had the same gap:
-- no NULL guard at all, letting a baixa be recorded with baixa_date = NULL. Both are reachable by
-- any authenticated veterinarian member calling this SECURITY DEFINER RPC directly (PostgREST/
-- supabase-js), not only through BaixaDialog, which always supplies both fields. This predates the
-- 20260808 migration but is carried forward unchanged into the full function body that migration
-- redeclares — fixed here with its own forward-only corrective migration per this phase's
-- convention (CREATE OR REPLACE FUNCTION with the full current body, only the guard clauses
-- changed).
--
-- Fix: reject p_reason IS NULL explicitly (short-circuits before the NOT IN, which stays as the
-- allow-list guard for a non-NULL value), and add a symmetrical guard rejecting p_date IS NULL.
-- Everything else in the function body — the CR-01 observation-append CASE from 20260808, the
-- IF NOT FOUND concurrent-archive re-check, the deliberate absence of a second UPDATE against
-- animal_atf_memberships (trg_animals_baixa_deactivates_atf handles that) — is unchanged.
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

  -- WR-01: `NULL NOT IN (...)` is NULL, not TRUE — plpgsql's `IF NULL THEN` takes the false
  -- branch, so an explicit `p_reason IS NULL` check is required; the allow-list NOT IN alone
  -- silently let a NULL reason through.
  IF p_reason IS NULL OR p_reason NOT IN ('sale', 'death', 'discard') THEN
    RAISE EXCEPTION 'invalid baixa reason %', p_reason
      USING ERRCODE = '22023';
  END IF;

  -- WR-01: p_date had no NULL guard at all — without this, a direct RPC call could archive an
  -- animal with baixa_date = NULL.
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'baixa date is required'
      USING ERRCODE = '22023';
  END IF;

  -- Guarded by deleted_at IS NULL, followed by the IF NOT FOUND re-check below — the WR-01 fix
  -- from move_animal_to_lot (20260715_04_gap_move_animal_to_lot.sql) reused here so two concurrent
  -- baixas on the same animal cannot both report success.
  --
  -- CR-01 (05-REVIEW-FIX.md, 20260808 migration): the observation assignment below appends the
  -- new note to the existing one with a newline separator, treating NULL or empty-string
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
