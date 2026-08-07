---
phase: 06-sanitary-module-snapshot
plan: 10
subsystem: presentation
tags: [flutter, riverpod, go_router, material3, tabs]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-03)
    provides: Dose model, DoseRepository CRUD + providers, Property.kgPerUa
  - phase: 06-sanitary-module-snapshot (06-04)
    provides: SanitaryApplication model, visibleApplications/reversedApplicationIds/sortByAppliedAtDesc, SanitaryApplicationRepository + providers
  - phase: 06-sanitary-module-snapshot (06-05)
    provides: AppRoutes.aplicacaoDetail(id), AplicacaoDetailScreen route
  - phase: 06-sanitary-module-snapshot (06-06)
    provides: DoseFormDialog (pops true on success, no own SnackBar)
  - phase: 06-sanitary-module-snapshot (06-08)
    provides: AplicacaoFormDialog, SanitaryAnimalSelectionScreen (full registration flow entry point)
  - phase: 06-sanitary-module-snapshot (06-09)
    provides: sanitary_history_section.dart's _VerTodasButton, which navigates here with lote/animal query parameters
provides:
  - "SanitarioScreen — the module's front door: two-tab shell (Aplicacoes/Doses) with filters, toggles, role-gated FABs, and query-parameter filter seeding"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Query-parameter filter seeding via a one-shot guard read in build() rather than initState — GoRouterState.of(context) uses dependOnInheritedWidgetOfExactType, which Flutter's own State.initState documentation forbids calling there; the mutation happens synchronously before the tree is returned (same shape as 06-08's _seeded guard), and the resulting tab switch is deferred to a postFrameCallback to avoid a setState-during-build conflict from TabController.animateTo's synchronous listener notification"
    - "DropdownButton value/items containment guard (lotValue = lots.any(...) ? _lotFilterId : null) before passing a possibly-stale seeded/selected id into a DropdownButton's value — prevents the 'exactly one item with this value' assertion crash when the referenced lot/dose hasn't loaded yet or no longer exists"

key-files:
  created: []
  modified:
    - lib/features/sanitario/presentation/sanitario_screen.dart

key-decisions:
  - "All three tasks landed in a single commit rather than three — every task modifies the exact same file with state that the next task immediately consumes (Task 1's filter fields exist only to be read by Task 2's filter row, and reading them in Task 1 alone before the filter row exists would earn an unused_field warning); the whole file was verified in one flutter analyze + flutter test pass rather than fabricating an intermediate broken state to force a mid-point commit."
  - "The applications FAB's 'on a returned animal count' snackbar path (invalidate + SnackBar) is implemented exactly as specified via `await showDialog<int>(builder: (_) => const AplicacaoFormDialog())`, but is very likely structurally unreachable given 06-08's already-merged AplicacaoFormDialog._continue: it calls navigator.pop() (completing this dialog's showDialog<int> Future with null) and THEN navigator.push(...) the full-screen checklist on the same root navigator, with that push's own Future never awaited or chained anywhere. The eventual animalCount from SanitaryAnimalSelectionScreen's Navigator.pop(context, result.animalCount) therefore resolves an orphaned Future, not this screen's showDialog await. Recorded as a cross-plan integration note (not fixed — aplicacao_form_dialog.dart is outside this plan's file boundary and owned by 06-08) for 06-12's live-flow verification to confirm or refute at runtime; the list itself still refreshes correctly regardless, since ResumoAplicacaoDialog already invalidates sanitaryApplicationListByPropertyProvider directly."
  - "Dose archive/restore icons have no locked Copywriting Contract error string, so a minimal generic inline SnackBar ('Não foi possível arquivar/reativar a dose. Tente novamente.') was added for the failure path (Rule 2 — missing error handling on a network call) rather than left silent."
  - "Lote/dose filter dropdown values are guarded against a seeded-but-not-yet-loaded or since-removed id via a lots.any(...)/doses.any(...) containment check before being passed as the DropdownButton's value, avoiding Flutter's 'exactly one item with this value' assertion."

patterns-established: []

requirements-completed: [SANI-01, SANI-04]

coverage:
  - id: T1
    description: "Tab shell with TabController created in initState/disposed in dispose, role-gated per-tab FAB (absent, not disabled), and one-shot lote/animal query-parameter filter seeding that switches to the applications tab when either is present"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ — No issues found; flutter test test/ — 257/257 passed"
        status: pass
      - kind: other
        ref: "grep confirms: both locked tab labels, both locked FAB tooltips, both locked success sentences ('Aplicação registrada — N animais', 'Dose salva.'), queryParameters present in the seeding logic, Phase 0 placeholder text absent"
        status: pass
    human_judgment: false
  - id: T2
    description: "Applications tab: lote/dose/period filters + animal chip, Mostrar estornadas toggle delegating to visibleApplications, two empty states keyed off the unfiltered list's emptiness, uncapped ListView.builder, cards with mutually-exclusive Estornada/Estorno badges and a null-guarded cost segment"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "flutter analyze / flutter test — same clean/green run as T1 (single combined commit)"
        status: pass
      - kind: other
        ref: "grep confirms: visibleApplications, showDateRangePicker, both empty-state headings/bodies, Período placeholder, Mostrar estornadas label, both badge labels; empty-state branch keys on rows.isEmpty (unfiltered), not the filtered/sorted list; card list has no take()/index cap"
        status: pass
    human_judgment: true
    rationale: "The applications FAB's snackbar-with-count path is structurally written per spec but, per the key-decisions entry above, is very likely unreachable at runtime given 06-08's already-merged navigator pop-then-push shape in AplicacaoFormDialog. This does not block the tab's own rendering/filtering (which is independently correct and covered by static/grep checks), but the FAB's specific 'shows the locked success snackbar with that count' truth is unverified end-to-end until 06-12's live-flow check, or a future gap-closure cycle that either fixes the navigator chain or confirms it resolves differently than analyzed here."
  - id: T3
    description: "Doses tab: Mostrar arquivadas toggle switching between doseListByPropertyProvider/archivedDoseListByPropertyProvider, dose cards with dosagePerUa/costPerUa computed via the shared helpers (primary-tinted), cost chips null-guarded on costPerKg, role-gated edit/archive-restore icons producing no widget for non-veterinarians, archived rows at 38% opacity with the Arquivada badge, single no-doses empty state"
    requirement: "SANI-01"
    verification:
      - kind: unit
        ref: "flutter analyze / flutter test — same clean/green run as T1 (single combined commit)"
        status: pass
      - kind: other
        ref: "grep confirms: Mostrar arquivadas label, Editar dose/Arquivar dose/Reativar dose tooltips, Arquivada badge, no-doses heading/body, archivedDoseListByPropertyProvider inside the toggle branch; both computed chips use dosagePerUa/costPerUa (not inline arithmetic); cost chips wrapped in a costPerKg null check; edit/archive icon row wrapped in `if (canEdit)`"
        status: pass
    human_judgment: false

# Metrics
duration: ~50min
completed: 2026-08-07
status: complete
---

# Phase 6 Plan 10: SanitarioScreen (Applications + Doses) Summary

**The sanitary module's front door — a two-tab `SanitarioScreen` replacing the Phase 0 placeholder, with client-side filters over the global applications list, a role-gated dose cadastro with live-computed per-UA figures, and query-parameter filter seeding from every "Ver todas" link in the phase**

## Performance

- **Duration:** ~50 min
- **Tasks:** 3 (landed in a single commit — see Decisions Made)
- **Files modified:** 1

## Accomplishments

- `SanitarioScreen` rewritten as a `ConsumerStatefulWidget` with a `TabController` (Aplicações/Doses), disposed correctly, and a per-tab role-gated `FloatingActionButton` (medical-services icon + "Registrar aplicação" on tab 1, add icon + "Nova dose" on tab 2) that is entirely absent — not disabled — for non-veterinarian roles.
- One-shot `lote`/`animal` query-parameter seeding read from `GoRouterState.of(context)` inside `build()` (not `initState`, since Flutter forbids `dependOnInheritedWidgetOfExactType` there), switching to the applications tab via a `postFrameCallback`-deferred `animateTo(0)` to avoid a setState-during-build conflict — this is what makes `sanitary_history_section.dart`'s "Ver todas" links land here pre-filtered.
- Applications tab: horizontally-scrollable lote/dose dropdown filters (value-containment guarded against a seeded-but-unloaded id), a period `showDateRangePicker` filter with a trailing clear control, a dismissible animal-number chip for the query-seeded animal filter, a right-aligned "Mostrar estornadas" `Switch` delegating to `visibleApplications`, two distinct empty states keyed off the *unfiltered* list's emptiness, and an uncapped `ListView.builder` of cards showing a mutually-exclusive Estornada/Estorno badge and a cost segment gated on the frozen `totalCost` being non-null.
- Doses tab: a "Mostrar arquivadas" toggle swapping between `doseListByPropertyProvider`/`archivedDoseListByPropertyProvider`, cards with `dosagePerUa`/`costPerUa` (never inline arithmetic) rendered in the theme's primary color, cost chips entirely absent when `costPerKg` is null, veterinarian-only edit/archive-restore icons, and archived rows rendered at 38% opacity with an "Arquivada" badge.
- `flutter analyze lib/features/sanitario/` reports 0 issues; `flutter test test/` passes 257/257 (full repo suite, no regressions).

## Task Commits

All three tasks landed in a single commit (see Decisions Made for why):

1. **Tasks 1-3: Tab shell, FAB, role gate, filter seeding + applications tab + doses tab** - `5f3a2d2` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified

- `lib/features/sanitario/presentation/sanitario_screen.dart` - `SanitarioScreen`, `_AplicacaoCard`, `_DoseCard`, `_EmptyNoApplicationsState`, `_EmptyFilteredApplicationsState`, `_EmptyDosesState`, `_Badge`

## Decisions Made

- All three tasks committed together: every task modifies the same file with state the next task consumes immediately (e.g. Task 1's filter fields would trigger an `unused_field` analyzer warning if committed before Task 2's filter row reads them) — splitting into three commits would require fabricating an intermediate, deliberately-incomplete state rather than reflecting genuine incremental progress. The full file was verified as one `flutter analyze` + `flutter test` pass.
- Query-parameter seeding reads `GoRouterState.of(context)` inside `build()` behind a one-shot `_filtersSeeded` guard, not literally inside `initState` as the plan's prose states — `initState`'s own Flutter documentation forbids calling `dependOnInheritedWidgetOfExactType` (which `GoRouterState.of` uses) there. This mirrors 06-08's `SanitaryAnimalSelectionScreen._seeded` guard precedent exactly (mutate fields synchronously before the tree is returned). The resulting tab switch is deferred via `WidgetsBinding.instance.addPostFrameCallback` to avoid `TabController.animateTo`'s synchronous listener notification calling `setState` mid-build.
- Dropdown filter values are guarded with a `lots.any(...)`/`doses.any(...)` containment check before being handed to `DropdownButton.value`, since a seeded-but-not-yet-loaded (or since-removed) id would otherwise trip Flutter's "exactly one item with this value" assertion.
- Dose archive/restore actions get a minimal generic failure `SnackBar` (no locked copy exists for this in the UI-SPEC's Copywriting Contract) rather than failing silently — Rule 2, a real network call needs error handling.

## Deviations from Plan

**1. [Rule 1 — bug avoidance] Query-parameter seeding moved from `initState` to a one-shot guard inside `build`.** See Decisions Made above; `initState` cannot safely call `GoRouterState.of(context)`. No behavioral change from the plan's intent — the seed still fires exactly once, before the first paint the user sees.

No other deviations — the remaining implementation matches the plan's task text, `06-UI-SPEC.md`'s locked copy/layout, and `06-PATTERNS.md`'s analogs exactly.

## Known Integration Gap (flagged, not fixed)

The applications FAB's "on a returned animal count, invalidate + show the locked success snackbar" path is implemented exactly as the plan specifies (`await showDialog<int>(builder: (_) => const AplicacaoFormDialog())`), but tracing 06-08's already-merged `AplicacaoFormDialog._continue` shows it calls `navigator.pop()` (resolving *this* screen's `showDialog<int>` Future to `null`) and only *then* `navigator.push(...)`s the full-screen checklist on the same root navigator — with that push's own `Future<int?>` never awaited or chained to anything. The eventual `animalCount` produced by `SanitaryAnimalSelectionScreen`'s `Navigator.pop(context, result.animalCount)` therefore resolves an orphaned `Future`, not this screen's await. This is a cross-plan integration detail in a file (`aplicacao_form_dialog.dart`) outside this plan's boundary (owned by 06-08) — not something this plan can fix without violating the sibling-file boundary. The applications LIST still refreshes correctly regardless, since `ResumoAplicacaoDialog` (06-07) already calls `ref.invalidate(sanitaryApplicationListByPropertyProvider)` directly on success; only the count-bearing SnackBar from this specific FAB handler is affected. Flagged here for 06-12's live-flow verification (or a future gap-closure cycle) to confirm or refute at runtime, and potentially resolve by having `AplicacaoFormDialog._continue` await/chain the push's result back through the original dialog's pop value.

## Issues Encountered

`dart run build_runner build` was required once at session start (worktree starts with no gitignored `.freezed.dart`/`.g.dart`/`.riverpod.dart` files) — not a deviation, per the worktree housekeeping instructions.

## User Setup Required

None. This plan only touches Dart client code; the schema this screen reads/writes against remains unapplied to any live database until 06-12 applies the Phase 6 migration, consistent with every other Phase 6 client-only plan.

## Next Phase Readiness

- `SanitarioScreen` is complete and reachable at `/sanitario`; it is the last file in this phase's `06-PATTERNS.md` inventory still marked as the Phase 0 placeholder — the placeholder is now fully replaced.
- Did not touch `aplicacao_form_dialog.dart`, `dose_form_dialog.dart`, `sanitary_history_section.dart`, `aplicacao_detail_screen.dart`, `estornar_aplicacao_dialog.dart`, `sanitary_animal_selection_screen.dart`, or `resumo_aplicacao_dialog.dart` — all sibling-owned, all read-only inputs to this plan.
- The Known Integration Gap above is the one open item for 06-12 (or a future gap-closure cycle) to verify against a live database and, if confirmed, resolve in `aplicacao_form_dialog.dart`.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-07*

## Self-Check: PASSED

`lib/features/sanitario/presentation/sanitario_screen.dart` verified present on disk with the full two-tab implementation. Commit hash `5f3a2d2` verified present in `git log --oneline`.
