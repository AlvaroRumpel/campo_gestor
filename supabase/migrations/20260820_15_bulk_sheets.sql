-- 20260820_15_bulk_sheets.sql — RPCs de importação/grade em lote (spec planilhas,
-- docs/superpowers/specs/2026-08-19-planilhas-design.md).
--
-- Padrão: SECURITY DEFINER + guardas explícitas is_member_of/get_role, o mesmo de
-- register_sanitary_application (20260811_06). Erro em qualquer linha → RAISE com
-- "linha N: motivo" → transação inteira desfeita (import é tudo-ou-nada).

-- ============================================================
-- 0. assert_vet_of — guarda compartilhada pelas três RPCs bulk
-- ============================================================
CREATE OR REPLACE FUNCTION assert_vet_of(p_property_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_property_id IS NULL THEN
    RAISE EXCEPTION 'property_id is required' USING ERRCODE = '22023';
  END IF;
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;
  IF get_role(p_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can bulk-write'
      USING ERRCODE = '42501';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION assert_vet_of(uuid) FROM public;

-- ============================================================
-- 1. bulk_upsert_doses — match por lower(trim(name)) ativa
--    rows: [{name, active_ingredient, dosage_per_kg, cost_per_kg}]
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_upsert_doses(p_property_id uuid, p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_name text; v_id uuid; v_dosage numeric; v_cost numeric;
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_name := nullif(trim(r->>'name'), '');
    IF v_name IS NULL THEN
      RAISE EXCEPTION 'linha %: nome da dose obrigatório', i;
    END IF;
    v_dosage := (r->>'dosage_per_kg')::numeric;
    v_cost   := (r->>'cost_per_kg')::numeric;

    SELECT id INTO v_id FROM doses
     WHERE property_id = p_property_id
       AND deleted_at IS NULL
       AND lower(trim(name)) = lower(v_name);

    IF v_id IS NULL THEN
      IF v_dosage IS NULL OR v_dosage <= 0 THEN
        RAISE EXCEPTION 'linha %: dosagem por kg obrigatória e maior que zero', i;
      END IF;
      INSERT INTO doses (property_id, name, active_ingredient, dosage_per_kg, cost_per_kg)
      VALUES (p_property_id, v_name,
              nullif(trim(r->>'active_ingredient'), ''), v_dosage, v_cost);
      v_created := v_created + 1;
    ELSE
      -- Chave presente no json decide se o campo é tocado; null explícito limpa.
      UPDATE doses SET
        active_ingredient = CASE WHEN r ? 'active_ingredient'
                                 THEN nullif(trim(r->>'active_ingredient'), '')
                                 ELSE active_ingredient END,
        dosage_per_kg     = COALESCE(v_dosage, dosage_per_kg),
        cost_per_kg       = CASE WHEN r ? 'cost_per_kg' THEN v_cost ELSE cost_per_kg END
      WHERE id = v_id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_doses(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_doses(uuid, jsonb) TO authenticated;

-- ============================================================
-- 2. bulk_upsert_animals — upsert por (property_id, number) ativo
--    rows: [{number|null, category, breed, body_condition, observation, lot_name}]
--    number null/inexistente → INSERT (lote obrigatório; número gerado se null);
--    number existente ativo  → UPDATE dos campos presentes no json.
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_upsert_animals(p_property_id uuid, p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_number int; v_category text; v_lot_id uuid; v_lot_name text; v_id uuid; v_ecc int;
  k_categories text[] := ARRAY['vaca','novilha','terneiro','terneira','touro','boi','novilho'];
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_number   := (r->>'number')::int;
    v_category := lower(trim(r->>'category'));
    v_lot_name := nullif(trim(r->>'lot_name'), '');
    v_ecc      := (r->>'body_condition')::int;

    IF v_category IS NULL OR NOT (v_category = ANY (k_categories)) THEN
      RAISE EXCEPTION 'linha %: categoria "%" inválida', i, COALESCE(r->>'category', '');
    END IF;
    IF v_ecc IS NOT NULL AND (v_ecc < 1 OR v_ecc > 5) THEN
      RAISE EXCEPTION 'linha %: ECC deve ser de 1 a 5', i;
    END IF;

    IF v_lot_name IS NOT NULL THEN
      SELECT id INTO v_lot_id FROM lots
       WHERE property_id = p_property_id
         AND deleted_at IS NULL
         AND lower(name) = lower(v_lot_name);
      IF v_lot_id IS NULL THEN
        RAISE EXCEPTION 'linha %: lote "%" não encontrado', i, v_lot_name;
      END IF;
    ELSE
      v_lot_id := NULL;
    END IF;

    v_id := NULL;
    IF v_number IS NOT NULL THEN
      SELECT id INTO v_id FROM animals
       WHERE property_id = p_property_id AND deleted_at IS NULL AND number = v_number;
    END IF;

    IF v_id IS NULL THEN
      IF v_lot_id IS NULL THEN
        RAISE EXCEPTION 'linha %: lote obrigatório para animal novo', i;
      END IF;
      IF v_number IS NULL THEN
        v_number := generate_animal_number(p_property_id);
      END IF;
      INSERT INTO animals (property_id, lot_id, category, number, breed, body_condition, observation)
      VALUES (p_property_id, v_lot_id, v_category, v_number,
              nullif(trim(r->>'breed'), ''), v_ecc, nullif(trim(r->>'observation'), ''));
      v_created := v_created + 1;
    ELSE
      UPDATE animals SET
        category       = v_category,
        lot_id         = COALESCE(v_lot_id, lot_id),
        breed          = CASE WHEN r ? 'breed' THEN nullif(trim(r->>'breed'), '') ELSE breed END,
        body_condition = CASE WHEN r ? 'body_condition' THEN v_ecc ELSE body_condition END,
        observation    = CASE WHEN r ? 'observation' THEN nullif(trim(r->>'observation'), '') ELSE observation END
      WHERE id = v_id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION
  WHEN unique_violation THEN RAISE EXCEPTION 'linha %: número já existe na propriedade', i;
  WHEN check_violation  THEN RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_animals(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_animals(uuid, jsonb) TO authenticated;

-- ============================================================
-- 3. bulk_register_sanitary — resolve nº→animal e nome→dose, agrupa por
--    (lote do animal, dose, data, notes) e delega a register_sanitary_application
--    (snapshot, totais e revalidação D-32 continuam num só lugar).
--    rows: [{animal_number, dose_name, applied_at, notes}]
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_register_sanitary(p_property_id uuid, p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  g record; v_apps int := 0; v_animals int := 0; i int := 0; r jsonb;
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  CREATE TEMP TABLE _bulk_san (
    idx int, animal_id uuid, lot_id uuid, dose_id uuid, applied_at date, notes text
  ) ON COMMIT DROP;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    INSERT INTO _bulk_san
    SELECT i, a.id, a.lot_id, d.id, (r->>'applied_at')::date, nullif(trim(r->>'notes'), '')
      FROM animals a
      LEFT JOIN doses d ON d.property_id = p_property_id AND d.deleted_at IS NULL
                       AND lower(trim(d.name)) = lower(trim(r->>'dose_name'))
     WHERE a.property_id = p_property_id
       AND a.deleted_at IS NULL
       AND a.number = (r->>'animal_number')::int;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'linha %: animal nº % não encontrado', i, r->>'animal_number';
    END IF;
    IF (SELECT dose_id FROM _bulk_san WHERE idx = i) IS NULL THEN
      RAISE EXCEPTION 'linha %: dose "%" não encontrada', i, r->>'dose_name';
    END IF;
    IF (SELECT applied_at FROM _bulk_san WHERE idx = i) IS NULL THEN
      RAISE EXCEPTION 'linha %: data obrigatória', i;
    END IF;
  END LOOP;

  FOR g IN
    SELECT lot_id, dose_id, applied_at, notes,
           jsonb_agg(DISTINCT animal_id) AS ids,
           count(DISTINCT animal_id)     AS n
      FROM _bulk_san
     GROUP BY lot_id, dose_id, applied_at, notes
  LOOP
    PERFORM register_sanitary_application(g.lot_id, g.dose_id, g.applied_at, g.ids, g.notes);
    v_apps := v_apps + 1;
    v_animals := v_animals + g.n;
  END LOOP;

  RETURN jsonb_build_object('applications', v_apps, 'animals', v_animals);
END; $$;
REVOKE ALL ON FUNCTION bulk_register_sanitary(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_register_sanitary(uuid, jsonb) TO authenticated;
