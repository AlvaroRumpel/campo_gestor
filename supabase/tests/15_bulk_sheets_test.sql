-- 15_bulk_sheets_test.sql — pgTAP para as RPCs bulk da feature Planilhas
-- (bulk_upsert_doses, bulk_upsert_animals, bulk_register_sanitary — migration
-- 20260820_15_bulk_sheets.sql).
--
-- Formato "SQL editor": o Studio só exibe o último result set, então cada
-- assert pgTAP é acumulado numa temp table e devolvido de uma vez no SELECT
-- final — as 15 linhas ok/not ok aparecem juntas. BEGIN/ROLLBACK: nada
-- persiste. (Projeto sem Docker — supabase test db não roda aqui.)


BEGIN;



CREATE TEMP TABLE _r (n serial, line text) ON COMMIT DROP;

INSERT INTO _r (line) SELECT plan(15);

-- ============================================================
-- Fixtures: propriedade A (vet + reader), propriedade B (vet), paddock + lote
-- em A, um animal pré-existente em A (nº 500 será criado pela própria RPC).
-- ============================================================

INSERT INTO properties (id, name) VALUES
  ('a0000000-0015-0015-0015-000000000001', 'BULK Test Property A'),
  ('b0000000-0015-0015-0015-000000000002', 'BULK Test Property B');

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
  ('c0000000-0015-0015-0015-0000000000a1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bulk-vet-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('c0000000-0015-0015-0015-0000000000a2', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bulk-reader-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', '')
ON CONFLICT (id) DO NOTHING;

INSERT INTO property_members (user_id, property_id, role) VALUES
  ('c0000000-0015-0015-0015-0000000000a1', 'a0000000-0015-0015-0015-000000000001', 'veterinarian'),
  ('c0000000-0015-0015-0015-0000000000a2', 'a0000000-0015-0015-0015-000000000001', 'reader')
ON CONFLICT (user_id, property_id) DO NOTHING;

INSERT INTO paddocks (id, property_id, name, area_ha, ua_capacity) VALUES
  ('a0000000-0015-0015-0015-000000000010', 'a0000000-0015-0015-0015-000000000001', 'Paddock A', 10, 20);

INSERT INTO lots (id, property_id, paddock_id, name) VALUES
  ('a0000000-0015-0015-0015-000000000020', 'a0000000-0015-0015-0015-000000000001', 'a0000000-0015-0015-0015-000000000010', 'Lote A1');

INSERT INTO _r (line)
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

INSERT INTO _r (line)
SELECT set_config('request.jwt.claim.sub', 'c0000000-0015-0015-0015-0000000000a1', true);

-- ============================================================
-- Group 1 — bulk_upsert_doses
-- ============================================================

SELECT lives_ok(
  $$SELECT bulk_upsert_doses('a0000000-0015-0015-0015-000000000001',
    '[{"name":"Ivermectina","active_ingredient":"ivermectina","dosage_per_kg":0.02,"cost_per_kg":0.5}]'::jsonb)$$,
  'doses: insert ok');

INSERT INTO _r (line)
SELECT is(
  (SELECT count(*) FROM doses
    WHERE property_id = 'a0000000-0015-0015-0015-000000000001'
      AND lower(name) = 'ivermectina' AND deleted_at IS NULL),
  1::bigint, 'doses: 1 row created');

INSERT INTO _r (line)
SELECT is(
  (bulk_upsert_doses('a0000000-0015-0015-0015-000000000001',
    '[{"name":"ivermectina","dosage_per_kg":0.03}]'::jsonb))->>'updated',
  '1', 'doses: same name (case-insensitive) updates');

INSERT INTO _r (line)
SELECT is(
  (SELECT dosage_per_kg FROM doses
    WHERE property_id = 'a0000000-0015-0015-0015-000000000001'
      AND lower(name) = 'ivermectina' AND deleted_at IS NULL),
  0.03::numeric, 'doses: dosage updated in place');

-- ============================================================
-- Group 2 — bulk_upsert_animals
-- ============================================================

SELECT is(
  (bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
    '[{"number":500,"category":"vaca","breed":"Nelore","lot_name":"Lote A1"},
      {"number":null,"category":"novilha","lot_name":"Lote A1"}]'::jsonb))->>'created',
  '2', 'animals: 2 created (one with generated number)');

INSERT INTO _r (line)
SELECT is(
  (SELECT count(*) FROM animals
    WHERE property_id = 'a0000000-0015-0015-0015-000000000001' AND deleted_at IS NULL),
  2::bigint, 'animals: rows exist');

INSERT INTO _r (line)
SELECT is(
  (bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
    '[{"number":500,"category":"vaca","body_condition":4,"lot_name":"Lote A1"}]'::jsonb))->>'updated',
  '1', 'animals: existing number updates');

INSERT INTO _r (line)
SELECT is(
  (SELECT body_condition FROM animals
    WHERE number = 500 AND property_id = 'a0000000-0015-0015-0015-000000000001'
      AND deleted_at IS NULL),
  4, 'animals: ecc updated');

INSERT INTO _r (line)
SELECT throws_ok(
  $$SELECT bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
    '[{"number":701,"category":"vaca","lot_name":"Lote A1"},
      {"number":702,"category":"vaca","lot_name":"Nao Existe"}]'::jsonb)$$,
  'P0001', 'linha 2: lote "Nao Existe" não encontrado',
  'animals: unknown lot raises with line number');

INSERT INTO _r (line)
SELECT is(
  -- 701, não 501: o animal de número gerado do teste 5 vira exatamente 501
  -- (max 500 + 1) — 501 aqui colidia com ele e dava falso negativo.
  (SELECT count(*) FROM animals
    WHERE number = 701 AND property_id = 'a0000000-0015-0015-0015-000000000001'),
  0::bigint, 'animals: whole batch rolled back on error');

INSERT INTO _r (line)
SELECT throws_ok(
  $$SELECT bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
    '[{"number":503,"category":"bezerro","lot_name":"Lote A1"}]'::jsonb)$$,
  'P0001', 'linha 1: categoria "bezerro" inválida',
  'animals: bad category raises');

-- ============================================================
-- Group 3 — bulk_register_sanitary (agrupa por data → 2 aplicações)
-- ============================================================

SELECT is(
  (bulk_register_sanitary('a0000000-0015-0015-0015-000000000001',
    '[{"animal_number":500,"dose_name":"Ivermectina","applied_at":"2026-08-01"},
      {"animal_number":500,"dose_name":"Ivermectina","applied_at":"2026-08-02"}]'::jsonb))->>'applications',
  '2', 'sanitary: distinct dates yield 2 applications');

INSERT INTO _r (line)
SELECT is(
  (SELECT count(*) FROM sanitary_applications
    WHERE property_id = 'a0000000-0015-0015-0015-000000000001'),
  2::bigint, 'sanitary: snapshots persisted');

-- ============================================================
-- Group 4 — permissões: reader não escreve (42501 vem de assert_vet_of)
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'c0000000-0015-0015-0015-0000000000a2', true);

INSERT INTO _r (line)
SELECT throws_ok(
  $$SELECT bulk_upsert_doses('a0000000-0015-0015-0015-000000000001',
    '[{"name":"X","dosage_per_kg":1}]'::jsonb)$$,
  '42501', NULL, 'doses: reader forbidden');

INSERT INTO _r (line)
SELECT throws_ok(
  $$SELECT bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
    '[{"number":600,"category":"vaca","lot_name":"Lote A1"}]'::jsonb)$$,
  '42501', NULL, 'animals: reader forbidden');

INSERT INTO _r (line) SELECT * FROM finish();



-- Resultado completo (todas as linhas ok/not ok):

SELECT line FROM _r ORDER BY n;



ROLLBACK;
