---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 03
subsystem: data
tags: [flutter, riverpod, supabase, rpc, membership, invites]

requires:
  - phase: 10-01
    provides: "supabase/migrations/20260814_11_membership_lifecycle.sql (invites table, 9 RPCs, 2 helpers) — plan authored but not applied"
provides:
  - "PropertyMember/Invite/MyInvite models + roleLabel/inviteStatusLabel pt-BR mappers"
  - "MembroErrorReason/MembroException/asMembroException — pt-BR error vocabulary for the 9 membership RPCs"
  - "MembroRepository + 4 Riverpod providers (membroRepositoryProvider, propertyMembersProvider, propertyInvitesProvider, myInvitesProvider)"
affects: [10-04, 10-05, 10-06, 10-07, 10-08, 10-09]

tech-stack:
  added: []
  patterns:
    - "Plain const-constructor classes for RPC/select result shapes (no freezed) — precedent PropertyMembership/LotWithPaddockName/AtfMembershipView"
    - "Exception-mapping factory (fromPostgrest) + routing function (asError) per feature's data layer — precedent sanitary_application_exception.dart"

key-files:
  created:
    - lib/features/membros/data/membro_models.dart
    - lib/features/membros/data/membro_exception.dart
    - lib/features/membros/data/membro_repository.dart
    - test/features/membros/membro_models_test.dart
    - test/features/membros/membro_exception_test.dart
  modified: []

key-decisions:
  - "Models are plain classes with const constructors, no freezed/json_serializable — RPC/select result shapes, not editable entities (planner decision, matches 10-PATTERNS.md analysis)"
  - "acceptInvite/declineInvite take only the invite id, never an email parameter — server derives identity via current_user_email()"

patterns-established:
  - "MembroException.fromPostgrest switches on SQLSTATE (42501/23514/23505/P0002/23503/22023/22P02/default), same shape as SanitaryApplicationException.fromPostgrest"

requirements-completed: [MEMB-01, MEMB-02]

coverage:
  - id: D1
    description: "PropertyMember/Invite/MyInvite models parse RPC/select JSON correctly, including missing-key defaults"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/features/membros/membro_models_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "roleLabel/inviteStatusLabel map every known enum value to pt-BR and never throw on unknown input"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/features/membros/membro_models_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "MembroException.fromPostgrest maps every SQLSTATE the 9 RPCs raise to an authored pt-BR sentence, including the last-veterinarian guard with farm-name interpolation"
    requirement: "MEMB-02"
    verification:
      - kind: unit
        ref: "test/features/membros/membro_exception_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "MembroRepository exposes the 9 RPCs + 2 reads through SupabaseService only, with 4 Riverpod providers ready for UI plans to consume"
    verification:
      - kind: unit
        ref: "flutter analyze (No issues found in lib/features/membros); flutter test (455/455 passing)"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 3: Camada de Dados de Membros e Convites Summary

**MembroRepository com os 9 RPCs de `20260814_11_membership_lifecycle.sql` (create/revoke/accept/decline invite, list/remove/update_role/leave member) + 3 modelos simples + vocabulário de erro pt-BR completo, sem nenhum import de `supabase_flutter` fora da camada `data/`**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-14T15:03:59-03:00
- **Completed:** 2026-08-14T15:15:35-03:00
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- `membro_models.dart`: `PropertyMember`, `Invite`, `MyInvite` — classes simples sem codegen, `roleLabel`/`inviteStatusLabel` traduzindo os enums do banco para pt-BR
- `membro_exception.dart`: `MembroErrorReason` + `MembroException.fromPostgrest` cobrindo os 7 SQLSTATEs conhecidos (42501/23514/23505/P0002/23503/22023/22P02) + `asMembroException` como roteador único, nunca lança
- `membro_repository.dart`: `MembroRepository` com 3 leituras (`list_property_members`/`invites` select/`list_my_invites`) e 7 escritas via RPC, mais 4 providers Riverpod (`myInvitesProvider` observa `authNotifierProvider`)

## Task Commits

Each task was committed atomically:

1. **Task 1: Modelos e rótulos pt-BR** - `d933fd5` (feat, TDD)
2. **Task 2: Vocabulário de erro pt-BR dos RPCs de membro** - `53de0a3` (feat, TDD)
3. **Task 3: MembroRepository e providers Riverpod** - `38c04fd` (feat)

_Note: TDD tasks 1 and 2 each landed as a single feat commit (models/tests written together per the plan's `<action>`, both red-then-green verified locally before commit)._

## Files Created/Modified
- `lib/features/membros/data/membro_models.dart` - PropertyMember, Invite, MyInvite + roleLabel/inviteStatusLabel
- `lib/features/membros/data/membro_exception.dart` - MembroErrorReason, MembroException, asMembroException
- `lib/features/membros/data/membro_repository.dart` - MembroRepository + 4 providers
- `test/features/membros/membro_models_test.dart` - 10 test cases
- `test/features/membros/membro_exception_test.dart` - 12 test cases

## Decisions Made
- Models as plain classes (no freezed) — matches planner_decision in 10-03-PLAN.md and the established `PropertyMembership`/`LotWithPaddockName`/`AtfMembershipView` precedent; avoids a build_runner round for result shapes with no `copyWith` need.
- `acceptInvite`/`declineInvite` signatures take only the invite id — enforced by the `<action>` spec and verified by acceptance criteria; matches the RPC contract in `10-01-PLAN.md` (`current_user_email()` derivation server-side).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Worktree had no `.dart_tool/` and no generated freezed/json_serializable outputs, causing `flutter analyze` to report ~849 spurious `undefined_getter` errors across unrelated files (pre-existing freezed-generated members like `SanitaryApplication.id`, `Lot.id`, `Animal.copyWith`). Resolved per the plan's environment constraint by running `dart run build_runner build` before analyze/test — after regeneration, `flutter analyze` reported only 4 pre-existing `info`-level issues (none in `lib/features/membros`), and `flutter test` passed 455/455.

## User Setup Required

None - no external service configuration required. The migration this plan's repository targets (`20260814_11_membership_lifecycle.sql`, authored by plan 10-01) is not yet applied to any environment — 10-01/10-10 own that.

## Next Phase Readiness
- `MembroRepository` and its 4 providers are ready for the UI plans (10-04 through 10-09) to consume in parallel.
- The RPC layer this repository calls exists only as an unapplied migration file (10-01's output) — no live-database exercise of these calls is possible until plan 10-10 applies it.

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

All 6 files and 3 commits verified present on disk / in git log.
