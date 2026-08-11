-- 07_expenses_test.sql — pgTAP for Phase 7 (Expenses by Paddock).
-- Run via: supabase test db (fallback: MCP execute_sql BEGIN/ROLLBACK replay, the
-- established path since Phase 3 — Supabase CLI unlinked / Docker unavailable, see
-- 07-01-PLAN.md environment_constraint).
--
-- Authored against a NOT-YET-APPLIED schema (deliberate red state, same D-39/D-41
-- precedent as 06_sanitary_test.sql) — this suite cannot pass until 07-08 applies
-- 20260813_07_expenses_module.sql.
--
-- Role-impersonation technique for Groups 4-7: unlike the RPC-internal 42501 checks in
-- 05_reproductive_test.sql/06_sanitary_test.sql (which only need
-- set_config('request.jwt.claim.sub', ...) because the 42501 is a manual RAISE EXCEPTION
-- inside a SECURITY DEFINER function body, not RLS itself), `expenses` is direct-table
-- CRUD (D-25) — its write gate is enforced by actual Postgres RLS policies. `supabase
-- test db` connects as the `postgres` superuser, which bypasses RLS unconditionally
-- (even FORCE ROW LEVEL SECURITY, per 04_movements_test.sql's header) — so a bare
-- set_config() alone would NOT exercise the RLS write gate: the INSERT/UPDATE would
-- simply succeed regardless of role. `SET ROLE authenticated;` is added (Supabase's own
-- documented pgTAP RLS-testing pattern) so the RLS policies' `TO authenticated` clause
-- actually applies for the remainder of this transaction; `SET ROLE`/`RESET ROLE`
-- effects are transaction-scoped and vanish at the trailing ROLLBACK regardless.
-- Group 3 (the isolation trigger) is deliberately run BEFORE the `SET ROLE authenticated`
-- switch, "with RLS out of the picture" per 07-01-PLAN.md Task 3 — proving the trigger
-- alone closes the raw-PATCH bypass, independent of RLS.
--
-- has_index() uses the TWO-argument form only — the three-argument overload is
-- ambiguous in this Postgres/pgTAP combination (05_reproductive_test.sql's single false
-- failure).
--
-- Every count(*) assertion below is scoped to fixture ids/property_id, never global
-- table state (06_sanitary_test.sql's Group 8 lesson — the only assertion there that
-- fails on PROD is the one scoped to global state).

BEGIN;

SELECT plan(42);

-- ============================================================
-- Fixtures: two properties, three members in property A (owner/veterinarian/reader,
-- D-23/D-24) plus one veterinarian in property B (cross-property + non-member read
-- assertions), one paddock per property, one lot + one dose + one animal in property A
-- for the Group 8 register_sanitary_application call.
-- ============================================================

INSERT INTO properties (id, name) VALUES
  ('70000000-0007-0007-0007-000000000001', 'GAST Test Property A'),
  ('70000000-0007-0007-0007-000000000002', 'GAST Test Property B');

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
  ('71000000-0007-0007-0007-0000000000a1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'gast-owner-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('71000000-0007-0007-0007-0000000000a2', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'gast-vet-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('71000000-0007-0007-0007-0000000000a3', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'gast-reader-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('71000000-0007-0007-0007-0000000000b1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'gast-vet-b@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', '')
ON CONFLICT (id) DO NOTHING;

INSERT INTO property_members (user_id, property_id, role) VALUES
  ('71000000-0007-0007-0007-0000000000a1', '70000000-0007-0007-0007-000000000001', 'owner'),
  ('71000000-0007-0007-0007-0000000000a2', '70000000-0007-0007-0007-000000000001', 'veterinarian'),
  ('71000000-0007-0007-0007-0000000000a3', '70000000-0007-0007-0007-000000000001', 'reader'),
  ('71000000-0007-0007-0007-0000000000b1', '70000000-0007-0007-0007-000000000002', 'veterinarian')
ON CONFLICT (user_id, property_id) DO NOTHING;

INSERT INTO paddocks (id, property_id, name, area_ha, ua_capacity) VALUES
  ('72000000-0007-0007-0007-000000000001', '70000000-0007-0007-0007-000000000001', 'Paddock GAST A', 10, 20),
  ('72000000-0007-0007-0007-000000000002', '70000000-0007-0007-0007-000000000002', 'Paddock GAST B', 10, 20);

INSERT INTO lots (id, property_id, paddock_id, name) VALUES
  ('73000000-0007-0007-0007-000000000001', '70000000-0007-0007-0007-000000000001', '72000000-0007-0007-0007-000000000001', 'Lot GAST A1');

INSERT INTO doses (id, property_id, name, active_ingredient, dosage_per_kg, cost_per_kg) VALUES
  ('74000000-0007-0007-0007-000000000001', '70000000-0007-0007-0007-000000000001', 'Dose GAST A', 'Ivermectina', 1.0, 10.0);

INSERT INTO animals (id, property_id, lot_id, category, number) VALUES
  ('75000000-0007-0007-0007-000000000001', '70000000-0007-0007-0007-000000000001', '73000000-0007-0007-0007-000000000001', 'vaca', 9101);

-- ============================================================
-- Group 1 — Structure (GAST-01, D-03, D-04, D-20, D-34).
-- ============================================================

SELECT has_table('public', 'expenses', 'expenses table exists (GAST-01)');

SELECT col_not_null('expenses', 'property_id', 'expenses.property_id is NOT NULL');
SELECT col_not_null('expenses', 'paddock_id', 'expenses.paddock_id is NOT NULL (D-34)');
SELECT col_not_null('expenses', 'category', 'expenses.category is NOT NULL');
SELECT col_not_null('expenses', 'amount', 'expenses.amount is NOT NULL');
SELECT col_not_null('expenses', 'expense_date', 'expenses.expense_date is NOT NULL');
SELECT col_not_null('expenses', 'created_by', 'expenses.created_by is NOT NULL');

SELECT col_is_null('expenses', 'description', 'expenses.description is nullable (D-04)');
SELECT col_is_null('expenses', 'updated_by', 'expenses.updated_by is nullable (server-set)');
SELECT col_is_null('expenses', 'deleted_at', 'expenses.deleted_at is nullable (D-22)');

SELECT col_type_is('expenses', 'amount', 'numeric(14,2)', 'expenses.amount is numeric(14,2) (D-20)');

SELECT has_index('expenses', 'expenses_paddock_date_idx');

-- ============================================================
-- Group 2 — Triggers.
-- ============================================================

SELECT has_trigger('expenses', 'trg_expenses_paddock_same_property',
  'trg_expenses_paddock_same_property (D-26 isolation trigger) exists');
SELECT has_trigger('expenses', 'trg_expenses_set_updated_by',
  'trg_expenses_set_updated_by (D-27 auditing trigger) exists');

-- ============================================================
-- Group 3 — Isolation trigger (D-26). Run with RLS out of the picture (still the
-- postgres superuser session, before the SET ROLE authenticated switch below) — proves
-- the trigger alone closes the raw-PATCH cross-property bypass, independent of RLS.
-- ============================================================

INSERT INTO expenses (id, property_id, paddock_id, category, amount, expense_date, created_by)
VALUES (
  '76000000-0007-0007-0007-000000000001', '70000000-0007-0007-0007-000000000001',
  '72000000-0007-0007-0007-000000000001', 'outros', 100.00, current_date,
  '71000000-0007-0007-0007-0000000000a2'
);

PREPARE cross_property_expense_insert AS
  INSERT INTO expenses (property_id, paddock_id, category, amount, expense_date)
  VALUES (
    '70000000-0007-0007-0007-000000000001', '72000000-0007-0007-0007-000000000002',
    'outros', 50.00, current_date
  );
SELECT throws_ok('EXECUTE cross_property_expense_insert', '23503', NULL,
  'INSERT with a cross-property paddock_id is rejected by trg_expenses_paddock_same_property (D-26)');

PREPARE cross_property_expense_update AS
  UPDATE expenses SET paddock_id = '72000000-0007-0007-0007-000000000002'
   WHERE id = '76000000-0007-0007-0007-000000000001';
SELECT throws_ok('EXECUTE cross_property_expense_update', '23503', NULL,
  'UPDATE reassigning paddock_id to a foreign property is rejected by the trigger (D-26)');

PREPARE archive_only_expense_update AS
  UPDATE expenses SET deleted_at = now()
   WHERE id = '76000000-0007-0007-0007-000000000001';
SELECT lives_ok('EXECUTE archive_only_expense_update',
  'a deleted_at-only UPDATE does not false-positive on the isolation trigger');

-- ============================================================
-- Group 4 — Write gate: two roles accepted (D-23). owner and veterinarian both write;
-- reader is rejected on both INSERT and UPDATE.
-- ============================================================

SET ROLE authenticated;

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a1', true);
PREPARE owner_expense_insert AS
  INSERT INTO expenses (id, property_id, paddock_id, category, amount, expense_date)
  VALUES (
    '76000000-0007-0007-0007-000000000002', '70000000-0007-0007-0007-000000000001',
    '72000000-0007-0007-0007-000000000001', 'arrendamento', 250.00, current_date
  );
SELECT lives_ok('EXECUTE owner_expense_insert', 'an owner can INSERT an expense (D-23)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a2', true);
PREPARE vet_expense_insert AS
  INSERT INTO expenses (id, property_id, paddock_id, category, amount, expense_date)
  VALUES (
    '76000000-0007-0007-0007-000000000003', '70000000-0007-0007-0007-000000000001',
    '72000000-0007-0007-0007-000000000001', 'sanidade_medicamentos', 300.00, current_date
  );
SELECT lives_ok('EXECUTE vet_expense_insert', 'a veterinarian can INSERT an expense (D-23)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a3', true);
PREPARE reader_expense_insert AS
  INSERT INTO expenses (property_id, paddock_id, category, amount, expense_date)
  VALUES (
    '70000000-0007-0007-0007-000000000001', '72000000-0007-0007-0007-000000000001',
    'outros', 75.00, current_date
  );
SELECT throws_ok('EXECUTE reader_expense_insert', '42501', NULL,
  'a reader-role member cannot INSERT an expense (D-23)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a1', true);
PREPARE owner_expense_update AS
  UPDATE expenses SET amount = 260.00 WHERE id = '76000000-0007-0007-0007-000000000002';
SELECT lives_ok('EXECUTE owner_expense_update', 'an owner can UPDATE an expense (D-23)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a2', true);
PREPARE vet_expense_update AS
  UPDATE expenses SET amount = 310.00 WHERE id = '76000000-0007-0007-0007-000000000003';
SELECT lives_ok('EXECUTE vet_expense_update', 'a veterinarian can UPDATE an expense (D-23)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a3', true);
PREPARE reader_expense_update AS
  UPDATE expenses SET amount = 999.00 WHERE id = '76000000-0007-0007-0007-000000000002';
SELECT throws_ok('EXECUTE reader_expense_update', '42501', NULL,
  'a reader-role member cannot UPDATE an expense (D-23)');

-- ============================================================
-- Group 5 — Read gate (D-24). Every member role sees the property's rows; a
-- non-member (property B's veterinarian) sees zero.
-- ============================================================

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a1', true);
SELECT is(
  (SELECT count(*) FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  1::bigint, 'owner can SELECT the fixture expense (D-24)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a2', true);
SELECT is(
  (SELECT count(*) FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  1::bigint, 'veterinarian can SELECT the fixture expense (D-24)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a3', true);
SELECT is(
  (SELECT count(*) FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  1::bigint, 'reader can SELECT the fixture expense (D-24)');

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000b1', true);
SELECT is(
  (SELECT count(*) FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  0::bigint, 'a member of a different property sees 0 rows for this property''s expense (D-24)');

-- ============================================================
-- Group 6 — Soft delete + restore (Pitfall 3 / G-06-2 regression class). The UPDATE
-- policy carries no deleted_at predicate — restoring a soft-deleted row must affect
-- exactly 1 row, never silently 0.
-- ============================================================

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a1', true);

PREPARE archive_owner_expense AS
  UPDATE expenses SET deleted_at = now() WHERE id = '76000000-0007-0007-0007-000000000002';
SELECT lives_ok('EXECUTE archive_owner_expense', 'owner archives the fixture expense');

SELECT ok(
  (SELECT deleted_at IS NOT NULL FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  'the expense is archived (deleted_at IS NOT NULL) after the archive UPDATE'
);

PREPARE restore_owner_expense AS
  UPDATE expenses SET deleted_at = NULL WHERE id = '76000000-0007-0007-0007-000000000002';
SELECT lives_ok('EXECUTE restore_owner_expense', 'owner restores the archived expense');

SELECT ok(
  (SELECT deleted_at IS NULL FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  'the expense is actually restored (deleted_at IS NULL) — regression check for G-06-2: the '
  || 'UPDATE USING clause must not exclude already-archived rows'
);

-- ============================================================
-- Group 7 — Auditing (D-27). created_by/updated_by are server-derived; the client
-- never sends either column.
-- ============================================================

SELECT is(
  (SELECT created_by FROM expenses WHERE id = '76000000-0007-0007-0007-000000000002'),
  '71000000-0007-0007-0007-0000000000a1'::uuid,
  'created_by is server-derived from auth.uid() on INSERT, proving repudiation cannot occur (D-27)'
);

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a2', true);
PREPARE vet_touch_expense AS
  UPDATE expenses SET description = 'touched by vet' WHERE id = '76000000-0007-0007-0007-000000000003';
SELECT lives_ok('EXECUTE vet_touch_expense', 'vet updates the fixture expense to trigger updated_by');

SELECT ok(
  (SELECT updated_by IS NOT NULL FROM expenses WHERE id = '76000000-0007-0007-0007-000000000003'),
  'updated_by is set by trg_expenses_set_updated_by after an UPDATE (D-27)'
);

RESET ROLE;

-- ============================================================
-- Group 8 — Sanitary paddock freeze (D-30, D-31). Structural columns, a fixture-scoped
-- NULL count (never global — 06_sanitary_test.sql's Group 8 lesson), and a live
-- register_sanitary_application call proving new rows freeze paddock_id/paddock_name
-- from the lot's paddock at write time.
-- ============================================================

SELECT has_column('sanitary_applications', 'paddock_id', 'sanitary_applications.paddock_id column exists (D-30)');
SELECT col_not_null('sanitary_applications', 'paddock_id', 'sanitary_applications.paddock_id is NOT NULL');
SELECT has_column('sanitary_applications', 'paddock_name', 'sanitary_applications.paddock_name column exists (D-30)');
SELECT col_not_null('sanitary_applications', 'paddock_name', 'sanitary_applications.paddock_name is NOT NULL');

SELECT is(
  (SELECT count(*) FROM sanitary_applications
    WHERE property_id = '70000000-0007-0007-0007-000000000001' AND paddock_id IS NULL),
  0::bigint,
  'no sanitary_applications row for this fixture property has a NULL paddock_id'
);

SELECT set_config('request.jwt.claim.sub', '71000000-0007-0007-0007-0000000000a2', true);
PREPARE register_gast_application AS
  SELECT register_sanitary_application(
    '73000000-0007-0007-0007-000000000001'::uuid,
    '74000000-0007-0007-0007-000000000001'::uuid,
    CURRENT_DATE,
    '["75000000-0007-0007-0007-000000000001"]'::jsonb,
    NULL
  );
SELECT lives_ok('EXECUTE register_gast_application',
  'the property veterinarian registers a sanitary application after the D-30 migration');

SELECT is(
  (SELECT paddock_id FROM sanitary_applications
    WHERE lot_id = '73000000-0007-0007-0007-000000000001' AND dose_id = '74000000-0007-0007-0007-000000000001'
      AND reverses_application_id IS NULL),
  '72000000-0007-0007-0007-000000000001'::uuid,
  'a new register_sanitary_application call freezes paddock_id from the lot''s current paddock (D-30)'
);

SELECT is(
  (SELECT paddock_name FROM sanitary_applications
    WHERE lot_id = '73000000-0007-0007-0007-000000000001' AND dose_id = '74000000-0007-0007-0007-000000000001'
      AND reverses_application_id IS NULL),
  'Paddock GAST A',
  'a new register_sanitary_application call freezes paddock_name from the lot''s current paddock (D-30)'
);

SELECT * FROM finish();
ROLLBACK;
