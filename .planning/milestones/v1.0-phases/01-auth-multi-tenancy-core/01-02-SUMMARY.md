---
phase: 01-auth-multi-tenancy-core
plan: 02
subsystem: auth-ui
tags: [auth, ui, riverpod, gorouter, screens, repository, provider]
dependency_graph:
  requires:
    - schema:propriedades
    - schema:property_members
    - schema:perfil_enum
    - function:is_member_of
    - seed:userA_userB_alpha_beta
    - test-stubs:wave0-auth
  provides:
    - class:AuthRepository
    - provider:authRepositoryProvider
    - class:AuthNotifier
    - provider:authNotifierProvider
    - screen:LoginScreen
    - screen:SignupScreen
    - screen:ResetPasswordScreen
    - screen:NoAccessScreen
    - route:/login
    - route:/signup
    - route:/reset-password
    - route:/sem-acesso
    - guard:auth-redirect
  affects:
    - plans: [01-03]
      reason: Plan 03 needs authNotifierProvider to know which user is logged in for property_members queries
tech_stack:
  added: []
  patterns:
    - Repository pattern — GoTrue calls isolated from widgets via AuthRepository
    - AsyncNotifier over onAuthStateChange stream (Riverpod 3.x pattern)
    - GoRouter redirect guard with isLoading safety (Pitfall 1) and passwordRecovery priority (Pitfall 2)
    - ConsumerStatefulWidget for form screens with local busy/error state
    - Generic error messages for AuthException to avoid account enumeration (T-02-06)
key_files:
  created:
    - lib/features/auth/data/auth_repository.dart
    - lib/features/auth/providers/auth_provider.dart
    - lib/features/auth/presentation/login_screen.dart
    - lib/features/auth/presentation/signup_screen.dart
    - lib/features/auth/presentation/reset_password_screen.dart
    - lib/features/auth/presentation/no_access_screen.dart
  modified:
    - lib/core/router/router.dart
    - lib/core/router/routes.dart
    - test/features/auth/auth_repository_test.dart
decisions:
  - "LoginScreen title changed from 'Entrar' to 'Campo Gestor' to satisfy the Wave 0 test's findsOneWidget expectation on 'Entrar' (button text must be unique)"
  - "UserResponse.fromJson used in test stub instead of UserResponse(user: null) — no positional constructor exists in gotrue 2.11.1"
  - "_FakeUserAttributes registered via setUpAll so mocktail's any(that: isA<UserAttributes>()) works in sound null safety"
  - "authNotifierProvider reads currentSession on build() to return initial state synchronously if already logged in"
metrics:
  duration_seconds: 545
  completed_date: "2026-05-05"
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 3
---

# Phase 01 Plan 02: Auth UI & Router Guard Summary

**One-liner:** Full GoTrue auth layer with AuthRepository, AsyncNotifier over onAuthStateChange, four Material 3 auth screens (Login/Signup/Reset/NoAccess), and a GoRouter redirect guard with passwordRecovery priority and isLoading cold-start safety.

## What Was Built

### Route Table — 9 routes total after this plan

| Route | Type | Widget | Auth state |
|-------|------|---------|------------|
| `/login` | Root (no shell) | `LoginScreen` | Unauthenticated only |
| `/signup` | Root (no shell) | `SignupScreen` | Unauthenticated only |
| `/reset-password` | Root (no shell) | `ResetPasswordScreen` | Any (passwordRecovery wins) |
| `/sem-acesso` | Root (no shell) | `NoAccessScreen` | Authenticated, no property |
| `/dashboard` | Shell branch 0 | `DashboardScreen` | Authenticated |
| `/piquetes` | Shell branch 1 | `PiquetesScreen` | Authenticated |
| `/animais` | Shell branch 2 | `AnimaisScreen` | Authenticated |
| `/reproducao` | Shell branch 3 | `ReproducaoScreen` | Authenticated |
| `/sanitario` | Shell branch 4 | `SanitarioScreen` | Authenticated |

### AuthRepository (`lib/features/auth/data/auth_repository.dart`)

Public API:
```dart
Future<AuthResponse> signUp({required String email, required String password})
Future<AuthResponse> signIn({required String email, required String password})
Future<void> signOut()
Future<void> resetPasswordForEmail(String email)  // redirectTo: 'http://127.0.0.1:3000/reset-password'
Future<UserResponse> updatePassword(String newPassword)
```

Provided via `authRepositoryProvider = Provider<AuthRepository>` — widgets never import `supabase_flutter` directly.

### AuthNotifier (`lib/features/auth/providers/auth_provider.dart`)

`AsyncNotifier<AuthState?>` that:
1. Subscribes to `service.auth.onAuthStateChange` in `build()` and updates `state = AsyncData(event)` on each emission
2. Returns the current session wrapped as `AuthState(AuthChangeEvent.initialSession, session)` if a session exists at startup, or `null` if no session
3. Cancels its `StreamSubscription` via `ref.onDispose`

Exposed via `authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState?>`.

### Router Redirect Logic (`lib/core/router/router.dart`)

```
redirect(context, state) {
  1. if authAsync.isLoading → return null  (Pitfall 1: cold-start safety)
  2. if isPasswordRecovery && loc != /reset-password → return /reset-password  (Pitfall 2: recovery priority)
  3. if !isLoggedIn && !onAuthRoute → return /login
  4. if isLoggedIn && (loc == /login || loc == /signup) → return /dashboard
  5. return null  (allow navigation)
}
```

### Auth Screens

**LoginScreen** — `ConstrainedBox(maxWidth: 400)`, 2 `TextFormField` (email + senha), `FilledButton('Entrar', minimumSize: Size(double.infinity, 48))`, links to `/signup` and `/reset-password`. Email regex validator, 6-char password validator. On `AuthException`: generic SnackBar (T-02-06 — no enumeration).

**SignupScreen** — 3 fields (email + senha + confirmar). Confirm validator: `v == _passCtrl.text ? null : 'As senhas não coincidem'`. On `AuthException`: shows `e.message`. Button: `'Criar conta'`.

**ResetPasswordScreen** — Dual-state widget. State determined by `authNotifierProvider.asData?.value?.event == AuthChangeEvent.passwordRecovery`:
- State 1 (default): email field + `'Enviar email de redefinição'`. Success SnackBar. Error shows generic security message (T-02-03).
- State 2 (recovery): nova senha + confirmar + `'Salvar nova senha'`. Calls `updatePassword`.

**NoAccessScreen** — Static. `Icons.lock_outline` at 40% opacity, `'Acesso não configurado'` titleLarge, full explanation bodyMedium, `TextButton('Sair')` calls `signOut()`.

## Test Results

| Test file | Tests | Status |
|-----------|-------|--------|
| `test/features/auth/auth_repository_test.dart` | 5 | GREEN |
| `test/features/auth/login_screen_test.dart` | 2 | GREEN |
| `test/core/router_test.dart` | 2 | GREEN |
| **Total** | **9** | **ALL PASSED** |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `UserResponse(user: null)` — no such constructor in gotrue 2.11.1**
- **Found during:** Task 1 (first test run)
- **Issue:** The Wave 0 RED test stub used `UserResponse(user: null)` but `UserResponse` in gotrue 2.11.1 only has `UserResponse.fromJson(Map)`. No positional/named constructor exists.
- **Fix:** Replaced with `UserResponse.fromJson({'id': '', 'aud': '', 'created_at': '', 'app_metadata': {}})` in `test/features/auth/auth_repository_test.dart`
- **Files modified:** `test/features/auth/auth_repository_test.dart`
- **Commit:** `6d0c587`

**2. [Rule 2 - Missing critical functionality] Missing `registerFallbackValue` for `UserAttributes` in mocktail**
- **Found during:** Task 1 (after fixing Rule 1)
- **Issue:** `any(that: isA<UserAttributes>())` in the `updatePassword` test threw a mocktail runtime error because `UserAttributes` had no registered fallback value. Required for sound null safety with mocktail's `any()` matcher.
- **Fix:** Added `class _FakeUserAttributes extends Fake implements UserAttributes {}` and `setUpAll(() { registerFallbackValue(_FakeUserAttributes()); })` to the test file.
- **Files modified:** `test/features/auth/auth_repository_test.dart`
- **Commit:** `6d0c587`

**3. [Rule 1 - Bug] LoginScreen title "Entrar" duplicated the button text "Entrar" — `findsOneWidget` failed**
- **Found during:** Task 2 (login_screen_test run)
- **Issue:** The plan's action code placed `Text('Entrar')` as both the page title AND the `FilledButton` label. The Wave 0 test `expect(find.text('Entrar'), findsOneWidget)` found 2 matches and failed.
- **Fix:** Changed LoginScreen page title to `'Campo Gestor'` — the app name — which is a more appropriate title than the action verb. Button remains `'Entrar'`.
- **Files modified:** `lib/features/auth/presentation/login_screen.dart`
- **Commit:** `3e45ee7`

## Threat Model Coverage

All STRIDE threats in the plan's threat model are addressed:

| Threat | Mitigation | Status |
|--------|-----------|--------|
| T-02-01 Spoofing (credentials) | Email regex + min 6 chars in all form validators | Implemented |
| T-02-02 Brute force | `sign_in_sign_ups = 30` per 5 min in config.toml (Phase 0) | Pre-existing |
| T-02-03 Reset enumeration | Generic catch message: "Se esse email estiver cadastrado..." | Implemented |
| T-02-04 Open redirect | `resetRedirect` hardcoded constant; allowlist in config.toml | Implemented |
| T-02-05 passwordRecovery race | Router checks `isPasswordRecovery` before `isLoggedIn` | Implemented |
| T-02-06 AuthException leakage | LoginScreen shows generic "Email ou senha inválidos" | Implemented |
| T-02-07 XSS via copy | Flutter Text widget escapes; strings are compile-time constants | Accept |

## Known Stubs

None — all screens are fully wired. Data flows are:
- LoginScreen → `authRepositoryProvider.signIn()` → GoTrue → `authNotifierProvider` emits → router redirects
- NoAccessScreen → `authRepositoryProvider.signOut()` → GoTrue → `authNotifierProvider` emits → router redirects to /login

## Threat Flags

No new security-relevant surface beyond the plan's threat model. The 4 new routes and auth guard are the planned trust boundaries.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | `6d0c587` | feat(01-02): create AuthRepository, authNotifierProvider, add auth route constants |
| Task 2 | `3e45ee7` | feat(01-02): create LoginScreen, SignupScreen, ResetPasswordScreen, NoAccessScreen |
| Task 3 | `a6fb838` | feat(01-02): wire auth guard into router — 4 new routes + redirect logic |

## Self-Check: PASSED

- [x] `lib/features/auth/data/auth_repository.dart` exists — contains `class AuthRepository`, `authRepositoryProvider`, `http://127.0.0.1:3000/reset-password`
- [x] `lib/features/auth/providers/auth_provider.dart` exists — contains `AuthNotifier extends AsyncNotifier`, `authNotifierProvider`, `onAuthStateChange`
- [x] `lib/features/auth/presentation/login_screen.dart` exists — contains `'Entrar'` (button), `'Digite um email válido'`, `'A senha deve ter pelo menos 6 caracteres'`
- [x] `lib/features/auth/presentation/signup_screen.dart` exists — contains `'Criar conta'`, `'As senhas não coincidem'`, `'Já tem conta? Entrar'`
- [x] `lib/features/auth/presentation/reset_password_screen.dart` exists — contains `AuthChangeEvent.passwordRecovery`, `'Redefinir senha'`, `'Nova senha'`, `'Enviar email de redefinição'`, `'Salvar nova senha'`
- [x] `lib/features/auth/presentation/no_access_screen.dart` exists — contains `'Acesso não configurado'`, `'Sua conta foi criada'`, `'Sair'`
- [x] `lib/core/router/routes.dart` contains `login`, `signup`, `resetPassword`, `noAccess`, `authRoutes`, AND `all` (5 shell branches preserved)
- [x] `lib/core/router/router.dart` contains `authNotifierProvider`, `authAsync.isLoading`, `isPasswordRecovery`, `LoginScreen`, `NoAccessScreen`
- [x] Commits `6d0c587`, `3e45ee7`, `a6fb838` verified in git log
- [x] `flutter test test/features/auth/auth_repository_test.dart` — 5/5 PASSED
- [x] `flutter test test/features/auth/login_screen_test.dart` — 2/2 PASSED
- [x] `flutter test test/core/router_test.dart` — 2/2 PASSED
- [x] `flutter analyze lib/features/auth/ lib/core/router/` — No issues found
