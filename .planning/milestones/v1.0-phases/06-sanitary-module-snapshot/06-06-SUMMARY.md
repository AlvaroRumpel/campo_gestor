---
phase: 06-sanitary-module-snapshot
plan: 06
subsystem: presentation
tags: [flutter, riverpod, dose-form]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-01)
    provides: sanitary_calculations.dart pure functions (dosagePerUa, costPerUa)
  - phase: 06-sanitary-module-snapshot (06-03)
    provides: Dose freezed model, DoseRepository CRUD + providers, Property.kgPerUa
provides:
  - "DoseFormDialog — create/edit dose dialog (SANI-01), the only place a dose is authored"
affects: [06-10 (SanitarioScreen Doses tab opens this dialog and owns the success SnackBar)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Live computed disabled field: persistent TextEditingController whose .text is rewritten every build() from the sibling editable field, rather than TextFormField(initialValue:) which does not refresh on rebuild"
    - "kg/UA joined client-side: currentPropertyProvider (id+name only) matched against propertyListProvider's full Property rows to reach Property.kgPerUa — no new provider added"

key-files:
  created:
    - lib/features/sanitario/presentation/dose_form_dialog.dart
  modified: []

key-decisions:
  - "Split DoseFormDialog's stateful fields across the two task commits: _saving/actions/submit landed only in Task 2 so Task 1's commit stays flutter-analyze-clean on its own (an unused-mutable-field lint would otherwise fire on a _saving field with no reassignment yet)"
  - "Inline save-failure text placed as an AlertDialog `actions` entry (no established codebase precedent for D-36's inline-error pattern in this specific dialog — sibling plans 06-05/06-07 own the other two inline-error surfaces)"

patterns-established: []

requirements-completed: [SANI-01]

coverage:
  - id: T1
    description: "Six fields render in order with exact Copywriting Contract labels; per-UA dosage/cost are disabled TextFormFields recomputed live via dosagePerUa/costPerUa; per-UA cost is absent from the tree while cost is blank; content wrapped in SingleChildScrollView"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ — No issues found"
        status: pass
      - kind: other
        ref: "grep -c 'enabled: false' dose_form_dialog.dart == 2; grep dosagePerUa/costPerUa matches; grep SingleChildScrollView matches; all six labels present"
        status: pass
    human_judgment: false
  - id: T2
    description: "Submit handler validates, resolves active property, creates/updates via DoseRepository with null (not empty-string/zero) for blank ingredient/cost, pops with true on success, renders mapped SanitaryApplicationException message inline on failure with input preserved, resets saving flag in a mounted-guarded finally"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "flutter analyze — no new issues; flutter test test/ — 248 passed"
        status: pass
      - kind: other
        ref: "grep -c ScaffoldMessenger == 0; locked Cancelar/Salvar dose/fallback-sentence strings present; all 6 declared TextEditingControllers disposed"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-08-06
status: complete
---

# Phase 6 Plan 06: Dose Form Dialog Summary

**`DoseFormDialog` — the single create/edit surface for SANI-01, with two live-recomputed read-only per-UA fields and D-11's nullable-cost semantics enforced from input through to the repository call**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 completed
- **Files modified:** 1 (created)

## Accomplishments
- `lib/features/sanitario/presentation/dose_form_dialog.dart`: `DoseFormDialog(existing: Dose?)` — one widget serving both create and edit, matching the `LoteFormDialog`/`AtfFormDialog` `AlertDialog` shell (480px width, `Form` + `SingleChildScrollView`, `TextButton`/`FilledButton` action pair with inline spinner).
- Six fields in the locked order: nome comercial (required, autofocus), princípio ativo (optional), dosagem mL/kg (required, pt-BR decimal), dosagem por UA (disabled, primary-tinted, live), custo R$/kg (optional, pt-BR decimal), custo por UA (disabled, primary-tinted, live, present only when cost parses).
- Both computed fields delegate to `dosagePerUa`/`costPerUa` from `sanitary_calculations.dart` — the formula is never restated in this file.
- `kg_per_ua` resolved by joining `currentPropertyProvider`'s selected id against `propertyListProvider`'s full `Property` rows (the only place client-side that needed `Property.kgPerUa`, since `currentPropertyProvider` only carries id+name), falling back to 400 while unresolved.
- Submit handler creates or updates via `DoseRepository`, sends `null` (never `''`/`0`) for a blank active ingredient or cost, maps any failure through `SanitaryApplicationException`/`asSanitaryException` with the dose-save fallback sentence, and renders it inline in the dialog's actions area with every controller untouched. Success pops with `true` — no `ScaffoldMessenger` in this file; the caller (06-10) owns the success SnackBar per the plan's explicit instruction.

## Task Commits

Each task was committed atomically:

1. **Task 1: Dialog scaffold, six fields, pt-BR decimal input, live computed fields** - `870b86d` (feat)
2. **Task 2: Save wiring, inline error, provider invalidation** - `d12e6c8` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified
- `lib/features/sanitario/presentation/dose_form_dialog.dart` - `DoseFormDialog` widget (create + edit)

## Decisions Made
- Deferred `_saving`/actions/submit entirely to Task 2's commit rather than stubbing them in Task 1, so Task 1's commit is independently `flutter analyze`-clean (a field declared but never reassigned yet would trigger `prefer_final_fields`).
- Read `Property.kgPerUa` by joining two already-existing providers (`currentPropertyProvider` + `propertyListProvider`) rather than adding a new provider — `propertyListProvider` already returns the full `Property` model this dialog needs, and this is the first client-side consumer of `kgPerUa` (per 06-03-SUMMARY.md).
- Placed the inline save-failure message as an `AlertDialog.actions` entry (rendered alongside Cancelar/Salvar dose) since no prior dialog in this codebase implements D-36's inline-error pattern yet — the two other inline-error surfaces (`ResumoAplicacaoDialog`, `EstornarAplicacaoDialog`) belong to sibling plans 06-07/06-05.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria in 06-06-PLAN.md passed without modification.

## Issues Encountered

None. `dart run build_runner build` was required once at session start (worktree starts with no gitignored `.freezed.dart`/`.g.dart` files) — not a deviation, per the worktree housekeeping instructions.

## User Setup Required

None. This plan only adds Dart client code; the `doses`/`sanitary_applications` schema this dialog reads/writes against (from 06-02) is still unapplied to any live database — this dialog is not exercisable against real Supabase rows until a later blocking plan applies that migration, consistent with every other Phase 6 client-only plan.

## Next Phase Readiness
- `DoseFormDialog` is ready for 06-10's `SanitarioScreen` Doses tab FAB ("Nova dose") and edit `IconButton` to open directly, and for that screen to show the "Dose salva." SnackBar on a `true` pop result.
- No routing, no `SanitarioScreen` changes, no other files touched — this plan's file boundary (`dose_form_dialog.dart` only) was respected exactly, per the sibling-awareness constraint (06-05 owns router + `aplicacao_detail_screen.dart` + `estornar_aplicacao_dialog.dart`; 06-07 owns `resumo_aplicacao_dialog.dart`).

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*

## Self-Check: PASSED

`lib/features/sanitario/presentation/dose_form_dialog.dart` verified present on disk. Both task commit hashes (`870b86d`, `d12e6c8`) verified present in `git log --oneline`.
