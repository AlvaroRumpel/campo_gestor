---
phase: quick
plan: 260813-ok3
subsystem: ui
tags: [flutter, riverpod, layoutbuilder, adaptive-layout, navigation]

requires:
  - phase: 09-redesign
    provides: AppColors tokens, PropertySelector, existing 2-faixa AppShell
provides:
  - Breakpoints (lib/core/theme/breakpoints.dart) as the single source of shell width thresholds
  - Three-tier AppShell (bottom nav <600 / 76px icon rail 600-1439 / 232px drawer >=1440)
  - showAdaptiveForm(width:) with FormWidth.confirm/form/wide (default 560, was fixed 480)
  - PropertySelector(compact:) for icon-only rendering in the rail
affects: [redesign-followups, any future screen needing FormWidth.wide dialogs]

tech-stack:
  added: []
  patterns:
    - "Breakpoints/FormWidth as abstract final class with named double constants — same idiom as AppColors/AppFonts"
    - "Badge counts scoped to the widget tier that needs them (drawer watches animalListByPropertyProvider, rail/mobile don't) to avoid unnecessary fetches"

key-files:
  created:
    - lib/core/theme/breakpoints.dart
  modified:
    - lib/core/widgets/ui.dart
    - lib/core/theme/app_colors.dart
    - lib/core/widgets/property_selector.dart
    - lib/core/widgets/app_shell.dart
    - test/widget/app_shell_test.dart

key-decisions:
  - "Rail badge count (Reprodução) and drawer badges (Animais + Reprodução) match by item.label string instead of adding an enum/id to _NavItem — smallest diff, no new indirection for 5 fixed items"
  - "ui.dart import removed from app_shell.dart after realizing monoStyle lives in app_colors.dart, not ui.dart — kept the doc-comment fix minimal (unused_import warning)"

requirements-completed: []

coverage:
  - id: D1
    description: "Breakpoints class (mobile/rail/drawer) is the single source of shell width thresholds, consumed by AppShell and showAdaptiveForm"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#AppShell renders NavigationBar at narrow viewport (360x800)"
        status: pass
    human_judgment: false
  - id: D2
    description: "600-1439px shows a 76px icon rail (not the 232px drawer) with compact PropertySelector and Reprodução badge"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#AppShell renders icon rail (no title, no NavigationBar) at 800x600"
        status: pass
      - kind: unit
        ref: "test/widget/app_shell_test.dart#AppShell renders icon rail (no title, no NavigationBar) at 1024x768"
        status: pass
    human_judgment: false
  - id: D3
    description: ">=1440px shows the 232px drawer with header, PropertySelector, and Animais/Reprodução badges"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#AppShell renders 232px drawer with title and Sair at 1440x900"
        status: pass
    human_judgment: false
  - id: D4
    description: "<600px is byte-identical to prior behavior (NavigationBar, no title)"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#AppShell renders NavigationBar at narrow viewport (360x800)"
        status: pass
    human_judgment: false
  - id: D5
    description: "showAdaptiveForm accepts width: with FormWidth.confirm/form/wide, defaults to 560 (was fixed 480), all 26 existing call sites unchanged"
    verification:
      - kind: unit
        ref: "flutter test test/widget/lote_form_dialog_test.dart test/widget/mover_animal_dialog_test.dart test/features/gastos/expense_form_dialog_test.dart"
        status: pass
    human_judgment: false
  - id: D6
    description: "flutter analyze clean and full test suite (361 tests) green"
    verification:
      - kind: unit
        ref: "flutter analyze --no-fatal-infos (0 errors/warnings, 3 pre-existing infos)"
        status: pass
      - kind: unit
        ref: "flutter test (361 passed)"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-08-13
status: complete
---

# Quick Task 260813-ok3: Shell Adaptativo Desktop Summary

**Three-tier AppShell (bottom nav / 76px icon rail / 232px drawer) driven by a new `Breakpoints` class, plus `showAdaptiveForm(width:)` with named `FormWidth` constants.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-08-13T17:45:18-03:00
- **Completed:** 2026-08-13T17:54:31-03:00
- **Tasks:** 2
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments
- `Breakpoints` (mobile=600, rail=1024, drawer=1440) is now the single source of shell width thresholds — `AppShell` and `showAdaptiveForm` both consume it instead of duplicating a `600` literal.
- `AppShell` now renders three faixas instead of two: bottom nav (<600), a new 76px icon rail (600–1439) with compact avatar + short labels + Reprodução ATF-count badge, and the existing 232px drawer (now >=1440) with Animais/Reprodução count badges.
- `showAdaptiveForm` accepts an optional `width` parameter (`FormWidth.confirm=440 / form=560 / wide=680`, default `form`), replacing the fixed 480px dialog width. All 26 existing call sites keep the old-equivalent behavior by inheriting the new default.
- `PropertySelector(compact: true)` renders just the farm avatar for the icon rail's tight 76px column, reusing the same popup menu as the full selector.

## Task Commits

Each task was committed atomically:

1. **Task 1: Breakpoints nomeados e largura configurável em showAdaptiveForm** - `cc79aa0` (feat)
2. **Task 2: Rail de ícones 76px e drawer 232px no AppShell** - `a2cc8c8` (feat)

**Plan metadata:** committed separately by the orchestrator per constraints (this executor did not commit STATE.md/PLAN.md/SUMMARY.md/ROADMAP.md).

## Files Created/Modified
- `lib/core/theme/breakpoints.dart` - New `Breakpoints` abstract final class (mobile/rail/drawer)
- `lib/core/widgets/ui.dart` - `FormWidth` class; `showAdaptiveForm` gains `width` param, uses `Breakpoints.mobile`
- `lib/core/theme/app_colors.dart` - New `onGreenMuted` token (inactive nav item over green)
- `lib/core/widgets/property_selector.dart` - New `compact` param (avatar-only rendering)
- `lib/core/widgets/app_shell.dart` - Rewritten: 3-tier `LayoutBuilder`, new `_IconRail`/`_IconRailItem`, `_DesktopRail` gains badges, `_RailItem` gains `trailing`
- `test/widget/app_shell_test.dart` - Rewritten to cover 360/800/1024/1440 instead of 360/1024

## Decisions Made
- Badge matching (Reprodução in the rail; Animais + Reprodução in the drawer) uses `item.label` string comparison rather than adding an id/enum to `_NavItem` — the nav list is a fixed 5 items, so a string match is the smallest correct diff.
- Drawer's `animalListByPropertyProvider` watch stays scoped to `_DesktopRail` only (marked with a `ponytail:` comment) so the mobile and rail faixas don't pay for that fetch — matches the plan's explicit instruction.
- Dropped the planned `ui.dart` import from `app_shell.dart`: `monoStyle` actually lives in `app_colors.dart` (already imported), so importing `ui.dart` too was flagged as `unused_import` by analyzer and removed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ran `build_runner` to generate missing freezed/json/riverpod code**
- **Found during:** Task 1 (`flutter analyze` verification step)
- **Issue:** Fresh worktree had zero `*.freezed.dart`/`*.g.dart` files (gitignored, never generated locally), causing 628 pre-existing analyzer errors unrelated to this plan's files (missing `copyWith`, `examDate`, etc. on generated models) — blocked running any meaningful verification.
- **Fix:** `flutter pub run build_runner build` (27 outputs generated). Not a code change — no files staged/committed from this step.
- **Files modified:** none (generated files stay gitignored, not committed)
- **Verification:** `flutter analyze --no-fatal-infos` dropped from 628 issues to 3 pre-existing infos unrelated to this plan
- **Committed in:** N/A (build artifact, not committed)

---

**Total deviations:** 1 auto-fixed (1 blocking, environment-only — no application code affected)
**Impact on plan:** Zero scope creep. Necessary to even run the plan's own verification commands.

## Issues Encountered
None beyond the build_runner gap above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `Breakpoints` and `FormWidth` are available for any future screen; no call sites elsewhere were touched, so this is purely additive.
- Visual/UAT confirmation of the rail/drawer at real viewport sizes is not part of this quick task's scope (plan only required `flutter analyze` clean + tests passing) — worth a manual look next time the app is run locally.

---
*Phase: quick*
*Completed: 2026-08-13*

## Self-Check: PASSED

- FOUND: lib/core/theme/breakpoints.dart
- FOUND: .planning/quick/260813-ok3-implementar-shell-adaptativo-desktop-do-/260813-ok3-SUMMARY.md
- FOUND: cc79aa0 (Task 1 commit)
- FOUND: a2cc8c8 (Task 2 commit)
