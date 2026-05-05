-- supabase/seed.sql
-- Phase 1 — Test seed for Auth & Multi-tenancy Core
-- Creates 2 properties + 2 auth users + 2 disjoint memberships.
-- Used by integration_test/rls_isolation_test.dart to prove cross-tenant isolation.

-- ============================================================
-- 1. Properties (deterministic UUIDs)
-- ============================================================
INSERT INTO propriedades (id, nome) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Fazenda Alpha'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Fazenda Beta')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. Auth users (deterministic IDs + bcrypt-hashed passwords)
-- Passwords: senha123A / senha123B
-- bcrypt hashes generated with cost=10 to match GoTrue defaults.
-- We use a Supabase admin technique: insert into auth.users with crypt().
-- ============================================================
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
) VALUES
  (
    'aaaa1111-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'userA@test.com',
    crypt('senha123A', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    false,
    '',
    '',
    '',
    ''
  ),
  (
    'bbbb2222-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'userB@test.com',
    crypt('senha123B', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    false,
    '',
    '',
    '',
    ''
  )
ON CONFLICT (id) DO NOTHING;

-- Identities are required for email/password login in newer GoTrue versions.
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES
  (
    gen_random_uuid(),
    'aaaa1111-0000-0000-0000-000000000001',
    '{"sub":"aaaa1111-0000-0000-0000-000000000001","email":"userA@test.com","email_verified":true}',
    'email',
    'aaaa1111-0000-0000-0000-000000000001',
    now(),
    now(),
    now()
  ),
  (
    gen_random_uuid(),
    'bbbb2222-0000-0000-0000-000000000002',
    '{"sub":"bbbb2222-0000-0000-0000-000000000002","email":"userB@test.com","email_verified":true}',
    'email',
    'bbbb2222-0000-0000-0000-000000000002',
    now(),
    now(),
    now()
  )
ON CONFLICT (provider, provider_id) DO NOTHING;

-- ============================================================
-- 3. Property memberships (D-04: seed-only)
-- userA → Fazenda Alpha (proprietario)
-- userB → Fazenda Beta  (proprietario)
-- ============================================================
INSERT INTO property_members (user_id, property_id, perfil) VALUES
  ('aaaa1111-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0000-000000000001',
   'proprietario'),
  ('bbbb2222-0000-0000-0000-000000000002',
   'bbbbbbbb-0000-0000-0000-000000000002',
   'proprietario')
ON CONFLICT (user_id, property_id) DO NOTHING;
