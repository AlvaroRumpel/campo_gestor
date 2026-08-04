-- 05_reproductive_test.sql — pgTAP for Phase 5 (REPR-02 database invariants + D-19 baixa side effect).
-- Run via: supabase test db
--
-- Proves REPR-02's two business rules ("apenas vacas e novilhas", "no máximo 1 ATF ativo") hold at
-- the database boundary, not only through the app's UI. `supabase test db` runs as the postgres
-- superuser, which bypasses RLS (even FORCE ROW LEVEL SECURITY) — so these assertions exercise
-- trg_atf_membership_valid, trg_dg_records_same_property, the pre-existing partial unique index
-- animal_atf_memberships_active_idx, and trg_animals_baixa_deactivates_atf alone, which is exactly
-- the point: the invariants must hold with RLS out of the picture, since RLS's WITH CHECK never
-- inspects a referenced row's property_id (Phase 4's CR-01 / WR-02 bug class, reopened twice).
--
-- Authored + committed now; NOT executed in the planning/execution environment (local
-- Supabase/Docker down, project unlinked). Runs green after a human executes
-- `supabase db push` + `supabase test db` (plan 05-10).

BEGIN;

SELECT plan(9);

-- ---- Fixtures: two properties, one paddock + one lot in each, three animals in property A
--      (vaca, novilha, touro), one animal in property B (vaca), two atf_batches in property A
--      (so the "already in another active ATF" case is expressible) and one in property B.
--      Fixed UUIDs so ids can be referenced across the separate statements pgTAP's
--      throws_ok/lives_ok each run.
INSERT INTO properties (id, name) VALUES
  ('aaaaaaaa-1111-1111-1111-111111111111', 'REPR Test Property A'),
  ('bbbbbbbb-2222-2222-2222-222222222222', 'REPR Test Property B');

INSERT INTO paddocks (id, property_id, name, area_ha, ua_capacity) VALUES
  ('aaaaaaaa-3333-3333-3333-333333333333', 'aaaaaaaa-1111-1111-1111-111111111111', 'Paddock A', 10, 5),
  ('bbbbbbbb-4444-4444-4444-444444444444', 'bbbbbbbb-2222-2222-2222-222222222222', 'Paddock B', 10, 5);

INSERT INTO lots (id, property_id, paddock_id, name) VALUES
  ('aaaaaaaa-5555-5555-5555-555555555555', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-3333-3333-3333-333333333333', 'Lot A1'),
  ('bbbbbbbb-6666-6666-6666-666666666666', 'bbbbbbbb-2222-2222-2222-222222222222', 'bbbbbbbb-4444-4444-4444-444444444444', 'Lot B1');

INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('aaaaaaaa-7777-7777-7777-777777777771', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'vaca', 9001),
  ('aaaaaaaa-7777-7777-7777-777777777772', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'novilha', 9002),
  ('aaaaaaaa-7777-7777-7777-777777777773', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'touro', 9003),
  ('bbbbbbbb-7777-7777-7777-777777777771', 'bbbbbbbb-2222-2222-2222-222222222222', 'bbbbbbbb-6666-6666-6666-666666666666', 'vaca', 9004);

INSERT INTO atf_batches (id, property_id, name, implantation_date, insemination_date, bull_name) VALUES
  ('aaaaaaaa-9999-9999-9999-999999999991', 'aaaaaaaa-1111-1111-1111-111111111111', 'ATF A1', '2026-01-01', '2026-01-11', 'Bull A'),
  ('aaaaaaaa-9999-9999-9999-999999999992', 'aaaaaaaa-1111-1111-1111-111111111111', 'ATF A2', '2026-01-01', '2026-01-11', 'Bull A'),
  ('bbbbbbbb-9999-9999-9999-999999999991', 'bbbbbbbb-2222-2222-2222-222222222222', 'ATF B1', '2026-01-01', '2026-01-11', 'Bull B');

-- ---- Assertion 1: the Phase 2 skeleton was extended with property_id.
SELECT has_column('animal_atf_memberships', 'property_id',
  'animal_atf_memberships.property_id column added (Phase 5 activation)');

-- ---- Assertion 2: the Phase 2 partial unique index survives.
SELECT has_index('animal_atf_memberships', 'animal_atf_memberships_active_idx',
  'animal_atf_memberships_active_idx still exists (REPR-02 guarantee)');

-- ---- Assertion 3: touro category is rejected (D-09, REPR-02).
PREPARE touro_membership AS
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, property_id)
  VALUES ('aaaaaaaa-7777-7777-7777-777777777773', 'aaaaaaaa-9999-9999-9999-999999999991', 'aaaaaaaa-1111-1111-1111-111111111111');
SELECT throws_ok('EXECUTE touro_membership', '23514', NULL,
  'ATF membership for a touro is rejected by trg_atf_membership_valid (D-09, REPR-02)');

-- ---- Assertion 4: cross-property animal_id is rejected (D-21).
-- Property B's vaca against property A's ATF — animal.property_id differs from NEW.property_id.
PREPARE cross_property_membership AS
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, property_id)
  VALUES ('bbbbbbbb-7777-7777-7777-777777777771', 'aaaaaaaa-9999-9999-9999-999999999991', 'aaaaaaaa-1111-1111-1111-111111111111');
SELECT throws_ok('EXECUTE cross_property_membership', '23503', NULL,
  'cross-property ATF membership is rejected by trg_atf_membership_valid (D-21)');

-- ---- Assertion 5: happy path — property A's vaca into ATF A1.
PREPARE happy_path_membership AS
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, property_id)
  VALUES ('aaaaaaaa-7777-7777-7777-777777777771', 'aaaaaaaa-9999-9999-9999-999999999991', 'aaaaaaaa-1111-1111-1111-111111111111');
SELECT lives_ok('EXECUTE happy_path_membership',
  'ATF membership for an eligible vaca in its own property succeeds');

-- ---- Assertion 6: a second ACTIVE membership for the same vaca is rejected (partial unique index
--      regression — the assertion 02_property_paddock_test.sql already proved, must not break here).
PREPARE dup_active_membership AS
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, property_id)
  VALUES ('aaaaaaaa-7777-7777-7777-777777777771', 'aaaaaaaa-9999-9999-9999-999999999992', 'aaaaaaaa-1111-1111-1111-111111111111');
SELECT throws_ok('EXECUTE dup_active_membership', '23505', NULL,
  'a second active ATF membership for the same animal raises unique_violation (REPR-02)');

-- ---- Assertion 7: dg_records.result CHECK constraint (D-11, D-12, REPR-03).
PREPARE invalid_dg_result AS
  INSERT INTO dg_records (property_id, atf_batch_id, animal_id, result, exam_date)
  VALUES ('aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-9999-9999-9999-999999999991',
          'aaaaaaaa-7777-7777-7777-777777777771', 'unknown', CURRENT_DATE);
SELECT throws_ok('EXECUTE invalid_dg_result', '23514', NULL,
  'dg_records.result outside pregnant/not_pregnant/doubtful is rejected by dg_records_result_check');

-- ---- Assertion 8/9: baixa deactivates the active ATF membership in the same transaction (D-19).
PREPARE baixa_animal AS
  UPDATE animals SET deleted_at = now()
   WHERE id = 'aaaaaaaa-7777-7777-7777-777777777771';
SELECT lives_ok('EXECUTE baixa_animal',
  'soft-deleting an animal (baixa) succeeds');

SELECT is(
  (SELECT active FROM animal_atf_memberships
    WHERE animal_id = 'aaaaaaaa-7777-7777-7777-777777777771'
      AND atf_batch_id = 'aaaaaaaa-9999-9999-9999-999999999991'),
  false,
  'baixa deactivates the animal''s active ATF membership (D-19, trg_animals_baixa_deactivates_atf)'
);

SELECT * FROM finish();
ROLLBACK;
