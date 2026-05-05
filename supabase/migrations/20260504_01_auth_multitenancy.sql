-- 20260504_01_auth_multitenancy.sql
-- Phase 1 — Auth & Multi-tenancy Core
-- Creates: propriedades, property_members, perfil_enum, is_member_of(), RLS policies
-- References: AUTH-02, AUTH-03, AUTH-05 / D-07, D-08

-- ============================================================
-- 1. Enum for membership profiles (D-07)
-- ============================================================
CREATE TYPE perfil_enum AS ENUM ('proprietario', 'veterinario', 'leitor');

-- ============================================================
-- 2. Propriedades (rural properties — multi-tenant root)
-- ============================================================
CREATE TABLE propriedades (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE propriedades ENABLE ROW LEVEL SECURITY;
ALTER TABLE propriedades FORCE ROW LEVEL SECURITY;

-- ============================================================
-- 3. Property members (auth multi-tenant binding)
-- ============================================================
CREATE TABLE property_members (
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id  uuid NOT NULL REFERENCES propriedades(id) ON DELETE CASCADE,
  perfil       perfil_enum NOT NULL DEFAULT 'leitor',
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, property_id)
);

ALTER TABLE property_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_members FORCE ROW LEVEL SECURITY;

-- Index for queries that filter only by user_id (e.g. listing user's properties).
-- The PK already covers (user_id, property_id) lookups.
CREATE INDEX property_members_user_id_idx ON property_members (user_id);

-- ============================================================
-- 4. Helper function — is_member_of (SECURITY DEFINER bypasses RLS
--    so it can read property_members from any policy context).
-- ============================================================
CREATE OR REPLACE FUNCTION is_member_of(p_property_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 FROM property_members
    WHERE user_id = auth.uid()
      AND property_id = p_property_id
  );
$$;

-- Lock function ownership and execution to prevent privilege issues.
REVOKE ALL ON FUNCTION is_member_of(uuid) FROM public;
GRANT EXECUTE ON FUNCTION is_member_of(uuid) TO authenticated;

-- ============================================================
-- 5. RLS Policies — propriedades
-- ============================================================
CREATE POLICY "members_can_read_their_properties"
  ON propriedades
  FOR SELECT
  TO authenticated
  USING (is_member_of(id));

-- INSERT/UPDATE/DELETE for propriedades is intentionally NOT granted in Phase 1.
-- Phase 2 (PROP-01) adds owner-write policies. Until then, only seed/admin can write.

-- ============================================================
-- 6. RLS Policies — property_members
-- ============================================================
CREATE POLICY "members_read_own_memberships"
  ON property_members
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- INSERT/UPDATE/DELETE for property_members is intentionally NOT granted in Phase 1.
-- Membership management arrives in a later phase. For now, only seed/admin writes.
