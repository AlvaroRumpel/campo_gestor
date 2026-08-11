---
status: complete
phase: 06-sanitary-module-snapshot
source: 06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-04-SUMMARY.md, 06-05-SUMMARY.md, 06-06-SUMMARY.md, 06-07-SUMMARY.md, 06-08-SUMMARY.md, 06-09-SUMMARY.md, 06-10-SUMMARY.md, 06-11-SUMMARY.md, 06-12-SUMMARY.md
started: 2026-08-07T17:31:38Z
updated: "2026-08-07T18:25:32Z"
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test

expected: Kill any running dev server. Start the app from scratch (flutter run). App boots without errors, login works, and the Sanitário screen loads live data from Supabase (doses/aplicações tabs render, no red error screens).
result: pass

### 2. Dose Management (Doses tab)

expected: Sanitário > Doses tab. FAB creates a dose — six fields in order, per-UA dosage/cost recompute live as you type (disabled fields), per-UA cost absent while cost is blank. Save shows "Dose salva." and the card appears with computed per-UA chips. Edit works. Archive hides the dose; "Mostrar arquivadas" shows it at reduced opacity with "Arquivada" badge; restore brings it back. Edit/archive icons only visible for veterinarian role.
result: pass
previous: issue — "eu clico em desarquivar e não desarquiva" (G-06-2, fixed by 06-13; re-tested pass 2026-08-11)

### 3. Register Application (Sanitário FAB)

expected: Applications-tab FAB opens the form — lote dropdown lists only lots with ≥1 active animal, dose dropdown lists active doses, date defaults to today. Continuar (no write yet) → animal selection screen with every active animal pre-checked and live "N de M selecionados · X,X UA" counter; Continuar disabled at zero selected. → Resumo dialog shows totals (animal count · UA, volume with mL/L threshold, cost only when dose has cost) and the always-on permanence warning. Confirmar → success snackbar "Aplicação registrada — N animais" (correct singular/plural) and the application appears in the list.
result: pass

### 4. Duplicate Detection Warning (D-34)

expected: Register an identical application (same lote, dose, date) again. Resumo dialog shows a warning box requiring an acknowledgement checkbox; Confirmar stays disabled until checked.
result: pass

### 5. Register from Lote Detail

expected: Lote detail screen shows "Registrar aplicação" footer button (visible only for veterinarian on an active lot with active animals — absent, not disabled, otherwise). Opens the same form with the lote locked as read-only text (not a dropdown). Completing the flow shows the success snackbar with animal count and the lote's application history updates.
result: pass

### 6. Applications Tab Filters

expected: Applications tab — lote/dose/período filters and animal chip narrow the list. "Mostrar estornadas" toggle hides/shows reversed applications. Empty state distinguishes "no applications at all" from "no matches for filter". Cards show mutually-exclusive Estornada/Estorno badges and omit the cost segment when dose has no cost.
result: pass

### 7. Application Detail Screen

expected: Tapping an application opens the detail screen — header card with status chip, key-value rows (custo/observação rows omitted when absent), totals line, and the full composition list rendering as one continuous page scroll (no nested inner scrollbar).
result: pass

### 8. Estorno (Reversal)

expected: Veterinarian sees the estorno action on an application (non-veterinarian sees nothing — absent, not disabled). Dialog requires a motivo (blank blocked inline), destructive-red confirm button. On success the original shows "Estornada", a linked estorno row appears, and history/list totals reflect it. Attempting to reverse an estorno row or an already-reversed application is blocked with a pt-BR message (no raw database error text anywhere).
result: pass

### 9. Animal Ficha — Histórico Sanitário

expected: Animal detail screen's Histórico Sanitário section shows real application rows for that animal (replacing the placeholder), with badges and the estornadas toggle behaving like the main list.
result: pass
previous: issue — PostgREST 22P02 on per-animal containment filter, section stuck on spinner (G-06-9, fixed by 06-14; re-tested pass 2026-08-11)

### 10. Lote Detail — Histórico Sanitário

expected: Lote detail screen shows a Histórico Sanitário section below the animal list, same visual shape as the animal variant (shared widget).
result: pass

### 11. Composition-Changed Recovery (D-33)

expected: (Hard to trigger — OK to skip.) With the resumo dialog open, archive or move one of the selected animals from another tab/session, then Confirmar. An inline error appears with a "Recarregar" action; reloading preserves your previous selection (intersection + newly-arrived animals), not a full reselect-everything.
result: pass

## Auto-Passed (source: automated)

Coverage-block entries deterministically covered by passing tests — not presented to the user:

- 06-01 D1 — sanitary calculation module (12 behaviors, 2 unit test files) [SANI-01]
- 06-02 D2 — properties.kg_per_ua default 400 [SANI-01]
- 06-02 D6 — GIN jsonb_path_ops index [SANI-05]
- 06-03 D1 — Dose freezed model [SANI-01]
- 06-03 D2 — Property.kgPerUa @Default(400) [SANI-01]
- 06-04 D1 — SanitaryApplication models + list helpers (6 unit tests) [SANI-04]
- 06-05 D1 — AppRoutes.aplicacaoById routes [SANI-04]
- 06-06 T1 — dose form fields/labels/live per-UA computation [SANI-01]
- 06-06 T2 — dose form submit handler [SANI-01]
- 06-07 D1 — ResumoAplicacaoDialog totals delegated to calculations module [SANI-02]
- 06-08 D1 — animal selection screen (5 widget tests) [SANI-03]
- 06-08 D3 — AplicacaoFormDialog (4 widget tests) [SANI-02]
- 06-08 D4 — E4 zero-doses backstop (widget test) [SANI-02]
- 06-10 T1 — tab shell, role-gated FABs, query-param seeding [SANI-04]
- 06-10 T3 — doses tab rendering/toggles [SANI-01]
- 06-11 D2 — LoteSanitaryHistorySection placement [SANI-04]

Resolved by 06-12 live wave (migrations applied to PROD, pgTAP 74/74 + 5/5 green) — original rationale deferred exactly to this evidence:

- 06-01 D2 — pgTAP suite executes green (74/74 against live PROD) [SANI-02]
- 06-02 D1 — doses table RLS/constraints/soft delete (pgTAP) [SANI-01]
- 06-02 D3 — server-authoritative totals recomputation (pgTAP) [SANI-02]
- 06-02 D4 — D-32 concurrency abort P0002 (pgTAP) [SANI-03]
- 06-02 D5 — reversal blocks: reversal-of-reversal, blank reason, double reversal (pgTAP) [SANI-02]

## Summary

total: 11
passed: 11
issues: 0
pending: 0
skipped: 0
blocked: 0
resolved: 2

## Gaps

- gap_id: G-06-2
  truth: "Restore (Reativar dose) on an archived dose un-archives it and it returns to the active list"
  status: resolved
  resolved_by: 06-13-PLAN.md
  resolved_at: 2026-08-10
  reason: "User reported: eu clico em desarquivar e não desarquiva"
  severity: major
  test: 2
  root_cause: "Live PROD still runs the original veterinarian_can_update_active_dose RLS policy with 'AND deleted_at IS NULL' in USING. Migration 20260810_06 was applied during 06-12 (~01:27) 13h BEFORE fix ae08dba (14:14) edited the already-applied migration file in place; no follow-up migration re-applied the corrected policy. RLS USING evaluates the pre-update row, so UPDATE on an archived dose matches 0 rows — 2xx success, silent no-op. Dart code (repository + invalidation) is correct."
  artifacts:
    - path: "supabase/migrations/20260810_06_sanitary_module.sql"
      issue: "lines 47-49 fixed on disk but never applied to PROD (applied migrations don't re-run)"
  missing:
    - "New migration (e.g. 20260812_06_fix_dose_update_policy.sql) with DROP POLICY + CREATE POLICY using corrected USING clause"
    - "Apply to PROD and replay updated pgTAP suite (81 assertions incl. Group 12 restore regression)"
  debug_session: ".planning/debug/dose-restore-noop.md"

- gap_id: G-06-9
  truth: "Animal ficha's Histórico Sanitário section loads real application rows via the per-animal containment lookup (composition_snapshot @> filter over GIN index)"
  status: resolved
  resolved_by: 06-14-PLAN.md
  resolved_at: 2026-08-10
  reason: "User reported: per-animal sanitary_applications requests fail with PostgREST 22P02 'invalid input syntax for type json — Expected \":\", but found \"}\"' — the containment filter JSON sent by the repository is malformed; section spins forever"
  severity: blocker
  test: 9
  root_cause: "fetchSanitaryHistoryByAnimal calls .contains('composition_snapshot', [{'animal_id': animalId}]) with a Dart List. postgrest-dart 2.7.0 encodes List as a Postgres array literal via _cleanFilterArray (Map.toString, unquoted keys) — request carries cs.{\"{animal_id: <uuid>}\"} which Postgres rejects as invalid json (22P02). Only a String value bypasses the array encoding. Secondary: Riverpod 3.3.1 default auto-retry (~10 attempts) re-issues the deterministic failure, keeping the section on a spinner instead of showing the error."
  artifacts:
    - path: "lib/features/sanitario/data/sanitary_application_repository.dart"
      issue: "lines 88-95 — containment value passed as List, must be pre-encoded JSON string"
  missing:
    - "Change to .contains('composition_snapshot', jsonEncode([{'animal_id': animalId}])) so postgrest forwards cs.[{\"animal_id\":\"<uuid>\"}] verbatim"
    - "Optionally limit provider retry for non-transient PostgrestExceptions so the error state renders"
  debug_session: ".planning/debug/animal-history-22p02.md"
