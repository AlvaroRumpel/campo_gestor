---
phase: 1
slug: auth-multi-tenancy-core
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-04
reviewed_at: 2026-05-04
---

# Phase 1 — Auth & Multi-tenancy Core: UI Design Contract

> Visual and interaction contract for Phase 1: Login, Signup, Reset de Senha, Sem Acesso, e Property Selector ativo.
> Gerado por gsd-ui-researcher. Verificado por gsd-ui-checker.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3 built-in) |
| Preset | not applicable — Flutter, não React/shadcn |
| Component library | Material 3 (Flutter SDK `useMaterial3: true`) |
| Icon library | `Icons` (Material Icons, já bundled no SDK) |
| Font | Roboto (Material 3 default — não requer bundling adicional) |

**shadcn gate:** não aplicável — stack é Flutter/Dart, não React/Next.js/Vite.

**Fonte:** `app_theme.dart` — `useMaterial3: true`, `ColorScheme.fromSeed(seedColor: Color(0xFF4A6741))`.
`main.dart` — `MaterialApp.router`, locale `pt_BR`, `theme: AppTheme.light()`.

---

## Spacing Scale

Declared values (multiples of 4 — Flutter `SizedBox` / `EdgeInsets` equivalents):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Gaps entre ícone e label inline; `SizedBox(width: 4)` |
| sm | 8px | Espaçamento compacto dentro de widgets (ex: padding interno de chip) |
| md | 16px | Padding padrão de cards e telas; `EdgeInsets.all(16)` |
| lg | 24px | Padding vertical de seção; separador entre formulário e botão |
| xl | 32px | Espaçamento entre grupos de campos no formulário |
| 2xl | 48px | Espaço superior da tela de login (logo → formulário) |
| 3xl | 64px | Reservado para page-level; não usado nas telas de auth desta fase |

**Exceção — touch targets:** botões e inputs de formulário devem ter altura mínima de 48px conforme Material 3 e WCAG 2.1 AA para alvos de toque.

**Fonte:** 8-point grid (padrão Material 3). Confirmado pelas convenções Flutter já em uso no AppShell (`SizedBox(width: 4)` no property_selector.dart).

---

## Typography

Todos os valores seguem a escala Material 3 (`TextTheme`). Os roles usados nesta fase são:

| Role | Flutter TextStyle | Size | Weight | Line Height | Uso nesta fase |
|------|-------------------|------|--------|-------------|----------------|
| Body | `bodyMedium` | 14sp | 400 (regular) | 1.43 | Textos de apoio, labels de campo, mensagens de erro inline |
| Label | `bodyLarge` | 16sp | 400 (regular) | 1.50 | Placeholder de campo, hint text, texto de link ("Esqueceu a senha?") |
| Heading | `titleLarge` | 22sp | 600 (semibold via `FontWeight.w600`) | 1.27 | Título da tela ("Entrar", "Criar conta", "Nova senha") |
| Display | `headlineSmall` | 24sp | 600 (semibold) | 1.33 | Nome da propriedade no PropertySelector do AppBar |

**Regra:** Apenas 2 weights em uso — regular (400) e semibold (600). Nenhum uso de bold (700) ou light (300) nesta fase.

**Fonte:** Material 3 type scale (m3.material.io/styles/typography/type-scale-tokens). Confirmado por `property_selector.dart` que usa `fontSize: 18` no AppBar — esta fase padroniza em `titleLarge` (22sp) como heading de tela e mantém o selector no `titleMedium` existente (fontSize 18 → equivalente a `titleMedium` do M3).

---

## Color

O `ColorScheme.fromSeed` do Material 3 gera todos os tokens de cor a partir do seedColor `#4A6741` (verde-musgo). As cores abaixo são os roles semânticos do M3 derivados desse seed:

| Role | M3 Token | Hex aproximado (light) | Usage |
|------|----------|------------------------|-------|
| Dominant (60%) | `surface` / `surfaceContainerLowest` | ~`#F8FAF5` (off-white esverdeado) | Fundo de telas (login, signup, reset, sem acesso) |
| Secondary (30%) | `surfaceContainer` / `surfaceContainerHigh` | ~`#EEF1EB` (cinza-verde claro) | Cards de formulário, AppBar background, NavigationRail |
| Accent (10%) | `primary` | ~`#4A6741` (verde-musgo) → gerado pelo M3 como tom mais saturado | Reservado para: botão CTA principal ("Entrar", "Criar conta"), indicador de item ativo no NavigationRail/NavigationBar, foco de campo de texto |
| Destructive | `error` | ~`#BA1A1A` (vermelho M3 padrão) | Apenas mensagens de erro de validação de campo e erros de autenticação (senha inválida, email não encontrado) |

**Accent reservado exclusivamente para:**
1. Botão CTA primário (`FilledButton` com `style` padrão do M3 — usa `primary` automaticamente)
2. Estado ativo do `NavigationRail` / `NavigationBar` (gerenciado pelo tema M3, não precisa override)
3. Indicador de foco em `TextField` (borda de foco — gerenciado pelo `InputDecoration` padrão M3)

**Accent NÃO usado em:** texto de corpo, ícones decorativos, links secundários (usar `onSurface` com 60% opacidade).

**Fonte:** `app_theme.dart` seed `Color(0xFF4A6741)` + especificação Material 3 ColorScheme.fromSeed (m3.material.io/styles/color/the-color-system/tokens).

---

## Screens in Scope (Phase 1)

Esta fase introduz 4 telas novas e atualiza 2 widgets existentes:

| Screen / Widget | Rota | Descrição |
|-----------------|------|-----------|
| `LoginScreen` | `/login` | Email + senha + link "Criar conta" + link "Esqueceu a senha?" |
| `SignupScreen` | `/signup` | Email + senha + confirmar senha + botão "Criar conta" |
| `ResetPasswordScreen` | `/reset-password` | Dois estados: (1) Solicitar reset — campo email + botão; (2) Nova senha — campo nova senha + confirmar + botão |
| `NoAccessScreen` | `/sem-acesso` | Tela estática informativa — sem ação do usuário (D-03) |
| `PropertySelector` (update) | widget no AppBar | Dropdown real com lista de propriedades quando o usuário tem 2+ |
| Router guard | — | Redirect auth automático — sem tela própria |

---

## Layout Contracts por Tela

### LoginScreen e SignupScreen

- Layout: `Scaffold` sem AppBar (telas de auth ficam fora do `AppShell`). Fundo `surface`.
- Conteúdo centralizado verticalmente em `SingleChildScrollView` > `Center` > `ConstrainedBox(maxWidth: 400)`.
- Estrutura vertical (de cima para baixo):
  1. `SizedBox(height: 48)` — espaço superior (token `2xl`)
  2. Ícone / logo — `Icons.grass` (64×64px) na cor `primary` — placeholder até logo real existir
  3. `SizedBox(height: 24)` — token `lg`
  4. Título da tela (`titleLarge`, weight 600)
  5. `SizedBox(height: 32)` — token `xl`
  6. Card do formulário: `Card` com `surfaceContainer`, `borderRadius: 12`, `padding: EdgeInsets.all(24)`
  7. Campos de formulário (`TextField` com `OutlineInputBorder`) com `SizedBox(height: 16)` entre eles
  8. `SizedBox(height: 24)` — token `lg`
  9. Botão CTA (`FilledButton`, largura 100% do card, height mínima 48px)
  10. Links secundários (`TextButton`) abaixo do botão

### ResetPasswordScreen

- Mesmo layout do Login. Dois estados renderizados condicionalmente no mesmo widget:
  - Estado 1 (solicitar): campo email + `FilledButton("Enviar email de redefinição")` + link "Voltar ao login"
  - Estado 2 (nova senha — ativado por `AuthChangeEvent.passwordRecovery`): campo nova senha + campo confirmar senha + `FilledButton("Salvar nova senha")`
- Transição entre estados: substituição inline do conteúdo do card (sem nova rota).

### NoAccessScreen

- `Scaffold` sem AppBar. Conteúdo centrado verticalmente.
- Ícone: `Icons.lock_outline` (64×64px, cor `onSurface` com 40% opacidade)
- Título: `titleLarge` — "Acesso não configurado"
- Subtítulo: `bodyMedium` — (ver Copywriting Contract abaixo)
- Sem botões de ação (D-03).

### PropertySelector (AppBar — com 2+ propriedades)

- Substitui o `Text` estático por `DropdownButton<String>` (Material) ou `PopupMenuButton` envolto em `TextButton`.
- Exibe: nome da propriedade ativa + `Icons.arrow_drop_down`
- Com 1 propriedade: mantém `Text` estático com nome (sem dropdown) — D-05.
- Em loading: `CircularProgressIndicator(strokeWidth: 2)` com `width: 16, height: 16` — já implementado.
- Em error: `Text('Erro ao carregar')` com `bodyMedium` na cor `error`.

---

## Interaction States

| Elemento | Estado | Tratamento visual |
|---------|--------|-------------------|
| `FilledButton` CTA | Idle | Cor `primary`, texto `onPrimary` |
| `FilledButton` CTA | Loading | `CircularProgressIndicator(strokeWidth: 2, color: onPrimary)` substitui label; botão permanece desabilitado |
| `FilledButton` CTA | Disabled | Opacidade 38% (M3 padrão) |
| `TextField` | Idle | `OutlineInputBorder` com `borderRadius: 8` |
| `TextField` | Focused | Borda na cor `primary` (M3 padrão) |
| `TextField` | Error | Borda + label de erro na cor `error`; `errorText` visível abaixo do campo |
| Tela inteira | Loading inicial | `CircularProgressIndicator` centrado na tela (aguardando auth state) |
| Auth error | Snackbar | `ScaffoldMessenger.of(context).showSnackBar()` com mensagem de erro, duração 4s |

---

## Form Validation Rules

| Campo | Validação | Mensagem de erro (pt-BR) |
|-------|-----------|--------------------------|
| Email | Obrigatório + formato válido | "Digite um email válido" |
| Senha (login) | Obrigatório, mínimo 6 caracteres | "A senha deve ter pelo menos 6 caracteres" |
| Senha (signup) | Obrigatório, mínimo 6 caracteres | "A senha deve ter pelo menos 6 caracteres" |
| Confirmar senha | Deve ser igual à senha | "As senhas não coincidem" |
| Nova senha | Obrigatório, mínimo 6 caracteres | "A senha deve ter pelo menos 6 caracteres" |

Validação disparada em `onChanged` (feedback imediato após primeiro submit) + no submit. Usar `Form` + `FormState.validate()`.

---

## Copywriting Contract

| Elemento | Copy |
|---------|------|
| Primary CTA — Login | "Entrar" |
| Primary CTA — Signup | "Criar conta" |
| Primary CTA — Solicitar reset | "Enviar email de redefinição" |
| Primary CTA — Nova senha | "Salvar nova senha" |
| Link "sem conta" | "Não tem conta? Criar conta" |
| Link "tem conta" | "Já tem conta? Entrar" |
| Link esqueceu senha | "Esqueceu a senha?" |
| Link voltar ao login | "Voltar ao login" |
| LoginScreen título | "Entrar" |
| SignupScreen título | "Criar conta" |
| ResetPasswordScreen título (estado 1) | "Redefinir senha" |
| ResetPasswordScreen título (estado 2) | "Nova senha" |
| NoAccessScreen título | "Acesso não configurado" |
| NoAccessScreen corpo | "Sua conta foi criada, mas ainda não está vinculada a nenhuma propriedade. Entre em contato com o proprietário da fazenda para receber acesso." |
| Sucesso — reset solicitado | Snackbar: "Email de redefinição enviado. Verifique sua caixa de entrada." |
| Sucesso — nova senha salva | Redirecionamento automático para dashboard (sem mensagem explícita — o router trata) |
| Erro — credenciais inválidas | Snackbar: "Email ou senha inválidos. Verifique e tente novamente." |
| Erro — email não encontrado (reset) | Snackbar: "Se esse email estiver cadastrado, você receberá as instruções em breve." (não revelar se existe) |
| Erro — genérico de rede | Snackbar: "Não foi possível conectar. Verifique sua conexão e tente novamente." |
| PropertySelector loading | (spinner — sem texto) |
| PropertySelector erro | "Erro ao carregar propriedade" |
| PropertySelector — label label perfil | Exibir abaixo do nome da propriedade no dropdown: "Proprietário" / "Veterinário" / "Leitor" (capitalizado) |

**Nota de tom:** linguagem direta, sem jargão técnico, sem "ops!" ou "poxa". Ações claras (verbos imperativos no infinitivo). Mensagens de erro explicam o problema e indicam o próximo passo.

**Destructive actions nesta fase:** nenhuma ação destrutiva com confirmação nesta fase. Logout será implementado (botão no AppShell/menu), mas por ser reversível (basta logar novamente) não requer diálogo de confirmação — apenas executar diretamente.

---

## Accessibility Contract

| Concern | Requirement |
|---------|-------------|
| Touch targets | Mínimo 48×48px para todos botões e campos (`minimumSize: Size(double.infinity, 48)`) |
| Contrast | Material 3 ColorScheme.fromSeed garante 4.5:1 em todos os pares text/bg por construção |
| Screen reader | Todos os `TextField` com `decoration.labelText` ou `semanticsLabel` explícito |
| Loading states | `CircularProgressIndicator` com `semanticsLabel: 'Carregando'` |
| Error feedback | `errorText` no `InputDecoration` é lido automaticamente pelo TalkBack/VoiceOver |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Flutter SDK (Material 3) | `FilledButton`, `TextField`, `Card`, `NavigationRail`, `NavigationBar`, `AppBar`, `Scaffold`, `DropdownButton`, `PopupMenuButton`, `SnackBar` | not required — SDK oficial Flutter |
| pub.dev — pacotes já instalados (Phase 0) | `go_router`, `flutter_riverpod`, `supabase_flutter`, `shared_preferences` | not required — packages verificados na Phase 0 |
| Terceiros novos nesta fase | nenhum | not applicable |

Nenhum componente de terceiros novo é introduzido nesta fase. Todos os widgets são Material 3 nativo.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

---

## Pre-population Sources

| Source | Decisions Used |
|--------|---------------|
| CONTEXT.md | D-01 (sem confirmação email → sem tela "verifique email"), D-02 (reset incluso), D-03 (NoAccessScreen estática), D-04 (seed-only vínculo), D-05 (auto-select 1 prop), D-06 (SharedPreferences persistência), D-07 (perfil exibido, não enforced), D-08 (RLS test) |
| RESEARCH.md | Stack M3 + GoRouter + Riverpod 3.x, estrutura de pastas `features/auth/presentation/`, padrão `AsyncValue` para loading/error states |
| REQUIREMENTS.md | AUTH-01 (login/signup), AUTH-02 (3 perfis exibidos), AUTH-03 (multi-prop), AUTH-04 (seletor ativo), AUTH-05 (isolamento — sem impacto visual direto) |
| Codebase — `app_theme.dart` | seed `#4A6741`, `useMaterial3: true` → toda paleta derivada |
| Codebase — `app_shell.dart` | Breakpoint 600px, `NavigationRail` (web) / `NavigationBar` (mobile), `AppBar` com `PropertySelector` |
| Codebase — `property_selector.dart` | Estados loading/error/data já implementados — Phase 1 conecta com dados reais |
| Codebase — `router.dart` | `GoRouterRefreshStream` já wired; rotas `/login`, `/signup`, `/reset-password`, `/sem-acesso` a adicionar em `routes.dart` |
| Default (Material 3 spec) | Spacing scale 8pt, typography roles (`titleLarge`, `bodyMedium`, `bodyLarge`), touch target 48px |
| User input desta sessão | nenhum — todas as questões respondidas por artefatos upstream |
