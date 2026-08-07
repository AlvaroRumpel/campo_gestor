-- 20260812_06_fix_dose_update_policy.sql
-- Phase 6 corrective migration — gap closure G-06-2
-- References: .planning/debug/dose-restore-noop.md, .planning/phases/06-sanitary-module-snapshot/06-13-PLAN.md
--
-- Why this migration exists: 20260810_06_sanitary_module.sql already contains the CORRECT
-- `veterinarian_can_update_active_dose` policy body on disk (no soft-delete predicate in USING or
-- WITH CHECK). That correctness is an illusion of the file, not of the live database: the
-- migration was applied to PROD project wrdwzychjhlpwpivfhhq at ~2026-08-07 01:27 (06-12), and the
-- CR-01 review fix (commit ae08dba) that removed the `AND deleted_at IS NULL` USING clause landed
-- ~13 hours later by editing that already-applied file in place. An applied migration does not
-- re-run, so the live policy never changed. RLS evaluates USING against the PRE-update row: an
-- UPDATE clearing deleted_at on an archived dose is evaluated against a row where deleted_at IS NOT
-- NULL, the old USING clause rejects it, zero rows match, and PostgREST answers 2xx anyway — the
-- silent no-op the UAT report described as "clico em desarquivar e não desarquiva". Editing an
-- archived dose (name/dosage/cost) fails the same way.
--
-- Fix: forward-only DROP + CREATE of the same policy, reproducing the body already committed in
-- 20260810_06_sanitary_module.sql:47-49 verbatim. 20260810_06_sanitary_module.sql itself is left
-- byte-identical — re-editing an already-applied migration file is the mistake that produced this
-- gap in the first place.
--
-- Policy name kept as "veterinarian_can_update_active_dose" though "active" is now a misnomer:
-- renaming would churn every pgTAP policy-name assertion and catalog check written in 06-12 for
-- zero behavioural gain.
--
-- Idempotency note: a fresh environment applies 20260810_06_sanitary_module.sql (already correct)
-- and then this migration, which drops and recreates the same policy a second time — harmless. An
-- existing (already-broken) environment like PROD gets the corrected policy for the first time.
DROP POLICY IF EXISTS "veterinarian_can_update_active_dose" ON doses;

CREATE POLICY "veterinarian_can_update_active_dose" ON doses FOR UPDATE TO authenticated
  USING (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum)
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
