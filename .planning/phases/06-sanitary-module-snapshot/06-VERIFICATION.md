---
phase: 06-sanitary-module-snapshot
verified: 2026-08-07T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Re-run UAT test 2 (Dose Management, Doses tab) — specifically the restore/desarquivar and edit-while-archived paths that failed originally as G-06-2"
    expected: "Tapping 'Reativar dose' on an archived dose actually un-archives it and it returns to the active list; editing a dose while archived persists"
    why_human: "Fix is proven at the RLS/catalog level (rolled-back RLS round-trip: UPDATE affected 1 row vs 0 pre-fix; pgTAP Group 12's 6 restore-regression assertions green) and the corrective migration is applied to live PROD (ledger 17), but no one has exercised the actual button in the running app since the fix landed — 06-UAT.md explicitly leaves this as the pending re-run"
  - test: "Re-run UAT test 9 (Animal Ficha — Histórico Sanitário) — open an animal ficha with sanitary applications and one without"
    expected: "The Histórico Sanitário section resolves to real application rows (or the empty-state sentence for an animal with none) instead of spinning forever on PostgREST 22P02"
    why_human: "Fix is proven at the unit-test level (request-level regression test asserts the emitted filter is valid JSON matching the GIN index shape; retry-policy test asserts a PostgrestException is not retried) but the plan itself defers the live-browser confirmation to the UAT re-run — 06-14-SUMMARY.md D3 explicitly marks this human_judgment: true, unexecuted by the plan's own executor"
---

# Phase 6: Sanitary Module (Snapshot) Verification Report

**Phase Goal:** Usuário cadastra doses, registra aplicações sanitárias em lotes com snapshot imutável da composição, e consulta histórico por lote e por animal.
**Verified:** 2026-08-07
**Status:** human_needed
**Re-verification:** No — initial verification (14 plans, including 2 gap-closure plans, verified together as one phase submission)

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth (SC) | Status | Evidence |
|---|---|---|---|
| 1 | Usuário cadastra dose com nome e valor por kg; sistema calcula `valor_por_ua = valor_por_kg × 400`, campo não editável | ✓ VERIFIED | `sanitary_calculations.dart` (`dosagePerUa`), `dose_form_dialog.dart` lines 167-168, 233, 258 (`enabled: false` on both computed fields), `properties.kg_per_ua NOT NULL DEFAULT 400` in `20260810_06_sanitary_module.sql`. Restore/edit-while-archived sub-path (originally G-06-2) fixed by corrective migration `20260812_06_fix_dose_update_policy.sql`, applied to live PROD (ledger 17), proven by a rolled-back RLS round-trip (UPDATE affected 1 row vs 0 pre-fix) and pgTAP Group 12 (6/6 green). Live browser re-confirmation still pending — see Human Verification. |
| 2 | Ao registrar aplicação em um lote, sistema mostra todos animais ativos pré-selecionados; usuário pode desmarcar individuais | ✓ VERIFIED | `sanitary_animal_selection_screen.dart` pre-checks all active animals, live counter, continue disabled at zero selected. UAT test 3 (Register Application) and test 5 (Register from Lote Detail) both `pass`. |
| 3 | Após confirmação, snapshot é gravado e nunca muda — UPDATE/DELETE bloqueado pelo banco | ✓ VERIFIED | `sanitary_applications` carries exactly 1 policy (`members_can_read_sanitary_applications`, SELECT-only) — no INSERT/UPDATE/DELETE policy exists; write surface is the two SECURITY DEFINER RPCs only. Phase 2's `trg_snapshot_immutable` confirmed still present/enabled post-ALTER (06-12 catalog verification, 14/14 objects). pgTAP suite (81 assertions, `plan(81)`) exercises immutability, reversal-of-reversal block (23514), blank-reason block (22023). 80/81 pass against live PROD; the 1 failure is a documented environmental false positive (Group 8's unscoped `count(*) FROM sanitary_applications` assumes an empty table, PROD holds real UAT rows) — not a schema defect. |
| 4 | Usuário visualiza histórico sanitário do lote ordenado por data | ✓ VERIFIED | `lote_detail_screen.dart` line 121 wires `LoteSanitaryHistorySection(lotId: loteId)`; `sanitary_history_section.dart` orders by `applied_at desc, created_at desc`. UAT test 10 `pass`. |
| 5 | Usuário visualiza histórico sanitário de um animal via lookup no snapshot, mesmo após mudança de lote | ✓ VERIFIED | `animal_detail_screen.dart` line 108 wires `AnimalSanitaryHistorySection(animalId: animal.id)`; `fetchSanitaryHistoryByAnimal` uses `.contains('composition_snapshot', jsonEncode([{'animal_id': animalId}]))` against the `jsonb_path_ops` GIN index — fixes the G-06-9 22P02 defect (verified: malformed-List encoding replaced with valid JSON, request-level regression test passes, retry policy no longer masks PostgrestException behind ~10 retries). Both new tests pass (`test/core/retry_policy_test.dart`, `test/features/sanitario/sanitary_application_repository_test.dart` — re-ran directly, 3/3 pass). Live browser re-confirmation still pending — see Human Verification. |

**Score:** 5/5 truths verified at the codebase/automated-proof level. 2 of the 5 carry a pending human UAT re-run (see Human Verification) because both were the exact tests that failed in the original UAT pass; their fixes are proven by RLS round-trip / unit test but not yet re-exercised in the running app.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/features/sanitario/data/sanitary_calculations.dart` | Pure calc module (dosagePerUa, costPerUa, totals, formatters) | ✓ VERIFIED | Present, imported by dose_form_dialog and resumo_aplicacao_dialog |
| `lib/features/sanitario/data/dose_model.dart` + `dose_repository.dart` | Dose CRUD, nullable cost | ✓ VERIFIED | Present, freezed model, `SupabaseService`-only access |
| `lib/features/sanitario/data/sanitary_application_model.dart` + `_repository.dart` + `_exception.dart` | Frozen-row model, 4 read shapes, pt-BR exception mapping | ✓ VERIFIED | Present, `visibleApplications`, `sanitaryHistoryByAnimalProvider` confirmed |
| `supabase/migrations/20260810_06_sanitary_module.sql` + `20260811_06_sanitary_rpcs.sql` | Schema + RPCs | ✓ VERIFIED | Applied to live PROD (ledger 16, then 17 after fix). Catalog-verified 14/14 objects. |
| `supabase/migrations/20260812_06_fix_dose_update_policy.sql` | G-06-2 corrective migration | ✓ VERIFIED | Present, applied to PROD, `20260810_06` left byte-identical (forward-only, no re-edit of applied migration) |
| `lib/features/sanitario/presentation/*.dart` (8 files: detail, form, dialogs, screens, history section) | Full UI surface | ✓ VERIFIED | All 8 files present, non-stub, wired into router/lote/animal screens |
| `supabase/tests/06_sanitary_test.sql` | pgTAP suite ≥25 assertions | ✓ VERIFIED | 585 lines, `plan(81)`, Group 12 present, 80/81 pass live (1 documented environmental false positive) |
| `lib/features/sanitario/data/sanitary_application_repository.dart` (G-06-9 fix) | JSON-encoded containment filter | ✓ VERIFIED | Lines 95-101, `jsonEncode([{'animal_id': animalId}])` |
| `lib/main.dart` (`providerRetryPolicy`) | Non-retry on PostgrestException | ✓ VERIFIED | Wired into `ProviderScope(retry: providerRetryPolicy, ...)`, line 24 & 41 |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|
| `dose_form_dialog.dart` | `sanitary_calculations.dart` | `dosagePerUa`/`costPerUa` calls, `enabled: false` fields | ✓ WIRED | Confirmed lines 167-168, 233, 258 |
| `animal_detail_screen.dart` | `sanitary_history_section.dart` | `AnimalSanitaryHistorySection(animalId: ...)` | ✓ WIRED | Line 108 |
| `lote_detail_screen.dart` | `sanitary_history_section.dart` + `aplicacao_form_dialog.dart` | `LoteSanitaryHistorySection(lotId: ...)`, "Registrar aplicação" button → `AplicacaoFormDialog` | ✓ WIRED | Lines 94, 121, 278 |
| `sanitary_application_repository.dart` | `sanitary_applications` table | `.contains('composition_snapshot', jsonEncode(...))` over GIN index | ✓ WIRED | Fixed encoding confirmed; regression test passes |
| `register_sanitary_application` RPC | `animals.category`, `doses`, `properties.kg_per_ua` | server-side recomputation, no client-submitted totals | ✓ WIRED | Confirmed in `20260811_06_sanitary_rpcs.sql` |
| `sanitary_applications` table | RLS | exactly 1 SELECT-only policy, zero write policies | ✓ WIRED | Confirmed via migration + 06-12 catalog verification |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| G-06-9 regression test exists and passes | `flutter test test/core/retry_policy_test.dart test/features/sanitario/sanitary_application_repository_test.dart` | 3/3 passed | ✓ PASS |
| pgTAP suite declares 81-assertion plan with Group 12 | `grep "plan(81)"` / `grep "Group 12"` on `06_sanitary_test.sql` | both found | ✓ PASS |
| Corrective migration leaves original migration untouched | executor-reported `git diff --stat` empty on `20260810_06_sanitary_module.sql` | confirmed in 06-13-SUMMARY.md | ✓ PASS (documented, not independently re-run — file content matches migration on disk) |
| Live PROD apply + pgTAP replay | orchestrator MCP `apply_migration` + `execute_sql` (ledger 16→17, 80/81 pass) | documented in STATE.md + 06-13-SUMMARY.md | ✓ PASS (orchestrator-run, cross-referenced against STATE.md ledger entry, not re-executed by this verifier — no MCP Supabase tool access in this session) |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| SANI-01 | 06-01, 02, 03, 06, 10, 13 | Cadastro dose + valor/UA automático | ✓ SATISFIED | Dose CRUD + calc module + form + live restore fix |
| SANI-02 | 06-01, 02, 04, 05, 07, 08, 11, 12 | Registrar aplicação com snapshot imutável | ✓ SATISFIED | RPC + immutability trigger + RLS + dialogs |
| SANI-03 | 06-01, 02, 04, 07, 08, 12 | Desmarcar animais antes de confirmar (default = todos) | ✓ SATISFIED | Selection screen, UAT test 3/4 pass |
| SANI-04 | 06-01, 02, 04, 05, 09, 10, 11, 12 | Histórico por lote | ✓ SATISFIED | `LoteSanitaryHistorySection`, UAT test 10 pass |
| SANI-05 | 06-01, 02, 04, 09, 12, 14 | Histórico por animal via snapshot lookup | ✓ SATISFIED | Containment fix (G-06-9), regression test passes; live re-confirm pending |

**No orphaned requirements** — all 5 SANI-* IDs from REQUIREMENTS.md appear in at least one plan's `requirements:` frontmatter, and every plan's declared requirement is covered by verified artifacts above.

### Anti-Patterns Found

None blocking. Grep for `TODO|FIXME|XXX|TBD|placeholder|not implemented|coming soon` across `lib/features/sanitario/`, `lote_detail_screen.dart`, `animal_detail_screen.dart` returned only doc-comment references to the historical Phase 0 placeholder being replaced (e.g. `sanitario_screen.dart:30`, `sanitary_history_section.dart:20`) — not live stub code. WR-03 (existence-leak between error codes in the two RPCs) was reviewed and deliberately deferred as a codebase-wide, pre-existing convention shared with Phase 4/5 RPCs, documented in `06-REVIEW-FIX.md` and `STATE.md` — not a Phase 6-introduced regression, not a blocker for this phase's goal.

### Gaps Summary

No code-level gaps. Both UAT-reported defects (G-06-2 dose restore no-op, G-06-9 animal-ficha spinner) have corrective migrations/code fixes applied and proven by automated evidence (RLS round-trip, pgTAP replay, unit/regression tests — all independently re-checked by this verifier where re-runnable). The only open item is procedural: the human has not yet re-run UAT tests 2 and 9 in the live app to close the loop on the two fixes, per 06-UAT.md's own outstanding gap entries and the session context note. This is an escalation to the developer, not a defect — routed as `human_needed`.

---

*Verified: 2026-08-07*
*Verifier: Claude (gsd-verifier)*
