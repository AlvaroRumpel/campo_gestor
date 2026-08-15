---
phase: quick-260815-h9w
plan: 01
subsystem: ui
tags: [flutter, riverpod, go_router, supabase, propriedades, membros, auth]

requires:
  - phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
    provides: PropriedadesScreen alternador Ativas/Arquivadas, MembrosScreen, DetailAppBar, routerProvider
provides:
  - fetchArchivedProperties() escopado por papel de veterinário (property_members)
  - alternador Ativas/Arquivadas e botão Restaurar ausentes (não desabilitados) para leitor/proprietário
  - GoRouter.optionURLReflectsImperativeAPIs=true — address bar acompanha todo context.push
  - tela terminal de confirmação de e-mail no signup, citando o e-mail informado
  - DetailAppBar.actions (slot opcional) + ação Atualizar em MembrosScreen
affects: [10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade]

tech-stack:
  added: []
  patterns:
    - "Gate de UI derivado da query já escopada por papel, não de um flag de permissão separado (archivedPropertyListProvider vet-only) — controle ausente, não desabilitado (role_gates.dart)"

key-files:
  created: []
  modified:
    - lib/features/propriedades/data/propriedade_repository.dart
    - lib/features/propriedades/presentation/propriedades_screen.dart
    - lib/core/router/router.dart
    - lib/features/auth/presentation/signup_screen.dart
    - lib/core/widgets/campo_app_bar.dart
    - lib/features/membros/presentation/membros_screen.dart
    - test/widget/propriedades_screen_test.dart
    - test/features/auth/signup_screen_test.dart
    - test/widget/membros_screen_test.dart

key-decisions:
  - "G-10-04 fechado escopando a QUERY (property_members filtrado por role='veterinarian'), não só o controle de UI — o RLS de properties não conhecia o papel do usuário na fazenda arquivada"
  - "G-10-01 era um bug de uma linha no go_router (optionURLReflectsImperativeAPIs), não rota faltante — a rota /propriedades já existia e já era aberta via push"
  - "G-10-02 trocado SnackBar+go(login) por estado terminal na própria tela — SnackBar não sobrevive à troca de rota"
  - "G-10-03 resolvido com uma ação manual de recarregar (Realtime é fora do MVP por CLAUDE.md) — providers já são auto-dispose (Riverpod 3.x), o furo era só a tela permanecer montada"

requirements-completed: [PROPV-02, MEMB-02, MEMB-03]

coverage:
  - id: D1
    description: "Leitor/proprietário não veem o alternador Ativas/Arquivadas nem a lista de arquivadas; veterinário continua vendo e conseguindo restaurar"
    requirement: "PROPV-02"
    verification:
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#non-veterinarian gate: empty archived (what the query returns for a reader) hides the alternador entirely"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#veterinarian gate: non-empty archived shows the alternador and still switches lists"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#archived card shows Restaurar fazenda button, not PopupMenuButton"
        status: pass
    human_judgment: true
    rationale: "Gap veio de UAT humana em produção contra o Supabase real; a query em property_members precisa ser confirmada com uma conta leitora de verdade no browser, não só com os overrides sintéticos do widget test"
  - id: D2
    description: "Abrir Fazendas pelo seletor muda a URL do browser para /propriedades (e os demais context.push do app refletem a URL)"
    requirement: null
    verification:
      - kind: unit
        ref: "grep -c \"optionURLReflectsImperativeAPIs = true\" lib/core/router/router.dart"
        status: pass
    human_judgment: true
    rationale: "GoRouter.optionURLReflectsImperativeAPIs afeta o comportamento real do address bar do browser — não há teste de widget que observe a URL do navegador; precisa confirmação visual no browser (registrada no plano como item de UAT humana no deploy)"
  - id: D3
    description: "Signup com confirmação pendente termina numa tela própria citando o e-mail informado, com botão Voltar para entrar"
    requirement: null
    verification:
      - kind: unit
        ref: "test/features/auth/signup_screen_test.dart#successful signUp with pending confirmation shows the e-mail in a terminal screen and does not navigate away"
        status: pass
    human_judgment: false
  - id: D4
    description: "Ação Atualizar na tela de Membros refaz os fetches de membros, convites e memberships"
    requirement: "MEMB-02, MEMB-03"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#G-10-03: tapping the Atualizar action refetches propertyMembersProvider"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-15
status: complete
---

# Quick Task 260815-h9w Summary

**Fecha os 4 gaps da UAT humana da Fase 10 (10-11-SUMMARY.md): fazendas arquivadas vazando para papéis não-vet via query escopada em `property_members`, `GoRouter.optionURLReflectsImperativeAPIs` ligado para o address bar acompanhar `context.push`, tela terminal de confirmação de e-mail no signup, e ação Atualizar na tela de Membros.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-15T15:37:34Z
- **Completed:** 2026-08-15T15:52:14Z
- **Tasks:** 3
- **Files modified:** 9 (6 produção, 3 teste)

## Accomplishments

- `fetchArchivedProperties()` consulta `property_members` filtrado por `role='veterinarian'` em vez de `properties` direto — o RLS de `properties` não conhecia o papel do usuário na fazenda arquivada, então qualquer membro (leitor/proprietário) via a fazenda e o botão Restaurar, que o banco recusaria
- `PropriedadesScreen` deriva `canSeeArchived`/`showArchived` da própria lista de arquivadas (já vet-only): alternador e botão Restaurar ficam ausentes da árvore para quem não tem nada arquivado, em vez de desabilitados — cobre inclusive o vet cuja única fazenda está arquivada
- `GoRouter.optionURLReflectsImperativeAPIs = true` no `routerProvider` — sem essa flag, `restoreRouteInformation` reportava ao browser a URL do último `go()`, ignorando qualquer `context.push` (afeta globalmente `/propriedades`, `/lotes/:id`, `/atfs/:id`, `/aplicacoes/:id`, `/gastos/:paddockId`, `/propriedades/:id/membros`)
- Signup com confirmação pendente (`session == null` na resposta) termina numa tela própria (`AuthScaffold` reaproveitado) citando o e-mail digitado e oferecendo "Voltar para entrar", em vez de SnackBar + `context.go(login)` (SnackBar não sobrevive à troca de rota)
- `DetailAppBar` ganhou o slot opcional `actions`; `MembrosScreen` passa um `IconButton` "Atualizar" que reusa os três invalidadores já existentes (`_invalidateMembers`, `_invalidateInvites`, `_invalidateMemberships`)

## Task Commits

Each task was committed atomically:

1. **Task 1: G-10-04 — arquivadas e Restaurar só para veterinário (PROPV-02)** - `a0e0a93` (fix)
2. **Task 2: G-10-01 URL do push + G-10-02 aviso de confirmação de e-mail** - `d3df388` (fix)
3. **Task 3: G-10-03 — recarregar membros e convites sem recarregar a página** - `658d27d` (fix)

_Nenhum commit de metadados de plano necessário adicional além deste SUMMARY (regra do dispatch: sem ROADMAP.md/STATE.md)._

## Files Created/Modified

- `lib/features/propriedades/data/propriedade_repository.dart` - `fetchArchivedProperties()` reescrito para `property_members!inner(properties)` filtrado por `role='veterinarian'`
- `lib/features/propriedades/presentation/propriedades_screen.dart` - `canSeeArchived`/`showArchived` derivados da lista de arquivadas; alternador envolto em `if (canSeeArchived)`; empty state do "arquivado" removido (virou código morto); botão Restaurar deixa de depender de `canEdit`
- `lib/core/router/router.dart` - `GoRouter.optionURLReflectsImperativeAPIs = true` como primeira instrução do `routerProvider`
- `lib/features/auth/presentation/signup_screen.dart` - campo `_sentTo`; `_submit` usa o `AuthResponse` retornado (retorna cedo se já autenticado, senão grava o e-mail); `build` retorna tela terminal quando `_sentTo != null`
- `lib/core/widgets/campo_app_bar.dart` - `DetailAppBar` ganha `final List<Widget>? actions` opcional, espalhado após `contextPill`
- `lib/features/membros/presentation/membros_screen.dart` - `DetailAppBar.actions` com `IconButton` "Atualizar" reusando os invalidadores existentes
- `test/widget/propriedades_screen_test.dart` - teste do empty state arquivado removido; teste de papel não-vet trocado por dois casos de gate (vazio esconde alternador; não-vazio mostra e continua alternando)
- `test/features/auth/signup_screen_test.dart` - teste reescrito para a tela terminal (verifica e-mail citado + navegação só ao tocar "Voltar para entrar")
- `test/widget/membros_screen_test.dart` - novo caso: contador de fetch incrementa de 1 para 2 ao tocar "Atualizar"

## Decisions Made

- G-10-04 exigiu mudar a fonte do dado (query), não só o gate de UI — só assim o caso "vet numa fazenda, leitor noutra" sai correto sem lógica adicional
- G-10-01 não era falta de rota: `/propriedades` já era `GoRoute` root-level aberta via `context.push`; a causa era `optionURLReflectsImperativeAPIs=false` (padrão do go_router 17.2.3)
- G-10-03 não usou `autoDispose` (já é o padrão do Riverpod 3.x) nem Realtime (fora do MVP por CLAUDE.md) — a correção proporcional foi uma ação manual de recarregar

## Deviations from Plan

None - plan executado exatamente como escrito.

## Issues Encountered

- Worktree fresco não tinha os arquivos gerados (`*.freezed.dart`, `*.g.dart`) de `propriedade_model.dart` e outros modelos `freezed`/`json_serializable` — `dart run build_runner build` (60s) resolveu antes de qualquer teste rodar. Não é um deviation de código, é infraestrutura de worktree esperada pelo próprio dispatch.

## User Setup Required

None - nenhuma configuração de serviço externo necessária.

## UAT Humana Pendente no Deploy

Registrado para a UAT humana no browser, conforme pedido pelo plano (fora do escopo automatizável deste executor):

1. Confirmar no browser que abrir Fazendas pelo seletor muda o address bar para `/propriedades` e que F5 nessa URL recarrega a tela — e que os outros `push` do app (`/lotes/:id`, `/aplicacoes/:id`, `/gastos/:paddockId`, `/propriedades/:id/membros`) passaram a refletir a URL também, já que a flag é global.
2. Confirmar com uma conta leitora que a aba Arquivadas sumiu.

## Fora de Escopo (não é regressão deste plano)

O banner de convites do dashboard usa `myInvitesProvider`, e a `DashboardScreen` fica permanentemente montada dentro do `StatefulShellRoute.indexedStack`, então um convite criado depois da carga do app só aparece após recarregar. É o mesmo sintoma do G-10-03 do lado do convidado, mas a causa é o keep-alive do shell, não o provider — não foi tocado por este plano.

## Next Phase Readiness

- Os 4 gaps da UAT da Fase 10 (`10-11-SUMMARY.md`) estão fechados no código; `flutter analyze` sem issues novos (4 infos pré-existentes, não relacionados) e `flutter test` com as 538 suítes verdes
- Sem migration, sem `supabase db push`: os quatro gaps eram inteiramente de cliente
- Pendente apenas a UAT humana no deploy listada acima

---
*Phase: quick-260815-h9w*
*Completed: 2026-08-15*

## Self-Check: PASSED

- All 9 modified source/test files confirmed present on disk.
- Commits `a0e0a93`, `d3df388`, `658d27d` confirmed present in `git log`.
