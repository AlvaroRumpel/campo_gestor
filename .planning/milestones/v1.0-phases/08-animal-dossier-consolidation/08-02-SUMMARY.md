---
phase: 08-animal-dossier-consolidation
plan: 02
subsystem: frontend
tags: [flutter, riverpod, widget-extraction, reproducao]

# Dependency graph
requires:
  - phase: 08-animal-dossier-consolidation
    provides: "08-01 — ReproductiveHistoryEntry.dgRecords/bullName/implantationDate (not consumed by this widget yet, but the plan that shares this file)"
  - phase: 06-sanitary-module-snapshot
    provides: "AnimalSanitaryHistorySection — the byte-shape analog this plan mirrors (D-11, D-37)"
provides:
  - "AnimalReproductiveHistorySection — public ConsumerWidget in lib/features/reproducao/presentation/, id-only constructor, resolves its own provider"
affects: [08-04, 08-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Widget extraction to a module-owned public class (ConsumerWidget, id-only constructor) instead of a screen-private class — mirrors AnimalSanitaryHistorySection (D-11)"

key-files:
  created:
    - lib/features/reproducao/presentation/animal_reproductive_history_section.dart
  modified:
    - lib/features/animais/presentation/animal_detail_screen.dart

key-decisions:
  - "AnimalReproductiveHistorySection is a stateless ConsumerWidget, not ConsumerStatefulWidget — unlike AnimalSanitaryHistorySection (stateful only for its 'Mostrar estornadas' toggle), this block has no local UI state to manage, per the plan's explicit instruction"
  - "Orphaned imports (atf_model.dart, atf_repository.dart, dg_record_model.dart) removed from animal_detail_screen.dart only after verifying via flutter analyze that nothing else in the file referenced them — no speculative removal"

patterns-established:
  - "Move, do not rewrite: an extracted widget's build() body and its private row helper class are copied verbatim into the new public file, byte-identical shell, only the class name and dartdoc cross-references change"

requirements-completed: [ANIM-03]

coverage:
  - id: D1
    description: "AnimalReproductiveHistorySection is a public widget in lib/features/reproducao/presentation/, id-only constructor, resolving its own provider — symmetric to AnimalSanitaryHistorySection"
    requirement: "ANIM-03"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/reproducao/presentation/animal_reproductive_history_section.dart — 0 issues"
        status: pass
    human_judgment: false
  - id: D2
    description: "animal_detail_screen.dart composes the extracted widget and no longer declares any reproductive-history rendering class; all 6 existing Histórico Reprodutivo tests (including the SC-3 ordering regression guard) pass with zero edits to the test file"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart — AnimalDetailScreen — Histórico Reprodutivo group, 6/6 tests pass, file untouched"
        status: pass
      - kind: unit
        ref: "flutter test (full suite) — 313/313 passing"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-08-11
status: complete
---

# Phase 8 Plan 2: Extract Reproductive History Block to a Public Widget Summary

**Moved `_ReproductiveHistorySection`/`_ReproductiveHistoryRow` out of `animal_detail_screen.dart` into a new public `AnimalReproductiveHistorySection` in `lib/features/reproducao/presentation/`, byte-identical to the original — zero pixel, copy, or query changes.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-08-11T21:05:00Z (approx.)
- **Completed:** 2026-08-11T21:09:20Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` with the public `AnimalReproductiveHistorySection extends ConsumerWidget` (id-only constructor), copying the card shell, copy strings, `when` branches, and the private `_ReproductiveHistoryRow` verbatim from the original screen-private classes — mirroring `AnimalSanitaryHistorySection`'s contract (D-11/D-37) exactly, including the dartdoc note that it resolves its own provider from nothing but an animal id.
- Rewired `animal_detail_screen.dart` to import and compose `AnimalReproductiveHistorySection(animalId: animal.id)` in the same ListView position (between `AnimalInfoCard` and `AnimalSanitaryHistorySection`, D-18 order preserved), removed the two now-migrated private classes, and dropped the three imports (`atf_model.dart`, `atf_repository.dart`, `dg_record_model.dart`) that became orphaned as a result — verified case-by-case via `flutter analyze`, not by assumption.
- The ficha is now composition of two symmetric module-owned blocks; `animal_detail_screen.dart` no longer contains any reproductive-history rendering logic.

## Task Commits

Each task was committed atomically:

1. **Task 1: Criar o widget público AnimalReproductiveHistorySection** - `0673977` (feat)
2. **Task 2: Compor a ficha com o widget público e remover o bloco privado da tela** - `9f3ebbe` (refactor)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` - NEW. `AnimalReproductiveHistorySection` (public `ConsumerWidget`) + private `_ReproductiveHistoryRow`, moved verbatim from `animal_detail_screen.dart`.
- `lib/features/animais/presentation/animal_detail_screen.dart` - composes the new widget; the two private reproductive-history classes and their now-orphaned imports were removed. Net -156 lines.

## Decisions Made
- None beyond what's captured in `key-decisions` above — the plan's action blocks were followed as written, including the explicit "move, do not rewrite" instruction.

## Deviations from Plan
None - plan executed exactly as written. No auto-fixes needed; `flutter analyze` (whole repo) returned only the same 4 pre-existing unrelated issues already documented in 08-01-SUMMARY.md, none touching either file this plan modified.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `AnimalReproductiveHistorySection` is now a standalone, testable-in-isolation public widget, unblocking plan 08-05 (DG `ExpansionTile` expansion) to modify it without touching `animal_detail_screen.dart`.
- The ficha's two history blocks (`AnimalReproductiveHistorySection`, `AnimalSanitaryHistorySection`) are fully symmetric module-owned components, ready for 08-04's remaining screen-level changes (baixa banner, `_KvRow` breakpoint, provider swap) without further reproductive-block coupling.
- No blockers. Full test suite (313 tests) and repo-wide `flutter analyze` (4 pre-existing unrelated issues, 0 errors) both green.

---
*Phase: 08-animal-dossier-consolidation*
*Completed: 2026-08-11*

## Self-Check: PASSED
All created/modified files confirmed present on disk; both task commits (0673977, 9f3ebbe) confirmed in git log.
