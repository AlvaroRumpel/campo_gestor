---
phase: 7
slug: expenses-by-paddock
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-11
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `07-RESEARCH.md` § Validation Architecture. The Per-Task Verification Map is
> populated by `/gsd-validate-phase` once PLAN.md task IDs exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (unit + widget, bundled with SDK); pgTAP 1.3.3 |
| **Config file** | none dedicated — no `dart_test.yaml`; tests run per-file via `flutter test <path>`, matching every prior phase |
| **Quick run command** | `flutter test test/features/gastos/` |
| **Full suite command** | `flutter test` + MCP `execute_sql` replay of `supabase/tests/07_expenses_test.sql` inside `BEGIN … ROLLBACK` |
| **Estimated runtime** | ~15 s (feature-scoped) / ~90 s (full Dart suite, 259+ tests) |

**Environment constraint:** local Docker / Supabase CLI stack is unavailable on this machine
(`docker info` and `supabase status` both fail), so `supabase test db` cannot run. The standing
workaround — established in Phases 4, 5 and 6 — is to replay the pgTAP suite verbatim against live
PROD `wrdwzychjhlpwpivfhhq` via MCP `execute_sql` in a rolled-back transaction.

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/gastos/`
- **After every plan wave:** Run `flutter test` (full Dart suite)
- **Before `/gsd-verify-work`:** Full Dart suite green **and** `07_expenses_test.sql` replayed with 0 failures
- **Max feedback latency:** 15 seconds (feature-scoped run)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _pending_ | — | — | GAST-01 | — | — | — | — | — | ⬜ pending |

*Populated by `/gsd-validate-phase` after PLAN.md files are written. Requirement→test coverage is
already fixed by the map below; only the task-ID binding is outstanding.*

**Requirement → test coverage (from RESEARCH.md):**

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| GAST-01 | Lançar gasto com categoria/valor/data/descrição + validação de campos obrigatórios | widget | `flutter test test/features/gastos/expense_form_dialog_test.dart` | ❌ W0 |
| GAST-01 | RLS: `reader` não pode INSERT; `owner`/`veterinarian` podem | pgTAP | replay `supabase/tests/07_expenses_test.sql` | ❌ W0 |
| GAST-01 | Trigger: `paddock_id` de outra propriedade é rejeitado | pgTAP | same suite | ❌ W0 |
| GAST-02 | Total agregado sobre lista mista (manual + sanitário); custo sanitário NULL conta como 0 e entra no N | unit | `flutter test test/features/gastos/expense_calculations_test.dart` | ❌ W0 |
| GAST-02 | Filtros de período e categoria combináveis produzem o subconjunto correto | unit | same file | ❌ W0 |
| GAST-02 | `SELECT` liberado a `reader` | pgTAP | same suite | ❌ W0 |
| D-23 | `canManageExpenses`: owner ✓, veterinarian ✓, reader ✗ | widget/unit | `flutter test test/features/gastos/role_gates_test.dart` | ❌ W0 |
| D-30/D-31 | Backfilled rows carry `paddock_id`/`paddock_name`; RPC-registered rows populate both NOT NULL | pgTAP + catalog read | same suite + post-apply `SELECT` via MCP | ❌ W0 |

---

## Wave 0 Requirements

- [ ] `test/features/gastos/` — directory does not exist yet
- [ ] `test/features/gastos/expense_calculations_test.dart` — pure-function total/filter tests
- [ ] `test/features/gastos/expense_form_dialog_test.dart` — widget test (mirror the existing
      `test/features/sanitario/` equivalent before authoring from scratch)
- [ ] `test/features/gastos/role_gates_test.dart` — first non-`_canEdit` role gate in the project (D-23)
- [ ] `supabase/tests/07_expenses_test.sql` — new pgTAP suite, authored against not-yet-applied
      schema (deliberate red state, same D-39/D-41 precedent as `06_sanitary_test.sql`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration applied to live PROD | GAST-01 | No local Docker stack; `apply_migration` runs against the live project and is not replayable in a test transaction | After apply, catalog-verify via MCP: `expenses` table + `property_id`/`paddock_id` FKs, isolation trigger, RLS policy set, and `SELECT paddock_id, paddock_name FROM sanitary_applications` returning non-null on the 2 pre-existing rows |
| Date-range picker + total refresh on the real web build | GAST-02 | `showDateRangePicker` interaction and live aggregate refresh are not covered by widget tests at the integration level | `flutter run -d edge` → paddock detail → Gastos → change range → confirm the header total and the row count both change |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
