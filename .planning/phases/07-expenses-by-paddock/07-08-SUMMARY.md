---
phase: 07-expenses-by-paddock
plan: 08
status: checkpoint
tasks_complete: 2
tasks_total: 3
completed: 2026-08-11
---

# 07-08 — Apply migration to PROD, verify, replay pgTAP

**Status: Tasks 1–2 COMPLETE. Task 3 (human UAT) is an open blocking checkpoint.**

## Execution note — who ran this

The plan was first dispatched to a `gsd-executor` subagent, which returned **BLOCKED** without
making any change. Cause: the `gsd-executor` agent type is registered with a restricted tool list
(`Read, Write, Edit, Bash, Grep, Glob, Skill, context7`) that does **not** include the Supabase MCP
tools, and the local Docker/CLI fallback is unavailable on this machine. It correctly refused to
improvise a raw connection to a live database rather than hand-rolling an unauthorized path — the
right call.

Tasks 1 and 2 were therefore executed by the orchestrator, which does hold the Supabase MCP tools.
This is a documented deviation from "executors execute": the assigned agent type structurally could
not perform the work.

**Action item for future phases:** any plan whose tasks require Supabase MCP must either be run by
an agent type that carries those tools, or be explicitly marked as orchestrator-owned. This will
recur on every migration plan until the `gsd-executor` tool list is widened.

## Task 1 — Apply to live PROD and verify by catalog read ✅

Applied `20260813_07_expenses_module` to project `wrdwzychjhlpwpivfhhq` via MCP `apply_migration`
(one file, one transaction). **Migration ledger 17 → 18.**

Preflight before applying (all as expected — not already applied):

| Check | Value |
|---|---|
| ledger count | 17 |
| `expenses` table exists | no |
| `sanitary_applications.paddock_id` / `paddock_name` present | no |
| `sanitary_applications` row count | 2 (real Phase 6 UAT rows) |
| `trg_snapshot_immutable` state | `O` (enabled) |

Additional preflight not required by the plan: confirmed both existing sanitary rows resolve
through `lots → paddocks` to paddock **"2A"**, so the backfill would cover them and the subsequent
`SET NOT NULL` could not abort the migration.

Post-apply catalog verification — 12/12:

| Check | Result |
|---|---|
| ledger count | 18 ✅ |
| **`trg_snapshot_immutable` re-enabled** | `O` ✅ (the critical one — the migration disables it around the backfill) |
| sanitary rows | 2, **0 unbackfilled** ✅ |
| backfilled `paddock_name` values | `2A` ✅ |
| `paddock_id` / `paddock_name` NOT NULL | both ✅ |
| `expenses` table exists | ✅ |
| `expenses` RLS enabled / forced | `true` / `true` ✅ |
| `expenses` policy count | 3 ✅ |
| `expenses` policy commands | `INSERT, SELECT, UPDATE` — **no DELETE** ✅ (D-22) |
| `expenses` triggers | 2 ✅ |
| `expenses` indexes | 3 (PK + 2 explicit) ✅ |
| `register_sanitary_application` / `reverse_sanitary_application` | both replaced, both write `paddock_id`+`paddock_name`, both still `SECURITY DEFINER`, both `EXECUTE` to `authenticated` ✅ |

## Task 2 — Replay pgTAP + full Dart suite ✅

`07_expenses_test.sql` replayed against live PROD via MCP `execute_sql` inside `BEGIN … ROLLBACK`.

**First run: 41/42.** One genuine failure, isolated by re-running with per-assertion capture:

> `not ok 9 - a reader-role member cannot UPDATE an expense (D-23)` — caught: no exception, wanted: `42501`

### Root cause — test defect, not a schema defect

RLS raises `42501` only from a failing **`WITH CHECK`**. A failing **`USING`** clause instead
*filters the row out*, so the statement matches 0 rows and returns without error. The reader INSERT
assertion passes precisely because INSERT is gated by `WITH CHECK`; the reader UPDATE is gated by
`USING`, so `throws_ok('42501')` was the wrong expectation for that path.

The security property was verified directly and **holds**:

| Probe (as the reader role) | Result |
|---|---|
| rows the reader's UPDATE actually modified | **0** |
| stored `amount` after the attempt | `250.00` (unchanged) |
| rows tampered to `999.00` | **0** |

### Fix applied

Replaced the assertion in `supabase/tests/07_expenses_test.sql` with one asserting the stored
amount is unchanged after the reader's attempt. This is a **stronger** claim than `throws_ok` — it
proves no mutation occurred, where the original only proved an error was raised. Assertion count
stays 42; no assertion was weakened or removed.

**Re-run after fix: 42/42 pass.**

Post-replay leakage check — the rollback left nothing behind: `expenses` 0 rows, 0 leftover test
properties/users/paddocks, `sanitary_applications` still exactly 2 rows, `trg_snapshot_immutable`
still `O`, ledger 18.

Full Dart suite: **305/305 pass.** `flutter analyze lib test` → 4 issues, all pre-existing and
outside Phase 7.

## Task 3 — Human UAT ⏸ OPEN CHECKPOINT

Not executed. `checkpoint:human-verify`, `gate="blocking"` — deliberately not auto-approved.
See the checkpoint block presented to the user for the exact flow to exercise.

## Deviations

1. **Orchestrator-executed instead of subagent-executed** — see "Execution note" above.
2. **`07_expenses_test.sql` modified** — this plan was specified as producing no source files. The
   test-file correction above was necessary to get an honest green; the alternative was recording a
   known-failing assertion against correct schema. Change is to the assertion only.
