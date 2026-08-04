-- 20260807_05_fix_remove_animal_from_atf_notfound.sql
-- Phase 5 corrective migration — code review WR-02
-- References: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md#WR-02
--
-- remove_animal_from_atf's final DELETE had no post-check, unlike close_atf and
-- register_baixa which both re-check IF NOT FOUND after their guarded UPDATE. If the animal
-- had no active membership in the given ATF (stale double-submit, two vets removing the same
-- animal concurrently), the DELETE silently affected 0 rows and the function returned success
-- — the caller could not distinguish "removed" from "was never there to remove". Adds the same
-- IF NOT FOUND -> RAISE EXCEPTION 23503 pattern already used elsewhere in this migration.
--
-- Does NOT touch the D-08 hard-DELETE semantics: save_dg_records still distinguishes a D-08
-- removal (membership row absent) from a D-16/D-19 deactivation (row present, active = false)
-- purely by whether the row exists — this fix only adds a post-check on the same DELETE.
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
  -- distinction in this migration. save_dg_records tells "removed before any DG, never accept a
  -- DG again" (D-08, this DELETE) apart from "closed, correction still allowed" (D-16, close_atf's
  -- UPDATE) purely by whether this membership row EXISTS. Do not "harmonize" this into a soft
  -- deactivation — that would silently reopen D-08's guarantee.
  DELETE FROM animal_atf_memberships
   WHERE atf_batch_id = p_atf_batch_id
     AND animal_id = p_animal_id
     AND active = true;

  -- WR-02: mirrors the IF NOT FOUND re-check close_atf/register_baixa already use elsewhere in
  -- this migration file — a 0-row DELETE (stale double-submit, concurrent removal) now surfaces
  -- as an error instead of a silent no-op success.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'animal % is not an active member of atf %', p_animal_id, p_atf_batch_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION remove_animal_from_atf(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION remove_animal_from_atf(uuid, uuid) TO authenticated;
