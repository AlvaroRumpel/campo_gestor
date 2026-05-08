---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 02
current_plan: —
status: unknown
last_updated: "2026-05-08T08:03:43.710Z"
progress:
  total_phases: 9
  completed_phases: 2
  total_plans: 14
  completed_plans: 9
  percent: 64
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo
**Current phase:** 02
**Current plan:** —
**Progress:** [██████████████████████] Phase 0–1 complete (2/9 phases)

---

## Phase Status

| # | Phase | Status |
|---|---|---|
| 0 | Foundation | complete (6/6 plans) |
| 1 | Auth & Multi-tenancy Core | complete (UAT 4/4 — 2026-05-07) |
| 2 | Property & Paddock Structure | not-started |
| 3 | Lots & Animals (Operational Core) | not-started |
| 4 | Movements | not-started |
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
| Last activity | 2026-05-03 (00-06 bootstrap + supabase init) |

---
| Phase 00 P05 | 10 | 3 tasks | 4 files |

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

None.

---

## Session Continuity

**Last session:** 2026-05-07T19:13:38.950Z
**Next action:** Plan and execute Phase 1 (Auth & Multi-tenancy Core) — resolve 6 open decisions first
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
