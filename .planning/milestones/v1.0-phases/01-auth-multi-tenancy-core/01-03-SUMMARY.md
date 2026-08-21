---
plan: 01-03
phase: 01-auth-multi-tenancy-core
status: complete
wave: 3
started: 2026-05-05
completed: 2026-05-05
requirements: [AUTH-02, AUTH-03, AUTH-04]
key-files:
  created:
    - lib/features/auth/data/property_repository.dart
  modified:
    - lib/core/providers/current_property_provider.dart
    - lib/core/widgets/property_selector.dart
    - lib/core/widgets/app_shell.dart
    - lib/core/router/router.dart
    - test/core/current_property_provider_test.dart
---

## What Was Built

Multi-tenancy UI layer wired to real Supabase data. Replaced the Phase 0 `currentPropertyProvider` placeholder with a full implementation querying `property_members`, added `PropertySelector` dropdown, logout button in AppShell, and router membership gate.

## API Surface

### PropertyRepository (`lib/features/auth/data/property_repository.dart`)
```dart
class PropertyMembership {
  final Property property;
  final String perfil; // 'proprietario' | 'veterinario' | 'leitor'
}
class PropertyRepository {
  Future<List<PropertyMembership>> fetchMemberProperties();
}
final propertyRepositoryProvider = Provider<PropertyRepository>(...);
```
Query: `property_members.select('perfil, propriedades(id, nome)')` — RLS implicit filter on `user_id = auth.uid()`.

### memberPropertiesProvider
`FutureProvider<List<PropertyMembership>>` that re-runs when `authNotifierProvider` changes. Returns `[]` when session is null.

### currentPropertyProvider (real implementation)
- 0 properties → `null` (router sends to `/sem-acesso`)
- 1 property → auto-select (D-05)
- 2+ properties → reads `active_property_id` from SharedPreferences; falls back to `first` if stale (Pitfall 4)

### selectProperty / clear
- `selectProperty(p)`: writes `active_property_id` to SharedPreferences + updates state
- `clear()`: removes `active_property_id` + sets state to null (called on logout)

## 3-Stage Router Redirect

```
Stage 1 (auth gate):   isLoading → null | not logged in → /login
Stage 2 (recovery):    passwordRecovery event → /reset-password
Stage 3 (membership):  logged in, membersList.isEmpty → /sem-acesso
                        logged in w/ members on /login|/signup → /dashboard
                        logged in w/ members on /sem-acesso → /dashboard
```

`members.isLoading` short-circuit returns `null` — router re-evaluates via `GoRouterRefreshStream` when auth stream fires.

## SharedPreferences Pattern

Key: `active_property_id` (constant `_kActivePropertyIdKey`)
- Written on `selectProperty`
- Removed on `clear()` (logout path)
- Read on `currentPropertyProvider.build()` when 2+ properties exist

## Test Results

| Suite | Tests | Status |
|-------|-------|--------|
| current_property_provider_test.dart | 6 | GREEN |
| property_repository_test.dart | 2 | GREEN |
| auth_repository_test.dart | 5 | GREEN |
| login_screen_test.dart | 4 | GREEN |
| router_test.dart | 2 | GREEN |
| app_shell_test.dart | 4 | GREEN |
| theme_test.dart | 1 | GREEN |
| **Total** | **24** | **ALL GREEN** |

`flutter analyze lib/` → No issues found.

## Deviations

None. All tasks executed per plan spec.

## Self-Check: PASSED

- AUTH-02: perfil enum materialized in `PropertyMembership.perfil`, displayed as pt-BR labels in `PropertySelector` dropdown
- AUTH-03: `PropertyRepository.fetchMemberProperties()` returns N memberships for N-property users
- AUTH-04: `PopupMenuButton` switches active property; selection persisted via SharedPreferences
- D-03: 0-membership users redirected to `/sem-acesso`
- D-05: 1-membership users see plain `Text` — no dropdown
- D-06: `active_property_id` persists across reloads via SharedPreferences
- All Wave 0 stubs from Plan 01 GREEN
- No new analyzer warnings
