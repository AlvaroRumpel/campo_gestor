---
phase: quick
plan: 260813-r4s
subsystem: ui
tags: [flutter, riverpod, layoutbuilder, master-detail, reproducao]

requires:
  - phase: quick-260813-p10
    provides: "AnimaisTableView/AnimalDetailPanel master-detail pattern this plan copies"
provides:
  - "ReproducaoTableView: desktop table of ATF cycles (8 columns), reused AtfScopeChip segmented"
  - "AtfDetailPanel: 380px master-detail side panel for a selected ATF cycle"
  - "ReproducaoScreen desktop cut at Breakpoints.rail, mobile path byte-for-byte unchanged"
affects: [reproducao]

tech-stack:
  added: []
  patterns:
    - "ReproducaoScreen mirrors AnimaisScreen's LayoutBuilder + table + 380px panel shape"
    - "Selection is local State (_selectedAtfId), not a NotifierProvider — derived from the visible list so switching Ativos/Encerrados closes the panel for free"

key-files:
  created:
    - lib/features/reproducao/presentation/reproducao_table_view.dart
    - lib/features/reproducao/presentation/atf_detail_panel.dart
    - test/widget/reproducao_desktop_test.dart
  modified:
    - lib/features/reproducao/presentation/reproducao_screen.dart

key-decisions:
  - "AtfScopeChip is the moved-and-renamed _FilterCountChip — one implementation reused by both mobile and desktop, zero duplication"
  - "Selection state is plain ConsumerStatefulWidget State, not a Notifier — no filters to survive rebuild here unlike AnimaisScreen's original reason for a provider"
  - "Export button omitted entirely — no exportation feature exists anywhere else in lib/"

patterns-established:
  - "Master-detail screens in this app: LayoutBuilder decides via Breakpoints.rail, table view is a pure StatelessWidget with all data passed in, detail panel is 380px ConsumerWidget/ConsumerStatefulWidget reading its own family providers"

requirements-completed: []

coverage:
  - id: D1
    description: "Desktop (>=Breakpoints.rail): ReproducaoTableView renders 8-column ATF cycle table with header (title, real-count subtitle, segmented, Novo ATF), replacing the mobile card list"
    verification:
      - kind: automated_ui
        ref: "test/widget/reproducao_desktop_test.dart#1440x900: renders ReproducaoTableView, not AtfDetailPanel, with the real-count subtitle"
        status: pass
    human_judgment: false
  - id: D2
    description: "Selecting a table row opens the 380px AtfDetailPanel; the table stays visible/usable"
    verification:
      - kind: automated_ui
        ref: "test/widget/reproducao_desktop_test.dart#tapping the ATF name in a row shows AtfDetailPanel; the table stays present"
        status: pass
    human_judgment: false
  - id: D3
    description: "AtfDetailPanel's primary button navigates to the existing ATF detail route (AppRoutes.atfDetail), same route the mobile card uses"
    verification:
      - kind: automated_ui
        ref: "test/widget/reproducao_desktop_test.dart#with the panel open, tapping \"Continuar DGs (N)\" navigates to the existing ATF detail route"
        status: pass
    human_judgment: false
  - id: D4
    description: "Below Breakpoints.rail: mobile cards/chips/FAB behavior unchanged, proven by an untouched reproducao_screen_test.dart"
    verification:
      - kind: automated_ui
        ref: "test/widget/reproducao_desktop_test.dart#800x600: no ReproducaoTableView/AtfDetailPanel, FAB present, ATF name on a card — mobile path"
        status: pass
      - kind: other
        ref: "git diff --exit-code -- test/widget/reproducao_screen_test.dart"
        status: pass
    human_judgment: false

duration: 94min
completed: 2026-08-13
status: complete
---

# Quick Task 260813-r4s: Reprodução mestre-detalhe desktop Summary

**Desktop table+380px-panel master-detail for the ATF cycle list, cut at `Breakpoints.rail`, mobile card list untouched below it.**

## Performance

- **Duration:** 94 min (spanned two sessions; a session limit interrupted execution mid-task-3 verification, resumed and finished cleanly)
- **Started:** 2026-08-13T19:42:22-03:00
- **Completed:** 2026-08-13T21:16:04-03:00
- **Tasks:** 3
- **Files modified:** 4 (2 created, 1 created test, 1 modified)

## Accomplishments
- `ReproducaoTableView`: 8-column desktop table of ATF cycles (ATF, Implante, Insemin., Touro, Fêmeas, DGs, Prenhez, Status), header with real-count subtitle, segmented Ativos/Encerrados, `Novo ATF` button
- `AtfDetailPanel`: 380px master-detail panel — header, stats strip, protocolo, progress bar, "Sem DG (N)" list (max 6 + overflow), footer button reusing `AppRoutes.atfDetail`
- `ReproducaoScreen` now cuts on `Breakpoints.rail` via `LayoutBuilder`; below the cut, behavior is byte-for-byte identical to before (proven by `git diff --exit-code` on the existing test file)
- `AtfScopeChip` extracted from the private `_FilterCountChip` and reused by both mobile and desktop — one segmented-chip implementation

## Task Commits

Each task was committed atomically:

1. **Task 1: Tabela de ciclos ATF (ReproducaoTableView)** - `72ad935` (feat)
2. **Task 2: Painel lateral do ciclo (AtfDetailPanel)** - `e0ae30e` (feat)
3. **Task 3: Ligar a tela no corte e provar os dois lados com teste de widget** - `49d6848` (feat)

**Plan metadata:** `36d709d` (docs: pre-dispatch plan commit, made by orchestrator before dispatch)

## Files Created/Modified
- `lib/features/reproducao/presentation/reproducao_table_view.dart` - `ReproducaoTableView` + public `AtfScopeChip`, no provider reads (StatelessWidget)
- `lib/features/reproducao/presentation/atf_detail_panel.dart` - `AtfDetailPanel`, 380px `ConsumerWidget`, reads only pre-existing family providers
- `lib/features/reproducao/presentation/reproducao_screen.dart` - `LayoutBuilder` cut at `Breakpoints.rail`, `_selectedAtfId` local state, `_openCreateForm` extracted and shared by FAB (mobile) and table header button (desktop)
- `test/widget/reproducao_desktop_test.dart` - 4 widget tests: table-not-panel at 1440x900, row-tap opens panel, panel button navigates via existing route, mobile path at 800x600

## Decisions Made
- `AtfScopeChip` made public and moved to `reproducao_table_view.dart` rather than duplicated — mobile and desktop segmented chips are now the exact same widget instance, so the pre-existing mobile widget test (`tap find.textContaining('Encerrados')`) keeps passing unmodified
- Selection is `String? _selectedAtfId` + `setState`, not a `NotifierProvider` — `AnimaisScreen`'s provider existed because of filters that needed to survive rebuilds; `ReproducaoScreen` has no such filters, so a plain State field is simpler and correct (Ponytail: skipped the extra provider, add one only if a future filter needs to survive it)
- Export button omitted per plan assumption 10 — no exportation feature exists anywhere in `lib/`, inventing one would violate the "no invented data/features" prohibition

## Deviations from Plan

None - plan executed exactly as written, with one drafting correction: the doc comment on `ReproducaoScreen` originally repeated the literal string `Breakpoints.rail`, which double-counted against the plan's `grep -c 'Breakpoints.rail' … -eq 1` verification gate. Reworded the comment to describe the cut without repeating the exact token — a documentation wording fix, not a behavior or scope change.

## Issues Encountered
- The new desktop test file initially shared a single top-level `GoRouter` instance across all four `testWidgets` blocks (mirroring `reproducao_screen_test.dart`'s pattern). Because one test navigates via `context.go` to the ATF detail stub route, the router's location leaked into the next test's fresh `pumpWidget`, making the mobile-path test intermittently render the wrong screen depending on run order. Fixed by building a new `GoRouter` per pump (`_buildRouter()`) instead of a shared `final _router`. Verified by running the full 4-test file repeatedly with a stable pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Desktop reproductive-cycle screen is feature-complete and covered by widget tests on both sides of the `Breakpoints.rail` cut.
- No blockers. The pattern (`LayoutBuilder` + table + 380px panel) is now used identically in `AnimaisScreen` (260813-p10) and `ReproducaoScreen` (this task) — a future `SanitarioScreen` desktop pass, if requested, has two working references to copy.

---
*Quick task: 260813-r4s*
*Completed: 2026-08-13*
