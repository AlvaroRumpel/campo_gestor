---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 04
current_plan: 5 of 5 (all plans code-complete, incl. 04-05 gap closure; DB push for both Phase-4 migrations BLOCKED pending manual credentials)
status: in-progress
stopped_at: "Completed 04-05-PLAN.md (gap closure: WR-01..04 + IN-01 dialog fixes/tests)"
last_updated: "2026-07-16T12:21:26.182Z"
last_activity: 2026-07-16
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 21
  completed_plans: 21
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo
**Current phase:** 04
**Current plan:** 5 of 5 (all plans code-complete, incl. 04-05 gap closure; DB push for both Phase-4 migrations BLOCKED pending manual credentials)
**Progress:** [██████████] 100%

---

## Phase Status

| # | Phase | Status |
|---|---|---|
| 0 | Foundation | complete (6/6 plans) |
| 1 | Auth & Multi-tenancy Core | complete (UAT 4/4 — 2026-05-07) |
| 2 | Property & Paddock Structure | complete (UAT 9/10 — 2026-05-08) |
| 3 | Lots & Animals (Operational Core) | complete |
| 4 | Movements | plans complete (5/5, incl. SC-4 + WR-01..04/IN-01 gap closure) — verification pending (DB push for both migrations BLOCKED) |
| 5 | Reproductive Module (LoteATF) | not-started |
| 6 | Sanitary Module (Snapshot) | not-started |
| 7 | Expenses by Paddock | not-started |
| 8 | Animal Dossier Consolidation | not-started |

---

## Performance Metrics

| Metric | Value |
|---|---|
| Phases planned | 9 |
| Phases complete | 0 |
| Requirements mapped | 26/26 |
| Plans complete | 6 (00-01 through 00-06) |
| Last activity | 2026-07-16 |

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

- **Phase 4 UAT blocked on manual Supabase schema push (now covers TWO migrations).** `supabase/migrations/20260519_04_movements.sql` (move_lot_to_paddock RPC, MOV-02) and `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` (move_animal_to_lot RPC, MOV-01/ROADMAP SC-4) are both authored and verified on disk but NOT applied to the dev Supabase project — this execution session's Supabase CLI is unlinked/unauthenticated (`supabase db push --dry-run` → "Cannot find project ref. Have you run supabase link?"), reconfirmed in 04-04. A human must run `supabase link --project-ref <dev-project-ref>` (if needed) then `supabase db push` from a machine with dev credentials — applying both migrations together — before `/gsd-verify-work` can exercise the live RPC paths for MOV-01 or MOV-02.

---

## Session Continuity

**Stopped at:** Completed 04-05-PLAN.md (gap closure: WR-01..04 + IN-01 dialog fixes/tests)
**Resume file:** None

**Last session:** 2026-07-16T04:35:46.906Z
**Next action:** Manual: run `supabase link` (if needed) + `supabase db push` from a machine with dev Supabase credentials (applies both `20260519_04_movements.sql` and `20260715_04_gap_move_animal_to_lot.sql`), then run `/gsd-verify-work` for Phase 4 (Movements) — all 5 plans (04-01 through 04-05) are code-complete.
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
