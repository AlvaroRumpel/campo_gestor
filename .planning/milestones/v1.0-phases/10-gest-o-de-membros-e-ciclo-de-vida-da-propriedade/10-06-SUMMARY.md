---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 06
subsystem: ui
tags: [flutter, riverpod, supabase, rls, postgrest]

# Dependency graph
requires:
  - phase: 02-property-paddock-structure
    provides: "properties table + veterinarian_can_update_property / members_can_read_their_properties RLS policies"
provides:
  - "PropertyRepository.fetchArchivedProperties() — the inverse of fetchProperties(), lists soft-deleted properties"
  - "PropertyRepository.restoreProperty(id) — clears deleted_at, authorized by the existing UPDATE policy"
  - "archivedPropertyListProvider — FutureProvider mirroring propertyListProvider"
  - "ArchiveConfirmDialog — strong confirmation (type-the-name) widget, decoupled from Riverpod/repository"
affects: [10-07 (the plan that wires these into PropriedadesScreen's Ativas/Arquivadas toggle and Restaurar button)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Archive/restore data-layer pair added to an existing repository with zero new SQL — read RLS policies that don't reference deleted_at make the read-visibility half free"
    - "Confirmation dialogs stay UI-only (no Riverpod, no repository calls) — the caller screen owns the mutation and provider invalidation"

key-files:
  created:
    - lib/features/propriedades/presentation/archive_confirm_dialog.dart
    - test/features/propriedades/archive_confirm_dialog_test.dart
  modified:
    - lib/features/propriedades/data/propriedade_repository.dart

key-decisions:
  - "Zero SQL: fetchArchivedProperties/restoreProperty reuse the pre-existing members_can_read_their_properties (read) and veterinarian_can_update_property (write) policies verbatim — neither references deleted_at"
  - "ArchiveConfirmDialog has no Riverpod import and calls no repository — it only returns a bool via Navigator.pop; the calling screen (plan 10-07) owns softDeleteProperty + provider invalidation"
  - "_matches compares with == directly (no trim/toLowerCase) — case-sensitive exact match against property.name is the specified behavior"

patterns-established:
  - "Pattern: an archive/restore pair needs only two repository methods + one provider when the underlying RLS read policy already ignores deleted_at — check that before reaching for a migration"

requirements-completed: [PROPV-01, PROPV-02]

coverage:
  - id: D1
    description: "fetchArchivedProperties lists soft-deleted properties the user is a member of, no new migration"
    requirement: "PROPV-02"
    verification:
      - kind: unit
        ref: "test/features/propriedades/propriedade_repository_test.dart#PropertyRepository surface exists"
        status: pass
    human_judgment: false
  - id: D2
    description: "restoreProperty clears deleted_at, authorized by the existing veterinarian_can_update_property policy"
    requirement: "PROPV-02"
    verification: []
    human_judgment: true
    rationale: "Live RLS authorization (a non-veterinarian being blocked, a veterinarian succeeding) can only be proven against the real Supabase project; no local Postgres/pgTAP available in this environment (project-wide constraint, see STATE.md blockers). The read-policy claim was verified by direct migration inspection, not by a live round-trip."
  - id: D3
    description: "ArchiveConfirmDialog: title/body/hint/buttons render; disabled until exact case-sensitive name match; confirm returns true, cancel returns false/null; long names wrap without truncation"
    requirement: "PROPV-01"
    verification:
      - kind: unit
        ref: "test/features/propriedades/archive_confirm_dialog_test.dart#ArchiveConfirmDialog (8 tests)"
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 06: Arquivar/Restaurar Fazenda (data layer + dialog) Summary

**PropertyRepository ganhou fetchArchivedProperties/restoreProperty sem uma linha de SQL nova, e ArchiveConfirmDialog agora exige digitar o nome exato da fazenda para arquivar.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-14T15:03:59-03:00
- **Completed:** 2026-08-14T15:16:25-03:00
- **Tasks:** 2
- **Files modified:** 3 (1 modified, 2 created)

## Accomplishments
- `PropertyRepository.fetchArchivedProperties()` e `restoreProperty(id)` + `archivedPropertyListProvider`, reaproveitando as policies RLS já existentes (nenhuma migration)
- `ArchiveConfirmDialog` — confirmação forte por digitação exata (case-sensitive) do nome da fazenda, desacoplada de Riverpod e do repositório
- 8 testes de widget cobrindo o `<behavior>` do plano (título/corpo/hint/botões, prefixo, caixa diferente, match exato, confirmar, cancelar, nome longo sem truncar)

## Task Commits

Each task was committed atomically:

1. **Task 1: fetchArchivedProperties, restoreProperty e archivedPropertyListProvider** - `1eb756f` (feat)
2. **Task 2: ArchiveConfirmDialog com confirmação por digitação do nome** - `d005d60` (test, RED) → `d8ed036` (feat, GREEN)

**Plan metadata:** pending (this commit)

_TDD task: RED (`d005d60`) then GREEN (`d8ed036`), no REFACTOR commit needed._

## Files Created/Modified
- `lib/features/propriedades/data/propriedade_repository.dart` - added `fetchArchivedProperties`, `restoreProperty`, `archivedPropertyListProvider`; annotated `softDeleteProperty`'s doc comment with the new UI path and reversibility
- `lib/features/propriedades/presentation/archive_confirm_dialog.dart` - new `ArchiveConfirmDialog` StatefulWidget
- `test/features/propriedades/archive_confirm_dialog_test.dart` - new widget test file, 8 cases

## Decisions Made
- Reused `PropertyFormDialog`'s `showAdaptiveForm` shell convention exactly (`SafeArea > Padding(20,18,20,16) > Column`, `FormWidth.confirm` = 440) so the dialog composes with the same entry point the rest of the app uses — no bespoke `showDialog` wrapper.
- Test file initially used a raw `showDialog` (RED); switched to `showAdaptiveForm` for GREEN once RED correctly failed on the missing class and a follow-up run surfaced "No Material widget found" — `showAdaptiveForm` wraps content in `Dialog`/`showModalBottomSheet`, which is what actually supplies the `Material` ancestor `TextField` needs. This mirrors the exact pattern already used by `test/features/gastos/expense_form_dialog_test.dart`.

## Deviations from Plan

None - plan executed exactly as written. The only adjustment was internal to Task 2's own TDD loop (test harness detail, not a scope or behavior change) and is documented above under Decisions Made.

## Issues Encountered
- `.dart_tool/` was absent in this worktree (fresh checkout) — ran `flutter pub get` then `flutter pub run build_runner build` before `flutter analyze`/`flutter test` would resolve generated freezed/json code, per this plan's environment constraint.
- First `flutter analyze` run showed 849 issues, all from missing generated code (freezed/`.g.dart`) rather than real problems; resolved by the build_runner step above. Final `flutter analyze` shows 4 pre-existing `info`-level lints, none in files this plan touched (scope boundary — not fixed).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 10-07 can now wire `archivedPropertyListProvider` + `restoreProperty` + `ArchiveConfirmDialog` into `PropriedadesScreen`'s Ativas/Arquivadas toggle, calling `softDeleteProperty` only after `ArchiveConfirmDialog` returns `true`.
- Live RLS round-trip for `restoreProperty` (non-veterinarian blocked, veterinarian succeeds) is unverified in this plan — no local Postgres available (project-wide constraint). Flagged as `human_judgment: true` in coverage (D2); recommend confirming during 10-07's UAT or a live MCP round-trip like the ones used for prior phases' RLS suites.

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

All created/modified files found on disk; all three task commits (`1eb756f`, `d005d60`, `d8ed036`) found in git log.
