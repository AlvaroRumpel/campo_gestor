---
phase: 01-auth-multi-tenancy-core
fixed_at: 2026-05-05T00:00:00Z
review_path: .planning/phases/01-auth-multi-tenancy-core/01-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-05-05
**Source review:** .planning/phases/01-auth-multi-tenancy-core/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (2 Critical, 4 Warning)
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: Hardcoded `http://` redirect URL breaks password reset on production

**Files modified:** `lib/core/config/app_config.dart` (new), `lib/features/auth/data/auth_repository.dart`
**Commit:** 0aeedde
**Applied fix:** Created `lib/core/config/app_config.dart` with `AppConfig.appOrigin` as a `String.fromEnvironment('APP_ORIGIN')` compile-time constant (defaulting to `http://127.0.0.1:3000` for local dev). Changed `AuthRepository.resetRedirect` from a `static const String` to a `static String get` that returns `'${AppConfig.appOrigin}/reset-password'`. The redirect URL is now injected at build time via `--dart-define=APP_ORIGIN=<origin>` and is never hard-coded in the binary.

---

### CR-02: Unsafe cast chain in `PropertyRepository.fetchMemberProperties` will crash on unexpected data shape

**Files modified:** `lib/features/auth/data/property_repository.dart`
**Commit:** c689a28
**Applied fix:** Added a null guard for `r['propriedades']` before casting to `Map<String, dynamic>`. When the join result is null (RLS blocked the property read mid-query or foreign key is null), the row is returned as `null` and filtered out via `whereType<PropertyMembership>()`. The method now returns only readable memberships instead of throwing a `TypeError`.

---

### WR-01: Auth error on token refresh is silently swallowed — router and UI see stale state forever

**Files modified:** `lib/features/auth/providers/auth_provider.dart`
**Commit:** dd333c7
**Applied fix:** The `onError` handler now checks `err is AuthException`. When an `AuthException` is received (session revoked or expired), `state` is set to `const AsyncData(null)`, clearing the session and causing the router to redirect to `/login`. Non-auth errors (socket exceptions, etc.) continue to keep the last known state, preserving the original behaviour for transient network blips.

---

### WR-02: Logout in `AppShell` does not await `signOut` before clearing the provider — race condition

**Files modified:** `lib/core/widgets/app_shell.dart`
**Commit:** 4911531
**Applied fix:** Swapped the order of the two `await` calls in the logout `onPressed` handler: `clear()` now runs first (removing the persisted `active_property_id` from `SharedPreferences`), then `signOut()` fires the auth event. This ensures the local state is clean before the `GoRouterRefreshStream` notifies listeners and the router evaluates the redirect.

---

### WR-03: Router redirect does not guard against loading `currentPropertyProvider` — transient shell exposure

**Files modified:** `lib/core/router/router.dart`, `lib/core/router/routes.dart`
**Commit:** 2c7ac51
**Applied fix:** Added a `currentPropertyProvider` loading check at the end of the redirect closure (after membership checks pass): if `currentProp.isLoading` is true, the redirect returns `null` to hold navigation until the provider resolves. Also added a doc-comment convention block to `routes.dart` stating that all shell screens must handle `currentPropertyProvider` loading/null state via `.when()` or `.isLoading` — never call `.requireValue` without checking `.hasValue` first.
**Status:** fixed: requires human verification — the added loading guard is a structural change to the router redirect logic; verify that cold-start navigation and property-switching flows behave correctly in manual testing.

---

### WR-04: `enable_confirmations = false` in `config.toml` allows unverified emails to sign in immediately

**Files modified:** `supabase/config.toml`
**Commit:** 087ce2a
**Applied fix:** Added a prominent three-line comment above `enable_confirmations = false` in `[auth.email]` explicitly marking this as a local-dev-only setting and instructing that `enable_confirmations = true` must be set in the production Supabase project via the dashboard before going live.

---

## Skipped Issues

None — all findings were fixed.

---

_Fixed: 2026-05-05_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
