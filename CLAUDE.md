<!-- GSD:project-start source:PROJECT.md -->
## Project

**Campo Gestor**

App de gestão de propriedades rurais voltado para pecuária. Permite estruturar a propriedade em piquetes, organizar lotes, controlar animais individualmente, registrar histórico reprodutivo e sanitário, e oferecer visão operacional e gerencial do rebanho. Atende veterinários e proprietários de fazenda.

**Core Value:** O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo por quem toma decisões operacionais.

### Constraints

- **Stack**: Flutter web-first + Supabase (PostgreSQL + Auth + RLS) — decisão tomada antes do MVP
- **Offline**: não é requisito no MVP — sistema assume conectividade
- **Plataformas**: web primário, mobile (android/iOS) secundário
- **Numeração**: número do animal único por propriedade, gerado via sequence/lock no banco
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Frontend (Flutter)
#### State management: **Riverpod 2.x (flutter_riverpod + riverpod_annotation)**
- Riverpod has overtaken BLoC as the community default for new Flutter projects since ~2023. The code-gen `@riverpod` API (Notifier/AsyncNotifier) removes the boilerplate pain and gives compile-time safety.
- Ships with `AsyncValue` which maps 1:1 to Supabase queries (loading/data/error) — this is exactly the shape of every screen that reads from Postgres.
- No `BuildContext` dependency → testable in pure Dart, composable across layers. Critical for a domain-rich app with business rules (ATF constraints, UA calculations, snapshot logic).
- Better ergonomics on Flutter web than BLoC for this app's size. BLoC's event/state machine shines in complex UI flows but is overkill for CRUD-heavy livestock screens.
#### Navigation: **GoRouter**
- **Web-first decision driver:** GoRouter is maintained by the Flutter team, integrates natively with `Router` API, handles URL synchronization, deep links, and browser back/forward out of the box. `auto_route` has better code-gen ergonomics but historically lags on Flutter web edge cases (hash vs path routing, query params, browser history stack).
- ShellRoute + StatefulShellRoute gives nested navigation (sidebar on web, bottom tabs on mobile) with the same route tree.
- Redirect guards are the natural place for auth gating against Supabase's `authStateChanges` stream.
- Pairs cleanly with Riverpod via `refreshListenable: GoRouterRefreshStream(ref.watch(authProvider.stream))`.
#### HTTP / Supabase client: **supabase_flutter (no dio)**
- `supabase_flutter` bundles `supabase` (postgrest, gotrue, realtime, storage, functions) and handles session persistence, deep-link auth callbacks, and web token storage. It uses `http` (not dio) under the hood, which is fine — you do not need dio.
- **Do not add dio** unless you have a specific non-Supabase REST endpoint to consume. Mixing dio and `http` doubles your interceptor/auth-header code and is the #1 source of "why is my session not refreshing" bugs in Flutter+Supabase projects.
- Supabase Dart SDK v2 introduced `.select<T>()` typed responses, upsert semantics fixes, and broke some v1 patterns — pin v2+ and ignore v1 tutorials on the web.
#### Data classes & serialization: **freezed + json_serializable**
# dev
- Freezed gives immutable data classes, sealed unions (perfect for domain events like `SanitaryApplication.created | rolled_back`), deep `copyWith`, equality, and pattern-matchable `switch` (Dart 3.5).
- Combined with `json_serializable` you get `fromJson`/`toJson` aligned with Supabase snake_case rows. Use `@JsonKey(name: 'lote_atf_id')` or `@JsonSerializable(fieldRename: FieldRename.snake)` to bridge PostgreSQL → Dart.
- **Do not use `dart_mappable`** for this project. It is excellent but less idiomatic for the Supabase/Riverpod community — more community examples use freezed, which matters when onboarding future contributors.
#### Local storage (session cache, NOT offline-first): **flutter_secure_storage + shared_preferences**
- `flutter_secure_storage: ^9.2.2` (auth tokens if supabase_flutter's default isn't enough)
- `shared_preferences: ^2.3.0` (user prefs: last selected propriedade, UI prefs)
- `supabase_flutter` already persists the auth session in `SharedPreferences` on web and `flutter_secure_storage` on mobile when configured. Leave that default behavior on.
- `shared_preferences` for "last opened propriedade" / theme / locale — anything < 1KB.
#### Forms: **reactive_forms or flutter_form_builder**
#### UI component layer: **Material 3 (flutter built-in) + a data-grid package**
- `data_table_2: ^2.5.15` — for the paddock/lote/animal list screens (sortable, fixed headers, scrollable on web). Flutter's built-in `DataTable` does not handle large lists well on web.
- `flutter_svg: ^2.0.10+1` — for any SVG icons/branding.
- `intl: ^0.19.0` — for pt-BR formatting (dates, numbers). Locale must be set to `pt_BR`.
#### Date/time: **intl + timezone (if needed)**
### Backend (Supabase)
| Service | Usage | Confidence |
|---|---|---|
| **Postgres** | Primary database, all domain entities | HIGH |
| **Auth** | Email/password + optionally magic link; JWT with custom claims for profile | HIGH |
| **RLS (Row Level Security)** | Multi-tenant isolation across propriedades | HIGH |
| **Database Functions (plpgsql)** | Animal number sequence per propriedade, UA calculations, ATF invariants | HIGH |
| **Edge Functions (Deno)** | Only if you need external integrations (email reports, etc.) — not MVP | LOW (skip for MVP) |
| **Realtime** | Optional for live dashboards later — skip for MVP | LOW (skip for MVP) |
| **Storage** | Attachments on sanitary applications (photos of treatments, receipts) — optional | MEDIUM |
- One Supabase project for dev, one for prod. Use the Supabase CLI (`supabase: ^1.200+`) for local dev with Docker and migrations-as-code (`supabase/migrations/*.sql`).
- All schema changes go through `supabase migration new <name>` → check into git → `supabase db push`. Never use the web SQL editor for schema changes in production.
### Database (PostgreSQL schema patterns)
#### Multi-tenant boundary: **propriedade_id** on every domain row + RLS
#### Permissions table (multi-property access for vets)
#### RLS policy template
#### Entity hierarchy (DDL sketch)
#### Animal numbering: **sequence per propriedade via function**
#### Snapshot immutability (sanitary applications)
#### Soft delete
#### Indexes (do these from day 1)
- `(propriedade_id)` on every domain table.
- `(propriedade_id, numero)` unique partial `where deleted_at is null` on `animais`.
- `(user_id, propriedade_id)` on `permissoes_usuario`.
- `(lote_atf_id, animal_id)` unique partial `where ativo = true` on `animais_lote_atf`.
### Auth
### Testing
| Layer | Tool | Purpose | Confidence |
|---|---|---|---|
| Unit (pure Dart) | `test`, `mocktail: ^1.0.4` | Domain logic (UA calculations, ATF invariants), Riverpod notifiers | HIGH |
| Widget | `flutter_test`, `mocktail` | Screen rendering, user flows in isolation | HIGH |
| Integration (Dart) | `integration_test` (SDK) | Smoke tests of critical flows on a real Supabase **dev** project | MEDIUM |
| RLS / SQL | `pgTAP` via Supabase CLI `supabase test db` | Verify every RLS policy with positive + negative cases | HIGH |
| E2E web | Defer — Playwright optional post-MVP | — | LOW (skip for MVP) |
### Flutter Web performance
## Key Packages (Summary Table)
| Package | Version | Purpose | Confidence |
|---|---|---|---|
| flutter | >=3.24.0 <4.0.0 | SDK | HIGH |
| flutter_riverpod | ^2.5.1 | State management | HIGH |
| riverpod_annotation | ^2.3.5 | Code-gen state | HIGH |
| riverpod_generator | ^2.4.0 (dev) | Codegen | HIGH |
| go_router | ^14.2.0 | Navigation (web-friendly) | HIGH |
| supabase_flutter | ^2.5.0 | Backend client (auth, db, realtime, storage) | HIGH |
| freezed_annotation | ^2.4.4 | Immutable data classes | HIGH |
| freezed | ^2.5.7 (dev) | Codegen for freezed | HIGH |
| json_annotation | ^4.9.0 | JSON serialization | HIGH |
| json_serializable | ^6.8.0 (dev) | Codegen for json | HIGH |
| build_runner | ^2.4.13 (dev) | Codegen runner | HIGH |
| flutter_secure_storage | ^9.2.2 | Secure token storage (mobile) | HIGH |
| shared_preferences | ^2.3.0 | User prefs cache | HIGH |
| reactive_forms | ^17.0.2 | Form state with cross-field validation | MEDIUM |
| data_table_2 | ^2.5.15 | Scrollable sortable tables on web | MEDIUM |
| flutter_svg | ^2.0.10+1 | SVG rendering | HIGH |
| intl | ^0.19.0 | pt-BR formatting | HIGH |
| mocktail | ^1.0.4 (dev) | Mocking | HIGH |
| integration_test | (SDK) | E2E smoke | MEDIUM |
| supabase (CLI) | latest | Local dev + migrations | HIGH |
## What NOT to Use
| Package / Pattern | Why Not |
|---|---|
| **BLoC (flutter_bloc)** | Fine library, but more ceremony than this CRUD-heavy app needs. Riverpod's `AsyncValue` maps to Supabase query states with zero glue code. Do not mix BLoC and Riverpod. |
| **Provider (standalone)** | Superseded by Riverpod. Riverpod is Provider's author's evolution. |
| **GetX** | Anti-pattern in 2025 — monolithic, hidden dependencies, encourages poor architecture, community has largely moved on. |
| **auto_route** | Fine on mobile; GoRouter is better for web-first because it is maintained by the Flutter team and tracks the Router API tightly. Do not mix both. |
| **dio** | Not needed unless you have non-Supabase REST endpoints. `supabase_flutter` handles HTTP, auth headers, refresh, retries. Adding dio creates two HTTP stacks. |
| **retrofit** | Same reason as dio — you do not have a typed REST API to consume. Supabase's query builder + freezed models give you type-safety already. |
| **hive / hive_ce** | Offline is out of scope for MVP. Hive's web story (IndexedDB) has edge cases. Defer. |
| **isar (v3)** | Maintenance has stalled; v4 is a rewrite with uncertain timeline. Not a safe pick in 2025/2026. |
| **moor (old name for drift)** | Use `drift` package name; `moor` is deprecated alias. |
| **google_fonts (on web)** | Runtime font fetch hurts first paint. Bundle fonts via `pubspec.yaml` `fonts:` instead. |
| **JWT custom claims for perfil** | Stale-until-refresh problem when perfil changes. Query `permissoes_usuario` in RLS helper instead. |
| **Realtime subscriptions in MVP** | Connection management + reconnect + backfill is real work. The app is not collaborative in the MVP sense. Add later for dashboards. |
| **Edge Functions in MVP** | Keep logic in Postgres (RLS + functions) for MVP. Edge Functions add a deploy surface you do not need yet. |
| **Supabase Storage in MVP** | Only needed if sanitary applications attach photos — verify that requirement before adding. |
| **Web SQL editor for schema changes** | Always go through `supabase/migrations/*.sql` + CLI. Otherwise dev/prod drift will bite you in week 3. |
## Risks & Unknowns
## Sources
- Training knowledge, Jan 2026 cutoff (authoritative for architecture and library selection; package versions to verify live during bootstrap).
- pub.dev (intended source, access blocked in this session — run `flutter pub outdated` to verify).
- supabase.com/docs (intended source, access blocked — confirm CLI version and v2 client patterns at bootstrap).
- Architecture choices (Riverpod, GoRouter, supabase_flutter, freezed, RLS-first multi-tenancy): HIGH confidence (stable, well-established patterns from 2023–2025).
- Exact minor/patch versions: MEDIUM confidence (session constraints; verify via `flutter pub outdated` during bootstrap — this is a 2-minute check).
- Performance claims (WASM renderer, bundle trimming): MEDIUM confidence (directionally correct; measure in staging).
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
