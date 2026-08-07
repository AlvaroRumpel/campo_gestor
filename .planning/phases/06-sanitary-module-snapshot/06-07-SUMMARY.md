---
phase: 06-sanitary-module-snapshot
plan: 07
subsystem: ui
tags: [flutter, riverpod, dialog, intl-plural, material3]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-04)
    provides: SanitaryApplicationRepository (registerApplication, findRecentIdenticalApplication, five providers), SanitaryApplicationException/asSanitaryException (D-35)
  - phase: 06-sanitary-module-snapshot (06-01)
    provides: sanitary_calculations.dart pure helpers (totalUaForCategories, totalVolumeMl, totalCost, formatUa, formatVolumeMl, formatCurrencyBrl)
  - phase: 06-sanitary-module-snapshot (06-03)
    provides: Dose model, Property.kgPerUa field
provides:
  - "ResumoAplicacaoDialog — the confirm-before-INSERT dialog: totals preview, permanence warning, D-34 duplicate-detection gate, the single register_sanitary_application call, and the D-35/D-36 inline error slot with the composition-changed 'Recarregar' recovery action"
  - "ResumoAplicacaoOutcome + ResumoAplicacaoResult — the public outcome contract 06-09's SanitaryAnimalSelectionScreen branches on (registered-with-count vs. reload vs. plain-back null)"
affects: [06-09, 06-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "First use of Intl.plural in this codebase (explicit locale: 'pt_BR' on every call) for the totals animal-count line and the deselected-count line"
    - "Dialog-inline-error slot (D-36): error rendered as colorScheme.error text inline in the dialog body, never a SnackBar, with a conditional TextButton recovery action gated on the exception's reason enum"

key-files:
  created:
    - lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart
  modified: []

key-decisions:
  - "The plan's 'small public enum for the outcome' (ResumoAplicacaoOutcome, two values: registered/reload) can't itself carry the registered count as a compile-time enum value, so the dialog actually pops a small ResumoAplicacaoResult(outcome, {animalCount}) wrapper — null still means a plain 'Voltar' back action, and 06-09 branches on result.outcome exactly as the plan describes"
  - "kgPerUa (D-12) has no dedicated provider — currentPropertyProvider only exposes a SelectedProperty id+name shell. Resolved by watching propertyListProvider (full Property list, has kgPerUa) and matching on the active property's id, defaulting to 400 while either is still loading — a display-only preview figure, never sent to the server, so the brief default window during initial load is harmless"
  - "Both plan tasks landed in a single commit: the file is new, and Task 2's actions/error-slot are wired directly into Task 1's build() method (the confirm button, back button and _confirm handler make no sense to author or verify as a separable half-file state) — splitting into two commits would have meant committing a temporarily-broken dialog with no way to dismiss or confirm it"

patterns-established:
  - "Pattern: a dialog's outcome contract is a small (enum, wrapper-class-with-optional-payload) pair rather than forcing the payload onto the enum itself, whenever the pop value needs to distinguish more than one non-null 'reason' AND carry data for only one of them"

requirements-completed: [SANI-02, SANI-03]

coverage:
  - id: D1
    description: "ResumoAplicacaoDialog: totals preview (Intl.plural animal count · UA, volume with mL/L threshold, conditional cost) delegated entirely to sanitary_calculations.dart, never re-derived inline"
    requirement: "SANI-02"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ (0 issues) — grep totalUaForCategories|totalVolumeMl|totalCost|formatVolumeMl all present, delegated not re-derived"
        status: pass
    human_judgment: false
  - id: D2
    description: "Always-on permanence warning (D-23) and D-34 duplicate-detection gate: identical-application lookup in initState, tertiary-container warning box with acknowledgement checkbox, confirm button disabled while the warning shows and the box is unchecked"
    requirement: "SANI-02"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ (0 issues) — locked strings present, lookup failure path sets held id to null"
        status: pass
    human_judgment: true
    rationale: "The duplicate-detection query and the RPC round-trip are only exercisable against a live Supabase project — the migrations from 06-02 are authored on disk but not yet applied to any database (owned by the 06-12 blocking wave). Structural correctness (query shape, error handling, disabled-state logic) is proven by analyze + the widget compiling against the real repository/exception types; end-to-end correctness against a live P0002/duplicate row requires 06-12."
  - id: D3
    description: "Single register_sanitary_application call with in-flight guards on both actions, provider invalidation (property/lot/per-animal history), inline D-35/D-36 error slot with the composition-changed 'Recarregar' recovery action, no ScaffoldMessenger in this dialog"
    requirement: "SANI-03"
    verification:
      - kind: unit
        ref: "flutter test (248/248 repo-wide green) + flutter analyze lib/features/sanitario/ (0 issues) — grep ScaffoldMessenger count 0, ref.invalidate count 3, register call passes only ids/date/list"
        status: pass
    human_judgment: true
    rationale: "The RPC call itself, its ERRCODE mapping against a live PostgrestException, and the actual write-then-invalidate round trip cannot be exercised until 06-12 applies the Phase 6 migration to a real database. This plan proves the Dart-side contract (call shape, disabled-state logic, exactly-once invalidation) compiles and analyzes clean against the real repository/exception types authored in 06-04."

# Metrics
duration: 35min
completed: 2026-08-06
status: complete
---

# Phase 6 Plan 07: ResumoAplicacaoDialog Summary

**Confirm-before-INSERT dialog with a totals preview delegated to sanitary_calculations.dart, an always-on permanence warning, a D-34 duplicate-detection gate with extra confirmation, the single register_sanitary_application RPC call, and a D-35/D-36 inline error slot with the composition-changed "Recarregar" recovery action**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 (landed in one commit — see Decisions Made)
- **Files modified:** 1 (created)

## Accomplishments
- `ResumoAplicacaoDialog`: 480px `AlertDialog` showing dose/lote/date key-value rows (wrapping, not truncating), a totals block (`Intl.plural` animal count · UA, volume with the mL/L 1000 threshold, cost omitted when the dose has no known cost), a deselected-count line (`Intl.plural`, omitted at zero), the always-on permanence warning, and the D-34 duplicate-detection warning with its required acknowledgement checkbox
- Duplicate-application lookup fires in `initState` via `findRecentIdenticalApplication`; a failed lookup is treated as "no duplicate found" rather than surfaced as an error
- Confirm handler calls `registerApplication` with only ids/date/list (no client-computed total ever leaves the device — T-06-02), invalidates the property list, the lot's applications, and every selected animal's sanitary history provider, then pops with `ResumoAplicacaoResult(registered, animalCount: N)`
- Inline error slot (D-36): the mapped `SanitaryApplicationException.message` in `colorScheme.error`, with a "Recarregar" `TextButton` shown only for the composition-changed reason, popping with the `reload` outcome — no `ScaffoldMessenger` anywhere in this file
- Both the back and confirm buttons are disabled while saving (double-tap guard); confirm is additionally disabled while the duplicate warning shows and its checkbox is unticked
- `ResumoAplicacaoOutcome` (registered/reload) + `ResumoAplicacaoResult` (outcome + optional animal count) declared top-level and public — the exact contract 06-09's `SanitaryAnimalSelectionScreen` will branch on

## Task Commits

Both tasks landed in a single commit (see Decisions Made for why):

1. **Task 1 + Task 2: dialog shell, totals, permanence/duplicate warnings, registration call, error slot** - `fdf341b` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified
- `lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart` - `ResumoAplicacaoDialog`, `ResumoAplicacaoOutcome`, `ResumoAplicacaoResult`, private `_KvRow`

## Decisions Made
- The plan asks for "a small public enum for the outcome, with two values." A bare Dart enum value can't carry a runtime int, but the plan also requires the registered outcome to "carry the number of animals." Resolved with `ResumoAplicacaoOutcome` (the two-value enum the plan describes, `registered`/`reload`) plus a thin `ResumoAplicacaoResult(outcome, {animalCount})` wrapper that the dialog actually pops — `null` still means a plain "Voltar," and the caller branches on `result.outcome` exactly as specified.
- `currentPropertyProvider` only exposes a `SelectedProperty` id+name shell — `kgPerUa` (D-12) lives on the full `Property` model from `propertyListProvider`. The dialog resolves it by matching the active property's id against that list, defaulting to 400 while either provider is still loading. This is a display-only preview value (the RPC re-derives it server-side), so a brief default window on first paint is harmless.
- Both plan tasks were committed together: the file is new and Task 2's actions/confirm-handler/error-slot are wired directly into Task 1's `build()` method — there is no meaningful intermediate state where Task 1 alone would compile into a usable (dismissable/confirmable) dialog. Splitting into two commits would have meant committing a temporarily non-functional widget.

## Deviations from Plan

None — plan executed exactly as written. All acceptance-criteria greps verified directly after implementation: `Intl.plural` count 2, `ScaffoldMessenger` count 0, `ref.invalidate` count 3, totals-delegation grep (`totalUaForCategories|totalVolumeMl|totalCost|formatVolumeMl`) all present, all locked pt-BR strings present verbatim (title, permanence warning, duplicate warning, checkbox label, back/confirm/recovery labels, generic-failure sentence).

## Issues Encountered

None. `flutter analyze lib/features/sanitario/` reports 0 issues; `flutter test` passes 248/248 repo-wide (no regressions in sibling test suites).

## User Setup Required

None — no external service configuration required. No migration was applied (06-02's migrations remain on-disk-only, owned by the 06-12 blocking wave per the phase's critical_scope_note); this plan's coverage entries D2/D3 flag that the RPC round-trip and duplicate-lookup correctness against a live database are unverified until then.

## Next Phase Readiness
- `ResumoAplicacaoDialog` is ready for 06-09's `SanitaryAnimalSelectionScreen` to `showDialog` with real `Dose`/`Animal` data — the constructor contract (`lotId`, `lotName`, `dose`, `appliedAt`, `selectedAnimals`, `deselectedCount`) and the `ResumoAplicacaoResult` return contract are both stable and public.
- Did not create `SanitaryAnimalSelectionScreen` (06-09, next wave) or touch any file owned by sibling plans 06-05/06-06, per this plan's sibling-awareness boundary.
- End-to-end correctness of the RPC call, the duplicate lookup, and the exception mapping against live SQLSTATEs remains unverified until 06-12 applies the Phase 6 migrations and runs `06_sanitary_test.sql` — flagged explicitly in this SUMMARY's `coverage` entries D2/D3.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*

## Self-Check: PASSED

`lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart` verified present on disk. Commit `fdf341b` verified present in `git log --oneline --all`.
