---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 07
subsystem: ui
tags: [flutter, riverpod, propriedades, soft-delete, archive-restore]

# Dependency graph
requires:
  - phase: 10-06
    provides: "archivedPropertyListProvider, restoreProperty, ArchiveConfirmDialog"
provides:
  - "Alternador Ativas/Arquivadas em PropriedadesScreen"
  - "Arquivamento com confirmação forte (digitar nome exato) substituindo o AlertDialog genérico"
  - "Restauração de fazenda arquivada pela UI, em um toque"
affects: [propriedades, membros]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_ScopeChip local (clone visual de _PeriodChip) quando o widget de origem é privado de outro arquivo de feature"
    - "Cartão arquivado esmaecido via Opacity(opacity: 0.6) envolvendo o conteúdo do Card"

key-files:
  created: []
  modified:
    - lib/features/propriedades/presentation/propriedades_screen.dart
    - test/widget/propriedades_screen_test.dart

key-decisions:
  - "PropriedadesScreen convertida de ConsumerWidget para ConsumerStatefulWidget para guardar _showArchived"
  - "Botão 'Restaurar fazenda' usa AppColors.accent/onAccent (CTA não-destrutivo), por 10-UI-SPEC.md"

requirements-completed: [PROPV-01, PROPV-02]

coverage:
  - id: D1
    description: "Alternador Ativas/Arquivadas acima da lista, com estado vazio dedicado para Arquivadas"
    requirement: "PROPV-02"
    verification:
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#Ativas tab selected by default shows active properties"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#tapping Arquivadas switches list to archivedPropertyListProvider"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#empty archived tab shows Nenhuma fazenda arquivada copy"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cartão arquivado esmaecido com botão Restaurar fazenda substituindo o PopupMenuButton"
    requirement: "PROPV-02"
    verification:
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#archived card shows Restaurar fazenda button, not PopupMenuButton"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#active card still shows PopupMenuButton for veterinarian"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#archived tab with non-veterinarian role hides Restaurar fazenda button"
        status: pass
    human_judgment: false
  - id: D3
    description: "Restaurar fazenda chama restoreProperty e invalida os três providers; FloatingActionButton só na aba Ativas"
    requirement: "PROPV-02"
    verification:
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#tapping Restaurar fazenda calls restoreProperty once with the id"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#FloatingActionButton only appears on Ativas tab"
        status: pass
    human_judgment: false
  - id: D4
    description: "Arquivamento exige digitação do nome exato via ArchiveConfirmDialog, substituindo o AlertDialog genérico"
    requirement: "PROPV-01"
    verification:
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#active card menu item is Arquivar, not Remover"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#selecting Arquivar opens ArchiveConfirmDialog with the property name"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#cancelling the dialog does not call softDeleteProperty"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#typing the exact name and confirming calls softDeleteProperty once"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#archive error shows an authored SnackBar, no raw db text"
        status: pass
      - kind: unit
        ref: "test/widget/propriedades_screen_test.dart#propriedades_screen.dart no longer contains an AlertDialog"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 07: Ciclo de vida da fazenda (arquivar/restaurar) Summary

**PropriedadesScreen ganha alternador Ativas/Arquivadas, arquivamento com confirmação forte por digitação do nome (`ArchiveConfirmDialog`), e restauração em um toque — fechando PROPV-01 e PROPV-02.**

## Performance

- **Duration:** ~15 min (commit a commit)
- **Started:** 2026-08-14T15:19:04-03:00 (base do worktree)
- **Completed:** 2026-08-14T15:32:17-03:00
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `PropriedadesScreen` virou `ConsumerStatefulWidget` com alternador `_ScopeChip` (Ativas/Arquivadas) acima da lista
- Estado vazio dedicado para a aba Arquivadas (`Nenhuma fazenda arquivada`)
- `_PropertyCard` ganhou modo `archived`: cartão esmaecido (`Opacity(0.6)`) com botão "Restaurar fazenda" (accent) no lugar do `PopupMenuButton`
- `_restore` chama `restoreProperty` e invalida `propertyListProvider`, `archivedPropertyListProvider` e `memberPropertiesProvider`
- `_confirmDelete`/`AlertDialog` genérico substituído por `_confirmArchive` + `ArchiveConfirmDialog` (digitação exata do nome) via `showAdaptiveForm(width: FormWidth.confirm)`
- Item de menu `'delete'`/`Remover` renomeado para `'archive'`/`Arquivar`
- 14 novos casos de teste em `propriedades_screen_test.dart` (15 no total, incluindo o caso original preservado)

## Task Commits

Each task was committed atomically:

1. **Task 1: Alternador Ativas/Arquivadas, cartão esmaecido e restauração** - `30e8040` (feat)
2. **Task 2: Arquivamento com confirmação forte substituindo o AlertDialog genérico** - `a42fdfe` (feat)

_Note: tdd="true" tasks were executed with the screen implementation and its test cases landing in the same commit per task — see Deviations._

## Files Created/Modified
- `lib/features/propriedades/presentation/propriedades_screen.dart` - alternador de escopo, cartão arquivado, restauração, arquivamento com confirmação forte
- `test/widget/propriedades_screen_test.dart` - 15 casos de widget test cobrindo os dois tasks

## Decisions Made
- `PropriedadesScreen` convertida para `ConsumerStatefulWidget` (era `ConsumerWidget`) para guardar `_showArchived` como estado local do widget
- `_ScopeChip` foi redeclarada localmente em `propriedades_screen.dart` (não importada de `gastos_property_screen.dart`, cuja `_PeriodChip` é privada), com as cores exatas do plano: `AppColors.primary`/`onGreen` selecionado, `AppColors.surfaceVariant`/`ink` não selecionado — diferente da paleta de `_PeriodChip`/`_ScopeChip` de `animais_table_view.dart` (`positiveChipBg`/`surface`), seguindo literalmente a instrução do plano
- Botão "Restaurar fazenda" estilizado com `AppColors.accent`/`onAccent` (CTA não-destrutivo), conforme `10-UI-SPEC.md` linha 73 ("Accent … Reserved for … Restaurar fazenda")

## Deviations from Plan

None - plan executed exactly as written. Both tasks' `<action>` and `<behavior>` blocks were implemented literally; the only judgment call was the `_ScopeChip` color mapping and the accent-colored restore button, both resolved from explicit plan/UI-SPEC text (documented above as decisions, not deviations).

## Issues Encountered
- Fresh worktree required `flutter pub get` + `dart run build_runner build` before the first `flutter test` run (freezed/json_serializable `.g.dart`/`.freezed.dart` outputs were missing) — expected per the plan's constraints, not a deviation.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PROPV-01 and PROPV-02 fully delivered on `PropriedadesScreen`; the reversible archive/restore cycle is now UI-complete.
- Full suite (477 tests) and `flutter analyze` (0 errors/warnings, 4 pre-existing unrelated `info`s) are green.
- No changes to `supabase/` — no migration to push for this plan.

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: lib/features/propriedades/presentation/propriedades_screen.dart
- FOUND: test/widget/propriedades_screen_test.dart
- FOUND: .planning/phases/10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade/10-07-SUMMARY.md
- FOUND commit: 30e8040
- FOUND commit: a42fdfe
