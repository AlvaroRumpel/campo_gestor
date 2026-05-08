-- 02_property_paddock_test.sql — pgTAP for Phase 2.
-- Run via: supabase test db
--
-- Concurrency proof for gerar_numero_animal (D-20) is run separately via pgbench:
--   echo "SELECT gerar_numero_animal('<propriedade_id>', 'vaca');" > /tmp/g.sql
--   pgbench -c 10 -j 10 -t 5 -n -f /tmp/g.sql "$DB_URL"
-- Expected: zero duplicate numbers in animais after 50 inserts using the RPC.

BEGIN;

SELECT plan(11);

-- ---- Schema existence ----
SELECT has_table('public', 'piquetes', 'piquetes table exists');
SELECT has_table('public', 'animais', 'animais skeleton exists');
SELECT has_table('public', 'animais_lote_atf', 'animais_lote_atf skeleton exists');
SELECT has_table('public', 'aplicacoes_sanitarias', 'aplicacoes_sanitarias skeleton exists');

SELECT has_column('public', 'propriedades', 'proprietario',
  'propriedades.proprietario column added');
SELECT has_column('public', 'propriedades', 'deleted_at',
  'propriedades.deleted_at column added');

-- ---- Backend prototypes ----
SELECT has_function('public', 'get_perfil', ARRAY['uuid'],
  'get_perfil(uuid) helper function exists');
SELECT has_function('public', 'gerar_numero_animal', ARRAY['uuid','text'],
  'gerar_numero_animal RPC exists');

-- ATF partial unique index — duplicate ativo=true raises 23505.
WITH animal AS (
  SELECT gen_random_uuid() AS id
), lote AS (
  SELECT gen_random_uuid() AS id
)
INSERT INTO animais_lote_atf (animal_id, lote_atf_id, ativo)
SELECT animal.id, lote.id, true FROM animal, lote;

PREPARE dup_atf AS
  INSERT INTO animais_lote_atf (animal_id, lote_atf_id, ativo)
  SELECT animal_id, gen_random_uuid(), true
  FROM animais_lote_atf LIMIT 1;
SELECT throws_ok('EXECUTE dup_atf', '23505',
  NULL,
  'duplicate active ATF for same animal raises unique_violation (D-22)');

-- composicao_snapshot trigger blocks UPDATE.
INSERT INTO aplicacoes_sanitarias (composicao_snapshot)
  VALUES ('{"animais": []}'::jsonb);
PREPARE upd_snap AS
  UPDATE aplicacoes_sanitarias SET composicao_snapshot = '{"animais":[1]}'::jsonb;
SELECT throws_ok('EXECUTE upd_snap', 'P0001',
  NULL,
  'composicao_snapshot UPDATE is blocked by trigger (D-21)');

-- composicao_snapshot trigger blocks DELETE.
PREPARE del_snap AS DELETE FROM aplicacoes_sanitarias;
SELECT throws_ok('EXECUTE del_snap', 'P0001',
  NULL,
  'composicao_snapshot DELETE is blocked by trigger (D-21)');

SELECT * FROM finish();
ROLLBACK;
