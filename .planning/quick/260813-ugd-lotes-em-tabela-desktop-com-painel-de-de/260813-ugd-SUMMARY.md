---
phase: quick-260813-ugd
plan: 01
subsystem: ui
tags: [flutter, riverpod, master-detail, responsive, lotes, piquetes]

requires:
  - phase: quick-260813-r4s
    provides: master-detail desktop pattern (ReproducaoTableView + AtfDetailPanel) reused as the mold
provides:
  - LotesTableView — dense, UA-sortable table for the Lotes tab at >=1024px
  - LoteDetailPanel — 380px master-detail side panel with the lot's existing actions
  - PiquetesScreen desktop branch wired via LayoutBuilder(Breakpoints.rail), mobile path untouched
affects: [piquetes, lotes]

tech-stack:
  added: []
  patterns:
    - "Master-detail desktop screens (Animais, Reprodução, now Lotes) share the same shape: StatefulWidget table with a UA/metric sort toggle + ConsumerStatefulWidget 380px panel reusing the mobile screen's existing dialogs/actions"

key-files:
  created:
    - lib/features/lotes/presentation/lotes_table_view.dart
    - lib/features/lotes/presentation/lote_detail_panel.dart
    - test/widget/lotes_desktop_test.dart
  modified:
    - lib/features/piquetes/presentation/piquetes_screen.dart

key-decisions:
  - "Header subtitle aggregates (UA ocupada / capacidade / ha / UA por ha) computed inside LotesTableView from the paddocks + animalsByLot params it already receives — no new params needed"
  - "'N DGs pendentes' badge omitted (no cheap lot->ATF mapping exists) per planner_assumptions, matching the spec's own omission rule"
  - "'Ver na lista de animais' link navigates to the plain /animais route (no lot filter exists in AppRoutes)"

patterns-established:
  - "Novo lote from the Lotes tab (no paddock in context): a SimpleDialog picker chained into the existing LoteFormDialog(paddockId:, propertyId:) — zero new dialog widgets"

requirements-completed: []

coverage:
  - id: D1
    description: "LotesTableView renders instead of LotesListView at >=1024px on the Lotes tab, sorted by UA desc with a sortable UA column"
    verification:
      - kind: automated_ui
        ref: "test/widget/lotes_desktop_test.dart#1440x900 aba Lotes: LotesTableView renders, not LotesListView/LoteDetailPanel, with the aggregated mono subtitle"
        status: pass
      - kind: automated_ui
        ref: "test/widget/lotes_desktop_test.dart#sorts rows by UA desc by default (Lote A before Lote B)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Selecting a row opens LoteDetailPanel (380px) with the table still visible; panel exposes Aplicação/Mover lote actions and the animal-list link"
    verification:
      - kind: automated_ui
        ref: "test/widget/lotes_desktop_test.dart#tapping a lot row shows LoteDetailPanel; the table stays present"
        status: pass
      - kind: automated_ui
        ref: "test/widget/lotes_desktop_test.dart#panel shows Aplicação/Mover lote actions and the \"ver na lista\" link"
        status: pass
    human_judgment: false
  - id: D3
    description: "Below 1024px the Lotes tab still renders LotesListView (mobile path unchanged); Piquetes tab unaffected at any width"
    verification:
      - kind: automated_ui
        ref: "test/widget/lotes_desktop_test.dart#800x600 aba Lotes: no LotesTableView/LoteDetailPanel, LotesListView present — mobile path intact"
        status: pass
      - kind: unit
        ref: "test/widget/piquetes_screen_test.dart (unmodified, still green — 800x600 default surface exercises the mobile branch)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Visual polish of the new table/panel at real breakpoints (spacing, chip wrapping, hover states)"
    verification: []
    human_judgment: true
    rationale: "Widget tests confirm structure/behavior; pixel-level layout quality needs a human look at the real app."

duration: 45min
completed: 2026-08-13
status: complete
---

# Quick Task 260813-ugd: Lotes tabela desktop com painel de detalhe Summary

**Aba Lotes de /piquetes ganhou o mesmo padrão mestre-detalhe desktop de Animais/Reprodução: tabela densa ordenada por UA (>=1024px) + painel lateral de 380px com as ações existentes (Aplicação, Mover lote), sem tocar no caminho mobile.**

## Performance

- **Duration:** 45 min
- **Tasks:** 3 completed
- **Files modified:** 4 (3 new, 1 modified)

## Accomplishments
- `LotesTableView`: tabela densa com colunas LOTE/PIQUETE/COMPOSIÇÃO/CAB./UA/ÚLT. APLICAÇÃO/ALERTA, ordenação por UA com toggle no cabeçalho (default desc), composição em chips compactos com "+N", alerta de piquete lotado
- `LoteDetailPanel`: painel 380px com header verde + badge de UA, ações Aplicação/Mover lote reusando `AplicacaoFormDialog`/`MoverLoteDialog` sem nenhum método novo de repositório, composição em barras, até 6 animais com status reprodutivo, rodapé de última aplicação
- `PiquetesScreen` ganhou um `LayoutBuilder(Breakpoints.rail)`: aba Lotes em >=1024px troca para `Row(LotesTableView, LoteDetailPanel?)`; qualquer outra combinação de aba/largura permanece byte-a-byte igual ao código anterior
- "Novo lote" no cabeçalho da tabela abre um `SimpleDialog` de escolha de piquete e encadeia no `LoteFormDialog` já existente

## Task Commits

Each task was committed atomically:

1. **Task 1: LotesTableView — tabela densa de lotes (>=1024px)** - `5b74ac5` (feat)
2. **Task 2: LoteDetailPanel — painel lateral 380px do lote** - `8d9aa8a` (feat)
3. **Task 3: Ligar o branch desktop em PiquetesScreen + teste de largura** - `6a8f0ed` (feat)

## Files Created/Modified
- `lib/features/lotes/presentation/lotes_table_view.dart` - Tabela mestre-detalhe desktop de lotes, molde `reproducao_table_view.dart`
- `lib/features/lotes/presentation/lote_detail_panel.dart` - Painel lateral 380px, molde `atf_detail_panel.dart`/`animal_detail_panel.dart`
- `lib/features/piquetes/presentation/piquetes_screen.dart` - `LayoutBuilder` desktop branch + fluxo "Novo lote"
- `test/widget/lotes_desktop_test.dart` - 5 testes cobrindo tabela/painel 1440x900 e caminho mobile 800x600

## Decisions Made
- Agregados do subtítulo (UA ocupada/capacidade/ha/UA por ha) calculados dentro de `LotesTableView` a partir de `paddocks` + `animalsByLot`, que a tela já passa — evitou 3 parâmetros extras não previstos na lista original do plano
- Badge "N DGs pendentes" por lote omitido — confirmado como `planner_assumptions`: não existe mapeamento lote→ATF barato sem uma query por ATF
- Link "Ver os N na lista de animais" navega para `/animais` sem filtro (não existe rota de animais filtrada por lote)

## Deviations from Plan

None - plan executed exactly as written. The header subtitle aggregates were computed from already-passed params rather than added as new params, which is a within-plan implementation detail, not a scope change.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Todas as telas de lista do app agora têm o padrão mestre-detalhe desktop consistente (Animais, Reprodução, Lotes); Piquetes (cards com semáforo de lotação) permanece intencionalmente fora desse padrão por não ter um "detalhe" natural além da própria tela `/piquetes/:id` já existente
- Nenhum bloqueio para próximos quick tasks ou fases

---
*Phase: quick-260813-ugd*
*Completed: 2026-08-13*

## Self-Check: PASSED

- FOUND: lib/features/lotes/presentation/lotes_table_view.dart
- FOUND: lib/features/lotes/presentation/lote_detail_panel.dart
- FOUND: test/widget/lotes_desktop_test.dart
- FOUND commit: 5b74ac5
- FOUND commit: 8d9aa8a
- FOUND commit: 6a8f0ed
