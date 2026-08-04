---
status: testing
phase: 05-reproductive-module-loteatf
source: [05-VERIFICATION.md, 05-REVIEW.md]
started: 2026-08-04T00:00:00Z
updated: 2026-08-04T00:00:00Z
---

## Current Test

number: 1
name: Fix and re-apply CR-01 before any other testing
expected: |
  Baixa succeeds for an animal that is a member of an active ATF, and that animal's
  membership is deactivated in the same transaction (D-19).
awaiting: user response

## Tests

### 1. [BLOCKER — fix first] CR-01: baixa fails for any animal in an active ATF
expected: Registering a baixa on an animal with an active ATF membership succeeds and deactivates that membership.
actual: Fails with SQLSTATE 23503 "animal ... not found or is archived"; the whole transaction aborts.
cause: |
  `trg_atf_membership_valid` is `BEFORE INSERT OR UPDATE` on `animal_atf_memberships`, and
  `enforce_atf_membership_valid()` re-checks `animals.deleted_at IS NULL`. The D-19 chain is:
  register_baixa sets deleted_at -> AFTER trigger UPDATEs the membership -> that UPDATE fires the
  BEFORE trigger -> the animal is already archived -> exception -> transaction aborts.
  Only bites when the animal HAS an active membership, i.e. precisely the D-19 case.
confirmed_against: live database (pg_get_triggerdef on wrdwzychjhlpwpivfhhq) and 05-REVIEW.md CR-01
would_have_been_caught_by: supabase/tests/05_reproductive_test.sql:99-112 (never executed — no Docker)
blocks: UAT step 9 below
result: [pending]

### 2. Run the pgTAP suite
expected: All 26 assertions in `supabase/tests/05_reproductive_test.sql` pass against a real Postgres engine, proving trg_atf_membership_valid (23514 category / 23503 cross-property), the partial unique index (23505 duplicate-active), dg_records_result_check (22023), D-08 hard-delete-then-refuse, D-16 closed-ATF-still-correctable, and D-19 baixa-deactivates-membership.
why_human: Never executed in any session — `docker info` fails on this machine, so `supabase test db` cannot start. The SQL was verified by reading only; the assertions have zero runtime evidence.
command: `supabase test db`
result: [pending]

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
  9.  Register a baixa on an animal in an active ATF — must succeed, animal drops out of composition  [BLOCKED BY TEST 1]
  10. Sign in as non-veterinarian — FAB, "+ Animais", remove icons, "Salvar DGs", encerrar are ABSENT (not greyed)
  11. As veterinarian, once every animal has a DG the banner appears; use it to encerrar. Composition/encerrar controls vanish, DG chips stay interactive (D-16)
  12. Add a released animal to a NEW ATF — now selectable
result: [pending]

### 4. Confirm the DG tie-breaker with a veterinarian (A-DG-ORDER)
expected: Either confirmation that `created_at` is correct, or a one-line change to `exam_date`.
why_human: Open domain question since 05-RESEARCH.md, repeated in STATE.md's TODO list. A wrong tie-breaker silently misreports % prenhez and the ficha's "last DG" in exactly the reexam-correction scenario D-12 exists for. No test can decide which is domain-correct.
isolated_to: `summarizeDg` / `fetchReproductiveHistory` (one line)
result: [pending]

## Summary

total: 4
passed: 0
issues: 1
pending: 4
skipped: 0
blocked: 0

## Gaps

### CR-01 — baixa aborts for animals in an active ATF
status: failed
severity: critical
source: 05-REVIEW.md
confirmed: live database trigger definitions
detail: See test 1 above. Blocks D-19 and UAT step 9.
