---
phase: 05-reproductive-module-loteatf
verified: 2026-08-05T15:00:00Z
status: human_needed
score: 9/11 must-haves verified (0 failed); 2 ROADMAP success criteria (SC-2, SC-4) remain behavior-unverified pending a live UAT re-run
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "7/9 must-haves verified (0 failed); 2 behavior-unverified pending live DB proof"
  gaps_closed:
    - "CR-01 (register_baixa observation overwrite, the blocker that held the prior verification at gaps_found): closed by supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql (plan 05-12, commit c444b0e) — observation assignment changed from COALESCE-replace to a CASE-append. Confirmed unpatched-literal absent and CASE-append present by direct read of the migration file, and reported applied + read-back-verified against the live wrdwzychjhlpwpivfhhq project per STATE.md (commits 86352a4/b99dd7f)."
  gaps_remaining: []
  regressions: []
  new_findings_this_session:
    - "WR-01 (05-REVIEW.md, 2026-08-05 re-review): ATF header showed touro's raw UUID instead of a readable label — closed by plan 05-13 (commits dea6bf4, 5618c46). Verified by direct code read + passing widget tests."
    - "WR-02 (05-REVIEW.md, original pass): add_animals_to_atf did not de-duplicate p_animal_ids — closed by the same 20260808 migration (bundled with CR-01)."
    - "CR-01 (05-REVIEW.md, second re-review pass — a different defect that reused the same finding id, see IN-01 note below): _DgSection batch save silently dropped a typed observation for any row whose chip selection did not change — closed by commit f6f70d5 (lib/features/reproducao/presentation/atf_detail_screen.dart). Verified by direct code read + a passing widget test named for CR-01."
    - "WR-01 (05-REVIEW.md, second re-review pass — a different defect that reused the same finding id): register_baixa silently accepted p_reason IS NULL / p_date IS NULL (SQL NOT IN on NULL is NULL, not TRUE) — closed by supabase/migrations/20260809_05_fix_register_baixa_null_guards.sql (commit 6df936d). Verified by direct read of the migration file and of the two new pgTAP throws_ok assertions (34-35, plan(33)->plan(35))."
    - "Quick task 260805-3mr: animal.observation was write-only since capture (never displayed on the ficha) — closed by commit 82ed37e (lib/features/animais/presentation/animal_detail_screen.dart). Verified by direct code read + 4 passing widget tests."
---

# Phase 5: Reproductive Module (LoteATF) Verification Report

**Phase Goal:** Usuário gerencia ciclos reprodutivos criando LoteATF, registrando DGs por animal e consultando o histórico reprodutivo de cada animal.
**Verified:** 2026-08-05
**Status:** human_needed
**Re-verification:** Yes — after CR-01 gap closure (05-12) and a subsequent re-review cycle (05-13, 05-REVIEW.md, 05-REVIEW-FIX.md)

## Goal Achievement

### Gap Closure Verification (this session)

| # | Item | Status | Evidence |
|---|---|---|---|
| GC-1 | **CR-01 (blocker, prior verification):** `register_baixa` appends rather than replaces the animal's general observation on baixa. | ✓ VERIFIED | `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql:151-155` — read directly: `observation = CASE WHEN p_observation IS NULL OR p_observation = '' THEN observation WHEN observation IS NULL OR observation = '' THEN p_observation ELSE observation \|\| E'\n' \|\| p_observation END`. The old `COALESCE(p_observation` literal is absent from the file. All guards (`is_member_of`, veterinarian-role check, `search_path` pin, `deleted_at`/`IF NOT FOUND` archival chain) byte-preserved. Two pgTAP assertions (28-29: append; 30-31: null no-op) added to `supabase/tests/05_reproductive_test.sql`, authored and structurally verified but not executed (no Docker — same as before). |
| GC-2 | **WR-02 (bundled with CR-01):** `add_animals_to_atf` de-duplicates a repeated uuid in one payload instead of failing the batch with `23505`. | ✓ VERIFIED | Same migration file, lines 87-88: `SELECT DISTINCT (elem)::uuid, ...`. Zero `ON CONFLICT` occurrences (`grep -c` = 0), so the partial unique index still raises `23505` for a genuine cross-ATF conflict (REPR-02 intact). |
| GC-3 | **CR-01 applied to the live database, not just committed.** | ✓ VERIFIED (per project documentation; not independently re-queried by this verifier — see caveat below) | `.planning/STATE.md` line 109 (commit `86352a4`/`b99dd7f`, authored by the developer directly, not an agent SUMMARY): "Corrective migration `20260808_05_fix_baixa_observation_and_atf_dedup` applied to live and verified: both function bodies read back correct (CASE-append, SELECT DISTINCT), SQL round-trip proved the append/no-op/dedup behavior transactionally (rolled back, zero leftover rows)." **Caveat:** this verifier has no Supabase MCP/live-DB tool access in this session and could not independently re-run that read-back query. Accepted on the same evidentiary basis the prior verification pass already used for the 20260806/20260807 live-apply claims (a STATE.md record, not re-queried by the verifier either time) — treated as project-documented fact rather than an unverifiable agent narrative. |
| GC-4 | **New finding (WR-01, 05-REVIEW.md 2026-08-05):** ATF header showed the touro's raw UUID instead of `#<numero> — <raça>`. | ✓ VERIFIED | `lib/features/reproducao/presentation/atf_form_dialog.dart:15` — single `_bullLabel(AnimalWithContext aw)` function, referenced at the dropdown (`atf_form_dialog.dart:228`) and at `_submit()` (`:132`). `lib/features/reproducao/presentation/atf_detail_screen.dart:295` — `atf.bullName ?? 'Ver touro'` (uuid fallback removed); `bullAnimalId` remains the `InkWell` navigation target only (`:293`). `flutter test test/widget/atf_form_dialog_test.dart test/widget/atf_detail_screen_test.dart` — all pass, including the load-bearing `findsNothing` assertion on the uuid literal. |
| GC-5 | **New finding (05-REVIEW.md, second re-review, labeled "CR-01" — a distinct defect from GC-1, see IN-01 below on the id collision):** `_DgSection`'s batch save silently dropped a typed observation for any row whose DG chip was never touched. | ✓ VERIFIED | `lib/features/reproducao/presentation/atf_detail_screen.dart:659-678` (`_changedAnimalIds()`) — now includes any animal id with non-empty staged observation text, guarded on a resolvable DG result (`_staged.containsKey(animalId) \|\| _mostRecentDg(animalId) != null`, avoiding a null-unwrap crash on an obs-only row with no DG history). `:731` — `result` resolved via `(_staged[animalId] ?? _mostRecentDg(animalId))!.dbValue` instead of a force-unwrap. `:822` — `onObservationChanged: () => setState(() {})` wired so typing actually enables the save button (the fix would otherwise be unreachable through the UI). Widget test named for CR-01 present at `test/widget/atf_detail_screen_test.dart:684` and passes. |
| GC-6 | **New finding (05-REVIEW.md, second re-review, labeled "WR-01" — a distinct defect from GC-4, same id-collision note):** `register_baixa` silently accepted `p_reason IS NULL` / `p_date IS NULL` (`NULL NOT IN (...)` evaluates to `NULL`, not `TRUE`, so the guard's `IF` took the false branch). | ✓ VERIFIED | `supabase/migrations/20260809_05_fix_register_baixa_null_guards.sql:59-69` — read directly: `IF p_reason IS NULL OR p_reason NOT IN (...)` and a new `IF p_date IS NULL THEN RAISE EXCEPTION ... '22023'`. GC-1's CASE-append and all other guards preserved verbatim in the same re-declaration. Two new pgTAP `throws_ok` assertions (34-35, `supabase/tests/05_reproductive_test.sql:357,366`) target both NULL cases with `22023`; plan count moved `27→33→35`. Live-apply claimed in `STATE.md` line 110, same caveat as GC-3. |
| GC-7 | **Quick task 260805-3mr:** `animal.observation` was write-only since capture — never displayed on the animal ficha, including any GC-1-appended baixa note. | ✓ VERIFIED | `lib/features/animais/presentation/animal_detail_screen.dart:277-280` — `_KvRow(label: 'Observação', value: Text(animal.observation!))` guarded on non-null/non-blank. `flutter test test/widget/animal_detail_screen_test.dart` — 4 new "Observação display" tests pass (set/null/blank/multi-line). |

**Full regression run (this session, not taken from any SUMMARY):** `flutter test` → 217/217 pass. `flutter analyze` → 4 issues, all pre-existing outside any Phase-5 file (2 info in `app_config.dart`/`propriedade_repository.dart`, 2 unused-import warnings in Phase-3-era test files) — zero issues in any file this session's gap-closure/re-review work touched. All named commits (`c444b0e`, `a3ad6d8`, `dea6bf4`, `5618c46`, `f6f70d5`, `6df936d`, `82ed37e`, `86352a4`, `b99dd7f`) confirmed present in `git log`.

### Note on finding-ID collisions (informational, IN-01 from 05-REVIEW.md)

This phase's review passes independently reused the ids "CR-01" and "WR-01" for **four different defects across two review sessions**: GC-1's baixa-observation-replace bug, GC-5's DG-batch-save-drops-observation bug, GC-4's bull-UUID-display bug, and GC-6's NULL-guard bug. All four are real, distinct, and now closed — grepping this codebase for "CR-01" or "WR-01" alone returns multiple unrelated fixes. Not a code defect; recorded here so a future reader is not misled into thinking one fix covers all four.

### Observable Truths (ROADMAP Success Criteria — re-checked for regression)

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|---|---|---|
| SC-1 | Usuário cria LoteATF com nome, data implantação, data inseminação, touro, observação | ✓ VERIFIED | Unchanged; re-confirmed in this session's full-suite run. Bull field now also correctly labeled (GC-4). |
| SC-2 | Ao adicionar animais, sistema só apresenta vacas/novilhas; rejeita animal já em outro ATF ativo com mensagem clara | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Unchanged. UI filter tested and passing. DB half (`trg_atf_membership_valid`, the partial unique index) unproven against a live pgTAP run — still no Docker in this session. |
| SC-3 | Usuário registra DG por animal; registros editáveis até encerramento manual | ✓ VERIFIED | Unchanged. The DG batch-save fix (GC-5) makes this MORE reliable than at the prior verification, not less — an observation typed on an already-correct DG is no longer silently dropped. |
| SC-4 | % prenhez exibido e atualiza automaticamente conforme DGs são registrados | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Unchanged. Formula/UI layer fully unit-tested; live end-to-end recompute against a real Supabase round trip still unproven — this is exactly the still-open 12-step UAT's step 6/7. |
| SC-5 | Histórico reprodutivo do animal mostra todos LoteATFs em que participou com resultados de DG | ✓ VERIFIED | Unchanged. Also now shows the animal's general `observation` (GC-7), which is adjacent but not itself an SC-5 requirement. |

**Score:** 9/11 must-have truths verified (5 ROADMAP SCs + 6 distinct gap/finding closures from GC-1..GC-2, GC-4..GC-7 — GC-3 folds into GC-1's live-apply evidence rather than counting separately). 0 truths FAILED. 2 truths (SC-2, SC-4) remain ⚠️ PRESENT_BEHAVIOR_UNVERIFIED, unchanged since the prior verification.

### Required Artifacts (delta — this session's files only; all prior-verified artifacts unchanged)

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql` | CASE-append `register_baixa`; `SELECT DISTINCT` `add_animals_to_atf` | ✓ VERIFIED | Confirmed by direct read; both functions re-declared with all guards intact. |
| `supabase/migrations/20260809_05_fix_register_baixa_null_guards.sql` | `p_reason IS NULL` / `p_date IS NULL` guards on `register_baixa` | ✓ VERIFIED | Confirmed by direct read; CR-01's CASE-append carried forward unchanged. |
| `lib/features/reproducao/presentation/atf_form_dialog.dart` | Single `_bullLabel` function feeding both dropdown and `createAtf` | ✓ VERIFIED | Confirmed present exactly once, referenced 3x. |
| `lib/features/reproducao/presentation/atf_detail_screen.dart` | `'Ver touro'` fallback (no uuid); `_changedAnimalIds()` includes obs-only rows | ✓ VERIFIED | Both confirmed by direct read at the exact lines the plan/review specified. |
| `lib/features/animais/presentation/animal_detail_screen.dart` | Renders `animal.observation` when non-blank | ✓ VERIFIED | Confirmed present, guarded correctly. |
| `supabase/tests/05_reproductive_test.sql` | `plan(35)`, new assertions covering all 4 closed findings | ✓ VERIFIED (structurally; unexecuted) | `plan(35)` confirmed; `baixa_with_prior_obs`, `baixa_null_obs`, `add_dup_animal_ids`, `baixa_null_reason`, `baixa_null_date` all present. Still not run against a real Postgres engine — no Docker. |

### Key Link Verification (delta)

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `AtfFormDialog` dropdown item label | `AtfFormDialog._submit()`'s `bullName` argument | `_bullLabel(aw)` (shared function) | ✓ WIRED | Both call sites confirmed routing through the same function — cannot drift. |
| `_DgSection._save()` | `saveDgRecords` RPC payload | `_changedAnimalIds()` (now obs-aware) | ✓ WIRED | Confirmed the obs-only-row inclusion feeds the same `records` builder used for chip-changed rows. |
| `register_baixa`'s `UPDATE animals` | `trg_animals_baixa_deactivates_atf` (D-19) | `deleted_at = now()` | ✓ WIRED | Confirmed byte-preserved across both 20260808 and 20260809 re-declarations — the trigger-firing assignment was never touched by either corrective migration. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite regression (this session) | `flutter test` | 217/217 pass | ✓ PASS |
| Static analysis clean on all session-touched files | `flutter analyze` | 4 pre-existing issues, 0 in any Phase-5 file | ✓ PASS |
| CR-01 (GC-1) old literal absent, CASE-append present | direct read `20260808_...sql` | `COALESCE(p_observation` count 0; CASE-append present | ✓ PASS |
| WR-01 (GC-6) NULL guards present | direct read `20260809_...sql` | both `IS NULL` guards present, `22023` on both | ✓ PASS |
| CR-01 (GC-5) DG batch-save obs-only row test | `flutter test test/widget/atf_detail_screen_test.dart` | test named for CR-01 passes | ✓ PASS |
| WR-01 (GC-4) bull-label tests | `flutter test test/widget/atf_form_dialog_test.dart test/widget/atf_detail_screen_test.dart` | all pass, uuid-absence assertion holds | ✓ PASS |
| Observation display tests (GC-7) | `flutter test test/widget/animal_detail_screen_test.dart` | 4/4 new tests pass | ✓ PASS |
| Live pgTAP execution | `supabase test db` | Not run — no Docker on this machine | ? SKIP (unchanged since 05-10) |
| Live-DB read-back of both corrective migrations | (no MCP/DB tool available to this verifier) | Not independently re-queried this session | ? SKIP — relying on STATE.md's documented read-back (see GC-3 caveat) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist. SKIPPED (unchanged).

### Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| REPR-01 | ✓ SATISFIED | Unchanged; also improved this session by the bull-label fix (GC-4) and the observation-display fix (GC-7). |
| REPR-02 | ⚠️ SATISFIED at UI/RPC layer; DB-invariant behavior (trigger, partial unique index) still unproven live via pgTAP. The CR-01 data-loss defect that previously blocked this requirement's RPC (`register_baixa`) is now closed at both code and (per STATE.md) live-DB level. | UI filter + rejection message tested; `add_animals_to_atf` de-dup (WR-02) closed; `trg_atf_membership_valid` live but pgTAP unrun. |
| REPR-03 | ✓ SATISFIED | Unchanged; strengthened by the DG batch-save observation fix (GC-5), which removes a silent data-loss path this requirement's "registros editáveis" language implies must not exist. |
| REPR-04 | ⚠️ SATISFIED at formula/UI layer, live auto-update unproven | Unchanged; this is exactly what the still-open 12-step UAT's step 6/7 will confirm once re-run. |
| REPR-05 | ✓ SATISFIED | Unchanged. |

**Orphans:** none. **Documentation-sync note (unchanged, non-blocking):** `.planning/REQUIREMENTS.md` lines 42-46 and 130-134 still show all 5 REPR-* requirements as unchecked `[ ]` / "Pending" — this is a documentation-sync item deferred to phase completion, not a code gap; the underlying capability is implemented per the evidence above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No `TBD`/`FIXME`/`XXX`/`HACK`/`TODO`/`PLACEHOLDER` markers found in any file touched this session (2 migrations, 2 Dart source files, 2 test files, the pgTAP suite) | — | None — clean |
| — | — | 05-REVIEW.md's IN-01 (finding-id reuse across review passes) and IN-02 (`AtfFormDialog._submit`'s stale-provider edge case) remain unfixed | ℹ️ Info | Both explicitly out of scope for `fix_scope: critical_warning` (05-REVIEW-FIX.md). Not blocking — Info severity, narrow edge cases, no data loss. |

### Human Verification Required

Three items carried forward unchanged from the prior verification — none were closed by this session's work, since none of them are code defects:

1. **Run `supabase test db`** once Docker is available. Now 35 pgTAP assertions (up from 33, up from 27 at the prior verification) — the suite has grown with every gap-closure round but has never executed against a real Postgres engine in any session on this machine.
2. **Re-run the 05-10 Task 3 twelve-step live UAT.** Step 9 (baixa on an ATF member) was already unblocked by 05-11's provider-invalidation fix at the prior verification; steps 6/7 (header % updates live) remain the open item. This session's CR-01/WR-01 fixes (baixa observation append, NULL guards) add two more behaviors worth spot-checking live now that they are (per STATE.md) applied to the live project: a baixa with a note preserves the prior observation, and a baixa attempted with a NULL reason/date is rejected.
3. **Resolve A-DG-ORDER with a veterinarian domain expert** (unchanged, still `[pending]` in 05-UAT.md test 4).

**New, lower-priority item from this session:**

4. **Independently confirm the live read-back of `register_baixa`/`add_animals_to_atf`** that STATE.md reports (commits `86352a4`, `b99dd7f`). This verifier had no Supabase MCP/DB tool access in this session and relied on the project's own documented record rather than re-running the query. Low priority given the project's established pattern of accepting STATE.md-recorded live-apply claims at prior verification passes too — flagged for completeness, not as a new blocker.

### Gaps Summary

**No gaps remain that are `gaps_found`-worthy.** The one blocker that held the prior verification at `gaps_found` — CR-01, `register_baixa`'s observation-overwrite data-loss defect — is closed, confirmed by direct code read of `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql`, and (per `STATE.md`) applied to and read-back-verified against the live project. The subsequent re-review round found two more real defects (a DG batch-save silently dropping observations, and missing NULL guards on `register_baixa`'s `p_reason`/`p_date`) — both are also closed, both verified directly in the code, and the SQL fix is (per `STATE.md`) also live. Full regression (`flutter test` 217/217, `flutter analyze` clean on every touched file) confirms nothing broke.

This verification lands at `human_needed`, not `passed`, because three items from the prior verification remain genuinely open and none of this session's work touched them: the pgTAP suite has still never executed on this machine, the live 12-step UAT (specifically the %-prenhez-updates-live step) has still not been re-run, and the DG created_at-vs-exam_date tie-breaker question is still unresolved. These are pre-existing, standing items — not new gaps introduced by this session — and they will keep this phase at `human_needed` until a human clears them, exactly as `A-REVERIFY-STILL-HUMAN` (05-12-PLAN.md) anticipated.

---

*Verified: 2026-08-05*
*Verifier: Claude (gsd-verifier)*
