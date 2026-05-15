---
phase: "02-property-paddock-structure"
plan: "05"
subsystem: "piquetes-ui"
tags: ["flutter", "ui", "riverpod", "screens", "PROP-02", "wave-2"]
dependency_graph:
  requires:
    - "02-03 (PaddockRepository + paddockListProvider)"
    - "02-04 (PropriedadesScreen + AppRoutes.propriedades)"
  provides:
    - "PiquetesScreen with empty state, paddock list, role-gated FAB"
    - "PaddockFormDialog AlertDialog with pt-BR decimal input (comma separator)"
    - "PaddockDetailScreen minimal detail view at /piquetes/:id"
    - "GoRoute /piquetes/:id registered inside StatefulShellBranch"
  affects:
    - "AppShell piquetes branch now has sub-route /piquetes/:id"
tech_stack:
  added: []
  patterns:
    - "ConsumerWidget + ref.watch(paddockListProvider) for async list"
    - "Role gate via memberPropertiesProvider membership lookup (veterinarian-only)"
    - "pt-BR decimal input: FilteringTextInputFormatter allow [0-9.,] + replaceAll comma→dot before parse"
    - "Display doubles with comma: toStringAsFixed(2).replaceAll('.', ',')"
    - "context.go('/piquetes/${paddock.id}') from ListTile.onTap"
key_files:
  created:
    - "lib/features/piquetes/presentation/piquetes_screen.dart"
    - "lib/features/piquetes/presentation/paddock_form_dialog.dart"
    - "lib/features/piquetes/presentation/paddock_detail_screen.dart"
  modified:
    - "lib/core/router/router.dart"
decisions:
  - "Role gate changed from owner||veterinarian (plan spec) to veterinarian-only during UAT — consistent with Phase 2 design decision that vet=admin, owner=read-only"
  - "context.go (not push) used for /piquetes/:id navigation — replaces shell tab stack cleanly with back via AppBar"
  - "Decimal display uses toStringAsFixed(1) on list cards, toStringAsFixed(2) on detail screen — more precision in context"
metrics:
  duration: "~5 min"
  completed_date: "2026-05-08"
  tasks_completed: 2
  files_created: 3
  files_modified: 1
---

# Phase 02 Plan 05: Piquetes UI Summary

**One-liner:** PiquetesScreen with empty state + role-gated FAB + PaddockFormDialog (pt-BR decimal) + PaddockDetailScreen at /piquetes/:id, replacing the Phase 0 placeholder and turning the RED stub test GREEN.

## Files Created / Modified

| File | Type | Description |
|------|------|-------------|
| `lib/features/piquetes/presentation/piquetes_screen.dart` | Created | Full screen: empty state, paddock list with edit/delete, role-gated FAB, onTap navigation |
| `lib/features/piquetes/presentation/paddock_form_dialog.dart` | Created | `PaddockFormDialog`: Nome (required) + Área ha (decimal) + Capacidade UA (decimal) with pt-BR comma separator |
| `lib/features/piquetes/presentation/paddock_detail_screen.dart` | Created | Minimal detail screen: name, areaHa, uaCapacity with comma formatting |
| `lib/core/router/router.dart` | Modified | Added PaddockDetailScreen import + `path: ':id'` sub-route inside piquetes StatefulShellBranch |

## pt-BR Decimal Handling

- Input: `FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))` — allows both comma and period
- Parse: `v.trim().replaceAll(',', '.')` → `double.tryParse()`
- Display: `v.toStringAsFixed(n).replaceAll('.', ',')`
- Validation: non-empty + parseable + > 0

## Test Results

```
flutter test test/
00:07 +33: All tests passed!
```

- `test/widget/piquetes_screen_test.dart` — GREEN (was RED Phase 0 stub)
- `test/core/router_test.dart` — GREEN (AppRoutes.all still 5 entries, no regression)
- All other 31 tests: passing

## UAT Results

All 10 UAT tests passed (9 pass + 2 issues found and fixed during UAT session):

| Test | Result | Notes |
|------|--------|-------|
| 1. Cold start smoke | pass | |
| 2. PropriedadesScreen empty state | fixed | Router blocked /propriedades when membersList empty |
| 3. PropertySelector "Gerenciar fazendas" | pass | |
| 4. Create fazenda (vet) | pass | |
| 5. Role-gated FAB — fazendas | pass | |
| 6. Edit + soft-delete fazenda | pass | |
| 7. PiquetesScreen empty state | pass | |
| 8. Create piquete pt-BR decimal | pass | Comma and period both accepted |
| 9. Tap piquete → detail screen | pass | |
| 10. Role-gated FAB — piquetes | pass | |

## Deviations from Plan

### Role Gate Change (UAT Fix)

**Plan spec:** `role == 'owner' || role == 'veterinarian'`
**Implemented:** `role == 'veterinarian'` only
**Reason:** Phase 2 design decision (memory: `project_phase2_decisions.md`) — vet=admin, proprietário=read-only. Owner role has read-only access consistent with PropriedadesScreen.

### UAT Bug Fixes Applied

1. **Router empty-membership redirect** — exempted `/propriedades` from redirect to `/sem-acesso` when `membersList.isEmpty`
2. **NoAccess signOut** — added `await clear()` before `signOut()` (WR-02 pattern); removed `noAccess` from `authRoutes`
3. **NoAccess missing CTA** — added "Criar minha fazenda" `FilledButton` → `context.push(AppRoutes.propriedades)`
4. **FAB hidden on empty memberships** — added `if (members.isEmpty) return true` guard in `_canEditProperties`
5. **First-property navigation** — added `isFirstProperty` flag + auto-navigate to `/dashboard` after first fazenda created

## Known Stubs

None. All three screens are fully wired to their respective repositories and providers.

## Threat Flags

None. RLS enforces role on all mutations. `/piquetes/:id` returns null for non-members (shows "Piquete não encontrado.").

## Self-Check: PASSED

- [x] `lib/features/piquetes/presentation/piquetes_screen.dart` contains 'Nenhum piquete cadastrado' and 'Adicione piquetes para começar a organizar os lotes da fazenda.'
- [x] `lib/features/piquetes/presentation/paddock_form_dialog.dart` exists with `PaddockFormDialog`
- [x] `lib/features/piquetes/presentation/paddock_detail_screen.dart` exists with `PaddockDetailScreen`
- [x] `lib/core/router/router.dart` contains `path: ':id'` sub-route inside piquetes branch
- [x] `flutter test test/widget/piquetes_screen_test.dart` — GREEN
- [x] `flutter test test/core/router_test.dart` — GREEN (no regression)
- [x] `flutter test test/` — 33/33 passing
- [x] UAT: all 10 tests passed; decimal input confirmed by user
