-- 20260814_09_multitenant_hardening.sql
-- Quick task 260814-f2v — hardening cross-fase vinda de review de segurança multi-tenant
-- References: T-f2v-01..05 (ver 260814-f2v-PLAN.md <threat_model>)
--
-- Cinco fixes, forward-only (não editar migrations já aplicadas — precedente
-- 20260812_06_fix_dose_update_policy.sql). Fecha furos em que um usuário
-- autenticado (tipicamente veterinário membro de duas propriedades) contorna
-- os RPCs SECURITY DEFINER com um PATCH/POST direto no PostgREST.
--
-- PENDENTE DE APLICAÇÃO MANUAL — este arquivo não foi rodado (sem
-- `supabase db push`, sem MCP `apply_migration`, sem `supabase test db`).
-- O bloco 2 (SET NOT NULL) e o bloco 4 (CHECK de categoria) abortam a
-- transação inteira se houver linhas violando a regra em PROD — a
-- pré-checagem no bloco 2 reporta a contagem de linhas para o operador
-- corrigir antes de tentar de novo.

-- ============================================================
-- 1. Fechar takeover de tenant — DROP self_insert_membership
-- ============================================================
-- Origem: 20260508_02_property_paddock.sql:61-67. A policy foi criada para
-- permitir que o criador da propriedade se auto-inserisse como veterinarian
-- logo após o INSERT em properties. Ficou obsoleta quando
-- create_property_with_membership (20260509_03_create_property_rpc.sql:11,22)
-- passou a SECURITY DEFINER e a inserir a membership sozinho, dentro da mesma
-- transação. Nenhum caminho Dart faz INSERT direto em property_members (só
-- leitura, ver lib/features/auth/data/property_repository.dart:42). Com a
-- policy viva, qualquer usuário autenticado pode fazer
-- `POST /property_members {"user_id": auth.uid(), "property_id": "<qualquer>",
-- "role": "veterinarian"}` e virar veterinário de uma propriedade que não é
-- sua — elevação de privilégio total (T-f2v-01).
DROP POLICY IF EXISTS "self_insert_membership" ON property_members;

-- ============================================================
-- 2. Animal sempre em lote — lot_id NOT NULL + trigger sem skip de NULL
-- ============================================================
-- animals.lot_id foi criado nullable em 20260514_03_lots_animals.sql:58, mas
-- o modelo Dart já assume não-nulo (Animal.lotId é String, não String?) e o
-- único write vem do RPC create_lot_with_animals, que sempre preenche.
-- Enquanto a coluna aceita NULL, o trigger de coerência lote↔propriedade
-- (enforce_animal_lot_same_property) pula a validação inteira em NEW.lot_id
-- IS NULL, então um PATCH direto `animals?id=eq.X {"lot_id": null}` escapa
-- da checagem de fronteira sem passar por nenhum RPC (T-f2v-03).
DO $$
DECLARE
  v_null_lot_count integer;
BEGIN
  SELECT count(*) INTO v_null_lot_count
    FROM animals
   WHERE lot_id IS NULL;

  IF v_null_lot_count > 0 THEN
    RAISE EXCEPTION
      'animals.lot_id SET NOT NULL abortado: % linha(s) com lot_id NULL '
      '(incluindo soft-deleted). Corrija essas linhas manualmente antes de '
      're-rodar esta migration.', v_null_lot_count;
  END IF;
END;
$$;

ALTER TABLE animals ALTER COLUMN lot_id SET NOT NULL;

-- Idêntica à versão original (20260716_04_animal_lot_property_trigger.sql),
-- exceto pela remoção de `NEW.lot_id IS NOT NULL AND` do IF externo — agora
-- que lot_id é NOT NULL, a validação roda sempre. CREATE OR REPLACE preserva
-- o binding de trg_animals_lot_same_property (nenhum DROP/CREATE TRIGGER
-- necessário).
CREATE OR REPLACE FUNCTION enforce_animal_lot_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- lot_id agora é obrigatório (NOT NULL) — a validação roda em todo
  -- INSERT, em toda troca de lot_id e em toda troca de property_id. Fires
  -- apenas quando um desses três muda, para não re-disparar em uma baixa
  -- (que só toca deleted_at).
  IF (
    TG_OP = 'INSERT'
    OR NEW.lot_id IS DISTINCT FROM OLD.lot_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM lots
       WHERE id = NEW.lot_id
         AND property_id = NEW.property_id
         AND deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION
        'lot % does not belong to property % or is archived',
        NEW.lot_id, NEW.property_id USING ERRCODE = '23503';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================
-- 3. property_id imutável — trigger genérico nas 6 tabelas de tenant
-- ============================================================
-- Fecha o gap deixado deliberadamente aberto em
-- 20260716_04_animal_lot_property_trigger.sql:36 e
-- 20260717_04_lot_paddock_property_trigger.sql:38-39 ("full property_id
-- immutability is deferred"). Sem isso, um PATCH direto
-- `<tabela>?id=eq.X {"property_id": "<outra propriedade>"}` move a linha
-- inteira para outro tenant, ignorando qualquer RPC (T-f2v-02).
-- sanitary_applications propositalmente FICA DE FORA: já é coberta por
-- trg_snapshot_immutable, que bloqueia qualquer UPDATE pós-INSERT (não só em
-- property_id) — um segundo trigger de imutabilidade ali seria redundante.
CREATE OR REPLACE FUNCTION enforce_property_id_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION
    '% .property_id is immutable: % -> %',
    TG_TABLE_NAME, OLD.property_id, NEW.property_id
    USING ERRCODE = '23514';
END;
$$;

DROP TRIGGER IF EXISTS trg_paddocks_property_id_immutable ON paddocks;
CREATE TRIGGER trg_paddocks_property_id_immutable
  BEFORE UPDATE OF property_id ON paddocks
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

DROP TRIGGER IF EXISTS trg_animals_property_id_immutable ON animals;
CREATE TRIGGER trg_animals_property_id_immutable
  BEFORE UPDATE OF property_id ON animals
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

DROP TRIGGER IF EXISTS trg_lots_property_id_immutable ON lots;
CREATE TRIGGER trg_lots_property_id_immutable
  BEFORE UPDATE OF property_id ON lots
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

DROP TRIGGER IF EXISTS trg_doses_property_id_immutable ON doses;
CREATE TRIGGER trg_doses_property_id_immutable
  BEFORE UPDATE OF property_id ON doses
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

DROP TRIGGER IF EXISTS trg_expenses_property_id_immutable ON expenses;
CREATE TRIGGER trg_expenses_property_id_immutable
  BEFORE UPDATE OF property_id ON expenses
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

DROP TRIGGER IF EXISTS trg_property_members_property_id_immutable ON property_members;
CREATE TRIGGER trg_property_members_property_id_immutable
  BEFORE UPDATE OF property_id ON property_members
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();

-- ============================================================
-- 4. Categoria válida e estável — CHECK + guarda ATF
-- ============================================================
-- animals.category não tinha nenhum CHECK: um PATCH direto podia gravar
-- qualquer string, e trocar a categoria de um animal com ATF ativa para uma
-- categoria não elegível (fora de vaca/novilha) deixava a membership
-- inconsistente sem passar pela validação de enforce_atf_membership_valid
-- (que só roda em INSERT/UPDATE de animal_atf_memberships, não de animals)
-- (T-f2v-04).
DO $$
DECLARE
  v_bad_category_count integer;
BEGIN
  SELECT count(*) INTO v_bad_category_count
    FROM animals
   WHERE category NOT IN (
     'vaca', 'novilha', 'terneiro', 'terneira', 'touro', 'boi', 'novilho'
   );

  IF v_bad_category_count > 0 THEN
    RAISE EXCEPTION
      'animals_category_check abortado: % linha(s) com category fora das 7 '
      'categorias válidas. Corrija essas linhas manualmente antes de '
      're-rodar esta migration.', v_bad_category_count;
  END IF;
END;
$$;

ALTER TABLE animals
  ADD CONSTRAINT animals_category_check
  CHECK (category IN (
    'vaca', 'novilha', 'terneiro', 'terneira', 'touro', 'boi', 'novilho'
  ));

-- Par ('vaca', 'novilha') é o mesmo usado em
-- enforce_atf_membership_valid (20260804_05_reproductive_module.sql:143) —
-- fonte única de elegibilidade ATF, não re-derivar.
CREATE OR REPLACE FUNCTION enforce_animal_category_atf_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.category NOT IN ('vaca', 'novilha') AND EXISTS (
    SELECT 1 FROM animal_atf_memberships
     WHERE animal_id = NEW.id
       AND active = true
  ) THEN
    RAISE EXCEPTION
      'animal % has an active ATF membership; remove it from the ATF before '
      'changing its category to %', NEW.id, NEW.category
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_animals_category_atf_guard ON animals;
CREATE TRIGGER trg_animals_category_atf_guard
  BEFORE UPDATE OF category ON animals
  FOR EACH ROW
  WHEN (NEW.category IS DISTINCT FROM OLD.category)
  EXECUTE FUNCTION enforce_animal_category_atf_guard();

-- ============================================================
-- 5. Baixa desativa membership ATF em qualquer caminho de escrita
-- ============================================================
-- animal_atf_memberships tem FORCE ROW LEVEL SECURITY e nenhuma policy de
-- UPDATE (deliberado — só RPCs SECURITY DEFINER escrevem ali). A função
-- original deactivate_atf_membership_on_baixa roda como invoker: quando a
-- baixa chega por PATCH direto em animals.deleted_at (fora do RPC
-- register_baixa), o UPDATE dentro do trigger é filtrado pela RLS e afeta 0
-- linhas — silenciosamente. O animal fica baixado mas continua constando
-- como membro ATF ativo (T-f2v-05). Corpo idêntico ao original
-- (20260804_05_reproductive_module.sql:212-225), só adicionando SECURITY
-- DEFINER — search_path já estava fixo. Trigger trg_animals_baixa_deactivates_atf
-- continua ligado, CREATE OR REPLACE preserva o binding.
CREATE OR REPLACE FUNCTION deactivate_atf_membership_on_baixa()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE animal_atf_memberships
     SET active = false
   WHERE animal_id = NEW.id
     AND active = true;

  RETURN NEW;
END;
$$;
