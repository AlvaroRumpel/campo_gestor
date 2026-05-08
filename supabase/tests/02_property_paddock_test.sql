-- 02_property_paddock_test.sql — pgTAP for Phase 2.
-- Run via: supabase test db
--
-- Concurrency proof for generate_animal_number (D-20) is run separately via pgbench:
--   echo "SELECT generate_animal_number('<property_id>', 'cow');" > /tmp/g.sql
--   pgbench -c 10 -j 10 -t 5 -n -f /tmp/g.sql "$DB_URL"
-- Expected: zero duplicate numbers in animals after 50 inserts using the RPC.

BEGIN;

SELECT plan(11);

-- ---- Schema existence ----
SELECT has_table('public', 'paddocks', 'paddocks table exists');
SELECT has_table('public', 'animals', 'animals skeleton exists');
SELECT has_table('public', 'animal_atf_memberships', 'animal_atf_memberships skeleton exists');
SELECT has_table('public', 'sanitary_applications', 'sanitary_applications skeleton exists');

SELECT has_column('public', 'properties', 'owner',
  'properties.owner column added');
SELECT has_column('public', 'properties', 'deleted_at',
  'properties.deleted_at column added');

-- ---- Backend prototypes ----
SELECT has_function('public', 'get_role', ARRAY['uuid'],
  'get_role(uuid) helper function exists');
SELECT has_function('public', 'generate_animal_number', ARRAY['uuid','text'],
  'generate_animal_number RPC exists');

-- ATF partial unique index — duplicate active=true raises 23505.
WITH animal AS (
  SELECT gen_random_uuid() AS id
), batch AS (
  SELECT gen_random_uuid() AS id
)
INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, active)
SELECT animal.id, batch.id, true FROM animal, batch;

PREPARE dup_atf AS
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, active)
  SELECT animal_id, gen_random_uuid(), true
  FROM animal_atf_memberships LIMIT 1;
SELECT throws_ok('EXECUTE dup_atf', '23505',
  NULL,
  'duplicate active ATF for same animal raises unique_violation (D-22)');

-- composition_snapshot trigger blocks UPDATE.
INSERT INTO sanitary_applications (composition_snapshot)
  VALUES ('{"animals": []}'::jsonb);
PREPARE upd_snap AS
  UPDATE sanitary_applications SET composition_snapshot = '{"animals":[1]}'::jsonb;
SELECT throws_ok('EXECUTE upd_snap', 'P0001',
  NULL,
  'composition_snapshot UPDATE is blocked by trigger (D-21)');

-- composition_snapshot trigger blocks DELETE.
PREPARE del_snap AS DELETE FROM sanitary_applications;
SELECT throws_ok('EXECUTE del_snap', 'P0001',
  NULL,
  'composition_snapshot DELETE is blocked by trigger (D-21)');

SELECT * FROM finish();
ROLLBACK;
