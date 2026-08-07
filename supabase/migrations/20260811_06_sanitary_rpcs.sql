-- 20260811_06_sanitary_rpcs.sql
-- Phase 6 — Sanitary Module (Snapshot)
-- References: SANI-02, SANI-03, D-27..D-34
--
-- Two SECURITY DEFINER RPCs — the entire write surface of sanitary_applications
-- (20260810_06_sanitary_module.sql §6). Both follow the project's standard guard sequence
-- (property resolution → is_member_of → get_role → REVOKE/GRANT footer), mirroring
-- register_baixa / add_animals_to_atf in 20260805_05_atf_rpcs.sql.
--
-- Not applied by this plan — 06-12 owns the push (see 06-02-PLAN.md critical_scope_note).

-- ============================================================
-- 1. register_sanitary_application (SANI-02, SANI-03, D-32, D-34)
-- ============================================================
CREATE OR REPLACE FUNCTION register_sanitary_application(
  p_lot_id     uuid,
  p_dose_id    uuid,
  p_applied_at date,
  p_animal_ids jsonb,             -- JSON array of animal uuid strings, post-deselection
  p_notes      text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_property_id     uuid;
  v_lot_name        text;
  v_dose            record;
  v_kg_per_ua       numeric;
  v_distinct_ids    jsonb;
  v_selected_count  integer;
  v_valid_count     integer;
  v_active_count    integer;
  v_snapshot        jsonb;
  v_total_ua        numeric;
  v_total_volume    numeric;
  v_total_cost      numeric;
  v_app_id          uuid;
BEGIN
  SELECT property_id, name INTO v_property_id, v_lot_name
    FROM lots WHERE id = p_lot_id AND deleted_at IS NULL;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'lot % not found or archived', p_lot_id USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register a sanitary application'
      USING ERRCODE = '42501';
  END IF;

  SELECT id, name, dosage_per_kg, cost_per_kg INTO v_dose
    FROM doses WHERE id = p_dose_id AND property_id = v_property_id AND deleted_at IS NULL;
  IF v_dose.id IS NULL THEN
    RAISE EXCEPTION 'dose % not found or archived', p_dose_id USING ERRCODE = '23503';
  END IF;

  SELECT kg_per_ua INTO v_kg_per_ua FROM properties WHERE id = v_property_id;

  -- Guard NULL parameters before any array operation — a null jsonb parameter must not
  -- silently become an empty selection (lesson of 20260809_05_fix_register_baixa_null_guards).
  IF p_applied_at IS NULL THEN
    RAISE EXCEPTION 'applied_at is required' USING ERRCODE = '22023';
  END IF;
  IF p_animal_ids IS NULL THEN
    RAISE EXCEPTION 'animal_ids is required' USING ERRCODE = '22023';
  END IF;

  -- Deduplicate the submitted id array before counting — a repeated uuid in the payload is a
  -- no-op rather than a spurious count mismatch (lesson of
  -- 20260808_05_fix_baixa_observation_and_atf_dedup).
  SELECT jsonb_agg(DISTINCT elem) INTO v_distinct_ids
    FROM jsonb_array_elements_text(p_animal_ids) elem;

  v_selected_count := COALESCE(jsonb_array_length(v_distinct_ids), 0);
  IF v_selected_count = 0 THEN
    RAISE EXCEPTION 'at least 1 animal must be selected' USING ERRCODE = '23514';
  END IF;

  -- D-32: concurrency revalidation — the whole transaction aborts if any submitted animal is no
  -- longer active in this exact lot. Never a partial write.
  SELECT count(*) INTO v_valid_count
    FROM animals a
    JOIN jsonb_array_elements_text(v_distinct_ids) elem(id) ON a.id = elem.id::uuid
   WHERE a.lot_id = p_lot_id AND a.deleted_at IS NULL AND a.property_id = v_property_id;

  IF v_valid_count <> v_selected_count THEN
    RAISE EXCEPTION '% animais mudaram desde que a tela foi aberta — recarregue',
      (v_selected_count - v_valid_count)
      USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*) INTO v_active_count FROM animals WHERE lot_id = p_lot_id AND deleted_at IS NULL;

  SELECT jsonb_agg(jsonb_build_object(
           'animal_id', a.id, 'number', a.number,
           'category', a.category, 'ua', animal_ua_weight(a.category)
         )),
         sum(animal_ua_weight(a.category))
    INTO v_snapshot, v_total_ua
    FROM animals a
    JOIN jsonb_array_elements_text(v_distinct_ids) elem(id) ON a.id = elem.id::uuid;

  v_total_volume := v_total_ua * v_dose.dosage_per_kg * v_kg_per_ua;
  v_total_cost   := CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL
                          ELSE v_total_ua * v_dose.cost_per_kg * v_kg_per_ua END;

  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes
  ) VALUES (
    v_snapshot, v_property_id, p_lot_id, v_lot_name, v_dose.id, v_dose.name,
    v_dose.dosage_per_kg, v_dose.dosage_per_kg * v_kg_per_ua, v_dose.cost_per_kg,
    CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL ELSE v_dose.cost_per_kg * v_kg_per_ua END,
    p_applied_at, auth.uid(), v_selected_count, v_total_ua, v_total_volume, v_total_cost,
    v_active_count - v_selected_count, p_notes
  ) RETURNING id INTO v_app_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_app_id);
END;
$$;

REVOKE ALL ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) FROM public;
GRANT EXECUTE ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) TO authenticated;

-- ============================================================
-- 2. reverse_sanitary_application (D-27..D-31)
-- ============================================================
-- Locked sign convention (06-VALIDATION.md § Locked Convention, resolving 06-RESEARCH.md
-- Assumption A1): all four numeric header totals (animal_count, total_ua, total_volume,
-- total_cost) are negated so any SUM() over the table self-corrects — "quantos animais
-- tratados", "quanto gastei" come out right without every future query remembering to exclude
-- reversals. composition_snapshot is copied unchanged (same animals, not a signed quantity), so
-- a screen reading the array length always shows a positive count. applied_at is set to
-- CURRENT_DATE (when the reversal happened), not the original row's applied_at, matching the
-- UI-SPEC "Estornada em" row and D-30 (an estorno can occur months after the original).
CREATE OR REPLACE FUNCTION reverse_sanitary_application(
  p_application_id uuid,
  p_reason         text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_orig   record;
  v_new_id uuid;
BEGIN
  SELECT * INTO v_orig FROM sanitary_applications WHERE id = p_application_id;
  IF v_orig.id IS NULL THEN
    RAISE EXCEPTION 'sanitary application % not found', p_application_id USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_orig.property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_orig.property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(v_orig.property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can reverse a sanitary application'
      USING ERRCODE = '42501';
  END IF;

  -- D-30: estorno de estorno é bloqueado.
  IF v_orig.reverses_application_id IS NOT NULL THEN
    RAISE EXCEPTION 'cannot reverse a reversal record' USING ERRCODE = '23514';
  END IF;

  -- Explicit trim(coalesce(...)) comparison rather than a bare NULL test — a whitespace-only
  -- reason must also be rejected.
  IF trim(coalesce(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'reversal reason is required' USING ERRCODE = '22023';
  END IF;

  -- D-31: legible pre-check before the unique index's 23505 backstop is the real guarantee.
  IF EXISTS (SELECT 1 FROM sanitary_applications WHERE reverses_application_id = p_application_id) THEN
    RAISE EXCEPTION 'sanitary application % was already reversed', p_application_id
      USING ERRCODE = 'P0003';
  END IF;

  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes,
    reverses_application_id
  ) VALUES (
    v_orig.composition_snapshot, v_orig.property_id, v_orig.lot_id, v_orig.lot_name,
    v_orig.dose_id, v_orig.dose_name, v_orig.dosage_per_kg, v_orig.dosage_per_ua,
    v_orig.cost_per_kg, v_orig.cost_per_ua, current_date, auth.uid(),
    -v_orig.animal_count, -v_orig.total_ua, -v_orig.total_volume,
    CASE WHEN v_orig.total_cost IS NULL THEN NULL ELSE -v_orig.total_cost END,
    v_orig.skipped_count, p_reason, v_orig.id
  ) RETURNING id INTO v_new_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_new_id);
END;
$$;

REVOKE ALL ON FUNCTION reverse_sanitary_application(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION reverse_sanitary_application(uuid, text) TO authenticated;
