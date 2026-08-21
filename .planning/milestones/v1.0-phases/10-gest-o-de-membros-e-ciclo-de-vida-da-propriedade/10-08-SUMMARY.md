---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 08
subsystem: auth
tags: [flutter, riverpod, invites, empty-state, widget-test]

# Dependency graph
requires:
  - phase: 10-04
    provides: "InviteBanner widget (accept/decline UI) and myInvitesProvider consumers"
provides:
  - "/sem-acesso reads myInvitesProvider and renders the invitee's pending invites via InviteBanner"
  - "_exitActions extraction (Criar minha fazenda / Sair) reused across loading/error/empty/data states"
affects: [10-09, membership-lifecycle]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Riverpod 3 ProviderContainer(retry: (retryCount, error) => null) to make FutureProvider error states deterministic in widget tests (auto-retry with exponential backoff otherwise masks AsyncError behind AsyncLoading)"

key-files:
  created:
    - test/widget/no_access_screen_test.dart
  modified:
    - lib/features/auth/presentation/no_access_screen.dart

key-decisions:
  - "Extracted _exitActions(BuildContext, WidgetRef) as a private method on NoAccessScreen so 'Criar minha fazenda'/'Sair' render identically in all four AsyncValue states, instead of duplicating the Column"
  - "No new handlers for aceitar/recusar added here — InviteBanner (10-04) owns that logic entirely, per plan prohibition"

patterns-established:
  - "AsyncValue.when() screens: loading -> spinner, error -> ErrorRetry with ref.invalidate, empty data -> EmptyState, non-empty data -> ListView; exits/actions factored into a shared widget-returning method so no branch is a dead end"

requirements-completed: [MEMB-01]

coverage:
  - id: D1
    description: "/sem-acesso lists the logged-in user's pending invites via InviteBanner instead of the old dead-end copy"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/widget/no_access_screen_test.dart#two pending invites render two InviteBanner widgets"
        status: pass
      - kind: unit
        ref: "test/widget/no_access_screen_test.dart#empty invites: shows the new empty-state copy, not the old one"
        status: pass
    human_judgment: false
  - id: D2
    description: "Loading, error (with working retry), and 360px-overflow states are all covered, and both exit actions persist in every state"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/widget/no_access_screen_test.dart#error loading invites shows ErrorRetry, and tapping retry invalidates the provider"
        status: pass
      - kind: unit
        ref: "test/widget/no_access_screen_test.dart#shows a CircularProgressIndicator while invites load"
        status: pass
      - kind: unit
        ref: "test/widget/no_access_screen_test.dart#at 360px, two invites with long farm names render with no overflow exception"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 08: /sem-acesso vira caixa de entrada de convites Summary

**NoAccessScreen agora observa `myInvitesProvider` (RPC `list_my_invites`) e renderiza um `InviteBanner` por convite pendente, substituindo a antiga copy "entre em contato com o proprietário" por um estado vazio, de carregamento e de erro totalmente autorados, com "Criar minha fazenda" e "Sair" sempre presentes.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-08-14
- **Tasks:** 1
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- `/sem-acesso` deixou de ser um beco sem saída informativo: agora é o principal ponto de entrega de convites no MVP (sem e-mail transacional)
- Os quatro estados de `AsyncValue` (`loading`, `error`, `data` vazio, `data` com convites) estão cobertos, cada um mantendo as duas saídas existentes da tela
- Nenhuma lógica de aceitar/recusar foi duplicada — `InviteBanner` (plano 10-04) continua sendo o único dono dessa lógica

## Task Commits

Ciclo TDD completo (RED → GREEN):

1. **Task 1: Lista de convites, estado vazio e estado de erro em /sem-acesso**
   - RED: `69c8c4d` (test) — testes falhando contra a implementação antiga
   - GREEN: `69c7c04` (feat) — `NoAccessScreen` reescrita + correção do teste de erro para o auto-retry do Riverpod 3

## Files Created/Modified
- `lib/features/auth/presentation/no_access_screen.dart` — `ConsumerWidget` reescrito: `_exitActions` privado reutilizado nos quatro estados de `myInvitesProvider.when(...)`; `loading` mostra spinner; `error` mostra `ErrorRetry` com `ref.invalidate(myInvitesProvider)`; `data` vazio mostra `EmptyState` com a nova copy; `data` com convites mostra `ListView` com um `InviteBanner` por convite
- `test/widget/no_access_screen_test.dart` — 7 casos de widget test cobrindo os sete comportamentos do `<behavior>` do plano

## Decisions Made
- `_exitActions` extraído como método privado em vez de widget separado — evita boilerplate de uma classe nova para dois botões reutilizados apenas dentro deste arquivo
- Overrides de teste usam `ProviderContainer(retry: (retryCount, error) => null, ...)` para o caso de erro — Riverpod 3 auto-retenta `FutureProvider`s com falha por padrão (backoff exponencial), o que mascarava `AsyncError` atrás de `AsyncLoading` até o retry se resolver. Esse padrão já existe em `test/widget/sanitary_history_section_test.dart`; apenas foi replicado aqui.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerado código gerado (freezed/json_serializable/riverpod_generator) antes de `flutter analyze`**
- **Found during:** Verificação pós-implementação (`flutter analyze`)
- **Issue:** Worktree fresco não tinha os arquivos `*.g.dart`/`*.freezed.dart` sincronizados com os modelos atuais, gerando ~850 erros de análise em arquivos não relacionados a este plano (getters/métodos ausentes em `Paddock`, `Property`, `AtfBatch`, `Animal`, etc.)
- **Fix:** `flutter pub run build_runner build --delete-conflicting-outputs` (conforme instruído nas constraints de execução do plano: "worktree fresco: flutter pub get + build_runner se preciso antes de analyze/test")
- **Files modified:** nenhum arquivo rastreado por git (saídas de `build_runner` estão em `.gitignore`)
- **Verification:** `flutter analyze` caiu de ~850 erros para 4 avisos `info` pré-existentes não relacionados a este plano

**2. [Rule 1 - Bug] Teste do estado de erro corrigido para o comportamento de auto-retry do Riverpod 3**
- **Found during:** Task 1 — fase GREEN, primeira execução do teste de erro
- **Issue:** `ProviderContainer` padrão (sem override de `retry`) reenviava automaticamente a chamada da `FutureProvider` que falhou (backoff exponencial), fazendo o estado transicionar de `AsyncLoading(error: ...)` diretamente para `AsyncData` bem-sucedido antes que o teste pudesse observar o branch `error` do `.when()` — o texto "Erro ao carregar..." nunca aparecia
- **Fix:** Adicionado `retry: (retryCount, error) => null` ao `ProviderContainer` do teste, desabilitando o auto-retry apenas nesse cenário determinístico (mesmo padrão já usado em `test/widget/sanitary_history_section_test.dart`)
- **Files modified:** `test/widget/no_access_screen_test.dart`
- **Verification:** `flutter test test/widget/no_access_screen_test.dart` passa nos 7 casos
- **Committed in:** `69c7c04` (parte do commit GREEN da Task 1)

---

**Total deviations:** 2 auto-fixed (1 blocking — codegen do worktree, 1 bug — comportamento de teste)
**Impact on plan:** Nenhum dos dois desvios altera o comportamento de produção descrito no plano; ambos foram necessários para que a verificação (`flutter analyze` limpo, `flutter test` verde) refletisse corretamente o código já escrito.

## Issues Encountered
None além dos dois desvios documentados acima.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `NoAccessScreen` está pronta para o plano 10-09 (banner de convite no dashboard), que reusa o mesmo `InviteBanner` e `myInvitesProvider`
- Nenhum bloqueio identificado

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: lib/features/auth/presentation/no_access_screen.dart
- FOUND: test/widget/no_access_screen_test.dart
- FOUND: .planning/phases/10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade/10-08-SUMMARY.md
- FOUND: 69c8c4d (test commit)
- FOUND: 69c7c04 (feat commit)
