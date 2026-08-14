-- 10_membership_test.sql — pgTAP for Phase 10 (Gestão de Membros e Ciclo de Vida da
-- Propriedade).
-- Run via: supabase test db (fallback: MCP execute_sql BEGIN/ROLLBACK replay, the
-- established path since Phase 3 — Supabase CLI unlinked / Docker unavailable, see
-- 10-02-PLAN.md environment_constraint).
--
-- Authored against a NOT-YET-APPLIED schema (deliberate RED state, same D-39/D-41
-- precedent as 06_sanitary_test.sql and 07_expenses_test.sql) — this suite cannot pass
-- until plan 10-10 applies 20260814_11_membership_lifecycle.sql. Replay of this file is
-- also owned by plan 10-10; this plan (10-02) only authors it.
--
-- has_index() below uses the TWO-argument form only — the three-argument overload is
-- ambiguous in this Postgres/pgTAP combination and produced the single false failure
-- recorded for 05_reproductive_test.sql's has_index call on
-- animal_atf_memberships_active_idx.
--
-- Every count(*) assertion below is scoped to fixture ids/emails, never global table
-- state (06_sanitary_test.sql's Group 8 lesson — the only assertion there that fails on
-- PROD is the one scoped to global state).
--
-- Role-impersonation technique (Groups 4-9): all 9 RPCs are SECURITY DEFINER functions
-- that raise their own 42501/22023/23505/23514/P0002 via manual RAISE EXCEPTION, so a
-- bare set_config('request.jwt.claim.sub', ...) is enough to exercise them — no
-- `SET ROLE authenticated` is required for the RPC calls themselves (mirrors
-- 05_reproductive_test.sql/06_sanitary_test.sql, not 07_expenses_test.sql's direct-CRUD
-- pattern). Group 8 is the one exception: it probes direct-table RLS on `invites`
-- (zero write policies + FORCE ROW LEVEL SECURITY), so it explicitly switches to
-- `SET ROLE authenticated` first — `supabase test db` / MCP execute_sql otherwise
-- connects as `postgres`, which bypasses RLS unconditionally (even FORCE ROW LEVEL
-- SECURITY, per 04_movements_test.sql's header).
--
-- Group 8's RLS-write assertion follows the 07_expenses_test.sql lesson: proving the
-- ABSENCE of a mutation (a fixture-scoped count(*) = 0) is the stronger claim, not just
-- that an error was raised — `invites` carries zero INSERT policies, so the direct
-- INSERT is expected to raise 42501 outright (unlike a restrictive USING-only UPDATE
-- policy, which silently filters instead of raising), and both properties are asserted.

BEGIN;

SELECT plan(81);

-- ============================================================
-- Fixtures: two properties, six users (two veterinarians + one owner + one reader in
-- property A, one veterinarian in property B, one user with zero memberships anywhere —
-- the invitee for every convite/accept/decline assertion below).
-- ============================================================

INSERT INTO properties (id, name) VALUES
  ('a1000000-0010-0010-0010-000000000001', 'MEMB Test Property A'),
  ('a1000000-0010-0010-0010-000000000002', 'MEMB Test Property B');

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
  ('a2000000-0010-0010-0010-0000000000a1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'memb-vet-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('a2000000-0010-0010-0010-0000000000a2', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'memb-vet2-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('a2000000-0010-0010-0010-0000000000a3', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'memb-owner-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('a2000000-0010-0010-0010-0000000000a4', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'memb-reader-a@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('a2000000-0010-0010-0010-0000000000b1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'memb-vet-b@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', ''),
  ('a2000000-0010-0010-0010-0000000000c1', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'memb-convidado@test.com',
   crypt('senha123C', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', false, '', '', '', '')
ON CONFLICT (id) DO NOTHING;

-- memb-convidado@test.com deliberately gets NO row here — it is the invitee for every
-- create_invite/accept_invite/decline_invite/list_my_invites assertion below.
INSERT INTO property_members (user_id, property_id, role) VALUES
  ('a2000000-0010-0010-0010-0000000000a1', 'a1000000-0010-0010-0010-000000000001', 'veterinarian'),
  ('a2000000-0010-0010-0010-0000000000a2', 'a1000000-0010-0010-0010-000000000001', 'veterinarian'),
  ('a2000000-0010-0010-0010-0000000000a3', 'a1000000-0010-0010-0010-000000000001', 'owner'),
  ('a2000000-0010-0010-0010-0000000000a4', 'a1000000-0010-0010-0010-000000000001', 'reader'),
  ('a2000000-0010-0010-0010-0000000000b1', 'a1000000-0010-0010-0010-000000000002', 'veterinarian')
ON CONFLICT (user_id, property_id) DO NOTHING;

-- ============================================================
-- Group 1 — Schema shape (MEMB-01): the invites table, its 8 columns, its 2 indexes,
-- FORCE RLS, and exactly 2 SELECT-only policies (zero write policies — writes only via
-- the RPCs asserted in Groups 4-9).
-- ============================================================

SELECT has_table('invites');

SELECT has_column('invites', 'id', 'invites.id column exists');
SELECT has_column('invites', 'property_id', 'invites.property_id column exists');
SELECT has_column('invites', 'invited_email', 'invites.invited_email column exists');
SELECT has_column('invites', 'role', 'invites.role column exists');
SELECT has_column('invites', 'status', 'invites.status column exists');
SELECT has_column('invites', 'invited_by', 'invites.invited_by column exists');
SELECT has_column('invites', 'created_at', 'invites.created_at column exists');
SELECT has_column('invites', 'resolved_at', 'invites.resolved_at column exists');

SELECT has_index('invites', 'invites_property_email_pending_idx');
SELECT has_index('invites', 'invites_invited_email_idx');

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'invites'::regclass),
  true,
  'invites has ROW LEVEL SECURITY enabled'
);

SELECT is(
  (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'invites'::regclass),
  true,
  'invites has ROW LEVEL SECURITY forced (FORCE ROW LEVEL SECURITY) — applies even to the table owner'
);

SELECT is(
  (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'invites'),
  2::bigint,
  'invites carries exactly 2 RLS policies'
);

SELECT is(
  (SELECT count(*) FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'invites' AND cmd <> 'SELECT'),
  0::bigint,
  'invites carries zero non-SELECT (write) policies — every write goes through a SECURITY DEFINER RPC'
);

-- ============================================================
-- Group 2 — Function existence and grant blindage (MEMB-01, MEMB-02). 11 functions
-- total: 10 client-callable RPCs (granted to authenticated, revoked from anon) plus
-- assert_not_last_veterinarian, an internal-only helper with no client grant at all.
-- ============================================================

SELECT has_function('current_user_email', 'current_user_email() RPC exists');
SELECT has_function('assert_not_last_veterinarian', 'assert_not_last_veterinarian() helper exists');
SELECT has_function('create_invite', 'create_invite() RPC exists');
SELECT has_function('revoke_invite', 'revoke_invite() RPC exists');
SELECT has_function('accept_invite', 'accept_invite() RPC exists');
SELECT has_function('decline_invite', 'decline_invite() RPC exists');
SELECT has_function('list_my_invites', 'list_my_invites() RPC exists');
SELECT has_function('list_property_members', 'list_property_members() RPC exists');
SELECT has_function('remove_member', 'remove_member() RPC exists');
SELECT has_function('update_member_role', 'update_member_role() RPC exists');
SELECT has_function('leave_property', 'leave_property() RPC exists');

SELECT ok(
  has_function_privilege('authenticated', 'current_user_email()', 'EXECUTE'),
  'authenticated can EXECUTE current_user_email()'
);
SELECT ok(
  NOT has_function_privilege('anon', 'current_user_email()', 'EXECUTE'),
  'anon cannot EXECUTE current_user_email()'
);

SELECT ok(
  has_function_privilege('authenticated', 'create_invite(uuid, text, role_enum)', 'EXECUTE'),
  'authenticated can EXECUTE create_invite(uuid, text, role_enum)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'create_invite(uuid, text, role_enum)', 'EXECUTE'),
  'anon cannot EXECUTE create_invite(uuid, text, role_enum)'
);

SELECT ok(
  has_function_privilege('authenticated', 'revoke_invite(uuid)', 'EXECUTE'),
  'authenticated can EXECUTE revoke_invite(uuid)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'revoke_invite(uuid)', 'EXECUTE'),
  'anon cannot EXECUTE revoke_invite(uuid)'
);

SELECT ok(
  has_function_privilege('authenticated', 'accept_invite(uuid)', 'EXECUTE'),
  'authenticated can EXECUTE accept_invite(uuid)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'accept_invite(uuid)', 'EXECUTE'),
  'anon cannot EXECUTE accept_invite(uuid)'
);

SELECT ok(
  has_function_privilege('authenticated', 'decline_invite(uuid)', 'EXECUTE'),
  'authenticated can EXECUTE decline_invite(uuid)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'decline_invite(uuid)', 'EXECUTE'),
  'anon cannot EXECUTE decline_invite(uuid)'
);

SELECT ok(
  has_function_privilege('authenticated', 'list_my_invites()', 'EXECUTE'),
  'authenticated can EXECUTE list_my_invites()'
);
SELECT ok(
  NOT has_function_privilege('anon', 'list_my_invites()', 'EXECUTE'),
  'anon cannot EXECUTE list_my_invites()'
);

SELECT ok(
  has_function_privilege('authenticated', 'list_property_members(uuid)', 'EXECUTE'),
  'authenticated can EXECUTE list_property_members(uuid)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'list_property_members(uuid)', 'EXECUTE'),
  'anon cannot EXECUTE list_property_members(uuid)'
);

SELECT ok(
  has_function_privilege('authenticated', 'remove_member(uuid, uuid)', 'EXECUTE'),
  'authenticated can EXECUTE remove_member(uuid, uuid)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'remove_member(uuid, uuid)', 'EXECUTE'),
  'anon cannot EXECUTE remove_member(uuid, uuid)'
);

SELECT ok(
  has_function_privilege('authenticated', 'update_member_role(uuid, uuid, role_enum)', 'EXECUTE'),
  'authenticated can EXECUTE update_member_role(uuid, uuid, role_enum)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'update_member_role(uuid, uuid, role_enum)', 'EXECUTE'),
  'anon cannot EXECUTE update_member_role(uuid, uuid, role_enum)'
);

SELECT ok(
  has_function_privilege('authenticated', 'leave_property(uuid)', 'EXECUTE'),
  'authenticated can EXECUTE leave_property(uuid)'
);
SELECT ok(
  NOT has_function_privilege('anon', 'leave_property(uuid)', 'EXECUTE'),
  'anon cannot EXECUTE leave_property(uuid)'
);

SELECT ok(
  NOT has_function_privilege('authenticated', 'assert_not_last_veterinarian(uuid, uuid)', 'EXECUTE'),
  'authenticated cannot EXECUTE assert_not_last_veterinarian(uuid, uuid) — internal-only, no client grant'
);

-- ============================================================
-- Group 3 — Immutability trigger (reused enforce_property_id_immutable(), MEMB-01).
-- ============================================================

SELECT has_trigger('invites', 'trg_invites_property_id_immutable',
  'trg_invites_property_id_immutable exists on invites');

-- ============================================================
-- Group 4 — create_invite (MEMB-02). Identity is switched per-block via
-- set_config('request.jwt.claim.sub', ...); each RPC's own manual RAISE EXCEPTION does
-- the enforcement, so no SET ROLE is needed here.
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a1', true);

PREPARE vet_a_invites_convidado AS
  SELECT create_invite(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'memb-convidado@test.com', 'reader'::role_enum);
SELECT lives_ok('EXECUTE vet_a_invites_convidado',
  'vet-a creates a pending invite for memb-convidado@test.com as reader');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000b1', true);

SELECT create_invite(
  'a1000000-0010-0010-0010-000000000002'::uuid, 'MEMB-Convidado@Test.com', 'reader'::role_enum);

SELECT is(
  (SELECT invited_email FROM invites
    WHERE property_id = 'a1000000-0010-0010-0010-000000000002'
      AND invited_email = 'memb-convidado@test.com' AND status = 'pending'),
  'memb-convidado@test.com',
  'create_invite normalizes a mixed-case input email (MEMB-Convidado@Test.com) to lowercase before storing it'
);

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a3', true);

PREPARE owner_a_invites AS
  SELECT create_invite(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'memb-owner-invite@test.com', 'reader'::role_enum);
SELECT lives_ok('EXECUTE owner_a_invites',
  'owner-a creates a pending invite — an owner can invite members too (D-10-04)');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a4', true);

PREPARE reader_a_invites AS
  SELECT create_invite(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'memb-blocked@test.com', 'reader'::role_enum);
SELECT throws_ok('EXECUTE reader_a_invites', '42501', NULL,
  'a reader-role member cannot create an invite');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a1', true);

PREPARE invalid_email_invite AS
  SELECT create_invite(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'not-an-email', 'reader'::role_enum);
SELECT throws_ok('EXECUTE invalid_email_invite', '22023', NULL,
  'an email without @ is rejected');

PREPARE dup_pending_invite AS
  SELECT create_invite(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'memb-convidado@test.com', 'reader'::role_enum);
SELECT throws_ok('EXECUTE dup_pending_invite', '23505', NULL,
  'a second pending invite for the same (property, email) pair is rejected by the partial unique index');

PREPARE already_member_invite AS
  SELECT create_invite(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'memb-reader-a@test.com', 'reader'::role_enum);
SELECT throws_ok('EXECUTE already_member_invite', '23505', NULL,
  'inviting the email of someone already a member of the property is rejected');

-- ============================================================
-- Group 5 — accept_invite / decline_invite (MEMB-02). Identity is never trusted from a
-- client parameter — both RPCs derive it from current_user_email().
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000b1', true);

PREPARE vet_b_accepts_wrong_invite AS
  SELECT accept_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
       AND invited_email = 'memb-convidado@test.com' AND status = 'pending'));
SELECT throws_ok('EXECUTE vet_b_accepts_wrong_invite', '42501', NULL,
  'accept_invite by a different email than the one invited is rejected');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000c1', true);

PREPARE convidado_accepts AS
  SELECT accept_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
       AND invited_email = 'memb-convidado@test.com' AND status = 'pending'));
SELECT lives_ok('EXECUTE convidado_accepts', 'the invited user accepts their own invite');

SELECT is(
  (SELECT role FROM property_members
    WHERE user_id = 'a2000000-0010-0010-0010-0000000000c1'
      AND property_id = 'a1000000-0010-0010-0010-000000000001'),
  'reader'::role_enum,
  'accepting the invite created a property_members row with the exact role from the invite'
);

SELECT is(
  (SELECT status FROM invites
    WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
      AND invited_email = 'memb-convidado@test.com' AND role = 'reader'::role_enum),
  'accepted',
  'the accepted invite is marked status = accepted'
);

SELECT ok(
  (SELECT resolved_at IS NOT NULL FROM invites
    WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
      AND invited_email = 'memb-convidado@test.com' AND role = 'reader'::role_enum),
  'the accepted invite has resolved_at populated'
);

PREPARE convidado_accepts_again AS
  SELECT accept_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
       AND invited_email = 'memb-convidado@test.com' AND role = 'reader'::role_enum));
SELECT throws_ok('EXECUTE convidado_accepts_again', 'P0002', NULL,
  'accepting an already-resolved invite is rejected');

PREPARE convidado_declines AS
  SELECT decline_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000002'
       AND invited_email = 'memb-convidado@test.com' AND status = 'pending'));
SELECT lives_ok('EXECUTE convidado_declines',
  'the invited user declines a separate invite in a second property');

SELECT is(
  (SELECT status FROM invites
    WHERE property_id = 'a1000000-0010-0010-0010-000000000002'
      AND invited_email = 'memb-convidado@test.com'
      AND role = 'reader'::role_enum),
  'declined',
  'the declined invite is marked status = declined'
);

SELECT is(
  (SELECT count(*) FROM property_members
    WHERE user_id = 'a2000000-0010-0010-0010-0000000000c1'
      AND property_id = 'a1000000-0010-0010-0010-000000000002'),
  0::bigint,
  'declining an invite creates no property_members row'
);

-- ============================================================
-- Group 6 — revoke_invite (MEMB-02). Closes the same-invite double-resolution race the
-- UI treats as a backstop.
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a1', true);

SELECT create_invite(
  'a1000000-0010-0010-0010-000000000001'::uuid, 'memb-revogar@test.com', 'reader'::role_enum);

PREPARE vet_a_revokes AS
  SELECT revoke_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
       AND invited_email = 'memb-revogar@test.com' AND status = 'pending'));
SELECT lives_ok('EXECUTE vet_a_revokes', 'vet-a revokes their own pending invite');

SELECT is(
  (SELECT status FROM invites
    WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
      AND invited_email = 'memb-revogar@test.com'),
  'revoked',
  'the revoked invite is marked status = revoked'
);

PREPARE vet_a_revokes_again AS
  SELECT revoke_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
       AND invited_email = 'memb-revogar@test.com'));
SELECT throws_ok('EXECUTE vet_a_revokes_again', 'P0002', NULL,
  'revoking an already-resolved invite is rejected');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a4', true);

PREPARE reader_a_revokes AS
  SELECT revoke_invite((
    SELECT id FROM invites
     WHERE property_id = 'a1000000-0010-0010-0010-000000000001'
       AND invited_email = 'memb-owner-invite@test.com' AND status = 'pending'));
SELECT throws_ok('EXECUTE reader_a_revokes', '42501', NULL,
  'a reader-role member cannot revoke an invite');

-- ============================================================
-- Group 7 — Reads: list_property_members and list_my_invites (MEMB-01, MEMB-02).
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a4', true);

SELECT is(
  (SELECT count(*) FROM list_property_members('a1000000-0010-0010-0010-000000000001'::uuid)),
  5::bigint,
  'reader-a lists all 5 property A members (4 original fixtures + the accepted convidado) — reader can read (D-10-04)'
);

SELECT ok(
  (SELECT bool_and(email IS NOT NULL) FROM list_property_members('a1000000-0010-0010-0010-000000000001'::uuid)),
  'list_property_members returns a populated email column for every row'
);

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000b1', true);

PREPARE vet_b_lists_property_a AS
  SELECT * FROM list_property_members('a1000000-0010-0010-0010-000000000001'::uuid);
SELECT throws_ok('EXECUTE vet_b_lists_property_a', '42501', NULL,
  'a non-member of property A cannot list its members');

SELECT create_invite(
  'a1000000-0010-0010-0010-000000000002'::uuid, 'memb-convidado@test.com', 'veterinarian'::role_enum);

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000c1', true);

SELECT is(
  (SELECT count(*) FROM list_my_invites()),
  1::bigint,
  'list_my_invites returns exactly the 1 still-pending invite belonging to the caller''s email'
);

SELECT is(
  (SELECT property_name FROM list_my_invites()),
  'MEMB Test Property B',
  'list_my_invites returns the property_name for the pending invite'
);

-- ============================================================
-- Group 8 — Direct-table RLS on invites (T-10-10). SET ROLE authenticated makes the
-- policies' `TO authenticated` clause actually apply for the rest of this transaction
-- (SET ROLE effects are transaction-scoped and vanish at the trailing ROLLBACK
-- regardless) — supabase test db / MCP execute_sql otherwise connect as postgres, which
-- bypasses RLS unconditionally, even FORCE ROW LEVEL SECURITY.
-- ============================================================

SET ROLE authenticated;

PREPARE raw_invite_insert AS
  INSERT INTO invites (id, property_id, invited_email, role, invited_by)
  VALUES (
    'a3000000-0010-0010-0010-000000000099',
    'a1000000-0010-0010-0010-000000000001',
    'memb-raw-insert@test.com',
    'reader'::role_enum,
    'a2000000-0010-0010-0010-0000000000a1'
  );
SELECT throws_ok('EXECUTE raw_invite_insert', '42501', NULL,
  'a direct INSERT into invites as authenticated is rejected — FORCE RLS + zero write policies');

SELECT is(
  (SELECT count(*) FROM invites WHERE id = 'a3000000-0010-0010-0010-000000000099'),
  0::bigint,
  'the attempted direct INSERT into invites created no row (fixture-scoped id) — proves absence of mutation, not merely an error'
);

RESET ROLE;

-- ============================================================
-- Group 9 — MEMB-03 guard: the three ways to leave a property without a veterinarian
-- (remove, demote, leave) are all rejected with 23514. Property B has exactly one
-- veterinarian (vet-b); property A has two (vet-a, vet2-a) so the sub-rule — a manager
-- CAN act on a fellow veterinarian, but not on the LAST one — is provable too.
-- ============================================================

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000b1', true);

PREPARE vet_b_removes_self AS
  SELECT remove_member(
    'a1000000-0010-0010-0010-000000000002'::uuid, 'a2000000-0010-0010-0010-0000000000b1'::uuid);
SELECT throws_ok('EXECUTE vet_b_removes_self', '23514', NULL,
  'removing the last veterinarian of property B is rejected');

PREPARE vet_b_demotes_self AS
  SELECT update_member_role(
    'a1000000-0010-0010-0010-000000000002'::uuid, 'a2000000-0010-0010-0010-0000000000b1'::uuid,
    'reader'::role_enum);
SELECT throws_ok('EXECUTE vet_b_demotes_self', '23514', NULL,
  'demoting the last veterinarian of property B is rejected');

PREPARE vet_b_leaves AS
  SELECT leave_property('a1000000-0010-0010-0010-000000000002'::uuid);
SELECT throws_ok('EXECUTE vet_b_leaves', '23514', NULL,
  'the last veterinarian of property B leaving is rejected');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a1', true);

PREPARE vet_a_removes_vet2_a AS
  SELECT remove_member(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'a2000000-0010-0010-0010-0000000000a2'::uuid);
SELECT lives_ok('EXECUTE vet_a_removes_vet2_a',
  'removing one of two veterinarians of property A succeeds — vet-a is still left');

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a3', true);

PREPARE owner_a_removes_last_vet AS
  SELECT remove_member(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'a2000000-0010-0010-0010-0000000000a1'::uuid);
SELECT throws_ok('EXECUTE owner_a_removes_last_vet', '23514', NULL,
  'the owner removing property A''s now-last veterinarian is rejected — the guard blocks the actor''s target, not the actor''s own role'
);

SELECT set_config('request.jwt.claim.sub', 'a2000000-0010-0010-0010-0000000000a1', true);

PREPARE vet_a_promotes_reader_a AS
  SELECT update_member_role(
    'a1000000-0010-0010-0010-000000000001'::uuid, 'a2000000-0010-0010-0010-0000000000a4'::uuid,
    'veterinarian'::role_enum);
SELECT lives_ok('EXECUTE vet_a_promotes_reader_a',
  'promoting a reader to veterinarian never triggers the last-veterinarian guard'
);

-- ============================================================
-- Group 10 — Concurrency note (MEMB-03, not assertible in this harness). The race
-- between two simultaneous removals of two DIFFERENT veterinarians (each observing
-- "1 remaining" and both proceeding, zeroing the property's veterinarians) cannot be
-- reproduced here: the MCP execute_sql replay runs this whole file inside a SINGLE
-- transaction, and pgTAP has no concurrent-session primitive. The structural proof is
-- the PERFORM ... FOR UPDATE over the full veterinarian row set inside
-- assert_not_last_veterinarian (Group 2 confirms the function exists and is
-- client-unreachable; the migration source is the source of truth for the FOR UPDATE
-- clause itself). Manual verification recipe for a human running two real psql
-- sessions: open two `psql` connections, BEGIN in both, call remove_member for a
-- different veterinarian in each, and observe the second session block until the first
-- COMMITs, then fail with 23514.

SELECT * FROM finish();
ROLLBACK;
