# Roadmap — Campo Gestor

## Milestones

- ✅ **v1.0 MVP** — Fases 0–11 (shipped 2026-08-21) — [arquivo](./milestones/v1.0-ROADMAP.md)
- 🚧 **v1.1** — em definição (`/gsd-new-milestone`)

## Phases

<details>
<summary>✅ v1.0 MVP (Fases 0–11) — SHIPPED 2026-08-21</summary>

- [x] Fase 0: Foundation (6/6)
- [x] Fase 1: Auth & Multi-tenancy Core (3 planos, UAT 4/4)
- [x] Fase 2: Property & Paddock Structure (UAT 9/10)
- [x] Fase 3: Lots & Animals — Operational Core (UAT 5/5)
- [x] Fase 4: Movements (7 planos, UAT 8/8)
- [x] Fase 5: Reproductive Module IATF (15 planos)
- [x] Fase 6: Sanitary Module — Snapshot (14 planos, UAT 11/11)
- [x] Fase 7: Expenses by Paddock (8 planos, UAT 7/7)
- [x] Fase 8: Animal Dossier Consolidation (5 planos, UAT 15/15)
- [x] Fase 9: Redesign UI/UX "musgo evoluído" (retroativa, UAT visual 2026-08-15)
- [x] Fase 10: Gestão de Membros e Ciclo de Vida da Propriedade (11 planos, pgTAP 81/81)
- [x] Fase 11: Planilhas e ajustes UX (retroativa 2026-08-20, pgTAP 15/15)

Detalhes completos: [milestones/v1.0-ROADMAP.md](./milestones/v1.0-ROADMAP.md)

</details>

### 🚧 v1.1 — Acesso, Consistência e Planilhas

#### Fase 12: Acesso e edição de piquete/lote

**Goal:** Toda entidade estrutural (piquete, lote) é editável/arquivável a partir de onde o usuário a vê — board desktop, detalhe e painel — fechando o bug de clique morto no board.
**Requirements:** ACES-01, ACES-02, ACES-03
**Depends on:** —

Plans:

- [ ] 12-01 — onTap + menu Editar/Arquivar no header de `_PaddockColumn` (board desktop); ações Editar/Arquivar no AppBar de `PaddockDetailScreen`
- [ ] 12-02 — Editar nome/Arquivar em `LoteDetailScreen` e `LoteDetailPanel` (extrair `_archiveLot` de `LotsSection` para reuso)

#### Fase 13: Consistência visual + Sanitário

**Goal:** Um só sistema visual: históricos pré-redesign migrados, contraste WCAG dos chips, tema de botões único, FABs gated, confirmações padronizadas, e a tela Sanitário alinhada às demais listas (busca incluída).
**Requirements:** VIS-01..VIS-08
**Depends on:** —

Plans:

- [ ] 13-01 — VIS-01 históricos sanitário/reprodutivo → SectionCard/StatusChip/AppColors
- [ ] 13-02 — VIS-02 chipTheme contraste + VIS-03 radius 14 no tema (remover overrides)
- [ ] 13-03 — VIS-04 FABs/paddings + VIS-06 confirmações + VIS-07 DetailAppBar em gastos + VIS-08 empty states
- [ ] 13-04 — VIS-05 Sanitário: busca, header/table view, filtros desktop

#### Fase 14: Hub Planilhas ("modo Excel")

**Goal:** Menu "Planilhas" com todas as entidades editáveis em grade estilo Excel — grade derivada de SheetSchema, novas entidades (lotes, piquetes, gastos) com RPCs bulk transacionais e export/import.
**Requirements:** GRID-01, GRID-02, GRID-03
**Depends on:** Fase 13 (tema estável)

Plans:

- [ ] 14-01 — GRID-01 EditableGrid derivado de SheetSchema
- [ ] 14-02 — GRID-02 migration bulk_upsert_lots/paddocks/expenses + pgTAP + schemas
- [ ] 14-03 — GRID-03 tela hub /planilhas + item de menu + export/import por entidade

## Progress

| Fase | Milestone | Status |
| --- | --- | --- |
| 0–11 | v1.0 | ✅ Complete (76/76 planos) |
| 12 | v1.1 | Not started |
| 13 | v1.1 | Not started |
| 14 | v1.1 | Not started |
