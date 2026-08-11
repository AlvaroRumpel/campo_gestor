---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 8 — Animal Dossier Consolidation
current_plan: Not started
status: phase-complete
stopped_at: Phase 07 complete — 8/8 plans, migration live, UAT 7/7, verification passed
last_updated: "2026-08-11T19:14:34.818Z"
last_activity: 2026-08-11
progress:
  total_phases: 8
  completed_phases: 8
  total_plans: 60
  completed_plans: 60
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo
**Current phase:** 8 — Animal Dossier Consolidation
**Current plan:** Not started
**Progress:** [████████░░] 78% (7 of 9 phases complete)

---

## Phase Status

| # | Phase | Status |
|---|---|---|
| 0 | Foundation | complete (6/6 plans) |
| 1 | Auth & Multi-tenancy Core | complete (UAT 4/4 — 2026-05-07) |
| 2 | Property & Paddock Structure | complete (UAT 9/10 — 2026-05-08) |
| 3 | Lots & Animals (Operational Core) | complete (UAT 5/5 — 2026-08-10) |
| 4 | Movements | complete (7/7 plans, UAT 8/8 — 2026-08-04) |
| 5 | Reproductive Module (LoteATF) | complete (15/15 plans, UAT — 2026-08-06) |
| 6 | Sanitary Module (Snapshot) | complete (14/14 plans, UAT 11/11 — 2026-08-11) |
| 7 | Expenses by Paddock | complete (8/8 plans, UAT 7/7 — 2026-08-11) |
| 8 | Animal Dossier Consolidation | not-started |

---

## Performance Metrics

| Metric | Value |
|---|---|
| Phases planned | 9 |
| Phases complete | 7 (0–6, all UAT-verified) |
| Requirements mapped | 26/26 |
| Plans complete | 52 of 52 across phases 0–6 |
| Last activity | 2026-08-11 |

---
| Phase 00 P05 | 10 | 3 tasks | 4 files |
| Phase 02 P04 | 7 | 2 tasks | 5 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 04 P01 | 25min | 6 tasks | 6 files |
| Phase 04 P02 | 21min | 4 tasks | 4 files |
| Phase 04 P03 | 20min | 5 tasks | 5 files |
| Phase 04 P04 | 25min | 3 tasks | 2 files |
| Phase 04-movements P05 | 25min | 3 tasks | 4 files |
| Phase 04 P06 | 5min | 3 tasks | 4 files |
| Phase 04 P07 | 8min | 3 tasks | 3 files |
| Phase 05 P15 | 30min | 2 tasks | 4 files |

## Accumulated Context

### Key Decisions Made During Roadmap

- **Phase 0 is infrastructure-only** (no requirement IDs). It is the prerequisite for every other phase per research/SUMMARY.md.
- **ANIM-03 (ficha consolidada) deferred to Phase 8** because it cross-cuts reproductive (Phase 5) and sanitary (Phase 6). Earlier phases deliver partial views; Phase 8 finalizes.
- **Risk-retirement prototypes (numbering RPC, snapshot JSONB, ATF partial unique index) live in Phase 2** even though only PROP-01/PROP-02 are formally consumed there. This validates technical risk before larger phases depend on them.
- **Phases 5, 6, 7 are parallelizable** once their prerequisites are met (3 for 5/6, 2 for 7).
- **Granularity calibrated to 9 phases** per `fine` setting (target 8–12). Each phase delivers a coherent, verifiable capability.

### Open Decisions Needed Before Phase 1 Coding

From research/SUMMARY.md — must be resolved with stakeholder (~30 min):

1. Animal numbering scope — global per propriedade vs (propriedade + categoria)
2. Number reusable after soft delete — recommended NO
3. LoteATF closure mode — manual with alert when all DGs filled
4. Sanitary application default — all lot animals pre-selected, individual deselection allowed
5. Auth method — email/password only for MVP
6. Supabase plan — free vs pro (verify pg_cron / Realtime availability)

### Active TODOs

- Resolve 6 open decisions before starting Phase 1 implementation
- Confirm with veterinarian domain expert before Phase 5/6 (DG math, UA validation)

### Phase 0 Completion Notes

- **`[analytics] enabled = false`** in `supabase/config.toml` — Docker socket unreachable from `supabase_vector` container on Windows WSL2. Safe for local dev.
- **`integration_test` no web support** — SC-1 verified manually via `flutter run -d edge`. Use `-d windows` for automated integration tests.
- **Riverpod 3.x** (upgraded from planned 2.x) — all future phases must use Riverpod 3.x / codegen 4.x APIs.
- **custom_lint / riverpod_lint deferred** — incompatible with flutter_riverpod 3.x + freezed_annotation 3.x stack.

### Blockers

- ~~Phase 5 schema push~~ **RESOLVED 2026-08-04.** Both Phase 5 migrations (`20260804_05_reproductive_module`, `20260805_05_atf_rpcs`) applied to cloud project `wrdwzychjhlpwpivfhhq` via MCP `apply_migration` — the CLI is authenticated but unlinked with no TTY for a DB password, same as Phase 4. Ledger now at 10 migrations. All objects verified by catalog query: 2 tables, `animal_atf_memberships.property_id` + 2 named FKs, `animal_atf_memberships_active_idx` preserved, 3 enabled triggers, 5 RPCs granted to `authenticated`, 4 SELECT-only RLS policies, and zero write policies on `dg_records`/`animal_atf_memberships` (D-21 holds).
- ~~CR-01: baixa aborted for any animal in an active ATF~~ **RESOLVED 2026-08-04.** Code review caught it; `trg_atf_membership_valid` was unscoped (`BEFORE INSERT OR UPDATE`), so the D-19 baixa chain re-validated an animal it had just archived and rolled the transaction back. Corrective migrations `20260806_05_fix_atf_membership_trigger_scope` (CR-01) and `20260807_05_fix_remove_animal_from_atf_notfound` (WR-02) applied to live and verified via `pg_get_triggerdef`/`tgattr`. Ledger now at 12 migrations. The originals were left untouched — forward-only corrections, no dev/prod drift.
- ~~CR-01: `register_baixa` replaced instead of appending the baixa observation; WR-02: `add_animals_to_atf` payload duplicate uuid raised 23505~~ **RESOLVED 2026-08-05.** Corrective migration `20260808_05_fix_baixa_observation_and_atf_dedup` applied to live and verified: both function bodies read back correct (CASE-append, SELECT DISTINCT), SQL round-trip proved the append/no-op/dedup behavior transactionally (rolled back, zero leftover rows). Ledger now at 13 migrations.
- ~~WR-01 (05-REVIEW.md #2): `register_baixa` silently accepted `p_reason IS NULL` / `p_date IS NULL` (SQL `NOT IN` on NULL is NULL, not TRUE)~~ **RESOLVED 2026-08-05.** Corrective migration `20260809_05_fix_register_baixa_null_guards` applied to live and verified via a transactional round-trip (both NULL cases now raise `22023`). Ledger now at 14 migrations.
- ~~`05_reproductive_test.sql` unrun~~ **RESOLVED 2026-08-06.** No local Docker stack (`docker info`/`supabase status` fail), so `supabase test db` still can't start — but the suite's 371 lines were run verbatim (BEGIN...ROLLBACK) against live PROD `wrdwzychjhlpwpivfhhq` via MCP `execute_sql`, confirmed during Phase 5's final UAT re-run. 34/35 assertions passed; the 1 failure is a pre-existing 3-arg `has_index()` overload-ambiguity bug in the TEST FILE itself (confirmed via direct `pg_indexes` read that the real index is correct), not a schema defect.
- ~~`04_movements_test.sql` still unrun~~ **RESOLVED 2026-08-07** (Phase 6, plan 06-12, D-42). Replayed verbatim against live PROD `wrdwzychjhlpwpivfhhq` via MCP `execute_sql` in a rolled-back transaction: **5/5 assertions pass**, no fixture rows left behind. Both cross-property guards hold with RLS out of the picture — `trg_animals_lot_same_property` (SC-4) and `trg_lots_paddock_same_property` (MOV-02). A genuine pass, no assertion weakened. Docker is still down, so `supabase test db` remains unavailable; the MCP replay is the standing workaround.
- **Phase 6 migrations applied 2026-08-07.** `20260810_06_sanitary_module` and `20260811_06_sanitary_rpcs` applied to live PROD via MCP `apply_migration` (CLI authenticated but unlinked, no TTY for a DB password — same path as Phases 3–5). **Migration ledger now at 16.** Preflight confirmed `sanitary_applications` held 0 rows, so the ALTER-only NOT NULL extension needed no backfill. Catalog verification passed 14/14: `doses`, `properties.kg_per_ua`, `animal_ua_weight()`, both SECURITY DEFINER RPCs, 18 new header columns, the partial reversal unique index, the GIN `jsonb_path_ops` index, `trg_sanitary_applications_same_property`, and Phase 2's `trg_snapshot_immutable` still intact. RLS as designed: 1 SELECT-only policy on `sanitary_applications` with **zero** write policies; 3 on `doses` with no DELETE.
- **`06_sanitary_test.sql`: 81 assertions, 80 pass** (2026-08-07, post-gap-closure replay — supersedes the earlier 74/74 record, which predates Group 12's restore-regression assertions). The 1 failure is environmental, not a schema defect: Group 8's `count(*) FROM sanitary_applications = 2` assumes an empty database, but PROD now holds 2 real UAT rows created during Phase 6 UAT; it is the suite's only assertion scoped to global table state instead of fixture ids. All 6 Group 12 assertions green. Earlier test-file defect (`ec5519b`, `like` vs `alike`) documented in the suite header.
- **G-06-2 closed 2026-08-07.** Corrective migration `20260812_06_fix_dose_update_policy` applied to live PROD via MCP `apply_migration` — **migration ledger now at 17**. Root cause: fix commit `ae08dba` edited the already-applied `20260810_06` file in place, so PROD kept the original doses UPDATE policy with `AND deleted_at IS NULL` in USING (restore/edit of archived doses matched 0 rows, silent no-op). Post-apply catalog read confirms the UPDATE policy is membership + veterinarian only; an RLS round-trip as `authenticated` impersonating the real vet restored the real archived UAT dose with 1 row affected (rolled back). Forward-only correction — `20260810_06` untouched.
- **`anon` can EXECUTE the SECURITY DEFINER RPCs** (all five Phase 5 ones and Phase 4's `move_animal_to_lot`). `REVOKE ALL … FROM public` does not remove Supabase's `ALTER DEFAULT PRIVILEGES` grant to `anon`. Fails closed — `is_member_of()` is false when `auth.uid()` is NULL → `42501` — but leaves a UUID-existence oracle (`23503` vs `42501`) because the row lookup precedes the membership check. Low severity (122-bit v4 UUIDs), pre-existing since Phase 1. Route through `/gsd-secure-phase`.
- **Phase 7 migration applied 2026-08-11.** `20260813_07_expenses_module` applied to live PROD `wrdwzychjhlpwpivfhhq` via MCP `apply_migration` — **migration ledger now at 18.** One file, one transaction, covering the `expenses` table + the `sanitary_applications` paddock freeze + both sanitary RPC replacements (a half-applied state would have left the unified list unable to render sanitary rows). Preflight confirmed not-already-applied and that both live sanitary rows resolved through `lots → paddocks` to paddock "2A", so the backfill could not abort the `SET NOT NULL`. Catalog verification 12/12: RLS enabled **and forced** on `expenses`, 3 policies (SELECT/INSERT/UPDATE) with **zero DELETE policy** (D-22), 2 triggers, 3 indexes; `sanitary_applications.paddock_id`/`paddock_name` NOT NULL with 0 unbackfilled; **`trg_snapshot_immutable` verified re-ENABLED** (`tgenabled='O'`) after the migration's DISABLE→backfill→ENABLE window; both RPCs SECURITY DEFINER, granted to `authenticated`, both writing the frozen paddock.
- **`07_expenses_test.sql`: 42 assertions, 42 pass** (2026-08-11), replayed against live PROD via MCP `execute_sql` in `BEGIN…ROLLBACK` with zero fixture leakage. First run was 41/42: the reader-UPDATE assertion expected `42501`, but **RLS only raises from a failing `WITH CHECK` — a failing `USING` clause silently filters the row instead**. The security property was verified directly (reader UPDATE affects 0 rows, stored amount unchanged, 0 tampered rows) and the assertion replaced with that check (commit `ac03bff`). This is a strengthening, not a weakening: it proves no mutation rather than merely that an error was raised. Worth remembering for every future RLS suite in this project.
- **`gsd-executor` cannot run migration plans.** Plan 07-08 was dispatched to a `gsd-executor` subagent and returned BLOCKED without changing anything: that agent type is registered with a restricted tool list (`Read, Write, Edit, Bash, Grep, Glob, Skill, context7`) that excludes the Supabase MCP tools, and the local Docker/CLI fallback is dead on this machine. It correctly refused to improvise a raw connection to PROD. Tasks 1–2 were run by the orchestrator instead. **This will recur on every future migration plan** — either widen that agent's tool list or mark such plans orchestrator-owned at plan time.
- **Phase 7 planning gap:** plan 07-04 had to modify `lib/features/sanitario/data/sanitary_application_model.dart` to add the required `paddockId`/`paddockName` fields, but **no Phase 7 plan listed that file in `files_modified`**. Necessary (07-01 made those columns NOT NULL, so the Dart model could not compile without them) and correctly recorded as a Rule 2 deviation — but it means the plan set had a coverage hole that the plan-checker did not catch.
- **Supabase Auth URL config not set for the deployed origin.** Project `wrdwzychjhlpwpivfhhq` still has Site URL at `http://localhost:3000`, so signup confirmation emails link to localhost. The `emailRedirectTo` client fix (quick task 260804-fpk, F-04-02) is inert until a human sets Site URL + allowed redirect URLs to `https://campo-gestor.pages.dev` in the dashboard.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260804-fpk | Fix 4 cross-phase UAT findings from Phase 4 session (auth signup + lotes UI) | 2026-08-04 | 97dd9e3 | [260804-fpk-fix-4-cross-phase-uat-findings-from-phas](./quick/260804-fpk-fix-4-cross-phase-uat-findings-from-phas/) |
| 260805-3mr | Show animal.observation on the ficha (AnimalInfoCard) — was write-only since capture, incl. CR-01 baixa-appended notes | 2026-08-05 | 51f50b2 | [260805-3mr-add-a-display-for-the-animal-s-observati](./quick/260805-3mr-add-a-display-for-the-animal-s-observati/) |
| 260810-dpl | Deploy script (`tool/deploy.dart`) — reads dart-defines from gitignored .vscode/launch.json, runs flutter build web + wrangler pages deploy | 2026-08-10 | — | (no dir — inline task) |

---

## Session Continuity

**Stopped at:** Phase 07 complete — 8/8 plans, migration live, UAT 7/7, verification passed
**Resume file:** .planning/phases/07-expenses-by-paddock/07-VERIFICATION.md

**Last session:** 2026-08-11T13:07:39.267Z
**Next action:** UAT humano da Fase 6 — todo o código está em master, as 2 migrations estão aplicadas em PROD, 259 testes Dart e 74+5 asserções pgTAP verdes. Falta você exercitar o fluxo no app: cadastrar dose, registrar aplicação em um lote, conferir o snapshot congelado, estornar, e ver o histórico na ficha de um animal movido de lote. Dois itens antigos seguem abertos, nenhum bloqueando: (1) Site URL + redirect URLs do projeto `wrdwzychjhlpwpivfhhq` ainda apontam para localhost; (2) as 4 correções do quick task 260804-fpk nunca foram confirmadas no browser.
**Files of interest:**

- `.planning/PROJECT.md` — vision and constraints
- `.planning/REQUIREMENTS.md` — 26 v1 requirements with traceability
- `.planning/ROADMAP.md` — 9-phase plan with success criteria
- `.planning/research/SUMMARY.md` — stack, build order, pitfalls

---

## Notes

- Project is Flutter web-first + Supabase. All multi-tenant isolation via RLS. Atomic operations via PL/pgSQL RPCs.
- Two independent lot types: Lote (operacional) and LoteATF (reprodutivo). Different tables, never enum-merged.
- Snapshot sanitário is immutable post-INSERT — enforced by trigger + RLS.
- Animal número único per propriedade (exact key tuple to be confirmed by Open Decision #1).

## Decisions

- [Phase 04]: 04-01: memberPropertiesProvider override (not currentPropertyProvider directly) drives Wave 0 canEdit gate tests, reusing CurrentPropertyNotifier's single-membership auto-select logic
- [Phase 04]: 04-02: loteListByPropertyProvider implemented as a plain (non-family) FutureProvider<List<Lot>> resolving currentPropertyProvider internally, deviating from the plan's family+DTO spec to match the already-committed Wave 0 widget test override contract
- [Phase 04]: 04-03: Task 5 (supabase db push for move_lot_to_paddock RPC) BLOCKED — this session's Supabase CLI is unlinked/unauthenticated, no TTY for a DB password. Migration file authored and verified on disk; manual push required before MOV-02 UAT.
- [Phase 04]: 04-03: _FakeLoteRepository (implements LoteRepository, in test/widget/lote_form_dialog_test.dart) needed stub overrides for fetchLotsWithCountByProperty (04-02) and moveLot (04-03) — flagging as a recurring maintenance tax on LoteRepository's public surface for future plans.
- [Phase 04]: 04-04: move_animal_to_lot RPC closes SC-4 gap (cross-property destination check); moveAnimal rewired with signature preserved; Task 3 DB push BLOCKED (unlinked CLI), mirrors 04-03
- [Phase 04]: 04-05: Closed WR-01..04 + IN-01 gap-closure findings from 04-REVIEW.md (invalidations, mounted guard, pt-BR plural, submit-flow tests) — CR-01 and RPC-live UAT remain owned by 04-04
- [Phase 04]: 04-06: Closed reopened CR-01 (04-REVIEW.md) with a trigger, not an RLS WITH CHECK tightening — access-path-independent, protects INSERT too, matches existing snapshot-immutability idiom; also closed WR-01 TOCTOU; MOV-02's identical lots.paddock_id bypass explicitly deferred (plan-locked scope: animals only); Task 3 DB push BLOCKED (unlinked CLI), now covers 3 migrations
- [Phase 04]: 04-07: Closed WR-02/CR-01-parallel (04-REVIEW.md) with trg_lots_paddock_same_property, mirroring the 04-06 animals trigger onto lots.paddock_id (MOV-02); scope reversal (accept->mitigate, T-4-08) per explicit user decision 2026-07-16; Task 3 DB push BLOCKED (unlinked CLI), now covers 4 migrations
- [Phase 07]: plan-phase 2026-08-11 — D-37 ("4 planos em 3 waves") deviated to **8 plans in 5 waves** with explicit user re-approval. Intent preserved (parallel W1 of DB + Dart data, UI in the middle, dedicated blocking apply/UAT plan last); split was for context cost only, zero scope reduction — decision-coverage gate reads 37/37. Do not re-flag this as a dropped decision at verify time.
- [Phase 07]: plan-phase 2026-08-11 — plan-checker BLOCKER "missing prohibitions block in 07-02" dismissed as a false positive: the unresolved edge-probe rows are surfaced in 07-02's `<planner_assumptions>` (edge probe ≠ prohibitions); the recalled prohibitions live descriptor-less in `must_haves.prohibitions:` across 07-01/03/04/05/06/07.
- [Phase 07]: plan-phase 2026-08-11 — D-35 (no receipt attachment / no Supabase Storage this phase) was uncovered by the decision-coverage gate because it is a negative decision; authored as a descriptor-less scope-fence prohibition in 07-05's `must_haves.prohibitions:` rather than tagged `[informational]`, so the executor sees the fence.
- [Phase 07]: plan-phase 2026-08-11 — "Ano" period preset confirmed as **calendar year** (Jan 1 → today), not rolling 12 months (RESEARCH A2 was open).
- [Phase 05]: 05-15: closed G-05-2/G-05-3 (AtfDetailScreen rendering/gating gaps) — added AtfMembershipView.animalDeleted from a new deleted_at select column, and hoisted a single dgAnimalIds/pendingMembers derivation shared by the encerrar banner, its AppBar action, its dialog, and the composition remove-gate; dg_summary.dart left untouched per explicit user decision
