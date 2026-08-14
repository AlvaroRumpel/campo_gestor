---
phase: quick-260813-vvh
plan: 01
subsystem: ui
tags: [flutter, riverpod, sanitario, desktop, tabela, adaptive-ui]

requires:
  - phase: quick-260813-v19
    provides: Breakpoints.rail (1024px) shell adaptativo desktop, molde de tabela densa (animais_table_view.dart, lotes_table_view.dart)
provides:
  - AplicacoesTableView e DosesTableView (lib/features/sanitario/presentation/sanitario_table_views.dart), tabelas densas desktop para /sanitario
  - confirmEstorno top-level (estornar_aplicacao_dialog.dart) — único dono do fluxo de escrita de estorno, usado pela ficha e pela tabela
  - Branch desktop em SanitarioScreen (header + tabelas >=1024px, cards/FAB intactos abaixo disso)
affects: [sanitario, redesign-desktop]

tech-stack:
  added: []
  patterns:
    - "Tabela densa desktop molde animais_table_view.dart/lotes_table_view.dart: larguras de coluna declaradas como const de arquivo, _HeaderText privado mono 10.5/700, linha 44px InkWell+hoverColor+Opacity para estado esmaecido"
    - "Helper de escrita compartilhado extraído para top-level function (confirmEstorno) quando duas superfícies (ficha + tabela) precisam do mesmo fluxo de dialog+invalidations+snackbar"

key-files:
  created:
    - lib/features/sanitario/presentation/sanitario_table_views.dart
    - test/widget/sanitario_desktop_test.dart
  modified:
    - lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart
    - lib/features/sanitario/presentation/aplicacao_detail_screen.dart
    - lib/features/sanitario/presentation/sanitario_screen.dart

key-decisions:
  - "confirmEstorno extraído como função top-level em estornar_aplicacao_dialog.dart (não um mixin/classe) — mínimo diff, único dono das 5 invalidações"
  - "IconButtons de ação da tabela de doses encolhidos (VisualDensity.compact, 28px, ícone 16px) para caber 2 ações na coluna de 92px sem overflow"

patterns-established:
  - "Duas tabelas que compartilham anatomia (_HeaderText, formatação mono) ficam em um único arquivo _table_views.dart quando a divisão em dois arquivos duplicaria só boilerplate"

requirements-completed: []

coverage:
  - id: D1
    description: "Aba Aplicações em >=1024px mostra AplicacoesTableView (data, produto, lote, piquete, animais, UA, custo, status) em vez dos cards mobile"
    verification:
      - kind: automated_ui
        ref: "test/widget/sanitario_desktop_test.dart#1440x900, aba Aplicações: AplicacoesTableView renders with a PIQUETE column header"
        status: pass
    human_judgment: false
  - id: D2
    description: "Aplicação estornada aparece riscada/esmaecida na tabela e nunca some — visibilidade continua governada pelo toggle Mostrar estornadas"
    verification:
      - kind: automated_ui
        ref: "test/widget/sanitario_desktop_test.dart#1440x900, aba Aplicações com \"Mostrar estornadas\" ligado: a linha estornada continua na tabela com o chip \"Estornada\""
        status: pass
    human_judgment: false
  - id: D3
    description: "Aba Doses em >=1024px mostra DosesTableView (<=1040px) com ML/UA, R$/UA calculados via resolveActiveKgPerUa e nota de rodapé kg/UA"
    verification:
      - kind: automated_ui
        ref: "test/widget/sanitario_desktop_test.dart#1440x900, aba Doses: DosesTableView renders with an ML/UA header and a kg/UA footer note"
        status: pass
    human_judgment: false
  - id: D4
    description: "Dose arquivada aparece esmaecida com chip Arquivada e ação de desarquivar (Reativar dose)"
    verification:
      - kind: automated_ui
        ref: "test/widget/sanitario_desktop_test.dart#1440x900, aba Doses com \"Mostrar arquivadas\" ligado: chip \"Arquivada\" e ação \"Reativar dose\" aparecem"
        status: pass
    human_judgment: false
  - id: D5
    description: "Abaixo de 1024px as duas abas continuam byte a byte as listas de cards atuais, sem FAB alterado"
    verification:
      - kind: automated_ui
        ref: "test/widget/sanitario_desktop_test.dart#800x600, as duas abas: nem AplicacoesTableView nem DosesTableView aparecem — caminho mobile intacto"
        status: pass
      - kind: unit
        ref: "flutter test (suíte completa, 408 testes) — nenhum teste existente editado"
        status: pass
    human_judgment: false
  - id: D6
    description: "Estornar a partir da tabela e a partir da ficha usam o mesmo confirmEstorno (mesma lista de invalidações)"
    verification:
      - kind: unit
        ref: "test/widget/aplicacao_detail_screen_test.dart (suíte completa passa sem edição, confirma o único ponto de escrita da ficha)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-13
status: complete
---

# Quick Task 260813-vvh: Sanitário em tabela densa desktop Summary

**AplicacoesTableView e DosesTableView levam as duas abas de /sanitario ao layout de tabela densa a partir de 1024px, com um `confirmEstorno` único compartilhado entre ficha e tabela.**

## Performance

- **Duration:** 20 min
- **Completed:** 2026-08-13T23:22:34-03:00
- **Tasks:** 3
- **Files modified:** 5 (2 criados, 3 modificados)

## Accomplishments
- `AplicacoesTableView` e `DosesTableView` (novo arquivo `sanitario_table_views.dart`), moldadas em `animais_table_view.dart`/`lotes_table_view.dart` — larguras de coluna declaradas uma vez, `_HeaderText` privado, linha 44px com hover
- `confirmEstorno` extraído para função top-level em `estornar_aplicacao_dialog.dart`, chamada tanto pela ficha (`AplicacaoDetailScreen`) quanto pela nova linha da tabela — único dono das 5 invalidações de provider
- `SanitarioScreen` ganhou um `LayoutBuilder` + `Breakpoints.rail`: header desktop (título, subtítulo mono agregado, botão primário) e ausência de FAB em >=1024px; segmented realinhado à esquerda a 320px nesse modo
- `test/widget/sanitario_desktop_test.dart` novo, cobrindo os dois breakpoints nas duas abas (5 casos)

## Task Commits

Each task was committed atomically:

1. **Task 1: Tabelas de Aplicações e Doses + helper de estorno compartilhado** - `2ee0306` (feat)
2. **Task 2: Branch desktop em SanitarioScreen (header + tabelas a partir de 1024px)** - `7d698c2` (feat)
3. **Task 3: Teste widget dos dois breakpoints** - `c8c79af` (test)

_Nenhum commit de metadados (docs) — `commit_docs` não solicitado nesta execução; SUMMARY.md fica no worktree para o orquestrador coletar._

## Files Created/Modified
- `lib/features/sanitario/presentation/sanitario_table_views.dart` - `AplicacoesTableView` (linha com data/produto/lote/piquete/animais/UA/custo/status + ação de estorno) e `DosesTableView` (<=1040px, ML/KG-UA, R$/KG-UA, nota de rodapé kg/UA)
- `lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart` - ganhou `confirmEstorno` top-level (dialog + 5 invalidações + snackbar)
- `lib/features/sanitario/presentation/aplicacao_detail_screen.dart` - perdeu o `_confirmEstorno` privado; botão "Estornar" chama `confirmEstorno`
- `lib/features/sanitario/presentation/sanitario_screen.dart` - `LayoutBuilder`/`Breakpoints.rail`, header desktop, `_filteredApplications` extraído, ambas as abas roteiam para as novas tabelas em >=1024px
- `test/widget/sanitario_desktop_test.dart` - novo, 5 casos (2 aba Aplicações, 2 aba Doses, 1 mobile-intacto)

## Decisions Made
- `confirmEstorno` é função top-level, não método de classe/mixin — menor diff, evita acoplar a tabela a um widget stateful só para reusar o fluxo
- Subtítulo do header desktop soma valores brutos (sem `abs()`) de `totalUa`/`totalCost`, para que uma linha de estorno cancele a original quando "Mostrar estornadas" está ligado — `abs()` continua só na exibição por linha
- Ícones de ação da `DosesTableView` (editar/arquivar) reduzidos a `VisualDensity.compact` + 28px + ícone 16px para caber lado a lado nos 92px da coluna sem overflow

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RenderFlex overflow nos IconButtons da coluna de ações de DosesTableView**
- **Found during:** Task 3 (primeira execução de `sanitario_desktop_test.dart`)
- **Issue:** Dois `IconButton`s de 36x36 (editar + arquivar) dentro de uma `SizedBox(width: 92)` estouravam 4px — o `Row` reportava `RenderFlex overflowed`, falhando 3 dos 5 testes novos por erro capturado pelo `FlutterError.onError` do `flutter_test`
- **Fix:** `visualDensity: VisualDensity.compact`, `constraints: BoxConstraints.tightFor(width: 28, height: 28)`, ícone reduzido para 16px em ambos os `IconButton`s
- **Files modified:** `lib/features/sanitario/presentation/sanitario_table_views.dart`
- **Verification:** `flutter test test/widget/sanitario_desktop_test.dart` — 5/5 passam; `flutter test` completo — 408/408 passam
- **Committed in:** `c8c79af` (commit da Task 3, junto com o teste que descobriu o bug)

---

**Total deviations:** 1 auto-fixed (1 bug de layout)
**Impact on plan:** Correção de renderização estritamente dentro do arquivo criado por este plano; nenhum escopo adicional, nenhuma mudança de comportamento fora da coluna de ações.

## Issues Encountered
None além do deviation acima.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `/sanitario` fica coerente com o resto do módulo desktop (Animais, Lotes, Reprodução, Piquetes já em tabela/kanban) — não há mais tela do redesign presa ao layout mobile em telas largas
- Nenhum blocker identificado; verificação visual manual (`flutter run -d chrome`) listada no plano como opcional/não bloqueante e não foi executada nesta sessão

---
*Phase: quick-260813-vvh*
*Completed: 2026-08-13*

## Self-Check: PASSED

- FOUND: lib/features/sanitario/presentation/sanitario_table_views.dart
- FOUND: test/widget/sanitario_desktop_test.dart
- FOUND: .planning/quick/260813-vvh-sanitario-e-doses-em-tabela-desktop-apli/260813-vvh-SUMMARY.md
- FOUND commit: 2ee0306 (Task 1)
- FOUND commit: 7d698c2 (Task 2)
- FOUND commit: c8c79af (Task 3)
