-- 04_movements_test.sql — pgTAP for Phase 4 gap closure #2 (SC-4).
-- Run via: supabase test db
--
-- Proves ROADMAP Phase 4 Success Criterion 4: a cross-property animal move
-- is rejected regardless of access path. `supabase test db` runs as the
-- postgres superuser, which bypasses RLS (even FORCE ROW LEVEL SECURITY) —
-- so these three assertions exercise trg_animals_lot_same_property alone,
-- which is exactly the point: the invariant must hold with RLS out of the
-- picture, since RLS's WITH CHECK never inspects lot_id (04-REVIEW.md CR-01).
--
-- Authored + committed now; NOT executed in the planning/execution
-- environment (local Supabase/Docker down, project unlinked). Runs green
-- after a human executes `supabase db push` + `supabase test db` (04-06 Task 3).

BEGIN;

SELECT plan(3);

-- ---- Fixtures: two properties, one paddock each, two lots in A + one in B,
--      one animal in lot A1. Fixed UUIDs so ids can be referenced across
--      the separate statements pgTAP's throws_ok/lives_ok each run.
INSERT INTO properties (id, name) VALUES
  ('11111111-1111-1111-1111-111111111111', 'SC-4 Test Property A'),
  ('22222222-2222-2222-2222-222222222222', 'SC-4 Test Property B');

INSERT INTO paddocks (id, property_id, name, area_ha, ua_capacity) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Paddock A', 10, 5),
  ('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'Paddock B', 10, 5);

INSERT INTO lots (id, property_id, paddock_id, name) VALUES
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Lot A1'),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Lot A2'),
  ('77777777-7777-7777-7777-777777777777', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', 'Lot B1');

INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('88888888-8888-8888-8888-888888888888', '11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 'vaca', 9001);

-- ---- Assertion 1: cross-property lot_id UPDATE is rejected (SC-4).
PREPARE cross_property_move AS
  UPDATE animals SET lot_id = '77777777-7777-7777-7777-777777777777'
   WHERE id = '88888888-8888-8888-8888-888888888888';
SELECT throws_ok('EXECUTE cross_property_move', '23503', NULL,
  'cross-property lot_id UPDATE is rejected by trg_animals_lot_same_property (SC-4)');

-- ---- Assertion 2: same-property lot_id UPDATE succeeds.
PREPARE same_property_move AS
  UPDATE animals SET lot_id = '66666666-6666-6666-6666-666666666666'
   WHERE id = '88888888-8888-8888-8888-888888888888';
SELECT lives_ok('EXECUTE same_property_move',
  'same-property lot_id UPDATE succeeds');

-- ---- Assertion 3: NULL lot_id INSERT is allowed (unassigned animal — guard skips).
PREPARE null_lot_insert AS
  INSERT INTO animals (property_id, category, number)
  VALUES ('11111111-1111-1111-1111-111111111111', 'vaca', 9002);
SELECT lives_ok('EXECUTE null_lot_insert',
  'INSERT with NULL lot_id is allowed (trigger guard skips unassigned animals)');

SELECT * FROM finish();
ROLLBACK;
