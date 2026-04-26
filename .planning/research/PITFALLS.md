# Pitfalls Research — Campo Gestor

**Domain:** Flutter web + Supabase for livestock/rural property management
**Researched:** 2026-04-24
**Confidence:** MEDIUM (WebSearch was unavailable — findings derived from codebase/platform knowledge, Supabase/Flutter known limitations, and livestock-software anti-patterns. Flag for validation during Phase 1 spikes.)

---

## Critical Pitfalls (Address Early)

These cause rewrites, data corruption, or multi-tenant security breaches. Address in Phase 0/1.

---

### CP-1: Race condition on per-property animal numbering

**What goes wrong:**
Two users (or one user + a batch create) generate animals in the same property simultaneously. Both read `MAX(numero) = 500`, both insert `501`. Unique constraint fires on the second insert; or worse, if you use "SELECT MAX + 1" without a unique constraint, you silently get duplicates.

**Warning signs:**
- Code that does `SELECT MAX(numero) FROM animal WHERE propriedade_id = X` then inserts with the result
- Application-side incrementing in Dart/Flutter
- Using Supabase client to "compute next number" client-side
- No unique constraint on `(propriedade_id, numero)`
- Intermittent "duplicate key" errors when creating lots in bulk

**Prevention:**
1. **Database-side sequence per property** — use a `propriedade_sequencia` table with `(propriedade_id, categoria, next_value)` and a `SELECT ... FOR UPDATE` inside a PL/pgSQL function, OR a single incrementing counter per property.
2. Wrap animal creation in a PostgreSQL function (`create_animals_for_lote`) called via `supabase.rpc()`. The function holds the row lock and assigns numbers atomically.
3. Add `UNIQUE (propriedade_id, numero)` constraint as a safety net.
4. Never generate numbers in Dart — the client is not the source of truth.
5. For bulk creation (e.g., create 80 vacas), assign numbers in a single transaction, not a loop of inserts.

**Phase:** Phase 1 (data model + animal creation). Must be designed before the first animal is inserted.

---

### CP-2: Frozen snapshot accidentally mutated

**What goes wrong:**
Sanitary snapshot (`aplicacao_snapshot` / `aplicacao_animais`) is intended to be immutable — it preserves which animals were in the lot at application time. Devs later add "edit application" feature, or a cascade deletes rows when animals are removed from a lot, and the historical record is destroyed.

**Warning signs:**
- Snapshot table has no `CHECK` or trigger preventing UPDATE/DELETE
- Foreign key from snapshot rows to `animal` with `ON DELETE CASCADE`
- UI offers "edit past application" without explicit "correction entry" workflow
- Developers talk about "fixing" historical applications instead of issuing corrections
- Soft-deleting an animal makes it vanish from past application records

**Prevention:**
1. Create snapshot rows that **denormalize** animal identity at application time: store `animal_id`, `animal_numero`, `categoria`, `lote_id`, `lote_nome_at_time`, `aplicado_em`. Do not rely on live joins to rebuild history.
2. Add a row-level trigger on `aplicacao_animais` that raises on UPDATE or DELETE unless an explicit `app.allow_snapshot_mutation` session variable is set (reserved for admin/DB migrations).
3. FK to `animal` should be `ON DELETE RESTRICT` or `ON DELETE SET NULL` — never CASCADE.
4. "Correct an application" = create a correction record pointing to the original, not edit the original.
5. Revoke UPDATE/DELETE privileges on snapshot tables from `authenticated` role in RLS.

**Phase:** Phase 2 (sanitary module). The trigger/privilege lockdown must ship with the first snapshot feature.

---

### CP-3: Multi-tenant RLS gap — user A sees property B's animals

**What goes wrong:**
The most dangerous bug in multi-tenant SaaS: wrong policy, missing policy on a join table, or a view that bypasses RLS leaks a competitor's animals. In a veterinary app where one vet manages multiple fazendas, the blast radius is "client X sees client Y's herd."

**Warning signs:**
- RLS enabled on `propriedade` but not on child tables (`piquete`, `lote`, `animal`, `aplicacao`)
- RLS policies use `auth.uid() = user_id` on child tables instead of walking up to propriedade
- Permissions table (`propriedade_usuario`) without its own RLS policy — user can grant themselves access by inserting a row
- Tests only check "I can see my data" and never "I cannot see someone else's data"
- Views created without `security_invoker = true` bypass RLS
- Supabase functions using `SECURITY DEFINER` without explicit tenant checks
- `service_role` key ever shipped to the client

**Prevention:**
1. **RLS on every table**, no exceptions. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY; ALTER TABLE ... FORCE ROW LEVEL SECURITY;` — FORCE blocks even the table owner.
2. Policy template: all tenant data goes through a SECURITY DEFINER function `user_has_propriedade_access(uuid)` that checks the `propriedade_usuario` join table. Every child table's policy is `USING (user_has_propriedade_access(propriedade_id))`.
3. Child tables (piquete, lote, animal) must carry denormalized `propriedade_id` for fast RLS — do not force RLS to join 3 tables.
4. Add a **negative integration test** in CI: user A inserts data in property P1, user B (with no access) tries SELECT/INSERT/UPDATE/DELETE on P1's animal — all must fail.
5. Never use `service_role` from Flutter. Ever. Only from server-side functions (Edge Functions) with tenant checks.
6. `propriedade_usuario` permissions table has its own RLS: user can SELECT rows where they are the subject; INSERT/UPDATE/DELETE only via RPC that validates "requester is owner of the propriedade."
7. Audit: write a SQL script that lists every table and whether RLS is enabled. Run in CI.

**Phase:** Phase 0/1. RLS model must be locked before any multi-user feature ships.

---

### CP-4: Soft delete collides with unique constraints

**What goes wrong:**
"Soft delete em todas entidades" is a key decision. A user creates animal #123, soft-deletes it, tries to create another animal #123 (valid — the old one is retired). `UNIQUE (propriedade_id, numero)` blocks the insert because the deleted row still occupies the slot.

Same pain with propriedade names, piquete names, lote names — or any other "unique within parent" constraint.

**Warning signs:**
- `deleted_at` column but unique constraints ignore it
- Application code filters `WHERE deleted_at IS NULL` but the DB constraint doesn't
- "Duplicate key" errors after users re-use an identifier they thought was free
- RLS policies that don't filter `deleted_at` — users see "ghost" animals

**Prevention:**
1. Use **partial unique indexes**: `CREATE UNIQUE INDEX ON animal (propriedade_id, numero) WHERE deleted_at IS NULL;`. Standard technique in Postgres.
2. Decide up front: is number reusable after soft-delete? Product decision. Document in PROJECT.md. Default recommendation for livestock: **no reuse** — the animal's identity is historical. A "deleted" animal still exists in past applications and reproductive records; reusing its number creates forensic ambiguity. If you go this route, unique constraint is on `(propriedade_id, numero)` always, no partial index needed.
3. Every query (and every RLS policy) must filter `deleted_at IS NULL` unless deliberately showing deleted records.
4. Consider a view `animal_ativo AS SELECT * FROM animal WHERE deleted_at IS NULL` with RLS and use it by default — reduces bugs of forgetting the filter.
5. Cascading soft-deletes need to be explicit: deleting a lote does NOT automatically soft-delete its animals; define the business rule (probably "animals move to a default/holding lote" or "animals become lot-less and require re-assignment").

**Phase:** Phase 1 (data model). Soft-delete + unique strategy is a foundational decision.

---

### CP-5: Moving a lote is not transactional

**What goes wrong:**
"Moving a lot moves all animals." If this is done as N separate Supabase updates from Flutter, a network blip halfway through leaves animals split between two piquetes. Worse: concurrent edit by another user changes composition mid-move.

**Warning signs:**
- Flutter code that loops `supabase.from('animal').update({piquete_id: X}).eq(...)` per animal
- No "operation in progress" UI lock
- No audit trail of when/who moved a lote
- Partial-failure scenarios not tested

**Prevention:**
1. All composite operations (move lote, merge lotes, split lote, dissolve lote) go through a single PL/pgSQL function invoked via `supabase.rpc()`. The function is atomic — it fully succeeds or fully rolls back.
2. Use `SELECT ... FOR UPDATE` on the lote row to block concurrent edits.
3. Record an audit trail: `lote_movimento (lote_id, from_piquete, to_piquete, movido_por, movido_em, num_animais)`.
4. Flutter UI shows a modal/spinner; disables the button until RPC returns.
5. Idempotency key: if Flutter retries on flaky network, include an idempotency token so the operation doesn't apply twice.

**Phase:** Phase 2 (lote management).

---

### CP-6: Auth token refresh silently breaks long sessions

**What goes wrong:**
Supabase access token expires (1 hour default). `supabase-flutter` auto-refreshes in most cases — but on Flutter web, if the user keeps a tab open idle overnight, or switches tabs and the browser throttles timers, refresh can fail and subsequent queries return 401 or stale data. Realtime channels disconnect and don't re-subscribe.

**Warning signs:**
- "Random" 401 errors in logs after hours of idle
- Realtime stops updating but no error shown to user
- Users report "I have to reload the page in the morning"
- No global error interceptor catching auth failures
- `onAuthStateChange` handler not wired

**Prevention:**
1. Subscribe to `supabase.auth.onAuthStateChange` in a top-level Riverpod provider. On `tokenRefreshed`, re-establish Realtime channels. On `signedOut`, route to login.
2. Wrap Supabase calls in a repository layer that catches `AuthException` and triggers refresh-or-relogin flow.
3. Test: open app, set system clock forward 2 hours, verify the app recovers (or at least shows a clear "please sign in again" state — not a blank page).
4. On Flutter web, handle `visibilitychange` — when tab becomes visible, check auth state and refresh if needed.
5. Set session duration appropriately in Supabase dashboard — a vet in the field needs long sessions; consider 1-week refresh tokens with 1-hour access tokens.

**Phase:** Phase 1 (auth shell). Must be solid before multi-day testing.

---

### CP-7: Flutter web cold start is 5+ MB and 10+ seconds

**What goes wrong:**
Default Flutter web build ships a ~5 MB bundle (CanvasKit) with slow first paint. For a rural user on 3G or at the edge of farm Wi-Fi, this feels broken. They close the tab.

**Warning signs:**
- Not measuring time-to-interactive in real conditions
- No loading screen in `index.html` (blank white screen during load)
- Using CanvasKit renderer without considering download size
- Shipping all Material icons, not tree-shaken
- Large images/assets bundled instead of served by Supabase Storage

**Prevention:**
1. Build with `--wasm` (Dart2Wasm, now default-stable) where supported, or `--web-renderer html` if size matters more than fidelity — test both for your UI.
2. Deferred loading for heavy modules: `import 'relatorios.dart' deferred as relatorios;` — load reports/dashboards only when navigated to.
3. Pre-cache fonts and use `--tree-shake-icons`.
4. Custom loading HTML/CSS in `web/index.html` — no blank white screen. Show "Campo Gestor carregando..."
5. Measure on real hardware/network, not localhost. Budget: TTI < 5s on 4G after cache warm-up, < 10s cold.
6. Serve assets via Supabase Storage/CDN with long cache headers; only ship UI code in the Flutter bundle.
7. Revisit when Flutter Web Hot Restart / WasmGC improves — keep an eye on 2026 release notes.

**Phase:** Phase 1 (shell) — set the baseline. Revisit at Phase 3 (features complete) before launch.

---

## Moderate Pitfalls (Watch During Build)

### MP-1: N+1 queries with Supabase client

**What goes wrong:**
Classic rookie pattern in Flutter:
```dart
final lotes = await supabase.from('lote').select();
for (final lote in lotes) {
  final animais = await supabase.from('animal').select().eq('lote_id', lote.id);
}
```
A property with 40 lotes = 41 round trips, each 100-300ms. Listing page takes 15 seconds.

**Warning signs:**
- `for` loops containing `await supabase...`
- "Animal count per lote" loaded lazily per row
- Chrome DevTools Network tab shows dozens of requests on a list view
- Repository methods that return incomplete data and "let the UI load more"

**Prevention:**
- Use Supabase's nested select: `.select('*, animal(count)')` or `.select('*, animal(*)')`.
- For counts, use `.select('*, animal(count)', { count: 'exact' })`.
- For aggregations (sum UA per piquete), create a PostgreSQL view and query it once.
- Use `.in_('lote_id', loteIds)` to batch-fetch all animals for a page of lotes in one query.
- If you need denormalized aggregates (animal_count, ua_total) frequently, add them as columns maintained by trigger — materialized count.

---

### MP-2: Realtime subscription leaks

**What goes wrong:**
Page widget subscribes to a Supabase Realtime channel in `initState`, but never unsubscribes in `dispose`. User navigates around for an hour — dozens of zombie channels, WebSocket connection cap hit, or duplicate UI updates as a widget receives events multiple times.

**Warning signs:**
- `supabase.channel(...).subscribe()` called from widget code without matching `removeChannel`
- Memory profile grows over navigation
- Console shows "received message for unknown channel" or duplicate payloads
- Riverpod providers with realtime that aren't `autoDispose`

**Prevention:**
- Prefer Riverpod `StreamProvider.autoDispose` that wraps Supabase Realtime. The provider's `onDispose` removes the channel.
- One channel per logical subscription, named predictably; deduplicate.
- Subscribe at the screen level, not per-widget. Multiple widgets on the same screen read from a shared provider.
- In Phase 1, decide **which tables actually need realtime**. For campo-gestor, a vet entering data alone probably doesn't need realtime. Start without it; add per-feature if needed (e.g., "property dashboard auto-refreshes when another vet applies vaccine").

---

### MP-3: Riverpod `ref.watch` vs `ref.read` misuse

**What goes wrong:**
Using `ref.read` inside `build` when you meant `ref.watch`: UI doesn't rebuild when state changes. Or the inverse: `ref.watch` in an `onPressed` callback causes excessive rebuilds.

Other classic mistakes:
- Providers without `autoDispose` → stale data across navigation
- Family providers with `autoDispose` but widgets subscribe/unsubscribe rapidly → constant tear-up/tear-down
- Side-effects (navigation, snackbars) inside `build` instead of `ref.listen`
- Global mutable state instead of scoped providers
- Not using `ref.invalidate` after a mutation — UI shows stale data until the next reload

**Prevention:**
- Rule: `ref.watch` in `build`; `ref.read` in callbacks; `ref.listen` for side-effects.
- Default to `autoDispose` providers; opt out only for genuinely global state (auth, current property).
- Use `@riverpod` code-gen — reduces typos that compile but don't work as expected.
- After mutations, `ref.invalidate(provider)` explicitly. Train the team on this early.
- Establish a folder/naming convention (feature-scoped providers) so shared state is obvious.

---

### MP-4: Flutter web browser back-button breaks deep links

**What goes wrong:**
With Flutter's default Navigator 1.0, browser back button either goes to the previous page in browser history (leaving the URL bar pointing at a non-existent route) or does nothing useful. Deep links (`/propriedade/123/lote/456`) don't work when pasted fresh.

**Warning signs:**
- URL doesn't change when navigating within the app
- Refreshing the page loses state / routes to home
- Paste-a-link-to-a-coworker flow doesn't work
- Using `Navigator.push(MaterialPageRoute(...))` everywhere

**Prevention:**
- Use `go_router` (or Navigator 2.0 with `RouterConfig`). `go_router` is the de-facto standard in 2026.
- Define named routes for every screen: `/`, `/propriedades`, `/propriedades/:id`, `/propriedades/:id/lotes/:loteId`.
- Avoid stateful nested navigators unless necessary — they complicate URL sync.
- Test: every primary screen, open a fresh tab with its URL → it loads correctly.
- Browser back: test that it navigates to the logical previous screen, not a loading state.

---

### MP-5: Form handling at scale — giant forms with no draft save

**What goes wrong:**
Creating a lote involves: name, piquete, category, count, starting number, initial body score... possibly 20+ fields spread across tabs. Users lose work when they navigate away accidentally or the session refreshes. No validation feedback until submit.

Same for applying a vaccine: selecting animals from a lote of 300 cabeças.

**Warning signs:**
- Single giant `Form` widget with dozens of `TextFormField`s
- State lost on navigation / page refresh
- Validation only on submit; no inline errors as the user types
- No "are you sure you want to leave?" prompt
- Bulk-select UI for animals that re-renders the whole list on every tap

**Prevention:**
- Use `flutter_hooks` + `reactive_forms` or a structured form lib; don't manage TextEditingControllers by hand for 20+ fields.
- Auto-save draft to `localStorage` (Flutter web) or a `drafts` table in Supabase every N seconds.
- Wizard/stepper UX for multi-section forms (4 steps of 5 fields beats 1 form of 20 fields).
- For animal bulk-select: virtualized list (`ListView.builder`), selection held in a Set<animalId>, not a List; memoized item builder.
- Intercept `PopScope` (formerly `WillPopScope`) and browser `beforeunload` (Flutter web) to warn about unsaved changes.

---

### MP-6: Migration management chaos

**What goes wrong:**
Team edits schema in Supabase dashboard without writing migrations. Dev/staging/prod drift. A feature works locally, fails in prod. Rollback is impossible. Worse, RLS policies are edited by hand and nobody remembers why.

**Warning signs:**
- "It works in my Supabase project, not yours"
- Schema differences between environments
- No `supabase/migrations/` folder in Git
- RLS policies created via UI, never codified
- `supabase db diff` output is ever non-empty unexpectedly

**Prevention:**
- **Migrations-as-code from day 1.** Use `supabase CLI`. Every schema change is a file in `supabase/migrations/`. Commit to Git.
- Never edit production schema via dashboard. Treat it as read-only.
- Dev workflow: `supabase db reset` rebuilds local DB from migrations + seed — if that breaks, the migration is wrong.
- RLS policies are migrations, not dashboard clicks.
- Staging environment with production-like data volume (anonymized) to catch RLS performance regressions before prod.
- Tag migrations with a phase number (e.g., `20260501_phase1_core_schema.sql`) for traceability.

---

### MP-7: Realtime auth with RLS is tricky

**What goes wrong:**
Realtime subscription inherits the session's JWT. Users only receive events for rows they can see via RLS. Good. But: if auth state changes (logout/login, token refresh), the subscription doesn't automatically re-authenticate; it may silently stop delivering events or deliver events for the wrong user.

**Warning signs:**
- Realtime works initially but stops after token refresh
- Post-login, data doesn't update until page reload
- Users see events from their old session after switching properties

**Prevention:**
- On `onAuthStateChange`, tear down all Realtime channels and re-subscribe.
- Centralize channel management in a singleton service / Riverpod provider keyed by `auth.uid()` so it naturally rebuilds.
- Test: login as user A, subscribe, logout, login as user B — verify A's channels are gone and B sees only B's events.

---

### MP-8: Edge Functions cold start latency

**What goes wrong:**
Critical RPCs (create_animals_for_lote, move_lote) if implemented as Supabase Edge Functions instead of PL/pgSQL have 500ms+ cold starts. Users perceive lag. Also: Edge Functions run outside the DB transaction boundary — harder to guarantee atomicity.

**Prevention:**
- Business logic that is **pure data manipulation** (animal numbering, lote moves, snapshot creation) lives in PL/pgSQL functions invoked via `supabase.rpc()`. In-process, in-transaction, fast.
- Edge Functions only for things that truly need a non-DB runtime (sending email/WhatsApp, calling external APIs, heavy computation).
- Warm Edge Functions with a cron ping if latency matters.

---

### MP-9: Large list views without virtualization

**What goes wrong:**
A property can have thousands of animals. `Column(children: animais.map(...).toList())` renders all 3000 rows — frame time of several seconds, jank, memory pressure (worse on Flutter web than native).

**Prevention:**
- Always `ListView.builder` / `SliverList` with `itemCount`. Never `children: list.map(...)`.
- Paginate at the Supabase query level: `.range(from, to)` with an infinite scroll controller.
- For very large datasets, use a server-side search/filter instead of client-side list filtering.
- Index columns used for sort/filter in the DB (numero, lote_id, categoria).

---

### MP-10: Flutter web hot reload pitfalls during development

**What goes wrong:**
Flutter web hot-reload is weaker than on native. Some state is lost; some stale state persists. Devs debug phantom bugs that don't exist in production builds.

**Prevention:**
- When in doubt, full reload (`R` not `r`).
- Don't chase bugs that only reproduce after a chain of hot reloads — verify with a cold start.
- CI runs production-mode builds, not dev-mode.

---

## Domain Traps (Industry-Specific)

### DT-1: Conflating operational lote and LoteATF

**What goes wrong:**
Devs see "lote" everywhere and model it as one table with a `tipo` enum. Then business rules diverge: LoteATF accepts only vacas/novilhas, has a defined ciclo (prenhez diagnosis window), may pull animals from multiple operational lotes, and dissolves when the cycle ends. Operational lote is structural (where the animal lives). Mixing them poisons queries and UI.

**Warning signs:**
- Single `lote` table with `tipo IN ('operacional', 'atf')`
- Animal membership in two lotes handled by arrays or "active flag"
- UI shows ATF lotes in the "piquete composition" view (nonsensical — ATF has no piquete)
- Query "lote atual de X animal" is ambiguous

**Prevention:**
- **Two separate tables:** `lote` (operational, must have piquete_id, lifecycle = active/retired) and `lote_atf` (reproductive, has ciclo dates, no piquete).
- **Two separate membership tables:** animal has exactly one current `lote_id` (operational, FK) and may belong to zero or one active `lote_atf` via a `lote_atf_animal` association table.
- Explicit invariants enforced by triggers or constraints:
  - Animal's operational lote is always set (except transiently).
  - Animal is in at most one *active* LoteATF (`deleted_at IS NULL AND ciclo_encerrado_em IS NULL`). Partial unique index on `lote_atf_animal (animal_id) WHERE active`.
  - LoteATF rejects animals whose `categoria` is not vaca or novilha (trigger).
- UIs for "minha propriedade" vs "ATF em curso" are separate navigation sections.

**Phase:** Phase 1 (data model) and Phase 3 (reprodutivo). Non-negotiable.

---

### DT-2: Animal state machine is implicit

**What goes wrong:**
"Is this animal in an ATF?" "Is it pregnant?" "Is it active or sold?" becomes a combinatorial explosion of boolean flags that contradict each other (animal with `vendida = true AND prenhez_confirmada = true AND em_atf = true`). Veterinarians report absurd filters.

**Warning signs:**
- Multiple boolean columns on animal
- No single source of truth for "animal status"
- UI shows contradictory badges
- Queries like `WHERE vendida = false AND deleted_at IS NULL AND ativa = true AND ...`

**Prevention:**
- Model an explicit state: `animal.estado IN ('ativa', 'vendida', 'morta', 'descartada')`. One column. Default `ativa`.
- Reproductive status is **derived** from active lote_atf membership and DG records — not stored as a flag.
- Sanitary "em dia" status is derived from aplicacao records.
- Document the state machine (allowed transitions: ativa → vendida, ativa → morta, ativa → descartada — never vendida → ativa without an explicit "revert sale" audited action).
- If certain transitions require side-effects (mortalidade closes any active ATF participation), enforce via trigger or RPC, not hope.

---

### DT-3: Historical composition loss when animal moves between lotes

**What goes wrong:**
An animal moves from Lote A to Lote B. A report "histórico sanitário da Lote A" should still include the aplicação applied while the animal was in A. If only current `lote_id` is stored on animal, and the snapshot join was "animal join lote," the animal disappears from A's history.

**Warning signs:**
- Snapshot only stores `aplicacao_id + animal_id`; rebuilds lote context from live animal.lote_id
- No historical record of lote membership changes
- Reports show empty lotes in the past

**Prevention:**
- Snapshot denormalizes (see CP-2): store `lote_id, lote_nome, piquete_id, piquete_nome` at the time of application. Do not rely on animal's current lote_id to derive history.
- Out-of-scope-per-PROJECT.md: detailed historical composition ("apenas composição atual importa"). But even so, sanitary/reproductive snapshots capture a point-in-time view — they are the historical record for their event.
- Be explicit about what history is preserved: **sanitary/reproductive events** yes; **pure "which animals were in Lote X on date Y"** no (out of scope).

---

### DT-4: Unique animal number per property — scope ambiguity

**What goes wrong:**
"Unique per property" is clear — until someone asks "can vaca #42 and touro #42 coexist?" Some livestock apps number per category, some globally per property. Customers assume one; the app does the other.

**Warning signs:**
- Unclear spec, inconsistent answers from stakeholders
- Numbers reused when an animal is sold
- Conflicts when importing from legacy spreadsheets

**Prevention:**
- Lock the rule in PROJECT.md. The current decision says "único por propriedade" and "incremental por categoria" — these conflict if taken literally. Clarify:
  - Option A: `(propriedade, numero)` is unique — number is global within propriedade, assigned from a single sequence. Categoria affects only the starting offset or display.
  - Option B: `(propriedade, categoria, numero)` is unique — a "vaca 42" and a "touro 42" are distinct.
- Recommendation for livestock: **Option B** is closer to traditional brinco numbering (pecuaristas think of "vaca número 42"). Confirm with a domain expert (veterinarian in the target persona).
- Whichever you pick, the DB constraint and the UI "number field" label must agree.

**Phase:** Phase 0 (clarify) → Phase 1 (implement).

---

### DT-5: Unidade Animal (UA) calculation drift

**What goes wrong:**
UA coefficients (vaca = 1.0, terneiro = 0.5, touro = 1.5, etc.) are used for pasture planning. If they're hardcoded in Dart **and** in SQL views **and** in a reports module, updating a coefficient (e.g., novilho from 0.75 to 0.8) requires changes in three places. Someone forgets one — pasture math diverges from animal count.

**Warning signs:**
- Magic numbers `0.5, 1.0, 1.5` scattered in code
- UA totals in UI disagree with SQL totals
- "The math on the report is wrong" bug reports

**Prevention:**
- Single source of truth: `categoria (id, nome, ua_coeficiente, sexo_implicito)` table in DB.
- All UA calculations join to this table. Flutter reads the table and caches it at app start; no hardcoded Dart map.
- Changing a coefficient is a data migration, not a code change — and it's auditable.
- Historical reports might need the coefficient *at the time of the data point* — if so, snapshot the coefficient into aplicacao/reports. Decide explicitly.

---

### DT-6: DG (diagnóstico de gestação) and prenhez % math

**What goes wrong:**
"% prenhez do ATF" has a surprising number of correct-answer variations: prenhas / total inseminadas; prenhas / total DG realizados; prenhas ao final do ciclo / total no início. Stakeholders (veterinary) interpret differently. App shows a number, vet says "that's wrong," nobody knows which definition is "right."

**Warning signs:**
- % prenhez shown without formula documented anywhere
- Disagreement between vets on correctness
- Number changes unexpectedly as DG events are entered

**Prevention:**
- Document the formula in PROJECT.md and in the UI tooltip.
- Show numerator and denominator, not just the percentage: "38 prenhas / 45 DG realizados (84%)".
- Distinguish "parcial" (during cycle) from "final" (after cycle closure).
- Let users download the underlying list if they disagree — transparency prevents bug reports.

---

### DT-7: Sanitary application "applies to lote" vs "applies to selected animals"

**What goes wrong:**
Veterinarian applies vaccine to "Lote Piquete 3." Next day, two animals were mis-tagged; vet wants to mark those two as "not applied." Or: vet vaccinates *most* of Lote Piquete 3 but skips a calf. If the model is "aplicação → lote_id," there's no way to express partial application. If it's "aplicação → lista de animais," the vet has to scroll through 300 animals — UX tax.

**Warning signs:**
- Aplicação model has `lote_id` but no per-animal record
- Requests to "exclude animal X from yesterday's application"
- Workarounds like "create another application for the missing animal"

**Prevention:**
- Model: `aplicacao (id, produto, data, ...)` + `aplicacao_animais (aplicacao_id, animal_id, lote_id_at_time, piquete_id_at_time, ...)`.
- UI: default action is "apply to entire lote," materializes one row per animal in `aplicacao_animais`. Vet can deselect animals before confirming.
- Per-animal granularity gives you accurate history and supports partial application, at the cost of more rows (cheap).
- Remember CP-2: these rows are the **snapshot** — immutable post-creation.

---

### DT-8: Gastos por piquete — no clear allocation rule

**What goes wrong:**
"Controlar gastos por piquete" is listed as MVP. But: a sack of feed serves three piquetes. A vaccine applied to Lote A in Piquete 3 is a gasto of Piquete 3? Or of the Propriedade? Or of the Lote A (which may move next week)? Users enter data, reports look wrong.

**Warning signs:**
- Ambiguous spec
- Gastos show on reports but totals don't match receipts
- Vet enters "gasto geral" and doesn't know which piquete to pick

**Prevention:**
- Define explicit gasto types: `gasto_piquete` (insumos specific to a piquete: cerca, reforma), `gasto_aplicacao` (drops from sanitary/reproductive events, allocated to the piquete of the lote at time of application), `gasto_propriedade` (shared, not piquete-specific).
- Reports roll up: Piquete = direct + allocated sanitary costs.
- Keep "gasto_propriedade" out of per-piquete reports (with a disclosure).
- Do not auto-allocate propriedade-level costs across piquetes without explicit user configuration — surprise allocations are the #1 source of "this number is wrong."

---

### DT-9: Time zone and date handling for a field app

**What goes wrong:**
Vet applies vaccine "on April 15" (local time in Rio Grande do Sul). Stored as UTC. Report filter "April 15" queries UTC. Off-by-one when crossing midnight. "Data da aplicação" on UI shows different day than entered.

**Warning signs:**
- `TIMESTAMP` vs `DATE` columns chosen without thought
- UI displays shifted by ±1 day near midnight
- Reports filtered by "day" miss edge records

**Prevention:**
- For **event dates that are "the day of" an action** (application date, DG date, birth date), use `DATE` in Postgres. No timezone.
- For **audit timestamps** (`created_at`, `updated_at`), use `TIMESTAMPTZ`. Always.
- Flutter: compare dates with `DateTime(y, m, d)` — don't subtract `TIMESTAMP`s.
- Test with a user set to UTC+-12 and UTC+14 for edge cases. At minimum, test America/Sao_Paulo (-03) and UTC.

---

### DT-10: CPF/CNPJ and telefone validation / duplicates

**What goes wrong:**
Propriedade ownership, usuário registration: CPF/CNPJ typed with and without mask, same propriedade created twice under different formats. Phone numbers with/without +55, with/without 9th digit. Users see duplicates; matching queries fail.

**Prevention:**
- Normalize to digits-only at the DB layer (trigger or check constraint). Store canonical.
- Validate with CPF/CNPJ check-digit at save time (libs exist; do not trust user input).
- Unique constraints on normalized form.
- For phone: E.164 format (+5551...).

---

## Scope Traps (MVP Scope Creep Risks)

### ST-1: "Simple" mapa/geolocalização creep

**Risk:** Already Out of Scope in PROJECT.md — but users will ask. Stay firm. A real map layer brings:
- Piquete polygons (user draws on map, needs persistence, tools)
- Area calculation (real geodesy, not pythagoras)
- Mobile GPS permissions and accuracy handling
- Tiles (Mapbox/Google) with API keys, cost
- Offline map caching (dwarfs any other offline concern)

**Prevention:** "Área do piquete em hectares" as a plain number input is 1000x simpler and covers 80% of the ask. If geolocation becomes needed, it's a full phase, not a sprint.

---

### ST-2: "Histórico completo de movimentações"

**Risk:** PROJECT.md says "apenas composição atual importa." But the first vet who asks "quando essa vaca entrou no Lote X?" will pressure for a full audit trail. That's an event-sourced sub-system.

**Prevention:** If needed post-MVP: add a `lote_movimento (animal_id, from_lote_id, to_lote_id, motivo, movido_em)` append-only log. Keep the current `animal.lote_id` as the projection. Do NOT start with this in MVP — costs 2-3 weeks and complicates every move operation.

---

### ST-3: "Just add a report" feature creep

**Risk:** Every user requests one report. Reports look simple (a SQL query + a table). But each one needs:
- RLS-safe query
- Pagination
- Filters (date, piquete, categoria...)
- Export to Excel/PDF
- "Why is this number different from last time?" support burden

**Prevention:** MVP: 3-5 opinionated reports, no customizable report builder. Explicitly out-of-scope in PROJECT.md already ("Relatórios e dashboards avançados — pós-MVP"). Hold the line.

---

### ST-4: Permissions granularity creep

**Risk:** "Proprietário, veterinário, leitor" is 3 roles. Easy. A week in, someone asks "can a veterinário see gastos?" "Can a leitor see reproductive data?" Next: per-property, per-module, per-action grid. This is a month of work.

**Prevention:** PROJECT.md already says "Permissões granulares por módulo — fora de escopo." Enforce at the design-review level: every "what if this role could X" question postponed to post-MVP. Document the role matrix on a single page; anything not on that page is not a question.

---

### ST-5: Offline support creep

**Risk:** "Offline não é requisito no MVP" is explicit. But the moment a vet loses signal in the field and loses 20 minutes of entry, pressure mounts. Real offline is: local SQLite mirror, conflict resolution, queued mutations, re-sync UI. 6+ weeks of work.

**Prevention:**
- Phase 1 UX mitigations: drafts saved to localStorage (see MP-5), optimistic UI, retry-with-backoff on network errors, clear "offline" banner. These cover "5-minute connectivity blip" without offline-mode work.
- Full offline = post-MVP decision after real usage data. Do not promise it.

---

### ST-6: Mobile app scope creep

**Risk:** "Web primário, mobile secundário." But Flutter compiles to both, so "just ship mobile too" feels free. It is not:
- Native camera/storage permissions
- Push notifications infrastructure
- App Store / Play Store approval (especially Apple — can take weeks)
- Mobile-specific layouts (web desktop grids don't work on phones)
- Touch vs mouse interaction differences
- Test matrix doubles

**Prevention:** Ship web first. Mobile is a *responsive web* target in MVP (phone browser). Actual native mobile = post-MVP phase with its own planning.

---

### ST-7: "Import from my Excel" feature

**Risk:** Every potential customer has a spreadsheet. "Can we just import it?" sounds like a day of work. It is not:
- Column mapping UI
- Data validation per row
- Duplicate detection (CP-4 territory)
- Partial success (100 rows good, 5 bad — what now?)
- Support burden (every customer's spreadsheet is different)

**Prevention:** MVP: manual entry only. For the first 10 customers, offer a concierge import (you run the import script for them offline). Build self-service import only after you see 3 consistent spreadsheet shapes — it will shape the feature correctly.

---

### ST-8: Notifications and reminders

**Risk:** "Remind me when DG is due" seems small. It requires:
- Scheduling (pg_cron or external scheduler)
- Delivery channel (email, WhatsApp, push)
- User preferences and quiet hours
- Deduplication (don't spam)
- "Mark as done" actions from outside the app

**Prevention:** Out of scope for MVP. If essential, add in Phase 3+. In MVP, an in-app "DG pendentes" dashboard widget covers 80% of the value for zero infrastructure.

---

### ST-9: Multi-language (i18n)

**Risk:** Brazilian pecuarista vocabulary is very specific ("pelagem," "cria," "sobreano"). Adding English for a future export seems trivial — it is not. It requires string extraction, translation memory, RTL considerations (fortunately not yet), date/number localization.

**Prevention:** pt-BR only for MVP. Keep strings out of the code (use a constants file or ARB) so *later* i18n is cheap; do not add the tooling now.

---

### ST-10: Photos/attachments on animal records

**Risk:** "Photo of the brinco," "photo of the mortalidade" — seems natural. Brings: Supabase Storage RLS, image resizing pipeline, offline photo queue, EXIF handling, privacy (location metadata), storage cost.

**Prevention:** Not in MVP. If allowed, a single optional `foto_url` field on animal populated via Supabase Storage with strict size limits. Anything richer = post-MVP.

---

## Summary — Phase-Specific Warning Map

| Phase | Top Pitfalls to Address |
|-------|--------------------------|
| Phase 0 (design) | CP-3 (RLS model), CP-4 (soft-delete decision), DT-4 (numbering scope), MP-6 (migrations-as-code) |
| Phase 1 (auth + core schema) | CP-1 (numbering race), CP-3 (RLS policies), CP-6 (auth refresh), CP-7 (web shell perf), DT-1 (separate lote tables) |
| Phase 2 (lotes + sanitário) | CP-2 (snapshot immutability), CP-5 (lote move atomicity), DT-3 (snapshot denorm), DT-7 (per-animal aplicação), MP-1 (N+1) |
| Phase 3 (reprodutivo + gastos) | DT-1 (ATF isolation), DT-2 (animal state), DT-6 (prenhez math), DT-8 (gasto allocation) |
| Phase 4 (polish + launch) | MP-2 (realtime leaks), MP-4 (routing), MP-5 (forms), CP-7 (web perf revisit) |

---

## Critical Unknowns (Need Validation in Phase 1 Spike)

These were flagged at LOW confidence due to WebSearch unavailability — verify via Supabase docs, Flutter release notes, and a small prototype:

1. **RLS performance at scale** — Supabase RLS with nested `SECURITY DEFINER` function calls. At 10k+ animals and 100+ applications per property, is query latency acceptable? Needs real data load test.
2. **Realtime + FORCE RLS** — confirm that `FORCE ROW LEVEL SECURITY` does not break Realtime subscriptions (there are historical edge cases).
3. **Flutter web Wasm stability in 2026** — confirm Dart2Wasm is production-ready for `package:supabase_flutter` and `package:go_router` on Safari/Firefox, not just Chromium.
4. **Partial unique index interaction with `supabase-dart` upsert** — verify `onConflict` semantics work with partial unique indexes; fall back to RPC if not.
5. **`pg_cron` availability on Supabase plan** — required if any scheduled data hygiene (e.g., close expired LoteATF cycles) is needed; verify on the target plan tier.

---

## Sources

No external sources were retrieved (WebSearch unavailable during research). Findings are derived from:
- Project context (PROJECT.md)
- Well-documented Supabase RLS / Postgres patterns and known platform constraints
- Flutter web platform known limitations (CanvasKit size, hot reload weakness, routing)
- Riverpod documented best practices
- Livestock software domain anti-patterns observed across agro SaaS

**Recommendation:** Before Phase 1 kickoff, spend 2-3 hours verifying items in "Critical Unknowns" with live docs (supabase.com/docs, docs.flutter.dev, riverpod.dev).
