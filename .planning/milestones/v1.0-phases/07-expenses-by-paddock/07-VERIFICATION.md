---
phase: 07-expenses-by-paddock
verified: 2026-08-11T00:00:00Z
status: passed
score: 4/4 roadmap success criteria verified; 2/2 requirements (GAST-01, GAST-02) satisfied
behavior_unverified: 0
overrides_applied: 0
---

# Phase 7: Expenses by Paddock Verification Report

**Phase Goal:** Usuário lança gastos vinculados a piquetes e consulta totais por período.
**Verified:** 2026-08-11
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Usuário pode lançar gasto vinculado a um piquete com categoria, valor, data e descrição | ✓ VERIFIED | `expenses` table (id/property_id/paddock_id/category/amount/expense_date/description) applied to live PROD (ledger 17→18, catalog-confirmed 12/12 per 07-08-SUMMARY.md); `ExpenseFormDialog` (`lib/features/gastos/presentation/expense_form_dialog.dart`) has categoria/valor/data/descrição fields, no piquete field (grep-confirmed), required-field validation, comma-decimal parsing; wired end-to-end via `ExpenseRepository.createExpense`; UAT check 3 passed |
| 2 | Usuário pode visualizar lista de gastos de um piquete filtrada por intervalo de datas | ✓ VERIFIED | `GastosScreen` (`lib/features/gastos/presentation/gastos_screen.dart`) renders `unifiedExpenseListByPaddockProvider`/`...WithDeletedByPaddockProvider`, filter row with 5 period presets + custom range (`showDateRangePicker`) + category dropdown, `filterByDateRange`/`filterByCategory` combinable (unit-tested); route `/gastos/:paddockId` registered root-level in `router.dart:159-163`; UAT checks 2, 5, 6 passed |
| 3 | Total agregado do período é exibido no topo da lista e atualiza ao mudar o filtro | ✓ VERIFIED | `_buildTotalHeader` in `gastos_screen.dart` always renders (even at 0 items), computed via `totalAmount`/`itemCount` over the filtered, non-deleted subset, `Intl.plural` pt-BR count; `PaddockExpenseSummaryCard` reads the same derived provider (`paddockMonthExpenseTotalProvider`) so the paddock-card figure and the screen's opening figure cannot structurally diverge; null-cost sanitary row contributes 0 while still counted, proven by an explicit Dart test (`expense_calculations_test.dart`); UAT check 4 passed |
| 4 | Gastos respeitam isolamento multi-tenant via RLS (mesmo padrão das outras tabelas) | ✓ VERIFIED | `expenses` RLS enabled AND forced; exactly 3 policies (SELECT via `is_member_of`, INSERT/UPDATE via `is_member_of AND get_role IN (owner, veterinarian)`), zero DELETE policy; cross-property isolation trigger `trg_expenses_paddock_same_property` re-validates `paddock_id ∈ property_id` independent of RLS (closes the raw-PATCH bypass class from Phase 4); pgTAP `07_expenses_test.sql` 42/42 replayed against live PROD in `BEGIN…ROLLBACK`, including a real `SET ROLE authenticated` RLS exercise (not just RPC-internal checks) for owner/veterinarian/reader on both INSERT and UPDATE |

**Score:** 4/4 roadmap success criteria verified.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| GAST-01 | 07-01, 07-02, 07-03, 07-04, 07-05, 07-06 | Usuário pode lançar gasto vinculado a um piquete (categoria, valor, data, descrição) | ✓ SATISFIED | End-to-end write path verified (migration → repository → form dialog → screen), UAT check 3 passed, widget/unit tests green |
| GAST-02 | 07-01, 07-02, 07-04, 07-06, 07-07 | Usuário pode visualizar total de gastos de um piquete por período (filtro por data) | ✓ SATISFIED | End-to-end read/filter/total path verified, UAT checks 2/4/6 passed |

Both IDs are declared in `requirements:` frontmatter across the plans that implement them and appear in each plan's `coverage:` block with `status: pass`. No orphaned requirement IDs — REQUIREMENTS.md maps only GAST-01/GAST-02 to Phase 7 and both are claimed.

**Note (not a phase-specific gap):** REQUIREMENTS.md's checkbox list and Traceability table still show `GAST-01`/`GAST-02` as unchecked/"Pending" — but this is a project-wide staleness pattern in that file (SANI-01..05 for the already-UAT-verified Phase 6 show the identical "Pending" state), not something introduced or missed by Phase 7 specifically.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `supabase/migrations/20260813_07_expenses_module.sql` | `expenses` table + RLS + triggers + sanitary paddock freeze + RPC edits | ✓ VERIFIED | On disk, matches plan spec exactly (read verbatim); applied to live PROD `wrdwzychjhlpwpivfhhq`, ledger 17→18, 12/12 catalog checks passed |
| `supabase/tests/07_expenses_test.sql` | 42-assertion pgTAP suite | ✓ VERIFIED | On disk, `plan(42)` matches assertion count; replayed 42/42 against live PROD; one assertion legitimately strengthened (see Anti-Patterns) not weakened |
| `lib/features/gastos/data/{expense_model,expense_constants,expense_calculations,expense_repository}.dart` | Model, constants, pure calc, repository/providers | ✓ VERIFIED | All exist, `flutter analyze` clean, unit-tested (60 unit tests across calc/unified-list) |
| `lib/core/auth/role_gates.dart` | `canManageExpenses` two-role gate | ✓ VERIFIED | Exists, 7 unit cases pass, `PaddockDetailScreen._canEdit` provably untouched (`git diff --quiet`) |
| `lib/features/gastos/presentation/{expense_form_dialog,gastos_screen,_expense_list_item_card,paddock_expense_summary_card}.dart` | Write dialog, screen, list card, summary card | ✓ VERIFIED | All exist, wired, widget-tested (26 widget tests) |
| `lib/core/router/routes.dart` + `router.dart` | `/gastos/:paddockId` route | ✓ VERIFIED | Root-level `GoRoute`, outside shell, matches `loteById`/`atfById`/`aplicacaoById` pattern |
| `lib/features/piquetes/presentation/paddock_detail_screen.dart` | Expense summary card wired in | ✓ VERIFIED | `PaddockExpenseSummaryCard(paddockId:)` renders unconditionally between `_PaddockInfoCard` and the lots section; `_canEdit` untouched, coexisting comment present |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `ExpenseFormDialog` submit | `unifiedExpenseListByPaddockProvider`/`...WithDeletedByPaddockProvider`/`paddockMonthExpenseTotalProvider` | `ref.invalidate` (3 calls in `GastosScreen`) | ✓ WIRED | Confirmed in `_invalidateProviders()` |
| `buildUnifiedExpenseItems` | frozen `SanitaryApplication.paddockId` (never `lots.paddock_id`) | filter before wrap | ✓ WIRED | Confirmed in `expense_repository.dart`; grep-enforced absence of a live `lots` join |
| `PaddockExpenseSummaryCard` | `AppRoutes.gastosPorPiquete` → `GoRoute(gastosById)` | `context.push` | ✓ WIRED | Confirmed in `paddock_expense_summary_card.dart` and `router.dart` |
| `GastosScreen` sanitary row tap | `/aplicacoes/:id` | `context.push(AppRoutes.aplicacaoDetail(...))` | ✓ WIRED | Confirmed in `gastos_screen.dart` `_buildList` |
| `expenses.paddock_id` | `paddocks.id` re-validated against `property_id` | `trg_expenses_paddock_same_property` | ✓ WIRED | Confirmed in migration text; pgTAP Group 3 exercises INSERT and UPDATE cross-property rejection (23503) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Gastos feature test suite | `flutter test test/features/gastos/` | 47/47 pass | ✓ PASS |
| Full Dart suite | `flutter test` | 312/312 pass | ✓ PASS (matches ground truth; 7 more than 07-08-SUMMARY's 305 due to the post-UAT G-07-2 restore test file added afterward) |
| Static analysis | `flutter analyze lib test` | 4 issues, all pre-existing outside Phase 7 (2 info, 2 unused-import warnings in Phase 3/6 test files) | ✓ PASS |
| pgTAP null-cost/backstop truth | `test/features/gastos/expense_calculations_test.dart` | Explicit assertion: null `totalCost` → 0 contribution, still counted | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention exists in this project; verification runs on Flutter/pgTAP tests directly (covered above). Not applicable.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `supabase/tests/07_expenses_test.sql` | Group 4 (reader-UPDATE assertion) | Assertion originally expected `throws_ok(..., '42501')`, corrected in commit `ac03bff` to assert 0-row-affected + unchanged stored value | ℹ️ Info | Verified NOT a weakening — RLS only raises 42501 from a failing `WITH CHECK`; a failing `USING` filters silently. The replacement assertion is *stronger* (proves no mutation occurred vs. merely proving an error was raised). Documented transparently in the SUMMARY and the test file's own comment. No action needed. |
| `.planning/STATE.md` | § Blockers / Phase Status table | 07-08-PLAN.md task 1 explicitly required "Update the migration ledger count in `.planning/STATE.md` § Blockers from 17 to 18 with a dated line" as an acceptance criterion; grep confirms no Phase 7 / ledger-18 line exists anywhere in STATE.md, and the Phase Status table still reads "planned (8 plans, 5 waves — ready to execute)" for Phase 7 despite 8/8 plans executed and UAT 7/7 passed | ⚠️ Warning | Documentation/bookkeeping gap only — does not affect the app's runtime behavior, the live database state, or any of the 4 roadmap success criteria, all of which were independently confirmed by direct code/schema/test inspection rather than by trusting this claim. SUMMARY.md's Task 1 "✅"/"12/12" framing did not surface that this specific acceptance criterion was left undone. Recommend updating STATE.md's ledger line and Phase 7 status row before starting Phase 8, so `/gsd-next` and future session resumes don't read a stale "planned" status. |
| Phase-wide `must_haves.prohibitions` blocks (07-01, 07-03 through 07-07) | frontmatter | Every prohibition's `status` field is still literally `unresolved` with `verification: null` — none was explicitly flipped to `resolved` in any PLAN/SUMMARY | ℹ️ Info | Substantively resolved by direct code inspection for all 7 prohibitions checked (no DELETE policy; frozen paddock attribution with no live `lots` join; two-role gate never merged with `_canEdit`; `.select().single()` on every write; no comprovante/attachment surface; sanitary rows never show a silent zero; error state never renders a fake `R$ 0,00`). This is a bookkeeping gap in the frontmatter status field, not a functional gap — flagging per the escalation-gate protocol rather than silently absorbing it into a clean pass. |

## Human Verification

None required — UAT (`07-UAT.md`) already covers the full flow with a human tester: 7/7 checks passed, one real gap found and fixed (G-07-2, commit `36b200b`, with 4 regression tests), one reported item investigated and closed as not-a-defect (G-07-1) with two kept artifacts (a stronger detail-screen-mounted test and an explicit `BackButton` fallback for the deep-link case).

## Gaps Summary

No gaps block the phase goal. The 4 ROADMAP success criteria and both requirement IDs (GAST-01, GAST-02) are all independently verified against the live database schema, the committed code, the automated test suites (312/312 Dart, 42/42 pgTAP), and a completed human UAT with a real fix cycle.

One documentation/bookkeeping item is flagged as a WARNING rather than silently passed over: `.planning/STATE.md` was never updated with the Phase 7 migration ledger entry or a "complete" phase status, despite this being an explicit task-1 acceptance criterion in `07-08-PLAN.md`. This should be corrected before the project moves to Phase 8, but it does not represent a functional defect in the shipped feature — every functional claim was verified independently of STATE.md.

Two known, honestly-documented deviations from the original plan set (both already surfaced in SUMMARY.md, re-confirmed here against the actual codebase, not just accepted on the SUMMARY's word):
1. `07-04` added `SanitaryApplication.paddockId`/`paddockName` to the Dart model — a file no Phase 7 plan's `files_modified` ever listed, despite three planning documents assuming it already existed. Confirmed via `git log` that this landed in commit `5112283`/`367ec84` as a necessary fix for `buildUnifiedExpenseItems` to compile; without it GAST-02's cross-module merge could not function. This is a real gap in the original plan set's coverage, correctly caught and fixed during execution rather than shipped broken.
2. `07-08` (the blocking migration-apply plan) was executed by the orchestrator rather than a `gsd-executor` subagent, because the `gsd-executor` tool list lacks Supabase MCP tools. Confirmed as an accurate account — this will recur on every future migration-apply plan until the executor's tool list is widened. Flagged in SUMMARY as an action item, not silently absorbed.

D-37's scope note ("4 planos em 3 waves" → shipped 8 plans in 5 waves) is confirmed as a legitimate re-approved scope expansion, not a dropped decision — every plan traces cleanly to GAST-01/GAST-02 and the ROADMAP success criteria.

---
*Verified: 2026-08-11*
*Verifier: Claude (gsd-verifier)*
