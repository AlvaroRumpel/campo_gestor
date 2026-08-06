---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 6 — Sanitary Module (Snapshot)
current_plan: Not started
status: in-progress
stopped_at: Phase 6 context gathered
last_updated: "2026-08-06T20:48:15.943Z"
last_activity: 2026-08-06
progress:
  total_phases: 7
  completed_phases: 6
  total_plans: 38
  completed_plans: 38
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo
**Current phase:** 6 — Sanitary Module (Snapshot)
**Current plan:** Not started
**Progress:** [██████████] 100%

---

## Phase Status

| # | Phase | Status |
|---|---|---|
| 0 | Foundation | complete (6/6 plans) |
| 1 | Auth & Multi-tenancy Core | complete (UAT 4/4 — 2026-05-07) |
| 2 | Property & Paddock Structure | complete (UAT 9/10 — 2026-05-08) |
| 3 | Lots & Animals (Operational Core) | complete |
| 4 | Movements | complete (7/7 plans, UAT 8/8 — 2026-08-04) |
| 5 | Reproductive Module (LoteATF) | not-started |
| 6 | Sanitary Module (Snapshot) | not-started |
| 7 | Expenses by Paddock | not-started |
| 8 | Animal Dossier Consolidation | not-started |

---

## Performance Metrics

| Metric | Value |
|---|---|
| Phases planned | 9 |
| Phases complete | 5 (0–4) |
| Requirements mapped | 26/26 |
| Plans complete | 6 (00-01 through 00-06) |
| Last activity | 2026-08-06 |

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
- **`04_movements_test.sql` still unrun** — same Docker blocker, no live-PROD run attempted yet for this suite. Run `supabase test db` once Docker is available, or repeat the MCP `execute_sql` workaround; a failure is a real migration defect, not an assertion to weaken.
- **`anon` can EXECUTE the SECURITY DEFINER RPCs** (all five Phase 5 ones and Phase 4's `move_animal_to_lot`). `REVOKE ALL … FROM public` does not remove Supabase's `ALTER DEFAULT PRIVILEGES` grant to `anon`. Fails closed — `is_member_of()` is false when `auth.uid()` is NULL → `42501` — but leaves a UUID-existence oracle (`23503` vs `42501`) because the row lookup precedes the membership check. Low severity (122-bit v4 UUIDs), pre-existing since Phase 1. Route through `/gsd-secure-phase`.
- **Supabase Auth URL config not set for the deployed origin.** Project `wrdwzychjhlpwpivfhhq` still has Site URL at `http://localhost:3000`, so signup confirmation emails link to localhost. The `emailRedirectTo` client fix (quick task 260804-fpk, F-04-02) is inert until a human sets Site URL + allowed redirect URLs to `https://campo-gestor.pages.dev` in the dashboard.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260804-fpk | Fix 4 cross-phase UAT findings from Phase 4 session (auth signup + lotes UI) | 2026-08-04 | 97dd9e3 | [260804-fpk-fix-4-cross-phase-uat-findings-from-phas](./quick/260804-fpk-fix-4-cross-phase-uat-findings-from-phas/) |
| 260805-3mr | Show animal.observation on the ficha (AnimalInfoCard) — was write-only since capture, incl. CR-01 baixa-appended notes | 2026-08-05 | 51f50b2 | [260805-3mr-add-a-display-for-the-animal-s-observati](./quick/260805-3mr-add-a-display-for-the-animal-s-observati/) |

---

## Session Continuity

**Stopped at:** Phase 6 context gathered
**Resume file:** .planning/phases/06-sanitary-module-snapshot/06-CONTEXT.md

**Last session:** 2026-08-06T20:48:15.917Z
**Next action:** `/gsd-discuss-phase 5` — Phase 5 (Reproductive Module / LoteATF) has no CONTEXT.md yet. Two items carried over, neither blocking Phase 5: (1) the Supabase dashboard for project `wrdwzychjhlpwpivfhhq` still needs Site URL + allowed redirect URLs set to `https://campo-gestor.pages.dev`, otherwise signup confirmation emails stay on localhost; (2) the 4 fixes from quick task 260804-fpk are green on 103/103 tests but were never confirmed live in the browser.
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
- [Phase 05]: 05-15: closed G-05-2/G-05-3 (AtfDetailScreen rendering/gating gaps) — added AtfMembershipView.animalDeleted from a new deleted_at select column, and hoisted a single dgAnimalIds/pendingMembers derivation shared by the encerrar banner, its AppBar action, its dialog, and the composition remove-gate; dg_summary.dart left untouched per explicit user decision
