-- 20260508_02_property_paddock.sql
-- Phase 2 — Property & Paddock Structure
-- Adds: properties.owner + deleted_at, paddocks table, get_role() helper,
--       owner-write RLS, animals skeleton, animal_atf_memberships skeleton + ATF partial unique index,
--       sanitary_applications skeleton + composition_snapshot immutability trigger,
--       generate_animal_number RPC.
-- References: PROP-01, PROP-02 / D-01 D-02 D-04 D-05 D-07 D-08 D-11 D-17 D-18 D-19 D-20 D-21 D-22

-- ============================================================
-- 1. Extend properties — add owner (free text, D-05) + deleted_at (D-11)
-- ============================================================
ALTER TABLE properties
  ADD COLUMN owner      text,
  ADD COLUMN deleted_at timestamptz;

CREATE INDEX properties_active_idx
  ON properties (id) WHERE deleted_at IS NULL;

-- ============================================================
-- 2. get_role() helper — SECURITY DEFINER (D-08)
-- ============================================================
CREATE OR REPLACE FUNCTION get_role(p_property_id uuid)
RETURNS role_enum
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT role FROM property_members
  WHERE user_id = auth.uid()
    AND property_id = p_property_id
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION get_role(uuid) FROM public;
GRANT EXECUTE ON FUNCTION get_role(uuid) TO authenticated;

-- ============================================================
-- 3. properties — owner-write RLS (D-01, D-04, D-07)
--    INSERT: any authenticated user can create a property (will become owner via Plan 02 RPC).
--    UPDATE/soft-delete: only veterinarian.
-- ============================================================
CREATE POLICY "any_authenticated_can_create_property"
  ON properties
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "veterinarian_can_update_property"
  ON properties
  FOR UPDATE
  TO authenticated
  USING (is_member_of(id) AND get_role(id) = 'veterinarian'::role_enum)
  WITH CHECK (is_member_of(id) AND get_role(id) = 'veterinarian'::role_enum);

-- Hard DELETE intentionally NOT granted — soft-delete via UPDATE deleted_at.

-- ============================================================
-- 4. property_members — allow self-INSERT for the property creator (D-04)
--    A user creates a property then INSERTs themselves with role='veterinarian'.
--    RLS WITH CHECK ensures user_id = auth.uid() (no impersonation).
-- ============================================================
CREATE POLICY "self_insert_membership"
  ON property_members
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 5. paddocks (D-13, D-17, D-18, D-19)
-- ============================================================
CREATE TABLE paddocks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name        text NOT NULL,
  area_ha     numeric(8,2) NOT NULL CHECK (area_ha > 0),
  ua_capacity numeric(8,2) NOT NULL CHECK (ua_capacity > 0),
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE INDEX paddocks_property_idx ON paddocks (property_id);
CREATE INDEX paddocks_active_idx
  ON paddocks (property_id) WHERE deleted_at IS NULL;

ALTER TABLE paddocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE paddocks FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_paddocks"
  ON paddocks FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "veterinarian_can_insert_paddock"
  ON paddocks FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );

CREATE POLICY "veterinarian_can_update_paddock"
  ON paddocks FOR UPDATE TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  )
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );

-- No DELETE policy — soft-delete via UPDATE.

-- ============================================================
-- 6. animals skeleton (Phase 3 will ALTER to add full columns)
--    Required for generate_animal_number RPC (D-20).
-- ============================================================
CREATE TABLE animals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  category    text NOT NULL,
  number      integer NOT NULL,
  deleted_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX animals_property_category_idx
  ON animals (property_id, category);

CREATE UNIQUE INDEX animals_property_number_idx
  ON animals (property_id, number) WHERE deleted_at IS NULL;

ALTER TABLE animals ENABLE ROW LEVEL SECURITY;
ALTER TABLE animals FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_animals"
  ON animals FOR SELECT TO authenticated
  USING (is_member_of(property_id));

-- ============================================================
-- 7. generate_animal_number RPC (D-20)
--    Atomic per-(property, category) sequence via advisory lock.
-- ============================================================
CREATE OR REPLACE FUNCTION generate_animal_number(
  p_property_id uuid,
  p_category    text
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next     integer;
  v_lock_key bigint;
BEGIN
  v_lock_key := hashtextextended(p_property_id::text || '|' || p_category, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX(number), 0) + 1
  INTO v_next
  FROM animals
  WHERE property_id = p_property_id
    AND category = p_category;

  RETURN v_next;
END;
$$;

REVOKE ALL ON FUNCTION generate_animal_number(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION generate_animal_number(uuid, text) TO authenticated;

-- ============================================================
-- 8. animal_atf_memberships skeleton + partial unique index (D-22)
-- ============================================================
CREATE TABLE animal_atf_memberships (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  animal_id    uuid NOT NULL,
  atf_batch_id uuid NOT NULL,
  active       boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX animal_atf_memberships_active_idx
  ON animal_atf_memberships (animal_id) WHERE active = true;

ALTER TABLE animal_atf_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE animal_atf_memberships FORCE ROW LEVEL SECURITY;
-- No policies in Phase 2 — Phase 5 owns this table; reads/writes blocked until then.

-- ============================================================
-- 9. sanitary_applications skeleton + composition_snapshot immutability trigger (D-21)
-- ============================================================
CREATE TABLE sanitary_applications (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  composition_snapshot jsonb NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION prevent_snapshot_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'snapshot is immutable — sanitary_applications rows cannot be modified or deleted';
END;
$$;

CREATE TRIGGER trg_snapshot_immutable
  BEFORE UPDATE OR DELETE ON sanitary_applications
  FOR EACH ROW
  EXECUTE FUNCTION prevent_snapshot_mutation();

ALTER TABLE sanitary_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE sanitary_applications FORCE ROW LEVEL SECURITY;
-- No policies in Phase 2 — Phase 6 owns this table.
