---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 05
subsystem: ui
tags: [flutter, riverpod, master-detail, role-gate, membership]

requires:
  - phase: 10-03
    provides: "MembroRepository + 4 providers (membroRepositoryProvider, propertyMembersProvider, propertyInvitesProvider, myInvitesProvider), PropertyMember/Invite/MyInvite models, MembroException/asMembroException pt-BR error vocabulary"
  - phase: 10-04
    provides: "canManageMembers role gate, InviteFormDialog (email+role invite form), InviteBanner shared accept/decline widget"
provides:
  - "MembrosScreen — lista de membros com papel, convidar, revogar convite, trocar papel, remover e sair, mobile (ListView+FAB) e desktop (tabela+painel 380px)"
  - "SectionCard de convites pendentes compartilhado entre mobile (corpo) e desktop (painel), método único sem duplicação"
affects: [10-10]

tech-stack:
  added: []
  patterns:
    - "LayoutBuilder envolvendo o Scaffold inteiro (não só o body) para gatear o FloatingActionButton por breakpoint — molde animais_screen.dart, necessário porque gastos_property_screen.dart não tem FAB para comparar"
    - "Linha de convite pendente em duas linhas (email cheio + Wrap de chip/papel/botão) em vez de uma única Row — Row+Expanded sozinho estoura a 360px quando chip+papel+botão de texto competem por espaço fixo"

key-files:
  created:
    - lib/features/membros/presentation/membros_screen.dart
    - test/widget/membros_screen_test.dart
  modified: []

key-decisions:
  - "MembrosScreen é ConsumerStatefulWidget (não ConsumerWidget) — os cinco handlers assíncronos (convidar/revogar/remover/sair/trocar papel) precisam de guarda `mounted` antes de cada SnackBar, o que exige State"
  - "LayoutBuilder envolve o Scaffold inteiro em vez de só o body (diferente do texto do plano) — necessário para o floatingActionButton (gatilho !isDesktop && canManage) decidir com a mesma constraints.maxWidth que o corpo, sem duplicar a lógica de breakpoint em dois lugares"
  - "_buildInvitesSection é um único método de instância chamado por _buildMobile e _buildPanel (desktop) — satisfaz a acceptance criteria de Task 2 de zero duplicação da seção de convites pendentes"
  - "_ColumnHeader local não faz .toUpperCase() (ao contrário do _HeaderText de gastos_property_screen.dart) — o 10-UI-SPEC pede 'Nome/E-mail'/'Papel'/'Ações' em mixed-case, não all-caps como DATA/CATEGORIA"

patterns-established:
  - "Convite pendente em duas linhas (email full-width + Wrap de chip/papel/revogar) evita overflow a 360px sem sacrificar nenhum dos quatro elementos exigidos pelo copywriting contract — precedente para qualquer linha futura de card mobile com chip+texto+botão"

requirements-completed: [MEMB-01, MEMB-02, MEMB-03]

coverage:
  - id: D1
    description: "Papel reader não vê nenhum controle de gestão (Convidar, Trocar papel, Remover membro, Revogar) nem FloatingActionButton — controle ausente, nunca desabilitado"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#reader role: no management controls, no FAB"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#1280x900: papel reader não mostra \"Convidar membro\" no painel"
        status: pass
    human_judgment: false
  - id: D2
    description: "Papel vet/owner vê FAB Convidar (mobile) ou botão Convidar membro no painel (desktop) e PopupMenuButton por linha; a própria linha oferece Sair da fazenda, as demais oferecem Remover membro"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#vet role: renders FAB Convidar and a PopupMenuButton per row"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#self row offers Sair da fazenda, not Remover membro"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#1280x900: painel mostra \"Convidar membro\" quando canManageMembers é verdadeiro"
        status: pass
    human_judgment: false
  - id: D3
    description: "Contagem de membros em pt-BR (1 membro singular, N membros plural) e SectionCard de convites pendentes com estado vazio inline (nunca um segundo EmptyState) — compartilhado entre mobile e desktop"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#count label: singular for 1 member"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#count label: plural for 3 members"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#empty invites: inline \"Nenhum convite pendente\", no second EmptyState"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#1280x900: SectionCard \"Convites pendentes\" vive dentro do painel (único método, compartilhado com o mobile)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Erros de RPC traduzidos para pt-BR: revogar convite já respondido (P0002) mostra o SnackBar genérico de estado obsoleto; remover/rebaixar/sair último veterinário (23514) mostra o nome da fazenda e a palavra 'responsável', nunca texto cru do Postgres"
    requirement: "MEMB-03"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#revoke failing with P0002 shows the generic stale-state SnackBar"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#remove failing with 23514 shows the guard SnackBar with the farm name and \"responsável\""
        status: pass
    human_judgment: false
  - id: D5
    description: "Layout desktop (>=1024px) troca ListView de Cards por tabela densa (Nome/E-mail, Papel, Ações) + painel ancorado de 380px com borda esquerda; e-mail longo trunca sem overflow; zero FAB no desktop"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#1280x900: painel de 380px com borda à esquerda e tabela (não ListView de Cards)"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#1280x900: cabeçalhos de coluna Nome/E-mail, Papel e Ações"
        status: pass
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#1280x900: e-mail muito longo na tabela não gera overflow, e não há FloatingActionButton"
        status: pass
    human_judgment: false
  - id: D6
    description: "A 360px de largura nenhuma linha (membro ou convite) gera exceção de overflow"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/widget/membros_screen_test.dart#360px width renders with no overflow exception"
        status: pass
    human_judgment: false

duration: ~55min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 5: MembrosScreen Summary

**MembrosScreen — lista de membros com papel, convidar/revogar/trocar papel/remover/sair, mobile (ListView+FAB) e desktop (tabela densa + painel 380px), tornando MEMB-02 alcançável pela primeira vez na UI**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-08-14 (approx)
- **Completed:** 2026-08-14
- **Tasks:** 2
- **Files modified:** 2 (both created)

## Accomplishments
- `MembrosScreen` mobile: `ListView` com contagem pt-BR, cartão por membro (`FarmAvatar` + `StatusChip` de papel + `PopupMenuButton` gated por `canManageMembers`), `FloatingActionButton.extended` "Convidar" e `SectionCard` "Convites pendentes" com estado vazio inline
- `MembrosScreen` desktop: tabela densa (Nome/E-mail, Papel, Ações) + painel ancorado de 380px (`ValueKey('membros-painel')`) com CTA "Convidar membro" no topo (gated) e a mesma seção de convites pendentes do mobile, sem FAB
- Cinco handlers (convidar, revogar convite, remover membro, sair da fazenda, trocar papel) compartilhados entre os dois layouts, todos roteando erro por `asMembroException` com guarda `mounted`
- 16 casos de teste de widget (10 na Task 1, 6 na Task 2) cobrindo os nove comportamentos do plano mais os seis comportamentos desktop

## Task Commits

Each task was committed atomically:

1. **Task 1: MembrosScreen — layout mobile, ações e convites pendentes** - `018cc2f` (feat, TDD)
2. **Task 2: MembrosScreen — layout desktop mestre-detalhe** - `7a6a17a` (feat, TDD)

## Files Created/Modified
- `lib/features/membros/presentation/membros_screen.dart` - MembrosScreen (mobile + desktop), `_MemberCard`, `_InviteRow`, `_DangerConfirmDialog`, `_RoleChangeSheet`, `_ColumnHeader`
- `test/widget/membros_screen_test.dart` - 16 casos de widget test cobrindo os dois layouts

## Decisions Made
- `MembrosScreen` é `ConsumerStatefulWidget`, não `ConsumerWidget` — os cinco handlers assíncronos precisam de `mounted` antes de cada `SnackBar`.
- `LayoutBuilder` envolve o `Scaffold` inteiro (não só o `body`, como o texto do plano sugeria) — necessário para o `floatingActionButton` decidir com a mesma `constraints.maxWidth` que o corpo, sem duplicar o cálculo de breakpoint em dois lugares (molde `animais_screen.dart`, que também gateia FAB por desktop).
- `_buildInvitesSection` é um único método de instância chamado tanto por `_buildMobile` quanto pelo painel desktop — zero duplicação, satisfaz a acceptance criteria da Task 2.
- `_ColumnHeader` local não aplica `.toUpperCase()` — diferente do `_HeaderText` de `gastos_property_screen.dart` (que sempre recebe literais já maiúsculos como `'DATA'`), o 10-UI-SPEC pede os rótulos de coluna em mixed-case (`'Nome/E-mail'`, `'Papel'`, `'Ações'`).
- `_InviteRow` (linha de convite pendente) usa duas linhas — email em `Text` de largura cheia seguido por um `Wrap` de chip/papel/botão — em vez de uma única `Row`. Ver Deviations abaixo.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Linha de convite pendente estourava a 360px de largura**
- **Found during:** Task 1, ao rodar o caso de teste de 360px
- **Issue:** A implementação inicial colocava chip de status + papel + botão "Revogar" numa única `Row` ao lado do e-mail (`Expanded`); mesmo com o e-mail truncando corretamente, a soma dos elementos de largura fixa (`StatusChip` + texto de papel + `TextButton`) excedia a largura disponível dentro do `SectionCard` a 360px, lançando um `RenderFlex overflowed` capturado por `tester.takeException()`.
- **Fix:** Reestruturado `_InviteRow` em duas linhas — o e-mail ganha a linha inteira (com `maxLines: 1` + ellipsis, com folga total); a segunda linha usa `Wrap` (não `Row`+`Spacer`) para chip + papel + botão "Revogar", que nunca estoura (só quebra linha se necessário) e reduz o `TextButton` para `minimumSize: Size.zero` / `tapTargetSize: shrinkWrap`.
- **Files modified:** lib/features/membros/presentation/membros_screen.dart
- **Verification:** `flutter test test/widget/membros_screen_test.dart` — caso "360px width renders with no overflow exception" passa; debug isolado confirmou zero overflow antes de reintegrar ao arquivo principal.
- **Committed in:** 018cc2f (Task 1 commit)

**2. [Rule 1 - Bug] `flutter analyze` acusava um `?.` redundante e um import não usado**
- **Found during:** Task 1, checagem de `flutter analyze` antes de commitar
- **Issue:** `membershipsAsync.asData?.value?.where(...)` encadeava um segundo `?.` depois de um `?.value` que a análise de null-shorting do Dart já provava não-nulo naquele ponto (`invalid_null_aware_operator`); e `property_repository.dart` estava importado sem uso direto (o tipo `PropertyMembership` chega transitivamente por `current_property_provider.dart`).
- **Fix:** Removido o `?.` redundante antes de `.where`; removido o import não usado.
- **Files modified:** lib/features/membros/presentation/membros_screen.dart
- **Verification:** `flutter analyze` limpo nos dois arquivos do plano.
- **Committed in:** 018cc2f (Task 1 commit)

**3. [Rule 1 - Bug] `RadioListTile.groupValue`/`onChanged` deprecados no SDK 3.41**
- **Found during:** Task 1, checagem de `flutter analyze`
- **Issue:** O Flutter SDK desta máquina (3.41.9) já emite `deprecated_member_use` info-level para `RadioListTile.groupValue`/`onChanged` diretos (deprecados a partir de 3.32) na folha "Trocar papel", que teria introduzido 2 issues novas.
- **Fix:** Envolvido o grupo de `RadioListTile` num `RadioGroup<String>` ancestral (API recomendada de substituição), removendo `groupValue`/`onChanged` de cada `RadioListTile` individual.
- **Files modified:** lib/features/membros/presentation/membros_screen.dart
- **Verification:** `flutter analyze` — zero issues nos dois arquivos do plano; comportamento de seleção de papel inalterado (não coberto por teste automatizado nesta plan, pois a folha "Trocar papel" não está no `<behavior>` explícito das Tasks 1/2 — só a existência do handler `_openRoleChange` compartilhado é verificada).
- **Committed in:** 018cc2f (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (todos Rule 1 — bugs descobertos durante verificação, não gaps de funcionalidade)
**Impact on plan:** Todos os três ajustes eram necessários para os próprios critérios de aceite do plano (zero overflow a 360px, `flutter analyze` limpo). Nenhum scope creep — nenhuma funcionalidade nova além do que o plano pediu.

## Issues Encountered
- **Worktree fresco sem código gerado.** `flutter analyze`/`flutter test` no worktree recém-criado reportavam ~850 erros em arquivos não relacionados a este plano (`copyWith`/`id`/`examDate` indefinidos em `Animal`, `DgRecord`, `SanitaryApplication`, `AtfBatch`, `Lot`) — os artefatos `.freezed.dart`/`.g.dart` não existiam ainda (gitignorados, gerados sob demanda). Resolvido rodando `flutter pub run build_runner build` (108s, 27 outputs) antes de qualquer `analyze`/`test`, exatamente como as constraints do dispatch instruíam. Não é um deviation do plano — é infraestrutura de worktree, não código deste plano.

## User Setup Required

None - no external service configuration required. As RPCs que `membro_repository.dart` chama (`revoke_invite`, `remove_member`, `update_member_role`, `leave_property`) já foram tratadas como pendentes de aplicação em planos anteriores (10-01/10-04); esta tela não introduz nenhuma RPC nova.

## Next Phase Readiness
- `MembrosScreen` está pronta para ser conectada ao roteador e ao popup "Membros" de `PropriedadesScreen` (10-10) — a rota `/propriedades/:id/membros` e o item de menu ficam fora do escopo deste plano (`files_modified` restrito a `membros_screen.dart` + teste).
- Suíte completa do projeto verde (514 testes) e `flutter analyze` limpo (mesmos 4 infos pré-existentes documentados em 10-04-SUMMARY.md) após este plano.
- Nenhum bloqueio conhecido para 10-10 consumir esta tela.

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

All files and commits verified present on disk / in git log (see below).
