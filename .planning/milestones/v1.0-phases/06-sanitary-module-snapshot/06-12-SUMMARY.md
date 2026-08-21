---
plan: 06-12
phase: 06
status: complete
tasks_completed: 3
date: 2026-08-07
---

# 06-12 — Apply migrations, replay pgTAP, record results

Blocking plan. Executed by the orchestrator rather than a `gsd-executor` subagent:
the executor persona reached its checkpoint blocked, having correctly diagnosed that
its restricted `tools:` frontmatter strips the whole MCP surface, so
`mcp__supabase__apply_migration` / `execute_sql` were not callable from it
(anthropics/claude-code#13898). It offered two unblock paths and — correctly — did not
attempt any credential workaround. The orchestrator holds those MCP tools, so it took
over Tasks 1–3 directly. No password was needed or requested.

## Task 1 — migrations applied to live PROD

Preflight (read-only) before any DDL:

| Check | Result |
|-------|--------|
| `sanitary_applications` row count | **0** — ALTER-only NOT NULL extension needs no backfill |
| `doses` / `kg_per_ua` / `animal_ua_weight` / both RPCs pre-exist? | none — no partial prior application |
| Migration ledger | 14 entries, neither Phase 6 migration present |

Applied via MCP `apply_migration` (CLI authenticated but unlinked, no TTY for a DB
password — the standing path since Phase 3):

- `20260810_06_sanitary_module`
- `20260811_06_sanitary_rpcs`

**Ledger now at 16.** Catalog verification passed 14/14 checks: `doses` table,
`properties.kg_per_ua`, `animal_ua_weight()`, both SECURITY DEFINER RPCs, all 18 new
header columns, the reversal unique index *with* its partial `WHERE` predicate, the GIN
index *with* `jsonb_path_ops`, `trg_sanitary_applications_same_property` enabled, and
Phase 2's `trg_snapshot_immutable` still present and enabled — confirming the ALTER-only
approach preserved it. RLS exactly as designed: **1 SELECT-only policy and 0 write
policies** on `sanitary_applications`; 3 policies on `doses` with no DELETE.

## Task 2 — both pgTAP suites replayed

Each replayed verbatim against live PROD inside a rolled-back transaction. `execute_sql`
returns only the last result set, so the trailing `SELECT * FROM finish(); ROLLBACK;` was
swapped for `SELECT _get('curr_test'), num_failed(); ROLLBACK;` to surface the counts.

| Suite | Result |
|-------|--------|
| `06_sanitary_test.sql` | **74/74 pass** |
| `04_movements_test.sql` | **5/5 pass** — closes the D-42 blocker open since Phase 4 |

**One test-file defect found and fixed** (`ec5519b`), not a schema defect: the Phase 6
suite called `like(...)`, but pgTAP names its pattern-match assertion `alike(...)`.
`pg_catalog` carries only `like(text,text)` as the 2-arg operator function, so the two
3-arg calls raised `42883` and aborted the entire run *before* `finish()` — hiding all 74
results rather than reporting a failed assertion. Verified against `pg_proc` on this
project (pgtap 1.3.3): `public.alike` exists at 2 and 3 args, `public.like` at none. After
the rename the suite runs green from disk with no in-memory substitution.

This is the **second** pgTAP overload trap on this project, after Phase 5's 3-arg
`has_index()` ambiguity. Both are now documented in the suite headers so a third suite
does not rediscover them.

Database left clean — post-hoc reads confirm zero fixture rows in `properties`,
`animals`, `doses`, `sanitary_applications`.

## Task 3 — STATE.md

Records the ledger count, both suite results, and the D-42 resolution. Also corrected
pre-existing drift in the `## Phase Status` table, which still listed Phase 5 as
`not-started` despite its completion the previous day.

## Orchestrator fixes folded in during this phase

Three defects surfaced at wave boundaries, none attributable to a single plan:

| Commit | What |
|--------|------|
| `6ee3d02` | Phase 5 test asserted `exam_date` against a UTC-derived date while the app deliberately formats local (WR-03) — failed only between 21:00 and midnight in America/Sao_Paulo. Latent since Phase 5. |
| `3fa75b4` | E7 composition-scroll backstop had no evidence; plan 06-05 built the screen but left the `verification: backstop` truth unprovable, which would have abstained to `human_needed`. |
| `44970b5` | The D-24 success SnackBar was structurally unreachable from `SanitarioScreen`'s FAB after the wave-5 merge, and both call sites hardcoded the plural (`"1 animais"`). Lifted into a shared `sanitaryRegisteredMessage()`. |

Also: `06-PATTERNS.md` had never been committed during plan-phase, so wave-1 worktrees
forked without it (`64e25ae`).

## Verification

- Dart suite: **259/259**; `flutter analyze`: 4 pre-existing unrelated issues only
- pgTAP: 74/74 + 5/5 against the live schema
- Both phase backstops (E4, E7) now carry explicit test evidence — neither will abstain

## Still open (not blocking, carried forward)

- `anon` can EXECUTE the SECURITY DEFINER RPCs — pre-existing since Phase 1, fails closed,
  leaves a UUID-existence oracle. Deliberately not "fixed" locally here; route through
  `/gsd-secure-phase`.
- Supabase Auth Site URL / redirect URLs still point at localhost.
- `kgPerUa` is resolved by joining `currentPropertyProvider` against `propertyListProvider`
  in three separate widgets — candidate for a dedicated provider.

## Human UAT

Not self-approved. Surfaced to the user as a checkpoint.
