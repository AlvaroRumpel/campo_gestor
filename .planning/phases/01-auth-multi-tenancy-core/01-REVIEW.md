---
phase: 01-auth-multi-tenancy-core
reviewed: 2026-05-05T00:00:00Z
depth: standard
files_reviewed: 20
files_reviewed_list:
  - integration_test/rls_isolation_test.dart
  - lib/core/providers/current_property_provider.dart
  - lib/core/router/router.dart
  - lib/core/router/routes.dart
  - lib/core/widgets/app_shell.dart
  - lib/core/widgets/property_selector.dart
  - lib/features/auth/data/auth_repository.dart
  - lib/features/auth/data/property_repository.dart
  - lib/features/auth/presentation/login_screen.dart
  - lib/features/auth/presentation/no_access_screen.dart
  - lib/features/auth/presentation/reset_password_screen.dart
  - lib/features/auth/presentation/signup_screen.dart
  - lib/features/auth/providers/auth_provider.dart
  - supabase/config.toml
  - supabase/migrations/20260504_01_auth_multitenancy.sql
  - supabase/seed.sql
  - test/core/current_property_provider_test.dart
  - test/features/auth/auth_repository_test.dart
  - test/features/auth/login_screen_test.dart
  - test/features/auth/property_repository_test.dart
findings:
  critical: 2
  warning: 4
  info: 4
  total: 10
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-05
**Depth:** standard
**Files Reviewed:** 20
**Status:** issues_found

## Summary

This phase delivers the auth + multi-tenancy foundation: Supabase GoTrue integration, per-user property membership, an RLS-secured schema, a GoRouter auth guard, and supporting UI screens. The architecture is well-structured — the Abstract Repository pattern is correctly applied, RLS is enabled with `FORCE ROW LEVEL SECURITY`, and the provider graph's dependency chain (auth → membership → property selection) is sound.

Two critical issues were found. The most impactful is a hardcoded `http://` redirect URL in `AuthRepository` that will silently break the password-reset flow on production (HTTPS required). The second is an unsafe cast chain in `PropertyRepository.fetchMemberProperties` that will throw an unhandled runtime exception if the PostgREST join returns an unexpected shape.

Four warnings cover auth state swallowing an error silently, a logout sequencing race in `AppShell`, a `resetPassword` URL that is never updated for a production build, and a router guard that can transiently admit unauthenticated users to the shell during the loading window. Four informational items cover code style and test coverage gaps.

---

## Critical Issues

### CR-01: Hardcoded `http://` redirect URL breaks password reset on production

**File:** `lib/features/auth/data/auth_repository.dart:20`

**Issue:** `resetRedirect` is permanently set to `http://127.0.0.1:3000/reset-password`. This value is baked into the binary. When the app is deployed to production, Supabase will send the reset email with a link pointing at `127.0.0.1` — a localhost address that does not exist from the end user's browser. The flow breaks completely in production. Additionally, `config.toml line 156` lists `additional_redirect_urls` with a mix of `http://` and `https://` localhost entries, but none of these cover a production domain, so even if the right domain were used, it would be rejected by GoTrue's allow-list.

**Fix:** Make the redirect URL an injectable constant (compile-time `--dart-define` or a config layer), never hard-code a `http://127.0.0.1` address in a repository that ships to production.

```dart
// In lib/core/config/app_config.dart (new file)
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appOrigin = String.fromEnvironment(
    'APP_ORIGIN',
    defaultValue: 'http://127.0.0.1:3000', // local dev only
  );
}

// In auth_repository.dart
static String get resetRedirect =>
    '${AppConfig.appOrigin}/reset-password';
```

Pair this with updating `config.toml additional_redirect_urls` to include the production domain, and add the production domain to `[auth] site_url` when the production Supabase project is configured.

---

### CR-02: Unsafe cast chain in `PropertyRepository.fetchMemberProperties` will crash on unexpected data shape

**File:** `lib/features/auth/data/property_repository.dart:49-55`

**Issue:** The method casts the entire Supabase response with `as List` and each element with `as Map<String, dynamic>`, then immediately accesses `r['propriedades'] as Map<String, dynamic>` without a null check. PostgREST embedded selects (`propriedades(id, nome)`) return `null` for the join column if the foreign key is null or the RLS policy on `propriedades` blocks the read mid-query (e.g., a race during membership revocation). When `r['propriedades']` is `null`, the cast `as Map<String, dynamic>` succeeds at runtime but the subsequent `p['id'] as String` throws a `Null check operator used on a null value` (or a `TypeError`) that propagates as an unhandled exception through `memberPropertiesProvider` and leaves the router in a permanent loading state.

```dart
// current — crashes if propriedades join is null
final p = r['propriedades'] as Map<String, dynamic>;
return PropertyMembership(
  property: Property(id: p['id'] as String, nome: p['nome'] as String),
  perfil: r['perfil'] as String,
);
```

**Fix:** Guard against a null join result and filter out or throw a meaningful error:

```dart
return (rows as List).map((row) {
  final r = row as Map<String, dynamic>;
  final rawProp = r['propriedades'];
  if (rawProp == null) {
    // Membership row exists but property is not readable — skip it.
    return null;
  }
  final p = rawProp as Map<String, dynamic>;
  return PropertyMembership(
    property: Property(
      id: p['id'] as String,
      nome: p['nome'] as String,
    ),
    perfil: r['perfil'] as String,
  );
}).whereType<PropertyMembership>().toList();
```

---

## Warnings

### WR-01: Auth error on token refresh is silently swallowed — router and UI see stale state forever

**File:** `lib/features/auth/providers/auth_provider.dart:31-34`

**Issue:** The `onError` handler of the `onAuthStateChange` subscription is a no-op comment. When a token refresh fails (bad network, revoked token), the stream emits an error. The handler catches it but does not update `state` — the notifier retains the last `AsyncData` value, meaning the router continues treating the user as authenticated even if the session is dead. Downstream providers that depend on `authNotifierProvider` (including the entire `memberPropertiesProvider` chain) will issue Supabase requests with an expired/revoked JWT, all of which will fail with 401s but those errors are independent of the auth state the router reads.

```dart
// current — error is silently ignored
onError: (Object err, StackTrace st) {
  // Network errors during refresh — keep last known state, don't crash.
},
```

**Fix:** Distinguish between transient network errors and fatal auth errors. At minimum, on a fatal auth failure, transition the notifier to `AsyncError` so the router's `authAsync.isLoading` path does not mask it, and so downstream providers react:

```dart
onError: (Object err, StackTrace st) {
  // Transient: supabase emits AuthException with message 'token_refresh_failed'
  // for network blips. Fatal: any other auth error clears the session.
  if (err is AuthException) {
    // Session is gone — force unauthenticated state so router redirects to /login.
    state = const AsyncData(null);
  }
  // For non-auth errors (socket errors etc.) keep last known state — router
  // will retry on next authStateChange event.
},
```

---

### WR-02: Logout in `AppShell` does not await `signOut` before clearing the provider — race condition

**File:** `lib/core/widgets/app_shell.dart:64-67`

**Issue:** The logout button's `onPressed` handler calls `signOut()` and `clear()` in parallel with `await` but no coordination:

```dart
onPressed: () async {
  await ref.read(authRepositoryProvider).signOut();
  await ref.read(currentPropertyProvider.notifier).clear();
},
```

This ordering looks sequential, but `signOut()` triggers a `signedOut` auth event that flows through `GoRouterRefreshStream` → `notifyListeners()` → router redirect evaluation **before** `clear()` has finished. The router's redirect reads `memberPropertiesProvider` (which depends on `authNotifierProvider` which is now `AsyncData(null)`) and routes to `/login` while `currentPropertyProvider` still holds the old `AsyncData(Property(...))`. On the next cold start, `SharedPreferences` still contains the stale `active_property_id` (if `clear()` did not complete its `prefs.remove` before the app was rebuilt/navigated away).

This is not a data-loss security issue (RLS is the real enforcement), but it can cause a stale property ID to persist in `SharedPreferences` when the user is signed out abruptly.

**Fix:** Call `clear()` before `signOut()` so the persisted ID is removed before the auth state change fires:

```dart
onPressed: () async {
  // Clear local state first so SharedPreferences is clean before
  // the auth event fires and triggers a router redirect.
  await ref.read(currentPropertyProvider.notifier).clear();
  await ref.read(authRepositoryProvider).signOut();
},
```

---

### WR-03: Router redirect does not guard against loading `currentPropertyProvider` — transient shell exposure

**File:** `lib/core/router/router.dart:71-78`

**Issue:** When a user is authenticated and has memberships, the redirect only checks `memberPropertiesProvider` for loading state. It does not check `currentPropertyProvider`, which is an `AsyncNotifier` that is itself async. An authenticated user navigating directly to `/dashboard` on cold start will pass all redirect checks (`isLoggedIn = true`, `membersList.isNotEmpty`) while `currentPropertyProvider` is still loading. The shell (`AppShell`) renders immediately, `PropertySelector` shows a `CircularProgressIndicator`, and the feature screens (Dashboard, etc.) receive a `null` active property from `ref.watch(currentPropertyProvider)`. If any downstream screen accesses `currentPropertyProvider.requireValue` without a null guard, it will throw.

This is not currently catastrophic because no feature screen exists yet beyond scaffolding, but it is a structural gap that will manifest in Phase 2 when screens actively use the property.

**Fix:** Add a `currentPropertyProvider` loading check in the redirect, or document explicitly that all shell screens must handle `currentPropertyProvider.isLoading` via `.when()` (the `PropertySelector` already does this — make it a convention enforced by a linting comment in the routes file).

---

### WR-04: `enable_confirmations = false` in `config.toml` allows unverified emails to sign in immediately

**File:** `supabase/config.toml:219`

**Issue:** `[auth.email] enable_confirmations = false` means a freshly registered user can sign in without verifying their email address. This is intentional for local dev (`inbucket` handles email), but the config is checked into git and will be used as the baseline when the team bootstraps the production Supabase project if they do not override it. An attacker who registers with a victim's email address can immediately access the app.

**Fix:** Add a prominent comment, and ensure the production Supabase project has `enable_confirmations = true` set via the Supabase dashboard or a separate production config file. This should be documented in the project `CLAUDE.md` under Constraints or in the deployment checklist.

```toml
# LOCAL DEV ONLY — set enable_confirmations = true in production Supabase project.
enable_confirmations = false
```

---

## Info

### IN-01: `_isRecoveryState` in `ResetPasswordScreen` reads provider with `ref.read` — misses reactive updates

**File:** `lib/features/auth/presentation/reset_password_screen.dart:31-34`

**Issue:** `_isRecoveryState` is a getter that calls `ref.read(authNotifierProvider)`. It is called once in `build()` on line 76. If the auth state updates (e.g., the recovery event arrives after the widget is first built), the widget does not rebuild because `ref.read` does not establish a subscription. The recovery mode toggle (`recovery = _isRecoveryState`) would remain `false` even after the token lands.

**Fix:** Move the watch into `build()` and use `ref.watch`:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final recovery = ref.watch(authNotifierProvider).asData?.value?.event
      == AuthChangeEvent.passwordRecovery;
  // ... rest of build
}
```

Remove the `_isRecoveryState` getter and the `ref.read(authNotifierProvider)` call in `_submitNewPassword` (it is not needed there — the action is only reachable when `recovery == true`).

---

### IN-02: `_kActivePropertyIdKey` is a private constant — not testable from outside the file

**File:** `lib/core/providers/current_property_provider.dart:25`

**Issue:** The SharedPreferences key `'active_property_id'` is duplicated as a string literal in `test/core/current_property_provider_test.dart:47` (`SharedPreferences.setMockInitialValues({'active_property_id': 'p2'})`). If the key changes in the provider, the test continues passing because `SharedPreferences.setMockInitialValues` silently sets a key that is never read.

**Fix:** Export the key as a `@visibleForTesting` constant, or use an integration pattern where the test invokes `selectProperty()` and reads back from `SharedPreferences.getInstance()` (which the `selectProperty persists id` test already does correctly). At minimum, add a comment warning that the string must stay in sync.

---

### IN-03: `test_helper.dart` default anon key is a non-functional placeholder

**File:** `test/test_helper.dart:12-14`

**Issue:** `defaultValue: 'test-anon-key-placeholder'` is not a valid JWT. If the integration test runs without `--dart-define=SUPABASE_ANON_KEY=...`, the Supabase client will initialize but every request will fail with a `401 invalid JWT`. The test will then fail with a confusing "Sign in returned null session" error rather than a clear "missing credentials" message.

**Fix:** Either assert that the env var is set (fail fast with a meaningful error), or document the required `--dart-define` flags in a `README` section or a CI script. Consider using `fail()` if the key still contains the placeholder token when the test runs in CI:

```dart
String testSupabaseAnonKey() {
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  assert(key.isNotEmpty, 'Set --dart-define=SUPABASE_ANON_KEY=<local-anon-key>');
  return key;
}
```

---

### IN-04: `property_repository_test.dart` only tests struct shape — no behavior is verified

**File:** `test/features/auth/property_repository_test.dart:17-20`

**Issue:** The second test (`'PropertyRepository exposes fetchMemberProperties signature'`) asserts `expect(PropertyRepository, isA<Type>())` — this is a tautology (every Dart class is a `Type`). It passes regardless of whether `PropertyRepository` or `fetchMemberProperties` exist, because a compile error would be the real guard. The test adds no signal.

**Fix:** Replace with a test that mocks `SupabaseService`, stubs the `.from('property_members').select(...)` chain, and verifies `fetchMemberProperties()` returns the expected `PropertyMembership` objects. This would also exercise the null-guard fix from CR-02.

---

_Reviewed: 2026-05-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
