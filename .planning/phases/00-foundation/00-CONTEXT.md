# Phase 0: Foundation - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Infraestrutura pura: Flutter scaffold completo com AppShell, Supabase inicializado (CLI local + Docker), state management skeleton (Riverpod + GoRouter), e camada de Repository base. Nenhuma feature de domínio — apenas o container que as próximas 8 fases preenchem.

</domain>

<decisions>
## Implementation Decisions

### App Shell Layout
- **D-01:** Web usa **sidebar fixo** (sempre visível, ícone + label). NavigationRail ou Drawer expandido.
- **D-02:** Itens de navegação top-level: Dashboard, Piquetes, Animais, Reprod., Sanitário — 5 items com placeholder screens vazias.
- **D-03:** Mobile colapsa para **Bottom NavigationBar** (tabs na parte inferior). GoRouter + StatefulShellRoute gerencia estado por tab.
- **D-04:** Header/AppBar mostra **nome da propriedade ativa + seletor** (dropdown para trocar propriedade). `currentPropertyProvider` alimenta o header desde o início — placeholder retorna null até Phase 1 preencher.

### Folder Structure
- **D-05:** Organização **feature-first hybrid**:
  ```
  lib/
    core/
      providers/     # Riverpod providers compartilhados
      widgets/       # widgets reutilizáveis
      services/      # SupabaseClient singleton, base service
      router/        # GoRouter config
      theme/         # Material 3 theme
    features/
      {feature}/
        data/        # repository impl (SupabaseXxxRepository)
        domain/      # modelos freezed (Phase 1+)
        presentation/ # screens + providers locais
  ```
- **D-06:** Padrão de acesso ao Supabase: **Abstract Repository + Supabase impl**. Interface Dart abstrata (ex: `abstract class AnimalRepository`) + implementação concreta (`SupabaseAnimalRepository`). Features dependem da interface — nunca importam `supabase_flutter` diretamente. Testabilidade via `mocktail`.

### Supabase Setup
- **D-07:** **CLI local + Docker** para dev. `supabase init` + `supabase start`. Migrações versionadas em `supabase/migrations/*.sql`. User instalará Docker Desktop antes da execução da fase.
- **D-08:** Secrets via **dart-define + VSCode launch.json**. `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Arquivo `.vscode/launch.json` no `.gitignore`. Sem arquivo .env, sem hardcode.

### Packages
- **D-09:** **Todo o stack instalado na Phase 0** — pubspec.yaml recebe todos os packages do CLAUDE.md de uma vez para validar compilação conjunta antes de qualquer feature.
  - Produção: `flutter_riverpod`, `riverpod_annotation`, `go_router`, `supabase_flutter`, `freezed_annotation`, `json_annotation`, `flutter_secure_storage`, `shared_preferences`, `flutter_svg`, `intl`, `data_table_2`
  - Dev: `riverpod_generator`, `build_runner`, `freezed`, `json_serializable`, `flutter_lints`, `mocktail`
- **D-10:** Codegen pipeline (`build_runner` + `freezed` + `riverpod_generator`) **configurado mas NÃO usado na Phase 0** — primeiro model freezed real aparece na Phase 1. Phase 0 apenas instala e valida que `flutter pub get` + `dart run build_runner build` executam sem erro.

### Web Renderer
- **D-11:** **Auto** (padrão Flutter) — CanvasKit em desktop, HTML em mobile. Sem configuração extra.

### Theme e Locale
- **D-12:** **Paleta agrária** com Material 3: seedColor em verde-musgo ou terra. Define identidade visual consistente com o domínio (pecuária, campo).
- **D-13:** **pt-BR configurado desde Phase 0** — `intl` + `flutter_localizations` no main. Datas, números e formatação em português em todas as fases futuras.

### Claude's Discretion
- Cor exata do seedColor dentro da paleta "verde-musgo/terra" — escolha do Claude.
- Breakpoint exato de colapso sidebar → bottom nav — padrão Material 3 (600px).
- Estrutura de sub-diretórios dentro de `lib/core/` além dos definidos em D-05.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Stack e Packages
- `CLAUDE.md` — Stack completo com versões de packages, padrões obrigatórios e anti-patterns (seção "Recommended Stack" e "What NOT to Use")
- `.planning/ROADMAP.md` §Phase 0 — Goal, success criteria e UI hint da fase

### Requisitos e Contexto
- `.planning/PROJECT.md` — Visão, hierarquia de domínio, constraints (stack, offline, plataformas)
- `.planning/REQUIREMENTS.md` — Phase 0 não tem REQ IDs; nota em Traceability confirma isso

### Supabase
- Documentação supabase CLI: `supabase init`, `supabase start`, `supabase migration new` (verificar via `supabase --help` durante execução)

No external specs beyond the above — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/main.dart`: vanilla counter app — será completamente substituído. Nenhum código reaproveitável.
- `pubspec.yaml`: apenas `cupertino_icons` além do SDK Flutter — blank slate para adicionar stack completo.

### Established Patterns
- Nenhum padrão estabelecido — Phase 0 é quem os define para as demais fases.

### Integration Points
- `lib/main.dart` → ProviderScope (Riverpod) → MaterialApp.router (GoRouter) → AppShell
- AppShell → StatefulShellRoute (GoRouter) → 5 feature shells
- `lib/core/services/` → SupabaseClient singleton → injetado via Riverpod provider em repositories

</code_context>

<specifics>
## Specific Ideas

- Shell: sidebar fixo no web visualmente similar a apps de gestão agrícola/ERP — ícone + label, área de conteúdo ocupa o resto.
- Header com seletor de propriedade ativa é prioridade desde o início — crítico para o modelo multi-tenant do app.
- `currentPropertyProvider`: AsyncNotifier que expõe `Property?`, começa null, será preenchido na Phase 1.

</specifics>

<deferred>
## Deferred Ideas

- Dark mode — pode ser adicionado pós-MVP sem breaking changes no Material 3 ThemeData.
- CanvasKit fixo ou WASM renderer — avaliar se performance exigir pós-MVP.
- Codegen com modelos na Phase 0 — adiado para Phase 1 (primeiro model de domínio real).

</deferred>

---

*Phase: 00-foundation*
*Context gathered: 2026-04-26*
