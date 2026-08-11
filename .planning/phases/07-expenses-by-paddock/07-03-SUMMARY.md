---
phase: 07-expenses-by-paddock
plan: 03
subsystem: auth
tags: [flutter, riverpod, role-gating, go_router]

requires:
  - phase: 04-movements
    provides: SelectedProperty/PropertyMembership shape and the role-gate pattern (_canEdit) this plan diverges from
provides:
  - "canManageExpenses(SelectedProperty?, List<PropertyMembership>?) in lib/core/auth/role_gates.dart — the project's first two-role (owner + veterinarian) permission gate"
  - "AppRoutes.gastosById ('/gastos/:paddockId') and AppRoutes.gastosPorPiquete(id) helper in lib/core/router/routes.dart"
affects: [07-06-gastos-screen, 07-07-paddock-detail-summary-card]

tech-stack:
  added: []
  patterns:
    - "core/auth/ as the location for cross-feature role predicates (first file in this directory)"
    - "Two-role gate coexisting with a single-role gate on the same screen, never merged"

key-files:
  created:
    - lib/core/auth/role_gates.dart
    - test/features/gastos/role_gates_test.dart
  modified:
    - lib/core/router/routes.dart

key-decisions:
  - "PropertyMembership is actually exported from features/auth/data/property_repository.dart, not core/providers/current_property_provider.dart as the plan's action text stated — imported from the correct file (Rule 1, plan's import claim was wrong, confirmed against paddock_detail_screen.dart's own import list)."

patterns-established:
  - "canManageExpenses lives in core/auth/, not private to gastos feature, because two features (GastosScreen FAB, PaddockDetailScreen summary card) will consume it in later plans."

requirements-completed: [GAST-01]

coverage:
  - id: D1
    description: "canManageExpenses returns true for owner and veterinarian, false for reader/null-selected/null-members/no-matching-membership, scoped correctly to the selected property"
    requirement: "GAST-01"
    verification:
      - kind: unit
        ref: "test/features/gastos/role_gates_test.dart#canManageExpenses (GAST-01, D-23)"
        status: pass
    human_judgment: false
  - id: D2
    description: "AppRoutes.gastosById template and gastosPorPiquete(id) helper added; AppRoutes.all (shell branch inventory) and PaddockDetailScreen._canEdit left byte-identical"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart (navigation-item count assertions)"
        status: pass
      - kind: other
        ref: "git diff --quiet -- lib/features/piquetes/presentation/paddock_detail_screen.dart"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-11
status: complete
---

# Phase 7 Plan 03: Expense Role Gate & Route Constants Summary

**`canManageExpenses` two-role (owner + veterinarian) permission gate in `core/auth/`, plus the `/gastos/:paddockId` route constant and helper, both dependency-free groundwork for the expenses-by-paddock feature.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 2 completed
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments
- Added `canManageExpenses`, the project's first two-role permission gate (D-23), with a 7-case unit test suite (TDD red→green)
- Kept it fully separate from `PaddockDetailScreen._canEdit` (vet-only, guards "Novo lote" FAB) — verified byte-identical via `git diff --quiet`
- Registered `AppRoutes.gastosById` / `AppRoutes.gastosPorPiquete` (D-08) without touching the shell-branch inventory (`AppRoutes.all` still 5 entries)

## Task Commits

Each task was committed atomically:

1. **Task 1: canManageExpenses two-role gate and its unit test** — `70b6ed1` (test, RED) → `2bba7f4` (feat, GREEN)
2. **Task 2: /gastos/:paddockId route constant and helper** — `2538db4` (feat)

_TDD task (Task 1) has two commits: failing test, then implementation._

## Files Created/Modified
- `lib/core/auth/role_gates.dart` - `canManageExpenses(SelectedProperty?, List<PropertyMembership>?)`, new `core/auth/` directory
- `test/features/gastos/role_gates_test.dart` - 7 unit tests covering every `<behavior>` case
- `lib/core/router/routes.dart` - `AppRoutes.gastosById`, `AppRoutes.gastosPorPiquete(id)`, top-of-file doc comment updated with Phase 7 line

## Decisions Made
- Imported `PropertyMembership` from `features/auth/data/property_repository.dart` rather than `core/providers/current_property_provider.dart` as the plan's action text specified — the latter only defines `SelectedProperty`; confirmed the correct source by reading `PaddockDetailScreen`'s own import list, which imports both files.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected import source for `PropertyMembership`**
- **Found during:** Task 1 (canManageExpenses implementation)
- **Issue:** Plan's action text said to import both `SelectedProperty` and `PropertyMembership` from `../providers/current_property_provider.dart`. `PropertyMembership` is actually declared in `features/auth/data/property_repository.dart`; `current_property_provider.dart` has no such declaration or re-export.
- **Fix:** Added a second import from `../../features/auth/data/property_repository.dart`, keeping the `current_property_provider.dart` import for `SelectedProperty`.
- **Files modified:** `lib/core/auth/role_gates.dart`
- **Verification:** `flutter analyze lib/core/auth/role_gates.dart` — 0 issues; `flutter test test/features/gastos/role_gates_test.dart` — 7/7 pass
- **Committed in:** `2bba7f4` (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Import path correction only; no scope change, no behavior change from what the plan specified.

## Issues Encountered
- `flutter analyze lib/core/` (the plan-level verification command, scanning the whole directory) surfaces 1 pre-existing info-level issue (`unintended_html_in_doc_comment` in `lib/core/config/app_config.dart`, untouched by this plan). Out of scope per the deviation rules' scope boundary; logged to `.planning/phases/07-expenses-by-paddock/deferred-items.md` rather than fixed. Both files this plan touched (`role_gates.dart`, `routes.dart`) individually pass `flutter analyze` with 0 issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `canManageExpenses` is ready for consumption by `GastosScreen`'s FAB (07-06) and `PaddockDetailScreen`'s summary card (07-07)
- `AppRoutes.gastosPorPiquete` is ready for the `PaddockDetailScreen` card's `onTap`; the matching `GoRoute` registration is still owed by 07-06
- No blockers for downstream plans in this wave

---
*Phase: 07-expenses-by-paddock*
*Completed: 2026-08-11*
