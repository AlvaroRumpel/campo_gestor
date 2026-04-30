---
phase: 00-foundation
plan: 03
subsystem: dependency-management
tags: [foundation, packages, codegen, riverpod, freezed]
dependency_graph:
  requires: [00-01, 00-02]
  provides: [full-phase0-dependency-stack, codegen-pipeline]
  affects: [all-future-phases]
tech_stack:
  added:
    - flutter_riverpod 3.3.1
    - riverpod_annotation 4.0.2
    - go_router 17.2.2
    - supabase_flutter 2.12.4
    - freezed_annotation 3.1.0
    - json_annotation 4.11.0
    - flutter_secure_storage 10.0.0
    - shared_preferences 2.5.5
    - flutter_svg 2.2.4
    - data_table_2 2.7.2
    - intl 0.20.2
    - flutter_localizations (SDK)
    - build_runner 2.15.0
    - freezed 3.2.5
    - json_serializable 6.13.0
    - riverpod_generator 4.0.3
    - mocktail 1.0.5
    - integration_test (SDK)
  patterns:
    - Riverpod 3.x runtime (flutter_riverpod) + 4.x codegen (riverpod_annotation/riverpod_generator)
    - Freezed 3.x immutable data classes + json_serializable 6.x serialization
    - build_runner codegen pipeline proven end-to-end (0 outputs, no annotations yet)
key_files:
  created: []
  modified:
    - pubspec.yaml
    - pubspec.lock
    - test/widget/app_shell_test.dart
    - integration_test/app_smoke_test.dart
decisions:
  - "Riverpod upgraded from planned 2.x to 3.x runtime + 4.x codegen tools due to irreconcilable transitive dependency conflicts with the rest of the stack"
  - "custom_lint and riverpod_lint deferred: incompatible with flutter_riverpod 3.x + freezed_annotation 3.x + json_serializable 6.13.x simultaneously"
  - "testWidgets skip parameter fixed from String to bool (API change in newer Flutter SDK)"
metrics:
  duration: ~25min
  completed: 2026-04-30
  tasks_completed: 2
  files_modified: 4
---

# Phase 00 Plan 03: Dependency Stack Installation Summary

Install the complete Phase 0 dependency stack and validate the codegen pipeline end-to-end.

## Resolved Package Versions (from pubspec.lock)

| Package | Resolved Version | Role |
|---------|-----------------|------|
| flutter_riverpod | **3.3.1** | State management runtime |
| riverpod_annotation | **4.0.2** | Codegen annotation markers |
| riverpod_generator | **4.0.3** | Codegen builder |
| freezed | **3.2.5** | Codegen builder (data classes) |
| freezed_annotation | **3.1.0** | Annotation markers |
| json_serializable | **6.13.0** | JSON codegen builder |
| json_annotation | **4.11.0** | JSON annotation markers |
| go_router | **17.2.2** | Navigation |
| supabase_flutter | **2.12.4** | Backend client |
| intl | **0.20.2** | pt-BR localization |
| flutter_secure_storage | **10.0.0** | Secure token storage |
| shared_preferences | **2.5.5** | User preferences cache |
| flutter_svg | **2.2.4** | SVG rendering |
| data_table_2 | **2.7.2** | Web-optimized data tables |
| mocktail | **1.0.5** | Test mocking |
| build_runner | **2.15.0** | Codegen runner |

Total: 138 dependencies resolved.

## Verification Results

| Check | Result |
|-------|--------|
| `flutter pub get` | Exit 0 — 138 dependencies resolved |
| `dart run build_runner build` | Exit 0 — "wrote 0 outputs" (no annotations yet, D-10 satisfied) |
| `flutter analyze --no-pub` | Exit 0 — No issues found |
| `flutter test --no-pub` | Exit 0 — 1 passed, 6 skipped (Plan 01 scaffolds intact) |
| No `.g.dart`/`.freezed.dart` in git | Confirmed — `.gitignore` covers generated files |
| `pubspec.lock` committed | Confirmed — deterministic builds |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Riverpod 2.x version constraint produces irresolvable dependency graph**
- **Found during:** Task 1 (flutter pub get)
- **Issue:** Plan specified `flutter_riverpod: ">=2.6.1 <3.0.0"` with `riverpod_generator: ">=2.6.5 <3.0.0"`. However:
  - `riverpod_generator 2.x` requires `source_gen ^2.0.0` and `build ^2.0.0`
  - `json_serializable ^6.13.0` requires `source_gen ^4.x`
  - `build_runner ^2.14.0` requires `build ^4.x`
  - These are mutually exclusive — no version of `riverpod_generator 2.x` is compatible with both `build_runner 2.14+` and `json_serializable 6.13+`
- **Fix:** Upgraded to `flutter_riverpod: ">=3.0.0 <4.0.0"`, `riverpod_annotation: ">=4.0.0 <5.0.0"`, `riverpod_generator: ">=4.0.0 <5.0.0"`. Phase 0 has no Riverpod code so no API migration was needed.
- **Files modified:** `pubspec.yaml`
- **Commit:** b19ea84

**2. [Rule 1 - Bug] `custom_lint` / `riverpod_lint` incompatible with full stack**
- **Found during:** Task 1 (dependency resolution investigation)
- **Issue:** `custom_lint` (any version) is incompatible with the combination of `flutter_riverpod 3.x` + `freezed_annotation 3.x` + `json_serializable ^6.13.0` due to transitive `analyzer` / `freezed_annotation` version conflicts.
- **Fix:** Commented out `custom_lint` and `riverpod_lint` in `pubspec.yaml` with explanatory note. Riverpod patterns enforced via `flutter_lints` + code review until ecosystem alignment.
- **Files modified:** `pubspec.yaml`
- **Commit:** b19ea84

**3. [Rule 1 - Bug] `testWidgets` skip parameter type changed from `String` to `bool?`**
- **Found during:** Task 2 (`flutter analyze` output — 3 `argument_type_not_assignable` errors)
- **Issue:** Plan 01 test scaffolds used `skip: 'reason string'` which was valid in older Flutter SDK. Current Flutter 3.41.6 `testWidgets` signature requires `skip: bool?`.
- **Fix:** Changed `skip: 'Wave 0 placeholder...'` to `skip: true` with the reason moved to an inline comment, in both `test/widget/app_shell_test.dart` and `integration_test/app_smoke_test.dart`.
- **Files modified:** `test/widget/app_shell_test.dart`, `integration_test/app_smoke_test.dart`
- **Commit:** 4d2925a

## Commits

| Hash | Message |
|------|---------|
| b19ea84 | feat(00-03): update pubspec.yaml with Phase 0 dependency stack |
| 4912c59 | feat(00-03): lock pubspec.lock (flutter pub get clean) |
| 4d2925a | feat(00-03): validate codegen pipeline and fix skip parameter type |

## Notes for Future Phases

- **Riverpod API:** All future phases must use Riverpod 3.x/4.x APIs. The `@riverpod` annotation codegen pattern (via `riverpod_generator 4.x`) is available. Consult Riverpod 3.x migration guide for `AsyncNotifier`, `Notifier` patterns.
- **custom_lint / riverpod_lint:** Deferred. Re-evaluate when a compatible release is published. Track at `.planning/phases/00-foundation/deferred-items.md` if needed.
- **freezed_annotation:** Resolved to `3.1.0` (slightly above `^3.0.0` floor) — all Phase 1+ freezed models should use Freezed 3.x syntax.

## Self-Check: PASSED

- [x] `pubspec.yaml` modified at `F:\_geral\Projetos\campo_gestor\pubspec.yaml`
- [x] `pubspec.lock` committed (138 deps, deterministic)
- [x] Commit b19ea84 exists (pubspec.yaml)
- [x] Commit 4912c59 exists (pubspec.lock)
- [x] Commit 4d2925a exists (codegen validation + test fix)
- [x] `flutter analyze` clean (0 issues)
- [x] `flutter test` green (1 pass, 6 skip)
- [x] `build_runner` exits 0 (0 outputs — no annotations yet)
