---
phase: quick-260813-ugd
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/lotes/presentation/lotes_table_view.dart
  - lib/features/lotes/presentation/lote_detail_panel.dart
  - lib/features/piquetes/presentation/piquetes_screen.dart
  - test/widget/lotes_desktop_test.dart
autonomous: true
requirements: []
must_haves:
  truths:
    - "Em >=1024px com a aba Lotes ativa, a tela /piquetes mostra uma tabela de lotes ordenada por UA desc, não a lista de cards."
    - "Clicar numa linha da tabela abre um painel lateral de 380px com o lote selecionado; a tabela continua visível."
    - "A linha selecionada tem barra verde de 3px à esquerda (mesmo padrão de animais_table_view/reproducao_table_view)."
    - "O painel expõe as duas ações existentes do lote (Aplicação, Mover lote) com o mesmo gate do LoteDetailScreen."
    - "Abaixo de 1024px a aba Lotes continua renderizando LotesListView, e a aba Piquetes continua igual nas duas larguras."
  artifacts:
    - lib/features/lotes/presentation/lotes_table_view.dart
    - lib/features/lotes/presentation/lote_detail_panel.dart
    - test/widget/lotes_desktop_test.dart
  key_links:
    - "PiquetesScreen -> LayoutBuilder(Breakpoints.rail) + _showLots -> Row(LotesTableView, LoteDetailPanel)"
    - "LotesTableView/LoteDetailPanel -> loteWithPaddockListByPropertyProvider + animalListByPropertyProvider + paddockListProvider (providers já existentes, zero método novo de repositório)"
    - "LoteDetailPanel -> AplicacaoFormDialog / MoverLoteDialog (ações já existentes de LoteDetailScreen)"
  prohibitions:
    - "Nenhum método novo em LoteRepository, AnimalRepository, PaddockRepository ou SanitaryApplicationRepository."
    - "Nenhum arquivo de teste existente pode ser editado (git diff --exit-code sobre eles precisa passar)."
    - "Nenhuma cor literal (Color(0x...) / Colors.*) fora de AppColors, exceto Colors.transparent para a borda não-selecionada, igual às tabelas existentes."
---

<objective>
Levar a aba **Lotes** da tela `/piquetes` para o padrão mestre-detalhe desktop já consolidado em Animais (quick 260813-p10) e Reprodução (260813-r4s): a partir de `Breakpoints.rail` (1024px), a lista de cards vira uma tabela densa ordenada por UA e um painel lateral de 380px mostra o lote selecionado — o destino desktop do "Lote detalhe" mobile.

Purpose: fechar a última tela de lista que ainda usava layout mobile em telas largas, sem tocar em nada abaixo de 1024px.
Output: `lotes_table_view.dart`, `lote_detail_panel.dart`, o branch desktop em `piquetes_screen.dart` e `test/widget/lotes_desktop_test.dart`.
</objective>

<execution_context>
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/workflows/execute-plan.md
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

Molde mestre-detalhe (seguir tal e qual — mesma arquitetura, mesmas constantes de coluna, mesmo `_HeaderText`):
@lib/features/reproducao/presentation/reproducao_table_view.dart
@lib/features/reproducao/presentation/atf_detail_panel.dart
@lib/features/animais/presentation/animais_table_view.dart
@lib/features/animais/presentation/animal_detail_panel.dart

Tela e conteúdo a portar:
@lib/features/piquetes/presentation/piquetes_screen.dart
@lib/features/lotes/presentation/lotes_list_view.dart
@lib/features/lotes/presentation/lote_detail_screen.dart

Dados e tema:
@lib/features/lotes/data/lote_repository.dart
@lib/features/animais/data/animal_model.dart
@lib/features/animais/data/animal_constants.dart
@lib/core/theme/breakpoints.dart
@lib/core/widgets/ui.dart

Teste-molde (harness `setSurfaceSize` + overrides de provider):
@test/widget/reproducao_desktop_test.dart
@test/widget/piquetes_screen_test.dart
</context>

<planner_assumptions>
Levantamento de fontes de dados feito antes de planejar. Regra herdada dos tasks anteriores: **campo sem fonte de dados barata é omitido, não inventado.**

| Item do spec | Fonte | Decisão |
|---|---|---|
| Lote, Piquete | `loteWithPaddockListByPropertyProvider` → `LotWithPaddockCount{lot, paddockName, activeAnimalCount}` | INCLUÍDO |
| Composição (chips por categoria), Cab., UA | `animalListByPropertyProvider` → `AnimalWithContext{animal, paddockId, ...}` agrupado por `animal.lotId` + `kCategories`/`kUaWeights`/`calcTotalUa` | INCLUÍDO |
| Subtítulo mono (UA ocupadas / capacidade · ha · UA/ha) | `paddockListProvider` (`areaHa`, `uaCapacity`) + UA agregada dos animais ativos | INCLUÍDO |
| Últ. aplicação | `sanitaryApplicationListByPropertyProvider` (uma query por propriedade, já ordenada newest-first, tem `lotId` + `appliedAt`) | INCLUÍDO — 1 provider a mais na tela, 0 método novo de repositório |
| Badge "Piquete lotado" | UA por piquete (soma dos animais ativos com `paddockId == p.id`) vs `paddock.uaCapacity`, mesma regra `ratio >= 1.0` do `_PaddockCard` | INCLUÍDO |
| Badge "N DGs pendentes" por lote | **Não existe** mapeamento lote→ATF barato: `AtfSummary.dgSummary.pending` é por ATF, e a associação animal↔ATF só vem de `atfActiveMembershipsProvider(atfId)` (family, 1 query por ATF) | **OMITIDO** — o próprio spec autoriza ("só se o dado já estiver disponível barato, senão omitir") |
| Badge repro na lista de animais do painel | `animalReproStatusByPropertyProvider` → `Map<animalId, AnimalReproStatus>`, com `.label`/`.chipKind` prontos | INCLUÍDO (renderizado só quando `!= foraDoAtf`) |
| Link "Ver os N na lista de animais" **filtrada por lote** | `AppRoutes` não tem rota de animais com filtro/query de lote (`/animais` é branch do shell, `/animais/:id` é a ficha) | **NAVEGAÇÃO SIMPLES** para `AppRoutes.animais`, conforme o fallback previsto no spec |
| Botão "Novo lote" | `LoteFormDialog` **exige `paddockId`** (só existe fluxo a partir de um piquete). Na aba Lotes não há piquete no contexto. | INCLUÍDO com o mínimo de cola: um `SimpleDialog` de escolha de piquete alimentado pelo `paddockListProvider` já carregado, encadeando no `LoteFormDialog` existente. Nenhum diálogo/rota nova além dessa escolha. |
</planner_assumptions>

<tasks>

<task type="auto">
  <name>Task 1: LotesTableView — tabela densa de lotes (>=1024px)</name>
  <files>lib/features/lotes/presentation/lotes_table_view.dart</files>
  <action>
Criar `LotesTableView` como `StatefulWidget` (única razão do estado: o toggle de ordenação da coluna UA). Espelhar `reproducao_table_view.dart` linha a linha na estrutura: `ColoredBox(color: AppColors.surface)` → `Column(crossAxisAlignment: stretch)` com header da tela, faixa do segmented, faixa de cabeçalho de colunas, `Expanded(ListView.builder)` e rodapé de contagem.

Parâmetros (todos vindos da tela, sem `ref` novo aqui — este widget é `StatelessWidget`-de-dados): `lots` (`List<LotWithPaddockCount>`), `animalsByLot` (`Map<String, List<Animal>>` já filtrado por `deletedAt == null`), `paddocks` (`List<Paddock>`), `overloadedPaddockIds` (`Set<String>`), `lastApplicationByLot` (`Map<String, DateTime>`), `paddockCount`/`lotCount` para o segmented, `showLots`/`onShowLotsChanged`, `selectedId`/`onSelect`, `canEdit`, `onCreate`.

Header da tela (padding `fromLTRB(16, 14, 16, 10)`): título `'Piquetes e lotes'` em 24/w600 + subtítulo em `monoStyle(size: 13, color: AppColors.textSecondary)` no formato `'{uaOcupada} / {capacidadeTotal} UA · {ha} ha · {uaPorHa} UA/ha'`, todos os números formatados com um helper local `_fmt1` (1 casa, vírgula decimal, idêntico ao de `lotes_list_view.dart`). `uaPorHa` = uaOcupada/haTotal, 0 quando haTotal é 0. À direita, quando `canEdit`, `FilledButton.icon(Icons.add, 'Novo lote')` chamando `onCreate`.

Segunda faixa (`fromLTRB(16, 0, 16, 10)`): reusar o segmented control existente da tela. `_SegmentButton` hoje é privado em `piquetes_screen.dart`; promovê-lo para público **neste arquivo novo** não é possível sem quebrar a tela — em vez disso, no desktop use `AtfScopeChip` (já público, exportado por `reproducao_table_view.dart`) com `label: 'Piquetes'/'Lotes'` e as contagens, exatamente como a faixa de chips de `ReproducaoTableView`. O segmented de 42px continua sendo o de mobile, intocado.

Cabeçalho de colunas: `Container(minHeight: 36, color: AppColors.surfaceVariant, padding horizontal 14)` com o mesmo `_HeaderText` (mono 10.5 / w700 / letterSpacing 0.8 / `AppColors.primaryDarkText`) — copiar a classe privada, como `reproducao_table_view.dart` fez a partir de `animais_table_view.dart`. Larguras declaradas uma vez como constantes de topo de arquivo e reusadas por cabeçalho e linhas: `_kColCab = 56`, `_kColUa = 76`, `_kColUltima = 108`, `_kColAlerta = 132`; flexes `_kFlexLote = 3`, `_kFlexPiquete = 2`, `_kFlexComposicao = 4`. Colunas: LOTE · PIQUETE · COMPOSIÇÃO · CAB. (right) · UA (right) · ÚLT. APLICAÇÃO · ALERTA.

Coluna UA sortável: o `_HeaderText` de UA fica dentro de um `InkWell` que alterna `_uaAsc` (default `false` = desc) e exibe `Icons.arrow_drop_down`/`arrow_drop_up` de 16px ao lado do label. A lista renderizada é `[...lots]..sort()` por UA total do lote, respeitando `_uaAsc`. Empate resolve por `lot.name.compareTo`.

Linha (`_buildRow`): `InkWell(hoverColor: AppColors.rowHover, onTap: () => onSelect(item.lot.id))` sobre `Container(minHeight: 44, padding horizontal 14)` com `decoration` idêntica à de `ReproducaoTableView._buildRow` — `color: selected ? AppColors.rowSelected : null` e `Border(left: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 3), bottom: BorderSide(color: AppColors.divider))`. Conteúdo: nome do lote com `FontWeight.w700` + ellipsis; `item.paddockName` com ellipsis; composição num `Row` de chips compactos privados `_CatChip` (bg `AppColors.surfaceVariant`, r8, padding h7/v3, texto `'{n} '` em `monoStyle(12, w600)` + label de `kCategoryLabels`/`kCategoryLabelsPlural`, `overflow: TextOverflow.ellipsis` no `Row` via `Expanded` + `clipBehavior`), mostrando no máximo 3 categorias e um `_CatChip` final `'+N'` quando houver mais; contagem de cabeças em `monoStyle(13)` alinhada à direita; UA em `monoStyle(13, w700)` alinhada à direita; última aplicação em `monoStyle(12.5)` no formato `dd/MM/yy` (um `DateFormat` de topo de arquivo, como `_dateFmtShort`) ou o texto `'sem registro'` em 12.5/`AppColors.textTertiary`; alerta com `StatusChip('Piquete lotado', kind: StatusKind.danger)` quando `overloadedPaddockIds.contains(item.lot.paddockId)`, senão `SizedBox.shrink()`.

Vazio: `Center(child: Text('Nenhum lote cadastrado'))` no lugar do `ListView`. Rodapé: `Container(minHeight: 34, color: AppColors.surfaceVariant, alignment: centerRight)` com `'1–{n} de {n}'` em `monoStyle(11.5, color: AppColors.textSecondary)`.

Nenhuma cor literal fora de `AppColors` (a única exceção permitida é `Colors.transparent` na borda esquerda não-selecionada, igual às tabelas existentes). Todo número na UI usa `monoStyle`.
  </action>
  <verify>
    <automated>flutter analyze --no-fatal-infos lib/features/lotes/presentation/lotes_table_view.dart</automated>
    <automated>[ "$(grep -oE '(^|[^A-Za-z.])Colors\.[A-Za-z]+|Color\(0x' lib/features/lotes/presentation/lotes_table_view.dart | grep -cv 'Colors\.transparent')" -eq 0 ]</automated>
  </verify>
  <done>`lotes_table_view.dart` compila limpo, exporta `LotesTableView`, declara as 4 larguras + 3 flexes de coluna uma única vez, ordena por UA com toggle no cabeçalho, e não contém nenhuma cor literal além de `Colors.transparent`.</done>
</task>

<task type="auto">
  <name>Task 2: LoteDetailPanel — painel lateral 380px do lote</name>
  <files>lib/features/lotes/presentation/lote_detail_panel.dart</files>
  <action>
Criar `LoteDetailPanel` como `ConsumerWidget` de 380px, molde `atf_detail_panel.dart` / `animal_detail_panel.dart`: `Container(width: 380, decoration: BoxDecoration(color: AppColors.surface, border: Border(left: BorderSide(color: AppColors.divider))))` → `Column(crossAxisAlignment: stretch)`.

Parâmetros: `item` (`LotWithPaddockCount`), `activeAnimals` (`List<Animal>` do lote, já filtrado pela tela — **não** disparar `animalListByLotProvider`, os dados já vieram de `animalListByPropertyProvider`), `lastApplication` (`DateTime?`), `canEdit`, `onClose`.

Header verde (`color: AppColors.primary`, padding `fromLTRB(16, 10, 8, 16)`): linha com `OverlineLabel('Lote', color: AppColors.onGreenSecondary)` expandido + `IconButton(Icons.open_in_full, tooltip: 'Abrir lote')` que faz `context.push(AppRoutes.loteDetail(item.lot.id))` + `IconButton(Icons.close)` chamando `onClose`; depois o nome do lote em 22/w700/`AppColors.onGreen`; depois a linha `'{item.paddockName} · {n} {animal ativo|animais ativos}'` em 13.5/`AppColors.onGreenSecondary`; e à direita do nome o badge laranja retangular com a UA total — mesma decoração de `_LoteHeader` em `lote_detail_screen.dart` (`AppColors.accent`, r10, padding h11/v7, texto `monoStyle(15, w700, color: AppColors.onAccent)` no formato `'{ua} UA'`).

Ações (só quando `canEdit && item.lot.deletedAt == null && activeAnimals.isNotEmpty` — espelho exato do gate `showActions` de `LoteDetailScreen`): `Padding(all 12)` com `Row` de `FilledButton.icon(Icons.medical_services_outlined, 'Aplicação')` + `OutlinedButton.icon(Icons.swap_horiz, 'Mover lote')`, ambos `Expanded`. Reutilizar as ações existentes exatamente como `LoteDetailScreen` as invoca: `showDialog(AplicacaoFormDialog(lotId:, onRegistered:))` e `showAdaptiveForm<Map<String, String>>(MoverLoteDialog(lot:, activeAnimalCount:))`. Após sucesso, invalidar os providers que alimentam esta tela: `loteWithPaddockListByPropertyProvider`, `animalListByPropertyProvider` e `sanitaryApplicationListByPropertyProvider` (mais `sanitaryApplicationsByLotProvider(lotId)` no caso da aplicação, para o histórico da tela de detalhe não ficar velho). Mostrar o mesmo `SnackBar` das duas ações (`sanitaryRegisteredMessage(count)` e `'Lote movido para {paddockName}'`). Como há `await` + `context`/`ref` depois, este widget precisa ser `ConsumerStatefulWidget` se o analyzer reclamar de `use_build_context_synchronously` — nesse caso siga `animal_detail_panel.dart`, que já é stateful pelo mesmo motivo, e guarde com `if (!mounted) return`.

Corpo (`Expanded(SingleChildScrollView(padding: fromLTRB(14, 12, 14, 10)))`):
1. `OverlineLabel('Composição')` + as linhas de barra por categoria portadas de `_ComposicaoCard` (`lote_detail_screen.dart`): label da categoria (`kCategoryLabelsPlural`) em `SizedBox(width: 88)`, `Expanded(StackedBar(height: 10, segments: [StackedBarSegment(count/total, cor rotativa)]))` com a mesma lista de 3 cores (`AppColors.primary`, `greenMid`, `greenLight`), e `SizedBox(width: 62)` à direita com `'{n} · {ua}'` em `monoStyle(13)`, `textAlign: right`. Ordem por `kCategories`, só categorias presentes. Sem animais ativos: texto `'Sem animais ativos.'` em 13.5/`AppColors.textSecondary`.
2. `OverlineLabel('Animais')` + no máximo 6 linhas (`activeAnimals` ordenado por `number`), cada uma um `InkWell` para `AppRoutes.animalDetail(a.id)` com: número em `monoStyle(15, w700)` numa `SizedBox(width: 42)`; `Expanded` com `'{categoria} · {raça}'` (raça omitida quando nula/vazia) em 13.5; `StatusChip(status.label, kind: status.chipKind)` quando `animalReproStatusByPropertyProvider[a.id]` existir e for diferente de `AnimalReproStatus.foraDoAtf`; e `'EC {n}'` em `monoStyle(12.5, color: AppColors.textSecondary)` quando `bodyCondition != null`.
3. Link final `TextButton` com o texto `'Ver os {n} na lista de animais'` (`n` = total de animais ativos do lote) navegando para `AppRoutes.animais` — navegação simples, sem filtro, porque não existe rota de animais filtrada por lote (ver `planner_assumptions`).

Rodapé: quando `lastApplication != null`, `Container(padding all 12, border top AppColors.divider)` com `'última aplicação '` em 12/`AppColors.textSecondary` + a data `dd/MM/yyyy` em `monoStyle(12.5, w600)`. Quando for nulo, não renderizar o rodapé.

Nenhuma cor literal fora de `AppColors`; todo número e data em `monoStyle`.
  </action>
  <verify>
    <automated>flutter analyze --no-fatal-infos lib/features/lotes/presentation/lote_detail_panel.dart</automated>
    <automated>[ "$(grep -c 'width: 380' lib/features/lotes/presentation/lote_detail_panel.dart)" -ge 1 ]</automated>
    <automated>[ "$(grep -oE '(^|[^A-Za-z.])Colors\.[A-Za-z]+|Color\(0x' lib/features/lotes/presentation/lote_detail_panel.dart | grep -cv 'Colors\.transparent')" -eq 0 ]</automated>
  </verify>
  <done>`lote_detail_panel.dart` compila limpo, exporta `LoteDetailPanel` com largura fixa 380, reusa `AplicacaoFormDialog`/`MoverLoteDialog` sem método novo de repositório, e não contém cor literal.</done>
</task>

<task type="auto">
  <name>Task 3: Ligar o branch desktop em PiquetesScreen + teste de largura</name>
  <files>lib/features/piquetes/presentation/piquetes_screen.dart, test/widget/lotes_desktop_test.dart</files>
  <action>
**(a) `piquetes_screen.dart`** — envolver o `Scaffold` num `LayoutBuilder` e derivar `final isDesktop = constraints.maxWidth >= Breakpoints.rail;` (importar `core/theme/breakpoints.dart`). Adicionar `String? _selectedLotId;` ao state.

Quando `isDesktop && _showLots`, o `body` passa a ser
`Row(crossAxisAlignment: stretch, children: [Expanded(LotesTableView(...)), if (selected != null) LoteDetailPanel(key: ValueKey(id), ...)])`,
com `selected` resolvido por `lots.where((l) => l.lot.id == _selectedLotId).firstOrNull` sobre a lista já carregada (se o lote sumir depois de um invalidate, o painel simplesmente não renderiza). Em **todos os outros casos** (`!isDesktop`, ou aba Piquetes em qualquer largura) o `body` continua sendo, byte a byte, o `Column` atual — segmented de 42px + `LotesListView`/lista de piquetes. Não alterar o gate do FAB (`canEdit && !_showLots` já o esconde na aba Lotes).

Derivar na tela, a partir dos providers que ela **já** observa, e passar para os dois widgets novos:
- `animalsByLot`: `Map<String, List<Animal>>` agrupando `animalListByPropertyProvider` por `animal.lotId`, ignorando `deletedAt != null` (mesma lógica de `LotesListView`).
- `overloadedPaddockIds`: para cada `Paddock`, somar `calcTotalUa` dos animais ativos com `ctx.paddockId == p.id` e incluir o id quando `uaCapacity > 0 && ua / uaCapacity >= 1.0` — a mesma regra `over` do `_PaddockCard`.
- agregados do subtítulo: UA ocupada total (todos os animais ativos), `capacidadeTotal`/`haTotal` somando `paddockListProvider`.
- `lastApplicationByLot`: observar `sanitaryApplicationListByPropertyProvider` (**somente dentro do branch desktop**, para não adicionar query ao caminho mobile — se isso exigir observar incondicionalmente, aceite: é um provider já existente e cacheado) e reduzir para o `appliedAt` máximo por `lotId`.

`onCreate` do botão "Novo lote": abrir um `SimpleDialog` com título `'Em qual piquete?'` e um `SimpleDialogOption` por piquete de `paddockListProvider` (nome do piquete como label); com o piquete escolhido, encadear no diálogo existente via `showAdaptiveForm<bool>(builder: (_) => LoteFormDialog(paddockId: escolhido, propertyId: currentProperty.id))` e, em caso de sucesso, `ref.invalidate(loteWithPaddockListByPropertyProvider)`. Sem rota nova, sem widget de formulário novo.

**(b) `test/widget/lotes_desktop_test.dart`** — arquivo novo, harness copiado de `reproducao_desktop_test.dart` (`addTearDown(() => tester.binding.setSurfaceSize(null))` + `setSurfaceSize`) e fixtures copiadas de `piquetes_screen_test.dart` (`Paddock`, `Lot`, `AnimalWithContext`). Overrides: `paddockListProvider`, `loteWithPaddockListByPropertyProvider`, `animalListByPropertyProvider`, `paddockMonthExpenseTotalProvider`, `sanitaryApplicationListByPropertyProvider` (retornando `const []` no caso simples), `animalReproStatusByPropertyProvider` (`const {}`), `memberPropertiesProvider` e `currentPropertyProvider` com papel `veterinarian`. Usar `MaterialApp.router` com um `GoRouter` local (rotas `/` → `PiquetesScreen`, `AppRoutes.loteById` e `AppRoutes.animais` como stubs), porque o painel navega.

Testes (mínimo 5):
1. `1440x900` na aba Lotes: `find.byType(LotesTableView)` findsOneWidget, `find.byType(LotesListView)` findsNothing, `find.byType(LoteDetailPanel)` findsNothing, e o subtítulo mono agregado aparece.
2. Ordenação: com dois lotes de UA diferente, a linha de maior UA aparece antes da de menor (comparar `tester.getTopLeft` dos dois `find.text` de nome de lote).
3. Seleção: tocar no nome de um lote faz `LoteDetailPanel` aparecer e `LotesTableView` continuar presente.
4. Painel: com o painel aberto, os botões `'Aplicação'` e `'Mover lote'` estão presentes (lote ativo, `canEdit`, com animais) e o link `'Ver os N na lista de animais'` também.
5. `800x600` na aba Lotes: `LotesTableView`/`LoteDetailPanel` ausentes, `LotesListView` presente — comportamento mobile intacto.

Trocar de aba nos testes tocando no segmented existente (`find.text('Lotes')`), que é o mesmo caminho do usuário.

**Não editar nenhum arquivo de teste existente.** Se `piquetes_screen_test.dart` quebrar, a causa é regressão no caminho mobile — corrigir o código de produção, não o teste.
  </action>
  <verify>
    <automated>flutter analyze --no-fatal-infos</automated>
    <automated>flutter test</automated>
    <automated>git diff --exit-code -- test/widget/piquetes_screen_test.dart test/widget/lote_detail_screen_test.dart test/widget/lote_form_dialog_test.dart test/widget/animais_desktop_test.dart test/widget/reproducao_desktop_test.dart</automated>
    <automated>[ "$(grep -c 'testWidgets(' test/widget/lotes_desktop_test.dart)" -ge 5 ]</automated>
    <automated>[ "$(grep -c 'Breakpoints.rail' lib/features/piquetes/presentation/piquetes_screen.dart)" -ge 1 ]</automated>
  </verify>
  <done>`flutter analyze --no-fatal-infos` limpo, `flutter test` verde com o suite inteiro, nenhum teste pré-existente modificado, e `lotes_desktop_test.dart` cobrindo tabela+painel em 1440x900 e lista atual em 800x600.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Flutter client → Supabase (PostgREST) | Já atravessado pelos providers reutilizados; este task não abre nenhum caminho novo. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ugd-01 | Elevation of Privilege | Botões "Aplicação"/"Mover lote" no `LoteDetailPanel` | medium | mitigate | Gate `canEdit` (papel `veterinarian`) replicado do `LoteDetailScreen`; a autorização real permanece nas policies RLS e nas RPCs SECURITY DEFINER, inalteradas. |
| T-ugd-02 | Information Disclosure | Tabela e painel exibem lotes/animais da propriedade ativa | low | accept | Todos os dados vêm de providers já escopados por `currentPropertyProvider` + RLS por `property_id`; nenhuma query nova. |
</threat_model>

<verification>
1. `flutter analyze --no-fatal-infos` sem issues.
2. `flutter test` — suite completa verde, nenhum teste pré-existente editado (`git diff --exit-code` nos arquivos listados).
3. `grep` confirma zero cor literal nos dois arquivos novos e a presença de `Breakpoints.rail` na tela.
4. Nenhum método novo em repositório: `git diff --stat` não deve tocar nenhum arquivo em `lib/features/*/data/`.
</verification>

<success_criteria>
- Em ≥1024px, a aba Lotes de `/piquetes` renderiza `LotesTableView` (ordenada por UA desc por padrão, coluna UA sortável) e nunca `LotesListView`.
- Selecionar uma linha abre `LoteDetailPanel` de 380px com header verde, ações existentes, composição em barras, lista curta de animais e rodapé de última aplicação; a tabela permanece visível com barra verde na linha selecionada.
- Em <1024px nada muda: mesmo segmented, mesma `LotesListView`, mesmo FAB, mesmos testes passando sem edição.
- Aba Piquetes inalterada nas duas larguras.
- Zero método novo de repositório; badge "N DGs pendentes" omitido e justificado em `planner_assumptions`.
</success_criteria>

<output>
Create `.planning/quick/260813-ugd-lotes-em-tabela-desktop-com-painel-de-de/260813-ugd-SUMMARY.md` when done
</output>
