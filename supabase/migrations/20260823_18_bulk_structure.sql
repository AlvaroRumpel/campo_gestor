-- 20260823_18_bulk_structure.sql — RPCs bulk para o hub Planilhas (fase 14,
-- GRID-02): piquetes, lotes e gastos editáveis em grade / importáveis.
--
-- Mesmo padrão de 20260820_15_bulk_sheets.sql: SECURITY DEFINER + guarda
-- explícita, erro "linha N: motivo", transação tudo-ou-nada. `id` presente na
-- linha = alvo exato (grade); ausente = match por nome (import) ou INSERT.

-- ============================================================
-- 1. bulk_upsert_paddocks — rows: [{id?, name, area_ha, ua_capacity}]
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_upsert_paddocks(p_property_id uuid, p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_id uuid; v_name text; v_area numeric; v_cap numeric;
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_name := nullif(trim(r->>'name'), '');
    v_area := (r->>'area_ha')::numeric;
    v_cap  := (r->>'ua_capacity')::numeric;

    v_id := NULL;
    IF r ? 'id' AND nullif(r->>'id', '') IS NOT NULL THEN
      SELECT id INTO v_id FROM paddocks
       WHERE id = (r->>'id')::uuid AND property_id = p_property_id
         AND deleted_at IS NULL;
      IF v_id IS NULL THEN
        RAISE EXCEPTION 'linha %: piquete não encontrado', i;
      END IF;
    ELSIF v_name IS NOT NULL THEN
      SELECT id INTO v_id FROM paddocks
       WHERE property_id = p_property_id AND deleted_at IS NULL
         AND lower(trim(name)) = lower(v_name);
    END IF;

    IF v_id IS NULL THEN
      IF v_name IS NULL THEN
        RAISE EXCEPTION 'linha %: nome do piquete obrigatório', i;
      END IF;
      IF v_area IS NULL OR v_area <= 0 THEN
        RAISE EXCEPTION 'linha %: área (ha) obrigatória e maior que zero', i;
      END IF;
      IF v_cap IS NULL OR v_cap <= 0 THEN
        RAISE EXCEPTION 'linha %: capacidade (UA) obrigatória e maior que zero', i;
      END IF;
      INSERT INTO paddocks (property_id, name, area_ha, ua_capacity)
      VALUES (p_property_id, v_name, v_area, v_cap);
      v_created := v_created + 1;
    ELSE
      UPDATE paddocks SET
        name        = COALESCE(v_name, name),
        area_ha     = COALESCE(v_area, area_ha),
        ua_capacity = COALESCE(v_cap, ua_capacity)
      WHERE id = v_id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_paddocks(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_paddocks(uuid, jsonb) TO authenticated;

-- ============================================================
-- 2. bulk_upsert_lots — rows: [{id?, name, paddock_name}]
--    id presente (grade) permite renomear; sem id o nome é a chave de match
--    (import não renomeia — cria). Mover de piquete via paddock_name;
--    trg_lots_paddock_same_property continua sendo a última linha de defesa.
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_upsert_lots(p_property_id uuid, p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_id uuid; v_name text; v_paddock_name text; v_paddock_id uuid;
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_name := nullif(trim(r->>'name'), '');
    v_paddock_name := nullif(trim(r->>'paddock_name'), '');

    v_paddock_id := NULL;
    IF v_paddock_name IS NOT NULL THEN
      SELECT id INTO v_paddock_id FROM paddocks
       WHERE property_id = p_property_id AND deleted_at IS NULL
         AND lower(trim(name)) = lower(v_paddock_name);
      IF v_paddock_id IS NULL THEN
        RAISE EXCEPTION 'linha %: piquete "%" não encontrado', i, v_paddock_name;
      END IF;
    END IF;

    v_id := NULL;
    IF r ? 'id' AND nullif(r->>'id', '') IS NOT NULL THEN
      SELECT id INTO v_id FROM lots
       WHERE id = (r->>'id')::uuid AND property_id = p_property_id
         AND deleted_at IS NULL;
      IF v_id IS NULL THEN
        RAISE EXCEPTION 'linha %: lote não encontrado', i;
      END IF;
    ELSIF v_name IS NOT NULL THEN
      SELECT id INTO v_id FROM lots
       WHERE property_id = p_property_id AND deleted_at IS NULL
         AND lower(trim(name)) = lower(v_name);
    END IF;

    IF v_id IS NULL THEN
      IF v_name IS NULL THEN
        RAISE EXCEPTION 'linha %: nome do lote obrigatório', i;
      END IF;
      IF v_paddock_id IS NULL THEN
        RAISE EXCEPTION 'linha %: piquete obrigatório para lote novo', i;
      END IF;
      INSERT INTO lots (property_id, paddock_id, name)
      VALUES (p_property_id, v_paddock_id, v_name);
      v_created := v_created + 1;
    ELSE
      UPDATE lots SET
        name       = COALESCE(v_name, name),
        paddock_id = COALESCE(v_paddock_id, paddock_id)
      WHERE id = v_id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_lots(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_lots(uuid, jsonb) TO authenticated;

-- ============================================================
-- 3. bulk_upsert_expenses — rows: [{id?, paddock_name, category, amount,
--    expense_date, description}]
--    Guarda própria: owner OU veterinarian (D-23 — gastos são o único módulo
--    com escrita do proprietário; assert_vet_of seria restritivo demais).
--    Sem match por nome (gasto não tem chave natural): id = UPDATE, sem id =
--    INSERT. Categoria: texto não-vazio (D-03 — lista vive no Dart).
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_upsert_expenses(p_property_id uuid, p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_id uuid; v_paddock_id uuid; v_paddock_name text;
  v_category text; v_amount numeric; v_date date;
BEGIN
  IF p_property_id IS NULL THEN
    RAISE EXCEPTION 'property_id is required' USING ERRCODE = '22023';
  END IF;
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;
  IF get_role(p_property_id) NOT IN ('owner'::role_enum, 'veterinarian'::role_enum) THEN
    RAISE EXCEPTION 'forbidden: only owners and veterinarians can bulk-write expenses'
      USING ERRCODE = '42501';
  END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_category := nullif(trim(r->>'category'), '');
    v_amount   := (r->>'amount')::numeric;
    v_date     := (r->>'expense_date')::date;
    v_paddock_name := nullif(trim(r->>'paddock_name'), '');

    v_paddock_id := NULL;
    IF v_paddock_name IS NOT NULL THEN
      SELECT id INTO v_paddock_id FROM paddocks
       WHERE property_id = p_property_id AND deleted_at IS NULL
         AND lower(trim(name)) = lower(v_paddock_name);
      IF v_paddock_id IS NULL THEN
        RAISE EXCEPTION 'linha %: piquete "%" não encontrado', i, v_paddock_name;
      END IF;
    END IF;

    IF r ? 'id' AND nullif(r->>'id', '') IS NOT NULL THEN
      SELECT id INTO v_id FROM expenses
       WHERE id = (r->>'id')::uuid AND property_id = p_property_id
         AND deleted_at IS NULL;
      IF v_id IS NULL THEN
        RAISE EXCEPTION 'linha %: gasto não encontrado', i;
      END IF;
      UPDATE expenses SET
        paddock_id   = COALESCE(v_paddock_id, paddock_id),
        category     = COALESCE(v_category, category),
        amount       = COALESCE(v_amount, amount),
        expense_date = COALESCE(v_date, expense_date),
        description  = CASE WHEN r ? 'description'
                            THEN nullif(trim(r->>'description'), '')
                            ELSE description END,
        updated_by   = auth.uid(),
        updated_at   = now()
      WHERE id = v_id;
      v_updated := v_updated + 1;
    ELSE
      IF v_paddock_id IS NULL THEN
        RAISE EXCEPTION 'linha %: piquete obrigatório', i;
      END IF;
      IF v_category IS NULL THEN
        RAISE EXCEPTION 'linha %: categoria obrigatória', i;
      END IF;
      IF v_amount IS NULL OR v_amount <= 0 THEN
        RAISE EXCEPTION 'linha %: valor obrigatório e maior que zero', i;
      END IF;
      IF v_date IS NULL THEN
        RAISE EXCEPTION 'linha %: data obrigatória', i;
      END IF;
      INSERT INTO expenses (property_id, paddock_id, category, amount,
                            expense_date, description)
      VALUES (p_property_id, v_paddock_id, v_category, v_amount, v_date,
              nullif(trim(r->>'description'), ''));
      v_created := v_created + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_expenses(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_expenses(uuid, jsonb) TO authenticated;
