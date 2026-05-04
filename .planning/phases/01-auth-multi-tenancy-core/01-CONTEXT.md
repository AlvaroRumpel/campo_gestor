# Phase 1: Auth & Multi-tenancy Core - Context

**Gathered:** 2026-05-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Implementar autenticação email/senha, tabela `property_members` com perfis, isolamento RLS completo, seleção e persistência de propriedade ativa. O usuário consegue se cadastrar, logar, ver só suas propriedades e trocar a propriedade ativa.

Criação de propriedade via UI é Phase 2. Phase 1 usa seed/admin para vincular propriedades a usuários de teste.

</domain>

<decisions>
## Implementation Decisions

### Signup & Login
- **D-01:** Sem confirmação de email — login imediato após signup. `enable_confirmations = false` (já configurado em `supabase/config.toml`). Nenhuma tela de "verifique seu email".
- **D-02:** Recuperação de senha inclusa nessa fase. Supabase envia email de reset; Flutter trata o deep-link de retorno e exibe formulário de nova senha. Necessário para produção.

### Fluxo sem acesso
- **D-03:** Usuário autenticado com 0 propriedades vinculadas vê tela estática de "sem acesso" com mensagem explicando que precisa ser vinculado por um proprietário. Sem ação do usuário nessa tela.
- **D-04:** Vínculo initial (proprietário ↔ propriedade) criado via seed/SQL/Supabase Studio durante Phase 1. Nenhuma UI de criação de propriedade nessa fase — isso é Phase 2.

### Seleção de propriedade ativa
- **D-05:** Com 1 propriedade: auto-seleciona e entra direto no app, sem mostrar seletor. Seletor só aparece com 2+ propriedades.
- **D-06:** Propriedade ativa persiste entre reloads via SharedPreferences (salva o ID). Ao recarregar, app carrega a propriedade salva diretamente — não passa pelo seletor.

### Perfil e autorização
- **D-07:** Phase 1 não bloqueia ações na UI por perfil. Apenas estrutura os dados: `property_members` tem coluna `perfil` (proprietário/veterinário/leitor) e a UI exibe o perfil ativo no AppShell. Bloqueios por perfil nas telas entram nas fases que criam essas telas (Phase 2+).
- **D-08:** RLS enforced com `FORCE ROW LEVEL SECURITY` em todas as tabelas de domínio. Teste negativo automatizado (SC-4 do ROADMAP): usuário A não consegue ler/escrever dados da propriedade B.

### Claude's Discretion
- Design visual das telas de login/signup/reset — Material 3, pt-BR, consistente com AppShell existente.
- Estrutura do `authProvider` Riverpod — `AsyncNotifier` ou `StreamNotifier` sobre `onAuthStateChange`.
- Estratégia de redirect no GoRouter — onde colocar a lógica de guard no `redirect` existente.
- Conteúdo exato da tela "sem acesso" — mensagem, ícone, contato.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §AUTH-01…AUTH-05 — 5 requisitos desta fase
- `.planning/ROADMAP.md` §Phase 1 — success criteria SC-1…SC-5

### Codebase de base (Phase 0)
- `lib/core/router/router.dart` — `routerProvider` com `GoRouterRefreshStream` e `redirect` placeholder; Phase 1 implementa auth guard aqui
- `lib/core/providers/current_property_provider.dart` — `AsyncNotifier<Property?>` com `selectProperty()` e `clear()` placeholder; Phase 1 preenche com dados reais de `property_members`
- `lib/core/services/supabase_service.dart` — `SupabaseService.auth` é o ponto de acesso ao GoTrue
- `lib/core/providers/supabase_providers.dart` — `supabaseServiceProvider` singleton

### Stack
- `supabase/config.toml` — `enable_confirmations = false`, `enable_signup = true`, `site_url`, `additional_redirect_urls` (para deep-link do reset de senha)
- `.planning/research/SUMMARY.md` — decisões de stack e pitfalls documentados na Phase 0

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SupabaseService.auth` (GoTrueClient): `signUp()`, `signInWithPassword()`, `signOut()`, `resetPasswordForEmail()`, `onAuthStateChange` — tudo disponível via `supabaseServiceProvider`
- `currentPropertyProvider` (`AsyncNotifier<Property?>`): selectProperty/clear já implementados — Phase 1 substitui o build() placeholder por query real em `property_members`
- `GoRouterRefreshStream`: já wired ao `onAuthStateChange` — router vai re-avaliar redirect automaticamente em login/logout
- `shared_preferences: ^2.3.0` já declarado no pubspec (Phase 0)

### Established Patterns
- Features não importam Supabase SDK diretamente — repository/service pattern já estabelecido
- Estado assíncrono via `AsyncNotifier` / `AsyncValue` (Riverpod 3.x)
- GoRouter com `StatefulShellRoute.indexedStack` para shell de navegação

### Integration Points
- `router.dart` `redirect`: adicionar auth guard (redireciona `/login` se não autenticado)
- `app_shell.dart`: exibir perfil ativo do usuário e property selector
- Nova rota `/login`, `/signup`, `/reset-password`, `/sem-acesso` (sem acesso + sem propriedade)
- `currentPropertyProvider.build()`: substituir `return null` por query a `property_members` + leitura de SharedPreferences

</code_context>

<specifics>
## Specific Ideas

- Supabase local usa `inbucket` (porta 54324) para capturar emails de reset — testável em dev sem SMTP real.
- Deep-link de reset de senha precisa de `additional_redirect_urls` configurado no config.toml para o ambiente de dev (`http://127.0.0.1:3000`).

</specifics>

<deferred>
## Deferred Ideas

- Bloqueio de ações por perfil na UI — Phase 2+ (quando existirem as telas com ações reais)
- Criação de propriedade no fluxo de signup — Phase 2 (PROP-01)
- MFA / passkey — fora do MVP
- SSO / OAuth providers — fora do MVP

</deferred>

---

*Phase: 01-auth-multi-tenancy-core*
*Context gathered: 2026-05-03*
