---
phase: 06-sanitary-module-snapshot
plan: 09
subsystem: ui
tags: [flutter, riverpod, sanitario, animal-ficha, snapshot-history]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot
    provides: "sanitaryHistoryByAnimalProvider / sanitaryApplicationsByLotProvider (06-04), /aplicacoes/:id route (06-05)"
provides:
  - "AnimalSanitaryHistorySection and LoteSanitaryHistorySection widgets in lib/features/sanitario/presentation/sanitary_history_section.dart"
  - "Real Histórico Sanitário section on the animal ficha, replacing the Phase 6 placeholder (SANI-05)"
affects: ["06-11 (lote ficha wiring)", "Phase 8 (consolidated ficha)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared outlined-card shell (_SanitaryHistoryCardShell) driven by per-widget State toggle, reused by two public ConsumerStatefulWidget variants"
    - "Reversal visibility/badge logic delegated entirely to visibleApplications/reversedApplicationIds from sanitary_application_model.dart — never re-implemented per surface"
    - "Ver todas' deep-link seeding via Uri(path: AppRoutes.sanitario, queryParameters: {...}) — animal/lote query params consumed by 06-10's SanitarioScreen"

key-files:
  created:
    - lib/features/sanitario/presentation/sanitary_history_section.dart
  modified:
    - lib/features/animais/presentation/animal_detail_screen.dart

key-decisions:
  - "Shared row rendering split into two thin format functions (_buildAnimalRow, _buildLoteRow) each owning its own Text(maxLines: 1, overflow: ellipsis) — keeps the two locked row formats (D-20 vs D-25) independent while still routing through one _HistoryRowShell for navigation/badge/line-through"
  - "Ver todas query parameters use 'animal' and 'lote' keys, matching the parameter names 06-10-PLAN.md's filter-seeding task already commits to"
  - "_PlaceholderSection deleted outright (no remaining call site) rather than left as dead code, per the plan's discretion clause"

requirements-completed: [SANI-04, SANI-05]

coverage:
  - id: D1
    description: "Animal ficha's Histórico Sanitário section renders real rows from the frozen containment lookup, replacing the Phase 6 placeholder"
    requirement: "SANI-05"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/animais/ (clean) + flutter test test/ (248 passed)"
        status: pass
    human_judgment: true
    rationale: "Visual row format, badge colors and toggle behavior require a rendered UAT pass — no widget test exists yet exercising AnimalSanitaryHistorySection directly (D-40 scoped Dart tests to calculation-only)."
  - id: D2
    description: "Shared sanitary history section widget (animal + lote variants) built to the D-37 standalone contract for Phase 8 reuse"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ (clean) + flutter test test/features/sanitario/ (21 passed)"
        status: pass
    human_judgment: true
    rationale: "D-37's 'compiles and renders with nothing but an animal id' contract and the lote variant's visual shape are structural/visual claims a human should confirm once 06-11 wires the lote placement; no widget test covers either variant's render tree yet."

# Metrics
duration: 22min
completed: 2026-08-06
status: complete
---

# Phase 06 Plan 09: Animal Sanitary History Section Summary

**Shared sanitary history card widget (animal + lote variants) replacing the animal ficha's Phase 6 placeholder, driven entirely by frozen `SanitaryApplication` rows.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-06T23:48:23-03:00 (Task 1 commit)
- **Completed:** 2026-08-06T23:54:26-03:00 (Task 2 commit)
- **Tasks:** 2/2 completed
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- New `lib/features/sanitario/presentation/sanitary_history_section.dart` holding one private outlined-card shell (`_SanitaryHistoryCardShell`) and two public standalone widgets: `AnimalSanitaryHistorySection` (D-37 contract — animal id only) and `LoteSanitaryHistorySection` (lot id only, ready for 06-11)
- Both variants delegate the "Mostrar estornadas" filter entirely to `visibleApplications`/`reversedApplicationIds` — no reversal logic re-implemented
- Rows cap at 10 with a "Ver todas" action deep-linking to `/sanitario?animal=<id>` or `/sanitario?lote=<id>`, which 06-10's `SanitarioScreen` will read to seed its filters
- Animal ficha now renders real sanitary history in place of the `_PlaceholderSection('Histórico Sanitário', 'Disponível na Fase 6.')` stub; the now-unused `_PlaceholderSection` class was deleted

## Task Commits

Each task was committed atomically:

1. **Task 1: Shared sanitary history section — animal and lote variants over one card shell** - `1458d28` (feat)
2. **Task 2: Replace the Histórico Sanitário placeholder on the animal ficha** - `44875ee` (feat)

_Note: no plan-metadata commit — orchestrator owns STATE.md/ROADMAP.md writes after the wave completes._

## Files Created/Modified
- `lib/features/sanitario/presentation/sanitary_history_section.dart` - Shared shell + `AnimalSanitaryHistorySection` + `LoteSanitaryHistorySection`, row builders, badge, "Ver todas" navigation
- `lib/features/animais/presentation/animal_detail_screen.dart` - Wired `AnimalSanitaryHistorySection(animalId: animal.id)` in place of the sanitary placeholder; deleted `_PlaceholderSection` (no remaining call site); updated header doc comment

## Decisions Made
- Kept the two locked row formats (D-20 lote vs D-25 animal) as separate small builder functions rather than one parameterized formatter, so each variant's `TextOverflow.ellipsis` usage is independently visible/verifiable (acceptance criterion required ≥2 occurrences in the file) while still sharing the `_HistoryRowShell` for tap-navigation, line-through and badge rendering.
- Chose `animal`/`lote` as the "Ver todas" query parameter names based on 06-10-PLAN.md's already-committed wording ("a lote parameter and an animal parameter") — kept consistent so 06-10's filter-seeding logic needs no renaming.

## Deviations from Plan

None - plan executed exactly as written. The one open item the plan explicitly flagged (FA-03, SANI-05's "moved-or-archived animal" edge) is covered as designed: the row always reads `app.lotName` (the frozen value), never a live lot lookup, so a moved animal's history still shows the lote it was in at application time.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `LoteSanitaryHistorySection` is already built and ready for 06-11 to drop into `lote_detail_screen.dart` with zero changes to this file.
- Phase 8's consolidated ficha can import `AnimalSanitaryHistorySection` directly per the D-37 contract — it takes nothing but an animal id.
- 06-10 must read the `animal`/`lote` query parameters this plan's "Ver todas" action produces when seeding `SanitarioScreen`'s filters.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*

## Self-Check: PASSED
- FOUND: lib/features/sanitario/presentation/sanitary_history_section.dart
- FOUND: lib/features/animais/presentation/animal_detail_screen.dart
- FOUND: .planning/phases/06-sanitary-module-snapshot/06-09-SUMMARY.md
- FOUND commit: 1458d28
- FOUND commit: 44875ee
