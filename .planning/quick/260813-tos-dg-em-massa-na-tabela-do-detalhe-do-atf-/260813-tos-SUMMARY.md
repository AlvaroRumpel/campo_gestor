---
phase: quick
plan: 260813-tos
subsystem: ui
tags: [flutter, riverpod, reproducao, atf, dg, desktop-table]

requires:
  - phase: quick-260813-r4s
    provides: ATF list mestre-detalhe desktop (ReproducaoTableView + AtfDetailPanel)
provides:
  - AtfDgTableView — tabela desktop densa do detalhe do ATF (>=1024px) com registro
    de DG inline por linha e barra contextual de seleção múltipla
  - latestDgFor(records, animalId) — regra de desempate por examDate (G-05-4)
    extraída para dg_summary.dart, compartilhada por mobile e desktop
affects: [reproducao, atf-detail]

tech-stack:
  added: []
  patterns:
    - "Tabela desktop densa (Row+Expanded, larguras/flex const no topo do arquivo)
       reusada pela terceira vez (animais_table_view, reproducao_table_view,
       agora atf_dg_table_view) — mesmo idioma de header mono + linha 44px + hover"
    - "Escrita única por widget (_registerDg) compartilhada entre ação individual
       (lista de 1) e ação em lote (lista de N) sobre a mesma RPC"

key-files:
  created:
    - lib/features/reproducao/presentation/atf_dg_table_view.dart
    - test/widget/atf_detail_desktop_test.dart
  modified:
    - lib/features/reproducao/data/dg_summary.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart

key-decisions:
  - "_registerDg limpa toda a seleção (_selectedIds.clear()) em qualquer sucesso,
     inclusive quando chamado pelo botão inline de uma linha não selecionada —
     comportamento explícito do plano (\"limpar a seleção\"), não um removeAll
     restrito aos ids afetados"

requirements-completed: [REPR-03, REPR-04]

coverage:
  - id: D1
    description: "Tabela desktop (>=1024px) mostra fêmeas em Nº/categoria+raça/lote/IA/DG/resultado"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_desktop_test.dart#1440x900 renderiza AtfDgTableView e não renderiza AtfHeaderCard"
        status: pass
    human_judgment: false
  - id: D2
    description: "Abaixo de 1024px o fluxo mobile de hoje continua intacto, sem edição do teste existente"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_desktop_test.dart#800x600 renderiza AtfHeaderCard e nenhum AtfDgTableView — fluxo de hoje intacto"
        status: pass
      - kind: unit
        ref: "git diff --exit-code -- test/widget/atf_detail_screen_test.dart (zero linhas alteradas)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Botão Prenhe/Vazia inline registra DG do animal via saveDgRecords, mesma RPC do mobile"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_desktop_test.dart#Desktop: clicar \"Prenhe\" na linha de um animal sem DG chama saveDgRecords uma vez..."
        status: pass
    human_judgment: false
  - id: D4
    description: "Seleção múltipla + barra contextual registra DG em lote numa única chamada saveDgRecords"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_desktop_test.dart#Desktop: marcar os checkboxes de dois animais mostra \"2 selecionadas\" e \"Marcar vazia\" envia UM payload..."
        status: pass
    human_judgment: false
  - id: D5
    description: "Tocar o mesmo resultado já registrado é no-op (registro é sempre aditivo, nunca update/delete)"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_desktop_test.dart#Desktop: numa linha cujo DG mais recente já é pregnant, clicar \"Prenhe\" não chama saveDgRecords..."
        status: pass
    human_judgment: false
  - id: D6
    description: "Papel reader (sem canEdit): tabela somente leitura, sem checkbox e sem botões de resultado"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_desktop_test.dart#Desktop com papel reader: nenhum Checkbox e nenhum botão de resultado na tabela"
        status: pass
    human_judgment: false
  - id: D7
    description: "latestDgFor compartilhado entre mobile e desktop — mesma regra de desempate G-05-4"
    verification:
      - kind: unit
        ref: "flutter test (392/392) — os testes G-05-4 pré-existentes de atf_detail_screen_test.dart continuam verdes com _mostRecentDg delegando para latestDgFor"
        status: pass
    human_judgment: false
  - id: D8
    description: "Nenhum método novo no AtfRepository, nenhuma query nova ao PostgREST"
    verification:
      - kind: other
        ref: "git diff --name-only -- lib/features/reproducao/data/atf_repository.dart (0 linhas)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-14
status: complete
---

# Quick Task 260813-tos: DG em massa na tabela do detalhe do ATF Summary

**Tabela desktop densa (>=1024px) no detalhe do ATF com registro de DG inline por
linha e barra contextual de seleção múltipla — mesma RPC `saveDgRecords`/
`removeAnimalFromAtf` que o fluxo mobile já usa, zero SQL novo.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-14T00:20:00Z (approx.)
- **Completed:** 2026-08-14T00:49:00Z
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- `AtfDgTableView` novo: tabela densa (checkbox, Nº, categoria·raça, lote, IA, DG,
  resultado) a partir de `Breakpoints.rail`, substituindo o header verde + lista
  mobile de hoje só quando `>=1024px`.
- Registro de DG inline por linha (Prenhe/Vazia), com no-op para re-registrar o
  mesmo resultado e chip "Duvidosa" quando o DG mais recente é `doubtful`.
- Seleção múltipla com barra contextual (fundo `AppColors.primaryDarkText`):
  "Marcar prenhe"/"Marcar vazia" em lote numa única chamada `saveDgRecords`, e
  "Remover do ATF" gated como o ícone mobile (D-08).
- `latestDgFor` extraído para `dg_summary.dart` — mobile (`_mostRecentDg`) e
  desktop agora compartilham a mesma implementação da regra de desempate G-05-4.
- Abaixo de `Breakpoints.rail`, `test/widget/atf_detail_screen_test.dart` passa
  sem uma linha editada.

## Task Commits

Each task was committed atomically:

1. **Task 1: latestDgFor compartilhado + tabela desktop somente-leitura** - `b41d689` (feat)
2. **Task 2: registro de DG inline + seleção múltipla com barra contextual** - `a5f6838` (feat)
3. **Task 3: teste de widget dos dois lados do corte de 1024px** - `77cfc65` (test)

_Plan metadata commit not created per constraints — SUMMARY.md is collected by the orchestrator from the worktree._

## Files Created/Modified
- `lib/features/reproducao/presentation/atf_dg_table_view.dart` - Tabela desktop nova: bloco de topo (nome + badge + subtítulo mono), barra contextual, cabeçalho de colunas, linhas com registro inline
- `test/widget/atf_detail_desktop_test.dart` - 6 testWidgets cobrindo os dois lados do corte de 1024px, registro individual, DG em lote, no-op de re-registro, e papel reader
- `lib/features/reproducao/data/dg_summary.dart` - `latestDgFor(records, animalId)` extraído como fonte única do desempate por examDate
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - `body` envolvido em `LayoutBuilder`; `_mostRecentDg` delega para `latestDgFor`

## Decisions Made
- `_registerDg` limpa `_selectedIds` inteiro em qualquer sucesso (não apenas os ids
  afetados) — segue literalmente a instrução do plano ("limpar a seleção") tanto
  para o caminho individual quanto o de lote, mantendo os dois caminhos idênticos
  no bloco de sucesso.
- Subtítulo mono do bloco de topo usa `DateFormat('dd/MM')` (sem ano), distinto do
  formato `dd/MM/yy` usado na coluna IA da tabela — os dois formatos coexistem no
  arquivo por decisão explícita do plano (assunção 5 vs. tabela da assunção 7).

## Deviations from Plan

None - plan executed exactly as written, incluindo as 14 `planner_assumptions`.

## Issues Encountered

Nenhum. `flutter analyze --no-fatal-infos` ficou limpo (warning `unused_element`
de `_kColCheckbox` na Task 1 foi corrigido movendo a constante para a Task 2,
onde a coluna de checkbox realmente entra em uso — não é um desvio de escopo, é
o próprio design faseado do plano).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Tabela desktop do ATF pronta para uso; nenhum follow-up bloqueante.
- `flutter analyze --no-fatal-infos` limpo e suíte inteira verde (392/392).
- Deploy + UAT visual (browser) seguem pendentes, como já registrado em STATE.md
  para o restante do redesign desktop.

---
*Phase: quick*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: `lib/features/reproducao/presentation/atf_dg_table_view.dart`
- FOUND: `test/widget/atf_detail_desktop_test.dart`
- FOUND: `.planning/quick/260813-tos-dg-em-massa-na-tabela-do-detalhe-do-atf-/260813-tos-SUMMARY.md`
- FOUND commit `b41d689` (Task 1)
- FOUND commit `a5f6838` (Task 2)
- FOUND commit `77cfc65` (Task 3)
