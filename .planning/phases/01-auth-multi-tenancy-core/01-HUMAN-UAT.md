---
status: complete
status_was: approved
phase: 01-auth-multi-tenancy-core
source: [01-VERIFICATION.md]
started: 2026-05-05
updated: 2026-08-11
---

<!-- 2026-08-11: status normalized `approved` → `complete` at milestone v1.0 close.
     Same terminal meaning (4/4 pass, 0 pending scenarios); `approved` is not in the
     audit tool's terminal set (`complete` | `resolved`), so it read as an open gap. -->


## Current Test

All 4 tests passed — 2026-05-07.

Bug found and fixed during UAT: router `refreshListenable` only wired to auth
stream; `memberPropertiesProvider` completing did not trigger re-evaluation →
user stayed on /login after successful login. Fixed by replacing
`GoRouterRefreshStream` with `_RouterRefreshNotifier` that also listens to
`memberPropertiesProvider` via `ref.listen`.

## Tests

### 1. Session persistence across reload
expected: After login, reload the browser. Session should survive — user stays on /dashboard without re-login.
result: PASSED

### 2. Email confirmation policy (SC-1 / D-01 tension)
expected: D-01 (01-CONTEXT.md) explicitly disables email confirmation — immediate login-after-signup is correct behavior. SC-1 "receber email de confirmação" in ROADMAP is intentionally loose wording. Confirm no-confirmation flow is accepted.
result: PASSED — no-confirmation flow accepted.

### 3. RLS isolation test (AUTH-05, SC-4)
expected: `integration_test/rls_isolation_test.dart` runs green with `supabase start && supabase db reset` — userA cannot query propriedade of userB (returns empty, not data).
result: PASSED

### 4. End-to-end smoke (login → dashboard → logout)
expected: Sign in as userA@test.com / senha123A → lands on /dashboard → AppBar shows "Fazenda Alpha" as plain Text (1 prop, D-05) → click logout icon → redirects to /login.
result: PASSED

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
