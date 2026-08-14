---
phase: quick-260813-wmm
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/auth/presentation/auth_scaffold.dart
  - test/widget/auth_scaffold_test.dart
autonomous: true
requirements: []

must_haves:
  truths:
    - "Em >=600px a folha de login deixa de ficar colada na borda inferior e vira um card creme de 440px de largura, cantos arredondados nos quatro lados (raio 22) e sombra, centrado vertical e horizontalmente sobre o fundo verde."
    - "Em >=600px o bloco de marca (quadrado laranja com ícone + 'Campo Gestor' + tagline) fica logo acima do card, na mesma coluna centrada."
    - "Abaixo de 600px o layout atual permanece idêntico: marca no topo, painel bone colado embaixo, raio 22 só nos cantos superiores, SafeArea inferior preservada."
    - "Nas duas larguras os campos são exatamente o mesmo widget filho passado pela tela — nenhum campo, controller, validação ou ação é duplicado ou reescrito."
    - "Se o conteúdo não couber na altura da janela (formulário de cadastro em janela baixa), o conjunto marca+card rola em vez de estourar."
    - "Signup e reset de senha ganham o mesmo tratamento sem edição própria, por já usarem AuthScaffold."
  artifacts:
    - lib/features/auth/presentation/auth_scaffold.dart
    - test/widget/auth_scaffold_test.dart
  key_links:
    - "AuthScaffold.build -> LayoutBuilder -> Breakpoints.mobile (600) decide entre card centrado e folha inferior; nenhum novo valor de largura fora de Breakpoints/440"
    - "LoginScreen/SignupScreen/ResetPasswordScreen -> AuthScaffold(child:) — o mesmo Form atravessa os dois branches sem cópia"
    - "AuthScaffold.cardKey / AuthScaffold.sheetKey -> test/widget/auth_scaffold_test.dart (única forma de distinguir os dois branches, já que ambos limitam a 440)"
  prohibitions:
    - "Zero diff em lib/features/auth/data/, lib/features/auth/providers/, login_screen.dart, signup_screen.dart e reset_password_screen.dart."
    - "Nenhum campo de formulário, controller ou validador dentro de auth_scaffold.dart."
    - "Nenhum literal de cor no arquivo — tudo de AppColors (derivar alpha com withValues)."
    - "Nenhum package novo: pubspec.yaml e pubspec.lock sem diff."
    - "Nenhum arquivo de teste existente pode ser editado."
    - "Nenhuma mudança visual ou de espaçamento abaixo de 600px."
---

<objective>
Reancorar a folha de auth em telas largas: a partir de `Breakpoints.mobile` (600px) o painel bone deixa de ser uma folha colada no rodapé (herança do layout mobile) e vira um card de 440px centrado sobre o fundo verde musgo, com o bloco de marca imediatamente acima. Abaixo de 600px nada muda.

Purpose: `/login` é a única tela do app que ainda cai no layout mobile em janela de desktop — o formulário fica ancorado no rodapé com metade da tela verde vazia por cima. É também a primeira tela que qualquer usuário vê, então a inconsistência com o shell adaptativo (quick task 260813-ok3) é a mais visível do produto.
Output: um branch adaptativo dentro de `auth_scaffold.dart` (arquivo único; login, signup e reset herdam) e `test/widget/auth_scaffold_test.dart`.
</objective>

<execution_context>
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/workflows/execute-plan.md
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@lib/features/auth/presentation/auth_scaffold.dart
@lib/core/theme/breakpoints.dart
@lib/core/theme/app_colors.dart

Interface já existente (não alterar):
- `AuthScaffold({required String title, String? tagline, IconData icon = Icons.grass, required Widget child})` — `child` é o `Form` completo da tela. Três chamadores: `login_screen.dart:78`, `signup_screen.dart:67`, `reset_password_screen.dart:90`.
- `Breakpoints.mobile = 600` — única fonte da faixa; não redeclarar o número.
- `AppColors.primary` (fundo verde), `AppColors.background` (bone do painel), `AppColors.accent`/`onAccent` (quadrado do logo), `AppColors.onGreen`/`onGreenSecondary` (título/tagline), `AppColors.ink` (base para a sombra).
- O projeto usa `withValues(alpha:)` (11 ocorrências), nunca `withOpacity`.
- Harness de teste de largura já estabelecido em `test/widget/animais_desktop_test.dart:131-145`: `tester.binding.setSurfaceSize(...)` com `addTearDown(() => tester.binding.setSurfaceSize(null))`.
</context>

<tasks>

<task type="auto">
  <name>Task 1: AuthScaffold adaptativo — card 440px centrado em >=600px, folha intacta abaixo</name>
  <files>lib/features/auth/presentation/auth_scaffold.dart</files>
  <behavior>
    - Superfície 900x800: o painel bone tem largura exatamente 440, está centrado horizontalmente e não encosta na borda inferior da tela.
    - Superfície 400x800: o painel bone continua encostado na borda inferior, com os cantos inferiores retos.
    - Nas duas superfícies o widget `child` recebido é montado uma única vez na árvore.
  </behavior>
  <action>
Editar apenas `auth_scaffold.dart`. Manter a assinatura pública do construtor exatamente como está — as três telas chamadoras não podem ser tocadas.

1. Importar `../../../core/theme/breakpoints.dart`.

2. Expor duas chaves públicas estáticas na classe para o teste distinguir os branches (ambos limitam a 440, então largura sozinha não distingue): `static const Key cardKey = ValueKey('auth-card');` e `static const Key sheetKey = ValueKey('auth-sheet');`.

3. Extrair o bloco de marca atual (quadrado 52x52 `AppColors.accent` raio 14 com o `icon`, gap 18, `title` 32/w700 `AppColors.onGreen`, gap 10, `tagline` opcional 15/height 1.5 `AppColors.onGreenSecondary`) para um método privado `Widget _brand()` — usado pelos dois branches, sem cópia. Preservar byte a byte os tamanhos e cores atuais.

4. Dentro do `LayoutBuilder` já existente, decidir por `constraints.maxWidth >= Breakpoints.mobile`.

5. Branch estreito (`< Breakpoints.mobile`): manter a árvore atual sem nenhuma alteração de espaçamento, padding, raio ou `SafeArea` — o único acréscimo permitido é `key: sheetKey` no `Container` do painel. Este branch é regressão pura; qualquer diferença visual aqui é falha.

6. Branch largo (`>= Breakpoints.mobile`): substituir a `Column` `spaceBetween` por uma composição centrada e rolável — `Center` > `SingleChildScrollView` (padding vertical 40, horizontal 24) > `Center` > `ConstrainedBox(maxWidth: 440)` > `Column(mainAxisSize: MainAxisSize.min)` com `_brand()`, um gap de 28 e o card. O `SingleChildScrollView` é obrigatório: o formulário de cadastro em janela baixa precisa rolar em vez de estourar.

7. O card do branch largo: `Container(key: cardKey, width: double.infinity)` com `AppColors.background`, `BorderRadius.circular(22)` (os quatro cantos, diferente da folha que arredonda só o topo), padding `fromLTRB(24, 26, 24, 18)` e uma sombra em `boxShadow` — cor derivada de `AppColors.ink` via `withValues(alpha: 0.18)`, blur 32, offset `Offset(0, 14)`. Nenhum valor de cor escrito à mão. O filho é o `child` recebido, direto: sem `SafeArea` inferior neste branch (o card não encosta na borda).

8. Atualizar o docstring da classe: a composição larga agora é um card centrado de 440px, não uma folha limitada a 440px.

Nada de lógica de auth, nada de campo, controller ou validador entra neste arquivo — o formulário continua chegando inteiro pelo slot `child`.
  </action>
  <verify>
    <automated>flutter analyze --no-fatal-infos lib/features/auth/presentation/auth_scaffold.dart</automated>
    <automated>git diff HEAD --exit-code -- lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/signup_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/data lib/features/auth/providers pubspec.yaml pubspec.lock  # rodar ANTES do commit</automated>
    <automated>grep -v '^\s*//' lib/features/auth/presentation/auth_scaffold.dart | grep -c 'TextFormField' | grep -qx 0</automated>
    <automated>grep -v '^\s*//' lib/features/auth/presentation/auth_scaffold.dart | grep -cE 'Color\(0x' | grep -qx 0</automated>
  </verify>
  <done>`auth_scaffold.dart` é o único arquivo de produção modificado; analyze limpo; nenhum campo de formulário nem literal de cor no arquivo; as três telas de auth, o repositório e os providers com diff zero.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Teste de largura do AuthScaffold + suíte completa</name>
  <files>test/widget/auth_scaffold_test.dart</files>
  <behavior>
    - `>=600px mostra card centrado de 440`: superfície 900x800, `find.byKey(AuthScaffold.cardKey)` encontra um widget, `tester.getSize(...).width` é 440, `find.byKey(AuthScaffold.sheetKey)` não encontra nada, e o `bottom` do card é menor que 800 (não encosta no rodapé).
    - `<600px mantém a folha inferior`: superfície 400x800, `find.byKey(AuthScaffold.sheetKey)` encontra um widget, `find.byKey(AuthScaffold.cardKey)` não encontra nada.
    - `o filho atravessa as duas larguras`: um sentinela (`Text('form-sentinel')`) passado como `child` aparece exatamente uma vez em cada uma das duas larguras.
  </behavior>
  <action>
Criar `test/widget/auth_scaffold_test.dart` seguindo o harness de `test/widget/animais_desktop_test.dart:131-145` (`setSurfaceSize` + `addTearDown` restaurando `null`).

O teste monta `AuthScaffold` diretamente dentro de um `MaterialApp` — sem router, sem `ProviderScope`, sem repositório falso: o scaffold é um `StatelessWidget` puro, e essa é a razão de testá-lo em vez de `LoginScreen`. `child` é um `Text('form-sentinel')`, provando que o slot é atravessado sem cópia nas duas larguras.

Cabeçalho do arquivo: uma linha de comentário identificando a quick task 260813-wmm e o que o arquivo prova.

Depois rodar a suíte inteira e o analyze do projeto: a mudança toca a tela de entrada de três fluxos, e qualquer teste existente que dependa da árvore de auth precisa continuar verde sem edição.
  </action>
  <verify>
    <automated>flutter test test/widget/auth_scaffold_test.dart</automated>
    <automated>flutter test</automated>
    <automated>flutter analyze --no-fatal-infos</automated>
    <automated>git status --porcelain test/ | grep -v '^?? test/widget/auth_scaffold_test.dart$' | grep -cx '' | grep -qx 0  # nenhum teste existente editado</automated>
  </verify>
  <done>Os três testes novos passam; a suíte completa continua verde (360+ testes) sem nenhum arquivo de teste pré-existente modificado; analyze do projeto limpo.</done>
</task>

</tasks>

<verification>
1. `flutter analyze --no-fatal-infos` — limpo.
2. `flutter test` — suíte completa verde, incluindo os 3 casos novos.
3. `git diff HEAD --stat` antes do commit final lista exatamente 2 arquivos: `lib/features/auth/presentation/auth_scaffold.dart` e `test/widget/auth_scaffold_test.dart`.
4. Checagem visual (humana, pós-deploy — não bloqueia): `/login` em janela larga mostra marca + card centrado; em 375px de largura a folha inferior está igual à de hoje. `/signup` e `/reset-password` herdam o card sem edição própria.
</verification>

<success_criteria>
- Em >=600px: card bone de 440px, raio 22 nos quatro cantos, sombra, centrado, com a marca acima; rola quando não cabe.
- Em <600px: layout atual byte a byte.
- Zero mudança de lógica de auth: `login_screen.dart`, `signup_screen.dart`, `reset_password_screen.dart`, `data/` e `providers/` com diff zero.
- Formulário não duplicado: um único `child`, um único branch de campos.
- Nenhum literal de cor fora de `AppColors`; nenhuma package nova.
</success_criteria>

<output>
Create `.planning/quick/260813-wmm-login-desktop-card-centralizado-440px-so/260813-wmm-SUMMARY.md` when done
</output>
