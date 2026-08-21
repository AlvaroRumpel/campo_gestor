---
phase: 1
slug: auth-multi-tenancy-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-04
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `mocktail ^1.0.5` |
| **Config file** | nenhum arquivo separado — `flutter test` nativo |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test test/ && flutter test integration_test/rls_isolation_test.dart` |
| **Estimated runtime** | ~30s (unit) + ~60s (integration, requer `supabase start`) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test test/ && flutter test integration_test/rls_isolation_test.dart`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds (unit) / 90 seconds (integration)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | AUTH-01 | — | N/A | unit stub | `flutter test test/features/auth/auth_repository_test.dart` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 0 | AUTH-01 | — | N/A | widget stub | `flutter test test/features/auth/login_screen_test.dart` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 0 | AUTH-03 | — | N/A | unit stub | `flutter test test/features/auth/property_repository_test.dart` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01 | 0 | AUTH-04 | — | N/A | unit stub | `flutter test test/core/current_property_provider_test.dart` | ✅ parcial | ⬜ pending |
| 1-01-05 | 01 | 0 | AUTH-05 | T-1-01 | Usuário A não lê dados de propriedade B | integration stub | `flutter test integration_test/rls_isolation_test.dart` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | AUTH-01 | T-1-02 | Força bruta bloqueado (rate limit config.toml) | unit | `flutter test test/features/auth/auth_repository_test.dart` | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | AUTH-02 | T-1-03 | Perfil não lido de JWT (sempre consulta property_members) | unit | `flutter test test/features/auth/property_repository_test.dart` | ❌ W0 | ⬜ pending |
| 1-03-01 | 03 | 2 | AUTH-04 | — | N/A | unit | `flutter test test/core/current_property_provider_test.dart` | ✅ parcial | ⬜ pending |
| 1-04-01 | 04 | 3 | AUTH-05 | T-1-01 | RLS bloqueia cross-tenant read/write | integration | `flutter test integration_test/rls_isolation_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/auth/auth_repository_test.dart` — stubs para AUTH-01 (signUp, signIn, signOut, resetPassword com mocktail)
- [ ] `test/features/auth/property_repository_test.dart` — stubs para AUTH-03 e AUTH-04 (fetchMemberProperties)
- [ ] `test/features/auth/login_screen_test.dart` — stub para AUTH-01 (validação de form na UI)
- [ ] `integration_test/rls_isolation_test.dart` — stub para AUTH-05 (teste negativo de RLS)
- [ ] Atualizar `test/core/current_property_provider_test.dart` — adicionar casos: 0 props → null, 1 prop → auto-seleciona, N props → usa saved_id

*Infraestrutura `flutter_test` + `mocktail` já instalada na Phase 0. Nenhum framework novo a instalar.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Reset de senha via email (link no Inbucket) | AUTH-01 | Requer interação com browser e Inbucket UI (http://localhost:54324) | 1. Solicitar reset via UI. 2. Abrir Inbucket. 3. Clicar link. 4. Verificar redirect para `/reset-password`. 5. Submeter nova senha. 6. Verificar redirect para dashboard. |
| `additional_redirect_urls` aceita `http://` e `https://` | AUTH-01 | Validação de config.toml aplicada no Supabase local | Verificar manualmente `supabase/config.toml` tem ambas as variantes antes de testar reset |
| Schema `property_members` tem coluna `perfil` com enum correto | AUTH-02 | Migration SQL não é testável via flutter_test | Após `supabase db push`, executar `psql` ou Supabase Studio e verificar `\d property_members` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (unit) / 90s (integration)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
