---
phase: 05-reproductive-module-loteatf
verified: 2026-08-04T00:00:00Z
status: human_needed
score: 5/5 must-haves structurally verified (0 failed); 2 of 5 ROADMAP success criteria carry a behavior-unverified component pending live DB proof
behavior_unverified: 3
overrides_applied: 0
human_verification:
  - test: "Run supabase test db (pgTAP, 26 assertions in supabase/tests/05_reproductive_test.sql) once a local Docker/Supabase stack is available."
    expected: "All 26 assertions pass, proving trg_atf_membership_valid (23514 category / 23503 cross-property), the partial unique index (23505 duplicate-active), dg_records_result_check (22023), D-08 hard-delete-then-refuse, D-16 closed-ATF-still-correctable, and D-19 baixa-deactivates-membership actually hold against a real Postgres engine rather than only against the authored SQL text."
    why_human: "Never executed in any session (no Docker on this machine, confirmed in 05-10-SUMMARY.md `docker info` failure). Presence and internal consistency of the trigger/RPC code was verified by reading the migration files; the assertions themselves have zero runtime evidence."
  - test: "Complete the 05-10-PLAN.md Task 3 twelve-step live UAT against the pushed Supabase project (flutter run -d edge): create an ATF, add animals (category filter + 'já em ATF' blocked-row message), save DGs and watch the header % prenhez update live, correct a DG, view the ficha's Histórico Reprodutivo, register a baixa on an ATF member, sign in as a non-veterinarian and confirm every write control is absent, encerrar an ATF with the banner, and re-add a released animal to a new ATF."
    expected: "All twelve steps behave as described; explicit approval or a list of failing steps recorded."
    why_human: "This is the phase's own designated blocking checkpoint (05-10-PLAN.md Task 3, `gate=\"blocking\"`, `autonomous: false`) and is OPEN — no approval or failure list has been recorded yet. It is also the only coverage the five RPCs' SQLSTATE 42501 role guards get, since pgTAP runs as the Postgres superuser with no JWT to impersonate (A-PGTAP-ROLE)."
  - test: "Confirm with a veterinarian domain expert whether 'most recent DG' should resolve by exam_date (the date the vet enters, which can be backdated on correction) instead of created_at (insertion order) — the tie-breaker summarizeDg and fetchReproductiveHistory currently use."
    expected: "Either confirmation that created_at is correct, or a one-line change to the tie-breaker (already isolated behind summarizeDg / fetchReproductiveHistory per 05-02-SUMMARY.md) if exam_date is preferred."
    why_human: "Open domain question carried since 05-RESEARCH.md (A-DG-ORDER) and repeated in STATE.md's TODO list; a wrong tie-breaker would silently misreport % prenhez and the ficha's 'last DG' in exactly the reexam-correction scenario D-12 exists to handle. No test can resolve which choice is domain-correct."
gaps_deferred_to_secure_phase:
  - "anon role can EXECUTE all five Phase 5 SECURITY DEFINER RPCs (and Phase 4's move_animal_to_lot) despite REVOKE ALL FROM public — Supabase's ALTER DEFAULT PRIVILEGES grants EXECUTE to anon/authenticated independently of that REVOKE. Each RPC's is_member_of() guard fails closed (42501) when auth.uid() is NULL, so this is not a write bypass, but it leaves a low-severity UUID-existence oracle (23503 vs 42501 lets an anonymous caller distinguish a real id from a fake one). Pre-existing since Phase 1, not introduced by Phase 5, explicitly routed to /gsd-secure-phase in 05-10-SUMMARY.md — not scored against this phase's must-haves."
---

# Phase 5: Reproductive Module (LoteATF) Verification Report

**Phase Goal:** Usuário gerencia ciclos reprodutivos criando LoteATF, registrando DGs por animal e consultando o histórico reprodutivo de cada animal.
**Verified:** 2026-08-04
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (mapped to ROADMAP Success Criteria)

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|---|---|---|
| SC-1 | Usuário cria LoteATF com nome, data implantação, data inseminação, touro, observação | ✓ VERIFIED | `AtfBatch` table + constraints (`atf_batches_bull_required`, `atf_batches_date_order`) present in `supabase/migrations/20260804_05_reproductive_module.sql`; `AtfFormDialog` collects all five fields and calls `AtfRepository.createAtf` (`lib/features/reproducao/presentation/atf_form_dialog.dart`); 7 widget tests pass (`test/widget/atf_form_dialog_test.dart`); migration applied to the live project per 05-10-SUMMARY.md catalog query. Standard CRUD flow, not a state-transition invariant — no behavioral gap. |
| SC-2 | Ao adicionar animais, sistema só apresenta vacas/novilhas; rejeita animal já em outro ATF ativo com mensagem clara | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED (UI half VERIFIED, DB-rejection half unproven live) | UI half: `AtfAnimalSelectionScreen` filters both the lot checklist and the avulsos list to `{vaca, novilha}` (defense-in-depth, `lib/features/reproducao/presentation/atf_animal_selection_screen.dart`) and renders a blocked animal as a disabled row carrying `blockedByAtfName` rather than hiding it — 8 widget tests pass (`test/widget/atf_animal_selection_screen_test.dart`), including an explicit assertion that a touro/terneiro never renders and that a blocked row is FOUND, not absent. DB half: the actual enforcement is `trg_atf_membership_valid` (23514 category / 23503 cross-property) and the pre-existing partial unique index (23505 duplicate-active) — both exist in the applied migration and were confirmed present/enabled by a live catalog query (05-10-SUMMARY.md), but the pgTAP suite that exercises them (`throws_ok` assertions 3/4/6 in `supabase/tests/05_reproductive_test.sql`) has never executed (no Docker). Symbol presence and live-schema presence are proven; the actual rejection behavior against a real INSERT is not. |
| SC-3 | Usuário registra DG por animal (prenha/não-prenha/duvidosa + data + observação); registros editáveis até encerramento manual | ✓ VERIFIED (with a documented scope note) | `_DgSection`/`_DgChipRow` on `AtfDetailScreen` implement the mass-entry flow with session date + per-row override + observation, 10 widget tests pass covering staging, save-payload diffing, and post-failure state retention (`test/widget/atf_detail_screen_test.dart`). `dg_records_result_check` CHECK constraint restricts to the three values. **Note:** the actual implementation (D-16, explicitly locked in 05-CONTEXT.md) permits DG correction to continue *after* manual encerramento — stronger than the roadmap's literal "editável até encerramento" wording, which could be read as "edits stop at closure." This is a deliberate, documented design decision, not a defect, but it is a divergence from the literal SC-3 text worth a human sanity-check. |
| SC-4 | % prenhez exibido e atualiza automaticamente conforme DGs são registrados (= prenhas / total DG × 100) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `summarizeDg`/`formatPrenhez` (`lib/features/reproducao/data/dg_summary.dart`) implement the exact formula once, pure-function, with 11 unit tests (`test/features/reproducao/dg_summary_test.dart`) proving D-12 (most-recent-DG-per-animal), D-17 (duvidosa in denominator not numerator), D-18 (display format incl. singular/plural pendente(s)), and D-20 (baixa'd animal with a DG still counted) — all four scenarios named in the plan's `verification: backstop` truth are present and passing. The "atualiza automaticamente" half is a live-recompute claim: `_DgSection`'s save handler invalidates `dgRecordsByAtfProvider`/`atfByIdProvider`/`atfListByPropertyProvider`/`reproductiveHistoryByAnimalProvider` after a successful `saveDgRecords`, but 05-08-SUMMARY.md's own coverage (item D10) marks this `human_judgment: true` because widget tests only prove the invalidation call sites execute against static fakes — no test observes the header % actually recomputing against genuinely new data through a real Supabase round trip. This is exactly UAT step 6/7 in the open 05-10 checkpoint. |
| SC-5 | Histórico reprodutivo do animal mostra todos LoteATFs em que participou com resultados de DG | ✓ VERIFIED | `_ReproductiveHistorySection` replaces the Fase-3 placeholder on `AnimalDetailScreen` (confirmed: the file's remaining `_PlaceholderSection` usage is only for "Histórico Sanitário", Phase 6 scope — "Histórico Reprodutivo" is real). `AtfRepository.fetchReproductiveHistory` includes active AND closed memberships. 7 widget tests cover empty/loading/error/populated/partial/read-only/navigation states (`test/widget/animal_detail_screen_test.dart`). Read-only per D-13 (no write affordance in the section, verified by absence of `ChoiceChip`/`ButtonStyleButton`/`IconButton` in that subtree). Rendering logic against a genuinely live-fetched dataset is covered by the same open UAT step 8, but the artifact/wiring/rendering-logic layer itself is solid and not itself a state-transition truth. |

**Score:** 5/5 must-have truth clusters structurally verified at the code level (all artifacts present, substantive, and wired); 3 behavior-dependent items (2 SCs + the pgTAP suite as a whole) remain unproven against a running database or a real end-to-end recompute, all routed to the already-open blocking checkpoint plus one additional domain question (A-DG-ORDER).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `supabase/migrations/20260804_05_reproductive_module.sql` | `atf_batches`, `dg_records`, extended `animal_atf_memberships`, RLS, 3 triggers | ✓ VERIFIED | Confirmed on disk; `CREATE TABLE atf_batches`/`dg_records`, `dg_records_result_check`, `animal_atf_memberships_atf_fk`, `FORCE ROW LEVEL SECURITY` ×2, 4 `CREATE POLICY`, 3 `CREATE TRIGGER` all present via grep. Applied to live project per 05-10-SUMMARY.md catalog query (not independently re-queried by this verifier — no live DB tool available in this session). |
| `supabase/migrations/20260805_05_atf_rpcs.sql` | 5 SECURITY DEFINER RPCs | ✓ VERIFIED | `add_animals_to_atf`, `remove_animal_from_atf`, `close_atf`, `save_dg_records`, `register_baixa` all present with `SECURITY DEFINER`/`SET search_path = public`/`REVOKE ALL`+`GRANT EXECUTE TO authenticated`. `remove_animal_from_atf` uses hard `DELETE`, not soft deactivation, exactly as D-08 specifies; `save_dg_records`'s `atf_batches` lookup and membership guard both correctly omit the `active` filter per D-16. |
| `supabase/tests/05_reproductive_test.sql` | pgTAP suite proving the invariants | ⚠️ ORPHANED (authored, never executed) | 26 assertions, `plan(26)` matches the actual count. Structurally sound (verified by direct read) but has zero runtime evidence — see human_verification. |
| `lib/features/reproducao/data/{atf_model,dg_record_model,dg_summary,atf_repository}.dart` | Freezed models, % prenhez formula, repository + 8 providers | ✓ VERIFIED | All four files exist; `atf_repository.dart` calls the four RPCs by name with matching parameter keys (`p_atf_batch_id`, `p_animal_ids`, `p_records`); no direct `.update()`/`.delete()` on `dg_records` or `animal_atf_memberships` anywhere in the repository — mutation is RPC-only as required. |
| `lib/features/reproducao/presentation/{reproducao_screen,atf_form_dialog,atf_detail_screen,atf_animal_selection_screen,encerrar_atf_dialog}.dart` | List, creation dialog, detail screen (header/composition/DG/encerramento), picker, close dialog | ✓ VERIFIED | All five files exist, substantive, and wired into `AppRoutes.atfById`/`atfDetail(id)` (root-level `/atf/:atfId`, confirmed registered outside the `StatefulShellRoute`). |
| `lib/features/animais/presentation/animal_detail_screen.dart` — `_ReproductiveHistorySection` | Replaces the Fase-3 placeholder | ✓ VERIFIED | Confirmed by direct read: `_ReproductiveHistorySection` renders real data; `_PlaceholderSection` remains only for "Histórico Sanitário" (out of this phase's scope). |
| `lib/features/animais/data/animal_repository.dart` — `registerBaixa` | Rewired to `.rpc('register_baixa')` | ✓ VERIFIED | `registerBaixa` calls `_service.client.rpc('register_baixa', params: {...})`; public signature unchanged; `baixa_dialog.dart` has zero diff (per 05-07-SUMMARY.md, confirmed by grep — no remaining `.from('animals').update(` in `registerBaixa`'s body). |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `AtfAnimalSelectionScreen` | `eligibleAnimalsForAtfProvider` → `add_animals_to_atf` RPC | confirm button | ✓ WIRED | Repository method calls `.rpc('add_animals_to_atf', ...)`; provider invalidation on success confirmed in source. |
| `_DgSection` | `save_dg_records` RPC | "Salvar DGs" button | ✓ WIRED | `AtfRepository.saveDgRecords` builds `p_records` from changed rows only; 4-provider invalidation chain present at the call site (behavior of the invalidation *result* is the SC-4 item marked behavior-unverified above, not the wiring itself). |
| `EncerrarAtfDialog` | `close_atf` RPC | "Encerrar" button | ✓ WIRED | Non-optimistic: awaits `closeAtf`, invalidates 4 providers, pops `true` only after. |
| `AnimalRepository.registerBaixa` | `register_baixa` RPC → `trg_animals_baixa_deactivates_atf` (D-19) | baixa flow | ✓ WIRED (trigger presence confirmed; live firing unproven) | The Dart→RPC link is directly verified by grep. The RPC→trigger link is structural (the trigger fires `AFTER UPDATE OF deleted_at ON animals`, and `register_baixa`'s `UPDATE animals ... SET deleted_at = now()` is exactly that event) — confirmed by reading both migration files, not by a live run. |
| `_ReproductiveHistorySection` row tap | `AppRoutes.atfDetail(id)` | `context.go(...)` | ✓ WIRED | Confirmed by widget test asserting navigation to `/atf/:atfId` on row tap. |

### Data-Flow Trace (Level 4)

All Phase 5 screens read from Riverpod `FutureProvider`s backed by `AtfRepository` methods that issue real Supabase queries (`.from('atf_batches')`, `.from('dg_records')`, `.from('animal_atf_memberships')` with embedded resources) — no hardcoded or static-empty returns were found in `atf_repository.dart`. The schema those queries target is confirmed live-applied (05-10-SUMMARY.md catalog query: tables, columns, FKs, triggers, RPCs all present with `EXECUTE` granted to `authenticated`). Data-flow is therefore **structurally FLOWING**, but no query has been exercised against real rows in this session — the 12-step UAT (open) is what proves rows actually round-trip correctly (dates not off-by-one across timezones, jsonb array serialization for `p_animal_ids`/`p_records`, embedded-resource joins resolving correctly).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full Dart test suite is green | `flutter test` | `All tests passed!` — 204/204 | ✓ PASS |
| Static analysis clean (no new issues) | `flutter analyze` | 4 issues — all pre-existing (2 info in `app_config.dart`/`propriedade_repository.dart` predating Phase 5, 2 unused-import warnings in Phase-3-era test files) — zero issues in any `reproducao`/Phase-5-touched file | ✓ PASS |
| pgTAP suite structural integrity | `grep plan(N) vs assertion count` in `05_reproductive_test.sql` | `plan(26)` == 26 counted assertions | ✓ PASS (structural only — suite itself unrun) |
| Live pgTAP execution | `supabase test db` | Not run — no Docker on this machine | ? SKIP (recorded, not silently dropped — see human_verification) |
| Live Supabase schema application | `supabase migration list` / MCP `apply_migration` | Per 05-10-SUMMARY.md: both migrations applied, all objects confirmed by catalog query | ? SKIP for this verifier (no live-DB tool available in this session to independently re-query; relying on the executor's documented catalog-query evidence, which is internally consistent with the migration files on disk) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist in this repository and no PLAN/SUMMARY in this phase references a probe script. Step 7c: SKIPPED (no probes declared or found).

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| REPR-01 | 05-01, 05-02, 05-04, 05-05, 05-10 | Criar LoteATF (nome, datas, touro, observação) | ✓ SATISFIED | `AtfFormDialog` + `atf_batches` schema + `createAtf`, all tested |
| REPR-02 | 05-01, 05-02, 05-03, 05-06, 05-10 | Seleção de animais restrita a vaca/novilha; rejeição de ATF ativo duplicado | ⚠️ SATISFIED at UI/RPC layer, DB-invariant behavior unproven | UI filter + `blockedByAtfName` tested; `trg_atf_membership_valid` + partial unique index exist live but pgTAP unrun |
| REPR-03 | 05-01, 05-02, 05-03, 05-08, 05-09, 05-10 | Registrar DG por animal, mass-entry, editável | ✓ SATISFIED | `_DgSection`, `save_dg_records`, `dg_records_result_check` all present and tested |
| REPR-04 | 05-02, 05-04, 05-05, 05-08, 05-09, 05-10 | % prenhez calculado e exibido, atualiza automaticamente | ⚠️ SATISFIED at formula/UI layer, live auto-update unproven | `summarizeDg`/`formatPrenhez` fully unit-tested; invalidation call sites present but live recompute untested end-to-end |
| REPR-05 | 05-02, 05-03, 05-07, 05-10 | Histórico reprodutivo na ficha do animal | ✓ SATISFIED | `_ReproductiveHistorySection` real, tested, read-only |

**Orphans:** none — REQUIREMENTS.md's Phase 5 row (REPR-01..05) is fully accounted for across the 10 plans; no requirement ID appears in REQUIREMENTS.md's Phase 5 mapping without a corresponding plan claim. Note: REQUIREMENTS.md itself still shows these 5 items as unchecked `[ ]` / "Pending" in its traceability table — a documentation-sync item, not a code gap (the doc is normally updated at phase completion, which is exactly what is blocked on the open checkpoint).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No `TBD`/`FIXME`/`XXX`/`HACK` markers found in any Phase 5-touched file (`lib/features/reproducao/`, `animal_detail_screen.dart`, `animal_repository.dart`, both new migrations) | — | None — clean |
| `animal_detail_screen.dart` | 106 | `_PlaceholderSection(title: 'Histórico Sanitário', ...)` | ℹ️ Info | Intentional — Phase 6 scope, not this phase's placeholder. Confirmed the Phase 5 "Histórico Reprodutivo" placeholder was correctly replaced. |

No blocker-level anti-patterns found. No debt markers requiring a `gaps_found` classification.

### Human Verification Required

Three items — see YAML frontmatter `human_verification` for full detail. Summary:

1. **Run `supabase test db`** once Docker is available — the 26-assertion pgTAP suite has never executed against a real Postgres engine. This is the primary DB-invariant proof gap (SC-2's rejection behavior, SC-3's result-vocabulary CHECK, D-08/D-16/D-19 state transitions).
2. **Complete the open 05-10 Task 3 twelve-step live UAT checkpoint** — this is the phase's own designated blocking gate (`gate="blocking"`, `autonomous: false`) and has not been approved or reported failed. It is the only coverage the RPCs' 42501 role guards get, and the only proof that SC-4's "atualiza automaticamente" claim holds against a real Supabase round trip.
3. **Resolve A-DG-ORDER with a veterinarian domain expert** — confirm `created_at` (current implementation) vs. `exam_date` as the "most recent DG" tie-breaker. A wrong choice silently misreports % prenhez and the ficha's "last DG" in exactly the reexam-correction scenario the feature exists to handle.

### Gaps Summary

No structural gaps: every artifact this phase's plans promised exists on disk, is substantive (no stub bodies, no placeholder returns), and is wired into the UI/routing/provider graph exactly as specified. All 204 Flutter tests pass and `flutter analyze` is clean in every Phase-5-touched file. Both migrations are authored correctly and — per the executor's own catalog-query evidence in 05-10-SUMMARY.md — applied to the live Supabase project.

What remains is exactly what the phase's own plan (05-10) designed as its blocking gate: the 26-assertion pgTAP suite has never run (no Docker), and the twelve-step human UAT checkpoint is still open. Two of the five ROADMAP success criteria (SC-2's DB-level rejection, SC-4's live auto-update) depend on state-transition/invariant behavior that only a running database or a live UAT pass can prove — Dart-side code presence and wiring cannot certify them on their own, per this phase's own explicit design intent ("Flutter build and test success alone is a false positive," 05-10-PLAN.md). This phase is therefore correctly `human_needed`, not `passed`, until that checkpoint clears — and not `gaps_found`, because nothing found on inspection contradicts the plans or is missing/stubbed/unwired.

---

*Verified: 2026-08-04*
*Verifier: Claude (gsd-verifier)*
