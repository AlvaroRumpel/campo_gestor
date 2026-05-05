---
phase: 01-auth-multi-tenancy-core
verified: 2026-05-05T00:00:00Z
status: human_needed
score: 4/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Sign up with a new email, log in, reload the browser tab"
    expected: "Session persists — user lands on /dashboard without re-entering credentials"
    why_human: "Session persistence is handled by supabase_flutter defaults (SharedPreferences/localStorage); cannot verify without a running Supabase + browser"
  - test: "Sign up → app redirects to /dashboard (or /sem-acesso if no membership)"
    expected: "Login is immediate with no email confirmation step (D-01: enable_confirmations=false)"
    why_human: "ROADMAP SC-1 says 'receber email de confirmação e fazer login' but D-01 explicitly disables email confirmation. Human must confirm this architectural deviation is intentional and SC-1 wording is loose."
  - test: "Run integration_test/rls_isolation_test.dart against local Supabase (supabase db reset + supabase start)"
    expected: "Both RLS isolation tests PASS — userA cannot read userB's property_members or propriedades rows"
    why_human: "Integration test requires supabase start running locally with seed applied; skipped in plain flutter test"
  - test: "Sign in as userA@test.com / senha123A, check AppBar title, click logout"
    expected: "AppBar shows 'Fazenda Alpha' as plain Text (1 property, D-05); logout returns to /login"
    why_human: "Requires running app against live Supabase with seeded data; visual verification needed"
---

# Phase 1: Auth & Multi-tenancy Core — Verification Report

**Phase Goal:** Usuário se cadastra, faz login, vê apenas dados das propriedades às quais pertence, e troca a propriedade ativa quando tem acesso a múltiplas.
**Verified:** 2026-05-05
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Usuário pode se cadastrar com email/senha e fazer login; sessão persiste entre reloads | ? UNCERTAIN | `AuthRepository.signUp/signIn` wired to GoTrue; `AuthNotifier.build()` reads `currentSession` on startup; `supabase_flutter` persists session by default. SC-1 mentions "email de confirmação" but `enable_confirmations = false` per D-01. Functional login exists but end-to-end requires human. |
| SC-2 | Usuário com 0 propriedades → /sem-acesso; 1 propriedade → direto; N → seletor com troca | ✓ VERIFIED | Router has 3-stage redirect; `memberPropertiesProvider` returns [] → noAccess; `currentPropertyProvider` auto-selects with 1, `PropertySelector` shows `PopupMenuButton` with 2+; 6 unit tests GREEN. |
| SC-3 | `property_members` define perfil (proprietário/veterinário/leitor); UI consulta o perfil ativo | ✓ VERIFIED | `property_members` table exists with `perfil perfil_enum`; `PropertyMembership.perfil` exposed; `PropertySelector._perfilLabel()` maps to pt-BR labels; dropdown shows perfil below property name. |
| SC-4 | Teste negativo automatizado: userA NÃO consegue ler dados da propriedade de userB (RLS + FORCE RLS) | ? UNCERTAIN | `integration_test/rls_isolation_test.dart` exists with correct test logic and seed data. Skipped via `SKIP_INTEGRATION` env flag — requires `supabase start` running. Schema DDL has FORCE RLS + correct policies. Needs human to execute. |
| SC-5 | Logout limpa sessão e redireciona para tela de login | ✓ VERIFIED | `AppShell` logout button calls `authRepositoryProvider.signOut()` + `currentPropertyProvider.notifier.clear()`; `GoRouterRefreshStream` triggers redirect; router sends unauthenticated to /login. Wiring confirmed in code. |

**Score:** 3/5 programmatically verified + 2 uncertain (human needed)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/20260504_01_auth_multitenancy.sql` | Schema with propriedades + property_members + is_member_of + RLS | ✓ VERIFIED | FORCE RLS on both tables; is_member_of SECURITY DEFINER STABLE with SET search_path; REVOKE/GRANT correct; both RLS policies present |
| `supabase/seed.sql` | 2 users + 2 properties + 2 disjoint memberships | ✓ VERIFIED | Deterministic UUIDs; bcrypt hashed passwords; auth.identities rows; ON CONFLICT DO NOTHING |
| `supabase/config.toml` | additional_redirect_urls includes http://127.0.0.1:3000 | ✓ VERIFIED | Line 156: `["https://127.0.0.1:3000", "http://127.0.0.1:3000", "http://localhost:3000"]` |
| `lib/features/auth/data/auth_repository.dart` | AuthRepository + authRepositoryProvider | ✓ VERIFIED | All 5 methods; resetRedirect constant; Provider wired to supabaseServiceProvider |
| `lib/features/auth/providers/auth_provider.dart` | AuthNotifier + authNotifierProvider | ✓ VERIFIED | AsyncNotifier<AuthState?>; onAuthStateChange.listen; currentSession on build(); ref.onDispose cancel |
| `lib/features/auth/presentation/login_screen.dart` | LoginScreen with 2 fields, Entrar, validation | ✓ VERIFIED | 2 TextFormField; FilledButton('Entrar'); validation messages exact; authRepositoryProvider.signIn called |
| `lib/features/auth/presentation/signup_screen.dart` | SignupScreen with 3 fields, Criar conta | ✓ VERIFIED | 3 fields; password confirm validator; 'Criar conta' button |
| `lib/features/auth/presentation/reset_password_screen.dart` | ResetPasswordScreen — 2 states | ✓ VERIFIED | AuthChangeEvent.passwordRecovery gate; 'Redefinir senha' / 'Nova senha' states |
| `lib/features/auth/presentation/no_access_screen.dart` | NoAccessScreen static with Sair | ✓ VERIFIED | 'Acesso não configurado'; full explanation text; TextButton('Sair') calls signOut() |
| `lib/features/auth/data/property_repository.dart` | PropertyRepository + PropertyMembership + provider | ✓ VERIFIED | PostgREST embedded select `property_members.select('perfil, propriedades(id, nome)')`; RLS-implicit filter; real DB query not static |
| `lib/core/providers/current_property_provider.dart` | Real impl replacing Phase 0 placeholder | ✓ VERIFIED | memberPropertiesProvider; 0/1/N branches; SharedPreferences active_property_id; selectProperty/clear |
| `lib/core/router/router.dart` | Auth guard + membership gate + 4 new routes | ✓ VERIFIED | 3-stage redirect (loading → recovery → auth → membership); authNotifierProvider + memberPropertiesProvider both checked; all 4 auth routes registered |
| `lib/core/router/routes.dart` | Auth route constants + authRoutes list | ✓ VERIFIED | login, signup, resetPassword, noAccess + authRoutes list; all = 5 shell routes preserved |
| `lib/core/widgets/property_selector.dart` | PopupMenuButton 2+ props; Text 1 prop | ✓ VERIFIED | list.length <= 1 → plain Text; 2+ → PopupMenuButton<PropertyMembership>; _perfilLabel pt-BR labels |
| `lib/core/widgets/app_shell.dart` | Logout button calling signOut + clear | ✓ VERIFIED | IconButton logout in AppBar actions; calls both authRepositoryProvider.signOut() and currentPropertyProvider.notifier.clear() |
| `test/features/auth/auth_repository_test.dart` | 5 mocktail tests GREEN | ✓ VERIFIED | All 5 pass (signUp, signIn, signOut, resetPasswordForEmail, updatePassword) |
| `test/features/auth/property_repository_test.dart` | 2 compile/API surface tests GREEN | ✓ VERIFIED | Both pass |
| `test/features/auth/login_screen_test.dart` | 2 widget tests GREEN | ✓ VERIFIED | Both pass (fields render; validation error appears) |
| `test/core/current_property_provider_test.dart` | 6 tests covering 0/1/N + persist + clear | ✓ VERIFIED | All 6 pass |
| `integration_test/rls_isolation_test.dart` | Negative RLS test; gated by SKIP_INTEGRATION | ✓ VERIFIED (structure) | File exists with correct test logic; `skip: const bool.fromEnvironment('SKIP_INTEGRATION', defaultValue: false)` — needs human to execute against real Supabase |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| RLS policies on propriedades | is_member_of() | USING (is_member_of(id)) | ✓ WIRED | Confirmed in migration line 70 |
| is_member_of() | auth.uid() | WHERE user_id = auth.uid() | ✓ WIRED | Confirmed in migration lines 52-54 |
| LoginScreen onSubmit | authRepositoryProvider.signIn | ref.read(authRepositoryProvider) | ✓ WIRED | login_screen.dart line 46 |
| Router redirect | authNotifierProvider | ref.read(authNotifierProvider) | ✓ WIRED | router.dart line 46 |
| Router redirect | memberPropertiesProvider | ref.read(memberPropertiesProvider) | ✓ WIRED | router.dart line 71 |
| currentPropertyProvider.build() | property_members via PropertyRepository | ref.watch(memberPropertiesProvider.future) | ✓ WIRED | current_property_provider.dart line 43 |
| memberPropertiesProvider | authNotifierProvider | ref.watch(authNotifierProvider) | ✓ WIRED | Invalidates on auth state change |
| AppShell logout | AuthRepository.signOut | ref.read(authRepositoryProvider).signOut() | ✓ WIRED | app_shell.dart line 65 |
| AppShell logout | currentPropertyProvider.clear() | ref.read(currentPropertyProvider.notifier).clear() | ✓ WIRED | app_shell.dart line 66 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `PropertySelector` | `memberPropertiesProvider` | `PropertyRepository.fetchMemberProperties()` | Yes — PostgREST query to `property_members` JOIN `propriedades` | ✓ FLOWING |
| `CurrentPropertyNotifier.build()` | `memberPropertiesProvider.future` | Same as above | Yes | ✓ FLOWING |
| `AuthNotifier.build()` | `service.auth.currentSession` | `supabase_flutter` GoTrueClient | Yes — reads from persisted session | ✓ FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| auth_repository_test (5 tests) | `flutter test test/features/auth/auth_repository_test.dart` | All 5 PASSED | ✓ PASS |
| property_repository_test (2 tests) | `flutter test test/features/auth/property_repository_test.dart` | All 2 PASSED | ✓ PASS |
| login_screen_test (2 tests) | `flutter test test/features/auth/login_screen_test.dart` | All 2 PASSED | ✓ PASS |
| current_property_provider_test (6 tests) | `flutter test test/core/current_property_provider_test.dart` | All 6 PASSED | ✓ PASS |
| router_test (2 tests) | `flutter test test/core/router_test.dart` | All 2 PASSED | ✓ PASS |
| flutter analyze auth + router + widgets | `flutter analyze lib/features/auth/ lib/core/router/ lib/core/widgets/ lib/core/providers/` | No issues found | ✓ PASS |
| RLS isolation test | Requires `supabase start` + seed | Not runnable without Supabase | ? SKIP |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUTH-01 | 01-02 | Usuário pode se cadastrar e fazer login com email e senha | ✓ SATISFIED | LoginScreen + SignupScreen + AuthRepository.signIn/signUp wired to GoTrue; router guard in place |
| AUTH-02 | 01-01, 01-03 | Sistema suporta 3 perfis por propriedade: proprietário, veterinário, leitor | ✓ SATISFIED | perfil_enum in migration; PropertyMembership.perfil; PropertySelector displays pt-BR labels |
| AUTH-03 | 01-01, 01-03 | Veterinário pode ser vinculado a múltiplas propriedades | ✓ SATISFIED | property_members has (user_id, property_id) PK; PropertyRepository.fetchMemberProperties() returns all memberships; currentPropertyProvider handles N>1 |
| AUTH-04 | 01-03 | Usuário com múltiplas propriedades pode selecionar a propriedade ativa | ✓ SATISFIED | PropertySelector shows PopupMenuButton with 2+ props; selectProperty writes to SharedPreferences; 6 tests GREEN |
| AUTH-05 | 01-01 | Isolamento de dados por propriedade via RLS | ? NEEDS HUMAN | Schema DDL has FORCE RLS + correct policies; RLS isolation test exists and compiles but requires running Supabase to execute |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/core/providers/current_property_provider.dart` | 9 | Comment says "Phase 0 placeholder" — outdated comment on an implemented class | ℹ️ Info | None — cosmetic only; class is fully implemented |
| `lib/features/auth/presentation/login_screen.dart` | 87 | Page title is 'Campo Gestor' (not 'Entrar') — intentional deviation from plan to fix findsOneWidget conflict | ℹ️ Info | Not a stub; documented in 01-02-SUMMARY.md decisions section; test passes |

No blocking anti-patterns found. No `return null`/`return []` used as data stubs. No hardcoded empty props flowing to user-visible output.

---

### Human Verification Required

#### 1. Session Persistence Across Reloads (SC-1)

**Test:** Sign up with a new email, log in, hard-reload the browser tab (Ctrl+F5)
**Expected:** User lands on /dashboard without re-entering credentials
**Why human:** `supabase_flutter` handles session persistence via localStorage on web. Cannot verify without a running browser + Supabase.

#### 2. Email Confirmation Policy (SC-1 wording vs D-01)

**Test:** Sign up with a new email
**Expected:** Login is immediate — no "check your email" step; user lands on /dashboard (or /sem-acesso)
**Why human:** ROADMAP SC-1 says "receber email de confirmação e fazer login" but architectural decision D-01 explicitly disables email confirmation (`enable_confirmations = false`). Human must confirm the SC-1 wording is intentionally loose (login after signup without confirmation is the intended behavior per D-01).

#### 3. RLS Isolation Test (AUTH-05, SC-4)

**Test:** Run `flutter test integration_test/rls_isolation_test.dart -d windows` after `supabase start && supabase db reset`
**Expected:** Both tests PASS — userA gets empty result when querying userB's property_members and propriedades
**Why human:** Integration test requires local Supabase stack running with seed applied. Cannot run without external service.

#### 4. End-to-End Login + Property Display + Logout

**Test:** `flutter run -d edge --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<local-anon-key>`. Sign in as userA@test.com / senha123A. Observe AppBar. Click logout icon.
**Expected:** AppBar shows "Fazenda Alpha" as plain Text (1 property — D-05); logout redirects to /login
**Why human:** Requires running app against seeded Supabase; visual verification of PropertySelector behavior in real routing context.

---

### Gaps Summary

No programmatic gaps found. All artifacts exist, are substantive, are wired, and data flows through real DB queries. The 4 human verification items are the only outstanding items — they require a running Supabase instance or browser environment.

**Note on SC-1 / D-01 tension:** The ROADMAP SC-1 wording includes "receber email de confirmação" which contradicts the explicit architectural decision D-01 (`enable_confirmations = false`). This is not a bug — it is a documentation inconsistency. The system correctly implements login-without-confirmation per D-01. Human should confirm the intent and optionally update ROADMAP SC-1 wording to "fazer login imediatamente após cadastro".

---

_Verified: 2026-05-05_
_Verifier: Claude (gsd-verifier)_
