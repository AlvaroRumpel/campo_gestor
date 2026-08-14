---
phase: quick
plan: 260813-tos
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/reproducao/data/dg_summary.dart
  - lib/features/reproducao/presentation/atf_dg_table_view.dart
  - lib/features/reproducao/presentation/atf_detail_screen.dart
  - test/widget/atf_detail_desktop_test.dart
autonomous: true
requirements: [REPR-03, REPR-04]

must_haves:
  truths:
    - "A partir de Breakpoints.rail o detalhe do ATF mostra as fêmeas numa tabela densa (checkbox, Nº, categoria·raça, lote, IA, DG, resultado), não a lista mobile de linhas com 3 chips"
    - "Clicar Prenhe ou Vazia numa linha registra o DG daquele animal na hora, via saveDgRecords — o mesmo RPC que o fluxo mobile usa"
    - "Selecionar ≥1 linha abre a barra contextual verde escura com contador mono, Marcar prenhe, Marcar vazia e Remover do ATF; as duas primeiras registram DG em lote numa única chamada saveDgRecords"
    - "Uma linha com DG já registrado mostra o botão daquele resultado preenchido; tocar o MESMO resultado não faz nada, tocar o outro registra a correção (registro aditivo, nunca update/delete — regra D-12/D-16 que o repositório já impõe)"
    - "Abaixo de Breakpoints.rail o fluxo atual é byte-a-byte o de hoje e test/widget/atf_detail_screen_test.dart passa sem uma linha editada"
    - "Nenhum método novo no AtfRepository, nenhuma query nova ao PostgREST, nenhum dado inventado: lote e raça vêm de animalListByPropertyProvider, que já existe"
    - "flutter analyze --no-fatal-infos limpo e a suíte inteira verde"
  artifacts:
    - lib/features/reproducao/presentation/atf_dg_table_view.dart
    - test/widget/atf_detail_desktop_test.dart
  key_links:
    - "AtfDetailScreen -> Breakpoints.rail (fonte única do corte, sem número mágico)"
    - "AtfDgTableView -> AtfRepository.saveDgRecords (individual = lista de 1, lote = lista de N; zero RPC novo)"
    - "AtfDgTableView -> AtfRepository.removeAnimalFromAtf (mesma RPC do botão remover mobile)"
    - "AtfDgTableView + _AtfDgBodyState -> latestDgFor em dg_summary.dart (uma única implementação da regra de desempate por examDate, G-05-4)"
    - "AtfDgTableView -> animalListByPropertyProvider (lote + raça sem query nova)"
    - "AtfDgTableView -> AppColors.primaryDarkText (#2F4429 já existe como token — nenhum token novo)"
  prohibitions:
    - "Nenhuma mudança de comportamento abaixo de Breakpoints.rail"
    - "Nenhum método novo no AtfRepository e nenhuma query nova ao PostgREST"
    - "Nenhum literal de cor hex nos arquivos novos — tudo por AppColors"
    - "Nenhum update ou delete de dg_records: registro é sempre aditivo via saveDgRecords"
    - "Nenhuma coluna com dado que os modelos não carregam"
---

<objective>
Em ≥1024px, o detalhe do ATF passa a mostrar as fêmeas numa tabela densa com registro
de DG inline por linha (Prenhe / Vazia) e seleção múltipla com barra contextual para DG
em massa e remoção do ATF. Abaixo de 1024px nada muda.

Purpose: no desktop o vet confere o ciclo inteiro de uma vez. A lista mobile — uma linha
alta por animal com três botões de 48px e um rodapé de salvar — obriga a rolar 50 fêmeas
para marcar as 12 que ele acabou de examinar. A tabela mostra tudo e a barra contextual
resolve as 12 numa ação.
Output: `AtfDgTableView` novo, `AtfDetailScreen` decidindo a forma por `LayoutBuilder`,
`latestDgFor` extraído para `dg_summary.dart`, e teste de widget cobrindo os dois lados
do corte.
</objective>

<execution_context>
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/workflows/execute-plan.md
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

@lib/core/theme/breakpoints.dart
@lib/core/theme/app_colors.dart
@lib/core/widgets/ui.dart
@lib/features/reproducao/presentation/atf_detail_screen.dart
@lib/features/reproducao/presentation/reproducao_table_view.dart
@lib/features/reproducao/presentation/atf_detail_panel.dart
@lib/features/reproducao/presentation/atf_animal_selection_screen.dart
@lib/features/reproducao/data/atf_model.dart
@lib/features/reproducao/data/atf_repository.dart
@lib/features/reproducao/data/dg_summary.dart
@lib/features/reproducao/data/dg_record_model.dart
@lib/features/animais/data/animal_model.dart
@lib/features/animais/data/animal_repository.dart
@lib/features/animais/data/animal_constants.dart
@lib/features/animais/presentation/animais_table_view.dart
@test/widget/atf_detail_screen_test.dart
@test/widget/animais_desktop_test.dart
</context>

Os dois gates abaixo são POSITIVOS (o token tem de aparecer no código), não negativos —
por isso os literais podem constar do corpo do plano:
<!-- planner-discipline-allow: Breakpoints.rail -->
<!-- planner-discipline-allow: saveDgRecords -->

<planner_assumptions>
Lidas do código, não do mockup. Já conferidas contra modelos, providers e testes
existentes — o executor segue estas resoluções sem reabrir a discussão:

1. **`Breakpoints.rail` é a constante do corte.** Nenhum literal de largura nos widgets
   novos. Mesmo padrão de `ReproducaoScreen` e `AnimaisScreen`
   (`constraints.maxWidth >= Breakpoints.rail` dentro de um `LayoutBuilder`).

2. **A arquitetura é a dos quick tasks p10/r4s, de propósito.** Larguras de coluna como
   constantes de topo de arquivo reusadas por cabeçalho e linhas; cabeçalho de coluna
   mono 10.5 w700 caixa alta `letterSpacing 0.8` em `AppColors.primaryDarkText`; linha
   com `minHeight 44`, `InkWell(hoverColor: AppColors.rowHover)`, divisor inferior
   `AppColors.divider`. O pacote de data-grid do pubspec continua não importado — a
   tabela é `Row`+`Expanded`, como nas outras duas.

3. **O AppBar não muda em nenhuma largura.** `DetailAppBar` já entrega back ("Voltar"),
   o pill Ativo/Encerrado e a ação Encerrar ATF, e os testes de back existentes se
   apoiam nele. O "header" que o mockup pede (nome + badge + subtítulo mono) é o bloco
   de topo do próprio `AtfDgTableView`, abaixo do AppBar. `AtfHeaderCard` (o header verde
   com o KPI) NÃO renderiza em ≥1024 — o % prenhez sobrevive no subtítulo mono, item 5.

4. **Registro é imediato no desktop, e é o MESMO RPC.** `saveDgRecords(atfBatchId:,
   records:)` com uma lista de 1 mapa (botão inline) ou de N mapas (barra contextual).
   Nada de staging nem rodapé "Salvar DGs" em ≥1024: o mockup não tem rodapé e o
   staging existe no mobile porque lá o vet marca enquanto anda pelo brete. `exam_date`
   = hoje, `DateFormat('yyyy-MM-dd').format(DateTime.now())` — mesma regra sem fuso do
   `_dateOnlyFmt` do repositório (WR-03). Sem banner de sessão de data no desktop
   (pulado: o mockup não pede; a data por linha continua editável no mobile).

5. **Subtítulo mono do header da tabela:** `IA dd/MM · {touro} · N fêmeas · prenhez P`,
   onde `P` = `dgSummary.percent == null ? '—' : '$percent%'` (regra E10: nunca "0%"),
   `N` = número de linhas renderizadas e o segmento do touro é OMITIDO quando
   `atf.bullName` é nulo ou vazio (nada de "· ·" nem de "null"). O `summarizeDg` é
   chamado com `compositionCount: activeMemberships.length`, exatamente como
   `AtfHeaderCard` já faz — não inventar outro cálculo de prenhez.

6. **Badge do header = a MESMA derivação de `_AtfCard`/`ReproducaoTableView`:**
   `!atf.active` → `Encerrado` (neutral); `pendingMembers > 0` → `N DGs pendentes` /
   `1 DG pendente` (warning); senão, se houve algum DG → `Completo` (positive). A
   contagem usada é o `pendingMembers` que `AtfDetailScreen.build` JÁ calcula (por
   membro ATUAL, G-05-3) e passa para baixo — nunca `summarizeDg(...).pending`, que
   responde outra pergunta e volta a zero quando a composição roda.

7. **Colunas e a origem de cada célula.** Só o que os modelos já carregam:

   | Coluna | Origem | Formato |
   |---|---|---|
   | checkbox | seleção local | 44px, só quando `canEdit` |
   | Nº | `m.animalNumber` | mono 15 w700, `#N`, 72px |
   | CATEGORIA | `kCategoryLabels[m.animalCategory]` + `· {raça}` quando houver | texto, flex 2 |
   | LOTE | `AnimalWithContext.lotName` | texto, flex 2, `—` quando desconhecido |
   | IA | `atf.inseminationDate` | mono `dd/MM/yy`, 82px |
   | DG | `latestDgFor(...)?.examDate` | mono `dd/MM/yy`, 82px, `—` quando sem DG |
   | RESULTADO | par de botões inline | 250px |

   **Lote e raça vêm de `animalListByPropertyProvider`**, que já existe e já é usado por
   `AnimaisScreen`: `ref.watch(...).asData?.value ?? const []` reduzido a um
   `Map<String, AnimalWithContext>` por `animal.id`, e o join é por `m.animalId`. Zero
   método novo no repositório, zero query nova escrita — enquanto o provider carrega, as
   duas colunas mostram `—`. `AtfMembershipView` sozinho não tem nem lote nem raça, e a
   alternativa (alterar `fetchMemberships`) mexeria na query que o mobile também usa.

   **A coluna "Dias" é omitida**, usando a licença explícita do próprio spec ("se
   derivável de datas existentes; senão omitir"): toda derivação candidata ou é
   constante em todas as linhas (hoje − IA, que a coluna IA já comunica) ou seria
   inventada. A coluna IA é mantida mesmo repetindo a mesma data em todas as linhas —
   é o que o mockup aprovado mostra e o campo é real.

8. **Imutabilidade: o spec delega ao domínio, e o domínio é aditivo.** `saveDgRecords`
   é insert-only e D-12/D-16 existem justamente para permitir correção depois do
   encerramento — o repositório não tem update nem delete de `dg_records`. Logo:
   - resultado registrado → aquele botão renderiza preenchido (`AppColors.primary` /
     `AppColors.danger`), o outro fica outline;
   - tocar o botão do resultado JÁ registrado é **no-op** (não empilha registro
     idêntico) — é esse o sentido em que "não permite re-registro" vale;
   - tocar o OUTRO botão registra a correção, criando um registro novo.
   Na ação em lote a mesma regra filtra o payload: animais que já estão naquele
   resultado saem da lista antes da chamada, e se sobrar zero a chamada nem acontece.

9. **`duvidosa` continua legível.** O desktop só tem dois botões, mas uma linha cujo DG
   mais recente é `doubtful` não pode parecer pendente: a célula RESULTADO renderiza um
   `StatusChip('Duvidosa', kind: StatusKind.warning)` ANTES do par de botões, e os dois
   botões continuam ativos para a correção. Registrar `duvidosa` continua sendo só do
   mobile — a tabela lê, não escreve esse resultado.

10. **A regra de "DG mais recente" passa a viver num lugar só.** `_AtfDgBodyState.
    _mostRecentDg` hoje reimplementa o desempate por `isLaterDg` inline; a tabela
    precisaria da mesma regra. Extrair `DgRecord? latestDgFor(List<DgRecord>, String
    animalId)` para `dg_summary.dart` (onde `isLaterDg` já mora) e fazer as DUAS chamarem
    — comportamento idêntico, os testes G-05-4 existentes continuam sendo a prova.

11. **Barra contextual: `AppColors.primaryDarkText` é exatamente `#2F4429`.** O token já
    existe. Nenhum token novo, nenhum literal hex.

12. **`canEdit` (papel `veterinarian`) governa tudo que escreve**, igual ao mobile: sem
    ele, nada de coluna de checkbox, nada de botões de resultado — a tabela fica só de
    leitura. Filtro de linhas idêntico ao mobile: roster completo (`memberships`) menos
    `animalDeleted` (G-05-2/D-16), NUNCA filtrado por `active`.

13. **"Remover do ATF" respeita o mesmo portão do ícone mobile:** só habilita quando
    `atf.active && canEdit` e TODAS as linhas selecionadas ainda não têm DG (o servidor
    rejeita as outras de qualquer jeito, D-08). Confirmação em `AlertDialog` antes, e a
    remoção é um `Future.wait` de `removeAnimalFromAtf` — a RPC é por animal e continua
    sendo, sem RPC nova.

14. **Pulado de propósito:** o banner de sugestão de encerramento (D-15) não renderiza
    em ≥1024 — a ação Encerrar ATF continua no AppBar em todas as larguras, que é o
    único caminho que importa; e o campo de observação por linha, que o mockup não tem
    (continua no mobile). Ambos ficam registrados aqui para não voltarem como "bug".
</planner_assumptions>

<tasks>

<task type="auto">
  <name>Task 1: latestDgFor compartilhado + tabela desktop somente-leitura atrás de Breakpoints.rail</name>
  <files>lib/features/reproducao/data/dg_summary.dart, lib/features/reproducao/presentation/atf_dg_table_view.dart, lib/features/reproducao/presentation/atf_detail_screen.dart</files>
  <action>
Em `dg_summary.dart`, adicionar a função de topo `DgRecord? latestDgFor(List<DgRecord> records, String animalId)`: varre os registros do animal e devolve o maior segundo `isLaterDg` (a mesma regra de desempate por `examDate`, G-05-4), ou null. Em `atf_detail_screen.dart`, `_AtfDgBodyState._mostRecentDg` passa a delegar para ela em vez de repetir o laço — comportamento idêntico, os testes G-05-4 existentes são a prova.

Criar `atf_dg_table_view.dart` com `AtfDgTableView` (`ConsumerStatefulWidget` — o estado de seleção entra na Task 2). Parâmetros: `atf`, `rows` (`List&lt;AtfMembershipView&gt;` já filtrada pelo pai), `activeMemberships`, `dgRecords`, `pendingMembers`, `canEdit`. Constantes de largura no topo do arquivo, reusadas por cabeçalho e linhas, seguindo `reproducao_table_view.dart`.

Bloco de topo (fundo `AppColors.surface`): nome do ATF (24 w600) + badge de status à direita, e abaixo o subtítulo mono conforme a assunção 5. Badge conforme a assunção 6. Quando `atf.active && canEdit`, um `OutlinedButton.icon` "Animais" à direita que empurra `AtfAnimalSelectionScreen` por `MaterialPageRoute`, igual ao `_openSelection` do mobile.

Cabeçalho de colunas em `AppColors.surfaceVariant` e as linhas conforme a tabela da assunção 7 — sem a coluna de checkbox e sem os botões de resultado ainda; a célula RESULTADO fica reservada com a largura final. Lote e raça pelo join em memória com `animalListByPropertyProvider` descrito na assunção 7. Roster vazio renderiza a MESMA cópia do mobile, "Nenhum animal neste ATF." Nenhum literal de cor hex: todo tom sai de `AppColors`.

Em `AtfDetailScreen.build`, envolver só o `body` num `LayoutBuilder`: `constraints.maxWidth >= Breakpoints.rail` monta `AtfDgTableView`, caso contrário devolve o `Column(AtfHeaderCard, Expanded(_AtfDgBody))` de hoje sem uma linha alterada. AppBar, cálculo de `pendingMembers`, portões `showEncerrarAction`/`showBanner` e o filtro de roster (`memberships.where((m) =&gt; !m.animalDeleted)`, agora calculado no pai para alimentar os dois caminhos) permanecem como estão.
  </action>
  <verify>
    <automated>cd "F:/_geral/Projetos/campo_gestor" &amp;&amp; flutter analyze --no-fatal-infos &amp;&amp; flutter test &amp;&amp; git diff --exit-code -- test/widget/atf_detail_screen_test.dart &amp;&amp; [ "$(grep -v '^\s*//' lib/features/reproducao/presentation/atf_detail_screen.dart | grep -c 'Breakpoints.rail')" -ge 1 ] &amp;&amp; [ "$(grep -v '^\s*//' lib/features/reproducao/presentation/atf_dg_table_view.dart | grep -c 'Color(0x')" -eq 0 ] &amp;&amp; [ "$(git diff --name-only -- lib/features/reproducao/data/atf_repository.dart | wc -l)" -eq 0 ]</automated>
  </verify>
  <done>`flutter analyze --no-fatal-infos` limpo e a suíte inteira verde sem editar nenhum teste existente; `atf_detail_screen.dart` cita `Breakpoints.rail` uma vez; `atf_dg_table_view.dart` não tem literal de cor; `atf_repository.dart` intocado.</done>
</task>

<task type="auto">
  <name>Task 2: registro de DG inline por linha + seleção múltipla com barra contextual em lote</name>
  <files>lib/features/reproducao/presentation/atf_dg_table_view.dart</files>
  <action>
Estado local em `_AtfDgTableViewState`: `final Set&lt;String&gt; _selectedIds = {}` e `bool _saving = false`.

Método único de escrita, usado pelos dois caminhos: `Future&lt;void&gt; _registerDg(List&lt;String&gt; animalIds, DgResult result)`. Filtra fora os animais cujo `latestDgFor(...)` já é aquele resultado (assunção 8); se sobrar zero, retorna sem chamar nada. Monta um mapa por animal com `animal_id`, `result` (o `dbValue` do enum) e `exam_date` = hoje em `yyyy-MM-dd`, e faz UMA chamada `ref.read(atfRepositoryProvider).saveDgRecords(atfBatchId: atf.id, records: ...)`. Em sucesso: invalidar `dgRecordsByAtfProvider(atf.id)`, `atfByIdProvider(atf.id)`, `atfListByPropertyProvider` e `reproductiveHistoryByAnimalProvider(id)` de cada animal afetado, limpar a seleção e mostrar o SnackBar 'DGs registrados.' — as mesmas invalidações e a mesma cópia do `_save()` mobile. Em erro: SnackBar 'Erro ao salvar DGs. Tente novamente.' e seleção preservada. `_saving` desabilita todos os controles de escrita enquanto a chamada corre.

Célula RESULTADO (só quando `canEdit`): quando o DG mais recente é `doubtful`, um `StatusChip('Duvidosa', kind: StatusKind.warning)` antes dos botões (assunção 9). Depois o par inline "Prenhe" / "Vazia": altura 32, raio 8, outline `AppColors.primary` / `AppColors.danger` quando não registrado, preenchido com o mesmo tom e texto `AppColors.onGreen` / `AppColors.onDanger` quando registrado. Tocar o resultado já registrado é no-op; tocar o outro chama `_registerDg([m.animalId], result)`. Fora de `canEdit` a célula só mostra o rótulo do resultado atual, ou `—`.

Coluna de checkbox (só quando `canEdit`): `Checkbox` por linha alternando `_selectedIds`, e um checkbox de "selecionar tudo" no cabeçalho com estado tristate derivado do tamanho da seleção contra o total de linhas.

Barra contextual, renderizada entre o bloco de topo e o cabeçalho de colunas apenas quando `_selectedIds` não está vazio: fundo `AppColors.primaryDarkText`, texto `AppColors.onGreen`, altura 48. Contador mono "N selecionadas" (singular "1 selecionada"), depois "Marcar prenhe" → `_registerDg(selecionados, DgResult.pregnant)`, "Marcar vazia" → `_registerDg(selecionados, DgResult.notPregnant)`, e "Remover do ATF" com o portão da assunção 13 — confirmação em `AlertDialog` e, ao confirmar, `Future.wait` de `removeAnimalFromAtf` por animal, invalidando `atfActiveMembershipsProvider`, `atfMembershipsProvider`, `atfListByPropertyProvider` e o histórico de cada animal, exatamente como o `_confirmRemove` mobile. Fecha com um `IconButton` de limpar seleção. Continua sem literal de cor hex no arquivo.
  </action>
  <verify>
    <automated>cd "F:/_geral/Projetos/campo_gestor" &amp;&amp; flutter analyze --no-fatal-infos &amp;&amp; flutter test &amp;&amp; git diff --exit-code -- test/widget/atf_detail_screen_test.dart &amp;&amp; [ "$(grep -v '^\s*//' lib/features/reproducao/presentation/atf_dg_table_view.dart | grep -c 'Color(0x')" -eq 0 ] &amp;&amp; [ "$(grep -v '^\s*//' lib/features/reproducao/presentation/atf_dg_table_view.dart | grep -c 'saveDgRecords')" -eq 1 ] &amp;&amp; [ "$(git diff --name-only -- lib/features/reproducao/data/atf_repository.dart | wc -l)" -eq 0 ]</automated>
  </verify>
  <done>Existe exatamente UMA chamada a `saveDgRecords` no arquivo (individual e lote passam pelo mesmo método); `atf_repository.dart` intocado; analyze limpo; suíte verde sem editar teste existente.</done>
</task>

<task type="auto">
  <name>Task 3: teste de widget dos dois lados do corte de 1024px</name>
  <files>test/widget/atf_detail_desktop_test.dart</files>
  <action>
Criar `test/widget/atf_detail_desktop_test.dart` seguindo o harness de `animais_desktop_test.dart` (`tester.binding.setSurfaceSize` com `addTearDown(() =&gt; ...setSurfaceSize(null))`) e as fakes/overrides de `atf_detail_screen_test.dart` (`_FakeAtfRepo` capturando o payload de `saveDgRecords`, overrides de `atfByIdProvider`, `atfActiveMembershipsProvider`, `atfMembershipsProvider`, `dgRecordsByAtfProvider`, `atfListByPropertyProvider`, `memberPropertiesProvider`, `atfRepositoryProvider`, mais `animalListByPropertyProvider` para as colunas de lote e raça). Não editar nem importar de `atf_detail_screen_test.dart` — as fakes são locais deste arquivo.

Casos:
1. 1440x900 renderiza `AtfDgTableView` e não renderiza `AtfHeaderCard`.
2. 800x600 renderiza `AtfHeaderCard` e nenhum `AtfDgTableView` — o fluxo de hoje intacto.
3. Desktop: clicar "Prenhe" na linha de um animal sem DG chama `saveDgRecords` uma vez, com exatamente um registro, `animal_id` correto e `result` `pregnant`.
4. Desktop: marcar os checkboxes de dois animais mostra o contador "2 selecionadas" e "Marcar vazia" envia UM payload com os dois `animal_id` e `result` `not_pregnant`.
5. Desktop: numa linha cujo DG mais recente já é `pregnant`, clicar "Prenhe" não chama `saveDgRecords` (payload capturado continua nulo) — regra de no-op da assunção 8.
6. Desktop com papel `reader`: nenhum `Checkbox` e nenhum botão de resultado na tabela.
  </action>
  <verify>
    <automated>cd "F:/_geral/Projetos/campo_gestor" &amp;&amp; flutter analyze --no-fatal-infos &amp;&amp; flutter test test/widget/atf_detail_desktop_test.dart &amp;&amp; flutter test &amp;&amp; git diff --exit-code -- test/widget/atf_detail_screen_test.dart &amp;&amp; [ "$(grep -c 'testWidgets(' test/widget/atf_detail_desktop_test.dart)" -eq 6 ]</automated>
  </verify>
  <done>Os 6 `testWidgets` passam, a suíte inteira segue verde e `test/widget/atf_detail_screen_test.dart` não tem uma linha alterada.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Flutter web → PostgREST/RPC | Toda escrita de DG e de composição atravessa aqui; o cliente é território do usuário |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-tos-01 | Elevation of Privilege | barra contextual / botões inline | medium | mitigate | `canEdit` só esconde a UI; a autorização real continua sendo o re-check de papel `veterinarian` dentro de `save_dg_records` e `remove_animal_from_atf` (SECURITY DEFINER). Nenhuma tabela nova é escrita direto e nenhum portão server-side é contornado — a task não toca em SQL. |
| T-tos-02 | Tampering | DG em lote | medium | mitigate | Registro segue aditivo: uma única chamada a `saveDgRecords` (insert-only), sem update nem delete de `dg_records`, preservando a trilha de correção D-12/D-16. |
| T-tos-03 | Information Disclosure | `animalListByPropertyProvider` | low | accept | Provider já em uso em `AnimaisScreen`, filtrado por `property_id` e coberto pelo RLS multi-tenant vigente; nenhum escopo novo de leitura é aberto. |
</threat_model>

<verification>
- `flutter analyze --no-fatal-infos` limpo.
- `flutter test` verde por inteiro.
- `git diff --exit-code -- test/widget/atf_detail_screen_test.dart` — nenhum teste existente da tela editado.
- `git diff --name-only -- lib/features/reproducao/data/atf_repository.dart` vazio — nenhum método novo, nenhuma query nova.
- Nenhum literal de cor hex em `atf_dg_table_view.dart`.
</verification>

<success_criteria>
Em ≥1024px o detalhe do ATF mostra a tabela de fêmeas com registro de DG inline e barra
contextual de ações em lote sobre o mesmo RPC que o mobile usa; em <1024px o fluxo é o
de hoje e a suíte existente passa sem edição.
</success_criteria>

<output>
Create `.planning/quick/260813-tos-dg-em-massa-na-tabela-do-detalhe-do-atf-/260813-tos-SUMMARY.md` when done
</output>
