---
phase: "00"
plan: "05"
subsystem: "shell"
tags: [navigation, adaptive-layout, riverpod, go_router, widget]
dependency_graph:
  requires: [00-04]
  provides: [app_shell, property_selector]
  affects: [router, all_screens]
tech_stack:
  added: []
  patterns: [ConsumerWidget, LayoutBuilder-breakpoint, StatefulShellRoute, NavigationRail, NavigationBar]
key_files:
  created:
    - lib/core/widgets/app_shell.dart
    - lib/core/widgets/property_selector.dart
  modified:
    - lib/core/router/router.dart
    - test/widget/app_shell_test.dart
decisions:
  - "Breakpoint 600px (Material 3 default) for NavigationRail vs NavigationBar"
  - "_TempShell stub removed; AppShell is now the live shell"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-30"
  tasks_completed: 3
  files_changed: 4
---

# Phase 00 Plan 05: AppShell Adaptive Layout + PropertySelector Summary

Adaptive shell widget wired into GoRouter: NavigationRail at >=600px, NavigationBar below breakpoint, PropertySelector in AppBar from Riverpod AsyncNotifier.

## What Was Built

### AppShell (`lib/core/widgets/app_shell.dart`)
`ConsumerWidget` wrapping `LayoutBuilder` to switch between two Material 3 navigation patterns at the 600px breakpoint:
- Wide (>=600px): `NavigationRail` with `labelType: all` alongside content in a `Row`
- Narrow (<600px): `NavigationBar` as `bottomNavigationBar` with `navigationShell` as body

Five destinations: Dashboard, Piquetes, Animais, Reprod., Sanitario — matching the 5 `StatefulShellBranch` routes in the router.

### PropertySelector (`lib/core/widgets/property_selector.dart`)
`ConsumerWidget` that watches `currentPropertyProvider` (AsyncNotifier) and renders:
- `data(null)` → "Selecionar propriedade" placeholder text
- `data(property)` → property name + dropdown arrow row
- `loading` → small `CircularProgressIndicator`
- `error` → "Erro ao carregar propriedade" fallback

### Router update (`lib/core/router/router.dart`)
- Added `import '../widgets/app_shell.dart'`
- `StatefulShellRoute.indexedStack` builder now delegates directly to `AppShell`
- `_TempShell` stub class removed entirely

### Tests (`test/widget/app_shell_test.dart`)
Replaced 2 skipped placeholder tests with 3 active widget tests:
1. `NavigationRail` at 1024x768 (wide) — passes
2. `NavigationBar` at 360x800 (narrow) — passes
3. `PropertySelector` fallback text when provider returns null — passes

## Verification Results

```
flutter analyze --no-pub  → No issues found!
flutter test --no-pub     → All tests passed! (9 total, 3 new in app_shell_test)
verify_no_supabase_in_features.sh → OK
```

## Commits

| Hash | Message |
|------|---------|
| a982afb | feat(00-05): add AppShell adaptive layout + PropertySelector |
| bac82cd | test(00-05): unskip app_shell_test — 3 widget tests active |
| 99fa21a | feat(00-05): replace _TempShell with AppShell in router |

## Deviations from Plan

None — plan executed exactly as written. Widget files were pre-staged (untracked) from prior work; content matched spec exactly.

## Known Stubs

- `currentPropertyProvider` always returns `null` in Phase 0 (by design). `PropertySelector` shows "Selecionar propriedade" placeholder. Phase 1 will wire real property data from Supabase `property_members` table.

## Self-Check: PASSED

- `lib/core/widgets/app_shell.dart` — FOUND
- `lib/core/widgets/property_selector.dart` — FOUND
- `lib/core/router/router.dart` — `_TempShell` absent, `AppShell` present — CONFIRMED
- `test/widget/app_shell_test.dart` — 3 active tests, 0 skipped — CONFIRMED
- Commits a982afb, bac82cd, 99fa21a — FOUND
