---
phase: 05-reproductive-module-loteatf
plan: 04
subsystem: ui
tags: [flutter, riverpod, go_router, reproductive]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf plan 02
    provides: AtfBatch/DgRecord models, summarizeDg/formatPrenhez, AtfRepository + atfByIdProvider/atfActiveMembershipsProvider/dgRecordsByAtfProvider
provides:
  - "AppRoutes.atfById / atfDetail(id) — root-level /atf/:atfId route, mirroring loteById/loteDetail"
  - "AtfDetailScreen — the ATF detail screen shell every other Phase 5 surface links into"
  - "AtfHeaderCard — name, Ativo/Encerrado badge, implantação/inseminação/touro/observação, % prenhez"
affects: [05-05, 05-06, 05-07, 05-08, 05-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Header-only detail screen: composition/DG/encerramento sections deliberately absent (no placeholder), later waves (05-06/05-08/05-09) add sections to this same file"
    - "AtfHeaderCard is a pure StatelessWidget computing summarizeDg/formatPrenhez itself, not a ConsumerWidget — the async membership/DG lists are resolved once at the screen level and passed down as plain lists"

key-files:
  created:
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_detail_screen_test.dart
  modified:
    - lib/core/router/routes.dart
    - lib/core/router/router.dart
    - test/core/router_test.dart

key-decisions:
  - "AtfHeaderCard's touro link label uses bullName when present (falling back to bullAnimalId as a last resort) even when bullAnimalId drives the tap target — AtfBatch carries no denormalized animal number/breed for display, and joining to animals data is out of this plan's scope (05-05's AtfFormDialog, which authors bullName, is deferred to a later wave)"
  - "Membership/DG-record AsyncValues (atfActiveMembershipsProvider, dgRecordsByAtfProvider) are read via .asData?.value ?? [] rather than their own AsyncValue.when branches — only the primary atfByIdProvider gates the loading/error Scaffold per the plan's read_first; treating a still-loading composition/DG list as empty is a deliberate simplification for this header-only shell (composition/DG sections don't exist yet — 05-06/05-08 add them)"

patterns-established:
  - "Pattern: a header-only detail screen commits with zero placeholder markup for sections owned by later-wave plans editing the same file — the screen must stand alone as useful, not as a stub with TODOs"

requirements-completed: [REPR-01, REPR-04]

coverage:
  - id: D1
    description: "/atf/:atfId is registered as a root-level GoRoute (sibling of loteById, outside the StatefulShellRoute) via AppRoutes.atfById/atfDetail(id), and AppRoutes.all still lists exactly 5 shell branches"
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/core/router_test.dart#AppRoutes.atfById / atfDetail (Phase 5, D-02 root-level route)"
        status: pass
    human_judgment: false
  - id: D2
    description: "AtfDetailScreen resolves atfByIdProvider/atfActiveMembershipsProvider/dgRecordsByAtfProvider, rendering loading/error/populated states through a single ListView; AtfHeaderCard shows name, neutral Ativo/Encerrado badge, KvRows for implantação/inseminação/touro/observação (absent rows omitted, never blank), and the D-05 hybrid touro link"
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart (10 tests: loading, error, populated, partial, bull-link x2, zero-DG, partial-DG, status-badge x2)"
        status: pass
    human_judgment: false
  - id: D3
    description: "% prenhez is rendered exclusively via summarizeDg/formatPrenhez from 05-02's dg_summary.dart — no local percentage arithmetic — and the zero-DG case renders '— · aguardando DG', never '0%'"
    requirement: "REPR-04"
    verification:
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#zero DG: renders \"— · aguardando DG\" and no widget containing \"0%\""
        status: pass
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#partial DG: 50 composed animals, 31 pregnant, renders 62% prenhez"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 04: ATF Detail Screen Shell + Header Card Summary

**Root-level `/atf/:atfId` GoRoute and the `AtfDetailScreen`/`AtfHeaderCard` shell — the screen every other Phase 5 surface (list card, reproductive-history rows) links into, with the % prenhez indicator driven exclusively by the shared `summarizeDg`/`formatPrenhez` formula.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-04T18:04:00Z
- **Completed:** 2026-08-04T18:24:00Z
- **Tasks:** 3
- **Files modified:** 5 (2 source, 1 new source, 2 tests, 1 new test)

## Accomplishments
- `/atf/:atfId` registered as a root-level `GoRoute`, sibling of `loteById`, outside every `StatefulShellBranch` (D-02) — deep-linkable, and `AppRoutes.all` proven unchanged at 5 entries
- `AtfDetailScreen` — single-`ListView` shell with `AsyncValue.when` loading/error/data handling; error and null-ATF share one generic copy string and never render a partial header
- `AtfHeaderCard` — name, neutral `Ativo`/`Encerrado` status badge (no red/error color — closure isn't a failure state), `_KvRow`s for implantação/inseminação/touro/observação (optional rows omitted entirely, never blank), D-05 hybrid touro link, and the % prenhez line + progress bar sourced from `summarizeDg`/`formatPrenhez` with zero local arithmetic
- 10 widget tests covering every state named in 05-UI-SPEC E4/E10 (loading, error, populated, partial, both bull-link branches, zero-DG, partial-DG at the UI-SPEC's own 62% example, both status-badge values)

## Task Commits

Each task was committed atomically:

1. **Task 1: Register /atf/:atfId as a root-level route** - `3d2c634` (feat)
2. **Task 2: AtfDetailScreen shell and AtfHeaderCard** - `14e53a9` (feat)
3. **Task 3: Widget test for AtfDetailScreen states** - `a2cabdd` (test)

**Plan metadata:** committed alongside this SUMMARY (worktree mode — orchestrator finalizes STATE.md/ROADMAP.md after wave merge)

_Note: freezed's `.freezed.dart` / `.g.dart` generated parts (from 05-02's `atf_model.dart`/`dg_record_model.dart`) are gitignored and did not exist in this fresh worktree — regenerated via `dart run build_runner build` before `flutter analyze`/`flutter test` ran; not part of any commit._

## Files Created/Modified
- `lib/core/router/routes.dart` - `AppRoutes.atfById` template + `atfDetail(id)` helper
- `lib/core/router/router.dart` - root-level `GoRoute(path: AppRoutes.atfById, ...)`, sibling of `loteById`
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - `AtfDetailScreen`, `AtfHeaderCard`, `_KvRow`
- `test/core/router_test.dart` - `atfById`/`atfDetail` + `AppRoutes.all` length assertions
- `test/widget/atf_detail_screen_test.dart` - 10 widget tests over every AtfDetailScreen state

## Decisions Made
- **Touro link display text**: when `bullAnimalId` is set, the tappable row shows `bullName` if present, else falls back to the raw `bullAnimalId` string, since `AtfBatch` carries no joined animal number/breed and this plan does not query `animals`. Not user-visible as a placeholder-looking string in practice — 05-05's `AtfFormDialog` (a later wave) is expected to populate `bullName` alongside `bullAnimalId` when a dropdown bull is chosen.
- **Secondary provider loading treated as empty, not a spinner**: `atfActiveMembershipsProvider`/`dgRecordsByAtfProvider` use `.asData?.value ?? const []` rather than their own `.when()` branches, so the header renders immediately once the primary `atfByIdProvider` resolves, briefly showing "— · aguardando DG" until the secondary lists settle. Matches the plan's explicit instruction that only the top-level `AsyncValue.when` on the ATF itself gates loading/error.

## Deviations from Plan

None - plan executed exactly as written. Route placement, screen structure, `AtfHeaderCard` contents, and the widget test's 8 required scenarios all match the plan's `<action>`/`<acceptance_criteria>` blocks.

## Issues Encountered
- Generated freezed/json_serializable parts for `atf_model.dart`/`dg_record_model.dart` (produced by plan 05-02 in a different worktree) were absent in this fresh worktree, per the standing gitignore convention. Ran `dart run build_runner build` once before Task 2's `flutter analyze` — resolved cleanly, no conflicting outputs, not committed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `/atf/:atfId` is live and reachable; the wave-3 presentation plans (05-05 ReproducaoScreen/AtfFormDialog, 05-06 composition, 05-07 reproductive-history section, 05-08 DG entry) can each navigate to or extend this screen.
- `AtfDetailScreen`/`AtfHeaderCard` intentionally has no composition, DG, or encerramento markup yet — 05-06, 05-08, and 05-09 each add a section to this same file in a later wave, per the plan's explicit scope boundary.
- Live-DB verification (navigating to a real `/atf/<id>` in `flutter run -d edge`) remains deferred to UAT, consistent with 05-02's note that the Supabase schema push is owned by plan 05-01/05-10.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

All 6 claimed files verified present on disk. All 3 task commits
(`3d2c634`, `14e53a9`, `a2cabdd`) verified present in `git log`.
