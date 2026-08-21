---
phase: 05-reproductive-module-loteatf
plan: 07
subsystem: ui
tags: [flutter, riverpod, supabase-rpc, reproductive-history, animal-ficha]

# Dependency graph
requires:
  - phase: 05-02
    provides: "reproductiveHistoryByAnimalProvider / AtfRepository.fetchReproductiveHistory —
      the REPR-05 data source (animal_atf_memberships joined to atf_batches, most-recent DG
      per ATF, sorted insemination-date descending)"
  - phase: 05-03
    provides: "register_baixa SECURITY DEFINER RPC with the D-19 side effect delivered via
      trg_animals_baixa_deactivates_atf (05-01)"
  - phase: 05-04
    provides: "AppRoutes.atfDetail(id) — the root-level /atf/:atfId GoRoute the history rows
      navigate to"
provides:
  - "_ReproductiveHistorySection: a read-only ConsumerWidget on AnimalDetailScreen rendering
    every ATF the animal participated in with its most recent DG result (REPR-05, ROADMAP SC-5)"
  - "AnimalRepository.registerBaixa rewired from a direct .update() onto the register_baixa
    RPC, preserving its public signature so BaixaDialog and test fakes compile unchanged"
affects: [08-animal-dossier-consolidation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Section-local AsyncValue.when inside a ConsumerWidget, reusing AnimalInfoCard's
      lot/paddock lookup treatment but applied to a full list instead of a single field —
      loading/error never blank the rest of the ficha"

key-files:
  created: []
  modified:
    - lib/features/animais/presentation/animal_detail_screen.dart
    - lib/features/animais/data/animal_repository.dart
    - test/features/animais/animal_repository_test.dart
    - test/widget/animal_detail_screen_test.dart

key-decisions:
  - "ReproductiveHistoryEntry ordering is a repository-level responsibility (AtfRepository
    already sorts insemination-date descending); the widget renders whatever order the
    provider supplies without re-sorting, so the populated widget test asserts the widget
    preserves supplied order rather than re-deriving the sort itself."
  - "DG semantic color mapping (primaryContainer/errorContainer/tertiaryContainer) and the
    ATF status badge (neutral outline for Ativo, surfaceContainerHigh for Encerrado) are
    applied via standard-size Chip, not the 48px DG-entry touch target — this section is
    read-only per D-13, so the mobile touch-target exception does not apply here."

patterns-established:
  - "Read-only history row: InkWell wrapping a Wrap of Text/Chip children, navigating via
    context.go(AppRoutes.<detail>(id)) — no onPressed/onSelected anywhere in the subtree,
    verified by a widget test asserting the absence of ChoiceChip/ButtonStyleButton/IconButton
    within the section's Card ancestor."

requirements-completed: [REPR-05]

coverage:
  - id: D1
    description: "AnimalDetailScreen's Histórico Reprodutivo placeholder replaced with
      _ReproductiveHistorySection, rendering every ATF the animal participated in (active or
      closed) with its most recent DG result, ordered by insemination date descending,
      strictly read-only, navigating to /atf/:atfId on tap"
    requirement: "REPR-05"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart — group 'AnimalDetailScreen —
          Histórico Reprodutivo (REPR-05, D-14, 05-UI-SPEC E8)': empty, loading, error,
          populated (row order), partial (aguardando DG), read-only (no ChoiceChip/button),
          navigation (row tap -> /atf/:atfId) — 7/7 pass"
      - kind: unit
        ref: "flutter analyze lib/features/animais — 0 issues"
        status: pass
    human_judgment: false
    rationale: null
  - id: D2
    description: "AnimalRepository.registerBaixa routes through the register_baixa RPC
      (p_animal_id, p_reason, p_date, optional p_observation) instead of a direct
      .from('animals').update(), with the public Dart signature unchanged and
      baixa_dialog.dart untouched"
    requirement: "REPR-05"
    verification:
      - kind: unit
        ref: "test/features/animais/animal_repository_test.dart#registerBaixa still exists
          with required id, reason, date and optional observation"
        status: pass
      - kind: automated_ui
        ref: "test/widget/baixa_dialog_test.dart — all 5 pre-existing tests pass unchanged
          against the fake repository (public signature preserved)"
        status: pass
      - kind: other
        ref: "grep confirms animal_repository.dart contains .rpc('register_baixa' with keys
          p_animal_id/p_reason/p_date and no longer contains
          .from('animals').update( in registerBaixa's body"
        status: pass
    human_judgment: true
    rationale: "The Dart-side call is structurally verified (correct RPC name, parameter
      keys, and unchanged public signature, all asserted by grep + passing tests), but the
      register_baixa migration itself (supabase/migrations/20260805_05_atf_rpcs.sql, plan
      05-03) has not been pushed to a live Postgres instance in this session — plan 05-10
      owns supabase db push. The D-19 trigger side effect (an active ATF membership actually
      deactivating on baixa) is therefore unverified end-to-end here and needs a live UAT
      pass once 05-10 lands."

# Metrics
duration: ~35min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 7: Reproductive History Ficha Section + registerBaixa RPC Rewire Summary

**Read-only REPR-05 reproductive history list on the animal ficha, plus `registerBaixa` rewired from a direct table `UPDATE` onto the `register_baixa` SECURITY DEFINER RPC so the D-19 ATF-membership deactivation fires.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Replaced the `Histórico Reprodutivo` placeholder on `AnimalDetailScreen` with `_ReproductiveHistorySection`, a `ConsumerWidget` reading `reproductiveHistoryByAnimalProvider(animalId)` and rendering all seven 05-UI-SPEC E8 states (empty, loading, error, populated, partial, read-only, overflow-safe)
- Each row navigates to `/atf/:atfId` on tap, formatted per D-14: `[ATF nome] — insem. [DD/MM] · [último DG] · [status]`, with the same DG semantic color mapping as the DG entry chips and a neutral status badge
- `AnimalRepository.registerBaixa`'s body replaced with a single `.rpc('register_baixa', params: ...)` call — public signature (`id`, `reason`, `date`, `observation`) unchanged, so `BaixaDialog` and every fake repository in the test suite compile and pass unmodified
- `baixa_dialog.dart` has zero diff in this plan's commits, confirming the D-19 side effect is data-layer only per 05-UI-SPEC section 7

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace the Histórico Reprodutivo placeholder with the real REPR-05 list** - `3bd95f0` (feat)
2. **Task 2: Route registerBaixa through the register_baixa RPC** - `b5eace3` (feat)
3. **Task 3: Widget tests for the reproductive history section** - `7ca3510` (test)

## Files Created/Modified
- `lib/features/animais/presentation/animal_detail_screen.dart` - `_ReproductiveHistorySection` + `_ReproductiveHistoryRow` widgets replacing the Fase 5 placeholder
- `lib/features/animais/data/animal_repository.dart` - `registerBaixa` body rewired onto `.rpc('register_baixa')`
- `test/features/animais/animal_repository_test.dart` - regression test confirming `registerBaixa`'s public signature is unchanged
- `test/widget/animal_detail_screen_test.dart` - 7 new tests covering the E8 states plus a `GoRouter` harness for the row-tap navigation assertion

## Decisions Made
- `ReproductiveHistoryEntry` ordering stays a repository-level concern (`AtfRepository.fetchReproductiveHistory` already sorts insemination-date descending); the widget renders supplied order as-is, and the populated widget test asserts order-preservation rather than re-deriving the sort.
- DG result badge and ATF status badge both use standard-size `Chip`, not the 48px DG-entry touch target — this section is read-only (D-13), so the mobile mass-entry touch-target exception in 05-UI-SPEC does not apply.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria and automated `<verify>` checks passed before each commit.

One process note (not a plan deviation): the plan's own `<verify>` blocks use `cd F:/_geral/Projetos/campo_gestor && ...`, which — inside this worktree — resolves to the shared main-repo checkout, not this worktree's copy. Running verification that way silently checks stale code. All verification in this plan was re-run without leaving the worktree (relying on the default cwd) after catching this on the first `flutter analyze` pass; `dart run build_runner build` was likewise re-run inside the worktree once the drift was caught, since the first run (under the drifted cwd) had generated files into the main repo instead.

## Issues Encountered

- First `flutter analyze` and `dart run build_runner build` invocations followed the plan's literal `<verify>` command (which `cd`s to the shared main-repo path) and therefore validated the wrong checkout, giving a false "No issues found!" pass against Task 1's stale (unedited) file. Caught by reading the main-repo file directly and finding the old placeholder still present. Resolved by re-running both commands from the worktree's default cwd (no `cd`) — see Deviations note above. No code changes required; this was a verification-tooling issue, not a bug in the implementation.

## User Setup Required

None - no external service configuration required. The `register_baixa` RPC (migration `supabase/migrations/20260805_05_atf_rpcs.sql`) was authored in plan 05-03 and its live execution (`supabase db push`) is already tracked as a plan 05-10 blocker, unchanged by this plan.

## Next Phase Readiness

- REPR-05 is structurally complete: the ficha shows every LoteATF an animal participated in with its DG result, satisfying ROADMAP SC-5 at the Dart/UI layer.
- `registerBaixa`'s Dart-side rewire is done and tested; the D-19 trigger's live behavior (ATF membership actually deactivating on baixa) still depends on plan 05-10's `supabase db push`, same blocker already carried forward from 05-03.
- No new blockers introduced. `baixa_dialog.dart` confirmed untouched.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

- FOUND: lib/features/animais/presentation/animal_detail_screen.dart
- FOUND: lib/features/animais/data/animal_repository.dart
- FOUND: test/features/animais/animal_repository_test.dart
- FOUND: test/widget/animal_detail_screen_test.dart
- FOUND: .planning/phases/05-reproductive-module-loteatf/05-07-SUMMARY.md
- FOUND commit: 3bd95f0 (Task 1)
- FOUND commit: b5eace3 (Task 2)
- FOUND commit: 7ca3510 (Task 3)
