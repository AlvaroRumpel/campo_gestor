---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 10
subsystem: ui
tags: [go_router, flutter, riverpod, navigation, role-gates]

# Dependency graph
requires:
  - phase: 10-05
    provides: "MembrosScreen(propertyId) — tela de gestão de membros, até então inalcançável"
  - phase: 10-07
    provides: "PropriedadesScreen com _showArchived, _PropertyCard(canEdit/archived/onRestore), PopupMenuButton gated por _canEditProperties"
provides:
  - "AppRoutes.membrosById (/propriedades/:propertyId/membros) e AppRoutes.membros(id) helper, root-level fora do StatefulShellRoute"
  - "GoRoute registrado em router.dart renderizando MembrosScreen com o propertyId do path"
  - "Item 'Membros' no menu do cartão de fazenda, visível a veterinário e proprietário, ausente para leitor e para cartão arquivado"
affects: [membros, propriedades, router]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Quinta rota de detalhe root-level (após loteById/atfById/aplicacaoById/gastosById) — dois segmentos coexistindo com o shell sem entrar em AppRoutes.all"
    - "PopupMenuButton com itens montados por dois gates independentes (canEdit vet-only, canManageMembers vet-ou-owner) na mesma tela"

key-files:
  created: []
  modified:
    - lib/core/router/routes.dart
    - lib/core/router/router.dart
    - lib/features/propriedades/presentation/propriedades_screen.dart
    - test/core/router_test.dart
    - test/widget/propriedades_screen_test.dart

key-decisions:
  - "canManageMembers (já existente em role_gates.dart desde 10-04) reutilizado sem alteração — Task 2 só consumiu o predicado, não criou um novo"
  - "PopupMenuButton passa a renderizar quando canEdit || canManageMembers (antes só canEdit); itens montados condicionalmente para preservar Editar/Arquivar vet-only"

patterns-established:
  - "Dois gates de papel coexistindo no mesmo PopupMenuButton.itemBuilder via ifs condicionais, sem duplicar o widget"

requirements-completed: [MEMB-02]

coverage:
  - id: D1
    description: "/propriedades/:propertyId/membros registrada como GoRoute root-level, deep-linkável, renderizando MembrosScreen com o propertyId do path"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/core/router_test.dart#/propriedades/abc-123/membros renders MembrosScreen with propertyId from the path"
        status: pass
      - kind: unit
        ref: "test/core/router_test.dart#/propriedades still renders PropriedadesScreen (not swallowed by the detail route)"
        status: pass
      - kind: unit
        ref: "test/core/router_test.dart#membrosById does not leak into AppRoutes.all"
        status: pass
    human_judgment: false
  - id: D2
    description: "Item 'Membros' no menu do cartão de fazenda: visível a veterinário e proprietário, ausente para leitor, ausente em cartão arquivado, navega para a rota correta"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#veterinarian: menu contains Membros, Editar and Arquivar"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#owner: menu contains Membros but not Editar/Arquivar"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#reader: no PopupMenuButton at all"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#selecting Membros navigates to /propriedades/{id}/membros"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#archived card does not offer Membros, only Restaurar fazenda"
        status: pass
    human_judgment: false

# Metrics
duration: 45min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 10: Rota e entrada de navegação para Membros Summary

**Registrada `/propriedades/:propertyId/membros` como quinta rota root-level do projeto e ligada ao menu do cartão de fazenda, tornando `MembrosScreen` (existente desde o plano 10-05) finalmente alcançável.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-14T18:30:00Z (approx)
- **Completed:** 2026-08-14T19:15:59Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- `AppRoutes.membrosById` (`/propriedades/:propertyId/membros`) e `AppRoutes.membros(id)` adicionados a `routes.dart`, fora de `AppRoutes.all` (continua com 6 entradas)
- `GoRoute` registrado em `router.dart`, root-level, fora do `StatefulShellRoute` — nenhuma branch do shell nem o `redirect` foi tocado
- Item "Membros" adicionado ao `PopupMenuButton` do cartão de fazenda, gated por `canManageMembers` (vet ou proprietário), coexistindo com o gate `canEdit` (vet-only) que continua a governar Editar/Arquivar
- Cartão arquivado permanece oferecendo apenas "Restaurar fazenda" — nenhum item "Membros" nesse modo

## Task Commits

Each task was committed atomically:

1. **Task 1: Rota /propriedades/:propertyId/membros** - `8142b50` (feat)
2. **Task 2: Item "Membros" no menu do cartão de fazenda** - `86f8c61` (feat)

**Plan metadata:** (this commit) `docs(10-10): complete rota e entrada de navegação para membros plan`

## Files Created/Modified
- `lib/core/router/routes.dart` - `AppRoutes.membrosById` + `AppRoutes.membros(id)` helper
- `lib/core/router/router.dart` - `GoRoute` root-level para `MembrosScreen`, import adicionado
- `lib/features/propriedades/presentation/propriedades_screen.dart` - `canManageMembersHere`, `_PropertyCard.canManageMembers`/`onMembers`, `PopupMenuButton` com itens condicionais
- `test/core/router_test.dart` - 5 novos casos: template/helper, coexistência com `/propriedades`, deep link com `propertyId`, `AppRoutes.all` intacto
- `test/widget/propriedades_screen_test.dart` - 6 novos casos: vet (3 itens), owner (só Membros), reader (sem menu), navegação, cartão arquivado, `_canEditProperties` permanece vet-only

## Decisions Made
- `canManageMembers` já existia em `role_gates.dart` (criado no plano 10-04) — Task 2 apenas o consumiu, sem criar um sexto gate.
- Nenhuma decisão arquitetural nova; plano executado como escrito, sem desvios Rule 4.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Nenhum. `flutter pub get` + `dart run build_runner build` foram necessários no worktree fresco antes do primeiro `flutter test` (build_runner não tinha rodado ainda neste checkout), conforme já esperado pelas constraints do plano — não é um desvio do plano em si.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `MembrosScreen` (10-05) agora é alcançável de ponta a ponta: rota registrada, deep-linkável, e com ponto de entrada na UI.
- MEMB-02 fechado. Suíte completa verde (537 testes) e `flutter analyze` limpo (apenas 4 infos pré-existentes, não relacionados a este plano).

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

All 6 files confirmed on disk (routes.dart, router.dart, propriedades_screen.dart, router_test.dart, propriedades_screen_test.dart, this SUMMARY). Both task commits (`8142b50`, `86f8c61`) confirmed in `git log`.
