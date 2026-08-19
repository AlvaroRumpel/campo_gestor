---
phase: quick-260819-mk7
plan: 01
status: complete
date: 2026-08-19
requirements: [QA-STURZA-1, QA-STURZA-2, QA-STURZA-3]
commits:
  - fbd6a74 fix(listas) — helper central de invalidação em 26 sites
  - 49c02bf fix(piquetes) — guarda de remoção (migration + UI) e reparo de órfãos
  - 5539098 feat(lotes) — ação "Arquivar lote" no menu do card
migrations_applied_prod_2026_08_19:
  - supabase/migrations/20260819_14_paddock_archive_guard.sql
tests: 538 passing
analyze: 4 issues (todas pré-existentes, idênticas à baseline em e0eb335)
---

# Quick 260819-mk7 — Ajustes do QA (Jorge Sturza)

Fechadas as 3 falhas do relatório de QA (iPhone 12 / Safari): piquete removido
deixando lotes e animais órfãos, listas stale sem F5, e dose recém-criada
invisível no seletor de "Registrar aplicação".

## Task 1 — Helper central de invalidação (`fbd6a74`)

**Criado** `lib/core/providers/invalidate_property_data.dart`:
`extension InvalidatePropertyData on WidgetRef { void invalidatePropertyData() }`,
invalidando os 29 providers/famílias de leitura escopados à propriedade ativa
(piquetes, lotes, animais, ATF/DG, sanitário, gastos). Passar a family sem
argumento invalida todos os membros — confirmado compilando.

Os providers de `dashboard_providers.dart` foram deliberadamente omitidos:
todos derivam via `ref.watch(...future)` de providers já na lista, então se
atualizam sozinhos. Providers de `membros`/`propriedades` também ficaram fora
(ciclo de vida da propriedade, não dados da propriedade).

**26 sites de mutação** trocados para `ref.invalidatePropertyData()` (43 usos
no total contando as declarações). Os `ref.invalidate` de botões
"Tentar novamente"/`ErrorRetry` ficaram intactos, como o plano exigia.

Arquivos: `piquetes_screen`, `paddock_detail_screen`, `lote_form_dialog`,
`mover_lote_dialog`, `_lots_section`, `lote_detail_panel`, `lote_detail_screen`,
`lotes_list_view` (retry, intacto), `animal_form_dialog`, `animal_edit_dialog`,
`mover_animal_dialog`, `baixa_dialog`, `animal_detail_screen`,
`animal_detail_panel`, `animais_table_view`, `dose_form_dialog`,
`sanitario_screen`, `registrar_aplicacao_screen`, `estornar_aplicacao_dialog`,
`atf_form_dialog`, `atf_detail_screen`, `atf_dg_table_view`,
`atf_animal_selection_screen`, `encerrar_atf_dialog`, `expense_form_dialog`,
`gastos_screen`, `gastos_property_screen`.

**`registrar_aplicacao_screen`**: removido `_lotsWithActiveAnimalsProvider`
(duplicata privada de `loteWithPaddockListByPropertyProvider` que ninguém
invalidava — causa raiz do item 3 do QA). `_pickLot` passa a ler o provider
compartilhado. `_pickDose` ganhou item final "Cadastrar nova dose" no seletor
(via novo parâmetro opcional `createLabel` do `_PickerSheet`, que devolve a
sentinela `_pickerCreateNew`), e o caminho de criação agora refaz o fetch
(`invalidate` + `read(...future)`) antes de reabrir o seletor. Cobre o fluxo do
QA — criar a dose no meio do registro — mesmo quando já existem doses.

## Task 2 — Guarda de remoção de piquete (`49c02bf`)

**`supabase/migrations/20260819_14_paddock_archive_guard.sql`** (NÃO aplicada —
orquestrador aplica):
1. `UPDATE paddocks SET deleted_at = NULL` para todo piquete arquivado que
   ainda tem lote ativo — desfaz os órfãos já em PROD (caso do QA: piquete
   "teste" / "lote 1"). Restaurar é a única correção que não descarta dado.
2. `enforce_paddock_archive_no_active_lots()` (plpgsql, `SET search_path =
   public`, `ERRCODE = '23514'`), espelhando
   `enforce_lot_archive_no_active_animals` de `20260814_10`.
3. `trg_paddocks_archive_guard BEFORE UPDATE OF deleted_at ON paddocks ... WHEN
   (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)` — restaurar
   continua livre.

**`piquete_repository.softDeletePaddock`**: `.select().single()` para 0 linhas
virarem erro em vez de sucesso silencioso.

**`piquetes_screen._confirmDelete`**: lê
`loteWithPaddockListByPropertyProvider`, conta lotes ativos do piquete e, se
> 0, abre um AlertDialog informativo sem chamar o repositório. O
`softDeletePaddock` ficou dentro de `try/catch PostgrestException` com
`code == '23514'` → mesma mensagem por SnackBar (defesa contra corrida). A
mensagem vive num único `_blockedMessage(int)` com `Intl.plural`.

## Task 3 — "Arquivar lote" no menu do card (`5539098`)

**`lote_repository.softDeleteLot`**: `.select().single()`.

**`_lots_section._LotCard`**: item `'archive'` "Arquivar lote" no PopupMenu,
que já é renderizado só quando `canEdit` (vet-only, herdado do "Editar nome").
O callback `onArchive` vem do pai (`LotsSection`, que tem `ref`), seguindo
exatamente como `onEdit` é passado — menor diff. `_archiveLot` lê
`animalListByLotProvider(lot.id)`, bloqueia com SnackBar se houver animal
ativo, confirma num AlertDialog, e envolve `softDeleteLot` em
`try/catch PostgrestException` (23514 = `trg_lots_archive_guard`).

## Verificação

| Gate | Resultado |
|---|---|
| `flutter analyze` | 4 issues — todas `info` pré-existentes, idênticas à baseline (verificado com `git stash`) |
| `flutter test` | 538 passing |
| `grep -rn "_lotsWithActiveAnimalsProvider" lib/` | 0 |
| `grep -rn "invalidatePropertyData" lib/ \| wc -l` | 43 (≥ 12) |
| Migration nova presente e NÃO aplicada | sim |

Baseline de analyze (`e0eb335`): 4 infos —
`app_config.dart:9` unintended_html_in_doc_comment, e 3
`use_null_aware_elements` em `_expense_list_item_card.dart`,
`propriedade_repository.dart`, `atf_dg_table_view.dart`. Nenhuma introduzida
por este trabalho, nenhuma removida (fora de escopo).

## Deviações

**[Rule 3 — bloqueio] Imports órfãos e locais mortos após a consolidação.**
Substituir blocos de `ref.invalidate(x); ref.invalidate(y);` por uma chamada só
deixou 7 imports e 3 variáveis locais sem uso, o que quebrava o gate de analyze
limpo. Removidos: imports de `animal_repository`/`sanitary_application_repository`/
`lote_repository`/`current_property_provider` em 7 arquivos; locais
`oldLotId` (`mover_animal_dialog`), `oldPaddockId` (`mover_lote_dialog`),
`memberIds` (`encerrar_atf_dialog`) — todos existiam apenas para alimentar as
invalidações por-id que sumiram.

**[Rule 3 — bloqueio] `ref.refresh(...future)` dispara `unused_result`.**
O plano pedia `await ref.refresh(doseListByPropertyProvider.future)` em
`_createDoseAndReopen`; `await` não conta como uso do resultado para o
analisador. Trocado por `ref.invalidate(...)` + `await ref.read(...future)` —
mesmo efeito (refetch forçado, aguardado) sem `// ignore`.

**[escopo] Ordenação de imports.** Os arquivos tocados tiveram o bloco de
imports relativos reordenado alfabeticamente ao inserir o novo import. Ruído
mínimo no diff, consistente com a convenção já existente nos arquivos.

## Nada pulado

Todos os 3 tasks e todos os itens de `<verify>`/`<done>` foram executados. Nada
deferido.

## Próximo passo (orquestrador)

Aplicar `supabase/migrations/20260819_14_paddock_archive_guard.sql` em PROD
(`wrdwzychjhlpwpivfhhq`) via MCP `apply_migration` — a CLI local segue
autenticada mas sem TTY para senha, mesmo caminho das Fases 3–7. O bloco 1
(reparo) é idempotente; rodar o arquivo inteiro duas vezes é seguro
(`CREATE OR REPLACE` + `DROP TRIGGER IF EXISTS`). Ledger passa a 24 migrations.

Depois, re-testar com o QA: (1) tentar remover piquete com lote → mensagem;
(2) criar/editar/mover qualquer entidade → listas atualizam sem F5;
(3) "Registrar aplicação" → "Cadastrar nova dose" no seletor → a dose aparece.

## Self-Check: PASSED

- `lib/core/providers/invalidate_property_data.dart` — FOUND
- `supabase/migrations/20260819_14_paddock_archive_guard.sql` — FOUND
- `fbd6a74`, `49c02bf`, `5539098` — todos em `git log`
