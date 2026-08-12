---
status: resolved
trigger: "G-06-2: eu clico em desarquivar e não desarquiva — clicking Reativar dose on an archived dose does nothing observable"
created: 2026-08-07T00:00:00Z
updated: 2026-08-07T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — live PROD doses UPDATE RLS policy still has `AND deleted_at IS NULL` in USING; the CR-01 fix (ae08dba) only edited the already-applied migration file and was never re-applied to PROD
test: documentary — commit timeline vs 06-12 apply ledger vs 06-REVIEW-FIX rationale
expecting: n/a — root cause confirmed
next_action: return diagnosis (goal: find_root_cause_only — no fix applied)

## Symptoms

expected: "Restore (Reativar dose) on an archived dose un-archives it and it returns to the active list" (UAT test 2)
actual: "eu clico em desarquivar e não desarquiva" — restore click does nothing observable; dose stays archived
errors: none reported (silent no-op)
reproduction: Sanitário > Doses tab — create dose, archive it, enable "Mostrar arquivadas", click Reativar dose
started: Discovered during UAT 2026-08-07. Phase 6 migrations applied to live PROD (pgTAP 74/74 green)

## Eliminated

- hypothesis: Client restoreDose implementation is wrong
  evidence: lib/features/sanitario/data/dose_repository.dart:110-115 correctly issues `update({'deleted_at': null}).eq('id', id)` on doses
  timestamp: 2026-08-07

- hypothesis: Missing provider invalidation after restore
  evidence: sanitario_screen.dart _toggleArchive (lines 159-168) invalidates BOTH doseListByPropertyProvider and archivedDoseListByPropertyProvider after the await
  timestamp: 2026-08-07

- hypothesis: Error swallowed by silent catch in the restore handler
  evidence: catch block shows a snackbar (not silent); and no exception is ever thrown — a zero-row UPDATE is a 2xx success in PostgREST, so the catch never fires
  timestamp: 2026-08-07

- hypothesis: Repo migration file still has the buggy policy
  evidence: current supabase/migrations/20260810_06_sanitary_module.sql:47-49 has the FIXED policy (no deleted_at clause in USING) — the file is correct; only the live DB is stale
  timestamp: 2026-08-07

## Evidence

- timestamp: 2026-08-07
  checked: git show d263fa8:supabase/migrations/20260810_06_sanitary_module.sql (original version)
  found: "veterinarian_can_update_active_dose" USING clause = `is_member_of(property_id) AND get_role(property_id) = 'veterinarian' AND deleted_at IS NULL`
  implication: under this policy, an UPDATE targeting an archived row (deleted_at NOT NULL) matches zero rows — RLS USING is evaluated against the pre-update row. PostgREST returns success with 0 rows updated. Exact silent no-op the user sees.

- timestamp: 2026-08-07
  checked: git log dates — 06-12 apply commits (ec5519b/61e60d1/b80f1f8 at 2026-08-07 01:27-01:29) vs fix commit ae08dba (2026-08-07 14:14)
  found: migration was applied to live PROD ~13 hours BEFORE the CR-01 fix commit edited the migration file
  implication: the fix never reached the live database; an already-applied migration edited in place does not re-run

- timestamp: 2026-08-07
  checked: 06-12-SUMMARY.md
  found: "Task 1 — migrations applied to live PROD ... Applied via MCP apply_migration ... 20260810_06_sanitary_module ... Ledger now at 16"; pgTAP recorded 74/74 (the PRE-fix suite size — the fix raised plan to 81)
  implication: PROD apply is confirmed and it applied the ORIGINAL (buggy) policy; the Group 12 restore regression tests added by ae08dba (plan 74→81) have never executed against PROD

- timestamp: 2026-08-07
  checked: 06-REVIEW-FIX.md CR-01 entry
  found: fixer wrote "migration not yet pushed — migration ledger confirmed 0/2 Phase 6 migrations applied as of 06-12-SUMMARY.md, so editing the migration file in place was safe"
  implication: the fixer misread the summary — it quoted the BEFORE-state table row ("14 entries, neither Phase 6 migration present") and missed "Ledger now at 16". The edit-in-place decision was made on a false premise.

- timestamp: 2026-08-07
  checked: supabase/migrations/ directory listing
  found: no migration after 20260811_06_sanitary_rpcs.sql — no ALTER POLICY hotfix exists
  implication: nothing ever re-applied the corrected policy to PROD

- timestamp: 2026-08-07
  checked: 06-REVIEW.md CR-01 finding
  found: review predicted this exact symptom: "PostgREST/RLS silently excludes any already-archived dose from being matched ... it does not raise an error, it just updates 0 rows"
  implication: UAT G-06-2 is CR-01 manifesting live — the code-level fix exists but the deployment step is missing. Archive works (pre-update row is active, USING passes); restore fails (pre-update row archived, USING rejects). Dose EDIT of an archived dose is also silently broken on PROD for the same reason.

## Resolution

root_cause: Live PROD still runs the original `veterinarian_can_update_active_dose` RLS policy with `AND deleted_at IS NULL` in its USING clause. Migration 20260810_06_sanitary_module was applied to PROD at 06-12 (2026-08-07 ~01:27) BEFORE the CR-01 fix commit ae08dba (14:14) removed that clause from the migration file. The fixer edited the already-applied migration in place, believing it unapplied (misread 06-12-SUMMARY's before-state ledger row), and no follow-up migration re-applied the policy. Restore issues `UPDATE doses SET deleted_at = NULL WHERE id = X`; RLS USING evaluates the existing archived row, `deleted_at IS NULL` is false, zero rows match, PostgREST returns success — silent no-op, no client error, providers refetch unchanged data.
fix: (not applied — find_root_cause_only) New migration with `DROP POLICY "veterinarian_can_update_active_dose" ON doses; CREATE POLICY ...` (or ALTER POLICY ... USING) matching the corrected clause already in 20260810_06_sanitary_module.sql:47-49, applied to PROD; then run the updated pgTAP suite (plan 81, incl. Group 12 restore assertions) against live.
verification: |
  APPLIED 2026-08-07. Corrective migration `20260812_06_fix_dose_update_policy` applied to live
  PROD `wrdwzychjhlpwpivfhhq` via MCP apply_migration — migration ledger 16 → 17. Forward-only;
  `20260810_06_sanitary_module` left untouched (no dev/prod drift). Post-apply catalog read
  confirms the doses UPDATE policy is membership + veterinarian only, with no
  `deleted_at IS NULL` in USING. Verified by an RLS round-trip as `authenticated` impersonating
  the real vet: the archived UAT dose restored with 1 row affected (transaction rolled back).
  pgTAP `06_sanitary_test.sql` replayed at plan 81 — all 6 Group 12 restore assertions green
  (80/81 overall; the 1 failure is Group 8's global-table-count assertion against a non-empty
  PROD, not a schema defect).
files_changed:
  - supabase/migrations/20260812_06_fix_dose_update_policy.sql
closed: 2026-08-11 (milestone v1.0 close)
