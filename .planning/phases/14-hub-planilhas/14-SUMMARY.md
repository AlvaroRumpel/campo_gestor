# Phase 14 — Hub Planilhas ("modo Excel") — SUMMARY

**Executado:** 2026-08-21 · milestone v1.1
**Status:** completa — flutter analyze limpo, flutter test 578/578, migration aplicada em PROD com probes 6/6 + 6/6 em BEGIN…ROLLBACK.

## O que foi entregue

### GRID-01 — grade derivada do SheetSchema
- `gridColumnsFromSchema(schema, {overrides, readOnly, flexKey})` em `editable_grid.dart`: colunas da grade derivam de `schema.importColumns` (largura por tipo, enum → dropdown, numérico/data → mono). Fim do `GridColumn` hand-built por tela para entidades novas; grades antigas (animais/doses) seguem intactas e reusadas.
- Teste unitário novo `grid_columns_from_schema_test.dart` (4 casos).

### GRID-02 — backend
- Migration `20260823_18_bulk_structure.sql` **aplicada em PROD** (`wrdwzychjhlpwpivfhhq`, ledger 25): `bulk_upsert_paddocks`, `bulk_upsert_lots`, `bulk_upsert_expenses`. Padrão de `bulk_upsert_doses`: SECURITY DEFINER, erro `linha N: motivo`, tudo-ou-nada. Semântica `id` presente = alvo exato (grade, permite renomear); ausente = match por nome (import) ou INSERT.
- Gastos com guarda própria owner+veterinarian (D-23); demais via `assert_vet_of`.
- `supabase/tests/18_bulk_structure_test.sql` (formato SQL editor): 6 guards (22023/42501) + 6 probes comportamentais (create/rename piquete, create/rename lote, piquete inexistente → `linha 1:`, gasto criado) — replay em PROD dentro de `BEGIN…ROLLBACK`, 12/12.
- Débito herdado: `anon` ainda tem EXECUTE (mesmo estado das RPCs bulk anteriores; falha fechado via guard — segue no backlog do `/gsd-secure-phase`).
- Schemas novos em `sheet_schema.dart`: `lotesSchema`, `piquetesSchema`, `gastosSchema` (categoria reusa `kExpenseCategoryLabels`); `BulkRepository` +3 métodos.

### GRID-03 — hub /planilhas
- `PlanilhasHubScreen`: 7ª branch do shell (item "Planilhas" no rail/drawer desktop; bottom nav mobile continua com 5). Chips de entidade (Animais, Lotes, Piquetes, Doses, Gastos), Export + Importar por entidade, grade da entidade ativa.
- Grades novas de lotes (nome + piquete via dropdown), piquetes (nome/área/capacidade) e gastos (data/piquete/categoria/valor/descrição — só manuais; sanitárias são snapshot) usando `gridColumnsFromSchema` + `{'id': rowId, ...values}` → RPCs.
- Mobile: grade desativada com EmptyState explicativo; export/import funcionam. Papel sem escrita: EmptyState "somente leitura" + export.
- **Import estendido às 3 entidades novas**: `ImportContext.paddockNamesLower`, validação client-side (piquete existe, valores > 0, update por nome), commit no `import_flow_screen`, textos "como funciona" e destinos pós-import.
- Aplicações sanitárias e DG ficam fora da edição do hub de propósito (imutáveis / fluxo próprio no IATF) — entrada em massa continua em `/sanitario/grade` e no DG do IATF.

## Verificação
- `flutter analyze`: 0 erros/warnings.
- `flutter test`: 578/578 (4 novos).
- PROD: catálogo confirma 3 funções SECURITY DEFINER com EXECUTE para authenticated; probes 12/12 com rollback.
