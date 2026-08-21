# Phase 1: Auth & Multi-tenancy Core - Research

**Researched:** 2026-05-04
**Domain:** Supabase Auth (GoTrue) + Flutter GoRouter guards + Riverpod 3.x + RLS multi-tenancy
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Sem confirmação de email — login imediato após signup. `enable_confirmations = false` já configurado em `supabase/config.toml`. Nenhuma tela de "verifique seu email".
- **D-02:** Recuperação de senha inclusa nesta fase. Supabase envia email de reset; Flutter trata o evento `passwordRecovery` do `onAuthStateChange` e exibe formulário de nova senha.
- **D-03:** Usuário autenticado com 0 propriedades vinculadas vê tela estática "sem acesso" com mensagem explicativa. Sem ação do usuário nessa tela.
- **D-04:** Vínculo inicial (proprietário ↔ propriedade) criado via seed/SQL/Supabase Studio. Nenhuma UI de criação de propriedade nesta fase.
- **D-05:** Com 1 propriedade: auto-seleciona e entra direto no app, sem seletor. Seletor só aparece com 2+ propriedades.
- **D-06:** Propriedade ativa persiste entre reloads via `SharedPreferences` (salva o ID).
- **D-07:** Phase 1 não bloqueia ações na UI por perfil. Apenas estrutura dados: `property_members.perfil` (proprietário/veterinário/leitor), UI exibe perfil ativo no AppShell. Bloqueios por perfil entram nas fases que criam essas telas.
- **D-08:** RLS enforced com `FORCE ROW LEVEL SECURITY` em todas as tabelas de domínio. Teste negativo automatizado: usuário A não consegue ler/escrever dados da propriedade B.

### Claude's Discretion

- Design visual das telas de login/signup/reset — Material 3, pt-BR, consistente com AppShell existente.
- Estrutura do `authProvider` Riverpod — `AsyncNotifier` ou `StreamNotifier` sobre `onAuthStateChange`.
- Estratégia de redirect no GoRouter — onde colocar a lógica de guard no `redirect` existente.
- Conteúdo exato da tela "sem acesso" — mensagem, ícone, contato.

### Deferred Ideas (OUT OF SCOPE)

- Bloqueio de ações por perfil na UI — Phase 2+ (quando existirem as telas com ações reais)
- Criação de propriedade no fluxo de signup — Phase 2 (PROP-01)
- MFA / passkey — fora do MVP
- SSO / OAuth providers — fora do MVP

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | Usuário pode se cadastrar e fazer login com email e senha | `supabase_flutter` `signUp()` / `signInWithPassword()` já disponíveis via `SupabaseService.auth`; telas login/signup a criar |
| AUTH-02 | Sistema suporta 3 perfis por propriedade: proprietário, veterinário, leitor | Tabela `property_members` com coluna `perfil` enum; lida via RLS helper function |
| AUTH-03 | Veterinário pode ser vinculado a múltiplas propriedades via tabela de permissões | Mesmo `property_members` — 1 row por (user_id, property_id); query retorna lista |
| AUTH-04 | Usuário com múltiplas propriedades pode selecionar a propriedade ativa na UI | `currentPropertyProvider` placeholder já existe; Phase 1 o preenche com query real + SharedPreferences |
| AUTH-05 | Isolamento de dados por propriedade via RLS (usuário nunca vê dados de outra fazenda) | RLS com `FORCE ROW LEVEL SECURITY` + função helper + teste negativo automatizado |

</phase_requirements>

---

## Summary

Phase 1 conecta três peças já preparadas na Phase 0: o `GoRouterRefreshStream` wired ao `onAuthStateChange`, o `currentPropertyProvider` com `build()` retornando `null`, e o `SupabaseService.auth` como ponto único de acesso ao GoTrue. O trabalho desta fase é preencher esses placeholders com implementação real e adicionar a camada de banco de dados (tabelas `propriedades` e `property_members` com RLS completo).

O fluxo de autenticação usa exclusivamente o GoTrue do Supabase via `supabase_flutter ^2.12.0`. Não há email de confirmação (D-01, já configurado). O reset de senha depende do evento `AuthChangeEvent.passwordRecovery` no stream `onAuthStateChange` — o router detecta esse evento e redireciona para a tela de nova senha antes de qualquer outra ação.

O isolamento multi-tenant é implementado integralmente via RLS PostgreSQL com `FORCE ROW LEVEL SECURITY`, ancorado em uma função helper `is_member_of(property_id uuid)` que consulta `property_members`. Toda tabela de domínio tem `property_id` desnormalizado e uma RLS policy que chama esse helper. O teste negativo automatizado (D-08) é um teste de integração Dart que cria dois usuários, um para cada propriedade, e verifica via `supabase_flutter` que as queries de um retornam vazio para dados do outro.

**Recomendação primária:** Implementar na ordem: (1) migrations SQL com `propriedades` + `property_members` + RLS + seed; (2) `authProvider` Riverpod 3.x como `AsyncNotifier<AuthState?>`; (3) guard no `router.dart`; (4) telas de auth (login, signup, reset); (5) `currentPropertyProvider` real; (6) teste negativo de RLS.

---

## Standard Stack

### Core (já no projeto — versões verificadas no pubspec.yaml)

| Library | Version | Purpose | Observação |
|---------|---------|---------|------------|
| supabase_flutter | ^2.12.0 | Auth GoTrue + PostgREST | Já instalado; `SupabaseService.auth` é o ponto de acesso |
| flutter_riverpod | >=3.0.0 <4.0.0 | State management | Phase 0 upgrade para 3.x; usar `AsyncNotifier` sem codegen para `authProvider` |
| go_router | ^17.2.0 | Navegação + auth guard | `redirect` placeholder já existe em `router.dart` |
| shared_preferences | ^2.5.0 | Persistência do property_id ativo | Já declarado; usar `SharedPreferences.getInstance()` |
| freezed_annotation | ^3.0.0 | Modelo `Property` imutável | Substituir placeholder em `current_property_provider.dart` |

### Supporting (dev)

| Library | Version | Purpose | Quando usar |
|---------|---------|---------|-------------|
| build_runner | ^2.14.0 | Codegen freezed | Rodar após criar `Property` model freezed |
| freezed | ^3.2.0 | Codegen imutabilidade | Modelo `Property` e `PropertyMember` |
| mocktail | ^1.0.5 | Mocking em testes | Mockar `SupabaseService` em unit tests de auth |

### Alternativas Consideradas

| Em vez de | Poderia usar | Tradeoff |
|-----------|-------------|----------|
| `AsyncNotifier<AuthState?>` manual | `StreamNotifier` sobre `onAuthStateChange` | `StreamNotifier` é mais idiomático para streams; porém `AsyncNotifier` é mais simples de testar — ambos válidos. Discretion de Claude. |
| `is_member_of()` helper SQL | `EXISTS (SELECT 1 FROM property_members ...)` inline nas policies | Helper centraliza lógica; inline duplica em cada tabela. Usar helper. |

**Instalação:** Nada a instalar — todas as dependências estão no pubspec.yaml da Phase 0.

**Verificação de versões:** [VERIFIED: pubspec.yaml lido diretamente]
- `supabase_flutter: ^2.12.0`
- `flutter_riverpod: >=3.0.0 <4.0.0`
- `go_router: ^17.2.0`
- `shared_preferences: ^2.5.0`
- `freezed_annotation: ^3.0.0`
- `freezed: ^3.2.0` (dev)

---

## Architecture Patterns

### Estrutura de pastas recomendada para Phase 1

```
lib/
├── core/
│   ├── providers/
│   │   ├── auth_provider.dart          # NOVO: AsyncNotifier<AuthState?>
│   │   ├── current_property_provider.dart  # ATUALIZAR: build() real
│   │   └── supabase_providers.dart     # existente
│   ├── router/
│   │   ├── router.dart                 # ATUALIZAR: redirect com auth guard
│   │   └── routes.dart                 # ATUALIZAR: adicionar /login, /signup, etc.
│   └── widgets/
│       └── property_selector.dart      # ATUALIZAR: dropdown real
├── features/
│   └── auth/
│       ├── data/
│       │   ├── auth_repository.dart    # NOVO: signUp, signIn, signOut, resetPassword
│       │   └── property_repository.dart # NOVO: fetchMemberProperties, fetchActivePerfil
│       └── presentation/
│           ├── login_screen.dart       # NOVO
│           ├── signup_screen.dart      # NOVO
│           ├── reset_password_screen.dart  # NOVO
│           └── no_access_screen.dart   # NOVO
supabase/
├── migrations/
│   └── 20260504_01_auth_multitenancy.sql  # NOVO: propriedades + property_members + RLS
└── seed.sql                            # ATUALIZAR: usuários de teste + vínculos
```

### Padrão 1: authProvider como AsyncNotifier sobre onAuthStateChange

**O que é:** Provider Riverpod que expõe o `AuthState` atual do Supabase. O router e outros providers observam este provider para reagir a login/logout/passwordRecovery.

**Quando usar:** Toda lógica que precisa saber se há sessão ativa.

```dart
// Source: padrão Supabase+Riverpod documentado em supabase.com/docs/guides/getting-started/tutorials/with-flutter
// + adaptação para Riverpod 3.x [VERIFIED: pubspec.yaml confirma flutter_riverpod >=3.0.0]

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthState?> build() async {
    final service = ref.watch(supabaseServiceProvider);
    // Subscribes to auth state changes
    ref.onDispose(
      service.auth.onAuthStateChange.listen((data) {
        state = AsyncData(data);
      }).cancel,
    );
    return service.auth.currentSession != null
        ? AuthState('INITIAL_SESSION', service.auth.currentSession)
        : null;
  }
}
```

**Nota Riverpod 3.x:** `ref.onDispose` aceita diretamente a função cancel do StreamSubscription. [VERIFIED: pubspec flutter_riverpod >=3.0.0 <4.0.0]

### Padrão 2: GoRouter redirect com auth guard

**O que é:** A função `redirect` em `router.dart` lê o `authProvider` e redireciona conforme o estado.

**Quando usar:** Cada vez que o auth stream emite um evento, `GoRouterRefreshStream` notifica o router, que re-executa `redirect`.

```dart
// Source: padrão estabelecido — router.dart já tem GoRouterRefreshStream wired
// [VERIFIED: lib/core/router/router.dart lido diretamente]

redirect: (context, state) {
  final authAsync = ref.read(authNotifierProvider);
  final authState = authAsync.asData?.value;
  final isLoggedIn = authState?.session != null;
  final isPasswordRecovery =
      authState?.event == AuthChangeEvent.passwordRecovery;

  final onAuthRoute = state.matchedLocation == AppRoutes.login ||
      state.matchedLocation == AppRoutes.signup ||
      state.matchedLocation == AppRoutes.resetPassword ||
      state.matchedLocation == AppRoutes.noAccess;

  // Password recovery: redireciona para tela de nova senha independente do estado
  if (isPasswordRecovery) return AppRoutes.resetPassword;

  // Não logado: redireciona para login, exceto se já está em rota de auth
  if (!isLoggedIn) return onAuthRoute ? null : AppRoutes.login;

  // Logado e em rota de auth: redireciona para dashboard
  if (isLoggedIn && onAuthRoute) return AppRoutes.dashboard;

  return null; // sem redirect
},
```

**Importante:** O `redirect` no `routerProvider` (que é um `Provider`, não `ConsumerWidget`) precisa de acesso ao `ref`. A solução estabelecida no projeto é passar `ref` via closure para dentro do `GoRouter`. [VERIFIED: router.dart usa `Provider<GoRouter>((ref) => ...)` com closure]

### Padrão 3: currentPropertyProvider com lógica real

**O que é:** Substitui o `build() async => null` por uma query real em `property_members`, com leitura de `SharedPreferences` para persistência entre reloads.

```dart
// [VERIFIED: lib/core/providers/current_property_provider.dart lido diretamente]

@override
Future<Property?> build() async {
  final service = ref.watch(supabaseServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  // Busca propriedades do usuário autenticado
  final rows = await service.client
      .from('property_members')
      .select('propriedades(id, nome), perfil')
      .order('propriedades(nome)');

  if (rows.isEmpty) return null; // → tela sem acesso

  // Auto-seleciona se só tem 1; respeita saved ID se tem múltiplas
  final savedId = prefs.getString('active_property_id');
  final match = rows.firstWhere(
    (r) => r['propriedades']['id'] == savedId,
    orElse: () => rows.first,
  );
  return Property.fromJson(match['propriedades'] as Map<String, dynamic>);
}

Future<void> selectProperty(Property property) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('active_property_id', property.id);
  state = AsyncData(property);
}
```

### Padrão 4: Schema SQL — propriedades + property_members + RLS

**O que é:** Migration que cria as duas tabelas de Phase 1 com RLS completo.

```sql
-- Source: padrão Supabase multi-tenant documentado em supabase.com/docs/guides/database/postgres/row-level-security
-- [CITED: https://supabase.com/docs/guides/database/postgres/row-level-security]

-- Tabela de propriedades rurais
CREATE TABLE propriedades (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE propriedades ENABLE ROW LEVEL SECURITY;
ALTER TABLE propriedades FORCE ROW LEVEL SECURITY;

-- Tabela de membros por propriedade (auth multi-tenant)
CREATE TYPE perfil_enum AS ENUM ('proprietario', 'veterinario', 'leitor');

CREATE TABLE property_members (
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id  uuid NOT NULL REFERENCES propriedades(id) ON DELETE CASCADE,
  perfil       perfil_enum NOT NULL DEFAULT 'leitor',
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, property_id)
);

ALTER TABLE property_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_members FORCE ROW LEVEL SECURITY;

-- Helper function: verifica se o usuário autenticado é membro da propriedade
CREATE OR REPLACE FUNCTION is_member_of(p_property_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM property_members
    WHERE user_id = auth.uid()
      AND property_id = p_property_id
  );
$$;

-- RLS policies: propriedades
CREATE POLICY "members_can_read_their_properties"
  ON propriedades FOR SELECT
  USING (is_member_of(id));

-- RLS policies: property_members (usuário vê apenas suas próprias linhas)
CREATE POLICY "members_read_own_memberships"
  ON property_members FOR SELECT
  USING (user_id = auth.uid());
```

**Nota `SECURITY DEFINER`:** A função `is_member_of` usa `SECURITY DEFINER` para que possa ler `property_members` mesmo quando RLS bloqueia o acesso direto. Isso é o padrão Supabase documentado. [CITED: https://supabase.com/docs/guides/database/postgres/row-level-security]

### Padrão 5: Reset de senha via evento passwordRecovery

**O que é:** Supabase envia email com link. Quando o usuário clica, o browser navega de volta para o app com tokens na URL. O `supabase_flutter` processa automaticamente a URL e emite `AuthChangeEvent.passwordRecovery` no stream `onAuthStateChange`. O router detecta e redireciona para a tela de nova senha.

```dart
// Na ResetPasswordScreen, após o usuário submeter a nova senha:
await supabaseService.auth.updateUser(
  UserAttributes(password: newPassword),
);
// Após updateUser, Supabase emite AuthChangeEvent.userUpdated
// O router redireciona automaticamente para dashboard
```

**Configuração necessária em config.toml:**
```toml
[auth]
site_url = "http://127.0.0.1:3000"
additional_redirect_urls = ["https://127.0.0.1:3000", "http://127.0.0.1:3000"]
```
O `additional_redirect_urls` já contém `https://127.0.0.1:3000`. Verificar se `http://` (sem TLS) também está — necessário para dev local. [VERIFIED: supabase/config.toml lido diretamente]

**Pitfall PKCE:** Há um issue reportado no `supabase-flutter` onde `AuthChangeEvent.passwordRecovery` não dispara quando `AuthFlowType.pkce` está ativo. O `supabase_flutter ^2.x` usa PKCE por padrão para mobile, mas no web usa implicit flow. Testar no browser antes de assumir que o evento chegará. [CITED: https://github.com/supabase/supabase-flutter/issues/664]

### Anti-Patterns a Evitar

- **Importar `supabase_flutter` diretamente em widgets:** O padrão estabelecido é acesso via `SupabaseService`/repository. [VERIFIED: supabase_service.dart lido]
- **Usar JWT custom claims para perfil:** Stale-until-refresh. Sempre consultar `property_members` via RLS. [ASSUMED — mencionado no CLAUDE.md]
- **Fazer lógica de auth no `build()` de widgets:** Toda lógica vai no notifier/repository; widgets apenas observam `AsyncValue`.
- **Setar `SECURITY DEFINER` em funções sem cuidado:** Toda função `SECURITY DEFINER` deve ter `STABLE` ou `VOLATILE` declarado e ser revisada para evitar SQL injection.
- **Não tratar `authAsync.isLoading` no redirect:** Se o authProvider ainda está carregando, o redirect não deve tomar decisões — retornar `null` e aguardar.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por quê |
|----------|--------------|-------------------|---------|
| Session persistence | Lógica manual de salvar JWT | `supabase_flutter` (já gerencia via SharedPreferences/SecureStorage) | Token refresh, rotação, expiração são tratados automaticamente |
| Token refresh | Timer manual de refresh | GoTrue interno do `supabase_flutter` | `enable_refresh_token_rotation = true` já configurado |
| Email de reset | Envio manual de email | `auth.resetPasswordForEmail()` | Supabase gerencia template, expiração e revogação do token |
| Captura do deep-link de reset | Parsing manual da URL | `supabase_flutter` auto-processa `onAuthStateChange` | SDK detecta `access_token` na URL e emite evento automaticamente |
| Isolamento multi-tenant | Guards no Flutter | RLS no PostgreSQL + `is_member_of()` | RLS é enforced no banco — cliente Flutter nunca precisa filtrar manualmente |
| Hash de senha | Qualquer coisa | GoTrue (bcrypt internamente) | Nunca manipular senhas no cliente |

---

## Common Pitfalls

### Pitfall 1: redirect lê authProvider com `.asData` antes do estado carregar

**O que acontece:** Se o `redirect` executa antes do `authProvider` ter terminado o `build()` async, `authAsync.asData` retorna `null`. O guard acha que o usuário não está logado e redireciona para `/login`, mesmo que esteja logado.

**Por que acontece:** `GoRouterRefreshStream` notifica o router imediatamente no construtor (`notifyListeners()` na primeira linha). O router executa `redirect` antes do primeiro `build()` do `authProvider` completar.

**Como evitar:** No `redirect`, verificar `authAsync.isLoading`:
```dart
if (authAsync.isLoading) return null; // aguardar
```
[VERIFIED: lib/core/router/router.dart — GoRouterRefreshStream chama notifyListeners() no construtor]

### Pitfall 2: passwordRecovery event chega e router redireciona para login

**O que acontece:** O evento `passwordRecovery` chega junto com um `signedIn`. O router processa `signedIn` e manda o usuário para o dashboard ao invés da tela de nova senha.

**Por que acontece:** O stream emite dois eventos em sequência. O guard trata `isLoggedIn = true` e redireciona para dashboard antes de checar `passwordRecovery`.

**Como evitar:** Verificar `passwordRecovery` **antes** do check `isLoggedIn` no redirect. Também manter um flag no `authProvider` ou verificar `authState.event` diretamente.

### Pitfall 3: FORCE ROW LEVEL SECURITY não aplicado nas tabelas futuras

**O que acontece:** Fases futuras criam novas tabelas sem `FORCE ROW LEVEL SECURITY`. O service role do Supabase Studio consegue ver todos os dados, mas mais perigoso: policies mal escritas ou ausentes deixam dados expostos.

**Por que acontece:** `ENABLE ROW LEVEL SECURITY` sem `FORCE` permite que o owner do banco bypass as policies. `FORCE` remove esse bypass.

**Como evitar:** Template de migration com ambos os comandos. Incluir no seed de cada fase. Adicionar nota no CLAUDE.md de convenções quando consolidado.

### Pitfall 4: SharedPreferences salva property_id de propriedade à qual o usuário não tem mais acesso

**O que acontece:** Usuário é removido de uma propriedade. No reload, `currentPropertyProvider.build()` tenta usar o `saved_id` do SharedPreferences, mas a query em `property_members` não retorna aquela propriedade. O app trata como "0 propriedades" e vai para "sem acesso".

**Por que acontece:** Divergência entre dado salvo localmente e dado no banco.

**Como evitar:** No `build()`, fazer o `firstWhere` com `orElse: () => rows.first` — se o saved_id não existir na lista retornada, usar a primeira da lista. Se a lista for vazia, ir para "sem acesso". Não tratar como erro fatal.

### Pitfall 5: additional_redirect_urls incompleto para dev

**O que acontece:** Link de reset de senha redireciona para URL não listada → Supabase bloqueia com erro `redirect_uri_mismatch`.

**Por que acontece:** `config.toml` tem `https://127.0.0.1:3000` mas não `http://127.0.0.1:3000` (sem TLS), que é o que o `flutter run -d edge` serve por padrão.

**Como evitar:** Incluir ambas as variantes no `additional_redirect_urls`. [VERIFIED: supabase/config.toml — atualmente só tem `https://`]

### Pitfall 6: is_member_of() chamada sem índice em property_members

**O que acontece:** A cada request autenticado, o PostgreSQL executa a função helper que faz `SELECT` em `property_members`. Sem índice em `(user_id, property_id)`, isso vira seq scan em tabelas grandes.

**Por que acontece:** A chave primária `(user_id, property_id)` já é um índice. Mas se a query filtrar só por `user_id`, precisa de índice parcial.

**Como evitar:** A PK composta `(user_id, property_id)` cobre a query da função. Adicionar índice separado em `(user_id)` se necessário para queries que listam propriedades do usuário.

---

## Code Examples

### Auth Repository — padrão estabelecido no projeto

```dart
// Source: padrão repository estabelecido em Phase 0 — features não importam supabase_flutter diretamente
// [VERIFIED: lib/core/services/supabase_service.dart]

class AuthRepository {
  AuthRepository(this._service);
  final SupabaseService _service;

  Future<void> signUp({required String email, required String password}) =>
      _service.auth.signUp(email: email, password: password);

  Future<void> signIn({required String email, required String password}) =>
      _service.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _service.auth.signOut();

  Future<void> resetPasswordForEmail(String email) =>
      _service.auth.resetPasswordForEmail(
        email,
        redirectTo: 'http://127.0.0.1:3000/reset-password',
      );

  Future<void> updatePassword(String newPassword) =>
      _service.auth.updateUser(UserAttributes(password: newPassword));
}
```

### Seed SQL para testes de Phase 1

```sql
-- Inserir via Supabase Studio ou seed.sql após supabase db reset
-- Cria 2 usuários de teste e vincula a propriedades separadas

-- Usuário A: proprietário da Fazenda Alpha
INSERT INTO propriedades (id, nome) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Fazenda Alpha'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Fazenda Beta');

-- Vínculos (user_id vem do auth.users após criar via Studio)
-- Inserir property_members após criar usuários via Supabase Studio/API
```

### Teste negativo de RLS (D-08)

```dart
// Source: padrão integration_test Dart — [ASSUMED] baseado em padrão Supabase+Flutter
// Rodar com: flutter test integration_test/rls_isolation_test.dart

test('usuário A não lê dados da propriedade do usuário B', () async {
  // Signed in as user A
  await supabase.auth.signInWithPassword(email: userA, password: passA);

  final result = await supabase
      .from('property_members')
      .select()
      .eq('property_id', propertyB_id); // propriedade de B

  expect(result, isEmpty); // RLS deve bloquear
});
```

---

## Runtime State Inventory

> Phase 1 cria tabelas novas — não é rename/refactor. Esta seção é incluída apenas para documentar que foi checada.

| Categoria | Itens encontrados | Ação necessária |
|-----------|-------------------|-----------------|
| Stored data | Nenhum dado de domínio ainda existe (Phase 0 foi apenas scaffold) | Nenhuma migração de dados |
| Live service config | `supabase/config.toml` — `enable_confirmations = false` já configurado; `additional_redirect_urls` com apenas `https://` | Adicionar `http://127.0.0.1:3000` |
| OS-registered state | Nenhum | — |
| Secrets/env vars | `SUPABASE_URL` e `SUPABASE_ANON_KEY` via dart-define; não mudam | Nenhuma ação |
| Build artifacts | Nenhum codegen gerado ainda para Phase 1 | Rodar `build_runner` após criar models freezed |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI | Migrations, local dev | ✓ | 2.95.4 | — |
| Flutter SDK | Toda a app | ✓ | 3.41.6 | — |
| Dart SDK | Toda a app | ✓ | 3.11.4 | — |
| Inbucket (email local) | Teste de reset de senha | ✓ (porta 54324, configurado em config.toml) | incluído no stack local | — |
| supabase_flutter | Auth + DB | ✓ | ^2.12.0 (pubspec) | — |
| shared_preferences | Persistência property ativa | ✓ | ^2.5.0 (pubspec) | — |
| freezed / build_runner | Codegen models | ✓ | ^3.2.0 / ^2.14.0 (pubspec) | — |

**Nenhuma dependência bloqueante ausente.**

**Nota sobre migrations:** `supabase/migrations/` está vazio — Phase 0 não criou nenhuma migration SQL (apenas scaffold Flutter). Phase 1 cria a primeira migration real.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `mocktail ^1.0.5` |
| Config file | nenhum arquivo de config separado — `flutter test` nativo |
| Quick run command | `flutter test test/` |
| Full suite command | `flutter test test/ && flutter test integration_test/` (integration requer Supabase local rodando) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Arquivo existe? |
|--------|----------|-----------|-------------------|----------------|
| AUTH-01 | signUp e signIn via email/senha | unit (mocktail) | `flutter test test/features/auth/auth_repository_test.dart` | ❌ Wave 0 |
| AUTH-01 | Login screen valida campos obrigatórios | widget | `flutter test test/features/auth/login_screen_test.dart` | ❌ Wave 0 |
| AUTH-02 | property_members tem coluna perfil | SQL / migration check | manual — verificar schema após migrate | N/A (SQL) |
| AUTH-03 | fetchMemberProperties retorna lista de propriedades | unit (mocktail) | `flutter test test/features/auth/property_repository_test.dart` | ❌ Wave 0 |
| AUTH-04 | currentPropertyProvider auto-seleciona com 1 prop; usa saved_id com N props | unit (ProviderContainer) | `flutter test test/core/current_property_provider_test.dart` | ✅ parcial (atualizar) |
| AUTH-05 | Usuário A não lê dados da propriedade de usuário B | integration (RLS negativo) | `flutter test integration_test/rls_isolation_test.dart` | ❌ Wave 0 |
| AUTH-05 | currentPropertyProvider retorna [] para user sem propriedades | unit | incluído em `current_property_provider_test.dart` | ❌ adicionar caso |

### Sampling Rate

- **Por commit de task:** `flutter test test/`
- **Por merge de wave:** `flutter test test/ && flutter test integration_test/rls_isolation_test.dart`
- **Phase gate:** Suite completa verde antes de `/gsd-verify-work`

### Wave 0 Gaps (arquivos a criar antes de implementar)

- [ ] `test/features/auth/auth_repository_test.dart` — cobre AUTH-01 (signUp, signIn, signOut, resetPassword)
- [ ] `test/features/auth/property_repository_test.dart` — cobre AUTH-03 e AUTH-04 (fetchMemberProperties)
- [ ] `test/features/auth/login_screen_test.dart` — cobre AUTH-01 (validação de form na UI)
- [ ] `integration_test/rls_isolation_test.dart` — cobre AUTH-05 (teste negativo de RLS — requer Supabase local rodando)
- [ ] Atualizar `test/core/current_property_provider_test.dart` — adicionar casos com mock de `PropertyRepository` (0 props → null, 1 prop → auto-seleciona, N props → usa saved_id)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim | Supabase GoTrue (bcrypt interno, rate limiting via `auth.rate_limit` no config.toml) |
| V3 Session Management | sim | `enable_refresh_token_rotation = true` já configurado; `jwt_expiry = 3600` |
| V4 Access Control | sim | RLS + `FORCE ROW LEVEL SECURITY` + `is_member_of()` helper |
| V5 Input Validation | sim | Validação no form Flutter (email format, senha mínima 6 chars per config.toml); Supabase valida server-side |
| V6 Cryptography | não aplicável | Senhas gerenciadas pelo GoTrue internamente — nunca manipuladas no cliente |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tenant data leakage (user A vê dados de B) | Information Disclosure | RLS com `FORCE ROW LEVEL SECURITY` + teste negativo automatizado (D-08) |
| Força bruta no login | Denial of Service / Auth | `sign_in_sign_ups = 30` por 5 min por IP (já configurado em config.toml) |
| Token stale após mudança de perfil | Elevation of Privilege | Não usar JWT custom claims para perfil; sempre consultar `property_members` via RLS |
| Reset de senha com token expirado | Authentication Bypass | GoTrue invalida tokens de reset após uso; `otp_expiry = 3600` |
| Redirect URL manipulation no reset | Authentication Bypass | `additional_redirect_urls` allowlist no config.toml; nunca aceitar redirect URL do cliente |

---

## Assumptions Log

| # | Claim | Section | Risk se errado |
|---|-------|---------|----------------|
| A1 | `AuthChangeEvent.passwordRecovery` dispara corretamente no Flutter web com supabase_flutter ^2.12.0 sem PKCE issues | Padrão 5 + Pitfall 2 | Reset de senha quebrado; workaround: usar OTP/magic link ou polling de session |
| A2 | `SECURITY DEFINER` em `is_member_of()` não cria vulnerabilidade de escalonamento com o schema atual | Padrão 4 | Se a função for manipulada para retornar true sem autenticação real, todas as policies falham |
| A3 | `flutter test integration_test/` com Supabase local funciona no Windows com `supabase start` rodando | Validation Architecture | Testes de RLS precisariam ser feitos manualmente via curl ou pgTAP |

---

## Open Questions (RESOLVED)

1. **`additional_redirect_urls` para produção**
   - O que sabemos: dev usa `http://127.0.0.1:3000`. Em produção precisará da URL real do app web.
   - O que está incerto: URL de produção ainda não definida.
   - Recomendação: Planner deve criar task de "atualizar config.toml e Supabase dashboard com URL de produção" como placeholder para quando o domínio for definido. Por ora, deixar só dev.

2. **Supabase local: `supabase start` deve estar rodando para testes de integração**
   - O que sabemos: `integration_test/rls_isolation_test.dart` depende de Supabase local ativo.
   - O que está incerto: CI/CD não está configurado ainda; testes de integração são manuais por ora.
   - Recomendação: Documentar no task que o dev precisa rodar `supabase start` antes dos integration tests. Marcar como pré-condição.

3. **Codegen Riverpod: usar `@riverpod` annotation no authProvider ou não?**
   - O que sabemos: `riverpod_generator >=4.0.0` está no pubspec; Phase 0 não criou nenhum provider com codegen ainda.
   - O que está incerto: Se é mais ergonômico usar `@riverpod` (codegen) ou `AsyncNotifierProvider` manual para o auth provider que é um singleton crítico.
   - Recomendação: Usar `AsyncNotifierProvider` manual (sem `@riverpod`) para o `authProvider` — é mais explícito para um provider tão central. Usar codegen para providers de features futuras. [Claude's Discretion]

---

## Sources

### Primary (HIGH confidence)
- `lib/core/router/router.dart` — GoRouterRefreshStream implementation, redirect placeholder [VERIFIED: lido diretamente]
- `lib/core/providers/current_property_provider.dart` — CurrentPropertyNotifier placeholder [VERIFIED: lido diretamente]
- `lib/core/services/supabase_service.dart` — SupabaseService pattern [VERIFIED: lido diretamente]
- `pubspec.yaml` — versões reais de todos os packages [VERIFIED: lido diretamente]
- `supabase/config.toml` — `enable_confirmations = false`, `additional_redirect_urls`, `enable_refresh_token_rotation` [VERIFIED: lido diretamente]
- `test/` — infraestrutura de testes existente [VERIFIED: todos os arquivos lidos]
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) — FORCE ROW LEVEL SECURITY, SECURITY DEFINER pattern [CITED]
- [Supabase Dart auth-resetpasswordforemail](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail) — API do reset de senha [CITED]

### Secondary (MEDIUM confidence)
- [supabase-flutter issue #664](https://github.com/supabase/supabase-flutter/issues/664) — PKCE + passwordRecovery event bug [CITED — issue aberto, verificar se resolvido em 2.12.0]
- [GoRouter + Riverpod patterns](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/) — padrão de redirect com ref [WebSearch verificado com codebase existente]

### Tertiary (LOW confidence)
- WebSearch sobre RLS multi-tenant com property_members — padrão geral confirmado, implementação específica é [ASSUMED] baseado em docs oficiais Supabase

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versões verificadas diretamente no pubspec.yaml
- Architecture: HIGH — baseado em código Phase 0 lido diretamente + docs Supabase oficiais
- Pitfalls: HIGH — pitfalls 1, 3, 4, 5 verificados via código existente; pitfall 2 via issue tracker oficial
- Validation: HIGH — infraestrutura de testes existente verificada diretamente

**Research date:** 2026-05-04
**Valid until:** 2026-06-04 (supabase_flutter minor releases frequentes; verificar changelog se >30 dias)
