-- 18_bulk_structure_test.sql — replay das RPCs bulk de estrutura (fase 14).
-- Formato SQL editor (sem Docker): rodar inteiro; termina em ROLLBACK.
-- Resultado esperado: nenhuma exceção (NOTICEs "guard probe: 6/6" e
-- "behavior probe: 6/6").
BEGIN;

DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN PERFORM bulk_upsert_paddocks(NULL, '[]'::jsonb);
  EXCEPTION WHEN SQLSTATE '22023' THEN ok := ok + 1; END;
  BEGIN PERFORM bulk_upsert_lots(NULL, '[]'::jsonb);
  EXCEPTION WHEN SQLSTATE '22023' THEN ok := ok + 1; END;
  BEGIN PERFORM bulk_upsert_expenses(NULL, '[]'::jsonb);
  EXCEPTION WHEN SQLSTATE '22023' THEN ok := ok + 1; END;
  BEGIN PERFORM bulk_upsert_paddocks(gen_random_uuid(), '[]'::jsonb);
  EXCEPTION WHEN SQLSTATE '42501' THEN ok := ok + 1; END;
  BEGIN PERFORM bulk_upsert_lots(gen_random_uuid(), '[]'::jsonb);
  EXCEPTION WHEN SQLSTATE '42501' THEN ok := ok + 1; END;
  BEGIN PERFORM bulk_upsert_expenses(gen_random_uuid(), '[]'::jsonb);
  EXCEPTION WHEN SQLSTATE '42501' THEN ok := ok + 1; END;
  IF ok <> 6 THEN
    RAISE EXCEPTION 'guard probe failed: only % of 6 guards raised', ok;
  END IF;
  RAISE NOTICE 'guard probe: 6/6';
END $$;

DO $$
DECLARE
  v_prop uuid; v_user uuid; v_res jsonb; v_paddock uuid; v_lot uuid; v_exp int;
BEGIN
  SELECT pm.property_id, pm.user_id INTO v_prop, v_user
    FROM property_members pm
    JOIN properties p ON p.id = pm.property_id AND p.deleted_at IS NULL
   WHERE pm.role = 'veterinarian'::role_enum
   LIMIT 1;
  IF v_prop IS NULL THEN RAISE EXCEPTION 'no vet membership to probe with'; END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_res := bulk_upsert_paddocks(v_prop,
    '[{"name":"__probe_piquete","area_ha":10,"ua_capacity":12}]'::jsonb);
  IF v_res->>'created' <> '1' THEN RAISE EXCEPTION 'paddock create: %', v_res; END IF;
  SELECT id INTO v_paddock FROM paddocks
   WHERE property_id = v_prop AND name = '__probe_piquete';

  v_res := bulk_upsert_paddocks(v_prop, jsonb_build_array(jsonb_build_object(
    'id', v_paddock, 'name', '__probe_piquete2', 'area_ha', 11)));
  IF v_res->>'updated' <> '1' THEN RAISE EXCEPTION 'paddock update: %', v_res; END IF;
  IF (SELECT name FROM paddocks WHERE id = v_paddock) <> '__probe_piquete2' THEN
    RAISE EXCEPTION 'paddock rename failed';
  END IF;

  v_res := bulk_upsert_lots(v_prop,
    '[{"name":"__probe_lote","paddock_name":"__probe_piquete2"}]'::jsonb);
  IF v_res->>'created' <> '1' THEN RAISE EXCEPTION 'lot create: %', v_res; END IF;
  SELECT id INTO v_lot FROM lots WHERE property_id = v_prop AND name = '__probe_lote';

  v_res := bulk_upsert_lots(v_prop, jsonb_build_array(jsonb_build_object(
    'id', v_lot, 'name', '__probe_lote2')));
  IF (SELECT name FROM lots WHERE id = v_lot) <> '__probe_lote2' THEN
    RAISE EXCEPTION 'lot rename failed';
  END IF;

  BEGIN
    PERFORM bulk_upsert_lots(v_prop,
      '[{"name":"__probe_x","paddock_name":"__nao_existe"}]'::jsonb);
    RAISE EXCEPTION 'expected missing-paddock error';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'linha 1:%' THEN RAISE; END IF;
  END;

  v_res := bulk_upsert_expenses(v_prop,
    '[{"paddock_name":"__probe_piquete2","category":"manutencao","amount":123.45,"expense_date":"2026-08-21","description":"probe"}]'::jsonb);
  IF v_res->>'created' <> '1' THEN RAISE EXCEPTION 'expense create: %', v_res; END IF;
  SELECT count(*) INTO v_exp FROM expenses
   WHERE property_id = v_prop AND description = 'probe' AND amount = 123.45;
  IF v_exp <> 1 THEN RAISE EXCEPTION 'expense row missing'; END IF;

  RAISE NOTICE 'behavior probe: 6/6';
END $$;

ROLLBACK;
