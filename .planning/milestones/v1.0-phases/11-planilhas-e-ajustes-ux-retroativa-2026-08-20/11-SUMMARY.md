# Phase 11 — Planilhas e ajustes UX — SUMMARY (registro retroativo)

**Executado:** 2026-08-20 · fora do fluxo plan/execute (sessões diretas com o usuário; spec da feature planilhas em `docs/superpowers/specs/2026-08-19-planilhas-design.md`)
**Status:** completa — pgTAP 15/15, `flutter test` verde, curadoria UI/UX validada pelo usuário em sessão. Registro retroativo criado em 2026-08-21 para fechamento do milestone v1.0 (mesmo padrão da Fase 9).

## O que foi entregue

### Feature Planilhas — export/import/grade (`b896498`..`07081da`)
- `SheetSchema` por entidade como fonte única de colunas (`lib/features/planilhas/domain/sheet_schema.dart`): animais, doses, sanitário, DG; auto-match de cabeçalhos com aliases normalizados.
- Export .xlsx/.csv em Animais, Sanitário (aplicações + doses) e DG.
- Import em 3 passos (arquivo → mapear colunas → revisar) com validação client-side, `ColumnMappingStore` (mapeamento lembrado por entidade+hash de header), limite 5000 linhas.
- RPCs `bulk_upsert_animals`, `bulk_upsert_doses`, `bulk_register_sanitary` (migration `20260820_15_bulk_sheets.sql`) — SECURITY DEFINER, guard `assert_vet_of`, erro `linha N: motivo`, transação all-or-nothing; pgTAP 15/15 (formato SQL editor, sem Docker).
- `EditableGrid` genérico (dirty-tracking por célula, Tab/Enter/Esc, Ctrl+V de bloco TSV do Excel, validação tipada, save bar) + grades de Animais e catálogo de Doses.
- Aplicação sanitária em grade multi-dose (`/sanitario/grade`): matriz animais × doses com totais de custo/volume por dose, salva via `bulk_register_sanitary`.

### Rename ATF → IATF (`e090f22`, breaking)
- Todo o sistema (UI, rotas, código, testes) passa a usar IATF; migrations renomeadas para versões únicas do CLI (`505b1a3`).

### Ajustes UX/QA (`f42116e`..`d779cb8`)
- IATF: horário de inseminação + valor do serviço no cadastro; DG Prenhe/Vazia acumula cliques com debounce 2s.
- Lotes: seleção múltipla de animais para mover em massa.
- Sanitário: modal de dose com R$/dose → R$/kg calculado; tabela de doses com respiro.
- Modais de IATF e dose confirmam antes de fechar com dados digitados; coluna Observação truncada na tabela de animais.
- Grade: search-select de raça e ECC via `RawAutocomplete` (overlay na raiz, sem clip), borda de foco, ordem ascendente na grade sanitária.
- Curadoria de consistência/contraste (`a3728ab`, `a1d1ac7`): contraste do Descartar, voltar nas telas fora do shell, plurais.

## Decisões
- Escrita em massa só via RPCs `bulk_*` — nunca N requests (convenção registrada no CLAUDE.md, `4c388f3`).
- Import all-or-nothing: qualquer linha inválida faz rollback da transação inteira.
- Aplicações sanitárias continuam imutáveis; grade sanitária é entrada em massa (create-only), não edição.
- `EditableGrid` construído sobre `GridColumn` próprio (não sobre `SheetSchema` diretamente) — dívida conhecida, unificação prevista para o hub Planilhas (v1.1).

## Verificação
- pgTAP das RPCs bulk: 15/15 (replay em PROD via SQL editor dentro de BEGIN…ROLLBACK).
- `flutter test` verde após correção de colisão de número no assert de rollback (`e56e923`).
- UAT informal contínua com o usuário durante as sessões de 2026-08-20 (QA Sturza + curadoria).

## Commits
30 commits em 2026-08-20 — principais: `b896498` RPCs bulk + pgTAP · `76d87ff` SheetSchema · `66ea3fe` import 3 passos · `ac7ece7` EditableGrid · `9df7503` grade animais · `7964163` grade doses · `f5daf3e` grade sanitária multi-dose · `07081da` integração export/import/grade · `e090f22` rename IATF · `f42116e` ajustes UX · `d3a32e8` mover em massa · `a3728ab`/`a1d1ac7` curadoria UI/UX · `d779cb8` search-select + contraste
