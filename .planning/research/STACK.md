# Stack Research

**Project:** Campo Gestor (livestock/pecuária management app)
**Researched:** 2026-04-24
**Research mode:** Ecosystem (prescriptive recommendations)
**Overall confidence:** HIGH on architecture choices, MEDIUM on exact patch versions (live verification was blocked — see "Risks & Unknowns")

> **Verification note:** WebSearch and WebFetch were denied in this research session. Version numbers below reflect the training cutoff (Jan 2026) and correspond to the last stable releases I have knowledge of. Run `flutter pub outdated` during project bootstrap to confirm the exact pinned minor/patch and adjust if a newer stable has shipped. The **architectural choices** do not change — only the version strings may need a bump.

---

## Recommended Stack

### Frontend (Flutter)

**Flutter SDK:** `>=3.24.0 <4.0.0` (stable channel, late-2024/2025 cadence). Dart `>=3.5.0`.
**Rationale:** Flutter 3.24+ is where web performance (particularly CanvasKit → Skwasm WASM renderer) stabilized and where `flutter build web --wasm` became production-viable. Dart 3.5 brings stable pattern matching and records which Riverpod 2.x leverages.
**Confidence:** HIGH

#### State management: **Riverpod 2.x (flutter_riverpod + riverpod_annotation)**
**Pin:** `flutter_riverpod: ^2.5.1`, `riverpod_annotation: ^2.3.5`, `riverpod_generator: ^2.4.0` (dev)
**Rationale:**
- Riverpod has overtaken BLoC as the community default for new Flutter projects since ~2023. The code-gen `@riverpod` API (Notifier/AsyncNotifier) removes the boilerplate pain and gives compile-time safety.
- Ships with `AsyncValue` which maps 1:1 to Supabase queries (loading/data/error) — this is exactly the shape of every screen that reads from Postgres.
- No `BuildContext` dependency → testable in pure Dart, composable across layers. Critical for a domain-rich app with business rules (ATF constraints, UA calculations, snapshot logic).
- Better ergonomics on Flutter web than BLoC for this app's size. BLoC's event/state machine shines in complex UI flows but is overkill for CRUD-heavy livestock screens.
**Confidence:** HIGH

#### Navigation: **GoRouter**
**Pin:** `go_router: ^14.2.0`
**Rationale:**
- **Web-first decision driver:** GoRouter is maintained by the Flutter team, integrates natively with `Router` API, handles URL synchronization, deep links, and browser back/forward out of the box. `auto_route` has better code-gen ergonomics but historically lags on Flutter web edge cases (hash vs path routing, query params, browser history stack).
- ShellRoute + StatefulShellRoute gives nested navigation (sidebar on web, bottom tabs on mobile) with the same route tree.
- Redirect guards are the natural place for auth gating against Supabase's `authStateChanges` stream.
- Pairs cleanly with Riverpod via `refreshListenable: GoRouterRefreshStream(ref.watch(authProvider.stream))`.
**Confidence:** HIGH

#### HTTP / Supabase client: **supabase_flutter (no dio)**
**Pin:** `supabase_flutter: ^2.5.0`
**Rationale:**
- `supabase_flutter` bundles `supabase` (postgrest, gotrue, realtime, storage, functions) and handles session persistence, deep-link auth callbacks, and web token storage. It uses `http` (not dio) under the hood, which is fine — you do not need dio.
- **Do not add dio** unless you have a specific non-Supabase REST endpoint to consume. Mixing dio and `http` doubles your interceptor/auth-header code and is the #1 source of "why is my session not refreshing" bugs in Flutter+Supabase projects.
- Supabase Dart SDK v2 introduced `.select<T>()` typed responses, upsert semantics fixes, and broke some v1 patterns — pin v2+ and ignore v1 tutorials on the web.
**Confidence:** HIGH

#### Data classes & serialization: **freezed + json_serializable**
**Pin:**
```
freezed_annotation: ^2.4.4
json_annotation: ^4.9.0
# dev
freezed: ^2.5.7
json_serializable: ^6.8.0
build_runner: ^2.4.13
```
**Rationale:**
- Freezed gives immutable data classes, sealed unions (perfect for domain events like `SanitaryApplication.created | rolled_back`), deep `copyWith`, equality, and pattern-matchable `switch` (Dart 3.5).
- Combined with `json_serializable` you get `fromJson`/`toJson` aligned with Supabase snake_case rows. Use `@JsonKey(name: 'lote_atf_id')` or `@JsonSerializable(fieldRename: FieldRename.snake)` to bridge PostgreSQL → Dart.
- **Do not use `dart_mappable`** for this project. It is excellent but less idiomatic for the Supabase/Riverpod community — more community examples use freezed, which matters when onboarding future contributors.
**Confidence:** HIGH

#### Local storage (session cache, NOT offline-first): **flutter_secure_storage + shared_preferences**
**Pin:**
- `flutter_secure_storage: ^9.2.2` (auth tokens if supabase_flutter's default isn't enough)
- `shared_preferences: ^2.3.0` (user prefs: last selected propriedade, UI prefs)

**Rationale:** PROJECT.md explicitly states "Offline: não é requisito no MVP". Do **not** introduce Hive or Isar until offline becomes a real requirement — they add migration pain, web-storage quirks (IndexedDB quotas), and conflict-resolution complexity you do not need.
- `supabase_flutter` already persists the auth session in `SharedPreferences` on web and `flutter_secure_storage` on mobile when configured. Leave that default behavior on.
- `shared_preferences` for "last opened propriedade" / theme / locale — anything < 1KB.
**Confidence:** HIGH

**If offline becomes a requirement post-MVP:** add **Drift** (formerly Moor) — `drift: ^2.20.0`. Drift has the best web support (via sql.js/WASM) of the Flutter local-DB options in 2025, supports typed queries with code-gen, and is actively maintained. Isar v3 stalled; Isar v4 is a rewrite that has not stabilized. Hive Community Edition exists but its web story (IndexedDB boxes) has sharp edges.
**Confidence on Drift recommendation:** MEDIUM — revisit at the time offline is scoped.

#### Forms: **reactive_forms or flutter_form_builder**
**Pin:** `reactive_forms: ^17.0.2`
**Rationale:** Domain has many forms with cross-field validation (ATF only accepts vacas/novilhas; animal cannot be in 2 active ATFs; estado corporal 1–5). `reactive_forms` gives you a `FormGroup` with synchronous and async validators — plug RLS-derived constraints directly into the validator layer. `flutter_form_builder` is the alternative; both are fine. Riverpod purists sometimes roll their own with `Notifier<FormState>` — that is acceptable but costs more boilerplate.
**Confidence:** MEDIUM (either library is fine; preference is weak)

#### UI component layer: **Material 3 (flutter built-in) + a data-grid package**
- `data_table_2: ^2.5.15` — for the paddock/lote/animal list screens (sortable, fixed headers, scrollable on web). Flutter's built-in `DataTable` does not handle large lists well on web.
- `flutter_svg: ^2.0.10+1` — for any SVG icons/branding.
- `intl: ^0.19.0` — for pt-BR formatting (dates, numbers). Locale must be set to `pt_BR`.
**Confidence:** HIGH on Material 3 + intl, MEDIUM on data_table_2 (alternatives: PlutoGrid for heavier use).

#### Date/time: **intl + timezone (if needed)**
**Pin:** `intl: ^0.19.0`
For this app's domain (reproductive cycle dates, sanitary application dates), local date (America/Sao_Paulo) is sufficient. Store as `timestamptz` in Postgres, render with `DateFormat('dd/MM/yyyy', 'pt_BR')`.
**Confidence:** HIGH

---

### Backend (Supabase)

**Services used:**

| Service | Usage | Confidence |
|---|---|---|
| **Postgres** | Primary database, all domain entities | HIGH |
| **Auth** | Email/password + optionally magic link; JWT with custom claims for profile | HIGH |
| **RLS (Row Level Security)** | Multi-tenant isolation across propriedades | HIGH |
| **Database Functions (plpgsql)** | Animal number sequence per propriedade, UA calculations, ATF invariants | HIGH |
| **Edge Functions (Deno)** | Only if you need external integrations (email reports, etc.) — not MVP | LOW (skip for MVP) |
| **Realtime** | Optional for live dashboards later — skip for MVP | LOW (skip for MVP) |
| **Storage** | Attachments on sanitary applications (photos of treatments, receipts) — optional | MEDIUM |

**Rationale for "Postgres + RLS does most of the work":** The project's invariants (animal number unique per propriedade, ATF accepts only certain categories, snapshot immutability, multi-property vet access) all live naturally at the database layer. RLS is the single source of truth for "who can see/modify what" — it is NOT duplicated in Dart. Dart code assumes the server will reject unauthorized queries.

**Supabase project setup:**
- One Supabase project for dev, one for prod. Use the Supabase CLI (`supabase: ^1.200+`) for local dev with Docker and migrations-as-code (`supabase/migrations/*.sql`).
- All schema changes go through `supabase migration new <name>` → check into git → `supabase db push`. Never use the web SQL editor for schema changes in production.
**Confidence:** HIGH

---

### Database (PostgreSQL schema patterns)

#### Multi-tenant boundary: **propriedade_id** on every domain row + RLS

Every table that holds domain data carries `propriedade_id uuid not null references propriedades(id)`. All RLS policies filter on the caller's membership in that propriedade (via the permissions table described below).

**Exceptions to "propriedade_id on every row":** `animais` does not strictly need it if it is always reached via `lote_id → piquete_id → propriedade_id`, but in practice **denormalize it** onto `animais` to keep RLS policies cheap (single join-less predicate) and indexes effective.

**Confidence:** HIGH

#### Permissions table (multi-property access for vets)

```sql
create table permissoes_usuario (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  propriedade_id uuid not null references propriedades(id) on delete cascade,
  perfil text not null check (perfil in ('proprietario','veterinario','leitor')),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, propriedade_id) where deleted_at is null
);
```

A helper SQL function `auth_has_access(prop_id uuid, min_perfil text)` centralizes "does the current `auth.uid()` have at least X perfil on this propriedade" and is reused from every RLS policy.

**Confidence:** HIGH

#### RLS policy template

For every domain table, four policies (SELECT / INSERT / UPDATE / DELETE), each calling the helper:

```sql
alter table lotes enable row level security;

create policy lotes_select on lotes for select
  using (auth_has_access(propriedade_id, 'leitor'));

create policy lotes_insert on lotes for insert
  with check (auth_has_access(propriedade_id, 'veterinario'));

create policy lotes_update on lotes for update
  using (auth_has_access(propriedade_id, 'veterinario'))
  with check (auth_has_access(propriedade_id, 'veterinario'));

create policy lotes_delete on lotes for delete
  using (auth_has_access(propriedade_id, 'proprietario'));
```

**Perfil hierarchy for the helper:** `proprietario > veterinario > leitor`. "leitor" reads only; "veterinario" reads + writes domain data; "proprietario" additionally manages permissions and deletes.

**Confidence:** HIGH

#### Entity hierarchy (DDL sketch)

```
propriedades (id, nome, created_at, deleted_at)
  piquetes (id, propriedade_id, nome, area_ha, deleted_at)
  lotes (id, propriedade_id, piquete_id, nome, tipo ['operacional'], deleted_at)
  lotes_atf (id, propriedade_id, nome, data_inicio, data_dg, pct_prenhez, deleted_at)
  animais (id, propriedade_id, lote_id, numero, categoria, estado_corporal, deleted_at)
  animais_lote_atf (animal_id, lote_atf_id, ativo)  -- M:N, enforces "no 2 active ATFs"
  aplicacoes_sanitarias (id, propriedade_id, lote_id, produto, data, custo, snapshot jsonb, deleted_at)
  gastos_piquete (id, propriedade_id, piquete_id, descricao, valor, data, deleted_at)
```

**Confidence:** HIGH on shape, MEDIUM on exact column names (these will be refined during schema design).

#### Animal numbering: **sequence per propriedade via function**

```sql
create or replace function next_animal_numero(prop_id uuid)
returns integer language plpgsql as $$
declare n integer;
begin
  -- row-level lock on propriedades row prevents concurrent insertions
  perform 1 from propriedades where id = prop_id for update;
  select coalesce(max(numero), 0) + 1 into n
    from animais where propriedade_id = prop_id;
  return n;
end; $$;
```

Wrap animal insertion in a function (`create_animal(prop_id, lote_id, categoria, ...)`) so the numbering + insert happens atomically. The app calls `rpc('create_animal', ...)` via `supabase.rpc()`.

**Alternative:** a dedicated `propriedade_animal_counters` table with `update ... returning` — slightly cleaner, avoids `max()` scan. Pick one during schema design; both are correct.

**Confidence:** HIGH on the approach, MEDIUM on which variant to pick.

#### Snapshot immutability (sanitary applications)

`aplicacoes_sanitarias.snapshot jsonb` stores the frozen list of animals at application time. Enforce immutability with a trigger:

```sql
create trigger tg_aplic_immutable
  before update on aplicacoes_sanitarias
  for each row execute function prevent_snapshot_change();
```

The trigger raises if `new.snapshot != old.snapshot` OR if any other field the business rule declares immutable is changed. Keep the list of editable fields small (maybe `observacoes`, nothing else).

**Confidence:** HIGH

#### Soft delete

Every table has `deleted_at timestamptz`. RLS SELECT policies add `and deleted_at is null` via a view or a helper. Recommended pattern: **all application queries go through views** (`lotes_view`, `animais_view`) that filter out soft-deleted rows, while the base tables are where FKs point. This way historical references (sanitary snapshots pointing to a now-deleted animal) still resolve, but active queries do not show the deleted row.

**Confidence:** MEDIUM — this is a design call; another valid approach is to keep base tables + add `where deleted_at is null` in every application query. Views are cleaner but add a migration layer.

#### Indexes (do these from day 1)

- `(propriedade_id)` on every domain table.
- `(propriedade_id, numero)` unique partial `where deleted_at is null` on `animais`.
- `(user_id, propriedade_id)` on `permissoes_usuario`.
- `(lote_atf_id, animal_id)` unique partial `where ativo = true` on `animais_lote_atf`.

**Confidence:** HIGH

---

### Auth

**Approach:** Supabase Auth with email + password for MVP. Magic link is a nice add but brings email deliverability concerns; defer.

**Pattern:**
1. User signs up → row in `auth.users`.
2. A trigger on `auth.users` insert creates a default `permissoes_usuario` row if the user is invited to a propriedade (or leaves them in a "no propriedade yet" state).
3. Dart listens to `supabase.auth.onAuthStateChange` → feeds a Riverpod `authProvider` → GoRouter `redirect` reads this and gates routes.
4. JWT carries `sub` = user id; perfil is looked up server-side in RLS helpers (not in the JWT claim) so perfil changes take effect immediately without requiring a token refresh.

**Do not** stuff perfil/propriedade_id into JWT claims for MVP. It is tempting for speed, but means revoking access requires a sign-out or token refresh. Perfil lookups in `auth_has_access()` are cached by Postgres's statement cache and are cheap.

**Confidence:** HIGH

**JWT handling in Dart:** `supabase_flutter` does this automatically. Do not roll your own. The session is refreshed in the background; expose it via a Riverpod `StreamProvider<AuthState>`.

---

### Testing

| Layer | Tool | Purpose | Confidence |
|---|---|---|---|
| Unit (pure Dart) | `test`, `mocktail: ^1.0.4` | Domain logic (UA calculations, ATF invariants), Riverpod notifiers | HIGH |
| Widget | `flutter_test`, `mocktail` | Screen rendering, user flows in isolation | HIGH |
| Integration (Dart) | `integration_test` (SDK) | Smoke tests of critical flows on a real Supabase **dev** project | MEDIUM |
| RLS / SQL | `pgTAP` via Supabase CLI `supabase test db` | Verify every RLS policy with positive + negative cases | HIGH |
| E2E web | Defer — Playwright optional post-MVP | — | LOW (skip for MVP) |

**Mocking Supabase:** Prefer `mocktail` over `mockito`. Mock the repository layer (your own abstraction) rather than the Supabase client directly. Create a `PropriedadeRepository` interface with a `SupabasePropriedadeRepository` implementation and an `InMemoryPropriedadeRepository` for tests. This is worth the upfront cost.

**Confidence:** HIGH

---

### Flutter Web performance

1. **Use the default renderer.** As of Flutter 3.24+, CanvasKit is default on desktop web, HTML on mobile web — let the framework decide unless you have a specific pain point.
2. **Try `flutter build web --wasm`** for production builds once stable for your Flutter channel. WASM + Skwasm gives large performance wins on data-heavy tables. Validate in staging; fall back to default if you hit plugin incompatibilities.
3. **Code-split / deferred imports:** Flutter web respects `deferred as` imports. Lazy-load heavy modules (sanitary history charts, admin screens).
4. **Avoid large PNGs.** Use WebP or SVG (`flutter_svg`).
5. **Pre-cache fonts** via `fonts:` in `pubspec.yaml` with `preload: true` where supported; avoid Google Fonts package on web (it downloads at runtime — hurts first paint).
6. **Data grids:** use virtualized lists (`ListView.builder`, or `data_table_2` with pagination). Never render 10k animals at once.
7. **Index.html:** trim the Flutter bootstrapper (the 3.22+ new bootstrapper is better). Set a minimal loading splash.

**Confidence:** HIGH on all the above; MEDIUM on WASM readiness — verify when you start.

---

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

---

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

---

## Risks & Unknowns

1. **Exact package versions could be one or two minor releases behind.** (MEDIUM)
   Web search was blocked during research. Before `pubspec.yaml` is finalized:
   - Run `flutter create campo_gestor --platforms=web,android,ios` with current Flutter stable.
   - Run `flutter pub add <each package>` — pub will resolve the latest compatible version.
   - Run `flutter pub outdated` and bump anything on a major that looks behind.
   - Verify especially: `supabase_flutter` (v2 line is what you want), `freezed` (v2 line), `go_router` (v14+), `flutter_riverpod` (v2 line).

2. **Riverpod 3.x may be stable or in beta.** (MEDIUM)
   Riverpod 3 was in development with some breaking renames (Notifier API cleanups). If stable by project start, use it — rationale is identical, only the imports/generator directives shift.

3. **Flutter WASM (`--wasm`) plugin compatibility.** (MEDIUM)
   `supabase_flutter` and its transitive deps should support WASM in 2025, but a stray plugin (e.g., a platform channel with `dart:ffi` stubs) can break WASM builds. Treat WASM as a nice-to-have after M1, not a blocker.

4. **Drift on Flutter Web if offline becomes required.** (LOW for MVP, HIGH if scope expands)
   Drift runs via sql.js / wasm-sqlite on web. This works but adds ~1MB to the bundle and requires cross-origin isolation headers for the WASM build. Verify at scoping time.

5. **RLS performance at scale.** (LOW for MVP)
   With thousands of animals per propriedade and the helper function called on every row, plan to materialize the helper as a `security definer` function and index `permissoes_usuario(user_id, propriedade_id)`. Measure before optimizing.

6. **pt-BR locale + Material date pickers on web.** (LOW)
   Confirm `MaterialLocalizations.delegate` and `GlobalMaterialLocalizations.delegate` are wired with `Locale('pt', 'BR')` in `MaterialApp`. Trivial but easy to forget.

7. **Animal numbering atomicity under high concurrency.** (LOW)
   The `for update` lock on `propriedades` is correct but serializes all animal inserts within one propriedade. For MVP this is fine (single-digit concurrent users). At scale, switch to a dedicated counter table.

8. **Snapshot jsonb schema evolution.** (MEDIUM)
   The frozen sanitary snapshot should include a `schema_version` field from day 1. When snapshot shape evolves (new animal fields), old snapshots stay readable via versioned parsers.

---

## Sources

- Training knowledge, Jan 2026 cutoff (authoritative for architecture and library selection; package versions to verify live during bootstrap).
- pub.dev (intended source, access blocked in this session — run `flutter pub outdated` to verify).
- supabase.com/docs (intended source, access blocked — confirm CLI version and v2 client patterns at bootstrap).

**Verification status:**
- Architecture choices (Riverpod, GoRouter, supabase_flutter, freezed, RLS-first multi-tenancy): HIGH confidence (stable, well-established patterns from 2023–2025).
- Exact minor/patch versions: MEDIUM confidence (session constraints; verify via `flutter pub outdated` during bootstrap — this is a 2-minute check).
- Performance claims (WASM renderer, bundle trimming): MEDIUM confidence (directionally correct; measure in staging).
