---
status: partial
phase: 01-auth-multi-tenancy-core
source: [01-VERIFICATION.md]
started: 2026-05-05
updated: 2026-05-05
---

## Current Test

[awaiting human testing]

## Tests

### 1. Session persistence across reload
expected: After login, reload the browser. Session should survive — user stays on /dashboard without re-login.
result: [pending]

### 2. Email confirmation policy (SC-1 / D-01 tension)
expected: D-01 (01-CONTEXT.md) explicitly disables email confirmation — immediate login-after-signup is correct behavior. SC-1 "receber email de confirmação" in ROADMAP is intentionally loose wording. Confirm no-confirmation flow is accepted.
result: [pending]

### 3. RLS isolation test (AUTH-05, SC-4)
expected: `integration_test/rls_isolation_test.dart` runs green with `supabase start && supabase db reset` — userA cannot query propriedade of userB (returns empty, not data).
result: [pending]

### 4. End-to-end smoke (login → dashboard → logout)
expected: Sign in as userA@test.com / senha123A → lands on /dashboard → AppBar shows "Fazenda Alpha" as plain Text (1 prop, D-05) → click logout icon → redirects to /login.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
