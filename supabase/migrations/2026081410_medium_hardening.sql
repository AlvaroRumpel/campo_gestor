-- 20260814_10_medium_hardening.sql
-- Quick task 260814-g9j — findings de severidade média do review geral
-- References: T-g9j-01..09 (ver 260814-g9j-PLAN.md <threat_model>)
--
-- Sete fixes de banco, forward-only (não editar migrations já aplicadas —
-- precedente 20260812_06_fix_dose_update_policy.sql e 20260814_09). O review
-- anterior (260814-f2v, migration 20260814_09) fechou os furos críticos de
-- isolamento multi-tenant; este fecha a camada seguinte — integridade de
-- dados (arquivar lote com animais, TOCTOU em move_lot_to_paddock, datas
-- futuras, autoria de gasto), superfície de execução (`anon` executando
-- RPCs SECURITY DEFINER) e `search_path` mutável.
--
-- PENDENTE DE APLICAÇÃO MANUAL — este arquivo não foi rodado (sem
-- `supabase db push`, sem MCP `apply_migration`, sem `supabase test db`).
-- Os dois blocos `DO` de pré-checagem (bloco 6) existem porque
-- `ADD CONSTRAINT` aborta a transação inteira se PROD tiver linha violando
-- a regra — o operador precisa saber quantas linhas corrigir antes de
-- re-rodar esta migration.

-- ============================================================
-- 1. Criação de propriedade só pelo RPC — DROP policy de INSERT direto
-- ============================================================
-- any_authenticated_can_create_property (20260508_02_property_paddock.sql,
-- WITH CHECK (true)) ficou obsoleta quando create_property_with_membership
-- passou a SECURITY DEFINER e passou a criar a propriedade + a membership do
-- dono na mesma transação (auditando nome/dono). Nenhum caminho Dart faz
-- INSERT direto em properties (só select/update em
-- lib/features/propriedades/data/propriedade_repository.dart); a criação
-- passa por .rpc('create_property_with_membership'). properties tem ENABLE
-- + FORCE ROW LEVEL SECURITY e, mesmo assim, dropar esta policy é seguro:
-- dg_records e animal_atf_memberships também têm FORCE RLS e zero policies
-- de escrita, e os RPCs SECURITY DEFINER deste projeto escrevem neles com
-- sucesso em PROD desde a Fase 5 — SECURITY DEFINER contorna RLS.
DROP POLICY IF EXISTS "any_authenticated_can_create_property" ON properties;

-- ============================================================
-- 2. Guarda de arquivamento de lote — nenhum animal ativo pode ficar órfão
-- ============================================================
-- softDeleteLot (lib/features/lotes/data/lote_repository.dart) não tem
-- nenhum caller na UI hoje — este trigger é defesa contra um PATCH direto
-- `lots?id=eq.X {"deleted_at": "..."}` que arquive um lote com animais ainda
-- ativos apontando para ele, independente do caminho de acesso.
CREATE OR REPLACE FUNCTION enforce_lot_archive_no_active_animals()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_active_count integer;
BEGIN
  SELECT count(*) INTO v_active_count
    FROM animals
   WHERE lot_id = NEW.id
     AND deleted_at IS NULL;

  IF v_active_count > 0 THEN
    RAISE EXCEPTION
      'lot % cannot be archived: % active animal(s) still assigned to it',
      NEW.id, v_active_count
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

-- WHEN cobre só a direção arquivar (deleted_at NULL -> NOT NULL); restaurar
-- um lote (NOT NULL -> NULL) continua livre, sem passar por esta checagem.
DROP TRIGGER IF EXISTS trg_lots_archive_guard ON lots;
CREATE TRIGGER trg_lots_archive_guard
  BEFORE UPDATE OF deleted_at ON lots
  FOR EACH ROW
  WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
  EXECUTE FUNCTION enforce_lot_archive_no_active_animals();

-- ============================================================
-- 3. TOCTOU em move_lot_to_paddock — mesmo padrão WR-01 de move_animal_to_lot
-- ============================================================
-- Corpo idêntico a 20260519_04_movements.sql, exceto o passo 6: o UPDATE
-- final ganha AND deleted_at IS NULL + um IF NOT FOUND, fechando a janela
-- entre a validação (passo 1) e o UPDATE, em que um outro caminho de escrita
-- pode arquivar o lote concorrentemente. CREATE OR REPLACE preserva a ACL
-- (REVOKE/GRANT já aplicados em 20260519_04, nenhum re-grant necessário
-- aqui).
CREATE OR REPLACE FUNCTION move_lot_to_paddock(
  p_lot_id     uuid,
  p_paddock_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id      uuid;
  v_current_paddock  uuid;
BEGIN
  -- 1. Load the lot's property_id + current paddock_id (also validates lot exists + active)
  SELECT property_id, paddock_id
    INTO v_property_id, v_current_paddock
    FROM lots
   WHERE id = p_lot_id
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'lot % not found or is archived', p_lot_id
      USING ERRCODE = '23503';
  END IF;

  -- 2. Membership check (T-4-07: defense-in-depth)
  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  -- 3. Role check — veterinarian only (T-4-02)
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can move lots'
      USING ERRCODE = '42501';
  END IF;

  -- 4. Source != destination guard (T-4-06: no-op rejection)
  IF v_current_paddock = p_paddock_id THEN
    RAISE EXCEPTION 'lot is already in paddock %', p_paddock_id
      USING ERRCODE = '23514';
  END IF;

  -- 5. Destination paddock must belong to the same property and be active (T-4-04)
  IF NOT EXISTS (
    SELECT 1 FROM paddocks
     WHERE id = p_paddock_id
       AND property_id = v_property_id
       AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION
      'paddock % not found, archived, or belongs to a different property',
      p_paddock_id USING ERRCODE = '23503';
  END IF;

  -- 6. Atomic single-row UPDATE (T-g9j-03: re-check deleted_at to close the
  --    TOCTOU where a concurrent archival removes the lot between the
  --    step-1 validation SELECT and this UPDATE — same pattern as WR-01 in
  --    move_animal_to_lot, 20260715_04_gap_move_animal_to_lot.sql).
  UPDATE lots
     SET paddock_id = p_paddock_id
   WHERE id = p_lot_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lot % was archived concurrently', p_lot_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

-- ============================================================
-- 4. Data futura em register_baixa
-- ============================================================
-- Corpo idêntico a 20260809_05_fix_register_baixa_null_guards.sql (versão
-- vigente em PROD), acrescentando só o guard de data futura logo depois do
-- guard existente p_date IS NULL. CR-01 (append de observação) e o
-- IF NOT FOUND de concorrência ficam idênticos.
CREATE OR REPLACE FUNCTION register_baixa(
  p_animal_id   uuid,
  p_reason      text,
  p_date        date,
  p_observation text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM animals
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or already archived', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register a baixa'
      USING ERRCODE = '42501';
  END IF;

  -- WR-01: `NULL NOT IN (...)` is NULL, not TRUE — plpgsql's `IF NULL THEN` takes the false
  -- branch, so an explicit `p_reason IS NULL` check is required; the allow-list NOT IN alone
  -- silently let a NULL reason through.
  IF p_reason IS NULL OR p_reason NOT IN ('sale', 'death', 'discard') THEN
    RAISE EXCEPTION 'invalid baixa reason %', p_reason
      USING ERRCODE = '22023';
  END IF;

  -- WR-01: p_date had no NULL guard at all — without this, a direct RPC call could archive an
  -- animal with baixa_date = NULL.
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'baixa date is required'
      USING ERRCODE = '22023';
  END IF;

  -- T-g9j-04: baixa não pode ser registrada com data no futuro — corromperia
  -- relatório de período.
  IF p_date > current_date THEN
    RAISE EXCEPTION 'baixa date cannot be in the future: %', p_date
      USING ERRCODE = '22023';
  END IF;

  -- Guarded by deleted_at IS NULL, followed by the IF NOT FOUND re-check below — the WR-01 fix
  -- from move_animal_to_lot (20260715_04_gap_move_animal_to_lot.sql) reused here so two concurrent
  -- baixas on the same animal cannot both report success.
  --
  -- CR-01 (05-REVIEW-FIX.md, 20260808 migration): the observation assignment below appends the
  -- new note to the existing one with a newline separator, treating NULL or empty-string
  -- p_observation as a strict no-op on the existing text.
  UPDATE animals
     SET baixa_reason = p_reason,
         baixa_date   = p_date,
         deleted_at   = now(),
         observation  = CASE
                           WHEN p_observation IS NULL OR p_observation = '' THEN observation
                           WHEN observation IS NULL OR observation = '' THEN p_observation
                           ELSE observation || E'\n' || p_observation
                         END
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'animal % was archived concurrently', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  -- Deliberately NO second UPDATE against animal_atf_memberships here — plan 05-01's
  -- trg_animals_baixa_deactivates_atf trigger (AFTER UPDATE OF deleted_at ON animals) fires on the
  -- UPDATE above and performs the D-19 deactivation on every access path, including a raw
  -- PostgREST PATCH that never reaches this function. This omission is deliberate, not a gap.
END;
$$;

-- ============================================================
-- 5. Data futura em register_sanitary_application
-- ============================================================
-- ARMADILHA: a versão-base é a de 20260813_07_expenses_module.sql (a que
-- está viva em PROD, com o congelamento de paddock_id/paddock_name — D-30),
-- NÃO a de 20260811_06_sanitary_rpcs.sql. Copiar de 20260811_06 reverteria a
-- Fase 7 inteira e quebraria paddock_id NOT NULL. Corpo copiado verbatim de
-- 20260813_07, acrescentando só o guard de data futura logo depois do guard
-- existente p_applied_at IS NULL.
CREATE OR REPLACE FUNCTION register_sanitary_application(
  p_lot_id     uuid,
  p_dose_id    uuid,
  p_applied_at date,
  p_animal_ids jsonb,             -- JSON array of animal uuid strings, post-deselection
  p_notes      text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_property_id     uuid;
  v_lot_name        text;
  v_paddock_id      uuid;
  v_paddock_name    text;
  v_dose            record;
  v_kg_per_ua       numeric;
  v_distinct_ids    jsonb;
  v_selected_count  integer;
  v_valid_count     integer;
  v_active_count    integer;
  v_snapshot        jsonb;
  v_total_ua        numeric;
  v_total_volume    numeric;
  v_total_cost      numeric;
  v_app_id          uuid;
BEGIN
  SELECT l.property_id, l.name, p.id, p.name
    INTO v_property_id, v_lot_name, v_paddock_id, v_paddock_name
    FROM lots l JOIN paddocks p ON p.id = l.paddock_id
   WHERE l.id = p_lot_id AND l.deleted_at IS NULL;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'lot % not found or archived', p_lot_id USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register a sanitary application'
      USING ERRCODE = '42501';
  END IF;

  SELECT id, name, dosage_per_kg, cost_per_kg INTO v_dose
    FROM doses WHERE id = p_dose_id AND property_id = v_property_id AND deleted_at IS NULL;
  IF v_dose.id IS NULL THEN
    RAISE EXCEPTION 'dose % not found or archived', p_dose_id USING ERRCODE = '23503';
  END IF;

  SELECT kg_per_ua INTO v_kg_per_ua FROM properties WHERE id = v_property_id;

  -- Guard NULL parameters before any array operation — a null jsonb parameter must not
  -- silently become an empty selection (lesson of 20260809_05_fix_register_baixa_null_guards).
  IF p_applied_at IS NULL THEN
    RAISE EXCEPTION 'applied_at is required' USING ERRCODE = '22023';
  END IF;

  -- T-g9j-04: aplicação sanitária não pode ser registrada com data no
  -- futuro — corromperia relatório de período.
  IF p_applied_at > current_date THEN
    RAISE EXCEPTION 'applied_at cannot be in the future: %', p_applied_at
      USING ERRCODE = '22023';
  END IF;

  IF p_animal_ids IS NULL THEN
    RAISE EXCEPTION 'animal_ids is required' USING ERRCODE = '22023';
  END IF;

  -- Deduplicate the submitted id array before counting — a repeated uuid in the payload is a
  -- no-op rather than a spurious count mismatch (lesson of
  -- 20260808_05_fix_baixa_observation_and_atf_dedup).
  SELECT jsonb_agg(DISTINCT elem) INTO v_distinct_ids
    FROM jsonb_array_elements_text(p_animal_ids) elem;

  v_selected_count := COALESCE(jsonb_array_length(v_distinct_ids), 0);
  IF v_selected_count = 0 THEN
    RAISE EXCEPTION 'at least 1 animal must be selected' USING ERRCODE = '23514';
  END IF;

  -- D-32: concurrency revalidation — the whole transaction aborts if any submitted animal is no
  -- longer active in this exact lot. Never a partial write.
  SELECT count(*) INTO v_valid_count
    FROM animals a
    JOIN jsonb_array_elements_text(v_distinct_ids) elem(id) ON a.id = elem.id::uuid
   WHERE a.lot_id = p_lot_id AND a.deleted_at IS NULL AND a.property_id = v_property_id;

  IF v_valid_count <> v_selected_count THEN
    RAISE EXCEPTION '% animais mudaram desde que a tela foi aberta — recarregue',
      (v_selected_count - v_valid_count)
      USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*) INTO v_active_count FROM animals WHERE lot_id = p_lot_id AND deleted_at IS NULL;

  SELECT jsonb_agg(jsonb_build_object(
           'animal_id', a.id, 'number', a.number,
           'category', a.category, 'ua', animal_ua_weight(a.category)
         )),
         sum(animal_ua_weight(a.category))
    INTO v_snapshot, v_total_ua
    FROM animals a
    JOIN jsonb_array_elements_text(v_distinct_ids) elem(id) ON a.id = elem.id::uuid;

  v_total_volume := v_total_ua * v_dose.dosage_per_kg * v_kg_per_ua;
  v_total_cost   := CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL
                          ELSE v_total_ua * v_dose.cost_per_kg * v_kg_per_ua END;

  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes,
    paddock_id, paddock_name
  ) VALUES (
    v_snapshot, v_property_id, p_lot_id, v_lot_name, v_dose.id, v_dose.name,
    v_dose.dosage_per_kg, v_dose.dosage_per_kg * v_kg_per_ua, v_dose.cost_per_kg,
    CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL ELSE v_dose.cost_per_kg * v_kg_per_ua END,
    p_applied_at, auth.uid(), v_selected_count, v_total_ua, v_total_volume, v_total_cost,
    v_active_count - v_selected_count, p_notes,
    v_paddock_id, v_paddock_name
  ) RETURNING id INTO v_app_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_app_id);
END;
$$;

-- ============================================================
-- 6. Data futura em expenses — pré-checagem + CHECK de tabela
-- ============================================================
-- current_date não é IMMUTABLE, mas Postgres exige IMMUTABLE apenas em CHECK
-- de domínio, não de tabela — o CHECK abaixo é aceito. Trade-off aprovado
-- pelo usuário. O bloco DO reporta a contagem de linhas violando antes do
-- ADD CONSTRAINT, para o operador corrigir manualmente em PROD antes de
-- re-rodar esta migration (ADD CONSTRAINT aborta a transação inteira se
-- houver violação).
DO $$
DECLARE
  v_future_expense_count integer;
BEGIN
  SELECT count(*) INTO v_future_expense_count
    FROM expenses
   WHERE expense_date > current_date;

  IF v_future_expense_count > 0 THEN
    RAISE EXCEPTION
      'expenses_date_not_future abortado: % linha(s) com expense_date no '
      'futuro. Corrija essas linhas manualmente antes de re-rodar esta '
      'migration.', v_future_expense_count;
  END IF;
END;
$$;

ALTER TABLE expenses
  ADD CONSTRAINT expenses_date_not_future CHECK (expense_date <= current_date);

-- ============================================================
-- 7. Autoria de gasto — created_by = auth.uid() no INSERT
-- ============================================================
-- O INSERT do Dart (lib/features/gastos/data/expense_repository.dart) não
-- envia created_by — o DEFAULT auth.uid() da coluna resolve, então este
-- predicado passa nos dois casos. Sem ele, um POST direto
-- `expenses {"created_by": "<outro usuário>"}` forjaria a autoria
-- (T-g9j-05). A policy de UPDATE (owner_vet_can_update_expense) fica
-- intacta de propósito — exigir created_by = auth.uid() ali bloquearia um
-- vet editando gasto lançado por outro membro.
DROP POLICY IF EXISTS "owner_vet_can_insert_expense" ON expenses;
CREATE POLICY "owner_vet_can_insert_expense" ON expenses FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
    AND created_by = auth.uid()
  );

-- ============================================================
-- 8. Superfície de execução — anon não pode executar nenhum RPC SECURITY DEFINER
-- ============================================================
-- REVOKE ... FROM public sozinho não remove o grant que o Supabase dá a anon
-- via ALTER DEFAULT PRIVILEGES — daí a menção explícita a anon em cada
-- linha. generate_animal_number(uuid, text) foi dropada em
-- 20260514_03_lots_animals.sql:94 e NÃO está nesta lista — revogá-la
-- abortaria a migration com 42883 (função inexistente). Só sobrevive a
-- overload generate_animal_number(uuid).
REVOKE EXECUTE ON FUNCTION is_member_of(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION get_role(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION create_property_with_membership(text, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION generate_animal_number(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION create_lot_with_animals(uuid, uuid, text, jsonb, jsonb, integer) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION move_animal_to_lot(uuid, uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION move_lot_to_paddock(uuid, uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION add_animals_to_atf(uuid, jsonb) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION remove_animal_from_atf(uuid, uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION close_atf(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION save_dg_records(uuid, jsonb) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION register_baixa(uuid, text, date, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION reverse_sanitary_application(uuid, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION deactivate_atf_membership_on_baixa() FROM anon, PUBLIC, authenticated;

-- ============================================================
-- 9. search_path fixo — advisor do Supabase
-- ============================================================
-- animal_ua_weight é LANGUAGE sql IMMUTABLE, sem referência a objeto nenhum
-- (CASE puro) — a cláusula SET impede o planner de fazer inlining dela, um
-- custo aceito para silenciar o advisor.
ALTER FUNCTION prevent_snapshot_mutation() SET search_path = public;
ALTER FUNCTION animal_ua_weight(text) SET search_path = public;
