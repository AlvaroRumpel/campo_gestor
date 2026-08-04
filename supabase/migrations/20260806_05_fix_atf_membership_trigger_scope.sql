-- 20260806_05_fix_atf_membership_trigger_scope.sql
-- Phase 5 corrective migration — code review CR-01
-- References: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md#CR-01
--
-- trg_atf_membership_valid was declared BEFORE INSERT OR UPDATE (unscoped), so
-- enforce_atf_membership_valid() re-validated the referenced animal on EVERY row write,
-- including a pure `active` flag flip. D-19's baixa chain
-- (register_baixa -> UPDATE animals SET deleted_at = now()
--  -> trg_animals_baixa_deactivates_atf fires an UPDATE animal_atf_memberships SET active = false
--  -> that UPDATE re-fires this BEFORE trigger
--  -> the animal now looks archived per `deleted_at IS NULL`
--  -> RAISE EXCEPTION 23503
--  -> the whole register_baixa transaction rolls back)
-- made register_baixa fail unconditionally for the exact scenario D-19 exists to handle:
-- an animal currently in an active ATF.
--
-- No write path in this module ever changes animal_id, atf_batch_id, or property_id on an
-- existing animal_atf_memberships row (add_animals_to_atf/remove_animal_from_atf only INSERT/
-- DELETE; close_atf and the baixa trigger only flip `active`) — so the UPDATE trigger is
-- rescoped to fire only when one of those three columns actually changes. This is idempotent
-- and safe to re-run: DROP TRIGGER IF EXISTS + CREATE TRIGGER replaces the trigger definition
-- without touching enforce_atf_membership_valid() itself.
DROP TRIGGER IF EXISTS trg_atf_membership_valid ON animal_atf_memberships;

CREATE TRIGGER trg_atf_membership_valid
  BEFORE INSERT OR UPDATE OF animal_id, atf_batch_id, property_id ON animal_atf_memberships
  FOR EACH ROW
  EXECUTE FUNCTION enforce_atf_membership_valid();
