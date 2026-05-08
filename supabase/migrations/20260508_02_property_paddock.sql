-- 20260508_02_property_paddock.sql
-- Phase 2 — Property & Paddock Structure
-- Adds: propriedades.proprietario + deleted_at, piquetes table, get_perfil() helper,
--       owner-write RLS, animais skeleton, animais_lote_atf skeleton + ATF partial unique index,
--       aplicacoes_sanitarias skeleton + composicao_snapshot immutability trigger,
--       gerar_numero_animal RPC.
-- References: PROP-01, PROP-02 / D-01 D-02 D-04 D-05 D-07 D-08 D-11 D-17 D-18 D-19 D-20 D-21 D-22

-- ============================================================
-- 1. Extend propriedades — add proprietario (free text, D-05) + deleted_at (D-11)
-- ============================================================
ALTER TABLE propriedades
  ADD COLUMN proprietario text,
  ADD COLUMN deleted_at   timestamptz;

CREATE INDEX propriedades_active_idx
  ON propriedades (id) WHERE deleted_at IS NULL;

-- ============================================================
-- 2. get_perfil() helper — SECURITY DEFINER (D-08)
-- ============================================================
CREATE OR REPLACE FUNCTION get_perfil(p_property_id uuid)
RETURNS perfil_enum
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT perfil FROM property_members
  WHERE user_id = auth.uid()
    AND property_id = p_property_id
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION get_perfil(uuid) FROM public;
GRANT EXECUTE ON FUNCTION get_perfil(uuid) TO authenticated;

-- ============================================================
-- 3. propriedades — owner-write RLS (D-01, D-04, D-07)
--    INSERT: any authenticated user can create a propriedade (will become owner via Plan 02 RPC).
--    UPDATE/soft-delete: only veterinario.
-- ============================================================
CREATE POLICY "any_authenticated_can_create_propriedade"
  ON propriedades
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "veterinario_can_update_propriedade"
  ON propriedades
  FOR UPDATE
  TO authenticated
  USING (is_member_of(id) AND get_perfil(id) = 'veterinario'::perfil_enum)
  WITH CHECK (is_member_of(id) AND get_perfil(id) = 'veterinario'::perfil_enum);

-- Hard DELETE intentionally NOT granted — soft-delete via UPDATE deleted_at.
-- Update the existing SELECT policy to also hide soft-deleted rows is NOT done here:
-- the UI/repository filters deleted_at IS NULL. Direct SELECT can still see them
-- (needed for restore in a future phase).

-- ============================================================
-- 4. property_members — allow self-INSERT for the propriedade creator (D-04)
--    A user creates a propriedade then INSERTs themselves with perfil='veterinario'.
--    RLS WITH CHECK ensures user_id = auth.uid() (no impersonation).
-- ============================================================
CREATE POLICY "self_insert_membership"
  ON property_members
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 5. piquetes (D-13, D-17, D-18, D-19)
-- ============================================================
CREATE TABLE piquetes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  propriedade_id  uuid NOT NULL REFERENCES propriedades(id) ON DELETE CASCADE,
  nome            text NOT NULL,
  area_ha         numeric(8,2) NOT NULL CHECK (area_ha > 0),
  capacidade_ua   numeric(8,2) NOT NULL CHECK (capacidade_ua > 0),
  created_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

CREATE INDEX piquetes_propriedade_idx ON piquetes (propriedade_id);
CREATE INDEX piquetes_active_idx
  ON piquetes (propriedade_id) WHERE deleted_at IS NULL;

ALTER TABLE piquetes ENABLE ROW LEVEL SECURITY;
ALTER TABLE piquetes FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_piquetes"
  ON piquetes FOR SELECT TO authenticated
  USING (is_member_of(propriedade_id));

CREATE POLICY "veterinario_can_insert_piquete"
  ON piquetes FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(propriedade_id)
    AND get_perfil(propriedade_id) = 'veterinario'::perfil_enum
  );

CREATE POLICY "veterinario_can_update_piquete"
  ON piquetes FOR UPDATE TO authenticated
  USING (
    is_member_of(propriedade_id)
    AND get_perfil(propriedade_id) = 'veterinario'::perfil_enum
  )
  WITH CHECK (
    is_member_of(propriedade_id)
    AND get_perfil(propriedade_id) = 'veterinario'::perfil_enum
  );

-- No DELETE policy — soft-delete via UPDATE.

-- ============================================================
-- 6. animais skeleton (Phase 3 will ALTER to add full columns)
--    Required for gerar_numero_animal RPC (D-20).
-- ============================================================
CREATE TABLE animais (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  propriedade_id uuid NOT NULL REFERENCES propriedades(id) ON DELETE CASCADE,
  categoria      text NOT NULL,
  numero         integer NOT NULL,
  deleted_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX animais_propriedade_categoria_idx
  ON animais (propriedade_id, categoria);

CREATE UNIQUE INDEX animais_propriedade_numero_idx
  ON animais (propriedade_id, numero) WHERE deleted_at IS NULL;

ALTER TABLE animais ENABLE ROW LEVEL SECURITY;
ALTER TABLE animais FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_animais"
  ON animais FOR SELECT TO authenticated
  USING (is_member_of(propriedade_id));

-- ============================================================
-- 7. gerar_numero_animal RPC (D-20)
--    Atomic per-(propriedade, categoria) sequence via advisory lock.
-- ============================================================
CREATE OR REPLACE FUNCTION gerar_numero_animal(
  p_propriedade_id uuid,
  p_categoria text
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next     integer;
  v_lock_key bigint;
BEGIN
  v_lock_key := hashtextextended(p_propriedade_id::text || '|' || p_categoria, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX(numero), 0) + 1
  INTO v_next
  FROM animais
  WHERE propriedade_id = p_propriedade_id
    AND categoria = p_categoria;

  RETURN v_next;
END;
$$;

REVOKE ALL ON FUNCTION gerar_numero_animal(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION gerar_numero_animal(uuid, text) TO authenticated;

-- ============================================================
-- 8. animais_lote_atf skeleton + partial unique index (D-22)
-- ============================================================
CREATE TABLE animais_lote_atf (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  animal_id     uuid NOT NULL,
  lote_atf_id   uuid NOT NULL,
  ativo         boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX animais_lote_atf_ativo_idx
  ON animais_lote_atf (animal_id) WHERE ativo = true;

ALTER TABLE animais_lote_atf ENABLE ROW LEVEL SECURITY;
ALTER TABLE animais_lote_atf FORCE ROW LEVEL SECURITY;
-- No policies in Phase 2 — Phase 5 owns this table; reads/writes blocked until then.

-- ============================================================
-- 9. aplicacoes_sanitarias skeleton + composicao_snapshot immutability trigger (D-21)
-- ============================================================
CREATE TABLE aplicacoes_sanitarias (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  composicao_snapshot  jsonb NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION prevent_snapshot_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'snapshot is immutable — aplicacoes_sanitarias rows cannot be modified or deleted';
END;
$$;

CREATE TRIGGER trg_snapshot_immutable
  BEFORE UPDATE OR DELETE ON aplicacoes_sanitarias
  FOR EACH ROW
  EXECUTE FUNCTION prevent_snapshot_mutation();

ALTER TABLE aplicacoes_sanitarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE aplicacoes_sanitarias FORCE ROW LEVEL SECURITY;
-- No policies in Phase 2 — Phase 6 owns this table.
