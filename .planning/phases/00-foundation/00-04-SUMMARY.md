---
phase: 00-foundation
plan: 04
subsystem: core-scaffolding
tags: [foundation, core, router, theme, riverpod, supabase]

dependency_graph:
  requires: [00-01, 00-03]
  provides:
    - supabaseServiceProvider (Riverpod Provider<SupabaseService>)
    - currentPropertyProvider (AsyncNotifier<Property?>)
    - routerProvider (Provider<GoRouter>)
    - AppTheme.light()
    - Env.requireOrThrow()
    - 5 placeholder feature screens
  affects: [00-05, 00-06]

tech_stack:
  added: []
  patterns:
    - Plain Provider/AsyncNotifierProvider constructors (no codegen per D-10)
    - GoRouterRefreshStream adapter with mandatory onError handler (Pitfall 2)
    - StatefulShellRoute.indexedStack with 5 branches (D-03)
    - String.fromEnvironment for compile-time secret injection (D-08)
    - SupabaseService singleton as single Supabase access point (D-06)

key_files:
  created:
    - lib/core/env/env.dart
    - lib/core/theme/app_theme.dart
    - lib/core/services/supabase_service.dart
    - lib/core/providers/supabase_providers.dart
    - lib/core/providers/current_property_provider.dart
    - lib/core/router/routes.dart
    - lib/core/router/router.dart
    - lib/features/dashboard/presentation/dashboard_screen.dart
    - lib/features/piquetes/presentation/piquetes_screen.dart
    - lib/features/animais/presentation/animais_screen.dart
    - lib/features/reproducao/presentation/reproducao_screen.dart
    - lib/features/sanitario/presentation/sanitario_screen.dart
  modified:
    - test/core/theme_test.dart
    - test/core/current_property_provider_test.dart
    - test/core/router_test.dart

decisions:
  - "Used asData?.value instead of valueOrNull for AsyncValue<Property?> — Riverpod 3.x removed valueOrNull getter"
  - "_TempShell placeholder in router.dart bridges gap until Plan 05 delivers real AppShell"
  - "GoRoute builders use (ctx, _) not (_, __) to satisfy unnecessary_underscores lint"

metrics:
  duration: ~15 minutes
  completed: 2026-04-30
  tasks_completed: 2
  files_created: 12
  files_modified: 3
---

# Phase 00 Plan 04: Core Scaffolding (Theme, Env, Services, Router, Screens) Summary

**One-liner:** GoRouter with StatefulShellRoute (5 branches), supabaseServiceProvider, currentPropertyProvider AsyncNotifier, AppTheme Material3 seed #4A6741, and Env dart-define loader — all with Wave 0 tests activated.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Env loader, AppTheme, SupabaseService, supabaseServiceProvider, currentPropertyProvider | 721b087 |
| 2 | GoRouter (5 routes), _TempShell, 5 placeholder screens | ec54482 |
| 3 | Unskip theme_test, current_property_provider_test, router_test | f3cf70b |

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| lib/core/env/env.dart | 23 | Env vars via dart-define + requireOrThrow() |
| lib/core/theme/app_theme.dart | 19 | Material3 ThemeData seeded from #4A6741 |
| lib/core/services/supabase_service.dart | 13 | SupabaseService singleton (D-06) |
| lib/core/providers/supabase_providers.dart | 8 | supabaseServiceProvider Provider<SupabaseService> |
| lib/core/providers/current_property_provider.dart | 38 | Property class + CurrentPropertyNotifier + currentPropertyProvider |
| lib/core/router/routes.dart | 15 | AppRoutes 5 path constants + all list |
| lib/core/router/router.dart | 141 | routerProvider + GoRouterRefreshStream + _TempShell |
| lib/features/dashboard/presentation/dashboard_screen.dart | 12 | DashboardScreen placeholder |
| lib/features/piquetes/presentation/piquetes_screen.dart | 12 | PiquetesScreen placeholder |
| lib/features/animais/presentation/animais_screen.dart | 12 | AnimaisScreen placeholder |
| lib/features/reproducao/presentation/reproducao_screen.dart | 12 | ReproducaoScreen placeholder |
| lib/features/sanitario/presentation/sanitario_screen.dart | 12 | SanitarioScreen placeholder |

## Wave 0 Tests Activated

| Test File | Tests Unskipped | Status |
|-----------|----------------|--------|
| test/core/theme_test.dart | 1 (AppTheme.light() Material3 + seedColor) | PASS |
| test/core/current_property_provider_test.dart | 2 (null initial state, selectProperty) | PASS |
| test/core/router_test.dart | 2 (AppRoutes.all length=5, GoRouterRefreshStream error swallow) | PASS |

Total: 5 new active tests, all green. Full suite: 6 passing, 2 skipped (app_shell_test Wave 0 placeholders for Plan 05).

## Verification Results

```
flutter analyze --no-pub   → No issues found
flutter test --no-pub      → +6 ~2: All tests passed
bash scripts/verify_no_supabase_in_features.sh → OK: No direct supabase_flutter imports in lib/features/
```

## _TempShell Placeholder

`lib/core/router/router.dart` contains `_TempShell` — a minimal Scaffold that wraps `StatefulNavigationShell` so the router compiles before Plan 05 delivers the real `AppShell`. Marked with `// TODO(plan-05): replace _TempShell with AppShell from lib/core/widgets/app_shell.dart`.

## SC-5 Invariant

`bash scripts/verify_no_supabase_in_features.sh` exits 0. Only `lib/core/router/router.dart` imports `package:supabase_flutter` (for auth stream). All 5 feature screens import only `package:flutter/material.dart`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed valueOrNull → asData?.value for Riverpod 3.x**
- **Found during:** Task 1 (IDE diagnostic after writing current_property_provider_test.dart)
- **Issue:** Plan's test code used `asyncValue.valueOrNull` which was removed in Riverpod 3.x (resolved version: 3.3.1). The getter does not exist on `AsyncValue<T>` in this version.
- **Fix:** Replaced with `asyncValue.asData?.value` which correctly returns `T?` in Riverpod 3.x.
- **Files modified:** test/core/current_property_provider_test.dart
- **Commit:** f3cf70b (part of test unskip commit)

**2. [Rule 1 - Bug] Fixed (_, __) → (ctx, _) in GoRoute builders**
- **Found during:** Task 2 (flutter analyze info-severity lint)
- **Issue:** `unnecessary_underscores` lint fires on `__` when `_` suffices. The `flutter analyze` command exits 1 on any issues including info-severity.
- **Fix:** Changed all 5 GoRoute `builder: (_, __) =>` to `builder: (ctx, _) =>`.
- **Files modified:** lib/core/router/router.dart
- **Commit:** ec54482

## Known Stubs

- `_TempShell` in `lib/core/router/router.dart` — intentional stub. Plan 05 replaces with real `AppShell`.
- `CurrentPropertyNotifier.build()` always returns `null` — intentional Phase 0 placeholder. Phase 1 wires to `propriedades` table via `PropertyRepository`.

## Threat Flags

None — all threat register items (T-00-11 through T-00-15) addressed:
- T-00-11: `onError:` handler present in `GoRouterRefreshStream.listen()`
- T-00-13: `verify_no_supabase_in_features.sh` exits 0
- T-00-14: `Env.requireOrThrow()` throws explicit `StateError`
- T-00-15: Phase 0 permissive redirect accepted per plan

## Self-Check: PASSED

Files verified:
- lib/core/env/env.dart: FOUND
- lib/core/theme/app_theme.dart: FOUND
- lib/core/services/supabase_service.dart: FOUND
- lib/core/providers/supabase_providers.dart: FOUND
- lib/core/providers/current_property_provider.dart: FOUND
- lib/core/router/routes.dart: FOUND
- lib/core/router/router.dart: FOUND
- lib/features/dashboard/presentation/dashboard_screen.dart: FOUND
- lib/features/piquetes/presentation/piquetes_screen.dart: FOUND
- lib/features/animais/presentation/animais_screen.dart: FOUND
- lib/features/reproducao/presentation/reproducao_screen.dart: FOUND
- lib/features/sanitario/presentation/sanitario_screen.dart: FOUND

Commits verified:
- 721b087: feat(00-04): add env loader, theme, Supabase service, Riverpod providers
- ec54482: feat(00-04): add GoRouter with 5 routes + placeholder screens
- f3cf70b: test(00-04): unskip theme, current_property_provider, router tests
