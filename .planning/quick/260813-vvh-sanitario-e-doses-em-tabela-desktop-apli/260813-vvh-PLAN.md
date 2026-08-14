---
phase: quick-260813-vvh
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/sanitario/presentation/sanitario_table_views.dart
  - lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart
  - lib/features/sanitario/presentation/aplicacao_detail_screen.dart
  - lib/features/sanitario/presentation/sanitario_screen.dart
  - test/widget/sanitario_desktop_test.dart
autonomous: true
requirements: []

must_haves:
  truths:
    - "Em >=1024px a aba Aplicações mostra uma tabela densa com cabeçalho de colunas (data, produto, lote, piquete, animais, UA, custo, status), não os cards mobile."
    - "Em >=1024px a aba Doses mostra uma tabela limitada a 1040px com produto, princípio ativo, mL/kg, mL/UA, R$/kg, R$/UA e badge de status, com nota de rodapé sobre a base kg/UA e a regra de arquivar em vez de excluir."
    - "Linha de dose arquivada aparece esmaecida (opacity 0.5), com badge 'Arquivada' e ação de desarquivar que chama o mesmo fluxo de restore de hoje."
    - "Aplicação estornada aparece riscada e esmaecida na tabela e nunca some por conta da tabela — a visibilidade continua governada pelo toggle 'Mostrar estornadas' existente."
    - "Estornar a partir de uma linha da tabela abre o EstornarAplicacaoDialog existente e, ao confirmar, revalida exatamente os mesmos providers que o caminho da tela de detalhe."
    - "O header desktop mostra título, subtítulo mono com contagens, o segmented existente e o botão primário da aba (Nova aplicação / Nova dose); o FAB só existe abaixo de 1024px."
    - "Abaixo de 1024px as duas abas continuam byte a byte as listas de cards atuais."
  artifacts:
    - lib/features/sanitario/presentation/sanitario_table_views.dart
    - test/widget/sanitario_desktop_test.dart
  key_links:
    - "SanitarioScreen.build -> LayoutBuilder(Breakpoints.rail) -> AplicacoesTableView | DosesTableView (desktop) vs ListView de _AplicacaoCard | _DoseCard (mobile)"
    - "DosesTableView -> resolveActiveKgPerUa(ref) + dosagePerUa/costPerUa de sanitary_calculations.dart (nenhuma aritmética nova, nenhum 450 hardcoded)"
    - "AplicacoesTableView.onEstornar -> confirmEstorno() extraído para estornar_aplicacao_dialog.dart -> EstornarAplicacaoDialog (mesmo caminho de escrita do AplicacaoDetailScreen)"
    - "Tabelas -> callbacks já existentes da tela (_openDoseForm, _toggleArchive, _openRegistrarAplicacao) — zero método novo de repositório"
  prohibitions:
    - "Nenhuma alteração em lib/features/sanitario/data/ (git status limpo nessa pasta ao fim do task 1 e 2)."
    - "Nenhum package novo: pubspec.yaml e pubspec.lock sem diff."
    - "Nenhum arquivo de teste existente pode ser editado."
    - "Nenhum literal de cor fora de AppColors."
    - "Nenhuma mudança de comportamento abaixo de 1024px, em nenhuma das duas abas."
---

<objective>
Levar as duas abas de `/sanitario` para o layout de tabela densa desktop aprovado nos mockups "2d" (Aplicações) e "3e" (Doses): a partir de `Breakpoints.rail` (1024px) as listas de cards viram tabelas, com o header de tela (título + subtítulo mono + segmented + botão primário) por cima. Abaixo de 1024px nada muda.

Purpose: Sanitário é a última tela do módulo que ainda cai no layout mobile em telas largas — hoje um card por aplicação desperdiça a largura e obriga a abrir a ficha para comparar duas aplicações. A tabela põe data, lote, piquete, nº de animais e custo lado a lado, e o catálogo de doses (3 linhas típicas) vira uma grade legível de dosagem e custo por kg e por UA.
Output: `sanitario_table_views.dart` (as duas tabelas), o helper `confirmEstorno` extraído para `estornar_aplicacao_dialog.dart`, o branch desktop em `sanitario_screen.dart` e `test/widget/sanitario_desktop_test.dart`.
</objective>

<execution_context>
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/workflows/execute-plan.md
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

Tela a estender (segmented, filtros, toggles e os dois callbacks de criação já existem aqui):
@lib/features/sanitario/presentation/sanitario_screen.dart

Padrão de tabela consolidado (larguras declaradas uma vez, `_HeaderText` privado por arquivo, linha 44px com `InkWell` + `hoverColor`, rodapé em `surfaceVariant`) — copiar a anatomia, não abstrair:
@lib/features/animais/presentation/animais_table_view.dart
@lib/features/lotes/presentation/lotes_table_view.dart

Fluxo de estorno existente (único caminho de escrita de aplicações neste task):
@lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart
@lib/features/sanitario/presentation/aplicacao_detail_screen.dart

Modelos, cálculos e tema:
@lib/features/sanitario/data/sanitary_application_model.dart
@lib/features/sanitario/data/dose_model.dart
@lib/features/sanitario/data/sanitary_calculations.dart
@lib/features/sanitario/data/kg_per_ua_resolver.dart
@lib/core/theme/app_colors.dart
@lib/core/theme/breakpoints.dart
@lib/core/widgets/ui.dart

Teste-molde (harness `setSurfaceSize` + overrides de provider + router stub):
@test/widget/lotes_desktop_test.dart
</context>

<planner_assumptions>
Levantamento feito antes de planejar — decisões que o executor **não** precisa reabrir:

| Item | Fonte / decisão |
|---|---|
| Um arquivo, duas tabelas | `sanitario_table_views.dart` com `AplicacoesTableView` e `DosesTableView`. Não dois arquivos: as duas dividem o `_HeaderText` privado e a mesma anatomia de linha. |
| Colunas de Aplicações | Todas têm fonte em `SanitaryApplication`: `appliedAt`, `doseName`, `lotName`, `paddockName`, `animalCount`, `totalUa`, `totalCost` (nullable). **Nenhuma coluna omitida.** Custo nulo renderiza travessão, nunca "R$ 0,00" (D-11). |
| Estornada vs. Estorno | Mesma regra do `_AplicacaoCard` atual: `reversedApplicationIds(rows)` diz quem **foi** estornada; `app.isReversal` diz quem **é** um estorno. Nenhuma lógica nova. |
| Ação de estorno na tabela | Reusa `EstornarAplicacaoDialog`. Para não duplicar as 5 invalidações do `_confirmEstorno`, esse método sai de `aplicacao_detail_screen.dart` e vira função top-level em `estornar_aplicacao_dialog.dart`, chamada pelos dois lugares. Diff líquido perto de zero. |
| Colunas de Doses | `name`, `activeIngredient` (nulo → travessão), `dosagePerKg`, `dosagePerUa` calculado, `costPerKg` (nulo → travessão), `costPerUa` calculado, status. Todas com fonte no modelo. |
| Base kg/UA | `resolveActiveKgPerUa(ref)` (D-12, fallback 400). **Não** hardcodar 450 — a nota de rodapé imprime o valor resolvido da propriedade ativa. |
| Linha arquivada | O modelo mantém `dosagePerKg`/`costPerKg` reais quando arquivada, então a linha mostra **valores reais** em `Opacity(0.5)` + badge "Arquivada" + ícone de desarquivar. Nada de travessão por estar arquivada. |
| Largura das tabelas | Doses: `ConstrainedBox(maxWidth: 1040)` alinhado à esquerda (3 doses não justificam 1440). Aplicações: largura total. |
| Toggles e filtros | `_buildFilterRow()` e `_buildToggleRow()` são reusados **como estão** no branch desktop — mesmo state, mesmos setters. Zero filtro novo. |
| FAB vs. botão primário | Desktop: `floatingActionButton: null` e `FilledButton.icon` no header ("Nova aplicação" / "Nova dose" conforme `_tab`), chamando os mesmos `_openRegistrarAplicacao` / `_openDoseForm()`. Mobile: FAB atual intacto. |
| Totais do subtítulo | Somam os valores **brutos** (sem `abs()`), para que uma linha de estorno cancele a original quando "Mostrar estornadas" está ligado. O `abs()` do `_AplicacaoCard` é exibição por linha e continua valendo dentro da linha. |
| Gate de permissão | Mesmo `canEdit` (`role == 'veterinarian'`) da tela. Sem ele, as colunas de ação renderizam vazias e o botão primário some. |
</planner_assumptions>

<tasks>

<task type="auto">
  <name>Task 1: Tabelas de Aplicações e Doses + helper de estorno compartilhado</name>
  <files>lib/features/sanitario/presentation/sanitario_table_views.dart, lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart, lib/features/sanitario/presentation/aplicacao_detail_screen.dart</files>
  <action>
**1a. Extrair o fluxo de estorno.**

Em `estornar_aplicacao_dialog.dart`, adicionar a função top-level:

`Future<void> confirmEstorno(BuildContext context, WidgetRef ref, SanitaryApplication app) async`

Corpo: exatamente o que hoje é o `_confirmEstorno` privado de `AplicacaoDetailScreen` — `showDialog<bool>` com `EstornarAplicacaoDialog(applicationId: app.id, doseName: app.doseName, appliedAt: app.appliedAt, lotId: app.lotId)`; se o resultado não for `true` ou o contexto não estiver montado, retorna; senão revalida, nesta ordem, `sanitaryApplicationByIdProvider(app.id)`, `sanitaryApplicationsByLotProvider(app.lotId)`, `sanitaryApplicationListByPropertyProvider` e, para cada entry de `app.compositionSnapshot`, `sanitaryHistoryByAnimalProvider(entry.animalId)`; por fim o mesmo `SnackBar` de sucesso de hoje, com o mesmo texto. Importar `sanitary_application_model.dart` para o tipo.

Em `aplicacao_detail_screen.dart`: apagar o método privado `_confirmEstorno` inteiro (dialog + invalidações + snackbar) e trocar o `onPressed` do botão "Estornar" por uma chamada a `confirmEstorno(context, ref, app)`. O import de `estornar_aplicacao_dialog.dart` permanece. Nenhuma outra linha do arquivo muda.

**1b. Criar `lib/features/sanitario/presentation/sanitario_table_views.dart`.**

Cabeçalho do arquivo: comentário curto dizendo que são as tabelas densas desktop do Sanitário (quick 260813-vvh, a partir de `Breakpoints.rail`), com larguras declaradas uma vez e reusadas por cabeçalho e linhas, molde `animais_table_view.dart`.

No fim do arquivo, copiar o `_HeaderText` privado de `animais_table_view.dart` tal e qual (mono 10.5 w700, `letterSpacing: 0.8`, `AppColors.primaryDarkText`), com o mesmo comentário de "idêntico ao de ..." que os outros arquivos de tabela usam.

Formatadores locais no topo: `DateFormat('dd/MM/yyyy')` para a coluna de data e `NumberFormat('#,##0.##', 'pt_BR')` para os números de mL (mesmo par que `sanitario_screen.dart` já usa). UA e dinheiro vêm de `formatUa` / `formatCurrencyBrl` de `sanitary_calculations.dart` — não reimplementar.

Constante local `const _kDash = '—'` para célula sem dado.

**`AplicacoesTableView extends ConsumerWidget`** — parâmetros: `rows` (`List<SanitaryApplication>`, já filtradas e ordenadas pela tela), `reversedIds` (`Set<String>`), `canEdit` (`bool`), `onOpen` (`ValueChanged<SanitaryApplication>`).

Layout: `ColoredBox(color: AppColors.surface)` + `Column(crossAxisAlignment: stretch)` com

1. Cabeçalho: `Container(constraints: BoxConstraints(minHeight: 36), padding: symmetric(horizontal: 14), color: AppColors.surfaceVariant)` com um `Row` de `_HeaderText`: `SizedBox(width: 92)` DATA · `Expanded(flex: 3)` PRODUTO · `Expanded(flex: 2)` LOTE · `Expanded(flex: 2)` PIQUETE · `SizedBox(width: 76)` ANIMAIS (right) · `SizedBox(width: 72)` UA (right) · `SizedBox(width: 104)` CUSTO (right) · `SizedBox(width: 100)` STATUS · `SizedBox(width: 44)` vazio. Declarar as larguras como constantes de arquivo (`_kColData`, `_kColAnimais`, ...) e reusá-las nas linhas.
2. `Expanded` com `ListView.builder` das linhas; quando `rows` está vazia, `Center(child: Text('Nenhuma aplicação encontrada.'))` — a tela continua dona dos `EmptyState` ricos.
3. Rodapé `Container(minHeight: 34, color: AppColors.surfaceVariant, alignment: centerRight)` com `'1–{n} de {n}'` em `monoStyle(size: 11.5, color: AppColors.textSecondary)`, onde n é `rows.length`.

Linha: `InkWell(hoverColor: AppColors.rowHover, onTap: () => onOpen(app))` envolvendo `Opacity(opacity: isReversed ? 0.5 : 1)` sobre um `Container(minHeight: 44, padding: symmetric(horizontal: 14), border: Border(bottom: BorderSide(color: AppColors.divider)))`, onde `isReversed = reversedIds.contains(app.id)`. Células, na ordem do cabeçalho:

- DATA: `appliedAt` formatada, `monoStyle(size: 12)`.
- PRODUTO: `app.doseName`, 14 w600, `TextOverflow.ellipsis`, com `decoration: TextDecoration.lineThrough` quando `isReversed`.
- LOTE / PIQUETE: `app.lotName` / `app.paddockName`, texto simples com ellipsis.
- ANIMAIS: `app.animalCount.abs()`, mono 13, alinhado à direita.
- UA: `formatUa(app.totalUa.abs())`, mono 13, direita.
- CUSTO: `formatCurrencyBrl(app.totalCost!.abs())` quando não nulo, senão `_kDash`; mono 13, direita.
- STATUS: `StatusChip('Estornada', kind: StatusKind.danger)` quando `isReversed`; `StatusChip('Estorno', kind: StatusKind.neutral)` quando `app.isReversal`; senão `SizedBox.shrink()` — mutuamente exclusivos, mesma regra do card de hoje.
- Ações: quando `canEdit` e a linha não é estorno nem foi estornada, `IconButton(icon: Icon(Icons.undo, size: 18), tooltip: 'Estornar aplicação', onPressed: () => confirmEstorno(context, ref, app))`; caso contrário `SizedBox` vazio da mesma largura.

**`DosesTableView extends StatelessWidget`** — parâmetros: `doses` (`List<Dose>`), `kgPerUa` (`double`), `canEdit` (`bool`), `onEdit` (`ValueChanged<Dose>`), `onArchiveToggle` (`ValueChanged<Dose>`).

Layout: `Align(alignment: Alignment.topLeft)` + `ConstrainedBox(constraints: BoxConstraints(maxWidth: 1040))` + `ColoredBox(color: AppColors.surface)` + `Column(crossAxisAlignment: stretch, mainAxisSize: min)` com cabeçalho, linhas e nota de rodapé. Como a altura é intrínseca, usar `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` — o catálogo tem poucas linhas — e envolver tudo num `SingleChildScrollView` para não estourar em telas baixas.

Cabeçalho (mesmo `Container` de 36px em `surfaceVariant`): `Expanded(flex: 3)` PRODUTO · `Expanded(flex: 3)` PRINCÍPIO ATIVO · `SizedBox(width: 84)` ML/KG (right) · `SizedBox(width: 92)` ML/UA (right) · `SizedBox(width: 96)` R$/KG (right) · `SizedBox(width: 96)` R$/UA (right) · `SizedBox(width: 104)` STATUS · `SizedBox(width: 92)` vazio.

Linha (`Opacity(opacity: dose.isArchived ? 0.5 : 1)` sobre `Container` de 44px com borda inferior `AppColors.divider`):

- PRODUTO: `dose.name`, 14 w700, ellipsis.
- PRINCÍPIO ATIVO: `dose.activeIngredient` ou `_kDash`, `AppColors.textSecondary`, ellipsis.
- ML/KG: `dose.dosagePerKg` formatado, mono 13, direita.
- ML/UA: `dosagePerUa(dose.dosagePerKg, kgPerUa)` formatado, `monoStyle(size: 13, weight: FontWeight.w700, color: AppColors.primaryDarkText)`, direita.
- R$/KG: `formatCurrencyBrl(dose.costPerKg!)` ou `_kDash`, mono 13, direita.
- R$/UA: `costPerUa(dose.costPerKg, kgPerUa)` via `formatCurrencyBrl` quando não nulo, senão `_kDash`; mono 13 w700, direita.
- STATUS: `StatusChip('Ativa', kind: StatusKind.positive)` ou `StatusChip('Arquivada', kind: StatusKind.neutral)`.
- Ações (só com `canEdit`): `IconButton` editar (`Icons.edit_outlined`, 18, tooltip 'Editar dose', `onEdit(dose)`) + `IconButton` arquivar/desarquivar (`Icons.archive_outlined` / `Icons.unarchive_outlined`, tooltip 'Arquivar dose' / 'Reativar dose', `onArchiveToggle(dose)`).

Nota de rodapé: `Container(padding: fromLTRB(14, 10, 14, 12), color: AppColors.surfaceVariant)` com um `Text.rich` de 11.5 em `AppColors.textSecondary` — texto plano "Valores por UA calculados sobre " + span mono com o `kgPerUa` formatado + " kg/UA. Doses já usadas em aplicações não podem ser excluídas — apenas arquivadas."

Regras transversais do arquivo: nenhuma cor fora de `AppColors` (o gate conta comentários também — não escreva construtor de cor literal em lugar nenhum do arquivo); todo número em `monoStyle`; nenhum método novo de repositório; nenhum arquivo em `lib/features/sanitario/data/` alterado; as tabelas não fazem `ref.watch` de listas (recebem dados prontos) — `AplicacoesTableView` só é `ConsumerWidget` para poder passar o `ref` ao `confirmEstorno`.
  </action>
  <verify>
    <automated>flutter analyze --no-fatal-infos lib/features/sanitario/presentation/sanitario_table_views.dart lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart lib/features/sanitario/presentation/aplicacao_detail_screen.dart</automated>
    <automated>[ "$(grep -cF 'class AplicacoesTableView' lib/features/sanitario/presentation/sanitario_table_views.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'class DosesTableView' lib/features/sanitario/presentation/sanitario_table_views.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'Color(0x' lib/features/sanitario/presentation/sanitario_table_views.dart)" -eq 0 ]</automated>
    <automated>[ "$(grep -cF 'Future<void> confirmEstorno' lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'confirmEstorno(' lib/features/sanitario/presentation/aplicacao_detail_screen.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'ref.invalidate' lib/features/sanitario/presentation/aplicacao_detail_screen.dart)" -eq 0 ]</automated>
    <automated>[ "$(git status --porcelain -- lib/features/sanitario/data/ pubspec.yaml pubspec.lock | wc -l)" -eq 0 ]</automated>
    <automated>flutter test test/widget/aplicacao_detail_screen_test.dart</automated>
  </verify>
  <done>As duas tabelas compilam, o estorno tem um único dono (`confirmEstorno`), o teste da tela de detalhe passa sem edição, e nada em `data/` ou no pubspec mudou.</done>
</task>

<task type="auto">
  <name>Task 2: Branch desktop em SanitarioScreen (header + tabelas a partir de 1024px)</name>
  <files>lib/features/sanitario/presentation/sanitario_screen.dart</files>
  <action>
Envolver o `build` num `LayoutBuilder` com `final isDesktop = constraints.maxWidth >= Breakpoints.rail;` — mesma forma de `animais_screen.dart` e `reproducao_screen.dart`. Importar `breakpoints.dart` e `sanitario_table_views.dart`.

**Extrair o filtro de aplicações.** Criar o método privado `List<SanitaryApplication> _filteredApplications(List<SanitaryApplication> rows)` que faz o que hoje está inline em `_buildApplicationsTab`: `visibleApplications(rows, showReversed: _showReversed)`, depois `.where(_matchesApplicationFilters)`, depois `sortByAppliedAtDesc`. `_buildApplicationsTab` passa a chamá-lo; o header desktop usa o mesmo método (uma única definição de "o que está na tela").

**Header desktop.** No `Scaffold`, antes do `Padding` do segmented, quando `isDesktop`, inserir `Padding(fromLTRB(16, 14, 16, 10))` com `Row(crossAxisAlignment: start)`:

- `Expanded` com `Column(crossAxisAlignment: start)`: `Text('Sanitário', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))`, `SizedBox(height: 2)` e o subtítulo em `monoStyle(size: 13, color: AppColors.textSecondary)`.
- Quando `canEdit` e há propriedade: `SizedBox(width: 10)` + `FilledButton.icon` — `_tab == 0` → ícone `Icons.add`, label 'Nova aplicação', `onPressed: _openRegistrarAplicacao`; `_tab == 1` → label 'Nova dose', `onPressed: () => _openDoseForm()`.

Subtítulo (método privado `String _desktopSubtitle()`), lendo os providers que a tela já observa:

- `_tab == 0`: sobre `_filteredApplications(rows)` do `sanitaryApplicationListByPropertyProvider` (lista vazia enquanto não resolveu) — `'{n} aplicações · {ua} UA'` com `n` mono e `ua` via `formatUa` da **soma bruta** de `totalUa`; concatenar `' · {custo}'` com `formatCurrencyBrl` da soma dos `totalCost` não nulos apenas quando ao menos um for não nulo.
- `_tab == 1`: `'{n} doses arquivadas'` quando `_showArchived`, senão `'{n} doses'`, sobre a lista do provider de escopo atual.

**Segmented.** Trocar o `SizedBox(width: double.infinity, height: 40)` por `width: isDesktop ? 320 : double.infinity` e, no desktop, alinhar à esquerda (`Align(alignment: Alignment.centerLeft)`). Abaixo de 1024px o resultado renderizado é idêntico ao de hoje.

**FAB.** `floatingActionButton: isDesktop ? null : _buildFab(canEdit, currentProperty)`.

**Aba Aplicações.** `_buildApplicationsTab` recebe `bool isDesktop`. As faixas `_buildFilterRow()` e `_buildToggleRow(...)` continuam iguais nos dois modos. Dentro do `data:`, quando `isDesktop` e a lista não está vazia, no lugar do `ListView.builder` de `_AplicacaoCard` renderizar

`AplicacoesTableView(rows: sorted, reversedIds: reversedApplicationIds(rows), canEdit: canEdit, onOpen: (app) => context.go(AppRoutes.aplicacaoDetail(app.id)))`

— mesmo destino de navegação do card. Os dois `EmptyState` (lista vazia vs. filtro sem resultado) continuam valendo nos dois modos. `_buildApplicationsTab` passa a precisar de `canEdit`: passar por parâmetro a partir do `build`.

**Aba Doses.** `_buildDosesTab(bool canEdit, bool isDesktop)`: quando `isDesktop` e há doses, trocar o `ListView.builder` de `_DoseCard` por

`DosesTableView(doses: doses, kgPerUa: kgPerUa, canEdit: canEdit, onEdit: (d) => _openDoseForm(existing: d), onArchiveToggle: _toggleArchive)`

— `kgPerUa` continua vindo do `resolveActiveKgPerUa(ref)` que já está no método. `_DoseCard`, `_AplicacaoCard` e `_DoseInfoTile` continuam no arquivo, intocados, servindo o caminho mobile.

Nada mais muda: filtros, toggles, seeding de query params, permissões e os dois callbacks de criação são os mesmos objetos de hoje. Nenhum provider novo, nenhum método novo de repositório, nenhuma cor literal.
  </action>
  <verify>
    <automated>flutter analyze --no-fatal-infos lib/features/sanitario/presentation/sanitario_screen.dart</automated>
    <automated>[ "$(grep -cF 'Breakpoints.rail' lib/features/sanitario/presentation/sanitario_screen.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'AplicacoesTableView(' lib/features/sanitario/presentation/sanitario_screen.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'DosesTableView(' lib/features/sanitario/presentation/sanitario_screen.dart)" -eq 1 ]</automated>
    <automated>[ "$(grep -cF 'class _DoseCard' lib/features/sanitario/presentation/sanitario_screen.dart)" -eq 1 ]</automated>
    <automated>[ "$(git status --porcelain -- lib/features/sanitario/data/ test/ pubspec.yaml pubspec.lock | grep -v '^??' | wc -l)" -eq 0 ]</automated>
    <automated>flutter test</automated>
  </verify>
  <done>Em >=1024px as duas abas renderizam tabelas com header + botão primário e sem FAB; abaixo de 1024px a árvore renderizada é a de hoje; a suíte inteira passa sem nenhum teste editado.</done>
</task>

<task type="auto">
  <name>Task 3: Teste widget dos dois breakpoints</name>
  <files>test/widget/sanitario_desktop_test.dart</files>
  <action>
Criar `test/widget/sanitario_desktop_test.dart` usando o harness de `test/widget/lotes_desktop_test.dart`: comentário de cabeçalho referenciando a quick task 260813-vvh, `ProviderScope` com overrides, `MaterialApp.router` com `GoRouter` stub (rota `/` → `SanitarioScreen`, rota `AppRoutes.aplicacaoDetail` → `Scaffold` com texto stub), helpers `_pumpDesktop` (1440x900) e `_pumpMobile` (800x600) com `addTearDown(() => tester.binding.setSurfaceSize(null))`.

Overrides necessários: `memberPropertiesProvider` com uma única `PropertyMembership(role: 'veterinarian')` (a seleção automática da propriedade depende disso), `propertyListProvider` com a `Property` correspondente e um `kgPerUa` explícito (conferir o construtor em `propriedade_repository.dart`/modelo antes de escrever), `sanitaryApplicationListByPropertyProvider`, `doseListByPropertyProvider`, `archivedDoseListByPropertyProvider` e `loteListByPropertyProvider` (usado pela linha de filtros).

Fixtures: duas `SanitaryApplication` — uma normal e uma que foi estornada (a segunda linha com `reversesApplicationId` apontando para a primeira, de forma que `reversedApplicationIds` marque a original) — e duas `Dose`, uma ativa com `costPerKg` e uma sem custo. Para o escopo arquivado, uma `Dose` com `deletedAt` no `archivedDoseListByPropertyProvider`.

Casos (nomes em português, no padrão dos outros arquivos):

1. 1440x900, aba Aplicações: `find.byType(AplicacoesTableView)` encontra um widget e nenhum card de aplicação (checar por um texto exclusivo do card ou pela ausência de `ListView` de cards — preferir asserção pelo tipo da tabela + presença de um cabeçalho de coluna como 'PIQUETE').
2. 1440x900, aba Aplicações com "Mostrar estornadas" ligado: a linha estornada continua na tabela e mostra o chip 'Estornada'.
3. 1440x900, aba Doses (tocar no segmented 'Doses'): `find.byType(DosesTableView)` encontra um widget, o cabeçalho mostra 'ML/UA' e a nota de rodapé contém 'kg/UA'.
4. 1440x900, aba Doses com "Mostrar arquivadas" ligado: aparece o chip 'Arquivada' e o `IconButton` com tooltip 'Reativar dose'.
5. 800x600, as duas abas: `find.byType(AplicacoesTableView)` e `find.byType(DosesTableView)` não encontram nada — caminho mobile intacto.

Nenhum arquivo de teste existente pode ser tocado. Se algum widget precisar de uma chave para ser localizável, prefira localizar por tipo/texto a adicionar `Key` no código de produção.
  </action>
  <verify>
    <automated>flutter test test/widget/sanitario_desktop_test.dart</automated>
    <automated>[ "$(grep -cF 'AplicacoesTableView' test/widget/sanitario_desktop_test.dart)" -ge 3 ]</automated>
    <automated>[ "$(grep -cF 'DosesTableView' test/widget/sanitario_desktop_test.dart)" -ge 3 ]</automated>
    <automated>[ "$(grep -cF 'setSurfaceSize(const Size(800, 600))' test/widget/sanitario_desktop_test.dart)" -ge 1 ]</automated>
    <automated>[ "$(git status --porcelain -- test/ | grep -v '^??' | wc -l)" -eq 0 ]</automated>
    <automated>flutter analyze --no-fatal-infos</automated>
  </verify>
  <done>O novo teste cobre os dois breakpoints nas duas abas, passa, e nenhum teste existente foi modificado.</done>
</task>

</tasks>

<verification>
1. `flutter analyze --no-fatal-infos` limpo no repositório inteiro.
2. `flutter test` verde — suíte completa, incluindo o arquivo novo.
3. `git status --porcelain -- test/ | grep -v '^??'` vazio durante toda a execução: o único arquivo de teste tocado é o novo, e ele entra como untracked.
4. `git status --porcelain -- lib/features/sanitario/data/ pubspec.yaml pubspec.lock` vazio: nenhuma mudança de modelo, repositório ou dependência.
5. Conferência visual manual (opcional, não bloqueia): `flutter run -d chrome`, janela larga → tabelas nas duas abas com header e botão primário; janela estreitada abaixo de 1024px → cards e FAB de volta.
</verification>

<success_criteria>
- Em >=1024px, `/sanitario` renderiza `AplicacoesTableView` na aba Aplicações e `DosesTableView` (limitada a 1040px) na aba Doses, com header de tela e sem FAB.
- Dose arquivada aparece esmaecida com badge e ação de reativar; aplicação estornada aparece riscada e esmaecida e nunca é removida pela tabela.
- Estornar pela tabela e estornar pela ficha executam o mesmo `confirmEstorno` — uma única lista de invalidações no projeto.
- Em <1024px a árvore renderizada é a de hoje, e a suíte existente passa sem uma linha editada.
</success_criteria>

<output>
Create `.planning/quick/260813-vvh-sanitario-e-doses-em-tabela-desktop-apli/260813-vvh-SUMMARY.md` when done
</output>
</content>
</invoke>
