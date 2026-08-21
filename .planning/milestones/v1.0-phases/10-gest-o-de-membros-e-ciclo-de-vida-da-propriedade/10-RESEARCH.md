# Phase 10: Gestão de Membros e Ciclo de Vida da Propriedade - Research

**Researched:** 2026-08-14
**Domain:** Supabase RLS/SECURITY DEFINER RPC design (invite-with-accept, membership CRUD, concurrency guard) + Flutter/Riverpod/GoRouter UI wiring
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Modelo de convite (MEMB-01) — LOCKED**
- Convite com aceite, não adição direta: tabela de convites pendentes (e-mail alvo + papel + propriedade + convidante + status pending/accepted/declined/revoked).
- Sem e-mail transacional no MVP: o convite aparece in-app para o convidado quando ele loga com o e-mail convidado (match por e-mail do auth.users). Quem convida informa o e-mail; se a pessoa ainda não tem conta, o convite fica pendente até ela se cadastrar com aquele e-mail.
- Convite revogável pelo gestor enquanto pending.
- Aceitar cria a linha em property_members (via RPC SECURITY DEFINER, nunca INSERT direto do client); recusar marca declined.

**Quem gerencia membros (MEMB-02) — LOCKED**
- Veterinário E proprietário podem convidar, remover e trocar papel. Leitor só visualiza.
- Sub-regra: proprietário pode remover/rebaixar um veterinário desde que não seja o último vet (a guarda MEMB-03 cobre).
- Sair da fazenda (self-service) disponível a qualquer membro — bloqueado se for o último vet.

**Guarda de último vet (MEMB-03) — LOCKED**
- No banco (trigger/validação nos RPCs): rejeitar remover, rebaixar ou sair do único veterinarian da fazenda. Tenant nunca fica sem admin.

**Arquivar/restaurar fazenda (PROPV-01/02) — LOCKED**
- Arquivar: dialog com confirmação forte — digitar o nome da fazenda. Qualquer vet pode arquivar.
- Restaurar: tela de propriedades lista fazendas arquivadas (visíveis aos vets que eram membros) com ação de restaurar.
- SEM trilha de auditoria (archived_by etc.) — decisão explícita, não adicionar.
- SEM mudança em is_member_of — decisão explícita: a função continua ignorando properties.deleted_at (necessário para a restauração funcionar; o acesso pós-arquivo via API é risco aceito nesta fase).

**Convenções herdadas do projeto (não re-decidir)**
- Toda escrita em property_members e na tabela de convites via RPC SECURITY DEFINER com SET search_path = public, validação de membership + papel, REVOKE de anon/PUBLIC (padrão da 20260814_10).
- Tabela de convites com ENABLE + FORCE ROW LEVEL SECURITY; leitura via policies (gestores veem convites da propriedade; convidado vê convites do próprio e-mail); escrita só via RPC (zero write policies — padrão dg_records).
- property_id imutável (trigger genérico enforce_property_id_immutable já existe — reusar na tabela nova).
- UI: papel negado vê controle ausente, nunca desabilitado (convenção role_gates.dart). pt-BR, padrões visuais do app (mestre-detalhe desktop, bottom sheet mobile via showAdaptiveForm, EmptyState com action).
- Forward-only migrations, nome 20260814_11_* ou data corrente.

### Claude's Discretion
- Estrutura exata da tabela de convites (índices, unique parcial por (property_id, email) pending).
- Onde a UI de membros vive (ex.: dentro da tela de Propriedades ou tela própria) — seguir o padrão do app.
- Textos pt-BR das telas.
- Expiração de convite: não requerida; pode omitir no MVP.

### Deferred Ideas (OUT OF SCOPE)
None recorded in CONTEXT.md for this phase — `<specifics>` and `<canonical_refs>` sections contain implementation pointers, not deferred/out-of-scope ideas. Notable specifics folded into this research: `/sem-acesso` copy must change (no longer "entre em contato com o proprietário"), `canManageMembers` gate mirrors `canManageExpenses`, and the `owner` role becomes reachable for the first time (existing `expenses` policies referencing `'owner'` start actually applying).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| MEMB-01 | Convite com aceite (tabela de convites, match por e-mail do usuário logado, sem e-mail transacional) | Pattern 2 (`current_user_email()`), Pitfall 2/3 (email-claim risk + case normalization), Code Examples (`invites` DDL, `accept_invite` RPC) |
| MEMB-02 | Gestão de membros (listar/trocar papel/remover/sair) via RPCs SECURITY DEFINER | Pattern 1 (RPC skeleton), Open Question 1 (owner-can-act-on-vet role check), Don't Hand-Roll (role-gate convention) |
| MEMB-03 | Guarda de último vet no banco | Pattern 3 (`assert_not_last_veterinarian()` lock-then-count), Pitfall 1 (concurrency race), Validation Architecture (concurrency test note) |
| PROPV-01 | Arquivar fazenda com confirmação forte | UI-SPEC's typed-name dialog contract (no new research needed — pure Dart/UI, existing `softDeleteProperty` RPC-free UPDATE path already covers the write) |
| PROPV-02 | Restaurar pela UI | Pitfall 4 (no new RLS/migration needed — existing `veterinarian_can_update_property` policy already permits it), Recommended Project Structure (`fetchArchivedProperties`/`restoreProperty`) |
</phase_requirements>

## Summary

This phase closes the last SaaS gap left over from Phase 1: `property_members` only ever gets a row from `create_property_with_membership` (creator → `veterinarian`); `owner` and `reader` are unreachable, there is no invite/remove/role-change/leave path, and archived farms have no strong confirmation or restore UI. The codebase already has every pattern needed — this is 95% "apply the established RPC/RLS/UI idiom to a new table," not new architecture.

The two technically load-bearing findings from this session: (1) **email matching for invite acceptance should NOT depend on the JWT `email` claim.** This project's existing pgTAP tests only ever simulate `auth.uid()` via `set_config('request.jwt.claim.sub', ...)`, never an email claim, and the exact GUC Supabase's `auth.jwt()`/`auth.email()` reads (flat `request.jwt.claim.email` vs. the JSON `request.jwt.claims`) is a compatibility-shim detail that varies by Postgres/PostgREST version and is not verifiable from this repo. The robust, already-provable pattern is a new SECURITY DEFINER helper `current_user_email()` that does `SELECT email FROM auth.users WHERE id = auth.uid()` — `auth.uid()` is proven reliable in this project (used by `is_member_of`/`get_role` since Phase 1, tested via pgTAP), and this repo's own migrations (`seed.sql`, three test fixtures) already INSERT directly into `auth.users`, proving the migration-owning role has full read/write access to that table. GoTrue stores `auth.users.email` lowercased since 2022 (PR supabase/auth#110), so normalizing the invite's `invited_email` to lowercase on write and comparing against `current_user_email()` (also naturally lowercase) closes the case-mismatch pitfall without needing `citext`. (2) **The last-veterinarian guard needs to lock the whole vet set of the property, not just the row being touched**, or two concurrent removals of two different vets both pass a naive `COUNT(*) > 1` check computed before either commits. `SELECT ... FOR UPDATE` cannot be combined with `count()` in the same query (Postgres rejects `FOR UPDATE` with aggregates) — the fix is a two-step lock-then-count inside a single shared helper function, called from `remove_member`, `update_member_role`, and `leave_property`.

Everything else — RPC skeleton (property resolution → `is_member_of` → `get_role` → REVOKE/GRANT footer), RLS conventions (FORCE RLS, zero write policies on tables written only through RPCs, `property_id` immutable via the existing generic trigger), the archive/restore mechanics for `properties` (the RLS already supports restoring an archived property with **zero new SQL** — confirmed below), the pgTAP fixture idiom, and every UI widget/pattern needed are already fully worked out precedents in this codebase. No new npm/pub packages are needed.

**Primary recommendation:** One migration file (`20260814_11_*`) adds the `invites` table + 5–6 new RPCs (`create_invite`, `revoke_invite`, `accept_invite`, `decline_invite`, `remove_member`, `update_member_role`, `leave_property`) plus the shared `current_user_email()` and `assert_not_last_veterinarian()` helpers; `properties` gets **no schema change** for archive/restore (existing UPDATE policy already covers it) — only new Dart repository methods (`fetchArchivedProperties`, `restoreProperty`) and UI.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Invite creation, revoke, accept, decline | Database / Storage (SECURITY DEFINER RPC) | API (PostgREST `.rpc()` call) | Membership mutation must never be a direct client INSERT — same rule already enforced on `property_members` (zero write RLS policies since 20260814_09) |
| Invite visibility (candidate sees own pending invites; gestor sees property's invites) | Database / Storage (RLS SELECT policies) | — | Pure read-authorization; no business logic, matches `members_read_own_memberships` precedent |
| Member list / role change / remove / leave | Database / Storage (SECURITY DEFINER RPC) | Frontend Server n/a (Flutter is client, no SSR tier) | Guard MEMB-03 (last-vet) must be transactionally atomic — cannot live only in Dart |
| Role-based control visibility (Convidar/Trocar papel/Remover buttons) | Browser / Client (Flutter widget tree) | — | UI-only gate (`canManageMembers`); real enforcement is the RPC/RLS layer, per project's `role_gates.dart` convention |
| Router redirect to `/sem-acesso` and back | Browser / Client (GoRouter `redirect`, Riverpod `memberPropertiesProvider`) | — | Already implemented (Phase 1); this phase only needs invalidation after accept |
| Archive / restore a property | Database / Storage (existing RLS `veterinarian_can_update_property`) | Browser / Client (strong-confirm dialog, archived-tab filter) | No new DB object needed — confirmed the current UPDATE policy already allows restoring an archived row |

## Standard Stack

No new third-party package is required for this phase. It reuses the project's locked stack (Flutter + Riverpod + GoRouter + `supabase_flutter`, PostgreSQL + RLS + PL/pgSQL) exactly as established in Phases 1–9.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | (already pinned in pubspec.yaml — verify with `flutter pub outdated`) | `.rpc()` calls for the new invite/member RPCs, `.from('invites')`/`.from('properties')` reads | Already the project's only DB client (D-06); no new package needed |
| PL/pgSQL (built-in) | Postgres 15/17 (Supabase-managed) | New RPCs, `current_user_email()`, `assert_not_last_veterinarian()` | Every existing RPC in this project is PL/pgSQL SECURITY DEFINER — zero reason to deviate |

### Supporting
None — Riverpod (`memberPropertiesProvider`, `currentPropertyProvider`), `intl` (plural "N membros"), and every widget needed (`SectionCard`, `StatusChip`, `EmptyState`, `WarningBanner`, `showAdaptiveForm`, `DetailAppBar`, `FarmAvatar`, `ErrorRetry`) already exist in `lib/core/widgets/ui.dart` and `lib/core/widgets/campo_app_bar.dart`.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SECURITY DEFINER `current_user_email()` reading `auth.users` | `auth.jwt() ->> 'email'` / deprecated `auth.email()` directly in RLS policies | Simpler (no new function), but (a) `auth.email()` is officially deprecated by Supabase in favor of `auth.jwt()`, (b) this repo's own pgTAP fixtures never set an email JWT claim — only `request.jwt.claim.sub` — so there is no proof-of-work in this codebase that an email claim GUC is even populated the way `auth.jwt()` expects in this project's Postgres/PostgREST version; using `auth.users` sidesteps the uncertainty entirely and is provably testable with the exact same fixture pattern already in use |
| Lock-then-count last-vet guard (2 statements) | `SELECT count(*) ... FOR UPDATE` in one statement | Postgres raises an error: `FOR UPDATE` is not allowed with aggregate functions — not a style choice, a hard SQL restriction |
| Lock-then-count last-vet guard | Trigger-only guard (`BEFORE DELETE/UPDATE ON property_members`) mirroring `enforce_lot_archive_no_active_animals` | A trigger that only counts sibling rows (no explicit row lock across the full vet set) has the exact same TOCTOU race as a naive RPC check — see Pitfall 1. A trigger COULD also take the lock, but since `property_members` already has zero write RLS policies (all writes are RPC-only, confirmed below), a trigger adds no additional security boundary here — unlike `enforce_lot_archive_no_active_animals`, which exists specifically because `lots` still has no equivalent "RPC-only" lockdown. Recommendation: guard lives in the RPCs via a shared helper, not a trigger. |

**Installation:** none — no `pubspec.yaml` or `flutter pub add` changes.

## Package Legitimacy Audit

Not applicable — this phase adds zero new dependencies (Dart or otherwise). No packages to audit.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────── Flutter (Browser / Client) ───────────────────────────┐
│                                                                                     │
│  PropriedadesScreen ──"Membros" popup item (canManageMembers gate)──▶ MembrosScreen│
│       │  (Ativas/Arquivadas toggle)                                    │           │
│       ▼                                                                ▼           │
│  fetchArchivedProperties()                              MembroRepository (new)     │
│  restoreProperty()                                       ├─ fetchMembers(propId)   │
│                                                            ├─ fetchInvites(propId)  │
│  NoAccessScreen / DashboardBanner ──fetchMyInvites()──▶   ├─ createInvite(...)      │
│       │  (email-matched pending invites)                 ├─ revokeInvite(id)       │
│       ▼                                                   ├─ acceptInvite(id) ─┐   │
│  accept/decline buttons                                   ├─ declineInvite(id) │   │
│                                                            ├─ removeMember(...) │   │
│                                                            ├─ updateMemberRole │   │
│                                                            └─ leaveProperty()  │    │
└─────────────────────────────────────────────────────────────────────┼─────────┼────┘
                                                                        │         │
                              ref.invalidate(memberPropertiesProvider) │         │
                              triggers GoRouter redirect re-evaluation │         │
                                                                        ▼         ▼
┌───────────────────────────── Supabase (API + Database / Storage) ─────────────────┐
│                                                                                     │
│  PostgREST `.rpc()` ──▶  create_invite / accept_invite / decline_invite /         │
│                          revoke_invite / remove_member / update_member_role /     │
│                          leave_property   (all SECURITY DEFINER, SET search_path) │
│                                │                                                   │
│                                ├─▶ is_member_of() / get_role()  (existing)         │
│                                ├─▶ current_user_email()  (new — reads auth.users)  │
│                                ├─▶ assert_not_last_veterinarian()  (new — locks    │
│                                │      full vet-row set FOR UPDATE, then counts)    │
│                                ▼                                                   │
│                          invites table (FORCE RLS, zero write policies)           │
│                          property_members table (FORCE RLS, zero write policies)  │
│                          properties table (FORCE RLS, existing UPDATE policy      │
│                             already covers restore — see Pitfall 4)               │
│                                                                                     │
│  PostgREST `.from()` SELECT (RLS-gated, no RPC needed):                          │
│    invites: candidate sees own email's rows; gestor sees property's rows          │
│    properties: is_member_of() ignores deleted_at → archived rows already visible  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
supabase/migrations/
└── 20260814_11_membership_lifecycle.sql   # single forward-only migration (table + all RPCs + helpers)
supabase/tests/
└── 11_membership_test.sql                  # pgTAP, mirrors 07_expenses_test.sql fixture idiom

lib/features/membros/                       # new feature folder (planner's discretion per CONTEXT.md)
├── data/
│   ├── invite_model.dart                   # freezed — Invite(id, propertyId, invitedEmail, role, status, invitedBy, createdAt)
│   ├── member_model.dart                   # freezed — Member(userId, email?, propertyId, role) — email may need a join or a second RPC
│   └── membro_repository.dart              # all .rpc()/.from() calls, mirrors expense_repository.dart shape
└── presentation/
    ├── membros_screen.dart                 # mobile ListView + desktop table+380px panel (mirrors GastosPropertyScreen)
    ├── invite_form_dialog.dart             # showAdaptiveForm(width: FormWidth.form)
    └── archive_confirm_dialog.dart         # showAdaptiveForm(width: FormWidth.confirm), typed-name gate

lib/features/auth/presentation/no_access_screen.dart   # MODIFIED — replace static empty message with invite list
lib/features/dashboard/presentation/dashboard_screen.dart  # MODIFIED — add invite banner (mirrors _AlertsBanner)
lib/features/propriedades/presentation/propriedades_screen.dart  # MODIFIED — Ativas/Arquivadas toggle, Membros menu item
lib/features/propriedades/data/propriedade_repository.dart  # MODIFIED — fetchArchivedProperties(), restoreProperty()
lib/core/auth/role_gates.dart               # MODIFIED — add canManageMembers(current, members)
lib/core/router/routes.dart                 # MODIFIED — add membrosById template
lib/core/router/router.dart                 # MODIFIED — register the route (root-level, mirrors loteById)
```

### Pattern 1: SECURITY DEFINER RPC skeleton (established since Phase 4)
**What:** Every mutating RPC in this codebase follows the identical shape: resolve `property_id` from the target row → `is_member_of()` check (42501 if not a member) → `get_role()` check for the required role (42501 if wrong role) → business validation (23514/22023/23503 as appropriate) → the actual write, re-checking any soft-delete condition with `IF NOT FOUND` to close TOCTOU windows → REVOKE/GRANT footer.
**When to use:** Every new RPC this phase adds (`create_invite`, `accept_invite`, `decline_invite`, `revoke_invite`, `remove_member`, `update_member_role`, `leave_property`).
**Example:**
```sql
-- Source: supabase/migrations/20260814_10_medium_hardening.sql:85-153 (move_lot_to_paddock)
CREATE OR REPLACE FUNCTION remove_member(
  p_property_id uuid,
  p_target_user_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(p_property_id) NOT IN ('veterinarian'::role_enum, 'owner'::role_enum) THEN
    RAISE EXCEPTION 'forbidden: only veterinarians and owners can remove members'
      USING ERRCODE = '42501';
  END IF;

  PERFORM assert_not_last_veterinarian(p_property_id, p_target_user_id);

  DELETE FROM property_members
   WHERE user_id = p_target_user_id AND property_id = p_property_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'member % not found in property %', p_target_user_id, p_property_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION remove_member(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION remove_member(uuid, uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION remove_member(uuid, uuid) FROM anon, PUBLIC;
```

### Pattern 2: Email-matched invite acceptance without trusting the JWT email claim
**What:** A SECURITY DEFINER helper that resolves the caller's *current, authoritative* email from `auth.users` by `auth.uid()`, instead of reading the JWT's `email` claim.
**When to use:** `accept_invite`, `decline_invite`, and the RLS SELECT policy that lets a candidate see their own pending invites.
**Example:**
```sql
-- New — mirrors is_member_of()/get_role() shape (20260504_01, 20260508_02)
CREATE OR REPLACE FUNCTION current_user_email()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT email FROM auth.users WHERE id = auth.uid();
$$;

REVOKE ALL ON FUNCTION current_user_email() FROM public;
GRANT EXECUTE ON FUNCTION current_user_email() TO authenticated;
REVOKE EXECUTE ON FUNCTION current_user_email() FROM anon, PUBLIC;

-- RLS: candidate sees only their own pending invites
CREATE POLICY "invitee_can_read_own_invites"
  ON invites FOR SELECT TO authenticated
  USING (invited_email = current_user_email());

-- RLS: gestores see all invites for properties they manage
CREATE POLICY "managers_can_read_property_invites"
  ON invites FOR SELECT TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) IN ('veterinarian'::role_enum, 'owner'::role_enum)
  );
```
`invited_email` MUST be normalized to `lower(trim(p_email))` inside `create_invite` before INSERT — `auth.users.email` is already stored lowercase by GoTrue (confirmed: [CITED: github.com/supabase/auth PR #110] — GoTrue lowercases and does case-insensitive lookups on `auth.users.email` since 2022), so comparing two already-lowercase strings needs no `citext` extension and no `LOWER()` at comparison time (only at write time, once, in `create_invite`).

### Pattern 3: Last-veterinarian guard — lock-then-count (closes the 2-simultaneous-removals race)
**What:** `FOR UPDATE` cannot appear with `count()` in the same statement (Postgres restriction: aggregates are disallowed in `SELECT ... FOR UPDATE`). The guard must lock the full veterinarian row-set for the property first, THEN count.
**When to use:** Called from `remove_member`, `update_member_role` (when demoting a vet), and `leave_property` — always as the FIRST statement after the role/membership checks, before the actual UPDATE/DELETE.
**Example:**
```sql
-- New helper, called from all 3 member-mutating RPCs. Not granted to
-- authenticated — only ever called from inside another SECURITY DEFINER
-- function, which already carries the elevated execution context.
CREATE OR REPLACE FUNCTION assert_not_last_veterinarian(
  p_property_id uuid,
  p_excluding_user_id uuid   -- the member being removed/demoted/leaving
) RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_remaining_vets integer;
BEGIN
  -- Lock the ENTIRE veterinarian row-set of this property (not just the
  -- target row) so a second concurrent call targeting a DIFFERENT vet
  -- blocks here until this transaction commits or rolls back. A guard that
  -- only locks/counts the target row is racy: two concurrent removals of
  -- two different vets can both see "1 other vet remains" before either
  -- commits, dropping the property to zero vets.
  PERFORM 1 FROM property_members
   WHERE property_id = p_property_id AND role = 'veterinarian'::role_enum
   FOR UPDATE;

  SELECT count(*) INTO v_remaining_vets
    FROM property_members
   WHERE property_id = p_property_id
     AND role = 'veterinarian'::role_enum
     AND user_id <> p_excluding_user_id;

  IF v_remaining_vets = 0 THEN
    RAISE EXCEPTION 'property % would be left without a veterinarian', p_property_id
      USING ERRCODE = '23514';
  END IF;
END;
$$;
```
For `update_member_role`, call this only when `p_new_role <> 'veterinarian'` AND the target's current role IS `veterinarian` (i.e., actually demoting a vet) — promoting someone TO vet, or changing a non-vet's role, never needs the guard.

### Anti-Patterns to Avoid
- **Trusting `auth.jwt() ->> 'email'` for the invite match without verifying the GUC in this project's Postgres image:** use `current_user_email()` (Pattern 2) instead — it is provable with the same pgTAP fixture idiom already used for `auth.uid()`.
- **`SELECT count(*) ... FOR UPDATE` in one statement:** Postgres rejects this outright for last-vet guard logic — use the two-step lock-then-count (Pattern 3).
- **Locking only the target row instead of the full vet row-set:** does not close the two-concurrent-removals race (see Pitfall 1).
- **Adding a `citext` extension or a `LOWER()` comparison on every read:** unnecessary — normalize once, at write time in `create_invite`, since `auth.users.email` is already always lowercase.
- **Re-adding an INSERT/UPDATE/DELETE RLS policy on `property_members` or the new `invites` table:** breaks the project's "RPC-only write, zero write policies" convention (`dg_records`, `animal_atf_memberships`, and — since 20260814_09 dropped `self_insert_membership` — `property_members` itself). All new tables must ship with `ENABLE + FORCE ROW LEVEL SECURITY` and only SELECT policies.
- **A new migration editing `20260814_09`/`20260814_10` in place:** forward-only, always a new file (project-wide, repeated rule — see every migration's header comment).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Determining the logged-in user's email server-side | A Dart-side "pass my email as an RPC parameter" call | `current_user_email()` SECURITY DEFINER helper (Pattern 2) | A client-supplied email parameter can be spoofed to accept someone else's invite; the RPC must derive it server-side from `auth.uid()` |
| Preventing the last-vet race | An RPC-level `COUNT(*) > 1` check with no lock | `assert_not_last_veterinarian()` (Pattern 3) | TOCTOU race across two concurrent RPC calls — MEMB-03 explicitly calls this out as a DB-level guard |
| "Control visible but disabled" for denied roles | Per-screen ad hoc `enabled: false` logic | `role_gates.dart`'s existing convention — control **absent**, not disabled (already the project rule, `canManageExpenses`/`isVeterinarian` precedent) | Consistency with every other screen in the app; UI-SPEC's "Layout & Interaction Contract" explicitly calls this out as the one designed exception being the archive-confirm typed-name button, nothing else |
| Router refresh after accepting an invite | Manual `context.go()` navigation from inside the accept handler | `ref.invalidate(memberPropertiesProvider)` | `_RouterRefreshNotifier` already `ref.listen`s on `memberPropertiesProvider` (router.dart:297) and re-evaluates `redirect` automatically — this is the existing, proven mechanism for post-membership-change navigation |

**Key insight:** Nothing in this phase requires new infrastructure. The single biggest risk is re-deriving something (email resolution, role-gate visibility, RPC skeleton) that the codebase already has a correct, battle-tested answer for — every "Don't Hand-Roll" row above has a working precedent in a migration or Dart file already in this repo.

## Common Pitfalls

### Pitfall 1: Last-vet guard checked without locking the full vet-row set
**What goes wrong:** Two veterinarians A and B on the same property. Two concurrent RPC calls remove A and remove B respectively. If the guard only counts "other vet rows besides the one being removed," both transactions see "1 other vet remains" (each sees the other's still-uncommitted row) and both proceed — the property ends up with zero veterinarians, violating MEMB-03's core invariant.
**Why it happens:** `SELECT count(*) FROM property_members WHERE role='veterinarian' AND user_id <> target` under READ COMMITTED sees the other vet's row as still present (that other transaction hasn't committed its own DELETE yet), so both counts return 1 independently.
**How to avoid:** `SELECT ... FOR UPDATE` the entire veterinarian row-set for the property BEFORE counting (Pattern 3) — this serializes any two concurrent calls that touch the same property's vet set, regardless of which specific vet each one targets.
**Warning signs:** A pgTAP or manual test with 2 vets, firing `remove_member` for both in two separate un-committed transactions, both succeeding.

### Pitfall 2: Relying on a JWT `email` claim that this project has never proven is populated
**What goes wrong:** An RLS policy or RPC written as `invited_email = (auth.jwt() ->> 'email')` (or the deprecated `auth.email()`) may work in production (PostgREST does set an `email` claim by default in the Supabase-issued JWT) but is **untestable with this repo's existing pgTAP idiom**, which only ever calls `set_config('request.jwt.claim.sub', ..., true)`. A test suite for this feature would either need to also fabricate `request.jwt.claims` as a full JSON GUC (untested combination in this codebase) or silently skip email-matching coverage.
**Why it happens:** Supabase's `auth.jwt()`/`auth.email()` read from `current_setting('request.jwt.claims', true)` (a JSON GUC) with a legacy fallback to flat `request.jwt.claim.X` GUCs depending on the Postgres/PostgREST version — which exact behavior this specific Supabase project has is not verifiable from within this repo.
**How to avoid:** Use `current_user_email()` (Pattern 2), which only depends on `auth.uid()` — already proven reliable and testable in this exact codebase.
**Warning signs:** A pgTAP test for `accept_invite` that needs `set_config('request.jwt.claims', ...)` and the author isn't sure if it actually reaches `auth.jwt()`.

### Pitfall 3: Storing the invited email with mixed case and comparing case-sensitively
**What goes wrong:** Vet types `Joao@Fazenda.com` into the invite form; the invited user's actual account was created (and GoTrue stored) as `joao@fazenda.com`. A case-sensitive `=` comparison never matches, and the invite is permanently invisible to the invited user with no error surfaced.
**Why it happens:** Free-text email input has no case constraint; Postgres `text` equality is case-sensitive by default.
**How to avoid:** Normalize `p_email` to `lower(trim(p_email))` once, inside `create_invite`, before INSERT. Since `auth.users.email` (and therefore `current_user_email()`'s return value) is already always lowercase (GoTrue-enforced since 2022), the comparison then never needs `LOWER()` at read time.
**Warning signs:** A user reports "I got told I'd be invited but I see nothing" — and the invite exists in the DB with a different-case email than the account.

### Pitfall 4: Assuming restore needs new RLS — it does not
**What goes wrong:** Time gets spent designing a new RLS policy or RPC for "restore a property," when the existing `veterinarian_can_update_property` policy (`USING (is_member_of(id) AND get_role(id) = 'veterinarian') WITH CHECK (same)`) already permits `UPDATE properties SET deleted_at = NULL ...` for any veterinarian member — because `is_member_of()`/`get_role()` **intentionally ignore `deleted_at`** (this is the explicit, locked CONTEXT.md decision: "SEM mudança em `is_member_of`").
**Why it happens:** It looks like "restoring a soft-deleted row" should need special-cased RLS, by analogy with how other tables (`animals`, `lots`) gate writes on `deleted_at IS NULL`. `properties` is different — its RLS predicate never references `deleted_at` at all.
**How to avoid:** Confirm with a direct read of `20260504_01_auth_multitenancy.sql` + `20260508_02_property_paddock.sql` before writing any new migration for PROPV-02 — the archive/restore mechanics are **pure Dart + UI work** (`restoreProperty()` calling `.update({'deleted_at': null})`, a new `fetchArchivedProperties()` without the client-side `isFilter('deleted_at', null)`, and the "Arquivadas" tab).
**Warning signs:** A plan task proposing a new migration purely for PROPV-02 with no other schema need — that's the signal to re-check this pitfall before writing it.

### Pitfall 5: `property_id` immutability trigger does not block role changes — but check anyway
**What goes wrong:** None expected, but worth confirming explicitly since MEMB-02 (trocar papel) writes to the same table (`property_members`) that already carries `trg_property_members_property_id_immutable` (20260814_09).
**Why it happens:** N/A — this is a verification note, not a real risk. The trigger fires `BEFORE UPDATE OF property_id` only (`WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)`); `update_member_role` only ever writes the `role` column, never touches `property_id`, so the trigger never fires for this RPC.
**How to avoid:** No action needed — just don't accidentally include `property_id` in `update_member_role`'s `SET` clause.
**Warning signs:** A `23514` error ("property_id is immutable") from `update_member_role` would mean the UPDATE statement was written wrong (touching `property_id`), not a real conflict.

## Code Examples

### Invite table DDL (Claude's discretion per CONTEXT.md — proposed shape)
```sql
-- Source: pattern synthesized from dg_records/sanitary_applications (FORCE RLS,
-- zero write policies) + property_members (composite constraints)
CREATE TABLE invites (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id    uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  invited_email  text NOT NULL,            -- always lower(trim(...)) — see Pitfall 3
  role           role_enum NOT NULL,
  status         text NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'accepted', 'declined', 'revoked')),
  invited_by     uuid NOT NULL REFERENCES auth.users(id),
  created_at     timestamptz NOT NULL DEFAULT now(),
  resolved_at    timestamptz             -- set on accept/decline/revoke
);

-- Only one PENDING invite per (property, email) — a second invite attempt
-- while one is already pending should be a clear conflict, not a duplicate row.
CREATE UNIQUE INDEX invites_property_email_pending_idx
  ON invites (property_id, invited_email) WHERE status = 'pending';

CREATE INDEX invites_invited_email_idx ON invites (invited_email);

ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites FORCE ROW LEVEL SECURITY;
-- No write policies — INSERT/UPDATE only via create_invite/accept_invite/
-- decline_invite/revoke_invite RPCs (SECURITY DEFINER), matching the
-- dg_records / property_members convention.

DROP TRIGGER IF EXISTS trg_invites_property_id_immutable ON invites;
CREATE TRIGGER trg_invites_property_id_immutable
  BEFORE UPDATE OF property_id ON invites
  FOR EACH ROW
  WHEN (NEW.property_id IS DISTINCT FROM OLD.property_id)
  EXECUTE FUNCTION enforce_property_id_immutable();  -- reuse existing function, per CONTEXT.md
```

### accept_invite RPC (creates the property_members row atomically)
```sql
CREATE OR REPLACE FUNCTION accept_invite(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite      record;
  v_caller_email text;
BEGIN
  v_caller_email := current_user_email();

  SELECT id, property_id, invited_email, role, status
    INTO v_invite
    FROM invites
   WHERE id = p_invite_id;

  IF v_invite.id IS NULL THEN
    RAISE EXCEPTION 'invite % not found' , p_invite_id USING ERRCODE = '23503';
  END IF;

  IF v_invite.invited_email <> v_caller_email THEN
    RAISE EXCEPTION 'forbidden: invite is not addressed to this account'
      USING ERRCODE = '42501';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'invite % is no longer pending (status: %)', p_invite_id, v_invite.status
      USING ERRCODE = 'P0002';   -- mirrors the "recarregue" concurrency error idiom
  END IF;

  INSERT INTO property_members (user_id, property_id, role)
  VALUES (auth.uid(), v_invite.property_id, v_invite.role)
  ON CONFLICT (user_id, property_id) DO NOTHING;

  UPDATE invites
     SET status = 'accepted', resolved_at = now()
   WHERE id = p_invite_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite % was resolved concurrently', p_invite_id
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION accept_invite(uuid) FROM public;
GRANT EXECUTE ON FUNCTION accept_invite(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION accept_invite(uuid) FROM anon, PUBLIC;
```
Note the `ON CONFLICT (user_id, property_id) DO NOTHING` — guards the edge case where the user is somehow already a member (e.g., re-invited after already being a member some other way); avoids a spurious 23505 crash on accept.

### Dart repository shape (mirrors expense_repository.dart / property_repository.dart)
```dart
// lib/features/membros/data/membro_repository.dart
class MembroRepository {
  MembroRepository(this._service);
  final SupabaseService _service;

  Future<void> createInvite({
    required String propertyId,
    required String email,
    required String role, // 'owner' | 'veterinarian' | 'reader'
  }) => _service.client.rpc('create_invite', params: {
        'p_property_id': propertyId,
        'p_email': email,
        'p_role': role,
      });

  Future<void> acceptInvite(String inviteId) =>
      _service.client.rpc('accept_invite', params: {'p_invite_id': inviteId});

  // ... revokeInvite, declineInvite, removeMember, updateMemberRole, leaveProperty
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `auth.email()` in RLS policies | `auth.jwt() ->> 'email'` (or, per this research, a `SECURITY DEFINER` helper reading `auth.users`) | `auth.email()` marked deprecated in Supabase's "Deprecated RLS features" doc | Do not write new code using `auth.email()` |

**Deprecated/outdated:** `auth.email()` — [CITED: supabase.com/docs/guides/troubleshooting/deprecated-rls-features-Pm77Zs] deprecated in favor of `auth.jwt()`. This research recommends going one step further (Pattern 2) for testability reasons specific to this codebase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The exact GUC(s) PostgREST populates for `auth.jwt()`/`auth.email()` in this specific Supabase project version were not verified live (no DB/MCP access this session) | Pattern 2, Pitfall 2 | Low — the recommendation already routes around this uncertainty by using `auth.uid()` + `auth.users` lookup instead, so this assumption does not block the recommended design; it only means "confirm `current_user_email()` before considering `auth.jwt()`-based alternatives" |
| A2 | The `invites` table DDL (columns, unique index shape, status enum vs. text+CHECK) is this researcher's proposal, not a locked decision — CONTEXT.md explicitly leaves "Estrutura exata da tabela de convites" to Claude's discretion | Code Examples | Low — planner/executor can adjust column names/types freely as long as the RLS-zero-write-policy and property_id-immutable conventions are preserved |
| A3 | `assert_not_last_veterinarian()` need not be a trigger given `property_members` already has zero write RLS policies (all writes are RPC-only) — reasoned from the current migration state, not independently verified against a live DB | Pattern 3, Alternatives Considered | Low — if a future migration ever re-adds a write policy to `property_members`, the guard would need to move into a trigger too; flagged explicitly so it isn't silently missed |

## Open Questions

1. **Should `remove_member`/`update_member_role` allow `owner` role to act on a `veterinarian`'s membership, or only on `reader`/`owner` peers?**
   - What we know: CONTEXT.md locks "proprietário pode remover/rebaixar um veterinário desde que não seja o último vet" — so yes, owner CAN act on a vet, guarded only by MEMB-03.
   - What's unclear: Nothing — this is explicitly resolved in CONTEXT.md line 28. Listed here only so the planner encodes `get_role(...) IN ('veterinarian', 'owner')` (not vet-only) in these three RPCs, unlike almost every other RPC in this codebase which is vet-only.
   - Recommendation: Use `IN ('veterinarian'::role_enum, 'owner'::role_enum)` for the actor-role check in `remove_member`/`update_member_role`/`create_invite`/`revoke_invite`; `leave_property` has no actor-role check (any member may leave, subject only to the last-vet guard).

2. **Does `revoke_invite` need the same last-vet-style concurrency guard as accept?**
   - What we know: Revoking a `pending` invite never touches `property_members`, so MEMB-03 doesn't apply.
   - What's unclear: Nothing significant — only the ordinary "invite already resolved" TOCTOU (mirrors `P0002` "recarregue" idiom already used project-wide for concurrent-state-change errors).
   - Recommendation: `revoke_invite` follows the same `UPDATE ... WHERE status = 'pending'` + `IF NOT FOUND THEN RAISE P0002` idiom as `accept_invite`/`decline_invite` — no new pattern needed.

## Environment Availability

Skipped — this phase adds no new external tool/service dependency. Supabase CLI/MCP `apply_migration` availability is the same as every prior phase (CLI unlinked/no TTY locally; MCP `apply_migration` against live PROD `wrdwzychjhlpwpivfhhq` is the established path per STATE.md's Blockers log — the planner should mark the migration-apply task orchestrator-owned per the recorded `gsd-executor` tool-list limitation).

**Note:** `20260814_09_multitenant_hardening.sql` is applied to PROD (STATE.md, quick task 260814-f2v). `20260814_10_medium_hardening.sql` is **still pending manual application** as of this research (its own header comment says "PENDENTE DE APLICAÇÃO MANUAL", and STATE.md's `last_activity_desc` confirms it). This phase's new migration should be sequenced `20260814_11_*` regardless, but the planner should flag that `20260814_10` needs to land first (or in the same session) since `move_lot_to_paddock`/`register_baixa`/`register_sanitary_application` in `20260814_10` are unrelated to this phase but sit in the same migration ledger — verify ledger state before applying `_11`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (widget) + `pgTAP` via Supabase CLI `supabase test db` (SQL) — both already in use, no setup needed |
| Config file | `pubspec.yaml` (Dart), `supabase/tests/*.sql` (pgTAP, no separate config) |
| Quick run command | `flutter test test/widget/membros_screen_test.dart` (new file) |
| Full suite command | `flutter test` (Dart) ; pgTAP suite replay via MCP `execute_sql` in `BEGIN...ROLLBACK` (the established fallback since Phase 3 — local Docker/`supabase test db` has been unavailable all project) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MEMB-01 | Invite created, matched by email on accept, wrong-email/wrong-status rejected | pgTAP (RLS + RPC) | replay `11_membership_test.sql` via MCP `execute_sql` BEGIN/ROLLBACK | ❌ Wave 0 |
| MEMB-01 | `/sem-acesso` + dashboard banner show pending invites for the logged-in email, accept/decline buttons work | widget | `flutter test test/widget/no_access_screen_test.dart` | ❌ Wave 0 (extend existing file if present, else create) |
| MEMB-02 | Vet/owner can invite/remove/change-role; reader sees no controls; self "Sair" row label | widget + pgTAP | `flutter test test/widget/membros_screen_test.dart` | ❌ Wave 0 |
| MEMB-03 | Last-vet guard blocks remove/demote/leave on the sole vet; two concurrent removals of 2 different vets cannot both succeed | pgTAP (two-session simulation via two `BEGIN`/interleaved `set_config`) | replay `11_membership_test.sql` | ❌ Wave 0 — this is the one assertion requiring genuine concurrency simulation, not just role-impersonation; plan the test as two separate pgTAP sessions or a documented manual-verification fallback if pgTAP session-interleaving isn't feasible in the MCP replay harness |
| PROPV-01 | Archive requires exact-name match to enable the confirm button; disabled otherwise | widget | `flutter test test/widget/propriedades_screen_test.dart` (extend existing) | ✅ file exists, extend |
| PROPV-02 | Archived properties listed only for vets; restore works via existing UPDATE policy | widget + manual RLS confirmation (no new policy to test) | `flutter test test/widget/propriedades_screen_test.dart` | ✅ file exists, extend |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/<touched_file>_test.dart`
- **Per wave merge:** `flutter test` (full Dart suite, currently 349+ passing) + pgTAP replay of `11_membership_test.sql` via MCP `execute_sql`
- **Phase gate:** Full Dart suite green + pgTAP suite green (or documented environmental-only failure, per the `06_sanitary_test.sql`/`07_expenses_test.sql` precedent of one acceptable non-schema failure) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `supabase/tests/11_membership_test.sql` — new pgTAP suite covering MEMB-01/02/03, mirrors `07_expenses_test.sql`'s fixture idiom (properties + `auth.users` + `property_members` fixtures, `SET ROLE authenticated` + `set_config('request.jwt.claim.sub', ...)`)
- [ ] `test/widget/membros_screen_test.dart` — new widget test file
- [ ] Extend `test/widget/no_access_screen_test.dart` if it exists (verify with a glob before Wave 0; not confirmed to exist in this research pass — grep for it during planning)
- [ ] Extend `test/widget/propriedades_screen_test.dart` (confirmed exists) — Ativas/Arquivadas toggle + strong-confirm dialog

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no (new) | Unchanged — Supabase Auth email/password, already covered by prior phases |
| V3 Session Management | no (new) | Unchanged |
| V4 Access Control | yes | Every new RPC follows the `is_member_of()` → `get_role()` skeleton (Pattern 1); every new table ships `ENABLE + FORCE ROW LEVEL SECURITY` with zero write policies |
| V5 Input Validation | yes | `p_email` normalized + validated (non-empty, contains `@`) inside `create_invite`; `p_role` implicitly validated by the `role_enum` Postgres type (invalid string → 22P02 at the parameter-binding level, before any business logic runs) |
| V6 Cryptography | no | N/A — no new crypto surface |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Direct PostgREST `POST /invites` bypassing `create_invite`'s role check | Elevation of Privilege | Zero write RLS policies on `invites` (FORCE RLS) — matches the `dg_records`/`property_members` precedent; PostgREST literally cannot write regardless of RPC bugs |
| Accepting someone else's invite by ID-guessing (`accept_invite` called with another user's invite id) | Elevation of Privilege | `current_user_email()` server-side match inside the RPC — client cannot supply or spoof the email used for matching (Pattern 2) |
| Concurrent double-removal dropping a property to zero vets | Tampering (of the tenant's admin invariant) | `assert_not_last_veterinarian()` lock-then-count (Pattern 3) — this is MEMB-03's core threat and the reason the guard must be transactionally atomic, not a Dart-side pre-check |
| `anon` executing the new RPCs (recurring project-wide gap — Blockers log: "`anon` can EXECUTE the SECURITY DEFINER RPCs... `REVOKE ALL FROM public` does not remove Supabase's default grant to `anon`") | Elevation of Privilege | Every new RPC's footer MUST include an explicit `REVOKE EXECUTE ON FUNCTION ... FROM anon, PUBLIC;` line, per the pattern already fixed for all prior RPCs in `20260814_09`/`20260814_10` §8 — do not skip this for the new functions this phase adds |
| Invite email enumeration (an attacker probes which emails have pending invites for a property) | Information Disclosure | Low severity, matches the project's already-accepted low-severity UUID-existence-oracle precedent (Blockers log) — not a new risk class, no additional mitigation required for MVP scope per CONTEXT.md's "risk aceito" framing on the related `is_member_of`/`deleted_at` decision |

## Sources

### Primary (HIGH confidence — direct codebase reads, this session)
- `supabase/migrations/20260504_01_auth_multitenancy.sql` — `property_members`, `role_enum`, `is_member_of()`
- `supabase/migrations/20260508_02_property_paddock.sql` — `get_role()`, `properties` RLS (INSERT/UPDATE policies), confirms restore needs no new policy
- `supabase/migrations/20260814_09_multitenant_hardening.sql` — dropped `self_insert_membership` (property_members now zero write policies), `property_id` immutability trigger, REVOKE pattern
- `supabase/migrations/20260814_10_medium_hardening.sql` — most recent RPC skeleton precedent (`move_lot_to_paddock`), still pending manual apply
- `supabase/tests/07_expenses_test.sql` — pgTAP fixture idiom (`set_config('request.jwt.claim.sub', ...)`, `SET ROLE authenticated`)
- `lib/features/auth/data/property_repository.dart`, `lib/features/propriedades/data/propriedade_repository.dart` — confirms client-side `deleted_at` filtering (not RLS), confirms `softDeleteProperty` shape
- `lib/core/auth/role_gates.dart`, `lib/features/propriedades/presentation/propriedades_screen.dart` — `_canEditProperties` is vet-only (matches "qualquer vet pode arquivar")
- `lib/core/router/router.dart`, `lib/core/router/routes.dart` — confirms `memberPropertiesProvider` invalidation drives the `/sem-acesso` redirect re-evaluation
- `lib/core/providers/current_property_provider.dart` — `memberPropertiesProvider` shape
- `lib/core/widgets/ui.dart` — `SectionCard`, `EmptyState`, `WarningBanner`, `ErrorRetry`, `showAdaptiveForm`/`FormWidth`, `StatusChip`
- `10-CONTEXT.md`, `10-UI-SPEC.md` — locked decisions and UI contract for this phase

### Secondary (MEDIUM confidence — WebSearch, official Supabase docs cited)
- [Supabase Docs: Deprecated RLS features](https://supabase.com/docs/guides/troubleshooting/deprecated-rls-features-Pm77Zs) — `auth.email()` deprecated in favor of `auth.jwt()`
- [supabase/auth PR #110](https://github.com/supabase/auth/pull/110) / [Issue #89](https://github.com/supabase/auth/issues/89) — GoTrue normalizes and stores `auth.users.email` in lowercase, case-insensitive lookup

### Tertiary (LOW confidence)
- None used as load-bearing — the one area with genuine uncertainty (exact JWT-claims GUC propagation, Pitfall 2/Assumption A1) is explicitly routed around by the recommended design rather than asserted as fact.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, entirely reuses verified existing project stack
- Architecture: HIGH — every pattern (RPC skeleton, RLS conventions, UI widgets) is a direct, cited precedent already in this codebase
- Pitfalls: HIGH for last-vet race and restore-needs-no-RLS (both independently verified against actual SQL in this repo); MEDIUM for the email-claim GUC specifics (explicitly flagged as A1 and routed around rather than resolved with certainty)

**Research date:** 2026-08-14
**Valid until:** 30 days (stable domain — no fast-moving external dependency; re-verify only if `auth.users` access patterns or Supabase's auth-helper functions change, or if `20260814_10` still hasn't been applied by then)
