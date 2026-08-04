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
--
-- Extended by plan 05-03 with assertions against the five SECURITY DEFINER RPCs
-- (add_animals_to_atf, remove_animal_from_atf, save_dg_records, close_atf, register_baixa) that
-- form the module's entire write surface, proving D-08 removal, D-16 closure, and the DG batch
-- validation rules are distinguishable by the database.

BEGIN;

SELECT plan(26);

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

-- ============================================================
-- Plan 05-03 additions: assertions against the five RPCs (add_animals_to_atf,
-- remove_animal_from_atf, save_dg_records, close_atf, register_baixa).
-- ============================================================

-- ---- Fixture: a veterinarian user + membership so the RPCs below can be called at all. Every one
-- of the five RPCs re-checks is_member_of()/get_role(), both of which read auth.uid(). `supabase
-- test db` runs as the postgres superuser with no JWT, so auth.uid() is NULL and every RPC call
-- would raise 42501 before reaching its business logic — this INSERT plus the set_config()
-- impersonation below are what let the D-08/D-16/22023/23503 assertions actually exercise the
-- function bodies. The 42501 guard itself is NOT asserted here (A-PGTAP-ROLE): supabase test db has
-- no JWT to impersonate an unauthorized caller with, so that path is covered by UAT instead of an
-- assertion the harness cannot honestly run.
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES (
  'cccccccc-8888-8888-8888-888888888888',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'repr-rpc-test@test.com',
  crypt('senha123C', gen_salt('bf')), now(), now(), now(),
  '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

INSERT INTO property_members (user_id, property_id, role) VALUES
  ('cccccccc-8888-8888-8888-888888888888', 'aaaaaaaa-1111-1111-1111-111111111111', 'veterinarian')
ON CONFLICT (user_id, property_id) DO NOTHING;

-- Transaction-local impersonation — persists for the remainder of this BEGIN...ROLLBACK block.
SELECT set_config('request.jwt.claim.sub', 'cccccccc-8888-8888-8888-888888888888', true);

-- ---- More animals in property A for the RPC assertions below. 774/775/776 join ATF A2 in the
--      setup step; 777 stays unattached — that absence is what the non-member assertion needs.
INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('aaaaaaaa-7777-7777-7777-777777777774', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'vaca', 9005),
  ('aaaaaaaa-7777-7777-7777-777777777775', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'vaca', 9006),
  ('aaaaaaaa-7777-7777-7777-777777777776', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'vaca', 9007),
  ('aaaaaaaa-7777-7777-7777-777777777777', 'aaaaaaaa-1111-1111-1111-111111111111', 'aaaaaaaa-5555-5555-5555-555555555555', 'vaca', 9008);

-- ---- The five RPCs exist.
SELECT has_function('add_animals_to_atf', 'add_animals_to_atf RPC exists');
SELECT has_function('remove_animal_from_atf', 'remove_animal_from_atf RPC exists');
SELECT has_function('save_dg_records', 'save_dg_records RPC exists');
SELECT has_function('close_atf', 'close_atf RPC exists');
SELECT has_function('register_baixa', 'register_baixa RPC exists');

-- ---- Setup: add three animals to ATF A2 via add_animals_to_atf (also proves its happy path).
PREPARE add_to_atf_a2 AS
  SELECT add_animals_to_atf(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    '["aaaaaaaa-7777-7777-7777-777777777774", "aaaaaaaa-7777-7777-7777-777777777775", "aaaaaaaa-7777-7777-7777-777777777776"]'::jsonb
  );
SELECT lives_ok('EXECUTE add_to_atf_a2',
  'add_animals_to_atf composes ATF A2 with three eligible animals');

-- ---- Setup: give animal 774 a DG record in ATF A2 via save_dg_records (also proves its happy path).
PREPARE save_initial_dg AS
  SELECT save_dg_records(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    '[{"animal_id": "aaaaaaaa-7777-7777-7777-777777777774", "result": "pregnant", "exam_date": "2026-02-01", "observation": null}]'::jsonb
  );
SELECT lives_ok('EXECUTE save_initial_dg',
  'save_dg_records records an initial DG for animal 774 in ATF A2');

-- ---- D-08: removing an animal that already has a DG in the ATF is rejected.
PREPARE remove_animal_with_dg AS
  SELECT remove_animal_from_atf(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    'aaaaaaaa-7777-7777-7777-777777777774'::uuid
  );
SELECT throws_ok('EXECUTE remove_animal_with_dg', '23514', NULL,
  'remove_animal_from_atf rejects an animal that already has a DG in the ATF (D-08)');

-- ---- Removing an animal with no DG succeeds and hard-deletes the membership row.
PREPARE remove_animal_no_dg AS
  SELECT remove_animal_from_atf(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    'aaaaaaaa-7777-7777-7777-777777777775'::uuid
  );
SELECT lives_ok('EXECUTE remove_animal_no_dg',
  'remove_animal_from_atf removes an animal with no DG record');

SELECT is(
  (SELECT count(*) FROM animal_atf_memberships
    WHERE animal_id = 'aaaaaaaa-7777-7777-7777-777777777775'
      AND atf_batch_id = 'aaaaaaaa-9999-9999-9999-999999999992'),
  0::bigint,
  'remove_animal_from_atf hard-deletes the membership row, not a soft deactivation'
);

-- ---- RESEARCH Pattern 3: save_dg_records rejects a record for an animal with no membership row
--      in the ATF. Animal 777 was never added to ATF A2.
PREPARE dg_non_member AS
  SELECT save_dg_records(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    '[{"animal_id": "aaaaaaaa-7777-7777-7777-777777777777", "result": "pregnant", "exam_date": "2026-02-01"}]'::jsonb
  );
SELECT throws_ok('EXECUTE dg_non_member', '23503', NULL,
  'save_dg_records rejects a record for an animal with no membership row in the ATF');

-- ---- save_dg_records rejects a result value outside the three allowed.
PREPARE dg_invalid_result AS
  SELECT save_dg_records(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    '[{"animal_id": "aaaaaaaa-7777-7777-7777-777777777776", "result": "unknown", "exam_date": "2026-02-01"}]'::jsonb
  );
SELECT throws_ok('EXECUTE dg_invalid_result', '22023', NULL,
  'save_dg_records rejects a result value outside pregnant/not_pregnant/doubtful');

-- ---- D-16: close_atf deactivates the batch and every remaining membership.
PREPARE close_atf_a2 AS
  SELECT close_atf('aaaaaaaa-9999-9999-9999-999999999992'::uuid);
SELECT lives_ok('EXECUTE close_atf_a2',
  'close_atf closes ATF A2');

SELECT is(
  (SELECT active FROM atf_batches WHERE id = 'aaaaaaaa-9999-9999-9999-999999999992'),
  false,
  'close_atf deactivates the atf_batches row'
);

SELECT is(
  (SELECT count(*) FROM animal_atf_memberships
    WHERE atf_batch_id = 'aaaaaaaa-9999-9999-9999-999999999992'
      AND active = true),
  0::bigint,
  'close_atf deactivates every remaining membership of the ATF (D-16)'
);

-- ---- D-16: a DG correction on an animal still in a now-CLOSED ATF still succeeds — the guarantee
--      that most directly distinguishes this design from a naive one.
PREPARE dg_after_close AS
  SELECT save_dg_records(
    'aaaaaaaa-9999-9999-9999-999999999992'::uuid,
    '[{"animal_id": "aaaaaaaa-7777-7777-7777-777777777774", "result": "not_pregnant", "exam_date": "2026-02-15", "observation": "correcao"}]'::jsonb
  );
SELECT lives_ok('EXECUTE dg_after_close',
  'save_dg_records still accepts a DG correction after close_atf (D-16 correcao de digitacao segue possivel)');

-- ---- Re-adding the animal removed above (775, hard-deleted, no active membership left) to a
--      different ATF succeeds — proving its slot in the partial unique index is free.
PREPARE readd_removed_animal AS
  SELECT add_animals_to_atf(
    'aaaaaaaa-9999-9999-9999-999999999991'::uuid,
    '["aaaaaaaa-7777-7777-7777-777777777775"]'::jsonb
  );
SELECT lives_ok('EXECUTE readd_removed_animal',
  'a previously-removed animal can be re-added to a different ATF (its active-membership slot was freed)');

SELECT * FROM finish();
ROLLBACK;
