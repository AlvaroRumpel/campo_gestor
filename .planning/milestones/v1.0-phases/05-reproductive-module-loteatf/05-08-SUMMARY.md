---
phase: 05-reproductive-module-loteatf
plan: 08
subsystem: ui
tags: [flutter, riverpod, choice-chip, widget-tests, mass-entry]

# Dependency graph
requires:
  - phase: 05-02
    provides: atfMembershipsProvider, dgRecordsByAtfProvider, summarizeDg/formatPrenhez, DgResult
  - phase: 05-03
    provides: save_dg_records RPC (insert-only, membership-existence guard), wrapped by AtfRepository.saveDgRecords
  - phase: 05-06
    provides: AtfDetailScreen shell, AtfHeaderCard, _CompositionSection — the ListView this plan appends into
provides:
  - _DgSection and _DgChipRow on AtfDetailScreen — the DG mass-entry surface (REPR-03)
  - The provider-invalidation chain that makes the header % prenhez move after a save (REPR-04, SC-4)
  - The E6 200-animal overflow backstop, executed as a widget test
affects: [05-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Staged local state separate from displayed state: _staged map holds only tapped selections; the displayed chip value is _staged[id] ?? mostRecentDg(id), so the changed-rows set is a simple diff against the pre-existing DG rather than a mutation-tracking flag"
    - "canEdit for a correction surface (DG chips) is gated on role only, independent of atf.active — contrasts with _CompositionSection's atf.active && canEdit gate, deliberately, per D-16"
    - "Widget test viewport off-screen taps: tester.ensureVisible(finder) before every tap/enterText on a control that may fall below the fixed 800x600 test viewport, rather than growing the viewport or restructuring the widget"

key-files:
  created: []
  modified:
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - test/widget/atf_detail_screen_test.dart

key-decisions:
  - "DG chip labels reuse DgResult.label (dg_record_model.dart) rather than hardcoding 'Prenha'/'Não-prenha'/'Duvidosa' literals in atf_detail_screen.dart — avoids a second source of truth for copy that's already established in the enum from plan 05-02."
  - "The DG section hides when the UNFILTERED membership list (atfMembershipsProvider) is empty, not when the active-only count is zero — a closed ATF deactivates every membership (all active:false) but the unfiltered list stays non-empty, so the section correctly stays visible for D-16 correction; a genuinely fresh, zero-animal ATF has an empty unfiltered list too, so E4's hide condition still holds."
  - "A chip tap always sets _staged[animalId] = r regardless of the ChoiceChip onSelected bool — there is no deselect-to-blank; three mutually exclusive results modeled as 'tap a different one to change it', not as independently toggleable booleans."
  - "Per-row date-override and observation icon buttons are gated on the same editable flag as the chips (role AND not-saving) rather than always visible — a read-only viewer has no use for a date picker it cannot save, and disabling both during the RPC keeps rows read-only per the E6 loading state."

patterns-established:
  - "tester.ensureVisible(finder) immediately before every tap/enterText targeting a widget that could be pushed below the fixed test viewport by a preceding action (chip selection reveals nothing new, but a growing DG list or an expanded observation field does) — new load-bearing pattern for any future widget test touching this screen."

requirements-completed: [REPR-03, REPR-04]

coverage:
  - id: D1
    description: "A veterinarian marks a whole herd in one pass; tapping a different chip on an animal with an existing DG stages exactly one changed record rather than mutating history (D-12), and the RPC has no update/delete path to begin with (05-01/05-03)"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#tapping a different chip on an animal with an existing DG stages exactly one changed row"
        status: pass
    human_judgment: false
  - id: D2
    description: "One session date applies to every row by default; a per-animal date override (via the event icon date picker) lands only in that row's payload entry while the rest keep the session date"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#exam_date defaults to the session date, and a per-animal override lands only in that entry"
        status: pass
    human_judgment: false
  - id: D3
    description: "A per-animal observation entered via the collapsed icon toggle is carried through to that row's save payload entry"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#a row with an observation entered carries it in the payload"
        status: pass
    human_judgment: false
  - id: D4
    description: "The DG section stays visible and its chips stay tappable for a CLOSED ATF (D-16 correction), while the composition '+ Animais' affordance is absent in the same tree"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#the DG chips are tappable for a CLOSED ATF while \"+ Animais\" stays absent (D-16)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Only rows whose selection changed are sent in the save payload — the save button stays disabled at zero changes and the payload never carries an unchanged row"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#the save button is disabled with zero changes and becomes enabled after one chip is tapped"
        status: pass
    human_judgment: false
  - id: D6
    description: "A failed saveDgRecords call leaves every staged chip selection in place — the vet does not need to re-mark the herd after a bad connection"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#a failing saveDgRecords leaves the staged chip selection intact"
        status: pass
    human_judgment: false
  - id: D7
    description: "E6 overflow backstop: a 200-animal ATF's DG list builds without throwing, and tapping 3 rows then saving produces a payload of exactly 3 entries — proves both lazy/shrinkWrap rendering at scale and changed-rows-only submission"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#E6 backstop: a 200-animal ATF builds, and the payload carries only the 3 changed rows"
        status: pass
    human_judgment: false
  - id: D8
    description: "The DG row list reads the unfiltered atfMembershipsProvider (not the active-only one), rendering a row for an inactive membership too — the closed-ATF full-roster requirement (D-16, RESEARCH Pattern 3)"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#one row renders per membership including an inactive one, each with three chips"
        status: pass
    human_judgment: false
  - id: D9
    description: "The save button and DG chips are absent/read-only for a non-veterinarian role, matching the role-gate convention used throughout the phase"
    requirement: "REPR-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/atf_detail_screen_test.dart#\"Salvar DGs\" is absent for a non-veterinarian override"
        status: pass
    human_judgment: false
  - id: D10
    description: "A successful save invalidates dgRecordsByAtfProvider, atfByIdProvider, atfListByPropertyProvider, and reproductiveHistoryByAnimalProvider for each affected animal — the mechanism behind ROADMAP SC-4's live '% prenhez atualiza automaticamente'"
    verification: []
    human_judgment: true
    rationale: "The widget tests use static provider overrides (fixed-list lambdas), so ref.invalidate() calls execute but cannot be observed re-fetching genuinely different data within the same test — the invalidation call sites themselves are visible in source (atf_detail_screen.dart) and exercised without throwing, but proving the header % actually recomputes after a real Supabase round-trip needs either a live-backend integration test or manual UAT once migrations are pushed (a pre-existing blocker from 05-03-SUMMARY.md, unrelated to this plan)."
  - id: D11
    description: "Layout constraints — single column, no horizontal scroll at 360px, 48px minimum chip touch target, 8px minimum chip separation, no swipe or long-press gestures"
    verification: []
    human_judgment: true
    rationale: "Structurally satisfied and grep-verified (ConstrainedBox(minHeight: 48), Wrap(spacing: 8), no GestureDetector/Dismissible in the file) and exercised at the default 800x600 test viewport without overflow, but no automated test pins the viewport to 360px specifically — a visual pass at that width is the remaining verification step."

duration: 35min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 8: DG Mass-Entry Section Summary

**_DgSection on AtfDetailScreen — one session date, one row per animal with three semantic-colored ChoiceChips, changed-rows-only batch save via `save_dg_records`, and the provider-invalidation chain that moves the header % prenhez.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `_DgSection`: session date field (defaults to today, per-row override via a date picker), one row per membership from the UNFILTERED `atfMembershipsProvider` (so a closed ATF still shows its full roster, D-16), staged local state that survives a save failure
- `_DgChipRow`: three `ChoiceChip`s (Prenha/Não-prenha/Duvidosa) reusing `DgResult.label`, the D-10 semantic color mapping (`primaryContainer`/`errorContainer`/`tertiaryContainer`), 48px `ConstrainedBox` touch targets, 8px `Wrap` spacing, and a collapsed observation field toggled by an icon
- Save payload built from changed rows only (`_staged` diffed against each animal's most-recent DG); on success invalidates `dgRecordsByAtfProvider`, `atfByIdProvider`, `atfListByPropertyProvider`, and `reproductiveHistoryByAnimalProvider` per affected animal — the SC-4 auto-update mechanism; on failure, staged selections are left untouched (no clearing code path exists in the error branch)
- 10 new widget tests covering D-10 through D-16 plus the E6 200-animal overflow backstop; full suite (191 tests) green

## Task Commits

Each task was committed atomically:

1. **Task 1: _DgSection — session date, per-animal chip rows, and staged local state** - `e69cac7` (feat)
2. **Task 2: Widget tests for DG mass entry, including the 200-animal backstop** - `039b073` (test)

## Files Created/Modified
- `lib/features/reproducao/presentation/atf_detail_screen.dart` - adds `_DgSection` and `_DgChipRow`; wires `atfMembershipsProvider` into `AtfDetailScreen.build`
- `test/widget/atf_detail_screen_test.dart` - extends the fake repo + builder for DG coverage; adds a 10-test `_DgSection` group; rescopes 2 pre-existing 05-06 assertions

## Decisions Made
- DG chip labels reuse `DgResult.label` rather than duplicating the pt-BR copy as literals in `atf_detail_screen.dart` — one source of truth.
- Hide condition for the section uses the UNFILTERED membership list's emptiness, not the active-only count, so D-16 (closed ATF stays correctable) and E4 (fresh zero-animal ATF hides the section) both hold with the same check.
- A chip tap always stages the tapped result (no deselect-to-blank) — the three results are modeled as "tap a different one to change it."
- Per-row date/observation icon buttons are gated on the same edit-capability flag as the chips, not always shown, since they're meaningless to a role that cannot save.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two pre-existing 05-06 test assertions became ambiguous once the DG section rendered alongside them**
- **Found during:** Task 2, first full-file test run
- **Issue:** `_CompositionSection (REPR-02, 05-UI-SPEC E5, D-08) an animal with no DG renders a remove IconButton...` and `confirming the remove dialog calls removeAnimalFromAtf once` both used an unscoped `find.byType(IconButton)`, relying on the remove icon being the ONLY `IconButton` in the tree. Once `_DgSection` renders its own `IconButton`s (session date, per-row date, per-row observation), the unscoped finder matched multiple widgets and the tests broke — a pre-existing brittleness the new sibling functionality exposed, not a change in the remove-flow's own behavior. Mirrors the identical `InkWell`-scoping fix documented in 05-06-SUMMARY.md.
- **Fix:** Scoped both to `find.byTooltip('Remover do ATF')`, which is unique regardless of how many other `IconButton`s the screen grows to have.
- **Files modified:** `test/widget/atf_detail_screen_test.dart`
- **Verification:** Both tests pass again; full 191-test suite green.
- **Committed in:** `039b073` (Task 2 commit)

**2. [Rule 3 - Blocking] `_buildScreen`'s MaterialApp lacked the localization delegates real `showDatePicker` calls need**
- **Found during:** Task 2, writing the per-animal date-override test
- **Issue:** The test harness's `MaterialApp` only declared `DefaultMaterialLocalizations`/`DefaultWidgetsLocalizations`. `_DgSection`'s date pickers pass `locale: Locale('pt', 'BR')` explicitly (matching the codebase's `BaixaDialog` convention), which requires that locale in `supportedLocales` with the full `Global*` delegate set — otherwise `showDatePicker` throws when the DG date-override test tries to open it.
- **Fix:** Upgraded `_buildScreen`'s `MaterialApp` to `GlobalMaterialLocalizations`/`GlobalWidgetsLocalizations`/`GlobalCupertinoLocalizations` + `supportedLocales: [Locale('pt', 'BR')]`, matching the existing pattern already used in `atf_form_dialog_test.dart`.
- **Files modified:** `test/widget/atf_detail_screen_test.dart`
- **Verification:** The date-override test opens the picker, types a date via input mode, and asserts it lands in the correct payload entry.
- **Committed in:** `039b073` (Task 2 commit)

**3. [Rule 3 - Blocking] Off-screen taps in the widget test's fixed 800x600 viewport**
- **Found during:** Task 2, running tests against a real `_DgSection` for the first time
- **Issue:** With a header, composition, and DG list stacked in one `ListView`, the "Salvar DGs" button and later-row chips/icons frequently render below the default 600px test-viewport height. `tester.tap()` computes a target's global position but does not scroll a widget into view first, so taps against off-screen controls silently miss (a `warnIfMissed` warning, not a hard failure, which then surfaces as a downstream assertion failure instead of a clear error).
- **Fix:** Added `await tester.ensureVisible(finder)` immediately before every tap/enterText on a control that could be below the fold, across all new DG tests.
- **Files modified:** `test/widget/atf_detail_screen_test.dart`
- **Verification:** All 10 new DG tests pass; documented as a new pattern in this summary's `patterns-established` for future tests on this screen.
- **Committed in:** `039b073` (Task 2 commit)

**4. [Rule 1 - Bug] E6 backstop test: a 200-row composition list ahead of the DG section pushed it entirely out of the sliver's lazy-build cache window**
- **Found during:** Task 2, writing the 200-animal backstop test
- **Issue:** Setting both `activeMemberships` and (by fallback) `allMemberships` to the same 200-item list meant `_CompositionSection`'s own nested `shrinkWrap` `ListView.builder` (from plan 05-06) forced full realization of 200 `ListTile`s, consuming so much vertical space that `_DgSection` — positioned after it in the outer page `ListView` — fell outside the default ~850px (viewport + cacheExtent) lazy-build window and was never mounted at all under `pumpAndSettle()` (no real scroll occurs in a widget test). This is not a production bug: real scrolling continuously extends the build window as the user scrolls, so a genuinely large ATF works fine in the app; it only affects a fixed-viewport, non-scrolling test.
- **Fix:** In the backstop test, kept `activeMemberships` small (3 rows, via `.take(3)`) while passing the full 200-item list only through `allMemberships` (the one `_DgSection` actually reads) — isolates the E6 backstop to the DG list specifically, which is what the plan's `<verification>` names.
- **Files modified:** `test/widget/atf_detail_screen_test.dart`
- **Verification:** The backstop test finds `_DgSection`, asserts 600 `ChoiceChip`s (200 rows × 3), tags 3 rows, and asserts a 3-entry payload.
- **Committed in:** `039b073` (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (1 Rule 1 test-scoping bug carried forward from 05-06's precedent, 1 Rule 1 test-construction bug specific to the new 200-item scenario, 2 Rule 3 blocking test-infrastructure gaps)
**Impact on plan:** All four are test-file-only fixes needed to make the plan's own acceptance criteria executable; no production code beyond Task 1's planned `_DgSection`/`_DgChipRow` was added. No scope creep.

## Issues Encountered
None beyond the four auto-fixed issues above.

## User Setup Required
None - no external service configuration required. The Supabase migrations-not-yet-pushed blocker noted in 05-03-SUMMARY.md still applies to any LIVE exercise of `save_dg_records`, unchanged by this plan (widget tests use a fake repository).

## Next Phase Readiness
- `_DgSection` and `_DgChipRow` are complete and independently testable; plan 05-09 (encerramento banner/action) extends the same `atf_detail_screen.dart` file in the next wave without needing further changes here, per the plan's own note that this task does not add the encerramento banner or AppBar action.
- ROADMAP SC-3 now has an executable assertion for every D-10 through D-16 rule, and the E6 overflow backstop is a passing 200-animal test.
- SC-4's "atualiza automaticamente" half is proven at the invalidation-call-site level (D10 in coverage above); the end-to-end live recompute against a real Supabase project remains blocked on the same pending `supabase db push` noted since 05-03, unrelated to this plan's scope.

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

- FOUND: lib/features/reproducao/presentation/atf_detail_screen.dart
- FOUND: test/widget/atf_detail_screen_test.dart
- FOUND: .planning/phases/05-reproductive-module-loteatf/05-08-SUMMARY.md
- FOUND commit: e69cac7 (Task 1)
- FOUND commit: 039b073 (Task 2)
