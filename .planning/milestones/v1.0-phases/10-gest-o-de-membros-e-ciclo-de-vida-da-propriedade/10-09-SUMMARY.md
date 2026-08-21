---
phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade
plan: 09
subsystem: ui
tags: [flutter, riverpod, dashboard, membros, invites]

# Dependency graph
requires:
  - phase: 10-04
    provides: InviteBanner widget (accept/decline UI, shared by /sem-acesso and the dashboard)
provides:
  - Dashboard (mobile + desktop) surfaces the current user's pending invites, independent of the active property's role
affects: [dashboard, membros]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "myInvitesProvider consumed with the same `.asData?.value ?? const []` degrade-to-empty pattern already used for dashboardAlertsProvider — loading/error states render nothing instead of crashing or showing a skeleton"

key-files:
  created: []
  modified:
    - lib/features/dashboard/presentation/dashboard_screen.dart
    - test/widget/dashboard_screen_test.dart

key-decisions:
  - "Invite loop has no role gate, unlike _AlertsBanner (vet-only) — an invite is addressed to the person, not to whatever role they hold on the currently active property"
  - "No accept/decline logic duplicated in dashboard_screen.dart — the loop only instantiates InviteBanner(invite:), which owns all the interaction (10-04)"

requirements-completed: [MEMB-01]

coverage:
  - id: D1
    description: "Dashboard mobile renders one InviteBanner per pending invite, positioned above _AlertsBanner"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/widget/dashboard_screen_test.dart#mobile: um convite pendente mostra InviteBanner acima do _AlertsBanner"
        status: pass
      - kind: unit
        ref: "test/widget/dashboard_screen_test.dart#mobile: dois convites pendentes mostram dois InviteBanner"
        status: pass
    human_judgment: false
  - id: D2
    description: "Dashboard desktop renders InviteBanner in the main column, above _AlertsBanner"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/widget/dashboard_screen_test.dart#desktop: convite pendente mostra InviteBanner na coluna principal, acima do _AlertsBanner"
        status: pass
    human_judgment: false
  - id: D3
    description: "Invite banner appears regardless of the user's role on the active property (no role gate, unlike _AlertsBanner)"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/widget/dashboard_screen_test.dart#mobile: banner de convite aparece mesmo com papel não-veterinário"
        status: pass
    human_judgment: false
  - id: D4
    description: "No invites, or myInvitesProvider loading/error, renders no banner and no crash — existing dashboard behavior unchanged"
    requirement: "MEMB-01"
    verification:
      - kind: unit
        ref: "test/widget/dashboard_screen_test.dart#mobile: sem convites, nenhum InviteBanner é renderizado"
        status: pass
      - kind: unit
        ref: "test/widget/dashboard_screen_test.dart#mobile: myInvitesProvider em erro não renderiza banner e não quebra"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-08-14
status: complete
---

# Phase 10 Plan 09: Dashboard Invite Banner Summary

**Dashboard (mobile and desktop) surfaces the current user's pending invites via a loop of `InviteBanner`, positioned above `_AlertsBanner`, with no role gate — closing the MEMB-01 gap for users who already have a farm and are invited to a second one.**

## Performance

- **Duration:** 4 min (test commit to feat commit; wall time including reads/analysis longer)
- **Started:** 2026-08-14T15:43:04-03:00
- **Completed:** 2026-08-14T15:47:32-03:00
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- `_MobileDashboard` and `_DesktopDashboard` both watch `myInvitesProvider` and render one `InviteBanner` per pending invite, directly above the existing `_AlertsBanner` block, using the project's established `.asData?.value ?? const []` degrade pattern for loading/error safety
- Banner has no `isVet` gate — a personal invite is visible to any role on the active property, unlike `_AlertsBanner` which is vet-only because it exists to trigger a vet-only action
- Extended `test/widget/dashboard_screen_test.dart` with 6 new cases covering all 7 `<behavior>` bullets from the plan (the "existing tests keep passing" bullet is covered by the pre-existing 4 tests, all still green)

## Task Commits

Each task was committed atomically, following the plan's `tdd="true"` RED→GREEN cycle:

1. **Task 1 (RED): failing tests for dashboard invite banner** - `fe72c1a` (test)
2. **Task 1 (GREEN): surface pending invites on dashboard** - `aa55512` (feat)

**Plan metadata:** committed separately per orchestrator constraints (STATE.md/ROADMAP.md not touched by this plan)

## Files Created/Modified
- `lib/features/dashboard/presentation/dashboard_screen.dart` - Added `myInvitesProvider` watch + invite loop (mobile and desktop), 3 new imports
- `test/widget/dashboard_screen_test.dart` - Added `_readerMembership`/`_invite1`/`_invite2` fixtures, `membership`/`inviteOverride` params on `_buildScreen`, and 6 new `testWidgets` cases

## Decisions Made
- No role gate on the invite loop, documented inline as a code comment contrasting with `_AlertsBanner` — matches the plan's explicit prohibition against filtering by role
- Reused `InviteBanner` as-is; no accept/decline logic duplicated in this file (verified: `grep -c "for (final invite in invites)"` = 2, zero `acceptInvite`/`declineInvite` references in `dashboard_screen.dart`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `depend_on_referenced_packages` analyzer info on the new `package:riverpod/misc.dart` import**
- **Found during:** Task 1, `flutter analyze` after GREEN
- **Issue:** `riverpod` is a transitive dependency (via `flutter_riverpod`), not declared directly in `pubspec.yaml`. Importing `package:riverpod/misc.dart` for the `Override` type (needed for the new `inviteOverride` test helper param) triggers an analyzer info.
- **Fix:** Added `// ignore: depend_on_referenced_packages` above the import, matching the exact convention already used in `test/widget/paddock_detail_gastos_entry_test.dart`, `test/widget/piquetes_screen_test.dart`, and `test/features/gastos/paddock_expense_card_test.dart`.
- **Files modified:** test/widget/dashboard_screen_test.dart
- **Verification:** `flutter analyze` clean (4 remaining infos, all pre-existing and unrelated to this file)
- **Committed in:** aa55512 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug — analyzer hygiene, following existing project convention)
**Impact on plan:** No scope creep — the fix mirrors an already-established pattern in the same test suite.

## Issues Encountered
- Fresh worktree required `flutter pub get` and `dart run build_runner build` before any test would compile (missing `.g.dart`/`.freezed.dart` outputs) — expected per the plan's execution constraints, not a plan defect.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
MEMB-01 is now covered on both delivery paths: `/sem-acesso` (10-08, for users with zero memberships) and the dashboard (this plan, for users who already have at least one farm). No known gaps remain for this requirement within Phase 10's planned scope.

---
*Phase: 10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: lib/features/dashboard/presentation/dashboard_screen.dart
- FOUND: test/widget/dashboard_screen_test.dart
- FOUND: .planning/phases/10-gest-o-de-membros-e-ciclo-de-vida-da-propriedade/10-09-SUMMARY.md
- FOUND commit: fe72c1a (test)
- FOUND commit: aa55512 (feat)
