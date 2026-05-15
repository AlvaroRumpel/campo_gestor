---
status: complete
phase: 02-property-paddock-structure
source: [02-04-SUMMARY.md, 02-05-PLAN.md]
started: 2026-05-08T16:30:00Z
updated: 2026-05-08T17:30:00Z
---

## Current Test

all tests complete

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running server/service. Clear ephemeral state. Start the application from scratch. Server boots without errors, migrations complete, and a primary query returns live data.
result: pass
notes: supabase db reset ran clean (3 migrations applied); flutter run -d edge booted without errors; app loaded and showed property list — cold start verified.

### 2. PropriedadesScreen empty state
expected: Navigate to /propriedades with no fazendas. Screen shows "Nenhuma fazenda cadastrada" and "Crie sua primeira fazenda para começar a organizar o rebanho."
result: issue
reported: "ao apagar as fazendas aconteceu isso, foi para a rota de sem-acesso"
severity: major

### 3. PropertySelector "Gerenciar fazendas" link
expected: Tap the selector at the top of the shell. "Gerenciar fazendas" option appears (single-property: as inline link below name; multi-property: as a menu item). Tapping it navigates to /propriedades.
result: pass
notes: Confirmed ok by user.

### 4. Create fazenda (vet role)
expected: On /propriedades, tap FAB (+). Dialog "Nova fazenda" appears with Nome (required) and Proprietário (optional) fields. Fill and tap Criar — fazenda appears in list.
result: pass
notes: Confirmed ok by user after fix-03 (atomic RPC replaces two-step INSERT).

### 5. Role-gated FAB — fazendas
expected: Logged in as a user with role != veterinarian — FAB is NOT visible on /propriedades and no edit/delete controls appear on cards. Vet sees FAB and card menu.
result: pass
notes: Confirmed ok by user after fix-01 (_canEdit veterinarian-only).

### 6. Edit + soft-delete fazenda
expected: Vet taps ⋮ menu on a fazenda card → "Editar" opens form pre-filled; "Remover" shows confirmation dialog; confirming removes fazenda from list.
result: pass
notes: Confirmed ok by user.

### 7. PiquetesScreen empty state
expected: Navigate to /piquetes with no paddocks seeded. Screen shows "Nenhum piquete cadastrado" and "Adicione piquetes para começar a organizar os lotes da fazenda."
result: pass
notes: Confirmed ok by user.

### 8. Create piquete — pt-BR decimal input
expected: Tap FAB on /piquetes. PaddockFormDialog opens with Nome, Área (ha), and Capacidade (UA) fields. Typing "8,5" in Área accepts comma as decimal separator and saves correctly. Typing "8.5" also works. Submitting empty fields shows validation errors.
result: pass
notes: Confirmed ok by user.

### 9. Tap piquete → detail screen
expected: Tap a piquete card on /piquetes. Browser navigates to /piquetes/:id. Detail screen shows the piquete's name, área, and capacidade. Back button returns to list.
result: pass
notes: Confirmed ok by user after fix-02 (onTap + GoRouter navigation).

### 10. Role-gated FAB — piquetes
expected: User with owner/reader role on /piquetes sees NO FAB and no edit/delete menu on cards. Vet sees FAB and card menu.
result: pass
notes: Confirmed ok by user.

## Summary

total: 10
passed: 9
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Navigating to /propriedades with no fazendas shows empty state 'Nenhuma fazenda cadastrada'"
  status: failed
  reason: "User reported: ao apagar as fazendas aconteceu isso, foi para a rota de sem-acesso"
  severity: major
  test: 2
  root_cause: "Router redirect (line 79) sends any user with empty membersList to /sem-acesso unconditionally, blocking access to /propriedades empty state. Fix: exempt /propriedades from redirect."
  artifacts:
    - path: "lib/core/router/router.dart"
      issue: "empty-membership redirect blocks /propriedades"
    - path: "lib/features/auth/presentation/no_access_screen.dart"
      issue: "no Criar minha fazenda CTA; signOut missing clear() call"
  missing:
    - "Allow /propriedades when membersList.isEmpty"
    - "Add Criar minha fazenda FilledButton to NoAccessScreen"
    - "Fix signOut: await clear() before signOut() (matches AppShell pattern)"

- truth: "Tapping Sair on /sem-acesso signs the user out and redirects to /login"
  status: failed
  reason: "User reported: ao clicar o botao sair nao acontece nada"
  severity: major
  test: 2
  root_cause: "NoAccessScreen signOut omits currentPropertyProvider.clear() before signOut (WR-02 pattern). Stale SharedPreferences prevents auth stream from triggering router redirect."
  artifacts:
    - path: "lib/features/auth/presentation/no_access_screen.dart"
      issue: "signOut missing clear() + not awaited"
  missing:
    - "await ref.read(currentPropertyProvider.notifier).clear() before signOut"
