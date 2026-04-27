---
phase: 0
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 0 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `mocktail ^1.0.5` |
| **E2E Framework** | `integration_test` (SDK) |
| **Config file** | `analysis_options.yaml` (exists); `test/` directory (Wave 0 creates) |
| **Quick run command** | `rtk flutter test --no-pub` |
| **Full suite command** | `rtk flutter test && rtk flutter analyze` |
| **Smoke test (web)** | `flutter test integration_test/app_smoke_test.dart -d edge --dart-define=SUPABASE_URL=http://localhost:54321 --dart-define=SUPABASE_ANON_KEY=<local-key>` |
| **Estimated runtime** | ~30s quick run; ~60s full suite |

---

## Sampling Rate

- **After every task commit:** `rtk flutter analyze && rtk flutter test --no-pub`
- **After every plan wave:** `rtk flutter test && rtk flutter analyze && bash scripts/verify_no_supabase_in_features.sh`
- **Before `/gsd-verify-work`:** Full suite + smoke integration test + `supabase db reset` green
- **Max feedback latency:** 30 seconds (quick run)

---

## Per-Task Verification Map

Phase 0 has no REQ-IDs — mapping is by Success Criteria (SC) from ROADMAP.md.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 0-SC1 | AppShell | 4 | SC-1 (TTI <2s) | — | N/A | smoke | `flutter test integration_test/app_smoke_test.dart -d edge` | ❌ W0 | ⬜ pending |
| 0-SC2 | Supabase | 1 | SC-2 (migrations) | T-V14 | CLI-only schema changes | shell | `supabase db reset` exit 0; `bash scripts/verify_supabase.sh` | ❌ W0 | ⬜ pending |
| 0-SC3 | Riverpod | 3 | SC-3 (currentPropertyProvider) | — | N/A | unit | `flutter test test/core/current_property_provider_test.dart` | ❌ W0 | ⬜ pending |
| 0-SC4 | GoRouter | 3 | SC-4 (deep links, back) | — | `usePathUrlStrategy()` | widget | `flutter test test/core/router_test.dart` | ❌ W0 | ⬜ pending |
| 0-SC5 | Repository | 3 | SC-5 (no Supabase in features) | — | abstract layer enforced | static | `bash scripts/verify_no_supabase_in_features.sh` | ❌ W0 | ⬜ pending |
| 0-theme | Theme | 3 | — | T-V6 (secrets not in bundle) | anon key only, no service key | unit | `flutter test test/core/theme_test.dart` | ❌ W0 | ⬜ pending |
| 0-shell | AppShell | 4 | SC-1 (shell renders) | — | N/A | widget | `flutter test test/widget/app_shell_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/core/router_test.dart` — cover SC-4 (PathUrlStrategy + 5 routes navigable)
- [ ] `test/core/theme_test.dart` — smoke ThemeData loads with seedColor
- [ ] `test/core/current_property_provider_test.dart` — cover SC-3 (returns null in initial state)
- [ ] `test/widget/app_shell_test.dart` — AppShell renders at both breakpoints (layout assertions)
- [ ] `integration_test/app_smoke_test.dart` — cover SC-1 (boot end-to-end without crash)
- [ ] `scripts/verify_no_supabase_in_features.sh` — cover SC-5 (grep custom lint)
- [ ] `scripts/verify_supabase.sh` — cover SC-2 (`supabase db reset` with exit code check)
- [ ] `test/test_helper.dart` — dart-define defaults for local Supabase (test environment setup)
- [ ] Add `mocktail ^1.0.5` and `integration_test` to `pubspec.yaml` dev_dependencies

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| TTI <2s in 4G simulated | SC-1 | Browser DevTools throttling not scriptable | `flutter run -d edge --profile`, open DevTools → Network → Slow 4G, measure time to interactive |
| Sidebar ↔ Bottom nav breakpoint at 600px | SC-1 / D-03 | Visual layout breakpoint | Resize browser window through 600px, verify NavigationRail ↔ NavigationBar transition |
| `supabase db reset` completes without error | SC-2 | Requires local Docker + Supabase CLI running | Run `supabase start` then `supabase db reset`, verify exit 0 and no migration errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
