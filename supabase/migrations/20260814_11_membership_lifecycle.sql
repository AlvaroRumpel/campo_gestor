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

-- ============================================================
-- 6. RPCs de convite
-- ============================================================

-- create_invite — D-10-04: qualquer gestor (veterinarian OU owner) convida,
-- não é vet-only como quase todo outro RPC deste projeto.
CREATE OR REPLACE FUNCTION create_invite(
  p_property_id uuid,
  p_email       text,
  p_role        role_enum
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_email      text;
  v_invite_id  uuid;
BEGIN
  v_email := lower(trim(p_email));

  IF v_email IS NULL OR v_email = '' OR v_email NOT LIKE '%@%' THEN
    RAISE EXCEPTION 'invalid email %', p_email USING ERRCODE = '22023';
  END IF;

  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(p_property_id) NOT IN ('veterinarian'::role_enum, 'owner'::role_enum) THEN
    RAISE EXCEPTION 'forbidden: only veterinarians or owners can invite members'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM property_members pm
      JOIN auth.users u ON u.id = pm.user_id
     WHERE pm.property_id = p_property_id
       AND u.email = v_email
  ) THEN
    RAISE EXCEPTION 'user % is already a member of this property', v_email
      USING ERRCODE = '23505';
  END IF;

  -- Convite pendente duplicado é barrado pelo índice único parcial
  -- invites_property_email_pending_idx e chega ao client como 23505 também
  -- (mesma família de erro, mesma copy pt-BR no plano 10-03).
  INSERT INTO invites (property_id, invited_email, role, invited_by)
  VALUES (p_property_id, v_email, p_role, auth.uid())
  RETURNING id INTO v_invite_id;

  RETURN v_invite_id;
END;
$$;

REVOKE ALL ON FUNCTION create_invite(uuid, text, role_enum) FROM public;
GRANT EXECUTE ON FUNCTION create_invite(uuid, text, role_enum) TO authenticated;
REVOKE EXECUTE ON FUNCTION create_invite(uuid, text, role_enum) FROM anon, PUBLIC;

-- revoke_invite — fecha o TOCTOU entre duas revogações/aceites concorrentes
-- do mesmo convite (fonte do backstop de UI "convite já respondido").
CREATE OR REPLACE FUNCTION revoke_invite(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id
    FROM invites
   WHERE id = p_invite_id;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'invite % not found', p_invite_id USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) NOT IN ('veterinarian'::role_enum, 'owner'::role_enum) THEN
    RAISE EXCEPTION 'forbidden: only veterinarians or owners can revoke invites'
      USING ERRCODE = '42501';
  END IF;

  UPDATE invites
     SET status = 'revoked', resolved_at = now()
   WHERE id = p_invite_id
     AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite % was already resolved', p_invite_id
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION revoke_invite(uuid) FROM public;
GRANT EXECUTE ON FUNCTION revoke_invite(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION revoke_invite(uuid) FROM anon, PUBLIC;

-- accept_invite — T-10-02: o e-mail nunca vem por parâmetro; deriva sempre
-- de current_user_email() para que ninguém aceite o convite de outra pessoa
-- só por saber o id.
CREATE OR REPLACE FUNCTION accept_invite(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_email text;
  v_invite       record;
BEGIN
  v_caller_email := current_user_email();

  SELECT id, property_id, invited_email, role, status
    INTO v_invite
    FROM invites
   WHERE id = p_invite_id;

  IF v_invite.id IS NULL THEN
    RAISE EXCEPTION 'invite % not found', p_invite_id USING ERRCODE = '23503';
  END IF;

  IF v_invite.invited_email <> v_caller_email THEN
    RAISE EXCEPTION 'invite % does not belong to the current user', p_invite_id
      USING ERRCODE = '42501';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'invite % was already resolved', p_invite_id
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO property_members (user_id, property_id, role)
  VALUES (auth.uid(), v_invite.property_id, v_invite.role)
  ON CONFLICT (user_id, property_id) DO NOTHING;

  UPDATE invites
     SET status = 'accepted', resolved_at = now()
   WHERE id = p_invite_id
     AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite % was already resolved', p_invite_id
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION accept_invite(uuid) FROM public;
GRANT EXECUTE ON FUNCTION accept_invite(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION accept_invite(uuid) FROM anon, PUBLIC;

-- decline_invite — mesmas checagens de e-mail/status de accept_invite, mas
-- não toca property_members.
CREATE OR REPLACE FUNCTION decline_invite(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_email text;
  v_invite       record;
BEGIN
  v_caller_email := current_user_email();

  SELECT id, invited_email, status
    INTO v_invite
    FROM invites
   WHERE id = p_invite_id;

  IF v_invite.id IS NULL THEN
    RAISE EXCEPTION 'invite % not found', p_invite_id USING ERRCODE = '23503';
  END IF;

  IF v_invite.invited_email <> v_caller_email THEN
    RAISE EXCEPTION 'invite % does not belong to the current user', p_invite_id
      USING ERRCODE = '42501';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'invite % was already resolved', p_invite_id
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE invites
     SET status = 'declined', resolved_at = now()
   WHERE id = p_invite_id
     AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite % was already resolved', p_invite_id
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION decline_invite(uuid) FROM public;
GRANT EXECUTE ON FUNCTION decline_invite(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION decline_invite(uuid) FROM anon, PUBLIC;

-- list_my_invites — SECURITY DEFINER porque o convidado ainda não é membro
-- da propriedade, então não passa pela RLS de properties para ler o nome da
-- fazenda. Filtra p.deleted_at IS NULL para não oferecer convite de fazenda
-- arquivada.
CREATE OR REPLACE FUNCTION list_my_invites()
RETURNS TABLE (
  id           uuid,
  property_id  uuid,
  property_name text,
  role         role_enum,
  created_at   timestamptz
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT i.id, i.property_id, p.name, i.role, i.created_at
    FROM invites i
    JOIN properties p ON p.id = i.property_id
   WHERE i.invited_email = current_user_email()
     AND i.status = 'pending'
     AND p.deleted_at IS NULL
   ORDER BY i.created_at;
$$;

REVOKE ALL ON FUNCTION list_my_invites() FROM public;
GRANT EXECUTE ON FUNCTION list_my_invites() TO authenticated;
REVOKE EXECUTE ON FUNCTION list_my_invites() FROM anon, PUBLIC;

-- ============================================================
-- 7. RPCs de membro
-- ============================================================

-- list_property_members — qualquer papel pode listar (leitor visualiza,
-- D-10-04). Existe porque members_read_own_memberships limita o SELECT
-- direto às linhas do próprio usuário e porque auth.users.email não é
-- legível por authenticated. is_self é calculado no servidor para que a
-- tela saiba qual linha oferece "Sair da fazenda" em vez de "Remover
-- membro" sem consulta extra de identidade no client.
CREATE OR REPLACE FUNCTION list_property_members(p_property_id uuid)
RETURNS TABLE (
  user_id    uuid,
  email      text,
  role       role_enum,
  created_at timestamptz,
  is_self    boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT pm.user_id, u.email, pm.role, pm.created_at, (pm.user_id = auth.uid())
    FROM property_members pm
    JOIN auth.users u ON u.id = pm.user_id
   WHERE pm.property_id = p_property_id
   ORDER BY pm.created_at;
END;
$$;

REVOKE ALL ON FUNCTION list_property_members(uuid) FROM public;
GRANT EXECUTE ON FUNCTION list_property_members(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION list_property_members(uuid) FROM anon, PUBLIC;

-- remove_member — guarda MEMB-03 chamada antes do DELETE.
CREATE OR REPLACE FUNCTION remove_member(
  p_property_id     uuid,
  p_target_user_id  uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(p_property_id) NOT IN ('veterinarian'::role_enum, 'owner'::role_enum) THEN
    RAISE EXCEPTION 'forbidden: only veterinarians or owners can remove members'
      USING ERRCODE = '42501';
  END IF;

  PERFORM assert_not_last_veterinarian(p_property_id, p_target_user_id);

  DELETE FROM property_members
   WHERE user_id = p_target_user_id
     AND property_id = p_property_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'member % not found in property %', p_target_user_id, p_property_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION remove_member(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION remove_member(uuid, uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION remove_member(uuid, uuid) FROM anon, PUBLIC;

-- update_member_role — a guarda só dispara quando o alvo é veterinarian
-- atual e o novo papel deixa de ser veterinarian (rebaixar/trocar o último
-- vet). Promover para vet, ou mexer no papel de um não-vet, nunca precisa
-- da guarda. O SET toca só a coluna role — incluir property_id no SET
-- dispararia trg_property_members_property_id_immutable.
CREATE OR REPLACE FUNCTION update_member_role(
  p_property_id     uuid,
  p_target_user_id  uuid,
  p_new_role        role_enum
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_role role_enum;
BEGIN
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(p_property_id) NOT IN ('veterinarian'::role_enum, 'owner'::role_enum) THEN
    RAISE EXCEPTION 'forbidden: only veterinarians or owners can update member roles'
      USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_current_role
    FROM property_members
   WHERE user_id = p_target_user_id
     AND property_id = p_property_id;

  IF v_current_role IS NULL THEN
    RAISE EXCEPTION 'member % not found in property %', p_target_user_id, p_property_id
      USING ERRCODE = '23503';
  END IF;

  IF v_current_role = 'veterinarian'::role_enum AND p_new_role <> 'veterinarian'::role_enum THEN
    PERFORM assert_not_last_veterinarian(p_property_id, p_target_user_id);
  END IF;

  UPDATE property_members
     SET role = p_new_role
   WHERE user_id = p_target_user_id
     AND property_id = p_property_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'member % not found in property %', p_target_user_id, p_property_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION update_member_role(uuid, uuid, role_enum) FROM public;
GRANT EXECUTE ON FUNCTION update_member_role(uuid, uuid, role_enum) TO authenticated;
REVOKE EXECUTE ON FUNCTION update_member_role(uuid, uuid, role_enum) FROM anon, PUBLIC;

-- leave_property — D-10-05: qualquer membro pode sair, sem checagem de
-- papel do próprio ator; bloqueado se for o último veterinarian.
CREATE OR REPLACE FUNCTION leave_property(p_property_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  PERFORM assert_not_last_veterinarian(p_property_id, auth.uid());

  DELETE FROM property_members
   WHERE user_id = auth.uid()
     AND property_id = p_property_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'member not found in property %', p_property_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION leave_property(uuid) FROM public;
GRANT EXECUTE ON FUNCTION leave_property(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION leave_property(uuid) FROM anon, PUBLIC;

-- ============================================================
-- Resumo dos objetos criados (conferência rápida no momento da aplicação)
-- ============================================================
-- 1 tabela (invites), 2 índices (invites_property_email_pending_idx,
-- invites_invited_email_idx), 2 policies SELECT (invitee_can_read_own_invites,
-- managers_can_read_property_invites), 1 trigger
-- (trg_invites_property_id_immutable), 11 funções (current_user_email,
-- assert_not_last_veterinarian, create_invite, revoke_invite, accept_invite,
-- decline_invite, list_my_invites, list_property_members, remove_member,
-- update_member_role, leave_property) — 10 delas chamáveis pelo client
-- (todas menos assert_not_last_veterinarian).
