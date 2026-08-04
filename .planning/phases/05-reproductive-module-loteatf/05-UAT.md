---
status: partial
phase: 05-reproductive-module-loteatf
source: [05-VERIFICATION.md, 05-REVIEW.md]
started: 2026-08-04T00:00:00Z
updated: 2026-08-04T00:10:00Z
---

## Current Test

[testing complete — blocked on test 1 regression]

## Tests

### 1. CR-01 / D-19: baixa on an animal in an active ATF
expected: |
  Baixa succeeds for an animal that is a member of an active ATF, and that animal's
  membership is deactivated in the same transaction (D-19).
result: issue
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
expected: All 26 assertions in `supabase/tests/05_reproductive_test.sql` pass against a real Postgres engine, proving trg_atf_membership_valid (23514 category / 23503 cross-property), the partial unique index (23505 duplicate-active), dg_records_result_check (22023), D-08 hard-delete-then-refuse, D-16 closed-ATF-still-correctable, and D-19 baixa-deactivates-membership.
why_human: Never executed in any session — `docker info` fails on this machine, so `supabase test db` cannot start. The SQL was verified by reading only; the assertions have zero runtime evidence.
command: `supabase test db`
result: blocked
blocked_by: prior-phase
reason: "Gated by test 1's D-19 regression -- no point running suite until membership-deactivation is fixed."

### 3. Twelve-step live UAT (05-10-PLAN.md Task 3)
expected: All twelve steps behave as described in 05-10-PLAN.md; explicit approval or a list of failing steps.
why_human: The phase's own designated blocking checkpoint (`gate="blocking"`, `autonomous: false`), still open. Also the only coverage the five RPCs' 42501 role guards get, since pgTAP runs as superuser with no JWT to impersonate (A-PGTAP-ROLE).
steps: |
  1.  flutter run -d edge against the live project
  2.  Sign in as veterinarian, open Reprodução — list renders (empty state), not an error
  3.  Create an ATF (name, both dates, touro or "Outro / sêmen externo") -> lands on detail screen
  4.  "+ Animais", pick a lote base — only vacas and novilhas listed
  5.  Add the same animal to a SECOND ATF — greyed out with "já em ATF [nome]", unselectable (SC-2)
  6.  Mark DG chips for two animals, set session date, "Salvar DGs" — header % updates immediately (SC-4)
  7.  Re-mark a chip on an animal that already has a DG — % reflects the new result, earlier record still exists
  8.  Open that animal's ficha — Histórico Reprodutivo lists the ATF with its last DG; tapping navigates to /atf/:atfId
  9.  Register a baixa on an animal in an active ATF — must succeed, animal drops out of composition  [FAILED — see test 1]
  10. Sign in as non-veterinarian — FAB, "+ Animais", remove icons, "Salvar DGs", encerrar are ABSENT (not greyed)
  11. As veterinarian, once every animal has a DG the banner appears; use it to encerrar. Composition/encerrar controls vanish, DG chips stay interactive (D-16)
  12. Add a released animal to a NEW ATF — now selectable
result: blocked
blocked_by: prior-phase
reason: "Step 9 already confirmed failing by test 1 — rest of the walkthrough waits on the fix."

### 4. Confirm the DG tie-breaker with a veterinarian (A-DG-ORDER)
expected: Either confirmation that `created_at` is correct, or a one-line change to `exam_date`.
why_human: Open domain question since 05-RESEARCH.md, repeated in STATE.md's TODO list. A wrong tie-breaker silently misreports % prenhez and the ficha's "last DG" in exactly the reexam-correction scenario D-12 exists for. No test can decide which is domain-correct.
isolated_to: `summarizeDg` / `fetchReproductiveHistory` (one line)
result: [pending]

## Summary

total: 4
passed: 0
issues: 1
pending: 1
skipped: 0
blocked: 2

## Gaps

- gap_id: G-05-1
  truth: "Baixa on an animal in an active ATF deactivates that animal's membership in the same transaction (D-19)."
  status: failed
  reason: "User reported: Dei baixa na Vaca #2 enquanto ela estava em um ATF, ela continuou no ATF ativo, mas não aparece mais nos animais, nem nos lotes."
  severity: blocker
  test: 1
  artifacts: []
  missing: []

- gap_id: G-05-1-nav
  truth: "ATF detail screen has a way back to the previous screen."
  status: failed
  reason: "User reported: não tem botão de voltar."
  severity: minor
  test: 1
  artifacts: []
  missing: []

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
