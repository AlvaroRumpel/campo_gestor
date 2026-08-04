---
phase: 05-reproductive-module-loteatf
plan: 05
subsystem: ui
tags: [flutter, riverpod, go_router, reproductive]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf plan 02
    provides: AtfBatch/DgRecord models, summarizeDg/formatPrenhez, AtfRepository, atfListByPropertyProvider
  - phase: 05-reproductive-module-loteatf plan 04
    provides: AppRoutes.atfById/atfDetail(id) — the root-level /atf/:atfId route this list navigates into
provides:
  - "AtfFormDialog — the REPR-01 creation dialog (name, implantation/insemination dates, hybrid touro, observation)"
  - "ReproducaoScreen (replacement) — the /reproducao ATF list with the Mostrar-encerrados toggle and the veterinarian-only FAB"
  - "_AtfCard — the D-04 list card, driven exclusively by summarizeDg/formatPrenhez"
affects: [05-06, 05-08, 05-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hybrid select-or-external field: a DropdownButtonFormField carrying a sentinel value ('__other__') that both drives dialog-level validation and conditionally reveals a follow-up TextFormField, without a second provider/query"
    - "Widget-testing showDatePicker via its Material 3 input-mode toggle (Icons.edit_outlined) + typed text, rather than tapping a calendar day — avoids any dependency on the test run's real 'today'"

key-files:
  created:
    - lib/features/reproducao/presentation/atf_form_dialog.dart
    - test/widget/atf_form_dialog_test.dart
    - test/widget/reproducao_screen_test.dart
  modified:
    - lib/features/reproducao/presentation/reproducao_screen.dart

key-decisions:
  - "AtfFormDialog never sends both bullAnimalId and bullName on create — per the plan's explicit instruction, only one of the two hybrid-field branches is populated per submission, matching AtfRepository.createAtf's own never-both contract"
  - "Zero-animal / zero-DG ATF cards need no special-case markup for the E9 'aguardando DG, no percentage' state — summarizeDg([], compositionCount: 0) already yields total: 0, so formatPrenhez already renders '— · aguardando DG'. The shared dg_summary.dart formula is the only place that logic lives."
  - "AtfFormDialog's date fields stay read-only (matching BaixaDialog/LoteFormDialog convention) rather than becoming type-and-parse text fields for testability — the date-order widget test instead drives the real showDatePicker via its documented Material 3 input-mode toggle"

patterns-established:
  - "Pattern: a hybrid dropdown-or-textfield bull/vendor-style field lives entirely in dialog state (no extra provider), with the same Copywriting Contract string doing double duty as both the dropdown's 'nothing selected' validator and the revealed field's 'required on this path' validator"

requirements-completed: [REPR-01, REPR-04]

coverage:
  - id: D1
    description: "AtfFormDialog collects all five REPR-01 fields (name, implantation date, insemination date, hybrid touro, observation), validates insemination >= implantation and the touro either/or rule, and calls AtfRepository.createAtf with never-both bull args"
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/widget/atf_form_dialog_test.dart (7 tests: blank-form, date-order, bull-required, external-semen reveal, real-touro submit, external-semen submit, repo-throw)"
        status: pass
    human_judgment: false
  - id: D2
    description: "ReproducaoScreen replaces the /reproducao placeholder with a toggle-filtered ATF list (Mostrar encerrados), two distinct empty states, and a veterinarian-only FAB that opens AtfFormDialog and navigates to the new ATF's detail screen"
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/widget/reproducao_screen_test.dart (7 tests: zero-ATF empty, toggle-filtered empty + reveal, populated list, zero-animal card, FAB present/absent, error state)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every _AtfCard's percentage line is rendered exclusively via formatPrenhez/summarizeDg from 05-02's dg_summary.dart — no local percentage arithmetic — including the zero-DG '— · aguardando DG' case"
    requirement: "REPR-04"
    verification:
      - kind: unit
        ref: "test/widget/reproducao_screen_test.dart#zero-animal ATF: renders the aguardando-DG tail and no \"%\" string"
        status: pass
      - kind: unit
        ref: "test/widget/reproducao_screen_test.dart#populated: renders one card per ATF with the name and a \"prenhez\" string"
        status: pass
    human_judgment: false

duration: 40min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 05: ReproducaoScreen + AtfFormDialog Summary

**Replaces the `/reproducao` placeholder with the real ATF list (toggle-filtered, two empty states, D-04 cards) and adds the AtfFormDialog creation form (name, dates, hybrid touro, observation) — closing REPR-01 and ROADMAP SC-1 end to end.**

## Performance

- **Duration:** 40 min
- **Tasks:** 3
- **Files modified:** 4 (1 new source, 1 replaced source, 2 new tests)

## Accomplishments
- `AtfFormDialog` — create-only `ConsumerStatefulWidget` mirroring `LoteFormDialog`'s `AlertDialog` shell exactly: `LinearProgressIndicator` title swap while saving, `SizedBox(width: 480)` + `Form` + `SingleChildScrollView` content, `TextButton`/`FilledButton` action pair with an inline spinner
- The D-05 hybrid touro field: a `DropdownButtonFormField` populated from `animalListByPropertyProvider` filtered client-side to `category == 'touro' && deletedAt == null` (no new query), with a sentinel `'__other__'` item that reveals a required free-text field. Both branches share the exact Copywriting Contract validation string
- `ReproducaoScreen` — replaced the Phase 0 placeholder with a `ConsumerStatefulWidget`: `AsyncValue.when` over `atfListByPropertyProvider`, a "Mostrar encerrados" toggle (`AnimaisScreen`'s "Mostrar arquivados" pattern), two distinct empty states (zero ATFs vs. toggle-filtered-to-zero), and a veterinarian-only FAB (absent, not disabled) that opens `AtfFormDialog` and navigates straight to the new ATF's `/atf/:atfId` detail screen
- `_AtfCard` — the D-04 list card (name, `impl. DD/MM · insem. DD/MM · N animais` summary, `formatPrenhez` progress line + `LinearProgressIndicator`, neutral "Encerrado" chip when closed) — zero local percentage math; the zero-animal E9 state falls out of `summarizeDg`/`formatPrenhez` for free
- 14 widget tests across the two new/replaced files covering every state named in 05-UI-SPEC E1, E2, and E9

## Task Commits

Each task was committed atomically:

1. **Task 1: AtfFormDialog — the REPR-01 creation form** - `08dd116` (feat)
2. **Task 2: ReproducaoScreen — the ATF list** - `c68c347` (feat)
3. **Task 3: Widget tests for the list and the creation dialog** - `0cb4909` (test)

**Plan metadata:** committed alongside this SUMMARY (worktree mode — orchestrator finalizes STATE.md/ROADMAP.md after wave merge)

_Note: freezed's `.freezed.dart` / `.g.dart` generated parts (from 05-02's `atf_model.dart`/`dg_record_model.dart`) are gitignored and did not exist in this fresh worktree — regenerated via `dart run build_runner build` before `flutter analyze`/`flutter test` ran; not part of any commit._

## Files Created/Modified
- `lib/features/reproducao/presentation/atf_form_dialog.dart` - `AtfFormDialog`, the REPR-01 creation form
- `lib/features/reproducao/presentation/reproducao_screen.dart` - `ReproducaoScreen` (replacement), `_AtfCard`, `_EmptyNoAtfsState`, `_EmptyFilteredState`
- `test/widget/atf_form_dialog_test.dart` - 7 widget tests over every `AtfFormDialog` state (E2)
- `test/widget/reproducao_screen_test.dart` - 7 widget tests over every `ReproducaoScreen`/`_AtfCard` state (E1, E9)

## Decisions Made
- **Never-both bull args**: `AtfFormDialog._submit` passes `bullAnimalId` only when a real touro was picked from the dropdown, `bullName` only when the external-semen path was taken, never both — matching the plan's explicit instruction and `AtfRepository.createAtf`'s own contract.
- **No special-case zero-animal card markup**: `summarizeDg(const [], compositionCount: 0)` already returns `total: 0`, so `formatPrenhez` already renders `'— · aguardando DG'` with no percentage block. E9's "aguardando-DG tail, no percentage" requirement needed zero new code in `_AtfCard` — it inherits directly from the shared `dg_summary.dart` formula.
- **Date fields stay read-only, tests drive the real picker**: rather than deviating from the established `BaixaDialog`/`LoteFormDialog` read-only-TextFormField-plus-`showDatePicker` convention for testability, the date-order widget test drives the actual Material 3 `showDatePicker` dialog via its documented input-mode toggle (`Icons.edit_outlined` → type a date → "OK"), confirmed against the installed Flutter 3.41.9 SDK source rather than assumed.

## Deviations from Plan

None - plan executed exactly as written. Field order, validation copy, hybrid-touro mechanics, list layout, empty states, and the FAB role gate all match the plan's `<action>`/`<acceptance_criteria>` blocks.

## Issues Encountered
- Generated freezed/json_serializable parts for `atf_model.dart`/`dg_record_model.dart` (produced by plan 05-02 in a different worktree) were absent in this fresh worktree, per the standing gitignore convention. Ran `dart run build_runner build` once before `flutter analyze`/`flutter test` — resolved cleanly, not committed.
- `showDatePicker(locale: Locale('pt', 'BR'))` requires `GlobalMaterialLocalizations`/`GlobalWidgetsLocalizations`/`GlobalCupertinoLocalizations` delegates in the test's ambient `Localizations` (matching `main.dart`'s app-level setup) — the initial test run without `GlobalCupertinoLocalizations.delegate` threw an uncaught `FlutterError` that failed every test touching the dialog; adding the missing delegate fixed all 7 `AtfFormDialog` tests immediately.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `/reproducao` is live: a veterinarian can create an ATF and land on its (currently header-only) detail screen; REPR-01 and ROADMAP SC-1 are closed end to end.
- `ReproducaoScreen`'s FAB and `AtfFormDialog`'s success path both depend on `AppRoutes.atfDetail(id)` (05-04) — unchanged, confirmed still resolving correctly via the widget tests' router stub.
- 05-06 (composition), 05-08 (DG entry), and 05-09 (encerramento) each add a section to `atf_detail_screen.dart` in a later wave, per that file's plan-04 scope boundary — untouched by this plan.
- Live-DB verification (creating a real ATF via `flutter run -d edge` against the Supabase project) remains deferred to UAT, consistent with 05-02's/05-04's notes that the schema push is owned by plan 05-01/05-10.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

All 5 claimed files verified present on disk. All 3 task commits
(`08dd116`, `c68c347`, `0cb4909`) verified present in `git log`.
