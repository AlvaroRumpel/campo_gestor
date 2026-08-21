---
phase: 06-sanitary-module-snapshot
plan: 05
subsystem: frontend
tags: [flutter, go_router, riverpod, material3]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-04)
    provides: "SanitaryApplication/SanitaryCompositionEntry freezed models, visibleApplications/reversedApplicationIds/sortByAppliedAtDesc, SanitaryApplicationException/asSanitaryException, SanitaryApplicationRepository + five providers"
provides:
  - "AppRoutes.aplicacaoById / AppRoutes.aplicacaoDetail(id) — the route helper every sanitary history row in 06-09/06-10/06-11 navigates through"
  - "Root-level GoRoute('/aplicacoes/:id') registered outside the shell"
  - "AplicacaoDetailScreen — read-only frozen-row detail surface with the estorno entry point"
  - "EstornarAplicacaoDialog — the D-27..D-31 reversal confirmation dialog other plans can reuse"
affects: [06-06, 06-07, 06-08, 06-09, 06-10, 06-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Resolved-fallback back button (canPop() ? pop() : go(sanitario)) for a root-level route with three possible list origins — mirrors LoteDetailScreen/AtfDetailScreen"
    - "Header-card + duplicated-per-file _KvRow pattern (A-KVROW-DUP convention) reused verbatim for the third time in this codebase"
    - "reversedApplicationIds() from the model file used to derive both a boolean (hasBeenReversed) and, when true, re-derive the specific sibling row for its date/link — avoids a second query while still surfacing the concrete reversal row"

key-files:
  created:
    - lib/features/sanitario/presentation/aplicacao_detail_screen.dart
    - lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart
  modified:
    - lib/core/router/routes.dart
    - lib/core/router/router.dart

key-decisions:
  - "EstornarAplicacaoDialog takes lotId as a third required constructor param (in addition to applicationId and doseName) — needed to resolve the sibling reversal row from sanitaryApplicationsByLotProvider when the already-reversed race (D-31) fires; the plan's prose only names id+doseName but the D-31 recovery link cannot be built without it"
  - "Dosage figures (dosagem_por_kg/dosagem_por_ua) format through a file-local NumberFormat('#,##0.##', 'pt_BR') rather than formatUa/formatVolumeMl/formatCurrencyBrl — those three helpers are each shaped for a specific unit (UA, mL-or-L, BRL) that doesn't match a plain mL/kg or mL/UA figure; introducing a fourth shared helper for a single call site would be premature abstraction"
  - "'Estorno de' and 'Estornada em' link labels ('Ver aplicação original' / '[date] · Ver estorno') are this plan's own copy choice — the UI-SPEC's Copywriting Contract locks the row *labels* ('Estorno de' / 'Estornada em') but not the tappable link text itself, so the link text follows the existing InkWell-link idiom (AnimalInfoCard's lote/piquete links, AtfHeaderCard's touro link)"

patterns-established: []

requirements-completed: [SANI-02, SANI-04]

coverage:
  - id: D1
    description: "AppRoutes.aplicacaoById/aplicacaoDetail(id) added mirroring loteById/atfById exactly, not added to the `all` shell-branch inventory"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "flutter analyze lib/core/router/routes.dart (0 issues) + flutter test test/ (248/248, including the existing AppRoutes.all count test)"
        status: pass
    human_judgment: false
  - id: D2
    description: "EstornarAplicacaoDialog: required motivo validator, destructive-red confirm button, inline error rendering via asSanitaryException with the estorno-specific fallback, already-reversed race resolves a 'Ver estorno' link from the by-lot sibling list, no ScaffoldMessenger in the file"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ (0 issues) + grep gates (ScaffoldMessenger count 0, PostgrestException absent, asSanitaryException present, colorScheme.error on confirm button, finally-guarded saving reset)"
        status: pass
    human_judgment: true
    rationale: "The dialog's RPC call and its ERRCODE-to-message mapping are structurally correct (routes through asSanitaryException, no raw PostgrestException type in the file) but unexercised against a live database — reverse_sanitary_application is authored on disk but not yet applied to any Supabase project (06-02's scope note, owned by the 06-12 blocking wave). End-to-end correctness of the already-reversed recovery link and the 42501/P0002/P0003/23505 mapping requires 06-12."
  - id: D3
    description: "AplicacaoDetailScreen: root-level route registration, header card with mutually-exclusive status chip, all key-value rows including conditional omission (custo, observação, reversal links), totals line delegating to formatUa/formatVolumeMl/formatCurrencyBrl, role-gated absent-not-disabled estorno action with full provider invalidation on success, uncapped composition list"
    requirement: "SANI-02"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ lib/core/router/ (0 issues) + flutter test test/ (248/248) + grep gates (all locked strings present, 3x Intl.plural, shrinkWrap+NeverScrollableScrollPhysics paired once, itemCount uncapped, cost rows null-guarded)"
        status: pass
    human_judgment: true
    rationale: "Widget compiles and renders against the frozen model shape, but end-to-end correctness (does register_sanitary_application actually produce a row this screen renders faithfully, does the RLS SELECT policy actually return null for a foreign property's id per T-06-06) is unverified until 06-12 applies the migration and runs the pgTAP suite. The must_haves backstop item ('a 200-row composition renders as one continuous scroll with no nested-scroll trap') has no automated widget test in this plan — D-40 is an explicit user decision to keep Dart test scope to calculation-only; the structural guarantee (ListView.builder with itemCount uncapped, no `.take()`, shrinkWrap+NeverScrollableScrollPhysics so it composes into the parent page ListView rather than nesting an independently-scrollable list) is verified by code inspection and mirrors the identical shape _CompositionSection already uses on AtfDetailScreen (05-04), which passed its own 200-row backstop test. Flagged here for the verifier rather than silently assumed."

# Metrics
duration: ~55min
completed: 2026-08-07
status: complete
---

# Phase 6 Plan 05: Application Detail Route + Estorno Dialog Summary

**Root-level `/aplicacoes/:id` route plus the read-only `AplicacaoDetailScreen` (frozen header card, skipped-count note, uncapped composition list) and `EstornarAplicacaoDialog` (required-reason, destructive-red, inline-error reversal confirmation) — the navigation leaf every sanitary history surface in waves 3-5 links into**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- `routes.dart`: `AppRoutes.aplicacaoById` (`/aplicacoes/:id` template) + `AppRoutes.aplicacaoDetail(id)` helper, mirroring `loteById`/`loteDetail` and `atfById`/`atfDetail` verbatim; deliberately excluded from the `all` shell-branch inventory
- `estornar_aplicacao_dialog.dart`: `EstornarAplicacaoDialog` — 400px `AlertDialog`, required-motivo `TextFormField` validator, `LinearProgressIndicator` title-slot while saving, `colorScheme.error`-styled confirm button (the one destructive-red button in the phase), inline error rendering via `asSanitaryException` with motivo text preserved, and a resolvable `"Ver estorno"` link for the D-31 already-reversed race
- `aplicacao_detail_screen.dart`: `AplicacaoDetailScreen` — resolved-fallback back button, three async states handled before any partial-data render, header card (icon + dose name + mutually-exclusive status chip + full key-value row set + reversal links both directions + totals line + role-gated estorno action with full provider invalidation), skipped-animals note via `Intl.plural`, and an uncapped `_CompositionListSection`
- `router.dart`: imports `AplicacaoDetailScreen` and registers `GoRoute(AppRoutes.aplicacaoById, ...)` as a root-level route immediately after the ATF registration, reading the `id` path parameter, in the same commit as the screen (avoids a non-compiling intermediate commit)
- `flutter analyze lib/features/sanitario/ lib/core/router/` reports 0 issues; `flutter test test/` passes 248/248 repo-wide after each task

## Task Commits

Each task was committed atomically:

1. **Task 1: Route constants for the application detail route** - `a77e6e0` (feat)
2. **Task 2: EstornarAplicacaoDialog — required motivo, destructive confirm, inline error** - `9eebc7d` (feat)
3. **Task 3: AplicacaoDetailScreen — header card, skipped note, composition list** - `8fb1df5` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified

- `lib/core/router/routes.dart` — `AppRoutes.aplicacaoById` template + `aplicacaoDetail(id)` helper
- `lib/core/router/router.dart` — root-level `GoRoute(AppRoutes.aplicacaoById, ...)` registration + import
- `lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart` — `EstornarAplicacaoDialog` (new)
- `lib/features/sanitario/presentation/aplicacao_detail_screen.dart` — `AplicacaoDetailScreen`, `_AplicacaoHeaderCard`, `_StatusChip`, `_KvRow`, `_CompositionListSection` (new)

## Decisions Made

- `EstornarAplicacaoDialog` takes `lotId` as a third required constructor parameter (beyond `applicationId`/`doseName`) — required to read `sanitaryApplicationsByLotProvider` and resolve the sibling reversal row for the D-31 "Ver estorno" recovery link; the plan's prose names only id+doseName but the recovery link cannot exist without it.
- Dosage figures (`dosagem_por_kg`/`dosagem_por_ua`) format through a file-local `NumberFormat('#,##0.##', 'pt_BR')` rather than reusing `formatUa`/`formatVolumeMl`/`formatCurrencyBrl` — each of those three is shaped for a specific unit (UA, mL-or-L with a 1000 threshold, BRL currency) that doesn't match a plain mL/kg or mL/UA figure. Adding a fourth shared helper for one call site would be premature.
- The reversal link text (`"Ver aplicação original"` / `"[date] · Ver estorno"`) is this plan's own copy choice — the UI-SPEC locks the row *labels* (`"Estorno de"` / `"Estornada em"`) but not the tappable link text, so the link text follows the codebase's existing InkWell-link idiom (`AnimalInfoCard`'s lote/piquete links, `AtfHeaderCard`'s touro link).

## Deviations from Plan

None (Rule 1-3 auto-fixes) — plan executed as written, with the `lotId` constructor addition and dosage-formatting choice noted above as within-discretion implementation decisions rather than deviations from any locked instruction.

## Known Stubs

None — every surface built this plan (route, dialog, detail screen) is fully wired to the 06-04 repository/providers with no placeholder data paths.

## Issues Encountered

None. `flutter analyze` and `flutter test` were both clean/green after every task commit.

## User Setup Required

None for this plan's Dart-only surface. As noted in 06-04's summary, end-to-end correctness against a live database (RLS returning null for a foreign property's application id per T-06-06, the RPC's actual ERRCODE mapping, the estorno unique-index race) remains unverified until 06-12 applies the migration and runs `06_sanitary_test.sql`.

## Next Phase Readiness

- `AppRoutes.aplicacaoDetail(id)` is available for every sanitary history row waves 3-5 build (06-06 lote section, 06-07 animal ficha section, 06-09..06-11 lists).
- `AplicacaoDetailScreen` and `EstornarAplicacaoDialog` are complete, reachable via `context.go`/`showDialog`, and require no further scaffolding from sibling plans.
- Sibling plans 06-06 (`dose_form_dialog.dart`) and 06-07 (`resumo_aplicacao_dialog.dart`) were not touched, per this plan's sibling-awareness boundary.
- The E7 backstop (200-row composition, one continuous page scroll) is structurally satisfied (uncapped `ListView.builder`, `shrinkWrap: true` + `NeverScrollableScrollPhysics` composing into the parent page `ListView`, same shape as `AtfDetailScreen`'s already-tested `_CompositionSection`) but has no dedicated widget test in this plan — flagged in `coverage` (D3) for the verifier rather than silently assumed, consistent with D-40's explicit calculation-only Dart test scope.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-07*

## Self-Check: PASSED

All created/modified files verified present on disk (`aplicacao_detail_screen.dart`, `estornar_aplicacao_dialog.dart`, `routes.dart`, `router.dart`, this SUMMARY). All three task commit hashes (`a77e6e0`, `9eebc7d`, `8fb1df5`) verified present in `git log --oneline --all`.
