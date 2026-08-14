---
phase: quick-260814-g9j
plan: 01
subsystem: database, auth, ui
tags: [postgresql, rls, security-definer, flutter, go_router, riverpod, role-gating]

requires:
  - phase: quick-260814-f2v
    provides: multi-tenant RLS hardening (migration 20260814_09), ErrorRetry pattern
provides:
  - "Migration 20260814_10_medium_hardening.sql — 7 database fixes, forward-only, NOT applied"
  - "safeReturnTo() open-redirect guard for post-login deep-link return"
  - "SectionCard.onTap — cards can be made tappable without breaking existing const usages"
  - "isVeterinarian() role helper in role_gates.dart"
  - "Role-gated DG rendering (StatusChip text vs interactive segments) in AtfDetailScreen"
  - "Role-gated empty-state CTAs in PiquetesScreen and AnimaisScreen"
affects: [database-migrations, dashboard, router, reproducao, piquetes, animais, sanitario]

tech-stack:
  added: []
  patterns:
    - "Forward-only corrective migrations (CREATE OR REPLACE FUNCTION with full body) for already-applied RPCs — established in 20260814_09, reused here for move_lot_to_paddock, register_baixa, register_sanitary_application"
    - "outOfNav boolean flag replacing index-clamp for bottom-nav destinations that exist outside the visible tab set"
    - "Papel negado → controle ausente, nunca desabilitado (role_gates.dart convention, applied to DG segments and empty-state CTAs)"

key-files:
  created:
    - supabase/migrations/20260814_10_medium_hardening.sql
  modified:
    - lib/core/widgets/ui.dart
    - lib/core/widgets/app_shell.dart
    - lib/core/router/router.dart
    - lib/features/dashboard/presentation/dashboard_screen.dart
    - lib/core/auth/role_gates.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - lib/features/piquetes/presentation/piquetes_screen.dart
    - lib/features/animais/presentation/animais_screen.dart
    - lib/features/sanitario/presentation/registrar_aplicacao_screen.dart
    - test/widget/app_shell_test.dart
    - test/core/router_test.dart
    - test/widget/atf_detail_screen_test.dart
    - test/widget/piquetes_screen_test.dart
    - test/widget/aplicacao_registro_screen_test.dart

key-decisions:
  - "register_sanitary_application recreated from 20260813_07 (paddock-freeze version, D-30), NOT from 20260811_06 — using the wrong base would have reverted Phase 7 and broken paddock_id NOT NULL"
  - "expenses.owner_vet_can_update_expense policy left untouched — adding created_by = auth.uid() there would block a vet editing an expense entered by another member"
  - "The 5 pre-existing private _canEdit duplicates (animais_screen, animal_detail_screen, lote_detail_screen, piquetes_screen, atf_detail_screen) were NOT consolidated — isVeterinarian() only exists so a 6th duplicate wasn't needed"

requirements-completed: []

coverage:
  - id: D1
    description: "Migration 20260814_10 closes 7 medium-severity DB findings (property-creation policy, lot-archive guard, move_lot_to_paddock TOCTOU, future-date guards on baixa/sanitary-application/expenses, expense authorship, anon RPC execute revocation, search_path pinning) — authored but NOT applied"
    verification:
      - kind: other
        ref: "grep-based structural verification (15 REVOKE lines, 2 ALTER FUNCTION lines, >=3 current_date guards) — see Task 1 verify block"
        status: pass
    human_judgment: true
    rationale: "SQL correctness against live PROD schema cannot be proven without applying the migration, which is explicitly out of scope for this executor (orchestrator applies via MCP)."
  - id: D2
    description: "Card Gastos on dashboard navigates to /gastos; bottom nav shows no false-selected tab when on /gastos below 600px"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#AppShell shows no selected tab at 360x800 on /gastos (branch 6, out of nav)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Deep link intercepted by login redirect returns to the original destination; external/auth/no-access targets fall back to /dashboard"
    verification:
      - kind: unit
        ref: "test/core/router_test.dart#safeReturnTo (T-g9j-08: open-redirect guard) — 6 cases"
        status: pass
    human_judgment: false
  - id: D4
    description: "ATF DG renders as static text (StatusChip) for a denied role, interactive segments stay for a veterinarian; dashboard alerts banner hidden for non-vet"
    verification:
      - kind: unit
        ref: "test/widget/atf_detail_screen_test.dart#T-g9j-09 tests (2)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Empty states of PiquetesScreen and AnimaisScreen show a create CTA for veterinarian, neutral text for other roles"
    verification:
      - kind: unit
        ref: "test/widget/piquetes_screen_test.dart#PiquetesScreen empty state ... (2 tests)"
        status: pass
    human_judgment: false
  - id: D6
    description: "RegistrarAplicacaoScreen opens the dose form directly when no dose exists, instead of a dead-end empty picker"
    verification:
      - kind: unit
        ref: "test/widget/aplicacao_registro_screen_test.dart#260814-g9j: zero-doses backstop opens the dose form directly"
        status: pass
    human_judgment: false

duration: 27min
completed: 2026-08-14
status: complete
---

# Quick Task 260814-g9j: Correções de findings médios do review geral Summary

**Migration de hardening médio (7 fixes de banco, forward-only, não aplicada) + 4 correções de Flutter: navegação do card Gastos, deep link preservado no login, convenção de papel negado no ATF/dashboard, empty states com CTA por papel.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-08-14T15:10:17Z
- **Completed:** 2026-08-14T15:36:35Z (docs commit follows)
- **Tasks:** 3
- **Files modified:** 14 (1 created, 13 modified)

## Accomplishments

- Authored `supabase/migrations/20260814_10_medium_hardening.sql` closing 7 medium-severity findings: property-creation policy DROP, lot-archive guard trigger, `move_lot_to_paddock` TOCTOU fix, future-date guards on `register_baixa`/`register_sanitary_application`/`expenses`, `expenses` authorship (`created_by = auth.uid()`), `REVOKE EXECUTE` from `anon`/`PUBLIC` on 15 SECURITY DEFINER functions, and `search_path` pinning on 2 functions — **not applied**, pending orchestrator MCP `apply_migration`.
- `SectionCard` gained an optional `onTap`; the dashboard's Gastos card now navigates to `/gastos` with a chevron affordance.
- Bottom nav no longer shows a false-selected tab when the active route (`/gastos`) is outside the mobile nav's 5 destinations — `outOfNav` flag replaces the old index-clamp, with the indicator pill and selected icon suppressed.
- Login redirect now captures the intercepted deep link (`from` query param) and returns the user to it post-auth via `safeReturnTo()`, which rejects external URLs, protocol-relative URLs, auth routes, and `/sem-acesso`.
- ATF detail screen renders each animal's DG result as a `StatusChip`/text for a denied role instead of a disabled `DgSegmentButton` row; the dashboard's "PRECISA DE VOCÊ HOJE" banner is now vet-only on both mobile and desktop.
- Empty states of `PiquetesScreen` and `AnimaisScreen` show a create CTA only for veterinarians; other roles see neutral copy with no action.
- `RegistrarAplicacaoScreen._pickDose` opens `DoseFormDialog` directly when no dose exists, instead of a dead-end empty picker sheet.

## Task Commits

Each task was committed atomically:

1. **Task 1: Migration de hardening médio (7 fixes, forward-only, não aplicada)** - `a4a1345` (feat)
2. **Task 2: Card Gastos navegável, bottom nav sem seleção falsa e deep link preservado no login** - `8215e15` (feat)
3. **Task 3: Convenção de papel — DG somente-leitura, banner de alertas vet-only e empty states com CTA** - `d75defd` (feat)

**Plan metadata:** _(this SUMMARY's commit follows)_

## Files Created/Modified

- `supabase/migrations/20260814_10_medium_hardening.sql` - 7 forward-only DB fixes; NOT applied to any environment
- `lib/core/widgets/ui.dart` - `SectionCard.onTap` (InkWell inside Card)
- `lib/core/widgets/app_shell.dart` - `outOfNav` flag replaces index-clamp for bottom nav
- `lib/core/router/router.dart` - `safeReturnTo()` + `from` capture/consumption in the redirect
- `lib/features/dashboard/presentation/dashboard_screen.dart` - Gastos card navigation + vet-only alerts banner (mobile + desktop)
- `lib/core/auth/role_gates.dart` - `isVeterinarian()` helper
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - DG renders as text for denied role
- `lib/features/piquetes/presentation/piquetes_screen.dart` - role-gated empty-state CTA
- `lib/features/animais/presentation/animais_screen.dart` - role-gated empty-state CTA
- `lib/features/sanitario/presentation/registrar_aplicacao_screen.dart` - opens dose form on empty dose list
- `test/widget/app_shell_test.dart` - new test for out-of-nav bottom bar state
- `test/core/router_test.dart` - new `safeReturnTo` test group (6 cases)
- `test/widget/atf_detail_screen_test.dart` - 2 new tests for role-gated DG rendering
- `test/widget/piquetes_screen_test.dart` - 2 new tests for role-gated empty state, `_buildScreen` gained `canEdit`/membership override
- `test/widget/aplicacao_registro_screen_test.dart` - updated the pre-existing zero-doses test for the new direct-open behavior (deviation, see below)

## Decisions Made

- `register_sanitary_application` was recreated from `20260813_07_expenses_module.sql` (the live PROD version with the paddock-freeze columns, D-30), never from `20260811_06_sanitary_rpcs.sql` — using the wrong base would have reverted Phase 7 and broken `paddock_id NOT NULL`.
- `owner_vet_can_update_expense` policy left intact — adding `created_by = auth.uid()` to it would block a veterinarian editing an expense entered by another member (owner or a different vet).
- The 5 pre-existing private `_canEdit` duplicates (`animais_screen`, `animal_detail_screen`, `lote_detail_screen`, `piquetes_screen`, `atf_detail_screen`) were **not** consolidated — `isVeterinarian()` in `role_gates.dart` exists only so a 6th duplicate wasn't created; consolidating the existing five is candidate for its own quick task.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Codegen artifacts missing at worktree start**
- **Found during:** Pre-flight, before Task 2
- **Issue:** `flutter analyze --no-pub` reported 849 errors, all `undefined_getter`/`undefined_method` on freezed model classes (`Paddock`, `Property`, `AtfBatch`, `Animal`, `DgRecord`, `SanitaryApplication`, `Lot`) — the worktree had no `*.freezed.dart`/`*.g.dart` files.
- **Fix:** Ran `flutter pub get` then `dart run build_runner build` (27 outputs written).
- **Files modified:** none (generated files are gitignored/excluded from analysis per `analysis_options.yaml`)
- **Verification:** `flutter analyze --no-pub` dropped to 4 pre-existing info-level lints
- **Committed in:** N/A (generated artifacts not committed)

**2. [Rule 1 - Bug] Pre-existing test broke from Task 3d's intentional behavior change**
- **Found during:** Task 3 (full test suite run)
- **Issue:** `test/widget/aplicacao_registro_screen_test.dart`'s "zero-doses backstop" test asserted the OLD behavior (empty `_PickerSheet` with an explanatory message) that Task 3d deliberately replaced.
- **Fix:** Updated the test to assert the new behavior — tapping "Selecionar" with zero doses opens `DoseFormDialog` ("Nova dose") directly, never the empty-picker message.
- **Files modified:** `test/widget/aplicacao_registro_screen_test.dart`
- **Verification:** `flutter test test/widget/aplicacao_registro_screen_test.dart` — 10/10 pass
- **Committed in:** `d75defd` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking/environment, 1 bug — pre-existing test contradicted the plan's own intended behavior change)
**Impact on plan:** Both necessary to reach a green suite. No scope creep — neither touched files outside this plan's declared scope beyond the one test file whose assertion the plan's own Task 3d instructions made obsolete.

## Issues Encountered

- `flutter analyze --no-pub` reports 4 pre-existing info-level lints (`unintended_html_in_doc_comment` in `app_config.dart`, `use_null_aware_elements` in `_expense_list_item_card.dart`/`propriedade_repository.dart`/`atf_dg_table_view.dart`) in files never touched by this plan. Logged to `.planning/quick/260814-g9j-corrigir-findings-medios-do-review-banco/deferred-items.md` per SCOPE BOUNDARY — not fixed here.

## User Setup Required

None - no external service configuration required.

**Database migration pending application** (not user setup, orchestrator-owned): `supabase/migrations/20260814_10_medium_hardening.sql` is authored and verified on disk but **NOT applied** to any environment. The orchestrator applies it via MCP `apply_migration` after this plan completes. Two operational notes for that step:

- The `ADD CONSTRAINT expenses_date_not_future` statement aborts the whole migration transaction if PROD has any `expenses` row with `expense_date` in the future — the preceding `DO` block reports the exact row count so the operator can correct them first.
- `register_sanitary_application` in this migration was rebuilt from `20260813_07_expenses_module.sql`, preserving the `paddock_id`/`paddock_name` freeze (D-30) — applying it does NOT touch or revert Phase 7's paddock-freeze columns.

## Next Phase Readiness

- All 3 tasks complete, `flutter analyze --no-pub` clean of new issues (4 pre-existing infos unrelated to this plan), `flutter test` green at 434/434 (11 new tests: 6 `safeReturnTo`, 1 `app_shell`, 2 `atf_detail_screen`, 2 `piquetes_screen`), plus 1 pre-existing test updated for an intentional behavior change.
- `20260814_09_multitenant_hardening.sql` confirmed byte-identical (no diff) — this plan never touched it.
- Blocker for next step: `20260814_10_medium_hardening.sql` needs the orchestrator's `apply_migration` pass before its 7 fixes take effect in any environment.

---
*Phase: quick-260814-g9j*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: `supabase/migrations/20260814_10_medium_hardening.sql`
- FOUND: `.planning/quick/260814-g9j-corrigir-findings-medios-do-review-banco/deferred-items.md`
- FOUND commit `a4a1345` (Task 1)
- FOUND commit `8215e15` (Task 2)
- FOUND commit `d75defd` (Task 3)
