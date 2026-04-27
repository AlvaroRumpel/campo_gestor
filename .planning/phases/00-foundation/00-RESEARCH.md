# Phase 0: Foundation - Research

**Researched:** 2026-04-26
**Domain:** Flutter web scaffold + Supabase local dev + Riverpod/GoRouter skeleton
**Confidence:** HIGH (stack and patterns are mature, well-documented; one ecosystem deviation explicitly locked by user)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**App Shell Layout**
- **D-01:** Web usa **sidebar fixo** (sempre visível, ícone + label). NavigationRail ou Drawer expandido.
- **D-02:** Itens de navegação top-level: Dashboard, Piquetes, Animais, Reprod., Sanitário — 5 items com placeholder screens vazias.
- **D-03:** Mobile colapsa para **Bottom NavigationBar** (tabs na parte inferior). GoRouter + StatefulShellRoute gerencia estado por tab.
- **D-04:** Header/AppBar mostra **nome da propriedade ativa + seletor** (dropdown para trocar propriedade). `currentPropertyProvider` alimenta o header desde o início — placeholder retorna null até Phase 1 preencher.

**Folder Structure**
- **D-05:** Organização **feature-first hybrid** (`lib/core/{providers,widgets,services,router,theme}` + `lib/features/{feature}/{data,domain,presentation}`).
- **D-06:** Padrão de acesso ao Supabase: **Abstract Repository + Supabase impl**. Interface Dart abstrata + implementação concreta. Features dependem da interface — nunca importam `supabase_flutter` diretamente. Testabilidade via `mocktail`.

**Supabase Setup**
- **D-07:** **CLI local + Docker** para dev. `supabase init` + `supabase start`. Migrações versionadas em `supabase/migrations/*.sql`. User instalará Docker Desktop antes da execução da fase.
- **D-08:** Secrets via **dart-define + VSCode launch.json**. `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Arquivo `.vscode/launch.json` no `.gitignore`. Sem arquivo .env, sem hardcode.

**Packages**
- **D-09:** **Todo o stack instalado na Phase 0** — pubspec.yaml recebe todos os packages do CLAUDE.md de uma vez para validar compilação conjunta antes de qualquer feature.
- **D-10:** Codegen pipeline (`build_runner` + `freezed` + `riverpod_generator`) **configurado mas NÃO usado na Phase 0** — primeiro model freezed real aparece na Phase 1. Phase 0 apenas instala e valida que `flutter pub get` + `dart run build_runner build` executam sem erro.

**Web Renderer**
- **D-11:** **Auto** (padrão Flutter) — sem configuração extra. *(Nota de pesquisa: o termo "auto" foi descontinuado em 2024; o default Flutter atual é `canvaskit`; o efeito prático é o mesmo — não passar `--web-renderer`.)*

**Theme e Locale**
- **D-12:** **Paleta agrária** com Material 3: seedColor em verde-musgo ou terra. Define identidade visual consistente com o domínio.
- **D-13:** **pt-BR configurado desde Phase 0** — `intl` + `flutter_localizations` no main.

### Claude's Discretion

- Cor exata do seedColor dentro da paleta "verde-musgo/terra" — escolha do Claude.
- Breakpoint exato de colapso sidebar → bottom nav — padrão Material 3 (600px).
- Estrutura de sub-diretórios dentro de `lib/core/` além dos definidos em D-05.

### Deferred Ideas (OUT OF SCOPE)

- Dark mode — pode ser adicionado pós-MVP sem breaking changes no Material 3 ThemeData.
- CanvasKit fixo ou WASM renderer — avaliar se performance exigir pós-MVP.
- Codegen com modelos na Phase 0 — adiado para Phase 1.

</user_constraints>

<phase_requirements>
## Phase Requirements

Phase 0 has **no requirement IDs** — it is pure infrastructure prerequisite to all subsequent phases. Mapped instead to ROADMAP.md success criteria:

| Success Criterion | Research Support |
|---|---|
| `flutter run -d chrome` renderiza app shell em <2s TTI 4G | Web renderer (D-11), Material 3 NavigationRail/NavigationBar adaptive pattern, font bundling guidance |
| Migrações SQL versionadas no git executam contra Supabase local sem erro | Supabase CLI local-dev workflow (init + start + migration new + db reset), Docker prerequisite |
| `currentPropertyProvider` (Riverpod) implementado e disponível em qualquer feature | Riverpod 2.x AsyncNotifier + code-gen pattern; provider scope em `lib/core/providers/` |
| GoRouter configurado com URLs deep-linkables, back button, guards permissivos | GoRouter StatefulShellRoute + redirect + auth Listenable pattern (placeholder em Phase 0) |
| Camada Repository/Service base implementada — sem importar Supabase SDK em features | Abstract Repository pattern (D-06), Supabase singleton em `lib/core/services/`, injeção via Riverpod |

**Coverage:** 5/5 success criteria têm research support direto.

</phase_requirements>

## Project Constraints (from CLAUDE.md)

Mandatory directives extracted from `./CLAUDE.md` — planner MUST verify compliance:

| Constraint | Source | Implication for Phase 0 |
|---|---|---|
| Stack: Flutter web-first + Supabase | Project §Constraints | Sem alternativas — locked |
| Riverpod (não BLoC, não Provider standalone, não GetX) | Stack §State management | flutter_riverpod no pubspec — não adicionar concorrentes |
| GoRouter (não auto_route) | Stack §Navigation | go_router no pubspec — não adicionar concorrentes |
| supabase_flutter sem dio | Stack §HTTP | Não adicionar dio nem retrofit |
| freezed + json_serializable (não dart_mappable) | Stack §Data classes | freezed_annotation + json_annotation no pubspec |
| flutter_secure_storage + shared_preferences (Hive/Isar proibidos no MVP) | Stack §Local storage | OK conforme D-09 |
| data_table_2 para tabelas web (não DataTable nativo) | Stack §UI | data_table_2 no pubspec |
| `intl` com locale `pt_BR` | Stack §Date/time | flutter_localizations + intl 0.20.x; locale fixo |
| pubspec versions HIGH confidence (verificar live) | Stack §Sources | Versões verificadas neste documento — ver Standard Stack |
| Não usar Realtime, Edge Functions, Storage no MVP | Stack §What NOT to Use | Phase 0 NÃO importa nem configura esses módulos |
| **Toda mudança de schema via `supabase/migrations/*.sql` + CLI** | Stack §Database | Phase 0 cria pasta migrations/ vazia; nenhuma SQL via Studio |
| **Não usar JWT custom claims para perfil** | Stack §What NOT to Use | Phase 0 não toca em auth claims (Phase 1) |
| GSD workflow obrigatório (não editar fora do GSD) | §GSD Workflow | Validado: estamos em GSD pipeline |
| RTK prefix em comandos | Global CLAUDE.md §RTK | Planner deve recomendar `rtk` para git/build/test commands em tasks |

## Summary

Phase 0 é o esqueleto da aplicação. Stack está totalmente decidido em CLAUDE.md e CONTEXT.md — esta pesquisa **não explora alternativas**, apenas verifica versões atuais, valida o caminho feliz de cada componente, e identifica armadilhas conhecidas para o planner traduzir em tasks defensivas.

Três achados críticos requerem atenção do planner:

1. **Riverpod 2.x está atrasado vs ecossistema.** flutter_riverpod 3.x foi lançado; user confirmou manter 2.x. Versões 2.x finais (estáveis há ~18 meses) precisam ser pinadas exatas no pubspec para evitar resolver para 3.x acidentalmente. Constraint correto: `flutter_riverpod: ">=2.6.1 <3.0.0"`.
2. **Supabase CLI não está instalado** na máquina (verificado: `where supabase` falha). Plan deve incluir uma task de pré-requisito guiando o user no `scoop install supabase` ANTES das tasks de inicialização.
3. **Chrome não está disponível** como dispositivo Flutter (apenas Edge). Critério de sucesso ROADMAP.md menciona `flutter run -d chrome`. Plan deve usar `flutter run -d edge` ou guiar instalação do Chrome — não é blocker técnico mas afeta o smoke test final.

**Primary recommendation:** Plan em 5 ondas claras: (1) ambiente externo/pubspec, (2) Supabase local, (3) core scaffolding (theme, router, services, providers), (4) shell adaptive (NavigationRail ↔ NavigationBar com 600px breakpoint), (5) smoke tests + verificação. Wave 0 cria infraestrutura de testes desde já.

## Standard Stack

Todas as versões abaixo foram **verificadas em pub.dev em 2026-04-26**.

### Core (verificado)

| Library | Versão Recomendada | Última (2026-04-26) | Constraint pubspec | Por quê |
|---|---|---|---|---|
| flutter SDK | 3.41.6 (stable) | 3.41.6 | `>=3.24.0 <4.0.0` | Já instalado no host; Riverpod/GoRouter modernos exigem ≥3.24 [VERIFIED: `flutter --version`] |
| Dart SDK | 3.11.4 | 3.11.4 | `^3.11.4` (já em pubspec) | Versão do Flutter 3.41.6 [VERIFIED: pubspec.yaml] |
| flutter_riverpod | **2.6.1** (LOCKED 2.x) | 3.3.1 | `^2.6.1` | User confirmou manter 2.x; última 2.x estável publicada há 18 meses [VERIFIED: pub.dev/packages/flutter_riverpod] |
| riverpod_annotation | **2.6.1** (LOCKED 2.x) | 3.x | `^2.6.1` | Pareada com flutter_riverpod 2.6.1 [VERIFIED: pub.dev/packages/riverpod_annotation] |
| go_router | 17.2.2 | 17.2.2 | `^17.2.0` | Última estável; CLAUDE.md diz `^14.2.0` (defasado) — atualizar para 17.x na fase [VERIFIED: pub.dev/packages/go_router] |
| supabase_flutter | 2.12.4 | 2.12.4 | `^2.12.0` | v2.x estável; v1 quebrou em várias APIs (auth, query) — pinar major 2 [VERIFIED: pub.dev/packages/supabase_flutter] |
| freezed_annotation | 3.x compatível | (linked w/ freezed 3.2.5) | `^3.0.0` | Freezed migrou para 3.x em fev/2025 (breaking changes); CLAUDE.md cita 2.4.4 (defasado) — alinhar para 3.x [VERIFIED: pub.dev/packages/freezed] |
| json_annotation | 4.11.0 | 4.11.0 | `^4.11.0` | Última estável [VERIFIED: pub.dev/packages/json_annotation] |
| flutter_secure_storage | 10.0.0 | 10.0.0 | `^10.0.0` | CLAUDE.md cita 9.2.2 (defasado); 10.x é a corrente [VERIFIED: pub.dev/packages/flutter_secure_storage] |
| shared_preferences | 2.5.5 | 2.5.5 | `^2.5.0` | Estável [VERIFIED: pub.dev/packages/shared_preferences] |
| flutter_svg | 2.2.4 | 2.2.4 | `^2.2.0` | Estável [VERIFIED: pub.dev/packages/flutter_svg] |
| intl | 0.20.2 | 0.20.2 | `^0.20.0` | CLAUDE.md cita 0.19.0 — atualizar; estável há 15 meses [VERIFIED: pub.dev/packages/intl] |
| data_table_2 | 2.7.2 | 2.7.2 | `^2.7.0` | Phase 0 não usa, mas instalar conforme D-09 [VERIFIED: pub.dev/packages/data_table_2] |
| flutter_localizations | (SDK) | (SDK) | `sdk: flutter` | Necessário para pt_BR [CITED: docs.flutter.dev] |

### Dev dependencies (verificado)

| Library | Versão | Constraint pubspec | Por quê |
|---|---|---|---|
| build_runner | 2.14.1 | `^2.14.0` | Última estável; codegen runner [VERIFIED: pub.dev/packages/build_runner] |
| freezed | 3.2.5 | `^3.2.0` | Última 3.x; pareado com freezed_annotation 3.x [VERIFIED: pub.dev/packages/freezed] |
| json_serializable | 6.13.1 | `^6.13.0` | Última; pareado com json_annotation 4.11 [VERIFIED: pub.dev/packages/json_serializable] |
| riverpod_generator | **2.6.5** (LOCKED 2.x) | `^2.6.5` | Pareado com riverpod_annotation 2.6.x [VERIFIED: pub.dev/packages/riverpod_generator] |
| custom_lint | (latest) | `^0.6.0` | Necessário para `riverpod_lint` funcionar [CITED: riverpod docs] |
| riverpod_lint | (latest) | `^2.3.0` | Lints específicos do Riverpod [CITED: riverpod docs] |
| flutter_lints | 6.0.0 | `^6.0.0` (já em pubspec) | OK; manter [VERIFIED: pubspec.yaml + pub.dev] |
| mocktail | 1.0.5 | `^1.0.0` | Mocking para testes [VERIFIED: pub.dev/packages/mocktail] |
| flutter_test | (SDK) | `sdk: flutter` | Já em pubspec |
| integration_test | (SDK) | `sdk: flutter` | Para smoke tests E2E (Phase 0 sucesso #1) |

### Externos ao pubspec (host)

| Tool | Versão Recomendada | Status na máquina | Como instalar |
|---|---|---|---|
| Docker Desktop | qualquer 24+ | **✓ instalado (29.4.0)** [VERIFIED: `docker --version`] | — |
| Supabase CLI | última | **✗ NÃO instalado** [VERIFIED: `where supabase` falha] | `scoop install supabase` (Windows) [CITED: supabase.com/docs/guides/cli] |
| Chrome | qualquer | **✗ NÃO detectado por Flutter** [VERIFIED: `flutter devices`] | Edge disponível como fallback |
| Scoop | latest | (verificar antes de instalar Supabase) | PowerShell: `Invoke-RestMethod -Uri https://get.scoop.sh \| Invoke-Expression` [CITED: scoop.sh] |

### Alternativas Consideradas (rejeitadas — locked)

| Em vez de | Poderia usar | Por que NÃO |
|---|---|---|
| flutter_riverpod 2.x | flutter_riverpod 3.x | User locked 2.x; CLAUDE.md também especifica 2.x. Ecosystem ainda compatível com 2.6.1; upgrade pode esperar pós-MVP. |
| GoRouter | auto_route | CLAUDE.md veta auto_route para web-first. |
| supabase_flutter | supabase + dio | CLAUDE.md veta dio quando supabase_flutter já gerencia HTTP. |
| dart-define | flutter_dotenv | D-08 locked; .env files não no git, dart-define é nativo do Flutter. |
| StatefulShellRoute (GoRouter) | IndexedStack manual | CONTEXT.md D-03 locked StatefulShellRoute. |

### Comandos de instalação

```bash
# 1. Pré-requisito do host (uma vez por máquina)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# 2. Atualizar pubspec.yaml manualmente (ver Standard Stack table acima), depois:
rtk flutter pub get

# 3. Verificar codegen pipeline (sem gerar nada de domínio em Phase 0)
rtk dart run build_runner build --delete-conflicting-outputs
```

## Architecture Patterns

### Estrutura de pastas (D-05)

```
lib/
├── core/
│   ├── providers/          # Providers globais (currentPropertyProvider, supabaseClientProvider)
│   ├── widgets/            # Widgets reutilizáveis (AppShell, PropertySelector placeholder)
│   ├── services/           # SupabaseClient singleton, base service abstractions
│   ├── router/             # router.dart (GoRouter config), routes.dart (path constants), guards.dart
│   ├── theme/              # app_theme.dart (Material 3 + seedColor verde-musgo)
│   └── env/                # env.dart (lê dart-define, valida em main)
├── features/
│   ├── dashboard/presentation/dashboard_screen.dart      # placeholder
│   ├── piquetes/presentation/piquetes_screen.dart        # placeholder
│   ├── animais/presentation/animais_screen.dart          # placeholder
│   ├── reproducao/presentation/reproducao_screen.dart    # placeholder
│   └── sanitario/presentation/sanitario_screen.dart      # placeholder
└── main.dart                                             # bootstrap

supabase/
├── config.toml             # gerado por `supabase init`
├── migrations/             # vazio em Phase 0; primeira migração em Phase 1
└── seed.sql                # vazio em Phase 0

test/
├── core/
│   ├── router_test.dart    # Wave 0: smoke test do GoRouter
│   └── theme_test.dart     # Wave 0: smoke test do ThemeData
└── widget/
    └── app_shell_test.dart # Wave 0: AppShell renderiza em ambos breakpoints

integration_test/
└── app_smoke_test.dart     # Wave 0: app inicia sem crash

.vscode/
└── launch.json             # NÃO commitado (.gitignore); contém SUPABASE_URL/ANON_KEY
```

**Sub-diretórios `core/env/` e `core/router/guards.dart`** são minhas escolhas dentro da discretion (D-05 lista apenas o nível superior).

### Pattern 1: Supabase singleton via Riverpod provider

**What:** Um único `Supabase.instance.client` exposto por um provider — features dependem do provider, não do SDK.

**When to use:** TODOS os repositories e screens que precisam tocar Supabase.

**Example:**
```dart
// lib/core/services/supabase_service.dart
// Source: supabase.com/docs/reference/dart/initializing
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;
}

// lib/core/providers/supabase_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/supabase_service.dart';

part 'supabase_providers.g.dart';

@Riverpod(keepAlive: true)
SupabaseService supabaseService(SupabaseServiceRef ref) => SupabaseService();
```

**Inicialização em main.dart:**
```dart
// Source: supabase.com/docs/reference/dart/initializing
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lê dart-define
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError('SUPABASE_URL e SUPABASE_ANON_KEY devem ser passados via --dart-define');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: CampoGestorApp()));
}
```

### Pattern 2: Abstract Repository (D-06)

**What:** Interface Dart abstrata em `data/`, implementação concreta separada com sufixo `Supabase`.

**When to use:** Toda entidade de domínio (a partir de Phase 1). Phase 0 estabelece o template SEM uma implementação real (placeholder).

**Example template (será exercitado em Phase 1):**
```dart
// lib/features/_template_/data/example_repository.dart
abstract class ExampleRepository {
  Future<Example?> findById(String id);
  Future<List<Example>> listByProperty(String propertyId);
  Future<Example> create(Example value);
}

// lib/features/_template_/data/supabase_example_repository.dart
class SupabaseExampleRepository implements ExampleRepository {
  SupabaseExampleRepository(this._service);
  final SupabaseService _service;

  @override
  Future<Example?> findById(String id) async {
    final row = await _service.client
        .from('examples')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Example.fromJson(row);
  }
  // ...
}
```

**Phase 0 nota:** NÃO criar `_template_/`. O pattern é documentado aqui para o planner referenciar; Phase 1 cria o primeiro repo real (Property).

### Pattern 3: GoRouter + StatefulShellRoute + auth Listenable

**What:** Router único com 5 branches (uma por feature top-level), StatefulNavigationShell injeta `currentIndex`/`goBranch` para AppShell trocar entre seções preservando estado.

**When to use:** Estrutura de navegação principal do app.

**Example:**
```dart
// lib/core/router/router.dart
// Source: pub.dev/documentation/go_router/latest + apparencekit.dev/blog
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellDashboardKey = GlobalKey<NavigatorState>();
// ... outras 4 keys

@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/dashboard',
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      // Phase 0: permissivo — sempre retorna null.
      // Phase 1 substitui por checagem real de sessão.
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellDashboardKey,
            routes: [GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen())],
          ),
          // ... 4 outros branches
        ],
      ),
    ],
  );
}

// Helper para converter Stream em Listenable (não vem com GoRouter por default)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
      onError: (_) {},  // OBRIGATÓRIO — supabase emite erros como stream errors
    );
  }
  late final StreamSubscription<dynamic> _subscription;
  @override void dispose() { _subscription.cancel(); super.dispose(); }
}
```

**Crítico:** `onError` no `.listen()` é OBRIGATÓRIO — supabase docs alertam que sem ele a app crasha em token refresh com rede instável.

### Pattern 4: Adaptive AppShell — NavigationRail (web) ↔ NavigationBar (mobile)

**What:** Um widget AppShell que decide entre NavigationRail e NavigationBar via LayoutBuilder, padrão Material 3.

**When to use:** Único shell para todas as 5 telas top-level.

**Breakpoint:** **600px** (Material 3 standard). [CITED: m3.material.io/foundations/layout/applying-layout]

**Example:**
```dart
// lib/core/widgets/app_shell.dart
// Source: api.flutter.dev/flutter/material/NavigationRail-class.html
//       + m3.material.io/components/navigation-rail/guidelines
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Scaffold(
          appBar: AppBar(
            title: const _PropertySelector(),  // consome currentPropertyProvider
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: navigationShell.goBranch,
                      labelType: NavigationRailLabelType.all,
                      destinations: _railDestinations,
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: navigationShell.goBranch,
                  destinations: _barDestinations,
                ),
        );
      },
    );
  }
}
```

### Pattern 5: `currentPropertyProvider` placeholder (D-04)

**What:** AsyncNotifier que expõe `Property?`, retorna `null` em Phase 0; Phase 1 substitui body por query real.

**Example:**
```dart
// lib/core/providers/current_property_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_property_provider.g.dart';

// Placeholder sealed class — Phase 1 substitui por modelo freezed real
class Property {
  const Property({required this.id, required this.nome});
  final String id;
  final String nome;
}

@Riverpod(keepAlive: true)
class CurrentProperty extends _$CurrentProperty {
  @override
  Future<Property?> build() async {
    // Phase 0: sempre null. Phase 1 lê de property_members + selecionada.
    return null;
  }

  Future<void> selectProperty(Property property) async {
    state = AsyncData(property);
  }
}
```

### Pattern 6: Theme Material 3 com seedColor verde-musgo (D-12)

**What:** Single `ThemeData` com `ColorScheme.fromSeed`. Verde-musgo escolhido: **#4A6741** (sage/moss green — discretion).

**Example:**
```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF4A6741);  // verde-musgo (discretion)

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        // Dark mode deferred (CONTEXT.md)
      );
}
```

### Anti-Patterns to Avoid

- **Importar `package:supabase_flutter/supabase_flutter.dart` em features/** — viola D-06. Lint check no PR.
- **`flutter run --web-renderer html`** — HTML renderer foi descontinuado em 2024 [CITED: groups.google.com/g/flutter-announce]; usar default canvaskit (D-11).
- **Schema changes via Supabase Studio** — CLAUDE.md proíbe; sempre `supabase migration new <name>`.
- **JWT custom claims para perfil** — CLAUDE.md proíbe (stale-until-refresh problem).
- **Hardcoded SUPABASE_URL/ANON_KEY** — D-08 exige dart-define; lint manual no review.
- **Realtime/Edge Functions/Storage no MVP** — CLAUDE.md proíbe; não importar mesmo que disponível no SDK.
- **`flutter pub upgrade --major-versions` sem revisão** — pode promover Riverpod para 3.x; sempre revisar pubspec.lock após mudanças.
- **`google_fonts` package** — CLAUDE.md veta no web (runtime fetch hurts first paint); Phase 0 usa font padrão Material 3 (Roboto bundled).

## Don't Hand-Roll

| Problema | Não construir | Usar | Por quê |
|---|---|---|---|
| Conversão Stream→Listenable para GoRouter `refreshListenable` | RxDart adapter custom | `ChangeNotifier` wrapper de 12 linhas (ver Pattern 3) | Pattern canônico, zero deps extras |
| Singleton de SupabaseClient | `static SupabaseClient _instance` manual | `Supabase.instance.client` (já é singleton) | SDK já gerencia |
| Persistência de sessão Supabase | shared_preferences manual | Default do supabase_flutter | SDK persiste em `flutter_secure_storage` (mobile) e `SharedPreferences` (web) automaticamente quando inicializado |
| Layout responsivo NavigationRail/NavigationBar | Custom adaptive widget | `LayoutBuilder` + Material 3 widgets nativos | M3 widgets são oficial; built-in pattern |
| Validação de env vars no startup | Reflection / scripts externos | `String.fromEnvironment` + `if(empty) throw StateError` em main | dart-define resolve em compile-time |
| Codegen runner | Script bash custom | `dart run build_runner build --delete-conflicting-outputs` | Comando oficial; flag resolve conflitos comuns |

**Key insight:** Phase 0 é puro plumbing — toda a "lógica" não-trivial está nos pacotes. Custom code total esperado: <500 LoC.

## Runtime State Inventory

> Phase 0 é greenfield (não há rename/refactor). Categoria-by-categoria:

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | None — projeto novo, sem dados | — |
| Live service config | None — sem Supabase project remoto ainda; CLI local cria isolado | — |
| OS-registered state | None — sem launchd/Task Scheduler/pm2 | — |
| Secrets/env vars | `SUPABASE_URL`, `SUPABASE_ANON_KEY` (D-08) — gravados em `.vscode/launch.json` (gitignored) | Documentar em `.vscode/launch.json.example` (commitado) com placeholders |
| Build artifacts | `build/`, `.dart_tool/`, `*.g.dart` (codegen) | `.gitignore` deve cobrir todos. Pubspec do template Flutter já gera `.gitignore` com `build/`, `.dart_tool/`. Adicionar `*.g.dart`, `*.freezed.dart` é opcional (alguns projetos commitam codegen) — recomendação: NÃO commitar codegen, sempre regenerar (build_runner é rápido) |

## Common Pitfalls

### Pitfall 1: `flutter_riverpod` resolvendo para 3.x acidentalmente
**What goes wrong:** Constraint frouxo (`^2.5.0`) permite resolver para 3.x se outro package puxar; APIs quebram silenciosamente em runtime.
**Why:** flutter_riverpod 3.x está disponível desde ~mar/2026; resolver pode escolher major superior.
**How to avoid:** Constraint EXATO de major: `flutter_riverpod: ">=2.6.1 <3.0.0"`. Mesmo para riverpod_annotation e riverpod_generator. Adicionar comentário no pubspec.yaml.
**Warning signs:** `flutter pub get` mostra "resolved to 3.x.x"; `Notifier` API muda assinatura.

### Pitfall 2: Supabase token refresh crashando app
**What goes wrong:** App crasha em background quando rede instável; stack trace aponta para zone exception.
**Why:** `Supabase.instance.client.auth.onAuthStateChange.listen(...)` sem `onError` rethrow do erro de rede no zone.
**How to avoid:** SEMPRE passar `onError: (_, __) {}` (ou logger) em qualquer `.listen()` no stream de auth. Já no `GoRouterRefreshStream` em Pattern 3.
**Warning signs:** "Unhandled exception" em logs; crash em re-conexão wifi.

### Pitfall 3: `supabase init` sem Docker rodando
**What goes wrong:** `supabase start` falha com "Cannot connect to the Docker daemon".
**Why:** Docker Desktop precisa estar **rodando** (não só instalado).
**How to avoid:** Task de pré-requisito guia user a abrir Docker Desktop antes de `supabase start`. Verificação: `docker info` deve retornar sem erro.
**Warning signs:** Erro acima; `docker ps` falha.

### Pitfall 4: dart-define values não persistem entre `flutter run` e `flutter test`
**What goes wrong:** Smoke test passa, mas `flutter run` falha por env vazio (ou vice-versa).
**Why:** `--dart-define` é por comando; `flutter test` precisa do mesmo flag.
**How to avoid:** Documentar em README e em `.vscode/launch.json.example` os comandos com flags. Para testes que precisam de Supabase, fornecer defaults via `String.fromEnvironment(... , defaultValue: 'http://localhost:54321')` apontando para Supabase CLI local.
**Warning signs:** `StateError: SUPABASE_URL deve ser passado` em runtime.

### Pitfall 5: Codegen quebrando em primeira execução por conflitos
**What goes wrong:** `dart run build_runner build` falha com "conflicting outputs".
**Why:** Builds anteriores deixaram `.g.dart` órfãos.
**How to avoid:** Sempre usar `--delete-conflicting-outputs` em desenvolvimento. Em CI, usar `dart run build_runner build` (sem flag) para detectar inconsistências reais.
**Warning signs:** Erro "Found N declared outputs which already exist on disk".

### Pitfall 6: Material 3 NavigationRail sem destinations gera erro de assert
**What goes wrong:** `NavigationRail` requer ≥2 destinations; com 1 (placeholder) crasha.
**Why:** Material 3 assert.
**How to avoid:** Phase 0 já tem 5 destinations (D-02), então OK. Caso planner divida em waves onde shell aparece com 1 destination temporariamente, usar `NavigationDrawer` ou Container vazio até completar.
**Warning signs:** Assert em Scaffold paint.

### Pitfall 7: GoRouter web URL paths usando `#` (hash routing)
**What goes wrong:** URLs viram `app.com/#/dashboard` em vez de `app.com/dashboard`; backlinks compartilhados quebram.
**Why:** Default web do Flutter é hash routing (`UrlStrategy`).
**How to avoid:** Em `main.dart`, ANTES de `runApp`, chamar `usePathUrlStrategy()` (export do `package:flutter_web_plugins/url_strategy.dart`).
**Warning signs:** URL no browser mostra `#/`.

### Pitfall 8: pt-BR sem `flutter_localizations` causa erros de DatePicker
**What goes wrong:** Material widgets de data renderizam em inglês; `Locale('pt', 'BR')` ignorado.
**Why:** `flutter_localizations` SDK package precisa estar no pubspec E `localizationsDelegates` declarado em MaterialApp.
**How to avoid:**
```dart
MaterialApp.router(
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('pt', 'BR')],
  locale: const Locale('pt', 'BR'),
  ...
);
```
**Warning signs:** DatePicker em inglês; `Intl.defaultLocale` vazio.

## Code Examples

Ver Patterns 1-6 acima — todos com source URLs.

Exemplo adicional: **Path URL strategy + locale + router** em main.dart completo:

```dart
// lib/main.dart
// Source: api.flutter.dev + supabase.com/docs
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers/router_provider.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || key.isEmpty) {
    throw StateError(
      'SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórios. '
      'Use --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  await Supabase.initialize(url: url, anonKey: key);

  runApp(const ProviderScope(child: CampoGestorApp()));
}

class CampoGestorApp extends ConsumerWidget {
  const CampoGestorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Campo Gestor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `--web-renderer auto` (HTML on mobile, CanvasKit on desktop) | Default = canvaskit (HTML deprecated) | Flutter 3.27 (~2024-Q4) | D-11 ainda fala "auto" — efeito prático é o mesmo (não passar `--web-renderer`) [CITED: groups.google.com/g/flutter-announce] |
| supabase_flutter v1 (`signInWithOAuth(context)`, mutable queries, `Provider` enum) | supabase_flutter v2 (PKCE default, immutable queries, `OAuthProvider` enum) | Out/2023 (v2 release) | Tutoriais antigos vão quebrar; CLAUDE.md já reflete v2 [CITED: supabase.com/docs/reference/dart/upgrade-guide] |
| flutter_riverpod 2.x (`Notifier` + `@riverpod`) | flutter_riverpod 3.x (refactor de internals, `Notifier` API revisada) | Mar/2026 | User locked 2.x — não usar 3.x até pós-MVP |
| freezed 2.x (`@freezed` com factory constructors) | freezed 3.x (sealed classes nativas Dart 3, `@Freezed()` config) | Fev/2025 | CLAUDE.md cita 2.4.4 — atualizar para 3.x na fase; migration guide existe [CITED: github.com/rrousselGit/freezed migration guide] |
| HTML web renderer | Removido | 2024-2025 | Ninguém deve passar `--web-renderer html` |

**Deprecated/outdated:**
- HTML renderer (use default canvaskit)
- supabase_flutter v1 patterns
- freezed 2.x syntax (mas freezed 3.x ainda aceita 2.x syntax — migrar gradualmente)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Flutter SDK | Tudo | ✓ | 3.41.6 stable | — |
| Dart SDK | Tudo | ✓ | 3.11.4 (vem com Flutter) | — |
| Docker Desktop | `supabase start` | ✓ | 29.4.0 | Sem fallback — Supabase Cloud exige internet e não atende D-07 |
| Supabase CLI | `supabase init/start/migration` | **✗** | — | **BLOCKER** — task de pré-requisito instala via scoop |
| Scoop | Instalar Supabase CLI no Windows | desconhecido (verificar antes) | — | Fallback: download manual do binário do GitHub releases |
| Chrome | `flutter run -d chrome` (success criterion #1) | **✗** detectado | — | Edge disponível como fallback (também Chromium-based, equivalente para smoke test) |
| Edge | Fallback para web smoke test | ✓ | 147.0.3912.72 | — |
| Windows desktop | Build target alternativo | ✓ | Win 10.0.26200 | — |

**Missing dependencies with no fallback:**
- Supabase CLI (blocker para success criterion #2). Plan deve incluir task explícita de instalação como pré-requisito.

**Missing dependencies with fallback:**
- Chrome → usar Edge para smoke test (D-11 default canvaskit funciona em ambos). Documentar nas instruções.

## Validation Architecture

`workflow.nyquist_validation: true` confirmado em `.planning/config.json`. Esta seção é mandatória.

### Test Framework

| Property | Value |
|---|---|
| Framework | `flutter_test` (SDK) + `mocktail ^1.0.5` para mocks |
| E2E Framework | `integration_test` (SDK) — para success criterion #1 |
| Config file | `analysis_options.yaml` (já existe), `test/` directory (a criar — Wave 0) |
| Quick run command | `rtk flutter test --no-pub` |
| Full suite command | `rtk flutter test && rtk flutter analyze` |
| Smoke test (web) | `flutter test integration_test/app_smoke_test.dart -d edge --dart-define=SUPABASE_URL=http://localhost:54321 --dart-define=SUPABASE_ANON_KEY=<local-key>` |

### Phase Requirements → Test Map

Phase 0 não tem REQ IDs; mapeamento é por success criterion (SC) do ROADMAP.md.

| SC | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| SC-1 | App shell renderiza em <2s TTI | manual + smoke | `flutter run -d edge --profile` (manual TTI measurement); `flutter test integration_test/app_smoke_test.dart` (automated boot) | ❌ Wave 0 |
| SC-2 | Migrações SQL executam contra Supabase local sem erro | integration (shell) | `supabase db reset` em CI — exit code 0 | ❌ Wave 0 (script `scripts/verify_supabase.sh`) |
| SC-3 | `currentPropertyProvider` disponível em qualquer feature | unit | `pytest tests/test_module.py` — *N/A: usar* `flutter test test/core/current_property_provider_test.dart` | ❌ Wave 0 |
| SC-4 | GoRouter URLs deep-linkables, back button | widget | `flutter test test/core/router_test.dart` — verifica path strategy + 5 routes navegáveis | ❌ Wave 0 |
| SC-5 | Repository layer existe; features não importam Supabase SDK | static (lint + script) | `grep -r "package:supabase_flutter" lib/features/` deve retornar vazio (script bash em `scripts/verify_no_supabase_in_features.sh`) | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `rtk flutter analyze && rtk flutter test --no-pub` (<30s na maioria dos commits)
- **Per wave merge:** `rtk flutter test && rtk flutter analyze && bash scripts/verify_no_supabase_in_features.sh`
- **Phase gate:** Suite completa + smoke integration test + `supabase db reset` verde antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/core/router_test.dart` — cover SC-4
- [ ] `test/core/theme_test.dart` — smoke test ThemeData carrega
- [ ] `test/core/current_property_provider_test.dart` — cover SC-3 (provider retorna null em estado inicial)
- [ ] `test/widget/app_shell_test.dart` — AppShell renderiza em ambos breakpoints (golden ou layout assertions)
- [ ] `integration_test/app_smoke_test.dart` — cover SC-1 (boot end-to-end sem crash)
- [ ] `scripts/verify_no_supabase_in_features.sh` — cover SC-5 (lint custom)
- [ ] `scripts/verify_supabase.sh` — cover SC-2 (`supabase db reset` em ambiente local)
- [ ] Adicionar `mocktail`, `integration_test` ao pubspec dev_dependencies (não estavam)
- [ ] Garantir que `flutter_test` test runner consegue executar com dart-define (criar `test/test_helper.dart` com defaults para Supabase local)

## Security Domain

`security_enforcement` não setado em config (default = enabled). Phase 0 é infraestrutura — a maioria dos controles AppSec virá em Phase 1+. O que se aplica AGORA:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | NÃO em Phase 0 | Phase 1: supabase_flutter Auth com PKCE (default em v2) |
| V3 Session Management | NÃO em Phase 0 | Phase 1: supabase_flutter persiste em flutter_secure_storage (mobile) / SharedPreferences (web) |
| V4 Access Control | NÃO em Phase 0 | Phase 1+: RLS em Supabase Postgres |
| V5 Input Validation | NÃO em Phase 0 (sem inputs) | Phase 1+: `reactive_forms` validators + RPC server-side checks |
| V6 Cryptography | parcial | dart-define para secrets em dev (não criptografado, mas fora de git via launch.json gitignored) |
| V7 Error Handling | yes | `onError` obrigatório em todos `.listen()` (Pitfall 2); StateError explícito em main para env vazio |
| V14 Configuration | yes | `.gitignore` deve cobrir `.vscode/launch.json`, `build/`, `.dart_tool/`, `supabase/.env`; `supabase/config.toml` é seguro commitar; chaves anon de DEV são públicas por design (RLS protege) |

### Known Threat Patterns para Flutter web + Supabase

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Anon key vazada em bundle JS | Information Disclosure | OK por design — anon key é pública; segurança real está no RLS (Phase 1+). Service role key NUNCA vai no app. |
| Schema changes via Studio causam dev/prod drift | Tampering | CLAUDE.md proíbe; só CLI migrations |
| Hardcoded secrets em commits | Information Disclosure | dart-define + `.vscode/launch.json` no `.gitignore`; criar `.vscode/launch.json.example` como template commitável |
| Token refresh silencioso falhando crasha app | Denial of Service | `onError` em todos `.listen()` (Pitfall 2) |
| URL hash routing expondo state em fragmento | Information Disclosure | `usePathUrlStrategy()` em main (Pitfall 7) |
| HTML renderer com text rendering bugs / XSS surface | Tampering | HTML renderer já deprecated; usar canvaskit default |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Verde-musgo `#4A6741` é uma escolha aceitável dentro da paleta agrária (D-12 Claude's Discretion) | Pattern 6 | Estética — user pode pedir tweaking; baixo risco |
| A2 | Plan vai usar Edge como fallback de Chrome (Chrome não detectado) | Environment Availability | Smoke test usa engine equivalente (Chromium); zero risco técnico |
| A3 | Não commitar `*.g.dart` / `*.freezed.dart` (regenerar localmente) | Runtime State Inventory | Trade-off: commits mais limpos vs CI ligeiramente mais longo. Comum em projetos Flutter |
| A4 | freezed 3.x é o caminho; CLAUDE.md cita 2.4.4 mas a indústria já está em 3.x | Standard Stack | Migration guide existe; freezed 3.x aceita maior parte da syntax 2.x. Baixo risco |
| A5 | `riverpod_lint` + `custom_lint` são valor adicional para projeto novo | Standard Stack dev deps | Sem risco — só lints, não muda runtime |
| A6 | Scoop já está instalado no host OU user instala via PowerShell snippet | Environment Availability | Se não estiver, task de pré-requisito guia. Mitigação documentada |
| A7 | Locale `Locale('pt', 'BR')` (não `pt_BR` string) é a forma correta para Flutter Material widgets | Pitfall 8 | Standard pattern do Flutter desde 3.x — conferido em docs |
| A8 | App responde em mobile com NavigationBar (não BottomNavigationBar legacy) — Material 3 | Pattern 4 | NavigationBar é o widget M3; BottomNavigationBar é Material 2. M3 está em useMaterial3:true |
| A9 | Supabase CLI scoop install funciona sem reboot | Environment Availability | Provedor oficial; raramente quebra |

**Total assumptions:** 9. Nenhuma é compliance/security crítica; A1, A3, A4 são as mais relevantes para `gsd-discuss-phase` confirmar com user antes do planner solidificar.

## Open Questions

1. **Pre-requirement install: Scoop está instalado?**
   - What we know: Docker está; Supabase CLI não está; Scoop status desconhecido.
   - What's unclear: Se user já tem Scoop, comando muda.
   - Recommendation: Plan inclui task condicional ou step com check `where scoop` antes de tentar `scoop bucket add`.

2. **`.vscode/launch.json.example` template — quais ENVs documentar?**
   - What we know: SUPABASE_URL, SUPABASE_ANON_KEY são obrigatórios.
   - What's unclear: Phase 0 precisa de outras (ex: SUPABASE_SERVICE_ROLE_KEY para testes futuros)? Provável que NÃO em Phase 0.
   - Recommendation: Apenas as duas. Phase futura adiciona se necessário.

3. **Smoke test integration_test em Edge funciona out-of-box no Windows?**
   - What we know: `flutter test integration_test/ -d edge` é suportado em teoria.
   - What's unclear: Comportamento real em Windows — Microsoft Edge driver setup.
   - Recommendation: Plan tem fallback: se driver falhar, smoke test roda em Windows desktop target (`-d windows`) que valida boot/router/theme sem chrome-specifics.

4. **freezed 2.x → 3.x: CLAUDE.md está oficialmente desatualizado?**
   - What we know: Versão atual da indústria é 3.2.5; CLAUDE.md ainda cita 2.4.4.
   - What's unclear: Se atualizar CLAUDE.md como parte de Phase 0 ou deixar para depois.
   - Recommendation: Plan inclui task pequena de atualizar versões em CLAUDE.md (sem mudar arquitetura) para evitar drift.

## Sources

### Primary (HIGH confidence)
- `pub.dev/packages/flutter_riverpod` (versions tab) — confirmou 2.6.1 como última 2.x
- `pub.dev/packages/supabase_flutter` — 2.12.4 atual
- `pub.dev/packages/go_router` — 17.2.2 atual
- `pub.dev/packages/freezed` (versions tab) — 3.2.5 atual; 2.5.8 última 2.x
- `pub.dev/packages/build_runner` — 2.14.1 atual
- `pub.dev/packages/json_serializable`, `json_annotation`, `intl`, `flutter_secure_storage`, `shared_preferences`, `flutter_svg`, `data_table_2`, `mocktail`, `flutter_lints`, `riverpod_generator`, `riverpod_annotation` — todos verificados
- `supabase.com/docs/reference/dart/initializing` — pattern oficial Supabase init
- `supabase.com/docs/reference/dart/auth-onauthstatechange` — `onError` obrigatório, AuthChangeEvent enum
- `supabase.com/docs/reference/dart/upgrade-guide` — breaking changes v1→v2
- `supabase.com/docs/guides/cli/getting-started` — scoop install + supabase init/start workflow
- `pub.dev/documentation/go_router/latest/topics/Configuration-topic.html` — StatefulShellRoute pattern
- `api.flutter.dev/flutter/material/NavigationRail-class.html` — NavigationRail Material 3
- `m3.material.io/components/navigation-rail/guidelines` — 600px breakpoint canônico
- `riverpod.dev/docs/concepts/about_code_generation` — `@riverpod` annotation, AsyncNotifier pattern
- `docs.flutter.dev/perf/web-performance` — profile mode, TTI debugging
- Local commands: `flutter --version`, `flutter devices`, `docker --version`, `where supabase`

### Secondary (MEDIUM confidence)
- WebSearch: "supabase_flutter v2 GoRouter authStateChanges redirect refreshListenable" — pattern descrito em múltiplas fontes (apparencekit.dev, flutter github issues)
- WebSearch: "Flutter Material 3 NavigationRail responsive breakpoint 600px 2026" — Material guidelines + codelabs confirmam 600px
- `dev.to/chiragx309/how-to-install-supabase-cli-on-windows` — confirma scoop como recommended path em 2026

### Tertiary (LOW confidence)
- Estética do verde-musgo `#4A6741` — escolha pessoal dentro da discretion; sem fonte autoritativa

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — todas versões verificadas em pub.dev em 2026-04-26
- Architecture: HIGH — patterns canônicos do ecossistema, não invenção
- Pitfalls: HIGH — derivados de docs oficiais e issues conhecidos
- Environment: HIGH — verificado por inspeção real do host
- Validation: MEDIUM — Wave 0 gaps identificados; smoke test em Edge com integration_test pode ter rugas em Windows (Open Question 3)
- Security: HIGH — Phase 0 superfície limitada, controles bem mapeados

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (estimativa 30 dias — Riverpod 3.x evoluindo rápido; revisar versions antes de Phase 1 se gap >2 semanas)
