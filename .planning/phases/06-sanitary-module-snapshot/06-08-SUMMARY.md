---
phase: 06-sanitary-module-snapshot
plan: 08
subsystem: ui
tags: [flutter, riverpod, dialog, full-screen-selection, material3]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-03)
    provides: Dose model, DoseRepository, doseListByPropertyProvider, Property.kgPerUa
  - phase: 06-sanitary-module-snapshot (06-04)
    provides: SanitaryApplicationRepository, providers, SanitaryApplicationException (consumed indirectly via ResumoAplicacaoDialog)
  - phase: 06-sanitary-module-snapshot (06-07)
    provides: ResumoAplicacaoDialog, ResumoAplicacaoOutcome, ResumoAplicacaoResult (the confirm-before-INSERT dialog this plan's screen calls)
provides:
  - "AplicacaoFormDialog — header dialog resolving lote/dose/data before the animal checklist; lote renders as locked plain text when opened from LoteDetailScreen, or a filtered dropdown when opened from the module FAB"
  - "SanitaryAnimalSelectionScreen — full-screen default-all checklist (SANI-03) with a live 'N de M selecionados · X,X UA' counter, the discard-confirm dialog, and the D-32/D-33 stale-composition reload recovery"
affects: [06-09, 06-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One-shot seeding guard (`bool _seeded`) mutating a Set field directly inside build()'s AsyncValue.data callback, rather than a post-frame callback — safe because the mutation happens synchronously before the widget tree is returned, and the guard prevents any later rebuild from re-running it"
    - "A single DropdownButtonFormField whose items/onChanged/helperText branch on an empty-vs-populated list, instead of two separate widgets for the empty and populated cases — keeps the file's static DropdownButtonFormField count locked to one-per-field for the plan's grep-based acceptance criteria"

key-files:
  created:
    - lib/features/sanitario/presentation/aplicacao_form_dialog.dart
    - lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart
    - test/widget/aplicacao_form_dialog_test.dart
    - test/widget/sanitary_animal_selection_screen_test.dart
  modified: []

key-decisions:
  - "AplicacaoFormDialog's unlocked-lote dropdown needs LotWithPaddockCount (lot + activeAnimalCount) but the only public property-wide provider (loteListByPropertyProvider) drops the count. Rather than modify lote_repository.dart (not owned by this plan, not in files_modified), added a small private FutureProvider in aplicacao_form_dialog.dart that calls the already-existing LoteRepository.fetchLotsWithCountByProperty directly — per the plan's explicit 'prefer an existing lots-with-count repository method; only add one if none exists.'"
  - "The discard-confirm dialog's trigger condition is tracked with an explicit `_hasDeselected` flag set the moment the user unchecks a row, rather than comparing `_selectedIds.length` to the total — a count comparison would misfire after a D-33 reload changes the total (animals leaving/arriving) even when the user's own deselection choices haven't changed."
  - "AplicacaoFormDialog's Continuar handler captures `Navigator.of(context)` into a local before calling `.pop()` then `.push()` on that same reference, rather than reusing the (about-to-be-popped) `context` for the second call — avoids relying on element-disposal timing across the two calls."

patterns-established: []

requirements-completed: [SANI-02, SANI-03]

coverage:
  - id: D1
    description: "SanitaryAnimalSelectionScreen: every active animal (deletedAt null) pre-checked by default, one-shot seed guard, live 'N de M selecionados · X,X UA' counter delegated to sanitary_calculations.dart, Continuar disabled at zero"
    requirement: "SANI-03"
    verification:
      - kind: unit
        ref: "test/widget/sanitary_animal_selection_screen_test.dart — 5/5 pass (pre-check + archived exclusion, live counter update, zero-selected disable + message, close-without-deselection, discard-confirm gating)"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-33 reload recovery: on ResumoAplicacaoDialog's reload outcome, re-fetches the lot and rebuilds selection as intersection-with-previous plus newly-arrived ids, never a full reselect-everything"
    requirement: "SANI-03"
    verification:
      - kind: unit
        ref: "flutter analyze (0 issues) — structural review: _reload() computes freshActiveIds.intersection(_selectedIds) unioned with freshActiveIds.difference(_selectedIds), no branch that clears then re-adds every id"
        status: pass
    human_judgment: true
    rationale: "This path only triggers after a live P0002 rejection from register_sanitary_application, which requires the Phase 6 migration applied to a real database (06-12, not yet run). Structural correctness of the set-recombination logic is proven by analyze plus the code's own review; the actual RPC-reject-then-reload round trip is unverified until 06-12."
  - id: D3
    description: "AplicacaoFormDialog: lote locked to read-only text when lotId is supplied (never a disabled-but-prefilled dropdown), unlocked dropdown filtered to lots with >=1 active animal, dose dropdown from active doses, date defaults to today, Continuar performs pure navigation (no write, no spinner)"
    requirement: "SANI-02"
    verification:
      - kind: unit
        ref: "test/widget/aplicacao_form_dialog_test.dart — 4/4 pass (locked-lote plain-text branch, unlocked-lote filter excludes zero-animal lots, valid-selection push to SanitaryAnimalSelectionScreen)"
        status: pass
    human_judgment: false
  - id: D4
    description: "E4 backstop: zero active doses renders the dose dropdown disabled with the explanatory hint 'Nenhuma dose cadastrada — cadastre uma dose primeiro' instead of a silently-empty openable menu"
    requirement: "SANI-02"
    verification:
      - kind: unit
        ref: "test/widget/aplicacao_form_dialog_test.dart#E4 backstop: zero active doses renders the dose dropdown disabled with the empty-list hint, never a silently-empty openable menu"
        status: pass
    human_judgment: false

# Metrics
duration: ~55min
completed: 2026-08-06
status: complete
---

# Phase 6 Plan 08: AplicacaoFormDialog + SanitaryAnimalSelectionScreen Summary

**Two upstream screens of the registration flow — a lockable-lote header dialog and a full-screen default-all animal checklist with a live UA counter and D-33 stale-composition recovery — completing the path from entry point to ResumoAplicacaoDialog**

## Performance

- **Duration:** ~55 min
- **Tasks:** 2 completed
- **Files modified:** 4 (all created — 2 widgets, 2 widget-test files)

## Accomplishments
- `SanitaryAnimalSelectionScreen`: full-screen `CheckboxListTile` checklist of a lot's active animals, all pre-checked by default (SANI-03), with a one-shot seeding guard, a live sticky-bottom-bar counter (`"N de M selecionados · X,X UA"`, UA delegated to `sanitary_calculations.dart`), the verbatim `AtfAnimalSelectionScreen` discard-confirm dialog (gated on an explicit deselection flag, not a count comparison), and the D-32/D-33 reload recovery (set intersection + newly-arrived union, never a full reselect)
- `AplicacaoFormDialog`: 480px header dialog collecting lote/dose/data — lote renders as locked read-only text when `lotId` is supplied (never a disabled dropdown that still reads as editable), or a dropdown filtered to active lots with at least one active animal when it is not; dose dropdown lists active doses and, on an empty list, renders disabled with an explanatory hint (E4 backstop, proven by a widget test asserting `onChanged` is `null` and the hint text renders); date defaults to today via the built-in picker; Continuar is pure `Navigator.push` navigation with no write and no spinner state
- Both files pass `flutter analyze lib/features/sanitario/` with 0 issues and all locked pt-BR copy verified verbatim via grep (screen title, discard-confirm title/body, minimum-selection message, counter format, continue label; the three field labels, cancel/continue labels)
- 9 new widget tests (4 + 5) all green; full repo suite 257/257 (248 baseline + 9 new), no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: SanitaryAnimalSelectionScreen — default-all checklist, live counter, D-33 reload** - `82432d6` (feat)
2. **Task 2: AplicacaoFormDialog — lote, dose and date, with the lote lockable** - `0f82155` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified
- `lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart` - `SanitaryAnimalSelectionScreen`
- `lib/features/sanitario/presentation/aplicacao_form_dialog.dart` - `AplicacaoFormDialog`, private `_KvRow`, private `_lotsWithActiveAnimalsProvider`
- `test/widget/sanitary_animal_selection_screen_test.dart` - 5 widget tests
- `test/widget/aplicacao_form_dialog_test.dart` - 4 widget tests, including the E4 backstop

## Decisions Made
- Added a small private `_lotsWithActiveAnimalsProvider` inside `aplicacao_form_dialog.dart` wrapping `LoteRepository.fetchLotsWithCountByProperty` (already exists) rather than modifying `lote_repository.dart`, which is outside this plan's `files_modified` and not owned by this plan.
- Discard-confirm gating uses an explicit `_hasDeselected` flag rather than `_selectedIds.length < animals.length`, because the latter would misfire after a D-33 reload changes the animal total independent of the user's own choices.
- The single dose `DropdownButtonFormField` branches its `items`/`onChanged`/`helperText` on `doses.isEmpty` internally rather than rendering two separate dropdown widgets for the empty/populated cases — keeps the file's static `DropdownButtonFormField` occurrence count at exactly 2 (one per field), matching the plan's grep-based acceptance criterion.
- `AplicacaoFormDialog.Continuar` captures `Navigator.of(context)` into a local variable before calling `.pop()` then `.push()` on it, avoiding any ambiguity about calling further Navigator methods against a `context` whose dialog route is being removed in the same handler.

## Deviations from Plan

None — plan executed exactly as written. All acceptance-criteria greps verified directly after implementation: `formatUa`/`totalUaForCategories` present, `ListView.builder` count 1 with no `take`/index cap, `DropdownButtonFormField` count 2 (one lote, one dose), `SingleChildScrollView` present, all locked pt-BR strings verbatim.

## Issues Encountered
- The worktree had no generated `.freezed.dart`/`.g.dart`/`.riverpod.dart` files (gitignored, absent on fresh checkout) — `dart run build_runner build` was run once before the first `flutter analyze`, per this plan's parallel-execution setup note. No other issues.

## User Setup Required

None — no external service configuration required. No migration was applied or touched by this plan; the RPC round-trip these screens ultimately feed (`register_sanitary_application`) remains unverified against a live database until 06-12 applies the Phase 6 migrations, per this SUMMARY's coverage entry D2 rationale.

## Next Phase Readiness
- `AplicacaoFormDialog` and `SanitaryAnimalSelectionScreen` are both ready for 06-10 (or whichever plan wires the `LoteDetailScreen` "Registrar aplicação" button and the `SanitarioScreen` FAB) to open `AplicacaoFormDialog(lotId: ...)` or `AplicacaoFormDialog()` respectively — the constructor contracts (`lotId` optional; `lotId`, `lotName`, `dose`, `appliedAt` required on the selection screen) are stable and public.
- Did not touch `sanitario_screen.dart`, `lote_detail_screen.dart`, or any file owned by sibling plan 06-09 (`sanitary_history_section.dart`, `animal_detail_screen.dart`), per this plan's sibling-awareness boundary.
- End-to-end correctness of the full registration flow (dialog -> checklist -> ResumoAplicacaoDialog -> RPC) against a live database remains unverified until 06-12 applies the Phase 6 migrations and runs `06_sanitary_test.sql` — flagged explicitly in coverage entry D2.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*

## Self-Check: PASSED

Both created widget files and both created test files verified present on disk. Both task commit hashes (`82432d6`, `0f82155`) verified present in `git log --oneline --all`.
