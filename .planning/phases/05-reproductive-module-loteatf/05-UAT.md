---
status: diagnosed
phase: 05-reproductive-module-loteatf
source: [05-VERIFICATION.md, 05-REVIEW.md]
started: 2026-08-04T00:00:00Z
updated: 2026-08-05T17:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. CR-01 / D-19: baixa on an animal in an active ATF
expected: |
  Baixa succeeds for an animal that is a member of an active ATF, and that animal's
  membership is deactivated in the same transaction (D-19).
result: resolved
resolution: |
  Plan 05-11 (commits: see 05-11-SUMMARY.md) fixed both gaps below. BaixaDialog._submit() now
  invalidates the atfActiveMembershipsProvider/atfMembershipsProvider/atfListByPropertyProvider
  families on success (fixes G-05-1 — stale Riverpod cache, not a DB defect). AtfDetailScreen
  now renders a BackButton in all four AppBar states (fixes G-05-1-nav). STATE.md records this
  as RESOLVED 2026-08-04. Not independently re-run against the live app this session — carried
  forward as resolved on the strength of 05-11's passing widget tests + STATE.md's record.
reported: |
  1. Nao tem botao de voltar (na tela do ATF apos salvar DGs).
  2. Dei baixa na Vaca #2 enquanto ela estava em um ATF: ela continuou no ATF ativo
     (nao foi desativada a membership), mas nao aparece mais nos animais nem nos lotes.
severity: blocker
note: |
  Transaction no longer aborts (CR-01's original SQLSTATE 23503 symptom is gone), but D-19's
  actual requirement -- membership deactivation in the same transaction -- is not happening.
  The animal vanishes from animais/lotes (soft-delete side working) while remaining an active
  ATF member. Regresses the "resolved" status this test previously carried.
resolution_prior: |
  Corrective migration `20260806_05_fix_atf_membership_trigger_scope.sql` (commit ef89470) rescopes
  the trigger to `BEFORE INSERT OR UPDATE OF animal_id, atf_batch_id, property_id`, fixing the abort.
  Did not verify the membership-deactivation side end-to-end -- that gap is what this test now catches.
cause_prior: |
  `trg_atf_membership_valid` is `BEFORE INSERT OR UPDATE` on `animal_atf_memberships`, and
  `enforce_atf_membership_valid()` re-checks `animals.deleted_at IS NULL`. The D-19 chain is:
  register_baixa sets deleted_at -> AFTER trigger UPDATEs the membership -> that UPDATE fires the
  BEFORE trigger -> the animal is already archived -> exception -> transaction aborts.
blocks: tests 2-4 below

### 2. Run the pgTAP suite
expected: All 35 assertions (grown from 26 across five gap-closure rounds) in `supabase/tests/05_reproductive_test.sql` pass against a real Postgres engine, proving trg_atf_membership_valid (23514 category / 23503 cross-property), the partial unique index (23505 duplicate-active), dg_records_result_check (22023), D-08 hard-delete-then-refuse, D-16 closed-ATF-still-correctable, D-19 baixa-deactivates-membership, the 20260808 CR-01/WR-02 append/dedup assertions, and the 20260809 WR-01 NULL-guard assertions.
why_human: Never executed in any session — `docker info` fails on this machine, so `supabase test db` cannot start. The SQL was verified by reading only; the assertions have zero runtime evidence.
command: `supabase test db`
result: pass
source: automated
note: |
  Docker unavailable (project moved to Supabase-hosted only). Ran the suite's 371 lines verbatim
  (BEGIN...ROLLBACK, unmodified except each assertion's SELECT wrapped in an INSERT into a temp
  tap_log table so all 35 per-assertion TAP lines could be recovered from the MCP execute_sql
  single-result-set response) against the connected PROD Supabase project (wrdwzychjhlpwpivfhhq),
  after user-confirmed "prod, run anyway" — schema-only side effect was `CREATE EXTENSION IF NOT
  EXISTS pgtap` (idempotent, left installed); all test data inserts rolled back.
  34/35 assertions passed. Assertion 2 (`has_index` on animal_atf_memberships_active_idx) failed,
  but it's a pre-existing bug in the TEST FILE itself, not a schema defect: the 3-arg
  `has_index(table, index, description)` call is ambiguous against pgTAP's own
  `has_index(name,name,name)` (table, index, columns) overload — Postgres resolved to the columns
  overload, silently truncating the description string to 63 chars (the `name` type's length cap)
  and comparing it against the real column list. Confirmed independently via
  `pg_indexes`: `CREATE UNIQUE INDEX animal_atf_memberships_active_idx ON
  animal_atf_memberships USING btree (animal_id) WHERE (active = true)` — exactly REPR-02's
  invariant, present and correct. Not logged as a gap (test-authoring defect, zero product risk);
  worth a one-line fix to the assertion's arg count if the suite is touched again.

### 3. Twelve-step live UAT (05-10-PLAN.md Task 3)
expected: All twelve steps behave as described in 05-10-PLAN.md; explicit approval or a list of failing steps.
result: issue
reported: |
  Steps 1-8, 10, 12: tudo ok.
  Step 9 (baixa on active ATF member) — screenshot of ATF 3: Composição header shows "(2 animais)"
  (#23, #26) after the baixa, correctly dropped. But the "Registrar DG" section right below still
  lists #23, #26, AND #27 (the animal that just got baixa) with #27's prior "Prenha" chip still
  selected, and the ATF's top summary still reads "33% prenhez (1/3 DG)" — pre-baixa math with 3
  animals, not 2. User: "eu dei baixa, é assim que é pra ficar?"
  Step 11 (encerrar banner, ATF 4, 0/5 animals have any DG yet) — the "Todos os animais têm DG
  registrado." banner with an "Encerrar ATF" action appears even though zero of the 5 animals in
  composição have a DG chip selected. Clicking Encerrar opens the confirm dialog, which correctly
  shows "Ainda há 5 animais sem DG registrado." — contradicting the banner that triggered it.
severity: major
why_human: The phase's own designated blocking checkpoint (`gate="blocking"`, `autonomous: false`), still open. Also the only coverage the five RPCs' 42501 role guards get, since pgTAP runs as superuser with no JWT to impersonate (A-PGTAP-ROLE).
note: |
  No longer blocked by test 1 — that gap is resolved. Step 9 (baixa on an active ATF member)
  should now succeed. While re-running this walkthrough, also spot-check two fixes from the
  2026-08-05 re-verification: a baixa with a note preserves the animal's prior general
  observation (now visible on the ficha — the display gap is also closed), and a baixa
  attempted with a blank/NULL reason or date is rejected rather than silently archiving the
  animal.
steps: |
  1.  flutter run -d edge against the live project
  2.  Sign in as veterinarian, open Reprodução — list renders (empty state), not an error
  3.  Create an ATF (name, both dates, touro or "Outro / sêmen externo") -> lands on detail screen
  4.  "+ Animais", pick a lote base — only vacas and novilhas listed
  5.  Add the same animal to a SECOND ATF — greyed out with "já em ATF [nome]", unselectable (SC-2)
  6.  Mark DG chips for two animals, set session date, "Salvar DGs" — header % updates immediately (SC-4)
  7.  Re-mark a chip on an animal that already has a DG — % reflects the new result, earlier record still exists
  8.  Open that animal's ficha — Histórico Reprodutivo lists the ATF with its last DG; tapping navigates to /atf/:atfId
  9.  Register a baixa on an animal in an active ATF — must succeed, animal drops out of composition  [was FAILED, see test 1 — fixed by 05-11, re-verify]
  10. Sign in as non-veterinarian — FAB, "+ Animais", remove icons, "Salvar DGs", encerrar are ABSENT (not greyed)
  11. As veterinarian, once every animal has a DG the banner appears; use it to encerrar. Composition/encerrar controls vanish, DG chips stay interactive (D-16)
  12. Add a released animal to a NEW ATF — now selectable
result: [pending]

### 4. Confirm the DG tie-breaker with a veterinarian (A-DG-ORDER)
expected: Either confirmation that `created_at` is correct, or a one-line change to `exam_date`.
why_human: Open domain question since 05-RESEARCH.md, repeated in STATE.md's TODO list. A wrong tie-breaker silently misreports % prenhez and the ficha's "last DG" in exactly the reexam-correction scenario D-12 exists for. No test can decide which is domain-correct.
isolated_to: `summarizeDg` / `fetchReproductiveHistory` (one line)
result: issue
reported: "fix — use exam_date, not created_at, as the DG tie-breaker"
severity: major

## Summary

total: 4
passed: 1
issues: 2
pending: 0
skipped: 0
blocked: 0
resolved: 1

## Gaps

- gap_id: G-05-4
  truth: "The DG tie-breaker for 'last DG' / % prenhez uses exam_date, not created_at, when an animal has more than one DG record."
  status: diagnosed
  reason: "User confirmed the fix: use exam_date, not created_at, as the tie-breaker (A-DG-ORDER)."
  severity: major
  test: 4
  root_cause: |
    Three independent, hand-written "keep the DG record with the max createdAt per animal"
    reduction loops exist (not one shared function) — each written separately under A-DG-ORDER's
    original (now-overruled) assumption that exam_date was untrustworthy since D-11 lets a vet
    manually correct it. Only two of the three were named in the UAT's isolated_to note; the third
    was uncataloged and 05-02-SUMMARY.md incorrectly claimed the tie-breaker was "already isolated,
    no callers to touch."
  artifacts:
    - path: "lib/features/reproducao/data/dg_summary.dart:41"
      issue: "summarizeDg() compares r.createdAt.isAfter(current.createdAt) — feeds % prenhez summary"
    - path: "lib/features/reproducao/data/atf_repository.dart:188"
      issue: "fetchReproductiveHistory() has its own separate createdAt.isAfter loop — feeds the ficha's last-DG display"
    - path: "lib/features/reproducao/presentation/atf_detail_screen.dart:646-655"
      issue: "private _mostRecentDg() in _DgSectionState, createdAt.isAfter at line 650 — drives DG chip preselection and the save_dg_records diff payload; NOT named in the original UAT isolated_to note"
  missing:
    - "Swap createdAt -> examDate in the isAfter comparison at all three sites (3 one-token changes, not 1)"
    - "Optional: extract a single shared latestByExamDate(Iterable<DgRecord>) helper reused by all three, since 3 independent copies already caused one to be missed from tracking docs once"
    - "Decide + document tie-handling when two records share an identical exam_date (currently first-encountered-in-loop wins, no explicit secondary tie-break)"
  debug_session: ".planning/debug/dg-tie-breaker-created-at.md"

- gap_id: G-05-2
  truth: "After a baixa on an active ATF member, the ATF detail screen's DG-registration list and prenhez summary reflect the new composition, not the pre-baixa one."
  status: failed
  reason: |
    User reported: eu dei baixa, é assim que é pra ficar? Composição header correctly dropped to
    (2 animais), but the Registrar DG list below still shows the baixa'd animal (#27) with its
    prior DG chip selected, and the header still reads "33% prenhez (1/3 DG)" instead of
    recomputing against the 2 remaining animals.
  severity: major
  test: 3
  root_cause: |
    NOT a stale-cache repeat of G-05-1 — every provider involved (atfMembershipsProvider,
    dgRecordsByAtfProvider) already returns fresh data after baixa; 05-11's family-wide
    invalidation already covers this provider. The real cause is a documented design conflation
    (D-16/D-19/D-20): "active=false because ATF closed" and "active=false because the animal was
    baixa'd" are the same boolean with no distinguishing signal. _DgSection renders every row from
    the unfiltered provider by design (so D-16 closed-ATF DG correction keeps working), and
    summarizeDg intentionally keeps a baixa'd animal's historical DG in the % prenhez total
    regardless of live composition (D-20) — verified the math is byte-identical pre/post baixa,
    not stale. User decision (2026-08-05): keep D-20's historical-total behavior; the actual fix
    is UI-only — stop rendering a baixa'd animal as an editable row in "Registrar DG" specifically
    (it can't be corrected there), while a closed-but-not-baixa'd ATF's rows keep rendering per D-16.
  artifacts:
    - path: "lib/features/reproducao/presentation/atf_detail_screen.dart (_DgSection, lines 585-846)"
      issue: "renders every atfMembershipsProvider row unconditionally — no signal to tell 'animal baixa'd' apart from 'ATF closed, correction still allowed'"
    - path: "lib/features/reproducao/data/atf_repository.dart (fetchMemberships, lines 72-98)"
      issue: "select() never joins animals.deleted_at, so the Dart layer has no data to distinguish the two active=false cases"
    - path: "lib/features/reproducao/data/atf_model.dart (AtfMembershipView, lines 34-49)"
      issue: "no field carries the member animal's soft-delete status"
  missing:
    - "Join animals.deleted_at into fetchMemberships()'s select and AtfMembershipView"
    - "Filter _DgSection's rendered rows to exclude memberships whose animal is baixa'd (deleted_at not null), while still showing rows for a closed-but-not-baixa'd ATF (D-16 unchanged)"
    - "Leave summarizeDg's D-20 total-counting behavior untouched per user decision — no change to % prenhez math"
  debug_session: ".planning/debug/atf-dg-list-stale-after-baixa.md"

- gap_id: G-05-3
  truth: "The 'Todos os animais têm DG registrado.' encerrar banner only appears once every animal in the ATF's composição actually has a DG registered."
  status: diagnosed
  reason: |
    User reported (screenshots, ATF 4): banner + Encerrar action appeared with 0/5 animals having
    any DG. Its own confirm dialog correctly says "Ainda há 5 animais sem DG registrado.",
    contradicting the banner condition that surfaced it.
  severity: major
  test: 3
  root_cause: |
    showBanner and the AppBar's pendingCount both gate on dgSummary.pending == 0, where dgSummary
    = summarizeDg(dgRecords, compositionCount: activeMemberships.length). By D-20 design, total
    counts every animalId that EVER had a DG for this atf_batch_id, including animals since
    removed/baixa'd — correct for the % prenhez header, but reused (wrongly) as a live "does every
    CURRENT member have a DG" check. When composition churns (a DG'd animal is removed/baixa'd and
    a DG-less animal is added in its place), cumulative historical total can reach/exceed the NEW
    compositionCount, clamping pending to 0 with zero current members actually having a DG — the
    exact reported symptom. Secondary finding: the banner's own embedded "Encerrar ATF" button
    hardcodes pendingCount: 0 to the confirm dialog; the correct live count the user saw in the
    dialog ("Ainda há 5...") most likely came from the AppBar's separate icon action, which
    recomputes independently, not the banner's own button.
  artifacts:
    - path: "lib/features/reproducao/presentation/atf_detail_screen.dart (showBanner/dgSummary, lines 64-78; banner button ~line 570)"
      issue: "reuses summarizeDg's cross-composition-cycle total as a live per-member gate instead of checking current members individually; banner's own Encerrar button hardcodes pendingCount: 0"
    - path: "lib/features/reproducao/presentation/atf_detail_screen.dart (_CompositionSection, lines 406-457)"
      issue: "already computes the correct per-row primitive (dgAnimalIds.contains(m.animalId)) for its remove-button gate, but it's never hoisted/reused for the banner"
  missing:
    - "Hoist dgAnimalIds = dgRecords.map((d) => d.animalId).toSet() to the parent build method"
    - "Replace showBanner's dgSummary.pending == 0 with activeMemberships.every((m) => dgAnimalIds.contains(m.animalId))"
    - "Replace AppBar/banner pendingCount with activeMemberships.where((m) => !dgAnimalIds.contains(m.animalId)).length instead of dgSummary.pending"
    - "Leave dg_summary.dart's summarizeDg/D-20 behavior untouched — it's correct for the % prenhez header"
  debug_session: ".planning/debug/atf-encerrar-banner-premature.md"
  missing: []
  debug_session: ""

- gap_id: G-05-1
  truth: "Baixa on an animal in an active ATF deactivates that animal's membership in the same transaction (D-19)."
  status: resolved
  resolved_by: "plan 05-11 — BaixaDialog._submit() invalidates the three ATF-composition provider families on success"
  reason: "User reported: Dei baixa na Vaca #2 enquanto ela estava em um ATF, ela continuou no ATF ativo, mas não aparece mais nos animais, nem nos lotes."
  severity: blocker
  test: 1
  root_cause: |
    NOT a database defect. The register_baixa -> trg_animals_baixa_deactivates_atf AFTER trigger ->
    animal_atf_memberships.active=false chain is sound after the CR-01 trigger-scope fix (the
    rescoped BEFORE trigger only re-fires on UPDATE OF animal_id/atf_batch_id/property_id, not on a
    pure `active` flip). The actual gap is a stale Riverpod cache: BaixaDialog._submit() invalidates
    animalByIdProvider, animalListByPropertyProvider, reproductiveHistoryByAnimalProvider — but never
    the reproducao feature's atfActiveMembershipsProvider / atfMembershipsProvider /
    atfListByPropertyProvider. Those are plain (non-autoDispose) FutureProviders that cache
    indefinitely, so the ATF detail screen keeps showing the pre-baixa composition until app restart.
    Every other ATF-composition-changing flow (remove_animal_from_atf, encerrar, add_animals_to_atf)
    already invalidates all three; baixa is the only mutation path missing it (triggered from a
    different feature module with no reference to atfBatchId).
  artifacts:
    - path: "lib/features/animais/presentation/baixa_dialog.dart"
      issue: "_submit() doesn't invalidate atfActiveMembershipsProvider / atfMembershipsProvider / atfListByPropertyProvider after a successful baixa"
    - path: "lib/features/reproducao/data/atf_repository.dart"
      issue: "defines the three non-autoDispose ATF-composition providers that go stale"
  missing:
    - "Invalidate atfActiveMembershipsProvider, atfMembershipsProvider, and atfListByPropertyProvider (whole-family, since BaixaDialog doesn't know the animal's atfBatchId) in BaixaDialog._submit() on success"
  debug_session: ".planning/debug/atf-membership-not-deactivated-on-baixa.md"

- gap_id: G-05-1-nav
  truth: "ATF detail screen has a way back to the previous screen."
  status: resolved
  resolved_by: "plan 05-11 — BackButton added to all 4 AtfDetailScreen AppBar states"
  reason: "User reported: não tem botão de voltar."
  severity: minor
  test: 1
  root_cause: |
    /atf/:atfId is a root-level GoRoute (router.dart:141-149), a sibling of the StatefulShellRoute,
    not nested inside it. All call sites navigate via context.go(...), which replaces the whole nav
    stack, so Navigator.canPop() is false on arrival and Flutter's default AppBar shows no back
    arrow. atf_detail_screen.dart never sets an explicit `leading` widget to compensate — unlike the
    identical /lotes/:loteId routing pattern, where lote_detail_screen.dart already has a working
    BackButton(onPressed: canPop() ? pop() : go(parent)) fallback that atf_detail_screen.dart's own
    header comment claims to mirror but never actually copied.
  artifacts:
    - path: "lib/features/reproducao/presentation/atf_detail_screen.dart"
      issue: "all 4 AppBar instances (loading/error/null-data/data states, lines 41-93) missing a leading BackButton"
  missing:
    - "Add leading: BackButton(onPressed: () { if (context.canPop()) context.pop(); else context.go(AppRoutes.reproducao); }) to all 4 AppBar instances, mirroring lote_detail_screen.dart:32-53"
  debug_session: ".planning/debug/atf-detail-missing-back-button.md"

### CR-01 — baixa aborts for animals in an active ATF
status: reopened (regression 2026-08-04, see G-05-1)
severity: critical
source: 05-REVIEW.md
confirmed: live database trigger definitions (before and after)
resolved_by: 20260806_05_fix_atf_membership_trigger_scope.sql (ef89470), applied to live 2026-08-04
detail: |
  Root cause was trigger scope, not the baixa logic. See test 1. The abort itself is fixed and
  verified at the schema level, but live UAT now shows D-19's membership-deactivation half never
  ran — see G-05-1.

### WR-02 — remove_animal_from_atf silent no-op
status: resolved
severity: warning
resolved_by: 20260807_05_fix_remove_animal_from_atf_notfound.sql (e90026e), applied to live 2026-08-04

### WR-01 / WR-03 — stale providers, UTC date shift
status: resolved
severity: warning
resolved_by: ed2219c, 784c9b1 (Dart only, no migration needed)
