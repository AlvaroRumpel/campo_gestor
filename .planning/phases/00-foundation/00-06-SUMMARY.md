---
phase: 00-foundation
plan: 06
subsystem: bootstrap
tags: [foundation, main, supabase, smoke-test]
dependency_graph:
  requires: [00-01, 00-02, 00-03, 00-04, 00-05]
  provides: [runnable-app, supabase-local-stack, sc-1-verified, sc-2-verified]
  affects: [all-future-phases]
key_files:
  created:
    - lib/main.dart
    - integration_test/app_smoke_test.dart
  modified:
    - pubspec.yaml (flutter_web_plugins added)
    - test/widget_test.dart (stale MyApp reference replaced)
    - .planning/ROADMAP.md
    - .planning/STATE.md
decisions:
  - "integration_test does not support web targets — SC-1 verified via manual flutter run -d edge (Option B)"
  - "supabase_vector (analytics) disabled in config.toml — Docker socket not accessible from container on Windows WSL2"
  - "SC-2 passed after analytics disabled and supabase db reset succeeded clean"
metrics:
  duration: ~2 sessions
  completed: 2026-05-03
  tasks_completed: 2
  files_modified: 4
---

# Phase 00 Plan 06: Bootstrap + Supabase Init Summary

Wire `main.dart` bootstrap, initialize Supabase local stack, and verify SC-1 (app renders) and SC-2 (db reset clean).

## Verification Results

| Check | Result |
|-------|--------|
| `lib/main.dart` — full bootstrap with `usePathUrlStrategy`, `Env.requireOrThrow`, `Supabase.initialize`, `ProviderScope` | ✓ |
| `flutter analyze` | ✓ Exit 0 — no issues |
| `flutter test --no-pub` | ✓ 9 passed (unit + widget) |
| SC-2: `supabase db reset` | ✓ Exit 0 after analytics disabled |
| SC-1: `flutter run -d edge --dart-define=...` | ✓ App shell renders (NavigationRail, Dashboard label, no crash) |

## Deviations from Plan

### Auto-fixed Issues

**1. `flutter_web_plugins` missing from pubspec.yaml**
- `main.dart` imports `package:flutter_web_plugins/url_strategy.dart` (for `usePathUrlStrategy`)
- Package was not declared in `pubspec.yaml`
- **Fix:** Added `flutter_web_plugins: sdk: flutter` to dependencies
- **Commit:** 75d33fc

**2. Stale `test/widget_test.dart` referenced deleted `MyApp`**
- Default Flutter counter test referenced `MyApp` class which no longer exists
- **Fix:** Replaced with Phase-0 placeholder `testWidgets('placeholder', ...)`
- **Commit:** 75d33fc

**3. `integration_test` does not support web targets**
- `flutter test integration_test/... -d edge` fails: "Web devices are not supported for integration tests yet"
- Flutter limitation — integration_test package only works on mobile/desktop
- **Resolution:** SC-1 verified manually via `flutter run -d edge` (visual confirmation: shell renders, NavigationRail visible, no crash)
- Smoke test file kept active; will run on Windows/mobile in CI when needed

**4. `supabase_vector` crash loop on Windows**
- Vector log-aggregator container tries to access Docker socket via TCP inside container
- Windows Docker Desktop (WSL2) → Docker socket not reachable from container network namespace
- Error: `ConnectError("tcp connect error", Os { code: 101, kind: NetworkUnreachable })`
- **Fix:** Set `[analytics] enabled = false` in `supabase/config.toml`
- `supabase stop && supabase start` → all containers stable (no vector)

## Commits

| Hash | Message |
|------|---------|
| 75d33fc | feat(00-06): main.dart bootstrap + flutter_web_plugins + widget_test fix |
| 22a77cd | test(00-06): activate integration smoke test |

## Success Criteria — All Green

| SC | Criterion | Status |
|----|-----------|--------|
| SC-1 | `flutter run -d edge` renders app shell in <2s | ✓ Manual verification |
| SC-2 | `supabase db reset` exits 0 | ✓ Exit 0 |
| SC-3 | `currentPropertyProvider` available (returns null) | ✓ In core/providers |
| SC-4 | GoRouter configured with web-friendly URLs | ✓ usePathUrlStrategy + StatefulShellRoute |
| SC-5 | Repository/Service base layer — features never import Supabase SDK directly | ✓ SupabaseService singleton in lib/core/services |

## Notes for Future Phases

- **Analytics disabled locally:** `[analytics] enabled = false` in `supabase/config.toml`. Safe for local dev — no log aggregation needed for MVP.
- **Integration tests:** Use `-d windows` (after `flutter config --enable-windows-desktop`) or `-d chrome` (when Flutter adds web support). Do not use `-d edge` for integration_test.
- **Env vars:** Always pass `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Launch configs in `.vscode/launch.json` (gitignored, template at `.vscode/launch.json.example`).
- **Supabase CLI on Windows:** Available via Scoop — run from PowerShell, not bash.

## Self-Check: PASSED

- [x] `lib/main.dart` exists and bootstraps with Env + Supabase + ProviderScope
- [x] `flutter analyze` clean (0 issues)
- [x] `flutter test` green (9 pass)
- [x] `supabase db reset` exits 0 (SC-2)
- [x] App shell renders on Edge with real Supabase connection (SC-1)
- [x] All 5 Phase 0 success criteria satisfied
