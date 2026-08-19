-- 20260819_14_paddock_archive_guard.sql
-- Quick task 260819-mk7 — item 1 do relatório de QA (Jorge Sturza,
-- iPhone 12 / Safari, "Teste do sistema campo gestor.pdf")
--
-- Remover um piquete deixava lotes e animais órfãos: softDeletePaddock
-- (lib/features/piquetes/data/piquete_repository.dart) é um UPDATE de
-- deleted_at sem nenhuma guarda, e as FKs lots.paddock_id / animals.lot_id
-- são RESTRICT — irrelevantes para soft delete. O lote sumia do board e os
-- animais ficavam com um rótulo de piquete inexistente, sem caminho de
-- limpeza na UI.
--
-- Espelha a guarda de lote (bloco 2 de 20260814_10_medium_hardening.sql) um
-- nível acima na hierarquia. Forward-only — não editar migrations já
-- aplicadas.
--
-- PENDENTE DE APLICAÇÃO MANUAL — este arquivo não foi rodado (sem
-- `supabase db push`, sem MCP `apply_migration`).

-- ============================================================
-- 1. Reparo dos órfãos já existentes
-- ============================================================
-- Desfaz o arquivamento de todo piquete que ainda tem lote ativo apontando
-- para ele (caso do QA: piquete "teste" com "lote 1" dentro). Restaurar o
-- piquete é a única correção que não descarta dado: o lote e seus animais
-- voltam a ter contexto, e o usuário decide se move ou arquiva antes de
-- remover de novo. Roda ANTES do trigger existir — nenhum piquete cuja
-- restauração este UPDATE faz passa pela checagem (o WHEN só cobre a
-- direção arquivar).
UPDATE paddocks p
   SET deleted_at = NULL
 WHERE p.deleted_at IS NOT NULL
   AND EXISTS (
     SELECT 1
       FROM lots l
      WHERE l.paddock_id = p.id
        AND l.deleted_at IS NULL
   );

-- ============================================================
-- 2. Guarda de arquivamento de piquete — nenhum lote ativo pode ficar órfão
-- ============================================================
-- Defesa independente do caminho de acesso: vale tanto para o fluxo da UI
-- quanto para um PATCH direto `paddocks?id=eq.X {"deleted_at": "..."}`.
CREATE OR REPLACE FUNCTION enforce_paddock_archive_no_active_lots()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_active_count integer;
BEGIN
  SELECT count(*) INTO v_active_count
    FROM lots
   WHERE paddock_id = NEW.id
     AND deleted_at IS NULL;

  IF v_active_count > 0 THEN
    RAISE EXCEPTION
      'paddock % cannot be archived: % active lot(s) still assigned to it',
      NEW.id, v_active_count
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

-- WHEN cobre só a direção arquivar (deleted_at NULL -> NOT NULL); restaurar
-- um piquete (NOT NULL -> NULL) continua livre, sem passar por esta checagem.
DROP TRIGGER IF EXISTS trg_paddocks_archive_guard ON paddocks;
CREATE TRIGGER trg_paddocks_archive_guard
  BEFORE UPDATE OF deleted_at ON paddocks
  FOR EACH ROW
  WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
  EXECUTE FUNCTION enforce_paddock_archive_no_active_lots();
