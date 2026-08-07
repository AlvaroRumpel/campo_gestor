-- 06_sanitary_test.sql — pgTAP for Phase 6 (Sanitary Module Snapshot).
-- Run via: supabase test db (fallback: MCP execute_sql BEGIN/ROLLBACK replay, the
-- established path since Phase 3 — Supabase CLI unlinked / Docker unavailable).
--
-- Authored in Wave 0 (plan 06-01), BEFORE the migration that creates the objects this
-- suite asserts against (doses, animal_ua_weight, register_sanitary_application,
-- reverse_sanitary_application, sanitary_applications_reversal_idx,
-- sanitary_applications_composition_gin_idx, trg_sanitary_applications_same_property).
-- This suite is NOT executed by plan 06-01 — it cannot pass until 06-12 applies the
-- migration authored in 06-02. That is the intended Wave 0 red state (D-39/D-41).
--
-- Structure mirrors 05_reproductive_test.sql exactly: fixtures, set_config-based role
-- impersonation, BEGIN/ROLLBACK, PREPARE/EXECUTE + throws_ok/lives_ok assertion style.
--
-- has_index() calls below deliberately use the TWO-argument form only (table, index
-- name, no description) — the three-argument overload is ambiguous in this
-- Postgres/pgTAP combination and produced the single false failure recorded for
-- 05_reproductive_test.sql. The partial-index predicate and GIN operator class are
-- instead asserted by reading pg_indexes.indexdef with like().

BEGIN;

SELECT plan(74);

-- ============================================================
-- Fixtures: two properties, one veterinarian + one reader member per property, one
-- paddock + two lots in property A (lot_a2 exists so the GIN/SANI-05 test can move an
-- animal to a genuinely different lot), one paddock + one lot in property B, one dose
-- in property A, and animals split across three purposes: a registration set (vaca +
-- novilha + terneiro, known UA weights for the totals assertions), a concurrency set
-- (three more vacas, one of which gets soft-deleted mid-suite), and one animal in
-- property B (for the cross-property rejection assertion).
-- ============================================================

INSERT INTO properties (id, name) VALUES
  ('a0000000-0006-0006-0006-000000000001', 'SANI Test Property A'),
  ('b0000000-0006-0006-0006-000000000002', 'SANI Test Property B');

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
  ('c0000000-0006-0006-0006-0000000000a1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'sani-vet-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('c0000000-0006-0006-0006-0000000000a2', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'sani-reader-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('c0000000-0006-0006-0006-0000000000b1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'sani-vet-b@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('c0000000-0006-0006-0006-0000000000b2', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'sani-reader-b@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', '')
ON CONFLICT (id) DO NOTHING;

INSERT INTO property_members (user_id, property_id, role) VALUES
  ('c0000000-0006-0006-0006-0000000000a1', 'a0000000-0006-0006-0006-000000000001', 'veterinarian'),
  ('c0000000-0006-0006-0006-0000000000a2', 'a0000000-0006-0006-0006-000000000001', 'reader'),
  ('c0000000-0006-0006-0006-0000000000b1', 'b0000000-0006-0006-0006-000000000002', 'veterinarian'),
  ('c0000000-0006-0006-0006-0000000000b2', 'b0000000-0006-0006-0006-000000000002', 'reader')
ON CONFLICT (user_id, property_id) DO NOTHING;

INSERT INTO paddocks (id, property_id, name, area_ha, ua_capacity) VALUES
  ('a0000000-0006-0006-0006-000000000010', 'a0000000-0006-0006-0006-000000000001', 'Paddock A', 10, 20),
  ('b0000000-0006-0006-0006-000000000010', 'b0000000-0006-0006-0006-000000000002', 'Paddock B', 10, 20);

INSERT INTO lots (id, property_id, paddock_id, name) VALUES
  ('a0000000-0006-0006-0006-000000000020', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000010', 'Lot A1'),
  ('a0000000-0006-0006-0006-000000000021', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000010', 'Lot A2'),
  ('b0000000-0006-0006-0006-000000000020', 'b0000000-0006-0006-0006-000000000002', 'b0000000-0006-0006-0006-000000000010', 'Lot B1');

-- dosage_per_kg 1.0 mL/kg, cost_per_kg 10.0 R$/kg — with the default kg_per_ua 400
-- (D-12), dosage_per_ua = 400 mL/UA and cost_per_ua = 4000 R$/UA.
INSERT INTO doses (id, property_id, name, active_ingredient, dosage_per_kg, cost_per_kg) VALUES
  ('a0000000-0006-0006-0006-000000000030', 'a0000000-0006-0006-0006-000000000001', 'Dose A', 'Ivermectina', 1.0, 10.0);

-- Registration set — vaca (UA 1.0) + novilha (UA 0.75) + terneiro (UA 0.5) = 2.25 UA.
INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('a0000000-0006-0006-0006-000000000101', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020', 'vaca', 8001),
  ('a0000000-0006-0006-0006-000000000102', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020', 'novilha', 8002),
  ('a0000000-0006-0006-0006-000000000103', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020', 'terneiro', 8003);

-- Concurrency set — three more vacas in the same lot; 113 gets soft-deleted below to
-- prove the RPC aborts the whole transaction on a stale submitted id list (D-32).
INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('a0000000-0006-0006-0006-000000000111', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020', 'vaca', 8004),
  ('a0000000-0006-0006-0006-000000000112', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020', 'vaca', 8005),
  ('a0000000-0006-0006-0006-000000000113', 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020', 'vaca', 8006);

-- Property B animal — for the cross-property rejection assertion.
INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('b0000000-0006-0006-0006-000000000101', 'b0000000-0006-0006-0006-000000000002', 'b0000000-0006-0006-0006-000000000020', 'vaca', 8001);

-- ============================================================
-- Group 1 — Schema shape (SANI-01/02, D-11..D-15).
-- ============================================================

SELECT has_table('public', 'doses', 'doses table exists (SANI-01)');

SELECT has_column('doses', 'property_id', 'doses.property_id column exists');
SELECT has_column('doses', 'name', 'doses.name column exists');
SELECT has_column('doses', 'active_ingredient', 'doses.active_ingredient column exists');
SELECT has_column('doses', 'dosage_per_kg', 'doses.dosage_per_kg column exists');
SELECT has_column('doses', 'cost_per_kg', 'doses.cost_per_kg column exists');
SELECT has_column('doses', 'deleted_at', 'doses.deleted_at column exists');

SELECT has_column('properties', 'kg_per_ua', 'properties.kg_per_ua column exists (D-12)');

SELECT has_column('sanitary_applications', 'property_id', 'sanitary_applications.property_id column exists');
SELECT has_column('sanitary_applications', 'lot_id', 'sanitary_applications.lot_id column exists');
SELECT has_column('sanitary_applications', 'lot_name', 'sanitary_applications.lot_name column exists');
SELECT has_column('sanitary_applications', 'dose_id', 'sanitary_applications.dose_id column exists');
SELECT has_column('sanitary_applications', 'dose_name', 'sanitary_applications.dose_name column exists');
SELECT has_column('sanitary_applications', 'dosage_per_kg', 'sanitary_applications.dosage_per_kg column exists');
SELECT has_column('sanitary_applications', 'dosage_per_ua', 'sanitary_applications.dosage_per_ua column exists');
SELECT has_column('sanitary_applications', 'cost_per_kg', 'sanitary_applications.cost_per_kg column exists');
SELECT has_column('sanitary_applications', 'cost_per_ua', 'sanitary_applications.cost_per_ua column exists');
SELECT has_column('sanitary_applications', 'applied_at', 'sanitary_applications.applied_at column exists');
SELECT has_column('sanitary_applications', 'applied_by', 'sanitary_applications.applied_by column exists');
SELECT has_column('sanitary_applications', 'animal_count', 'sanitary_applications.animal_count column exists');
SELECT has_column('sanitary_applications', 'total_ua', 'sanitary_applications.total_ua column exists');
SELECT has_column('sanitary_applications', 'total_volume', 'sanitary_applications.total_volume column exists');
SELECT has_column('sanitary_applications', 'total_cost', 'sanitary_applications.total_cost column exists');
SELECT has_column('sanitary_applications', 'skipped_count', 'sanitary_applications.skipped_count column exists');
SELECT has_column('sanitary_applications', 'notes', 'sanitary_applications.notes column exists');
SELECT has_column('sanitary_applications', 'reverses_application_id', 'sanitary_applications.reverses_application_id column exists');

SELECT has_function('animal_ua_weight', 'animal_ua_weight helper function exists');
SELECT has_function('register_sanitary_application', 'register_sanitary_application RPC exists');
SELECT has_function('reverse_sanitary_application', 'reverse_sanitary_application RPC exists');

SELECT has_trigger('sanitary_applications', 'trg_sanitary_applications_same_property',
  'trg_sanitary_applications_same_property (D-10 isolation trigger) exists');

-- ============================================================
-- Group 2 — UA weight helper (Common Pitfalls #1). The assertion that catches drift
-- from lib/features/animais/data/animal_constants.dart's kUaWeights map.
-- ============================================================

SELECT is(animal_ua_weight('vaca'), 1.0::numeric, 'animal_ua_weight(vaca) = 1.0');
SELECT is(animal_ua_weight('novilha'), 0.75::numeric, 'animal_ua_weight(novilha) = 0.75');
SELECT is(animal_ua_weight('terneiro'), 0.5::numeric, 'animal_ua_weight(terneiro) = 0.5');
SELECT is(animal_ua_weight('touro'), 1.5::numeric, 'animal_ua_weight(touro) = 1.5');
SELECT is(animal_ua_weight('categoria-inexistente'), 0.0::numeric,
  'animal_ua_weight of an unrecognised category = 0.0 (no throw)');

-- ============================================================
-- Group 3 — Immutability (T-06-01). A standalone fixture row in Lot A2 (kept apart
-- from Lot A1/Dose A so it never collides with the totals-section queries below,
-- which filter on lot_id/dose_id + reverses_application_id IS NULL expecting exactly
-- one match).
-- ============================================================

INSERT INTO sanitary_applications (
  composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
  dosage_per_kg, dosage_per_ua, applied_at, applied_by, animal_count,
  total_ua, total_volume, notes
) VALUES (
  '[]'::jsonb, 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000021',
  'Lot A2', 'a0000000-0006-0006-0006-000000000030', 'Dose A',
  1.0, 400, current_date, 'c0000000-0006-0006-0006-0000000000a1', 1,
  1.0, 400, 'immutability fixture row'
);

PREPARE upd_notes AS
  UPDATE sanitary_applications SET notes = 'tampered' WHERE notes = 'immutability fixture row';
SELECT throws_ok('EXECUTE upd_notes', 'P0001', NULL,
  'UPDATE of a registered row''s notes is rejected by trg_snapshot_immutable regardless of access path (T-06-01)');

PREPARE del_fixture AS
  DELETE FROM sanitary_applications WHERE notes = 'immutability fixture row';
SELECT throws_ok('EXECUTE del_fixture', 'P0001', NULL,
  'DELETE of a registered row is rejected by trg_snapshot_immutable regardless of access path (T-06-01)');

-- ============================================================
-- Group 4 — Write surface. The RPC pair is the ONLY write path — proven by the table
-- carrying exactly one policy, and that policy being SELECT-only.
-- ============================================================

SELECT is(
  (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'sanitary_applications'),
  1::bigint,
  'sanitary_applications carries exactly one RLS policy — the RPC pair is the only write path'
);

SELECT is(
  (SELECT cmd FROM pg_policies WHERE schemaname = 'public' AND tablename = 'sanitary_applications'),
  'SELECT',
  'the single sanitary_applications policy is SELECT-only'
);

-- ============================================================
-- Group 5 — Indexes (D-31, D-38). Two-argument has_index() only — see file header.
-- Partial predicate + GIN operator class read from pg_indexes.indexdef instead of the
-- ambiguous three-argument has_index() overload.
-- ============================================================

SELECT has_index('sanitary_applications', 'sanitary_applications_reversal_idx');
SELECT has_index('sanitary_applications', 'sanitary_applications_composition_gin_idx');

SELECT like(
  (SELECT indexdef FROM pg_indexes WHERE indexname = 'sanitary_applications_reversal_idx'),
  '%WHERE (reverses_application_id IS NOT NULL)%',
  'sanitary_applications_reversal_idx is a partial index on reverses_application_id IS NOT NULL (D-31)'
);

SELECT like(
  (SELECT indexdef FROM pg_indexes WHERE indexname = 'sanitary_applications_composition_gin_idx'),
  '%jsonb_path_ops%',
  'sanitary_applications_composition_gin_idx uses the jsonb_path_ops operator class (D-38)'
);

-- ============================================================
-- Group 6 — Role and tenancy (T-06-04). Reader rejected, cross-property vet rejected,
-- correct property veterinarian succeeds — the same call this last assertion makes is
-- what Group 7 (totals) and Group 9 (reversal) below read back.
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'c0000000-0006-0006-0006-0000000000a2', true);
PREPARE reader_register AS
  SELECT register_sanitary_application(
    'a0000000-0006-0006-0006-000000000020'::uuid,
    'a0000000-0006-0006-0006-000000000030'::uuid,
    CURRENT_DATE,
    '["a0000000-0006-0006-0006-000000000101","a0000000-0006-0006-0006-000000000102","a0000000-0006-0006-0006-000000000103"]'::jsonb,
    NULL
  );
SELECT throws_ok('EXECUTE reader_register', '42501', NULL,
  'a reader-role member cannot register a sanitary application (T-06-04)');

SELECT set_config('request.jwt.claim.sub', 'c0000000-0006-0006-0006-0000000000b1', true);
PREPARE cross_property_register AS
  SELECT register_sanitary_application(
    'a0000000-0006-0006-0006-000000000020'::uuid,
    'a0000000-0006-0006-0006-000000000030'::uuid,
    CURRENT_DATE,
    '["a0000000-0006-0006-0006-000000000101","a0000000-0006-0006-0006-000000000102","a0000000-0006-0006-0006-000000000103"]'::jsonb,
    NULL
  );
SELECT throws_ok('EXECUTE cross_property_register', '42501', NULL,
  'a veterinarian of a different property cannot register against this property''s lot (T-06-04, is_member_of)'
);

SELECT set_config('request.jwt.claim.sub', 'c0000000-0006-0006-0006-0000000000a1', true);
PREPARE vet_a_register AS
  SELECT register_sanitary_application(
    'a0000000-0006-0006-0006-000000000020'::uuid,
    'a0000000-0006-0006-0006-000000000030'::uuid,
    CURRENT_DATE,
    '["a0000000-0006-0006-0006-000000000101","a0000000-0006-0006-0006-000000000102","a0000000-0006-0006-0006-000000000103"]'::jsonb,
    NULL
  );
SELECT lives_ok('EXECUTE vet_a_register',
  'the correct property veterinarian registers a sanitary application successfully'
);

-- ============================================================
-- Group 7 — Server-authoritative totals (T-06-02). Reads back the row Group 6's
-- vet_a_register call just froze; every column asserted here is derived from the
-- fixtures, never from a client-submitted total.
-- ============================================================

SELECT is(
  (SELECT total_ua FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  2.25::numeric, 'total_ua = 1.0 (vaca) + 0.75 (novilha) + 0.5 (terneiro)'
);
SELECT is(
  (SELECT total_volume FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  900::numeric, 'total_volume = total_ua(2.25) * kg_per_ua(400) * dosage_per_kg(1.0)'
);
SELECT is(
  (SELECT total_cost FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  9000::numeric, 'total_cost = total_ua(2.25) * kg_per_ua(400) * cost_per_kg(10.0)'
);
SELECT is(
  (SELECT dosage_per_ua FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  400::numeric, 'dosage_per_ua = dosage_per_kg(1.0) * kg_per_ua(400)'
);
SELECT is(
  (SELECT cost_per_ua FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  4000::numeric, 'cost_per_ua = cost_per_kg(10.0) * kg_per_ua(400)'
);
SELECT is(
  (SELECT animal_count FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  3, 'animal_count = 3 selected animals'
);
SELECT is(
  (SELECT skipped_count FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  3, 'skipped_count = 6 active animals in the lot at call time minus 3 selected'
);
SELECT is(
  (SELECT lot_name FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  'Lot A1', 'lot_name is frozen from the lot at registration time'
);
SELECT is(
  (SELECT dose_name FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  'Dose A', 'dose_name is frozen from the dose at registration time'
);
SELECT is(
  (SELECT applied_by FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  'c0000000-0006-0006-0006-0000000000a1'::uuid,
  'applied_by is server-derived from auth.uid(), proving repudiation cannot occur (T-06-08)'
);

-- ============================================================
-- Group 8 — Concurrency abort (D-32, Common Pitfalls #2). One of the three submitted
-- animals is soft-deleted between "load" and "confirm" (simulated here by mutating the
-- animal, then calling the RPC with the original id list) — the whole transaction must
-- abort, never partially write.
-- ============================================================

PREPARE soft_delete_conc_animal AS
  UPDATE animals SET deleted_at = now() WHERE id = 'a0000000-0006-0006-0006-000000000113';
SELECT lives_ok('EXECUTE soft_delete_conc_animal',
  'soft-deleting one of the three concurrency-set animals succeeds (simulates a concurrent baixa)'
);

PREPARE stale_composition_register AS
  SELECT register_sanitary_application(
    'a0000000-0006-0006-0006-000000000020'::uuid,
    'a0000000-0006-0006-0006-000000000030'::uuid,
    CURRENT_DATE,
    '["a0000000-0006-0006-0006-000000000111","a0000000-0006-0006-0006-000000000112","a0000000-0006-0006-0006-000000000113"]'::jsonb,
    NULL
  );
SELECT throws_ok('EXECUTE stale_composition_register', 'P0002', NULL,
  'registering with the original (now-stale) animal id list aborts the whole transaction (D-32)'
);

SELECT is(
  (SELECT count(*) FROM sanitary_applications),
  2::bigint,
  'sanitary_applications row count is unchanged after the aborted attempt — the immutability '
  || 'fixture row plus the earlier successful registration, proving no partial write occurred'
);

-- ============================================================
-- Group 9 — Reversal (D-27..D-31, D-30 role gate). Reverses the application Group 6/7
-- froze, then exercises every rejection path: double reversal, reversal-of-a-reversal,
-- blank reason, and a direct INSERT bypassing the RPC.
-- ============================================================

PREPARE reverse_original AS
  SELECT reverse_sanitary_application(
    (SELECT id FROM sanitary_applications
      WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
        AND reverses_application_id IS NULL),
    'Estorno de teste'
  );
SELECT lives_ok('EXECUTE reverse_original',
  'reversing the registered application succeeds'
);

SELECT is(
  (SELECT count(*) FROM sanitary_applications
    WHERE reverses_application_id = (
      SELECT id FROM sanitary_applications
        WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
          AND reverses_application_id IS NULL
    )),
  1::bigint,
  'exactly one reversal row exists for the original application'
);

PREPARE reverse_again AS
  SELECT reverse_sanitary_application(
    (SELECT id FROM sanitary_applications
      WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
        AND reverses_application_id IS NULL),
    'Motivo diferente'
  );
SELECT throws_ok('EXECUTE reverse_again', 'P0003', NULL,
  'a second reversal of the same application raises P0003 (D-31 pre-check)'
);

PREPARE reverse_the_reversal AS
  SELECT reverse_sanitary_application(
    (SELECT id FROM sanitary_applications
      WHERE reverses_application_id = (
        SELECT id FROM sanitary_applications
          WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
            AND reverses_application_id IS NULL
      )),
    'Tentando estornar o estorno'
  );
SELECT throws_ok('EXECUTE reverse_the_reversal', '23514', NULL,
  'reversing a reversal row itself raises 23514 (D-30)'
);

PREPARE reverse_blank_reason AS
  SELECT reverse_sanitary_application(
    (SELECT id FROM sanitary_applications
      WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
        AND reverses_application_id IS NULL),
    ''
  );
SELECT throws_ok('EXECUTE reverse_blank_reason', '22023', NULL,
  'a blank reversal reason raises 22023'
);

PREPARE dup_reversal_insert AS
  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, applied_at, applied_by, animal_count,
    total_ua, total_volume, reverses_application_id
  ) VALUES (
    '[]'::jsonb, 'a0000000-0006-0006-0006-000000000001', 'a0000000-0006-0006-0006-000000000020',
    'Lot A1', 'a0000000-0006-0006-0006-000000000030', 'Dose A',
    1.0, 400, current_date, 'c0000000-0006-0006-0006-0000000000a1', -1,
    -2.25, -900,
    (SELECT id FROM sanitary_applications
      WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
        AND reverses_application_id IS NULL)
  );
SELECT throws_ok('EXECUTE dup_reversal_insert', '23505', NULL,
  'a direct INSERT bypassing the RPC with a duplicate reverses_application_id raises 23505 from the unique index (D-31)'
);

-- ============================================================
-- Group 10 — Reversal zero-sum (locked convention, 06-VALIDATION.md). The reversal row
-- negates all four numeric header totals uniformly; composition_snapshot itself is not
-- negated; applied_at is the reversal's own date, not the original's.
-- ============================================================

SELECT is(
  (SELECT sum(animal_count) FROM sanitary_applications
    WHERE id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)
       OR reverses_application_id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)),
  0::bigint, 'SUM(animal_count) over the original and its reversal is 0'
);
SELECT is(
  (SELECT sum(total_ua) FROM sanitary_applications
    WHERE id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)
       OR reverses_application_id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)),
  0::numeric, 'SUM(total_ua) over the original and its reversal is 0'
);
SELECT is(
  (SELECT sum(total_volume) FROM sanitary_applications
    WHERE id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)
       OR reverses_application_id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)),
  0::numeric, 'SUM(total_volume) over the original and its reversal is 0'
);
SELECT is(
  (SELECT sum(total_cost) FROM sanitary_applications
    WHERE id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)
       OR reverses_application_id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)),
  0::numeric, 'SUM(total_cost) over the original and its reversal is 0'
);
SELECT is(
  (SELECT applied_at FROM sanitary_applications
    WHERE reverses_application_id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)),
  CURRENT_DATE,
  'the reversal row''s applied_at is CURRENT_DATE, not the original''s applied_at (locked convention)'
);
SELECT is(
  (SELECT jsonb_array_length(composition_snapshot) FROM sanitary_applications
    WHERE reverses_application_id = (SELECT id FROM sanitary_applications
                  WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
                    AND reverses_application_id IS NULL)),
  (SELECT jsonb_array_length(composition_snapshot) FROM sanitary_applications
    WHERE lot_id = 'a0000000-0006-0006-0006-000000000020' AND dose_id = 'a0000000-0006-0006-0006-000000000030'
      AND reverses_application_id IS NULL),
  'the reversal row''s composition_snapshot array length equals the original''s (not negated)'
);

-- ============================================================
-- Group 11 — GIN containment (SANI-05, D-38). Move one applied animal to a different
-- lot; the containment lookup must still find the original application, and its
-- lot_name must stay the frozen name, not the animal's new lot.
-- ============================================================

PREPARE move_applied_animal AS
  UPDATE animals SET lot_id = 'a0000000-0006-0006-0006-000000000021'
    WHERE id = 'a0000000-0006-0006-0006-000000000101';
SELECT lives_ok('EXECUTE move_applied_animal',
  'the applied animal can be moved to a different lot after the application was frozen'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM sanitary_applications
     WHERE composition_snapshot @> jsonb_build_array(jsonb_build_object('animal_id', 'a0000000-0006-0006-0006-000000000101'))
       AND reverses_application_id IS NULL
  ),
  'GIN containment lookup on composition_snapshot still finds the original application for an animal that has since moved lots (SANI-05, D-38)'
);

SELECT is(
  (SELECT lot_name FROM sanitary_applications
     WHERE composition_snapshot @> jsonb_build_array(jsonb_build_object('animal_id', 'a0000000-0006-0006-0006-000000000101'))
       AND reverses_application_id IS NULL),
  'Lot A1',
  'the containment-matched application keeps the frozen lot_name, not the animal''s new lot (D-38)'
);

SELECT * FROM finish();
ROLLBACK;
