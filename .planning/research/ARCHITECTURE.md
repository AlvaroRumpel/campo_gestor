# Architecture Research

**Project:** Campo Gestor (Flutter web-first + Supabase rural property management)
**Researched:** 2026-04-24
**Overall confidence:** HIGH (stack is mainstream, patterns are well-established)

## Executive Summary

For a domain-rich app like Campo Gestor — hierarchical data (Propriedade → Piquete → Lote → Animal), multi-tenancy (veterinário com acesso a várias fazendas), snapshot/immutability rules, auto-numbering with race conditions, and web-first with future mobile — the architecture that wins is:

- **Flutter side:** Feature-first folder layout on top of Flutter team's recommended MVVM (View + ViewModel + Repository + Service), with **Riverpod** as the DI/state container and **GoRouter** for web-friendly deep linking.
- **Supabase side:** PostgreSQL-first. RLS on EVERY table, anchored on a single **`property_members`** pivot. All mutations that cross entities or need atomicity go through **Postgres functions (RPC)**, not client code. Snapshot/numbering/ATF-constraint are enforced at the DB layer so they can't be bypassed.
- **Build order:** Auth + multi-tenant skeleton first, then hierarchy CRUD bottom-up (Propriedade → Piquete → Lote → Animal), then reproductive (LoteATF), then sanitário (snapshot), then gastos. Snapshot + numeração são os pontos de maior risco técnico — build early on isolated prototypes.

---

## Recommended Architecture

### Flutter Layer Structure

Adopt the **Flutter team's official architecture** (MVVM + Repository + Service) with a **feature-first** folder layout. This matches the 2024–2026 official guide and scales better than layer-first once you pass ~5 features.

#### Layer responsibilities

| Layer | Role | Knows about | Does NOT know about |
|-------|------|-------------|---------------------|
| **View** (Widget) | Render state, handle user input, navigate | ViewModel | Repository, Supabase |
| **ViewModel** (Notifier / AsyncNotifier) | Hold UI state, expose commands, call repositories | Repository, domain models | Widgets, Supabase client |
| **Repository** | Source of truth per aggregate (animals, lots, applications). Business logic, caching, mapping | Services, domain models | Widgets, ViewModels |
| **Service** (SupabaseClient wrappers) | Raw data access. Stateless. Returns DTOs or throws | Supabase SDK | Business rules, state |
| **Domain** (models + optional use-cases) | Plain Dart entities, value objects, invariants | Nothing (pure Dart) | Everything else |

One-to-one between View and ViewModel. Many-to-many between Repository and Service (the `PropertyRepository` can use both `PropertyService` and `MemberService`; both services can be used by multiple repositories).

#### Folder organization (feature-first, hybrid)

```
lib/
├── main.dart
├── app/                          # App-level wiring
│   ├── app.dart                  # MaterialApp.router
│   ├── router.dart               # GoRouter config + guards
│   ├── theme.dart
│   └── bootstrap.dart            # Supabase.initialize, ProviderScope
│
├── core/                         # Cross-cutting, framework-agnostic
│   ├── errors/                   # AppException, mapping from PostgrestException
│   ├── result/                   # Result<T>/Either for repository returns
│   ├── logging/
│   ├── extensions/
│   └── utils/                    # Date, UA calc, formatters
│
├── data/                         # Shared infrastructure
│   ├── supabase/
│   │   ├── supabase_client_provider.dart
│   │   └── auth_listener.dart
│   └── realtime/
│
├── domain/                       # Shared domain primitives (rare)
│   ├── value_objects/            # AnimalCategory, UA, EstadoCorporal
│   └── exceptions/
│
├── features/                     # ← feature-first goes here
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_service.dart
│   │   │   └── auth_repository.dart
│   │   ├── domain/
│   │   │   └── app_user.dart
│   │   ├── presentation/
│   │   │   ├── sign_in_view.dart
│   │   │   └── sign_in_view_model.dart
│   │   └── providers.dart        # Riverpod exposure for this feature
│   │
│   ├── properties/               # Propriedade + members
│   │   ├── data/
│   │   │   ├── property_service.dart
│   │   │   ├── member_service.dart
│   │   │   └── property_repository.dart
│   │   ├── domain/
│   │   │   ├── property.dart
│   │   │   └── property_role.dart
│   │   ├── presentation/
│   │   │   ├── property_list_view.dart
│   │   │   ├── property_list_view_model.dart
│   │   │   ├── property_detail_view.dart
│   │   │   └── property_switcher_widget.dart
│   │   └── providers.dart
│   │
│   ├── paddocks/                 # Piquete
│   ├── lots/                     # Lote (operacional)
│   ├── animals/                  # Animal (+ numeração)
│   ├── atf/                      # LoteATF + DG + prenhez
│   ├── sanitary/                 # Aplicação sanitária + snapshot
│   ├── expenses/                 # Gastos por piquete
│   └── shell/                    # AppShell, NavRail, current-property context
│
└── l10n/                         # pt-BR primary
```

**Why feature-first, not layer-first:**
- The team is small; features map cleanly to user-facing modules.
- Each feature can be built/tested/deleted as a unit.
- Cross-feature imports are rare — the only real share is `core/` and `domain/`, plus a couple of selectors (current property).
- Layer-first (`lib/views`, `lib/models`, `lib/services`) collapses once you have ~7 features and everything depends on everything.

**Why keep `core/` and `data/`:**
- `core/` = zero-dependency helpers used anywhere.
- `data/` = shared infra (Supabase client provider, realtime channel factory). Not a feature.

#### Riverpod architecture

Use **riverpod 2.x+ with code generation** (`@riverpod`). Mental model:

| Riverpod construct | Use for | Example |
|--------------------|---------|---------|
| `Provider` (synchronous) | Pure-compute, services, derived values | `supabaseClientProvider`, `currentPropertyIdProvider` |
| `FutureProvider` | One-shot async reads (rare — prefer AsyncNotifier) | One-off config fetch |
| `StreamProvider` | Supabase Realtime subscriptions | `animalsStreamProvider(lotId)` |
| **`AsyncNotifier`** | Feature state that is async + mutable (the common case) | `AnimalsController`, `LotsController` |
| `Notifier` | Synchronous mutable state | `filterState`, `formState` |

**Recommended pattern per CRUD screen:**

```
// features/animals/presentation/animals_controller.dart
@riverpod
class AnimalsController extends _$AnimalsController {
  @override
  Future<List<Animal>> build(String lotId) async {
    // ref.watch(currentPropertyIdProvider) triggers rebuild on property switch
    final repo = ref.watch(animalRepositoryProvider);
    return repo.listByLot(lotId);
  }

  Future<void> create(CreateAnimalCommand cmd) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(animalRepositoryProvider);
      await repo.create(cmd);
      return repo.listByLot(cmd.lotId);
    });
  }
}
```

Rules of thumb:
- **One AsyncNotifier per screen-shaped query**, not per table. The UI decides the shape.
- **Never call SupabaseClient from a ViewModel.** Always go through a repository.
- **Invalidate, don't mutate optimistically** in the MVP — use `ref.invalidate(animalsControllerProvider(lotId))` after a mutation. Optimistic UI can be added later per-feature.
- **`currentPropertyIdProvider` is the tenant axis.** Every property-scoped query `ref.watch`es it so switching property rebuilds everything automatically.

#### GoRouter for web-first

Web-first means URLs must be real and shareable. Use GoRouter with nested `ShellRoute` for the persistent nav rail + property switcher.

```
/sign-in
/                                  → redirect to first property or /select-property
/select-property
/p/:propertyId                     → ShellRoute (holds property context)
  /p/:propertyId/dashboard
  /p/:propertyId/paddocks
  /p/:propertyId/paddocks/:paddockId
  /p/:propertyId/lots/:lotId
  /p/:propertyId/lots/:lotId/animals/:animalId
  /p/:propertyId/atf
  /p/:propertyId/atf/:atfId
  /p/:propertyId/sanitary
  /p/:propertyId/sanitary/:applicationId    # immutable view
  /p/:propertyId/expenses
```

Key patterns:
- **`propertyId` in the URL** is the multi-tenant key. When it changes, `currentPropertyIdProvider` re-emits, all providers rebuild.
- **`redirect`** on the root and on every shell route: if user not signed in → `/sign-in`. If signed in but no propertyId path → `/select-property`. If propertyId not in user's membership list → `/select-property` (not 404 — security-sensitive).
- **`refreshListenable`** tied to an auth-state stream so route refreshes on sign-in/out.
- **Deep links survive refresh** because the router is declarative and property context is parsed from the URL, not held in memory only.

---

### Supabase Structure

#### Tables (MVP scope)

| Table | Purpose | Soft delete |
|-------|---------|-------------|
| `profiles` | App user, 1:1 with `auth.users` | No |
| `properties` | Propriedade | Yes |
| `property_members` | User ↔ Property pivot with role | No (hard delete = revoke) |
| `paddocks` (piquetes) | Piquete within Property | Yes |
| `lots` | Lote operacional within Paddock | Yes |
| `animals` | Animal within Lot, unique number per property | Yes |
| `animal_number_sequences` | Per-property, per-category counter | No |
| `atf_lots` | LoteATF (reprodutivo, independente) | Yes |
| `atf_memberships` | Animal ↔ ATF pivot, 1 active per animal | Yes |
| `sanitary_applications` | Aplicação + `lot_snapshot` JSONB | Yes (append-only ideally) |
| `expenses` | Gasto por piquete | Yes |

#### RLS policy architecture

**Pattern: "everything anchors on property_members"**

Every property-scoped table gets a policy that says: "you can see/modify this row iff you are a member of its property (with appropriate role)."

Create a single **SECURITY DEFINER function** used by every policy:

```sql
-- Returns true if auth.uid() has any role in property_id
create or replace function app.is_member_of(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from property_members
    where user_id = auth.uid()
      and property_id = p_property_id
  );
$$;

-- Role-aware variant
create or replace function app.has_role(p_property_id uuid, p_roles text[])
returns boolean ...
```

Then every table:

```sql
-- Example: paddocks
alter table paddocks enable row level security;

create policy paddocks_select on paddocks
for select using (app.is_member_of(property_id));

create policy paddocks_write on paddocks
for all using (app.has_role(property_id, array['owner','vet']))
with check (app.has_role(property_id, array['owner','vet']));
```

**Critical performance tips:**
1. **Wrap `auth.uid()` in a subquery** in policies — `(select auth.uid())` — so PostgreSQL caches it per-statement instead of per-row. Documented Supabase gotcha; order-of-magnitude difference on large tables.
2. **Index the tenancy column.** Every property-scoped table MUST have an index on `property_id`. RLS filters become sequential scans without it.
3. **Index `property_members(user_id, property_id)`** — that's the hot lookup behind every policy.
4. **Use `security definer` helper functions** so the planner inlines the membership check efficiently and you don't duplicate logic across policies.
5. **Deeply nested tables (animals, applications) still carry `property_id`** redundantly. Don't try to join through lot→paddock→property at policy time — denormalize the tenant key.

#### Postgres functions (RPC) for atomic ops

Client code must NEVER do these — use RPC functions invoked from the client via `supabase.rpc('name', { ... })`:

| RPC function | Why DB-side |
|--------------|-------------|
| `create_animals_batch(lot_id, category, count, initial_body_score)` | Numeração needs `SELECT ... FOR UPDATE` on `animal_number_sequences` + insert of N animals atomically. Race-condition-proof. |
| `record_sanitary_application(lot_id, application_data)` | Must atomically: read current lot composition, freeze into `lot_snapshot` JSONB, insert row. Single transaction guarantees snapshot consistency. |
| `start_atf(atf_id, animal_ids)` | Must check no animal is currently in an active ATF; insert memberships; fail if conflict. Uses unique partial index + explicit error. |
| `move_animals(animal_ids, target_lot_id)` | Cross-lot moves, keeps audit log if needed. |
| `soft_delete_X(id)` | Consistent deleted_at/deleted_by writing. |

**Guideline:** if an operation spans >1 row and needs consistency guarantees, it's an RPC. If it's a single-row CRUD, it's a regular PostgREST query.

#### Realtime (Supabase Realtime)

MVP scope is modest ("sistema assume conectividade", no offline). Realtime gives pleasant UX when two people look at the same property.

Recommended usage:
- Subscribe on **list screens** only (animals-by-lot, paddocks, expenses).
- **Don't subscribe per-row** in detail screens — fetch once and let navigation re-read.
- Subscribe filtered by `property_id` (Realtime RLS respects your policies, and the filter reduces bandwidth).
- Wire a `StreamProvider` per list screen that mirrors the `AsyncNotifier`'s shape.

**Defer** realtime until after CRUD phases are stable. It's a polish layer, not a correctness requirement.

#### Storage

Not required for MVP per PROJECT.md. Reserve a bucket design for later:
- `property-assets/{property_id}/animal/{animal_id}/photo.jpg`
- RLS policies on `storage.objects` that mirror `property_members`.

#### Edge Functions vs client vs Postgres functions

Decision matrix:

| Logic type | Where |
|------------|-------|
| Simple CRUD, form validation | Client (Flutter) |
| Multi-row atomic mutation, uniqueness, snapshots | **Postgres function (RPC)** |
| Webhooks, 3rd-party integrations, scheduled jobs | Edge Functions (none needed MVP) |
| PDF / report generation | Edge Function (post-MVP) |

**Keep Edge Functions out of MVP.** They add a deploy pipeline and cold-start latency. Postgres functions cover all MVP needs.

---

### Component Boundaries

```
┌──────────────────────────────────────────────────────────────┐
│                       Flutter Client                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Presentation (Widgets + ViewModels via Riverpod)      │  │
│  │  - Views read AsyncValue<T> from controllers           │  │
│  │  - Commands call controller methods                    │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       │ reads/commands                       │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │  Repositories (business rules, mapping)                │  │
│  │  - PropertyRepo, LotRepo, AnimalRepo, SanitaryRepo...  │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │  Services (thin Supabase wrappers, return DTOs)        │  │
│  │  - table queries, rpc calls, realtime channels         │  │
│  └────────────────────┬───────────────────────────────────┘  │
└───────────────────────┼──────────────────────────────────────┘
                        │ HTTPS / WebSocket
┌───────────────────────▼──────────────────────────────────────┐
│                       Supabase                               │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────┐   │
│  │ Auth         │  │ PostgREST   │  │ Realtime           │   │
│  │ (JWT)        │  │ (REST API)  │  │ (WebSocket)        │   │
│  └──────┬───────┘  └──────┬──────┘  └─────────┬──────────┘   │
│         │                 │                   │              │
│  ┌──────▼─────────────────▼───────────────────▼──────────┐   │
│  │  PostgreSQL                                           │   │
│  │  - Tables with RLS                                    │   │
│  │  - app.is_member_of() helpers                         │   │
│  │  - RPC functions (numbering, snapshot, ATF)           │   │
│  │  - Triggers (updated_at, soft delete)                 │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**Invariants (never cross these):**
- Widgets never import Supabase SDK.
- Repositories never import Flutter widgets.
- Services never hold state.
- Business rules that MUST NOT be bypassed live in Postgres (RLS + RPC + constraints). Client-side checks are UX, not security.

---

### Data Flow

**Read flow (list screen):**
```
Widget reads animalsControllerProvider(lotId)
  → AsyncNotifier.build()
    → ref.watch(currentPropertyIdProvider)         # tenant axis
    → AnimalRepository.listByLot(lotId)
      → AnimalService.selectByLot(lotId)           # supabase.from('animals').select()...
        → PostgREST
          → RLS filters by property_members
          → returns rows
      → DTO -> Animal domain object
    ← List<Animal>
  ← AsyncData<List<Animal>>
Widget renders
```

**Write flow (create animals batch):**
```
View calls controller.create(CreateAnimalsBatchCommand)
  → AnimalsController.create()
    → AnimalRepository.createBatch(cmd)
      → AnimalService.rpcCreateAnimalsBatch(...)
        → supabase.rpc('create_animals_batch', { ... })
          → Postgres function:
              BEGIN
                SELECT last_number FROM animal_number_sequences
                  WHERE property_id=? AND category=? FOR UPDATE;
                UPDATE animal_number_sequences SET last_number = last_number + N;
                INSERT INTO animals (... generate_series(...)) RETURNING *;
              COMMIT
    ← List<Animal>
  → ref.invalidate(animalsControllerProvider(lotId))
Widget re-renders
```

**Write flow (record sanitary application — snapshot):**
```
View submits application form
  → SanitaryController.recordApplication(cmd)
    → SanitaryRepository.record(cmd)
      → SanitaryService.rpcRecordApplication(lotId, applicationData)
        → Postgres function:
            BEGIN
              SELECT id, number, category, body_score
                FROM animals
                WHERE lot_id=? AND deleted_at IS NULL;
              -- aggregate into JSONB array = lot_snapshot
              INSERT INTO sanitary_applications
                (property_id, lot_id, applied_at, lot_snapshot, payload)
                VALUES (?, ?, now(), ?::jsonb, ?::jsonb);
            COMMIT
    ← SanitaryApplication
  → navigate to immutable detail view
```

---

## Build Order

Build **bottom-up on the hierarchy but top-down on value**: user must be able to see a property before animals exist. The riskiest integrations (numeração, snapshot, ATF uniqueness) should get a **vertical slice prototype** in Phase 1 to retire risk early.

### Phase 0: Foundation (prerequisite to everything)

Must be complete before any feature work.

1. **Supabase project + local dev** — `supabase init`, `supabase start`, migrations folder committed.
2. **Flutter project skeleton** — Riverpod, GoRouter, Supabase SDK, freezed/json_serializable, code-gen pipeline.
3. **Theme + AppShell + responsive layout** — nav rail on web, bottom nav on mobile.
4. **Auth flow** — sign-in, sign-up, password reset. `profiles` table + trigger on `auth.users` insert.
5. **`currentPropertyProvider` + property switcher + guard routes** — even if the property list is hard-coded initially. Gets the multi-tenant axis wired from day one.

Why first: every downstream feature depends on "I have a propertyId". Wiring this late is catastrophic.

### Phase 1: Multi-tenant core + risk retirement

1. **Properties + property_members + RLS skeleton** — create property, list properties for user, invite member (can be simple email-based post-MVP; for now, seed via SQL). **Every subsequent table inherits this RLS pattern.**
2. **Risk-retirement prototypes (isolated, throwaway if needed):**
   - Animal numbering RPC with concurrency test (two clients creating batches simultaneously).
   - Snapshot JSONB insertion + retrieval.
   - ATF uniqueness partial unique index test.
3. **Paddocks (Piquete) CRUD** — simplest property-child. Validates the entire vertical slice end-to-end: RLS, GoRouter nested route, Riverpod controller, form, list.

Why: Phase 1 de-risks the three technically hardest invariants before they're load-bearing.

### Phase 2: Operational hierarchy

4. **Lots (Lote operacional) CRUD** — belongs to Paddock. Display UA totals (computed).
5. **Animals CRUD + batch creation with numbering** — promote the Phase 1 numbering prototype to production. Individual animal view. Edit body score / category.
6. **Move animals between lots** — RPC, ensures history is preserved (MVP can be simple overwrite; richer history post-MVP).

Why: Core value depends on animals existing and being countable by lot.

### Phase 3: Reproductive (ATF)

7. **LoteATF CRUD** — independent entity, not tied to paddock.
8. **Animal ↔ ATF memberships** — uniqueness enforcement (1 active ATF per animal).
9. **DG (diagnóstico gestação) + % prenhez calculation** — derived view / stored aggregate.

Why: Reproductive is independent of paddock/lot structure and can be built in parallel with Phase 2's latter half if a second dev exists.

### Phase 4: Sanitary (snapshot)

10. **Sanitary applications with frozen snapshot** — promote Phase 1 snapshot prototype.
11. **Immutable detail view** — no edit UI; only cancel-with-reason post-MVP.
12. **Application history per lot / per animal (via snapshot lookup).**

Why: Depends on animals existing (Phase 2) but not on ATF (Phase 3). Can parallelize with Phase 3.

### Phase 5: Financial

13. **Expenses per paddock** — simplest CRUD, lowest risk.
14. **Aggregations** — total per paddock, per period.

### Phase 6: Polish

15. **Realtime subscriptions on list screens.**
16. **Reader role implementation** (if not done in Phase 1 RLS).
17. **Empty states, error states, loading states audit.**

### Dependency graph

```
Phase 0 (Auth, AppShell, currentPropertyProvider)
   │
   ▼
Phase 1 (Properties + RLS + risk prototypes + Paddocks)
   │
   ├────────────────┬─────────────────┐
   ▼                ▼                 ▼
Phase 2 (Lots,   Phase 3 (ATF,    Phase 5 (Expenses —
Animals,         DG, prenhez)     depends only on Paddocks)
numbering)          │
   │                │
   └────────┬───────┘
            ▼
        Phase 4 (Sanitary — needs Animals from Phase 2)
            │
            ▼
        Phase 6 (Realtime, polish)
```

**Parallelizable if multiple devs:**
- Phase 3 (ATF) and Phase 5 (Expenses) are independent of each other and only share Phase 1 foundation.
- Phase 4 (Sanitary) only needs Animals → can start once Phase 2 step 5 lands, overlapping with Phase 3.

**Solo-dev recommended order:** 0 → 1 → 2 → 4 → 3 → 5 → 6 (sanitary before ATF because it exercises the snapshot pattern second-time-through and has more immediate user-visible value for the core persona, veterinarian).

---

## Critical Design Decisions

Decisions that MUST be made before Phase 2 because reversing them is expensive.

### 1. Denormalized `property_id` on every property-scoped table

**Decision:** Every table that belongs to a property — animals, lots, paddocks, ATF, applications, expenses — carries `property_id` as a direct column (not derived via joins).

**Trade-off:** +1 column per table, must be kept consistent (enforce via trigger or RPC only). Saves: every RLS policy, every index, every query stays flat and fast.

**Alternative rejected:** Join-based RLS (`USING (EXISTS (SELECT 1 FROM lots JOIN paddocks ON ... WHERE paddocks.property_id IN ...))`). Becomes unmaintainable and kills planner performance at scale.

### 2. RLS everywhere, no `service_role` in client

**Decision:** Client uses anon key only. `service_role` is server-side (migrations, seed). RLS is the ONLY security layer the client sees.

**Trade-off:** Every table needs a policy from day one. Forgetting one = silent data leak OR silent empty result (depending on SELECT vs INSERT). Mitigation: test harness with a "logged-in as user B" session that tries to access user A's data on every PR.

### 3. Soft delete via `deleted_at` column, hidden via RLS or view

**Decision:** `deleted_at timestamptz NULL`. Queries filter `WHERE deleted_at IS NULL`. Either bake into RLS policy or expose as an `_active` view.

**Trade-off:** Queries must always remember the filter. Benefit: histórico reprodutivo/sanitário keeps referential integrity even after an animal is "deleted".

**Recommendation:** Filter via RLS policy `USING (deleted_at IS NULL)` for the default `SELECT`. Add a separate policy or dedicated RPC `list_deleted_X()` for admin restoration flows if needed. This keeps the happy path clean.

### 4. Auto-numbering via SELECT FOR UPDATE on a sequence table, not SERIAL

**Decision:** `animal_number_sequences(property_id, category, last_number)` + `SELECT ... FOR UPDATE` in the RPC.

**Trade-off:** Serializes inserts on the same (property, category). At farm scale (hundreds to thousands of animals, not sustained inserts), this is fine. Alternatives (`SERIAL` global, or client-side max+1) either produce non-per-property-unique numbers or race catastrophically.

**Reject:** Postgres sequences (`CREATE SEQUENCE`) — they're global, not per-property-per-category.

### 5. Snapshot = JSONB column, validated by schema version

**Decision:** `sanitary_applications.lot_snapshot jsonb not null` containing an array of `{animal_id, number, category, body_score}` + a `snapshot_schema_version smallint`. Populated in RPC, never mutated after.

**Trade-off:** JSONB is flexible but loses FK integrity — an animal_id in the snapshot might reference a deleted row. That's acceptable (soft-delete preserves it) and even desirable (snapshot is independent of current state). Schema version lets you migrate shape if needed.

**Index:** `CREATE INDEX ... USING gin (lot_snapshot jsonb_path_ops)` only if you need to query inside snapshots (e.g., "show all applications that included animal X"). Start without; add if a real query needs it.

### 6. ATF active-membership uniqueness via partial unique index

**Decision:**
```sql
create unique index one_active_atf_per_animal
  on atf_memberships (animal_id)
  where deleted_at is null and status = 'active';
```

**Trade-off:** Constraint enforced at DB level, impossible to bypass. Client gets a `23505` error to translate into UX. Alternative (application-level check) is race-prone.

### 7. Category encoded as enum-like text with `CHECK` constraint

**Decision:** `category text check (category in ('vaca','terneiro','terneira','touro','boi','novilho','novilha'))`. UA multiplier computed client-side via a map OR stored in a `categories` reference table.

**Trade-off:** Text enum is easier to evolve than Postgres `ENUM` types (which are painful to alter). Reference table adds a join but makes adding categories a data change, not a migration.

**Recommendation:** Start with text + CHECK + client-side map. Promote to reference table if categories become user-editable (out of scope for MVP).

### 8. Frozen UA calculation in snapshot, live calc elsewhere

**Decision:** Current UA total is computed at query time (client or `generated column`). In snapshots, UA is frozen-calculated at snapshot creation.

**Trade-off:** Live calc is cheap (`sum(ua_multiplier)` over animals in lot). Freezing it in snapshot is non-negotiable for audit. Don't persist live UA in the `lots` table — invalidation is painful.

### 9. GoRouter `propertyId` in URL, not in global state only

**Decision:** `/p/:propertyId/...` on every authed route. The URL is the source of truth for current property.

**Trade-off:** URLs are a bit longer. Gains: browser back/forward, refresh, deep links, shareable links, multiple tabs on different properties — all work automatically. On mobile (secondary), the URL is invisible; no cost.

### 10. Riverpod code generation vs legacy API

**Decision:** Use `@riverpod` / `@Riverpod(keepAlive: ...)` code generation (riverpod_generator). Avoid `StateNotifier`/`ChangeNotifierProvider` legacy APIs.

**Trade-off:** Adds `build_runner` step. Gains: type-safe families, auto-dispose by default, alignment with current Riverpod docs and examples (2024–2026).

---

## Database Schema Sketch

High-level. Not a migration file — shape and constraints only. `uuid_generate_v4()` assumed available.

```sql
-- ============ profiles (1:1 with auth.users) ============
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  created_at timestamptz not null default now()
);

-- ============ properties ============
create table properties (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index properties_not_deleted on properties (id) where deleted_at is null;

-- ============ property_members (tenancy pivot) ============
create type property_role as enum ('owner','vet','reader');

create table property_members (
  property_id uuid not null references properties(id) on delete cascade,
  user_id     uuid not null references profiles(id)    on delete cascade,
  role        property_role not null,
  created_at  timestamptz not null default now(),
  primary key (property_id, user_id)
);
create index property_members_user_idx on property_members (user_id, property_id);

-- ============ paddocks (piquetes) ============
create table paddocks (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,
  name text not null,
  area_ha numeric(12,2),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (property_id, name) where deleted_at is null
);
create index paddocks_property_idx on paddocks (property_id) where deleted_at is null;

-- ============ lots (operational) ============
create table lots (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,
  paddock_id  uuid not null references paddocks(id),
  name text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index lots_property_idx on lots (property_id) where deleted_at is null;
create index lots_paddock_idx on lots (paddock_id)  where deleted_at is null;

-- ============ animal numbering sequences ============
create table animal_number_sequences (
  property_id uuid not null references properties(id) on delete cascade,
  category    text not null,
  last_number int  not null default 0,
  primary key (property_id, category),
  check (category in ('vaca','terneiro','terneira','touro','boi','novilho','novilha'))
);

-- ============ animals ============
create table animals (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,  -- denorm
  lot_id      uuid not null references lots(id),
  category    text not null,
  number      int  not null,
  body_score  smallint check (body_score between 1 and 5),
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  check (category in ('vaca','terneiro','terneira','touro','boi','novilho','novilha')),
  unique (property_id, category, number)  -- number unique per property+category
);
create index animals_lot_idx on animals (lot_id) where deleted_at is null;
create index animals_property_idx on animals (property_id) where deleted_at is null;

-- ============ ATF (reproductive lots) ============
create table atf_lots (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,
  name text not null,
  started_at date not null,
  closed_at  date,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create type atf_status as enum ('active','dg_positive','dg_negative','closed');

create table atf_memberships (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id),   -- denorm
  atf_id    uuid not null references atf_lots(id) on delete cascade,
  animal_id uuid not null references animals(id),
  status    atf_status not null default 'active',
  dg_at     timestamptz,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (status <> 'active' or dg_at is null)  -- only set dg_at when leaving active
);
-- Enforce: at most one active ATF per animal
create unique index one_active_atf_per_animal
  on atf_memberships (animal_id)
  where deleted_at is null and status = 'active';

-- Enforce: only vaca/novilha allowed (check via trigger referencing animals.category)

create index atf_memberships_atf_idx    on atf_memberships (atf_id)    where deleted_at is null;
create index atf_memberships_animal_idx on atf_memberships (animal_id) where deleted_at is null;

-- ============ sanitary applications (FROZEN SNAPSHOT) ============
create table sanitary_applications (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,  -- denorm
  lot_id      uuid not null references lots(id),
  applied_at  timestamptz not null default now(),
  applied_by  uuid not null references profiles(id),
  payload     jsonb not null,          -- product, dose, notes
  lot_snapshot jsonb not null,         -- [{animal_id, number, category, body_score}, ...]
  snapshot_schema_version smallint not null default 1,
  created_at  timestamptz not null default now()
  -- intentionally no deleted_at / no UPDATE policy — immutable
);
create index sanitary_applications_lot_idx      on sanitary_applications (lot_id);
create index sanitary_applications_property_idx on sanitary_applications (property_id);

-- ============ expenses ============
create table expenses (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references properties(id) on delete cascade,
  paddock_id  uuid not null references paddocks(id),
  amount      numeric(14,2) not null check (amount >= 0),
  category    text not null,
  description text,
  incurred_at date not null,
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index expenses_property_idx on expenses (property_id) where deleted_at is null;
create index expenses_paddock_idx  on expenses (paddock_id)  where deleted_at is null;
```

### Key constraints

1. **`animals.unique (property_id, category, number)`** — enforces per-property-per-category uniqueness. Combined with RPC + FOR UPDATE, race-safe.
2. **`atf_memberships one_active_atf_per_animal`** partial unique index — only 1 active ATF per animal.
3. **Trigger on atf_memberships** to assert `animals.category IN ('vaca','novilha')`. Can't express via check constraint because it references another table.
4. **No update policy on sanitary_applications** — immutable by RLS.
5. **`property_id` denormalized** on deep tables (animals, atf_memberships, sanitary_applications, expenses) for fast RLS policies and indexes.

### Key RLS policies (pattern)

```sql
-- Helper
create schema if not exists app;
create or replace function app.is_member_of(p uuid)
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from property_members
    where property_id = p and user_id = (select auth.uid())
  );
$$;

create or replace function app.has_role(p uuid, roles property_role[])
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from property_members
    where property_id = p
      and user_id = (select auth.uid())
      and role = any(roles)
  );
$$;

-- Example: animals
alter table animals enable row level security;

create policy animals_select on animals for select
using (app.is_member_of(property_id) and deleted_at is null);

create policy animals_write on animals for all
using      (app.has_role(property_id, array['owner','vet']::property_role[]))
with check (app.has_role(property_id, array['owner','vet']::property_role[]));

-- Example: sanitary_applications (no UPDATE / no DELETE)
alter table sanitary_applications enable row level security;

create policy sanapp_select on sanitary_applications for select
using (app.is_member_of(property_id));

create policy sanapp_insert on sanitary_applications for insert
with check (app.has_role(property_id, array['owner','vet']::property_role[]));
-- no update policy, no delete policy = immutable by RLS
```

### Key RPC functions

```sql
-- Atomic batch animal creation with race-safe numbering
create or replace function create_animals_batch(
  p_lot_id uuid,
  p_category text,
  p_count int,
  p_body_score smallint
) returns setof animals
language plpgsql security invoker as $$
declare
  v_property_id uuid;
  v_start_number int;
begin
  select property_id into v_property_id from lots
    where id = p_lot_id and deleted_at is null;
  if v_property_id is null then raise exception 'lot not found'; end if;

  -- Lock per (property, category)
  insert into animal_number_sequences (property_id, category, last_number)
    values (v_property_id, p_category, 0)
    on conflict do nothing;

  update animal_number_sequences
     set last_number = last_number + p_count
   where property_id = v_property_id and category = p_category
   returning last_number - p_count into v_start_number;

  return query
    insert into animals (property_id, lot_id, category, number, body_score)
    select v_property_id, p_lot_id, p_category, v_start_number + g, p_body_score
      from generate_series(1, p_count) as g
    returning *;
end $$;

-- Atomic snapshot + application
create or replace function record_sanitary_application(
  p_lot_id uuid,
  p_payload jsonb
) returns sanitary_applications
language plpgsql security invoker as $$
declare
  v_property_id uuid;
  v_snapshot jsonb;
  v_row sanitary_applications;
begin
  select property_id into v_property_id from lots
    where id = p_lot_id and deleted_at is null;
  if v_property_id is null then raise exception 'lot not found'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'animal_id', id,
           'number', number,
           'category', category,
           'body_score', body_score
         )), '[]'::jsonb)
    into v_snapshot
    from animals where lot_id = p_lot_id and deleted_at is null;

  insert into sanitary_applications
    (property_id, lot_id, applied_by, payload, lot_snapshot)
    values (v_property_id, p_lot_id, (select auth.uid()), p_payload, v_snapshot)
    returning * into v_row;

  return v_row;
end $$;
```

---

## Open Questions / Flags for Later

- **Invitation flow** for adding a veterinário to a property — Supabase doesn't have first-class invitations; likely need Edge Function + magic link. Defer past MVP or use SQL-seed for first users.
- **Audit log** (who moved which animal when) — out of MVP scope but schema (`animals.lot_id` change history) should leave room. Recommend: add `animal_events` table in Phase 6 if needed.
- **Export to CSV/Excel** — out of MVP but users will ask. Flutter web has `universal_html` patterns.
- **Offline** explicitly deferred; when added, Supabase patterns break (local SQLite + sync queue). Redesign required, not incremental.
- **Category → allowed ATF check** via trigger — need to decide on error code/message contract for UX.
- **`currentPropertyProvider` caching** on sign-in — fetch memberships once, keep in memory; re-fetch on auth change. Don't re-fetch per route.

---

## Sources and Confidence

| Area | Confidence | Basis |
|------|------------|-------|
| Flutter MVVM + feature-first layout | HIGH | Official Flutter architecture guide (docs.flutter.dev/app-architecture/guide), fetched 2026-04-24 |
| Riverpod patterns (AsyncNotifier, codegen) | HIGH | Riverpod 2.x is the current recommended API; documented heavily in 2024–2026 |
| GoRouter nested routing | HIGH | Official Flutter routing guidance for web-first apps |
| Supabase RLS patterns (auth.uid() subquery optimization, is_member_of pattern) | HIGH | Well-documented Supabase performance guidance and multi-tenant examples |
| RPC > client logic for atomic ops | HIGH | Standard PostgREST + Supabase pattern |
| Per-property numbering via SELECT FOR UPDATE | HIGH | Standard PostgreSQL concurrency pattern |
| Partial unique index for "1 active ATF per animal" | HIGH | Standard PostgreSQL idiom |
| JSONB for snapshot | HIGH | Standard PostgreSQL pattern; schema_version a well-known safeguard |
| Realtime subscription scoping guidance | MEDIUM | Training data; confirm bandwidth/perf on staging before committing to per-list subscriptions |
| Soft delete via RLS filter | MEDIUM | Works, but teams sometimes prefer dedicated views; either is defensible |

Sources fetched: https://docs.flutter.dev/app-architecture/guide
Other sources (Supabase RLS docs, Riverpod docs) blocked by WebFetch permission at research time — claims grounded in training data through Jan 2026 and cross-checked against the fetched Flutter guide. No contradictions found.
