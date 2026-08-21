---
phase: 6
slug: sanitary-module-snapshot
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-06
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `06-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Dart unit/widget) + `pgTAP` (SQL) |
| **Config file** | none dedicated — pgTAP suites in `supabase/tests/*.sql`; Dart tests in `test/features/**/*_test.dart` |
| **Quick run command** | `flutter test test/features/sanitario/` |
| **Full suite command** | `flutter test` + `supabase test db` (fallback: MCP `execute_sql` BEGIN/ROLLBACK replay — the established path since Phase 3, CLI not linked) |
| **Estimated runtime** | ~30 seconds (Dart) + ~10 seconds (pgTAP replay) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/sanitario/` (calculation-only per D-40 — fast)
- **After every plan wave:** Run full `flutter test` + the blocking wave's pgTAP replay (D-41)
- **Before `/gsd-verify-work`:** both `06_sanitary_test.sql` AND the outstanding `04_movements_test.sql` (D-42) green
- **Max feedback latency:** 40 seconds

---

## Per-Task Verification Map

Task IDs are filled by the planner; rows below fix the requirement → test-type contract the plans must satisfy.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | SANI-01 | — | N/A | unit | `flutter test test/features/sanitario/dose_calculations_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-02 | T-06-01 (mutation of frozen row) | UPDATE/DELETE on `sanitary_applications` rejected by trigger regardless of access path | pgTAP | `supabase test db` / MCP replay of `06_sanitary_test.sql` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-02 | T-06-02 (client-tampered totals) | `register_sanitary_application` recomputes UA/volume/cost server-side; a tampered client total never persists | pgTAP | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-03 | T-06-03 (stale composition) | Animal removed from lot between load and confirm → whole transaction aborts with mapped ERRCODE, no partial write | pgTAP | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-03 | — | kg→UA conversion, estornada filtering, `applied_at` ordering | unit | `flutter test test/features/sanitario/sanitary_calculations_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-04, SANI-05 | — | GIN containment lookup returns the application for an animal that has since moved lots | pgTAP | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-02 | T-06-04 (role bypass) | Non-veterinarian role rejected inside the SECURITY DEFINER RPC; cross-property caller rejected by `is_member_of()` | pgTAP | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-02 | T-06-05 (double reversal) | Partial unique index blocks a second reversal of the same application; reversal-of-a-reversal blocked | pgTAP | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | SANI-02 | — | Reversal row zero-sums the original: `SUM(animal_count) = 0`, `SUM(total_ua) = 0`, `SUM(total_volume) = 0`, `SUM(total_cost) = 0` across both rows (locked convention, see below) | pgTAP | same suite | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `supabase/tests/06_sanitary_test.sql` — pgTAP suite: immutability trigger, reversal unique index, RLS isolation, RPC role rejection, concurrency abort, GIN containment correctness, reversal zero-sum (D-39)
- [ ] `test/features/sanitario/dose_calculations_test.dart` — kg→UA conversion, `valor_por_ua` formula (D-40)
- [ ] `test/features/sanitario/sanitary_calculations_test.dart` — total UA/volume/cost, estornada filtering, `applied_at` ordering (D-40)
- [ ] No framework install needed — `flutter_test` and the pgTAP MCP-replay pattern are both already established.

---

## Locked Convention (resolved this session — research Assumption A1)

D-28 said "totais negativos" without naming columns. Locked:

- The reversal row negates **all four** header totals: `animal_count`, `total_ua`, `total_volume`, `total_cost`. Rationale: any `SUM()` over the table is then self-correcting — "quantos animais tratados", "quanto gastei" come out right without every future query remembering to exclude reversals.
- `composition_snapshot` is **not** negated (same animals, not a signed quantity) — so a screen reading the array length shows a positive count.
- The reversal row's `applied_at` = `CURRENT_DATE` (when the reversal happened), not the original's date — matches the UI-SPEC "Estornada em" row and D-30 (estorno can occur months later).

This is a testable invariant, not a style choice: the zero-sum pgTAP assertion above is what enforces it.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pre-checked animal list renders all active animals of the lot; deselection updates the live counter | SANI-03 | Widget-level interaction on a real lot; D-40 scopes Dart tests to calculation only | Open a lot with ≥3 active animals → "Registrar aplicação" → confirm all rows pre-checked, uncheck 1, counter drops by 1 and UA recomputes |
| Estorno flow end-to-end, including the "já estornada" race message | SANI-02 | Needs two sessions / live DB state | Register an application, estornar it with a motivo, then attempt a second estorno from a stale screen → "Esta aplicação já foi estornada." + "Ver estorno" link |
| Per-animal history survives a lot move | SANI-05 | Cross-phase (needs Phase 4 movement) | Apply to a lot, move one animal to another lot, open that animal's ficha → the application still lists with the **frozen** lot name |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 40s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
