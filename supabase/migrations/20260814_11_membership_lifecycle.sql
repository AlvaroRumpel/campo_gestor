-- 20260814_11_membership_lifecycle.sql
-- Phase 10 — Gestão de Membros e Ciclo de Vida da Propriedade (plano 10-01)
-- Creates: tabela invites (RLS forçada, 2 policies SELECT, 0 de escrita),
--          helpers current_user_email() / assert_not_last_veterinarian(),
--          9 RPCs SECURITY DEFINER (convites + membros) que passam a ser a
--          única porta de escrita/leitura ampla de property_members.
-- References: MEMB-01, MEMB-02, MEMB-03 (ver 10-CONTEXT.md, 10-RESEARCH.md)
--
-- PENDENTE DE APLICAÇÃO — este arquivo é forward-only e NÃO foi rodado (sem
-- `supabase db push`, sem MCP `apply_migration`, sem `supabase test db`). A
-- aplicação em PROD é do plano 10-10; os testes pgTAP são do plano 10-02.

-- ============================================================
-- 1. Tabela invites
-- ============================================================
CREATE TABLE invites (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id   uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  invited_email text NOT NULL,
  role          role_enum NOT NULL,
  status        text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'declined', 'revoked')),
  invited_by    uuid NOT NULL REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz
);

-- Só pode haver 1 convite pendente por (propriedade, e-mail) — reconvidar
-- exige revogar o anterior primeiro. Índice parcial: convites já resolvidos
-- (accepted/declined/revoked) não entram na checagem de unicidade.
CREATE UNIQUE INDEX invites_property_email_pending_idx
  ON invites (property_id, invited_email) WHERE status = 'pending';

CREATE INDEX invites_invited_email_idx ON invites (invited_email);

ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites FORCE ROW LEVEL SECURITY;

-- ============================================================
-- 2. RLS Policies — invites (exatamente 2, ambas SELECT; zero de escrita)
-- ============================================================
-- Escrita em invites é só via RPC SECURITY DEFINER (create_invite,
-- revoke_invite, accept_invite, decline_invite) — mesmo precedente de
-- dg_records / animal_atf_memberships / property_members: FORCE RLS + zero
-- policies de INSERT/UPDATE/DELETE.
CREATE POLICY "invitee_can_read_own_invites"
  ON invites
  FOR SELECT
  TO authenticated
  USING (invited_email = current_user_email());

CREATE POLICY "managers_can_read_property_invites"
  ON invites
  FOR SELECT
  TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) IN ('veterinarian'::role_enum, 'owner'::role_enum)
  );

-- ============================================================
-- 3. Trigger de imutabilidade — reusa enforce_property_id_immutable()
--    (20260814_09_multitenant_hardening.sql), não escreve função nova.
-- ============================================================
DROP TRIGGER IF EXISTS trg_invites_property_id_immutable ON invites;
CREATE TRIGGER trg_invites_property_id_immutable
  BEFORE UPDATE OF property_id ON invites
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

-- ============================================================
-- 4. current_user_email() — resolve o e-mail do chamador a partir de
--    auth.users; usado pelas policies acima e pelos RPCs de convite para
--    nunca confiar em e-mail vindo por parâmetro do client.
-- ============================================================
CREATE OR REPLACE FUNCTION current_user_email()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT email FROM auth.users WHERE id = auth.uid();
$$;

REVOKE ALL ON FUNCTION current_user_email() FROM public;
GRANT EXECUTE ON FUNCTION current_user_email() TO authenticated;
REVOKE EXECUTE ON FUNCTION current_user_email() FROM anon, PUBLIC;

-- ============================================================
-- 5. assert_not_last_veterinarian() — guarda MEMB-03 (lock-then-count)
--    Sem SECURITY DEFINER: só é chamada de dentro de outra função SECURITY
--    DEFINER (remove_member, update_member_role, leave_property) e herda o
--    contexto elevado dela.
-- ============================================================
CREATE OR REPLACE FUNCTION assert_not_last_veterinarian(
  p_property_id        uuid,
  p_excluding_user_id  uuid
) RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_remaining_vets integer;
BEGIN
  -- Trava o CONJUNTO INTEIRO de linhas veterinarian da propriedade antes de
  -- contar. Travar só a linha alvo seria racy: duas remoções concorrentes de
  -- dois veterinários diferentes cada uma veria "resta 1" e as duas
  -- passariam, zerando os veterinários da fazenda. Postgres rejeita
  -- count(*) combinado com FOR UPDATE na mesma instrução — os dois passos
  -- (PERFORM ... FOR UPDATE, depois SELECT count(*)) são obrigatórios, não
  -- estilo.
  PERFORM 1 FROM property_members
   WHERE property_id = p_property_id
     AND role = 'veterinarian'::role_enum
   FOR UPDATE;

  SELECT count(*) INTO v_remaining_vets
    FROM property_members
   WHERE property_id = p_property_id
     AND role = 'veterinarian'::role_enum
     AND user_id <> p_excluding_user_id;

  IF v_remaining_vets = 0 THEN
    RAISE EXCEPTION
      'property % would be left without a veterinarian', p_property_id
      USING ERRCODE = '23514';
  END IF;
END;
$$;

-- Não é chamável pelo client — sem GRANT a authenticated.
REVOKE ALL ON FUNCTION assert_not_last_veterinarian(uuid, uuid) FROM public;
