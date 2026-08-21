# Requirements — Campo Gestor v1.1

**Milestone:** v1.1 — Acesso, Consistência e Planilhas
**Criado:** 2026-08-21 (escopo aprovado pelo usuário na sessão de auditoria UI/UX)

## Requisitos

### Acesso e edição (Fase 12)

- [x] **ACES-01** — Piquete clicável no board desktop: cabeçalho da coluna em `PiquetesBoardView` abre `/piquetes/:id` e expõe menu Editar/Arquivar (hoje só o mobile tem).
- [x] **ACES-02** — Editar/arquivar piquete alcançável a partir do detalhe: `PaddockDetailScreen` ganha ações Editar e Arquivar no AppBar (role-gated).
- [x] **ACES-03** — Renomear/arquivar lote alcançável fora do detalhe do piquete: `LoteDetailScreen` e `LoteDetailPanel` expõem Editar nome/Arquivar (hoje só no popup escondido de `LotsSection`).

### Consistência visual (Fase 13)

- [x] **VIS-01** — `sanitary_history_section.dart` e `animal_reproductive_history_section.dart` alinhados ao padrão do redesign (`SectionCard` r16 sem borda, `StatusChip`, `AppColors`, `EmptyState`).
- [x] **VIS-02** — Contraste de chips selecionados ≥ 4.5:1 via `chipTheme` (label resolve em `WidgetState.selected`); remoção dos overrides locais redundantes.
- [x] **VIS-03** — Radius de botão unificado: tema passa a 14, overrides por chamada removidos.
- [x] **VIS-04** — Conteúdo não passa mais sob o FAB (bottom padding 96 em reprodução e detalhe do piquete). *Ajuste de escopo na execução:* FABs mantidos sem gate `isDesktop` — nas telas apontadas o FAB é a única affordance de criação; gateá-lo removeria a função (ver 13-SUMMARY).
- [x] **VIS-05** — Sanitário alinhado ao padrão de lista: busca, header dentro da table view no desktop, filtros via `FilterMenuChip` (sem bottom-sheet em desktop), chips/segmented no padrão.
- [x] **VIS-06** — Confirmações destrutivas padronizadas em `showAdaptiveForm`.
- [x] **VIS-07** — Tela de gastos do piquete usa `DetailAppBar` (fim do AppBar cru).
- [x] **VIS-08** — Empty states desktop usam `EmptyState` (fim do `Text` cru nas table views).

### Hub Planilhas (Fase 14)

- [x] **GRID-01** — `EditableGrid` deriva colunas de `SheetSchema` (fim da duplicação `GridColumn` manual por tela).
- [x] **GRID-02** — `SheetSchema` + RPCs `bulk_upsert_lots` / `bulk_upsert_paddocks` / `bulk_upsert_expenses` (template de `bulk_upsert_doses`), com pgTAP.
- [x] **GRID-03** — Tela hub `/planilhas` no menu: seletor de entidade (animais, doses, lotes, piquetes, gastos) com grade + export + import por entidade.

## Out of Scope (v1.1)

- Grade de IATF/memberships — write path passa por RPCs próprios com invariantes; fica para depois do hub estabilizar.
- Edição em grade de aplicações sanitárias — snapshot imutável por design; grade sanitária existente é entrada em massa (create-only).
- Site URL do Supabase Auth — ação manual do usuário no dashboard (não é código).
