---
phase: 00-foundation
plan: 01
subsystem: validation-scaffolding
tags: [foundation, testing, scaffolding, lint, supabase]
dependency_graph:
  requires: []
  provides:
    - "Wave 0 test scaffolding (compile-ready, all skipped)"
    - "SC-2 verification script (verify_supabase.sh)"
    - "SC-5 verification script (verify_no_supabase_in_features.sh)"
    - "Lint configuration baseline (analysis_options.yaml with custom_lint plugin)"
  affects:
    - "All downstream plans (00-02..00-06) — they unskip scaffolded tests"
    - "Plan 04 (router, theme, current_property_provider) — unskips test/core/*"
    - "Plan 05 (AppShell, main.dart) — unskips test/widget/* + integration_test/*"
tech_stack:
  added: []
  patterns:
    - "Skipped placeholder tests with skip: 'Wave 0 placeholder' string"
    - "TODO(plan-NN) markers for traceability between scaffolds and downstream plans"
    - "Forward-compatible analyzer plugin reference (custom_lint pre-declared)"
    - "Script pre-flight checks (CLI presence + Docker daemon) before destructive ops"
key_files:
  created:
    - "test/test_helper.dart"
    - "test/core/router_test.dart"
    - "test/core/theme_test.dart"
    - "test/core/current_property_provider_test.dart"
    - "test/widget/app_shell_test.dart"
    - "integration_test/app_smoke_test.dart"
    - "scripts/verify_no_supabase_in_features.sh"
    - "scripts/verify_supabase.sh"
  modified:
    - "analysis_options.yaml"
decisions:
  - "Tests start with skip: 'Wave 0 placeholder — unskip when production file lands' so flutter test exits 0 even when production files don't exist yet (Nyquist sampling)"
  - "TODO(plan-NN) markers on every scaffold trace which downstream plan unskips each test"
  - "custom_lint plugin pre-declared in analysis_options.yaml even though packages land in Plan 03 — analyzer ignores plugin section until packages exist"
  - "Verification scripts use exit 0 on no-op (lib/features/ absent) so they can be wired into CI from day one without false negatives"
  - "Scripts marked executable (mode 100755) in git index via git update-index --chmod=+x for cross-platform consistency"
metrics:
  duration_minutes: 4
  completed_date: "2026-04-27"
  tasks_completed: 2
  files_created: 8
  files_modified: 1
---

# Phase 00 Plan 01: Validation Scaffolding (Wave 0) Summary

Wave 0 test scaffolds, two bash verification scripts (SC-2 and SC-5), and lint configuration baseline so every downstream plan can run `rtk flutter test` and the SC scripts for fast feedback before production code lands.

## What Was Built

### Test Scaffolds (6 files)

All tests start `skip: 'Wave 0 placeholder — unskip when production file lands'` so `flutter test --no-pub` exits 0 even before production code exists. Each file carries a `// TODO(plan-NN):` marker pointing to the downstream plan that unskips it.

| File | Skipped Tests | Validates | Unskipped By |
|------|---------------|-----------|--------------|
| `test/test_helper.dart` | n/a (utility) | dart-define defaults for local Supabase | (used by future tests) |
| `test/core/router_test.dart` | 2 | SC-4 (5 routes + path URL strategy) | Plan 04 |
| `test/core/theme_test.dart` | 1 | AppTheme.light() seedColor #4A6741 | Plan 04 |
| `test/core/current_property_provider_test.dart` | 1 | SC-3 (provider returns null initial) | Plan 04 |
| `test/widget/app_shell_test.dart` | 2 | SC-1 widget breakpoints (1024 / 360) | Plan 05 |
| `integration_test/app_smoke_test.dart` | 1 | SC-1 boot end-to-end | Plan 05 |

Total skipped tests scaffolded: **7** (matches plan acceptance criteria: 2 + 1 + 1 + 2 + 1).

### Verification Scripts (2 files)

| Script | Validates | Behavior |
|--------|-----------|----------|
| `scripts/verify_no_supabase_in_features.sh` | SC-5 (D-06 Repository pattern) | greps `package:supabase_flutter` in `lib/features/`; exits 1 on offenders; no-op (exit 0) until `lib/features/` exists |
| `scripts/verify_supabase.sh` | SC-2 (migrations apply cleanly) | wraps `supabase db reset` with pre-flight checks for `supabase` CLI (exit 2) and Docker (exit 3) |

Both marked executable (mode `100755`) in the git index via `git update-index --chmod=+x`.

### Lint Configuration (1 file modified)

`analysis_options.yaml` now:

- **Includes** `package:flutter_lints/flutter.yaml` (preserved).
- **Declares** `custom_lint` analyzer plugin (forward-compatible: only activates when Plan 03 adds `custom_lint` + `riverpod_lint` to `dev_dependencies`).
- **Excludes** codegen outputs from analysis: `**/*.g.dart`, `**/*.freezed.dart`, `build/**`, `.dart_tool/**`.
- **Adds** project lint rules: `avoid_print: true`, `prefer_const_constructors: true`, `prefer_const_literals_to_create_immutables: true`, `require_trailing_commas: true`, `sort_pub_dependencies: false`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create test scaffolds + test_helper.dart | `274c4df` | 6 test files (test_helper, router_test, theme_test, current_property_provider_test, app_shell_test, app_smoke_test) |
| 2 | Verification scripts + analysis_options.yaml | `134f197` | 2 scripts (verify_no_supabase_in_features.sh, verify_supabase.sh) + analysis_options.yaml |

## Verification Results

| Check | Method | Result |
|-------|--------|--------|
| All 6 test files exist with `skip:` parameters | Grep on `test/` and `integration_test/` | PASS — 6 skip markers across 4 test files (router=2, theme=1, current_property=1, app_shell=2, smoke=1) |
| Each test file has `TODO(plan-NN)` marker | Grep on `TODO\(plan-` in `test/` and `integration_test/` | PASS — 5 markers (router→04, theme→04, current_property→04, app_shell→05, smoke→05) |
| `test/test_helper.dart` contains `defaultValue: 'http://localhost:54321'` | Grep | PASS |
| `analysis_options.yaml` contains `custom_lint`, codegen excludes, lint rules | Grep | PASS |
| `scripts/verify_supabase.sh` contains `command -v supabase`, `docker info`, `supabase db reset` | Grep | PASS |
| `scripts/verify_no_supabase_in_features.sh` contains `OK: No direct supabase_flutter imports` | Grep | PASS |
| Scripts marked executable (mode 100755) | `git ls-files --stage scripts/` | PASS — both at 100755 |

## Deferred Verification

The plan's `<automated>` verify commands (`flutter test --no-pub`, `flutter analyze --no-pub`, `bash scripts/verify_no_supabase_in_features.sh`) **could not be executed** in this agent session because the executor environment denies direct invocation of `flutter`, `bash <script>`, and `sh <script>`. Static verification (Grep/file contents/git index mode) confirms every acceptance criterion. Functional verification deferred to:

- **Plan 02 (Bootstrap)** — runs `flutter pub get` then `flutter test` and `flutter analyze`. Will surface any compile or lint issue with the scaffolds at that point.
- **Wave 1 onward** — sampling rate of `rtk flutter test --no-pub` after every task per VALIDATION.md ensures issues bubble up within ~30 s.

This is documented as a deferred check, not a blocker — Wave 0 scaffolds are deliberately skipped placeholders that compile against `flutter_test` only (already in `dev_dependencies`).

## Deviations from Plan

None — plan executed exactly as written.

The only friction was operational (executor sandbox blocks direct `flutter`/`bash` invocation), not a deviation from the plan's behavior or acceptance criteria. All eight `<acceptance_criteria>` items in Task 1 and all six in Task 2 verified statically via Grep, file inspection, and `git ls-files --stage`.

## Authentication Gates

None encountered. Plan touches only local files and git; no external services or credentials required.

## Threat Model Compliance

| Threat ID | Disposition | Status |
|-----------|-------------|--------|
| T-00-01 (info disclosure in `verify_supabase.sh`) | mitigate | OK — script does not echo or log anon/service keys; only invokes `supabase db reset` which uses CLI defaults from `supabase/config.toml` |
| T-00-02 (lint tampering) | accept | N/A — accepted risk per plan |
| T-00-03 (test scaffolding repudiation) | accept | OK — all scaffold files have TODO markers + git history |

## Known Stubs

This plan creates Wave 0 placeholders intentionally — every test starts skipped and contains no real assertions. These are not "stubs" in the sense of half-implemented production code; they are tracked instrumentation that downstream plans (04, 05) wire to real production files. Each scaffold has an explicit TODO marker naming the unskipping plan, so they cannot be silently forgotten.

No production-code stubs were introduced.

## Threat Flags

None — plan introduces no new network endpoints, auth paths, file access patterns, or schema changes. The two new shell scripts are local development tooling that read filesystem and invoke installed CLIs; they do not cross any new trust boundary.

## Self-Check

- [x] `test/test_helper.dart` exists — verified via Read + Grep.
- [x] `test/core/router_test.dart` exists with 2 `test(` + `skip:` calls — verified via Grep count.
- [x] `test/core/theme_test.dart` exists with 1 `test(` + `skip:` — verified.
- [x] `test/core/current_property_provider_test.dart` exists with 1 `test(` + `skip:` — verified.
- [x] `test/widget/app_shell_test.dart` exists with 2 `testWidgets(` + `skip:` — verified.
- [x] `integration_test/app_smoke_test.dart` exists with 1 `testWidgets(` + `skip:` — verified.
- [x] All 5 TODO(plan-NN) markers present and correctly numbered (3×plan-04, 2×plan-05).
- [x] `scripts/verify_no_supabase_in_features.sh` exists, mode 100755 — verified via `git ls-files --stage`.
- [x] `scripts/verify_supabase.sh` exists, mode 100755, contains required pre-flight strings — verified via Grep.
- [x] `analysis_options.yaml` contains `custom_lint`, codegen excludes, project lint rules — verified via Grep.
- [x] Commit `274c4df` (Task 1) exists — verified via `rtk git log`.
- [x] Commit `134f197` (Task 2) exists — verified via `rtk git log`.

## Self-Check: PASSED

All artifacts in `key_files.created` and `key_files.modified` exist on disk and in the git tree at the expected commits. No missing items.
