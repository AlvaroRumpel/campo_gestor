---
phase: 05-reproductive-module-loteatf
verified: 2026-08-05T00:00:00Z
status: gaps_found
score: 7/9 must-haves verified (0 failed); 2 behavior-unverified pending live DB proof
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: "5/5 must-haves structurally verified (0 failed); 2 of 5 ROADMAP success criteria carried a behavior-unverified component"
  gaps_closed:
    - "G-05-1: BaixaDialog now invalidates atfActiveMembershipsProvider/atfMembershipsProvider/atfListByPropertyProvider on a successful baixa (05-11, commit e4a84cd) — regression-tested with a real ProviderContainer that fails if the invalidation lines are removed."
    - "G-05-1-nav: AtfDetailScreen renders a BackButton in all four AppBar states with a context.canPop()/pop() + AppRoutes.reproducao fallback (05-11, commit c9e6303) — tested via a routed GoRouter harness."
  gaps_remaining:
    - "CR-01 (new, 05-REVIEW.md 2026-08-05): register_baixa's UPDATE ... SET observation = COALESCE(p_observation, observation) silently overwrites (not appends to) the animal's general observation field — confirmed still present, unpatched, at supabase/migrations/20260805_05_atf_rpcs.sql:310-314. Not one of the two gaps 05-11 targeted; discovered by a fresh code review after 05-11 landed."
  regressions: []
gaps:
  - truth: "register_baixa does not silently destroy the animal's prior general observation when a baixa observation is entered."
    status: failed
    reason: "CR-01 from 05-REVIEW.md (2026-08-05, fresh code review): COALESCE(p_observation, observation) replaces rather than appends, so any baixa note permanently erases prior general notes (health remarks, body-condition notes) with no confirmation, no merge, and no recovery path since the row becomes archived immediately after. Confirmed still present in the current migration file by direct read of lines 310-314 during this verification."
    artifacts:
      - path: "supabase/migrations/20260805_05_atf_rpcs.sql"
        issue: "Lines 310-314: observation = COALESCE(p_observation, observation) overwrites rather than appends"
      - path: "lib/features/animais/presentation/baixa_dialog.dart"
        issue: "Lines 170-179: field hint text 'Observações adicionais (opcional)' explicitly signals additive behavior the RPC does not provide"
    missing:
      - "A corrective forward-only migration (matching the pattern of 20260806_05_fix_atf_membership_trigger_scope.sql / 20260807_05_fix_remove_animal_from_atf_notfound.sql) that either appends p_observation to the existing value, or gives baixa its own column (e.g. baixa_observation) so it never collides with the general notes field."
human_verification:
  - test: "Run supabase test db (pgTAP, 27 assertions per 05-REVIEW-FIX.md's WR-02 bump) once a local Docker/Supabase stack is available."
    expected: "All assertions pass, proving trg_atf_membership_valid (23514/23503), the partial unique index (23505), dg_records_result_check (22023), D-08/D-16/D-19 state transitions, and the WR-02 remove-nonmember 23503 assertion actually hold against a real Postgres engine."
    why_human: "Still never executed in any session (no Docker on this machine). Unchanged from the previous verification."
  - test: "Re-run the 05-10-PLAN.md Task 3 twelve-step live UAT (blocked at step 9 in 05-UAT.md) now that G-05-1/G-05-1-nav are closed — in particular re-confirm step 9 (baixa on an ATF member) and step 6/7 (header % updates live) end-to-end against the live Supabase project."
    expected: "All twelve steps behave as described; explicit approval or a list of failing steps recorded."
    why_human: "05-UAT.md's own test 1 blocked tests 2-4 pending this exact fix. The fix is now in the code and covered by widget-level regression tests, but no live Supabase round-trip has been observed in this session — widget tests exercise the invalidation call sites against fakes/overrides, not a real database."
  - test: "Confirm with a veterinarian domain expert whether 'most recent DG' should resolve by exam_date instead of created_at (A-DG-ORDER, 05-UAT.md test 4, still [pending])."
    expected: "Either confirmation that created_at is correct, or a one-line change to the tie-breaker."
    why_human: "Open domain question, unchanged since the previous verification. No test can resolve which choice is domain-correct."
---

# Phase 5: Reproductive Module (LoteATF) Verification Report

**Phase Goal:** Usuário gerencia ciclos reprodutivos criando LoteATF, registrando DGs por animal e consultando o histórico reprodutivo de cada animal.
**Verified:** 2026-08-05
**Status:** gaps_found
**Re-verification:** Yes — after gap closure (05-11-PLAN.md / 05-11-SUMMARY.md)

## Goal Achievement

### Gap Closure Verification (05-11 / G-05-1, G-05-1-nav)

| # | Truth (05-11 must_have) | Status | Evidence |
|---|---|---|---|
| GC-1 | After a baixa on an animal in an active ATF, the ATF detail screen's composition no longer lists that animal without an app restart (D-19, G-05-1). | ✓ VERIFIED | `baixa_dialog.dart:99-101` (`_submit()`, success path): `ref.invalidate(atfActiveMembershipsProvider); ref.invalidate(atfMembershipsProvider); ref.invalidate(atfListByPropertyProvider);` — added immediately after the pre-existing `reproductiveHistoryByAnimalProvider` invalidation, before `Navigator.pop`. Regression test `test/widget/baixa_dialog_test.dart` group `"G-05-1: BaixaDialog invalidates ATF composition providers"` uses a real `ProviderContainer` with build counters and asserts each provider rebuilds exactly once after a successful baixa — a load-bearing test (plan's `<done>` explicitly requires reverting the three lines to fail it). Ran directly: `flutter test test/widget/baixa_dialog_test.dart` → 6/6 pass. |
| GC-2 | After a baixa, the Reprodução list's animal count for the affected ATF reflects the removal without an app restart. | ✓ VERIFIED | Same invalidation call covers `atfListByPropertyProvider`; same regression test's third counter (`atfListByPropertyProvider`) asserted to reach 2. |
| GC-3 | The ATF detail screen always shows a back control, in every one of its four AppBar states (G-05-1-nav). | ✓ VERIFIED | `atf_detail_screen.dart`: shared `_backButton(context)` helper wired into `leading:` of all 4 `AppBar` instances (loading line 45, error line 49, null-data line 57, loaded-data line 82). `test/widget/atf_detail_screen_test.dart` group `"back control (G-05-1-nav)"` has one presence assertion per state (4 tests, all pass). |
| GC-4 | Tapping the back control returns to the previous screen when there is history, and lands on /reproducao when reached via context.go with no history. | ✓ VERIFIED (no-history path directly tested; history-pop path is a one-line delegation to go_router's own `context.pop()`) | `_backButton`'s `onPressed` closure: `if (context.canPop()) { context.pop(); return; } context.go(AppRoutes.reproducao);`. Routed test (`_buildRoutedScreen` with a real `GoRouter`) taps the button with no navigation history and asserts landing on the `/reproducao` sentinel screen — passes. The plan deliberately did not add a "pops when history exists" test since that branch is bare `context.pop()`, framework behavior rather than custom logic. |

**Full regression run (this session, not taken from SUMMARY):** `flutter test test/widget/baixa_dialog_test.dart test/widget/atf_detail_screen_test.dart` → 43/43 pass. `flutter test` (full suite) → 210/210 pass. `flutter analyze` → 4 issues, all pre-existing and outside any Phase-5-touched file (2 info in `app_config.dart`/`propriedade_repository.dart`, 2 unused-import warnings in unrelated Phase-3-era test files) — zero issues in `reproducao`/`baixa_dialog.dart`/`atf_detail_screen.dart`. Commits `e4a84cd`, `c9e6303`, `9de0267` all present in `git log`.

**Conclusion: both G-05-1 (blocker) and G-05-1-nav (minor) from 05-UAT.md are genuinely closed at the code level**, with load-bearing regression tests, not just claimed in SUMMARY.md.

### Observable Truths (ROADMAP Success Criteria — carried forward, re-checked for regression)

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|---|---|---|
| SC-1 | Usuário cria LoteATF com nome, data implantação, data inseminação, touro, observação | ✓ VERIFIED | Unchanged from previous verification; not touched by 05-11. `AtfFormDialog` + `atf_batches` schema intact; 7 widget tests still pass (confirmed in this session's full-suite run). |
| SC-2 | Ao adicionar animais, sistema só apresenta vacas/novilhas; rejeita animal já em outro ATF ativo com mensagem clara | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Unchanged. UI half tested and passing. DB half (`trg_atf_membership_valid`) unproven against a live pgTAP run — still no Docker in this session. |
| SC-3 | Usuário registra DG por animal; registros editáveis até encerramento manual | ✓ VERIFIED | Unchanged. `_DgSection` tests still pass (11 tests confirmed in full-suite run, unaffected by 05-11). |
| SC-4 | % prenhez exibido e atualiza automaticamente conforme DGs são registrados | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Unchanged. Formula/UI layer fully unit-tested; live end-to-end recompute against a real Supabase round trip still unproven — this is exactly the re-opened UAT step 6/7. |
| SC-5 | Histórico reprodutivo do animal mostra todos LoteATFs em que participou com resultados de DG | ✓ VERIFIED | Unchanged. `_ReproductiveHistorySection` tests still pass. |

**Score:** 7/9 must-have truths verified (5 ROADMAP SCs + 4 gap-closure truths, minus 2 SCs left behavior-unverified). 0 truths FAILED. One new **blocker-level anti-pattern** (CR-01, below) is what moves this verification's overall status to `gaps_found` — not a failed truth in the must-have sense, but an unresolved data-loss defect in phase-5-authored code that must not be silently passed over.

### New Finding Since Last Verification: CR-01 (register_baixa observation overwrite)

A fresh code review (`05-REVIEW.md`, 2026-08-05, run after 05-11 landed) found one new Critical issue, independent of G-05-1/G-05-1-nav:

**`register_baixa`'s `UPDATE ... SET observation = COALESCE(p_observation, observation)` (supabase/migrations/20260805_05_atf_rpcs.sql:310-314) silently overwrites the animal's entire prior general `observation` value** instead of appending to it, whenever a vet types anything into `BaixaDialog`'s "Observação" field. That field's hint text (`baixa_dialog.dart:175`, "Observações adicionais (opcional)") explicitly promises additive behavior it does not deliver. Since the row is archived (`deleted_at` set) in the same statement, the prior text is not recoverable through the UI afterward.

**Verified directly in this session** (not taken from the review report): read `supabase/migrations/20260805_05_atf_rpcs.sql:310-314` — `COALESCE(p_observation, observation)` is still present, unpatched. No corrective migration for this exists (`ls supabase/migrations/` shows only `20260806_...trigger_scope` and `20260807_...notfound`, both addressing the *prior* review's CR-01/WR-02, not this new finding — confirmed by reading `05-REVIEW-FIX.md`, which fixed the previous review's 4 findings and predates this one).

**Scope note:** this defect does not touch any of the 5 ROADMAP success criteria's literal wording (LoteATF creation, DG registration, % prenhez, reproductive history) — it is a data-integrity bug in the baixa flow, which Phase 5 rewired (`registerBaixa` → `register_baixa` RPC, 05-07) but does not own conceptually (baixa itself is ANIM-04). It is, however, unresolved, confirmed-present, Critical-severity, and lives in a migration file this phase authored (`20260805_05_atf_rpcs.sql`) — silently passing this phase as `human_needed`/`passed` without surfacing it would hide a live data-loss bug. Recorded as a gap rather than deferred, since nothing in the roadmap routes this to a later phase.

### Other Review Findings (not blocking, recorded for completeness)

| ID | Severity | File | Status |
|---|---|---|---|
| WR-01 | Warning | `atf_form_dialog.dart` / `atf_detail_screen.dart` | New (05-REVIEW.md 2026-08-05): ATF header shows the touro's raw UUID instead of a readable label when selected from the dropdown (`bullName` never backfilled). Not part of any ROADMAP SC; UI polish issue, not blocking. |
| WR-02 | Warning | `20260805_05_atf_rpcs.sql:62-64` | New (05-REVIEW.md 2026-08-05): `add_animals_to_atf` doesn't de-duplicate `p_animal_ids`; a client-side duplicate fails the whole batch with a raw 23505. Defensive-coding gap, not currently reachable given `Set`-based client-side selection. |
| IN-01 | Info | repository contract tests | Pre-existing project-wide convention (tautological `isA<Function>()` assertions); explicitly not a regression from this phase. |

### Required Artifacts (delta from previous verification — 05-11 files only; all others unchanged)

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/features/animais/presentation/baixa_dialog.dart` | Invalidates 3 ATF composition provider families on baixa success | ✓ VERIFIED | Confirmed by direct read; `grep -c atfActiveMembershipsProvider` returns 1 in production code plus references in the test file. |
| `lib/features/reproducao/presentation/atf_detail_screen.dart` | `_backButton` wired into all 4 AppBar `leading:` slots | ✓ VERIFIED | Confirmed by direct read; all 4 `AppBar(...)` constructors carry `leading: _backButton(context)`. |
| `test/widget/baixa_dialog_test.dart` | G-05-1 regression group | ✓ VERIFIED | Present, passes, load-bearing per plan's own reversion check (spot-verified conceptually: the test asserts counters == 2, which is only reachable if the invalidate calls fire). |
| `test/widget/atf_detail_screen_test.dart` | G-05-1-nav regression group | ✓ VERIFIED | Present, passes, 5 new tests confirmed in this session's run. |

### Key Link Verification (delta)

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `BaixaDialog._submit()` success | `atfActiveMembershipsProvider` / `atfMembershipsProvider` / `atfListByPropertyProvider` | `ref.invalidate(...)` (whole family, no id) | ✓ WIRED | Direct read confirms all 3 calls present in the success path only (not in the catch block). |
| `AtfDetailScreen` AppBar `leading` | go_router `context.canPop()`/`context.pop()`/`context.go(AppRoutes.reproducao)` | `_backButton(context)` | ✓ WIRED | Direct read + routed widget test confirms the no-history fallback actually navigates. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| G-05-1 regression test proves invalidation, not just presence | `flutter test test/widget/baixa_dialog_test.dart` | 6/6 pass | ✓ PASS |
| G-05-1-nav regression tests prove back control renders + navigates | `flutter test test/widget/atf_detail_screen_test.dart` | 37/37 pass | ✓ PASS |
| Full suite regression (this session) | `flutter test` | 210/210 pass | ✓ PASS |
| Static analysis clean on 05-11-touched files | `flutter analyze` | 4 pre-existing issues, 0 in Phase-5 files | ✓ PASS |
| CR-01 still present in migration source | direct read `supabase/migrations/20260805_05_atf_rpcs.sql:310-314` | `COALESCE(p_observation, observation)` confirmed unpatched | ✗ FAIL (data-loss defect confirmed live) |
| Live pgTAP execution | `supabase test db` | Not run — no Docker on this machine | ? SKIP (unchanged from previous verification) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist. SKIPPED (unchanged).

### Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| REPR-01 | ✓ SATISFIED | Unchanged; also re-touched by 05-11's back-button fix (navigation UX around the same screen). |
| REPR-02 | ⚠️ SATISFIED at UI/RPC layer, DB-invariant behavior still unproven; **now also touching an unresolved data-loss defect (CR-01) in the same RPC file that implements the D-19 baixa→membership-deactivation chain this requirement depends on.** | UI filter + rejection message tested; `trg_atf_membership_valid` live but pgTAP unrun; `register_baixa` (same migration) has the CR-01 overwrite bug. |
| REPR-03 | ✓ SATISFIED | Unchanged. |
| REPR-04 | ⚠️ SATISFIED at formula/UI layer, live auto-update unproven | Unchanged; this is exactly what 05-UAT.md's re-opened step 6/7 will confirm once the live UAT is re-run. |
| REPR-05 | ✓ SATISFIED | Unchanged; also re-touched by the reproductive-history-adjacent invalidation added to `BaixaDialog`. |

**Orphans:** none, unchanged from previous verification. REQUIREMENTS.md still shows all 5 as unchecked `[ ]` / "Pending" — documentation-sync item, not a code gap, deferred to phase completion.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `supabase/migrations/20260805_05_atf_rpcs.sql` | 310-314 | Data-loss: `COALESCE(p_observation, observation)` overwrites instead of appending | 🛑 Blocker | CR-01 — confirmed present, unpatched, no corrective migration filed. Forces `gaps_found` for this verification. |
| `lib/features/reproducao/presentation/atf_form_dialog.dart` | 115-119 | UI defect: bull UUID shown instead of readable label (WR-01, new) | ⚠️ Warning | Cosmetic, not data-integrity; does not block the phase goal. |
| `supabase/migrations/20260805_05_atf_rpcs.sql` | 62-64 | Missing input de-duplication (WR-02, new) | ⚠️ Warning | Defensive-coding gap, low likelihood given client-side `Set` semantics. |
| — | — | No `TBD`/`FIXME`/`XXX`/`HACK` markers found in any Phase 5-touched file, including the 4 files 05-11 modified | — | None — clean |

### Human Verification Required

Three items — see YAML frontmatter `human_verification`. Summary:

1. **Run `supabase test db`** once Docker is available (unchanged from previous verification — 27 assertions per the WR-02 bump).
2. **Re-run the 05-10 Task 3 twelve-step live UAT**, now unblocked at step 9 by 05-11's fix — in particular re-confirm step 9 (baixa on an ATF member drops the animal from composition live) and steps 6/7 (header % updates live).
3. **Resolve A-DG-ORDER with a veterinarian domain expert** (unchanged, still `[pending]` in 05-UAT.md test 4).

### Gaps Summary

**G-05-1 and G-05-1-nav are genuinely closed.** Both fixes exist in the code exactly as SUMMARY.md claims, are covered by regression tests that are load-bearing (not decorative — the G-05-1 test is explicitly designed to fail if the invalidation lines are reverted), and the full 210-test suite plus `flutter analyze` are clean. This is not a case of "task complete, goal missed" — the artifacts, wiring, and behavioral proof all line up for these two specific gaps.

**However, this verification is not `passed`.** A fresh code review that ran after 05-11 landed found CR-01: `register_baixa` (in the same migration file this phase authored, `20260805_05_atf_rpcs.sql`) silently destroys an animal's prior general observation on baixa instead of appending to it — a confirmed, unpatched, live data-loss defect. It is unrelated to G-05-1/G-05-1-nav and was not this plan's target, but it is real, present in the code today, and severe enough (data loss, no recovery path) that reporting this phase as clean would be misleading. It is recorded here as a new gap rather than silently dropped or deferred (nothing in the roadmap covers it in a later phase).

Once CR-01 has a corrective migration (matching the pattern already established by `20260806_05_fix_atf_membership_trigger_scope.sql` / `20260807_05_fix_remove_animal_from_atf_notfound.sql`), re-run this verification. The three items in `human_verification` (pgTAP, live UAT re-run, DG tie-breaker) remain open regardless and will keep this phase at `human_needed` even after CR-01 is fixed, until a human clears them.

---

*Verified: 2026-08-05*
*Verifier: Claude (gsd-verifier)*
