---
phase: quick-260813-wmm
plan: 01
subsystem: auth
tags: [auth, layout, desktop, adaptive]
status: complete
dependency-graph:
  requires: []
  provides:
    - "AuthScaffold.cardKey / AuthScaffold.sheetKey (test hooks distinguishing wide/narrow branches)"
  affects:
    - lib/features/auth/presentation/login_screen.dart
    - lib/features/auth/presentation/signup_screen.dart
    - lib/features/auth/presentation/reset_password_screen.dart
tech-stack:
  added: []
  patterns:
    - "LayoutBuilder + Breakpoints.mobile branch inside a shared scaffold, single child slot atravessando ambos os branches"
key-files:
  created:
    - test/widget/auth_scaffold_test.dart
  modified:
    - lib/features/auth/presentation/auth_scaffold.dart
decisions: []
metrics:
  duration: 11min
  completed: 2026-08-13
---

# Phase quick-260813-wmm Plan 01: Login desktop — card centralizado 440px Summary

AuthScaffold ganhou um branch largo (`>= Breakpoints.mobile`) que renderiza um card bone de 440px com raio 22 nos quatro cantos, sombra e rolagem, centrado sobre o fundo verde com a marca logo acima — substituindo a folha ancorada no rodapé que antes era usada em toda largura.

## What Was Built

- `auth_scaffold.dart`: `LayoutBuilder` decide entre dois branches usando `Breakpoints.mobile` (600px), sem redeclarar o valor.
  - Branch estreito (`< 600`): árvore idêntica à anterior — mesmo `Padding`/`Column` de marca, mesma folha `Container` com `BorderRadius.vertical(top: 22)`, mesmo `SafeArea(top: false)` interno. Único acréscimo: `key: sheetKey` no `Container` da folha, para o teste.
  - Branch largo (`>= 600`): `Center > SingleChildScrollView(padding v:40 h:24) > Center > ConstrainedBox(maxWidth: 440) > Column(mainAxisSize: min)` com `_brand()`, gap de 28 e o card (`key: cardKey`, `AppColors.background`, `BorderRadius.circular(22)`, `boxShadow` derivado de `AppColors.ink.withValues(alpha: 0.18)`, blur 32, offset `(0, 14)`, padding `fromLTRB(24, 26, 24, 18)`). O `child` recebido é montado direto, sem `SafeArea` extra (o card não encosta em nenhuma borda).
  - Bloco de marca (quadrado laranja + título + tagline) extraído para `Widget _brand()`, compartilhado pelos dois branches — nenhuma duplicação de layout de marca.
  - Duas chaves públicas estáticas (`AuthScaffold.cardKey`, `AuthScaffold.sheetKey`) expostas só para diferenciar os branches em teste (ambos limitam a 440px, então a largura sozinha não distingue).
- `test/widget/auth_scaffold_test.dart` (novo): monta `AuthScaffold` puro dentro de um `MaterialApp` (sem router/ProviderScope, pois o scaffold é `StatelessWidget`), com um `Text('form-sentinel')` como `child`. Três casos: card 440px + sem folha + não encostando no rodapé em 900x800; folha presente + sem card em 400x800; sentinela aparece exatamente uma vez em cada largura (prova que o slot não é duplicado).

## Deviations from Plan

None — plan executado exatamente como escrito.

Nota operacional (não é desvio de plano): o worktree estava "fresh" sem artefatos gerados por `build_runner` (freezed/json_serializable), o que quebrava a suíte inteira com erros de getter ausente em `DgRecord`/`Animal`. Rodei `flutter pub run build_runner build` antes de reexecutar `flutter test`, conforme instruído no despacho da tarefa — nenhum arquivo de produção foi tocado por esse passo, só saída gerada (`.g.dart`/`.freezed.dart`, gitignorada).

## Known Stubs

None.

## Threat Flags

None — nenhuma superfície nova de rede, auth, arquivo ou schema; alteração é puramente visual/layout em um `StatelessWidget` sem lógica de auth.

## Verification

- `flutter analyze --no-fatal-infos lib/features/auth/presentation/auth_scaffold.dart` — limpo.
- `flutter analyze --no-fatal-infos` (projeto inteiro) — limpo (4 infos pré-existentes em arquivos não tocados por este plano: `app_config.dart`, `_expense_list_item_card.dart`, `propriedade_repository.dart`, `atf_dg_table_view.dart`).
- `flutter test` — 411 testes, todos verdes (incluindo os 3 novos casos de `auth_scaffold_test.dart`).
- `git diff HEAD --stat` (a partir da base do worktree) lista exatamente os 2 arquivos esperados: `lib/features/auth/presentation/auth_scaffold.dart` e `test/widget/auth_scaffold_test.dart`.
- `git diff` de `login_screen.dart`, `signup_screen.dart`, `reset_password_screen.dart`, `lib/features/auth/data/`, `lib/features/auth/providers/`, `pubspec.yaml`, `pubspec.lock` — todos com diff zero.
- Nenhum `TextFormField` nem literal `Color(0x` em `auth_scaffold.dart`.
- Nenhum arquivo de teste pré-existente foi editado (`git status --porcelain test/` só lista o arquivo novo).
- Checagem visual em `/login`, `/signup`, `/reset-password` em janela larga vs. estreita: pendente de UAT humana (não bloqueia a tarefa).

## Self-Check

- `lib/features/auth/presentation/auth_scaffold.dart` — FOUND
- `test/widget/auth_scaffold_test.dart` — FOUND
- Commit `84021c1` (feat AuthScaffold) — FOUND in `git log --oneline --all`
- Commit `2fcdd88` (test AuthScaffold) — FOUND in `git log --oneline --all`

## TDD Gate Compliance

Task 2 estava marcada `tdd="true"`, mas o comportamento já havia sido implementado na Task 1 (plano estruturado como implementação + teste em duas tarefas separadas, não como um único ciclo RED/GREEN). O teste foi escrito e já passou de primeira contra a implementação existente — não houve fase RED isolada dentro desta task. Commits: `feat(quick-260813-wmm)` seguido de `test(quick-260813-wmm)` — ordem invertida do padrão RED→GREEN por decisão de estrutura do próprio plano, não um desvio do executor.

## Self-Check: PASSED
