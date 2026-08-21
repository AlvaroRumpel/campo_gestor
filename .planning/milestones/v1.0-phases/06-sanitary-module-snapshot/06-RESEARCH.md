# Phase 6: Sanitary Module (Snapshot) - Research

**Researched:** 2026-08-06
**Domain:** Postgres immutable-ledger design (SECURITY DEFINER RPCs, JSONB snapshot, GIN containment) + Flutter/Riverpod read-mostly module, following the Phase 5 (`reproducao`) precedent exactly.
**Confidence:** HIGH

## Summary

Phase 6 has no new technology to evaluate — the stack (Flutter/Riverpod/GoRouter/supabase_flutter/freezed, Postgres via Supabase migrations) is fixed by CLAUDE.md and already proven across Phases 2–5. The research work here is entirely about **getting the immutable-ledger mechanics right**: extending the Phase 2 `sanitary_applications` skeleton (already has `trg_snapshot_immutable`, already tested) with header columns, a `doses` table that mirrors the `lots`/`atf_batches` CRUD pattern, and two new `SECURITY DEFINER` RPCs — one to freeze a registration, one to freeze a reversal. Every mechanic (isolation trigger, partial unique index, SECURITY DEFINER role/property checks, ERRCODE-driven exception mapping, `Navigator.push` selection screen, `ref.invalidate` on success) already has a working precedent in this codebase from Phases 3–5. This phase composes those precedents; it does not invent new ones.

The one genuinely new piece of Postgres mechanics is the **JSONB GIN containment lookup** for SANI-05 (D-38): `composition_snapshot @> '[{"animal_id":"<uuid>"}]'` against a `jsonb_path_ops` GIN index. This is verified in this session (see Sources) — Postgres containment is recursive through array elements that are themselves objects, so a partial-object match inside an array element works exactly as D-38 assumes, and `supabase_flutter`'s `.contains()` filter method maps directly onto it.

The one real technical gap this research surfaces (not flagged in CONTEXT.md) is that **UA weights per category exist only in Dart** (`kUaWeights`) — there is no Postgres source of truth. Since the registration RPC must compute `total_ua`/`total_volume`/`total_cost` server-side (a client cannot be trusted to submit its own UA math), the RPC needs its own copy of the weight table. See Common Pitfalls #1 and Code Examples for the concrete, minimal-footprint fix (a `plpgsql` function mirroring `kUaWeights`, not a new table).

**Primary recommendation:** Extend `sanitary_applications` in place (no child table — D-01 already locked this), add two `SECURITY DEFINER` RPCs (`register_sanitary_application`, `reverse_sanitary_application`) following the exact `add_animals_to_atf`/`register_baixa` shape, add one `plpgsql` UA-weight helper mirroring `kUaWeights`, and reuse `AtfAnimalSelectionScreen` + `EncerrarAtfDialog`/`BaixaDialog` as the literal structural templates for the five new Flutter screens/dialogs the UI-SPEC already locked.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SANI-01 | Cadastrar doses (nome, valor/kg); valor/UA calculado automaticamente | `doses` table + `properties.kg_per_ua` schema (Code Examples §1); dose CRUD mirrors `lots`/`atf_batches` direct-RLS pattern, no RPC needed |
| SANI-02 | Registrar aplicação sanitária em lote com snapshot congelado imutável | `register_sanitary_application` RPC (Code Examples §3) atop the already-proven `trg_snapshot_immutable` trigger from Phase 2 |
| SANI-03 | Desmarcar animais individuais antes de confirmar (default = todos) | `SanitaryAnimalSelectionScreen` mirrors `AtfAnimalSelectionScreen` exactly (Architecture Patterns Pattern 2); RPC revalidates the final selection server-side (D-32, Common Pitfalls #2) |
| SANI-04 | Histórico sanitário do lote por data | Direct `SELECT ... WHERE lot_id = ... ORDER BY applied_at DESC` — no RPC, mirrors `atfListByPropertyProvider`/`fetchReproductiveHistory` read pattern |
| SANI-05 | Histórico sanitário do animal via lookup no snapshot | GIN `jsonb_path_ops` index + `.contains()` filter (Code Examples §6/§7), verified this session |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dose CRUD (SANI-01) | Database (RLS policies) | Frontend Server (Flutter) | Single-row, single-entity write — same shape as `lots`/`atf_batches`, no RPC needed (RLS `WITH CHECK` is sufficient) |
| Valor/UA computation (SANI-01) | Database (RPC, authoritative) | Frontend (live preview) | RPC recomputes at freeze time from `properties.kg_per_ua`; Dart recomputes the same formula for the DoseFormDialog's live read-only field, but Dart's copy is display-only, never trusted for a write |
| Snapshot freeze (SANI-02) | Database (SECURITY DEFINER RPC + trigger) | — | Must be atomic and server-authoritative — a client cannot be trusted to submit its own UA/volume/cost totals or to bypass the immutability trigger via raw PostgREST |
| Animal selection UI (SANI-03) | Frontend (Flutter/Riverpod) | Database (RPC revalidation) | UI provides the interaction; the RPC is the actual guard (D-22, D-32) — mirrors the established "UI is never the last guard" lesson from Phase 4/5 |
| History reads (SANI-04, SANI-05) | Database (RLS SELECT policy + GIN index) | Frontend (Riverpod FutureProvider) | Plain reads through existing SELECT policies; no RPC needed, same shape as `fetchReproductiveHistory` |
| Estorno (reversal) | Database (SECURITY DEFINER RPC + unique index) | Frontend (confirmation dialog) | Same reasoning as snapshot freeze — the "estorno único" and "não pode reverter reversão" invariants must hold regardless of write path |

## Standard Stack

No new packages this phase (UI-SPEC "Registry Safety": zero new pub.dev dependencies). The existing stack is used as-is:

### Core (already in `pubspec.yaml`, unchanged)
| Library | Purpose in this phase | Why Standard |
|---------|---------|--------------|
| `flutter_riverpod` 3.x | `FutureProvider`/`FutureProvider.family` for dose list, application list, lot/animal history | Established since Phase 0; Riverpod 3.x API (not 2.x — STATE.md Phase 0 note) |
| `supabase_flutter` | RPC calls (`register_sanitary_application`, `reverse_sanitary_application`), `.contains()` GIN filter, direct table CRUD for `doses` | `.contains()` for jsonb containment `[VERIFIED: Context7 /websites/supabase_reference_dart]` |
| `freezed`/`json_serializable` | `Dose`, `SanitaryApplication`, `SanitaryHistoryEntry` models | Established pattern; `fieldRename: FieldRename.snake` bridges Postgres snake_case |
| `intl` | pt-BR dates/currency, `Intl.plural` for count copy (D-21, D-25, D-23) | `Intl.plural(num howMany, {..., required String other})` `[CITED: pub.dev/documentation/intl]` |
| `go_router` | Root-level `/aplicacoes/:id` GoRoute (D-19) | Mirrors `loteById`/`atfById` verbatim |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend `sanitary_applications` in place (JSONB array, D-01) | A child table `sanitary_application_animals` | Rejected by CONTEXT.md D-01 — two immutability surfaces to guard (own trigger + `FORCE ROW LEVEL SECURITY`) vs. one; scale (hundreds of animals, dozens of applications/year) does not justify normalizing |
| UA-weight `plpgsql` function mirroring `kUaWeights` | A `ua_weights` reference table | A table would be the "more correct" single-source-of-fix, but no such table exists anywhere in this codebase for the identical Phase 3/5 category-eligibility duplication pattern (`IN ('vaca','novilha')` lives in a trigger, not a table); introducing one now is a bigger surface than this phase needs — see Common Pitfalls #1 |
| GIN index operator class `jsonb_path_ops` | Default `jsonb_ops` | D-38 already specifies `jsonb_path_ops`; it supports `@>` (the only operator SANI-05 needs), is smaller and faster than `jsonb_ops`, at the cost of not supporting `?`/`?|`/`?&` — not needed here `[CITED: postgresql.org/docs/current/gin.html]` |

**Installation:** none — no new dependencies.

## Package Legitimacy Audit

**Not applicable.** Phase 6 introduces zero new pub.dev dependencies (confirmed in 06-UI-SPEC.md "Registry Safety" — Flutter Material 3 SDK widgets only, no new packages). The Package Legitimacy Gate is skipped per its own trigger condition ("whenever this phase installs external packages").

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────── Flutter (Frontend) ───────────────────────────┐
│                                                                            │
│  SanitarioScreen (tabs)          LoteDetailScreen        AnimalDetailScreen│
│   ├─ Aplicações tab               └─ _SanitaryHistorySection └─ _SanitaryHistorySection│
│   └─ Doses tab                        (SANI-04, read)         (SANI-05, read)│
│        │                                                                  │
│        ▼ FAB "Registrar aplicação"                                       │
│  AplicacaoFormDialog (lote+dose+data, no write)                          │
│        │ Navigator.push                                                  │
│        ▼                                                                 │
│  SanitaryAnimalSelectionScreen (loads active lot animals, no write)      │
│        │ showDialog                                                      │
│        ▼                                                                 │
│  ResumoAplicacaoDialog ─────────────► register_sanitary_application(RPC) │
│        │ on success: pop + SnackBar + ref.invalidate(...)                │
│        ▼                                                                 │
│  AplicacaoDetailScreen ─── EstornarAplicacaoDialog ──► reverse_sanitary_  │
│                                                          application(RPC) │
└────────────────────────────────────────────────────────────────────────┘
                                    │  supabase_flutter (RPC + SELECT via RLS)
                                    ▼
┌─────────────────────────── Postgres (Supabase) ──────────────────────────┐
│                                                                            │
│  doses (RLS CRUD, no RPC)          properties.kg_per_ua (D-12)           │
│                                                                            │
│  register_sanitary_application(p_lot_id, p_dose_id, p_applied_at,        │
│    p_animal_ids, p_notes)                                                │
│    1. resolve lot → property_id, lot_name                                │
│    2. is_member_of + get_role = veterinarian                             │
│    3. resolve dose → freeze dose_name/dosage/cost fields                 │
│    4. D-32: revalidate every p_animal_ids id is still active in this lot │
│       → mismatch: RAISE '% animais mudaram...' USING ERRCODE='P0002'     │
│    5. build composition_snapshot (animal_id, number, category, ua)       │
│    6. compute total_ua/total_volume/total_cost via UA-weight helper      │
│    7. INSERT sanitary_applications (frozen row)                          │
│       └─ trg_sanitary_applications_same_property (BEFORE INSERT)         │
│       └─ trg_snapshot_immutable (BEFORE UPDATE/DELETE, from Phase 2)     │
│                                                                            │
│  reverse_sanitary_application(p_application_id, p_reason)                │
│    1. resolve original row, role/membership check                        │
│    2. block reversal-of-reversal (D-30) + pre-check unique reversal (D-31)│
│    3. INSERT new row: copies composition_snapshot, negates totals        │
│       └─ sanitary_applications_reversal_idx (UNIQUE, backstop)           │
│                                                                            │
│  SELECT ... WHERE composition_snapshot @> '[{"animal_id":"..."}]'        │
│    └─ sanitary_applications_composition_gin_idx (jsonb_path_ops)         │
└────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
supabase/migrations/
└── 20260810_06_sanitary_module.sql   # doses, sanitary_applications extension,
                                        # kg_per_ua, GIN index, reversal unique
                                        # index, isolation trigger, both RPCs
lib/features/sanitario/
├── data/
│   ├── dose_model.dart                # freezed
│   ├── dose_repository.dart           # CRUD, direct RLS writes
│   ├── sanitary_application_model.dart # freezed (header + composition list)
│   ├── sanitary_application_repository.dart  # RPCs + reads
│   └── sanitary_application_exception.dart   # D-35 enum + fromPostgrest()
└── presentation/
    ├── sanitario_screen.dart          # replacement (D-16)
    ├── dose_form_dialog.dart
    ├── aplicacao_form_dialog.dart
    ├── sanitary_animal_selection_screen.dart
    ├── resumo_aplicacao_dialog.dart
    ├── aplicacao_detail_screen.dart
    └── estornar_aplicacao_dialog.dart
```

### Pattern 1: Header-Dialog-Then-Push-Selector-Then-Confirm (SANI-02/03)

**What:** A three-step flow — a small `AlertDialog` collects header fields (lote/dose/data) with no write; `Navigator.push` opens a full-screen checklist that loads real data and lets the user deselect; a final `showDialog` summarizes totals and performs the single write.
**When to use:** Any registration flow where the write is expensive to undo (this one is literally irreversible without a new ledger row) and the selection set is too large for a dialog checkbox list.
**Example — direct precedent, `AtfAnimalSelectionScreen`:**
```dart
// Source: lib/features/reproducao/presentation/atf_animal_selection_screen.dart
// Pushed via Navigator.push, not a GoRoute — transient workflow, no deep-link need.
class AtfAnimalSelectionScreen extends ConsumerStatefulWidget { ... }
// Bottom sticky bar with live counter + FilledButton "Continuar" disabled at 0 selected.
```
The Phase 6 `SanitaryAnimalSelectionScreen` is the same shape, single-lot instead of lot+avulsos (no "lote base" picker needed — the lote is already resolved by `AplicacaoFormDialog`).

### Pattern 2: SECURITY DEFINER RPC with zero write policies (SANI-02, Estorno)

**What:** The mutated table (`sanitary_applications`) gets `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` and a SELECT-only policy. Every mutation is a named `SECURITY DEFINER` function that re-derives `property_id` server-side, checks `is_member_of()` + `get_role() = 'veterinarian'`, and performs the write. No client can ever reach an INSERT/UPDATE/DELETE except through the function.
**When to use:** Any write with an invariant more complex than "row belongs to a property the caller is a member of" — here, "the snapshot is authoritative and frozen at write time," which an RLS `WITH CHECK` cannot express (it only inspects the row being written, not a computed aggregate over other rows).
**Example — direct precedent, `register_baixa`:**
```sql
-- Source: supabase/migrations/20260805_05_atf_rpcs.sql
CREATE OR REPLACE FUNCTION register_baixa(...) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id FROM animals WHERE id = p_animal_id AND deleted_at IS NULL;
  IF v_property_id IS NULL THEN RAISE EXCEPTION '...' USING ERRCODE = '23503'; END IF;
  IF NOT is_member_of(v_property_id) THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN RAISE EXCEPTION '...' USING ERRCODE = '42501'; END IF;
  ...
END; $$;
REVOKE ALL ON FUNCTION register_baixa(...) FROM public;
GRANT EXECUTE ON FUNCTION register_baixa(...) TO authenticated;
```

### Pattern 3: Access-path-independent isolation trigger (D-10)

**What:** A `BEFORE INSERT` trigger that re-validates cross-table `property_id` alignment (here: `lot_id` and `dose_id` both belong to `sanitary_applications.property_id`), independent of whether the write came through the RPC or (hypothetically) a raw PostgREST call.
**When to use:** Always, for any table where an RPC's own checks could be bypassed by a different write path. This is the project's established idiom for "belt and suspenders" applied correctly (one place enforces it — the trigger — not duplicated in the RPC and the trigger).
**Example — direct precedent:**
```sql
-- Source: supabase/migrations/20260716_04_animal_lot_property_trigger.sql
CREATE OR REPLACE FUNCTION enforce_animal_lot_same_property() RETURNS trigger ...
CREATE TRIGGER trg_animals_lot_same_property BEFORE INSERT OR UPDATE ON animals ...
```
For `sanitary_applications` this only needs `BEFORE INSERT` (not `OR UPDATE`) — `trg_snapshot_immutable` (Phase 2) already blocks every `UPDATE`/`DELETE` unconditionally, so there is no UPDATE path to guard.

### Pattern 4: Partial unique index as the real concurrency guard (D-31)

**What:** A `CREATE UNIQUE INDEX ... WHERE <partial condition>` is the actual invariant enforcement; the RPC's own pre-check exists only to turn a raw `23505` into a legible message.
**Example — direct precedent:**
```sql
-- Source: supabase/migrations/20260508_02_property_paddock.sql
CREATE UNIQUE INDEX animal_atf_memberships_active_idx
  ON animal_atf_memberships (animal_id) WHERE active = true;
```
D-31 asks for the identical technique on `reverses_application_id`:
```sql
CREATE UNIQUE INDEX sanitary_applications_reversal_idx
  ON sanitary_applications (reverses_application_id)
  WHERE reverses_application_id IS NOT NULL;
```

### Anti-Patterns to Avoid
- **Trusting client-submitted UA/volume/cost totals:** the RPC must recompute everything from `animals.category` + `doses.dosage_per_kg`/`cost_per_kg` + `properties.kg_per_ua` server-side. A client-submitted total is trivially falsifiable and the row is permanent.
- **Adding a write RLS policy "just for this one case":** `sanitary_applications` and `doses`' write surfaces are already fully covered by (a) direct RLS INSERT/UPDATE policies for `doses` (single-row CRUD, safe) and (b) SECURITY DEFINER RPCs for `sanitary_applications` (complex invariant, unsafe via RLS alone). Do not add an INSERT/UPDATE policy to `sanitary_applications` — that would let a raw PostgREST call bypass the concurrency/total-computation logic entirely (same class of bug as Phase 4's CR-01/WR-02).
- **Re-checking category eligibility or property alignment in both the RPC and the trigger:** per the `add_animals_to_atf` precedent comment, duplicating a check across two places is exactly the "drifting out of sync" pitfall this codebase has already flagged once (05-RESEARCH Pitfall 2). The isolation trigger owns cross-table alignment; the RPC owns role/membership and the concurrency revalidation (a different concern — "is this the same set of animals the user saw," not "does this row belong to this property").

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Does this array-of-objects JSONB column contain an object with this key?" | A custom SQL function looping `jsonb_array_elements` to check membership, or a Dart-side full-table scan | `composition_snapshot @> '[{"animal_id":"<uuid>"}]'` with a `jsonb_path_ops` GIN index | Postgres's containment operator is recursive through array elements that are objects — this exact query shape is documented Postgres behavior, index-accelerated, and needs zero custom code `[VERIFIED: postgresql.org/docs/current/datatype-json.html + pgsql-hackers thread, see Sources]` |
| "Prevent two reversal rows for the same application" | An `EXISTS` check inside the RPC as the sole guard | `CREATE UNIQUE INDEX ... WHERE reverses_application_id IS NOT NULL` (D-31) | An `EXISTS` check alone has a TOCTOU race between two concurrent estorno calls; the partial unique index is the actual guarantee, proven by the identical `animal_atf_memberships_active_idx` technique already live in this schema |
| "pt-BR singular/plural copy" | String concatenation with manual `if (n == 1)` branches scattered across widgets | `Intl.plural(n, one: '...', other: '...')` | Already a project dependency (`intl`); UI-SPEC explicitly mandates this over the `"(s)"` parenthetical form for this phase |
| "Prevent mutation of a frozen row" | A `deleted_at`/`cancelled_at` soft-flag column plus app-level checks before every read | The existing `trg_snapshot_immutable` `BEFORE UPDATE OR DELETE` trigger (Phase 2) + estorno-by-new-row (D-27) | Already built and pgTAP-tested (`02_property_paddock_test.sql`); a soft flag would be weaker (still permits `UPDATE ... SET cancelled_at = ...`, i.e. a mutation) and CONTEXT.md D-27 explicitly rejected it |

**Key insight:** every "hard part" of this phase (immutability, uniqueness, containment lookup) is already a solved problem either in Postgres itself or in this exact codebase from Phases 2–5. The only genuinely new code is the composition/total-computation logic inside `register_sanitary_application`.

## Common Pitfalls

### Pitfall 1: UA weights have no Postgres source of truth
**What goes wrong:** `register_sanitary_application` must compute `total_ua` (and everything derived from it: `total_volume`, `total_cost`) server-side, using each selected animal's category. But the category→UA weight table (`kUaWeights`) lives only in `lib/features/animais/data/animal_constants.dart` — there is no Postgres table or function that knows `vaca = 1.0, terneiro = 0.5, touro = 1.5, novilha = 0.75, novilho = 0.75, boi = 1.5, terneira = 0.5`.
**Why it happens:** Phase 3 hardcoded the weights in Dart because at the time nothing in Postgres needed them (UA totals were computed client-side for display only, e.g. `_LoteHeaderCard`'s composition chips). Phase 6 is the first feature where a **server-side, authoritative** computation is required (a client cannot be trusted to submit its own `total_ua`).
**How to avoid:** Add a small `plpgsql` function in the Phase 6 migration that mirrors `kUaWeights` exactly, with a code comment cross-referencing both the Dart constant and `REQUIREMENTS.md`'s Business Rules table so a future edit to one is flagged as needing to sync the other (see Code Examples §2). Do not introduce a new `ua_weights` table for this — no precedent for that shape exists in this schema and it is more surface than the fixed, rarely-changing 7-category table needs (see Standard Stack "Alternatives Considered").
**Warning signs:** a pgTAP test that inserts one `vaca` (weight 1.0) and asserts `total_ua = 1.0` on the returned row will immediately catch a stale or missing weight mapping.

### Pitfall 2: Trusting the animal-selection screen's snapshot of "active" without revalidating at confirm time
**What goes wrong:** Between opening `SanitaryAnimalSelectionScreen` and tapping "Registrar aplicação" in `ResumoAplicacaoDialog`, another user could move an animal out of the lot or register a baixa on it. If the RPC blindly inserts whatever `p_animal_ids` the client sends, the frozen snapshot could include an animal that, at freeze time, no longer belongs to that lot — a silent correctness bug in a row that can never be corrected once written.
**Why it happens:** This is the exact TOCTOU class the project already named `WR-01`/`SC-4` in Phase 4's history (STATE.md), and D-32 explicitly calls it out for this phase.
**How to avoid:** The RPC must re-query `animals` for every submitted id at confirm time (`WHERE lot_id = p_lot_id AND deleted_at IS NULL AND property_id = v_property_id`) and abort the entire transaction — not partially insert — if the count doesn't match what was submitted. See Code Examples §3, step 4.
**Warning signs:** a pgTAP test that soft-deletes one animal between "load" and "confirm" (simulated by two separate transactions in the test) and asserts the RPC raises rather than silently freezing a stale composition.

### Pitfall 3: Reversal totals sign convention is undocumented in CONTEXT.md/UI-SPEC
**What goes wrong:** D-28 says the estorno row "grava totais negativos no cabeçalho" but does not specify which of `animal_count`/`total_ua`/`total_volume`/`total_cost` get negated, nor whether `applied_at` on the reversal row copies the original's date or uses today's date. Guessing inconsistently here breaks D-28's own "soma dos totais bate em zero naturalmente" guarantee and could make `AplicacaoHeaderCard`'s "Totais" line render a confusing negative animal count.
**Why it happens:** This is exactly the kind of mechanical detail that CONTEXT.md's `<decisions>` locks the *what* for but leaves the *exact columns* to research/planning.
**How to avoid:** This research recommends (see Code Examples §4 and Open Questions #1): negate all four numeric header totals (`animal_count`, `total_ua`, `total_volume`, `total_cost`) uniformly so the zero-sum property holds exactly; keep `composition_snapshot` itself un-negated (it is a list of the same animals, not a signed quantity) so `_CompositionListSection`'s "(N animais)" header — which reads `composition_snapshot`'s array length, not `animal_count` — always displays a positive, correct count; set the reversal row's `applied_at` to `CURRENT_DATE` (the actual reversal date) rather than copying the original's `applied_at`, because UI-SPEC's "Estornada em → date" KvRow implies the reversal carries its own distinct date, and D-30 explicitly notes an estorno can happen months after the original. **This is a recommendation, not a verified fact — flag for planner/user confirmation** (see Assumptions Log A1).
**Warning signs:** a pgTAP test inserting an application then reversing it, asserting `SUM(total_cost) = 0` and `SUM(animal_count) = 0` over both rows.

### Pitfall 4: `anon` role can execute SECURITY DEFINER RPCs despite `REVOKE ALL FROM public`
**What goes wrong:** STATE.md documents a known, pre-existing issue: Supabase's `ALTER DEFAULT PRIVILEGES` grants `anon` execute on every new function regardless of an explicit `REVOKE ALL ... FROM public`. The function still fails closed (`is_member_of()` returns false when `auth.uid()` is NULL → `42501`), but it leaks a UUID-existence oracle (`23503` "not found" vs `42501` "forbidden" tells an anonymous caller whether a given lot/dose id exists).
**Why it happens:** Supabase project-level default privilege grants, not something this migration controls.
**How to avoid:** Not a Phase 6 blocker (low severity, pre-existing since Phase 1, tracked for `/gsd-secure-phase`) — but don't "fix" it locally in this phase's RPCs in a way that diverges from the rest of the codebase's pattern. Follow the identical structure (`REVOKE ALL ... FROM public; GRANT EXECUTE ... TO authenticated;`) used by every other RPC in this project, and let the systemic fix happen in its own pass.
**Warning signs:** none new — this is a known, accepted, tracked gap.

## Code Examples

Verified/derived patterns for this phase's migration and Dart layer.

### 1. Schema additions
```sql
-- properties.kg_per_ua (D-12) — property-scoped, no UI this phase, default 400
ALTER TABLE properties
  ADD COLUMN kg_per_ua numeric NOT NULL DEFAULT 400 CHECK (kg_per_ua > 0);

-- doses (SANI-01, D-11..D-15) — direct RLS CRUD, mirrors lots/atf_batches shape
CREATE TABLE doses (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id       uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name              text NOT NULL CHECK (length(trim(name)) > 0),
  active_ingredient text,
  dosage_per_kg     numeric NOT NULL CHECK (dosage_per_kg > 0),
  cost_per_kg       numeric CHECK (cost_per_kg >= 0),
  created_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);

CREATE INDEX doses_property_active_idx ON doses (property_id) WHERE deleted_at IS NULL;

ALTER TABLE doses ENABLE ROW LEVEL SECURITY;
ALTER TABLE doses FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_doses" ON doses FOR SELECT TO authenticated
  USING (is_member_of(property_id));
CREATE POLICY "veterinarian_can_insert_dose" ON doses FOR INSERT TO authenticated
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
CREATE POLICY "veterinarian_can_update_active_dose" ON doses FOR UPDATE TO authenticated
  USING (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum AND deleted_at IS NULL)
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
-- No DELETE policy — soft-delete via UPDATE deleted_at, same as lots/paddocks/atf_batches.

-- sanitary_applications — extend the Phase 2 skeleton (id, composition_snapshot, created_at)
-- Table is guaranteed empty in every environment (Phase 2 shipped zero write policies —
-- "Phase 6 owns this table" comment, same A-SCHEMA-01 precedent as Phase 5's
-- animal_atf_memberships.property_id NOT NULL-without-backfill).
ALTER TABLE sanitary_applications
  ADD COLUMN property_id             uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  ADD COLUMN lot_id                  uuid NOT NULL REFERENCES lots(id),
  ADD COLUMN lot_name                text NOT NULL,
  ADD COLUMN dose_id                 uuid NOT NULL REFERENCES doses(id),
  ADD COLUMN dose_name               text NOT NULL,
  ADD COLUMN dosage_per_kg           numeric NOT NULL,
  ADD COLUMN dosage_per_ua           numeric NOT NULL,
  ADD COLUMN cost_per_kg             numeric,
  ADD COLUMN cost_per_ua             numeric,
  ADD COLUMN applied_at              date NOT NULL DEFAULT current_date,
  ADD COLUMN applied_by              uuid NOT NULL REFERENCES auth.users(id),
  ADD COLUMN animal_count            integer NOT NULL,
  ADD COLUMN total_ua                numeric NOT NULL,
  ADD COLUMN total_volume            numeric NOT NULL,
  ADD COLUMN total_cost              numeric,
  ADD COLUMN skipped_count           integer NOT NULL DEFAULT 0,
  ADD COLUMN notes                   text,
  ADD COLUMN reverses_application_id uuid REFERENCES sanitary_applications(id);

CREATE INDEX sanitary_applications_property_idx ON sanitary_applications (property_id);
CREATE INDEX sanitary_applications_lot_idx       ON sanitary_applications (lot_id, applied_at DESC);

-- D-31: estorno único, same technique as animal_atf_memberships_active_idx
CREATE UNIQUE INDEX sanitary_applications_reversal_idx
  ON sanitary_applications (reverses_application_id)
  WHERE reverses_application_id IS NOT NULL;

-- D-38: GIN containment index for SANI-05's per-animal lookup
CREATE INDEX sanitary_applications_composition_gin_idx
  ON sanitary_applications USING GIN (composition_snapshot jsonb_path_ops);

ALTER TABLE sanitary_applications ADD CONSTRAINT sanitary_applications_animal_count_check
  CHECK (animal_count <> 0);  -- either positive (registration) or negative (reversal)

CREATE POLICY "members_can_read_sanitary_applications"
  ON sanitary_applications FOR SELECT TO authenticated
  USING (is_member_of(property_id));
-- Deliberately NO INSERT/UPDATE/DELETE policy — the two RPCs below are the entire write
-- surface (Pattern 2). trg_snapshot_immutable (Phase 2) already blocks UPDATE/DELETE
-- unconditionally, independent of RLS.
```

### 2. UA weight helper (Common Pitfalls #1)
```sql
-- Mirrors lib/features/animais/data/animal_constants.dart kUaWeights EXACTLY.
-- No single source of truth exists yet between Dart and Postgres for this table —
-- pre-existing gap (Phase 3), not introduced by this phase. If kUaWeights changes,
-- this function must change too.
CREATE OR REPLACE FUNCTION animal_ua_weight(p_category text) RETURNS numeric
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE p_category
    WHEN 'vaca'     THEN 1.0
    WHEN 'novilha'  THEN 0.75
    WHEN 'terneiro' THEN 0.5
    WHEN 'terneira' THEN 0.5
    WHEN 'touro'    THEN 1.5
    WHEN 'boi'      THEN 1.5
    WHEN 'novilho'  THEN 0.75
    ELSE 0.0
  END;
$$;
```

### 3. register_sanitary_application RPC (SANI-02, SANI-03, D-32)
```sql
CREATE OR REPLACE FUNCTION register_sanitary_application(
  p_lot_id     uuid,
  p_dose_id    uuid,
  p_applied_at date,
  p_animal_ids jsonb,             -- JSON array of animal uuid strings, post-deselection
  p_notes      text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_property_id    uuid;
  v_lot_name       text;
  v_dose           record;
  v_kg_per_ua      numeric;
  v_selected_count integer;
  v_valid_count    integer;
  v_active_count   integer;
  v_snapshot       jsonb;
  v_total_ua       numeric;
  v_total_volume   numeric;
  v_total_cost     numeric;
  v_app_id         uuid;
BEGIN
  SELECT property_id, name INTO v_property_id, v_lot_name
    FROM lots WHERE id = p_lot_id AND deleted_at IS NULL;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'lot % not found or archived', p_lot_id USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register a sanitary application'
      USING ERRCODE = '42501';
  END IF;

  SELECT id, name, dosage_per_kg, cost_per_kg INTO v_dose
    FROM doses WHERE id = p_dose_id AND property_id = v_property_id AND deleted_at IS NULL;
  IF v_dose.id IS NULL THEN
    RAISE EXCEPTION 'dose % not found or archived', p_dose_id USING ERRCODE = '23503';
  END IF;

  SELECT kg_per_ua INTO v_kg_per_ua FROM properties WHERE id = v_property_id;

  v_selected_count := jsonb_array_length(p_animal_ids);
  IF v_selected_count = 0 THEN
    RAISE EXCEPTION 'at least 1 animal must be selected' USING ERRCODE = '23514';
  END IF;

  -- D-32: concurrency revalidation — the whole transaction aborts if any submitted
  -- animal is no longer active in this exact lot. Never a partial write.
  SELECT count(*) INTO v_valid_count
    FROM animals a
    JOIN jsonb_array_elements_text(p_animal_ids) elem(id) ON a.id = elem.id::uuid
   WHERE a.lot_id = p_lot_id AND a.deleted_at IS NULL AND a.property_id = v_property_id;

  IF v_valid_count <> v_selected_count THEN
    RAISE EXCEPTION '% animais mudaram desde que a tela foi aberta — recarregue',
      (v_selected_count - v_valid_count)
      USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*) INTO v_active_count FROM animals WHERE lot_id = p_lot_id AND deleted_at IS NULL;

  SELECT jsonb_agg(jsonb_build_object(
           'animal_id', a.id, 'number', a.number,
           'category', a.category, 'ua', animal_ua_weight(a.category)
         )),
         sum(animal_ua_weight(a.category))
    INTO v_snapshot, v_total_ua
    FROM animals a
    JOIN jsonb_array_elements_text(p_animal_ids) elem(id) ON a.id = elem.id::uuid;

  -- D-02: per-animal volume/cost = ua × dosagem_por_ua / × custo_por_ua. Totals are
  -- the sum of that, expressed directly via total_ua (no per-animal loop needed).
  v_total_volume := v_total_ua * v_dose.dosage_per_kg * v_kg_per_ua;
  v_total_cost   := CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL
                          ELSE v_total_ua * v_dose.cost_per_kg * v_kg_per_ua END;

  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes
  ) VALUES (
    v_snapshot, v_property_id, p_lot_id, v_lot_name, v_dose.id, v_dose.name,
    v_dose.dosage_per_kg, v_dose.dosage_per_kg * v_kg_per_ua, v_dose.cost_per_kg,
    CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL ELSE v_dose.cost_per_kg * v_kg_per_ua END,
    p_applied_at, auth.uid(), v_selected_count, v_total_ua, v_total_volume, v_total_cost,
    v_active_count - v_selected_count, p_notes
  ) RETURNING id INTO v_app_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_app_id);
END;
$$;

REVOKE ALL ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) FROM public;
GRANT EXECUTE ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) TO authenticated;
```

### 4. reverse_sanitary_application RPC (D-27..D-31, D-30 role gate)
```sql
CREATE OR REPLACE FUNCTION reverse_sanitary_application(
  p_application_id uuid,
  p_reason         text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_orig   record;
  v_new_id uuid;
BEGIN
  SELECT * INTO v_orig FROM sanitary_applications WHERE id = p_application_id;
  IF v_orig.id IS NULL THEN
    RAISE EXCEPTION 'sanitary application % not found', p_application_id USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_orig.property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_orig.property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(v_orig.property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can reverse a sanitary application'
      USING ERRCODE = '42501';
  END IF;

  -- D-30: estorno de estorno é bloqueado.
  IF v_orig.reverses_application_id IS NOT NULL THEN
    RAISE EXCEPTION 'cannot reverse a reversal record' USING ERRCODE = '23514';
  END IF;

  IF trim(coalesce(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'reversal reason is required' USING ERRCODE = '22023';
  END IF;

  -- D-31: legible pre-check before the unique index's 23505 backstop.
  IF EXISTS (SELECT 1 FROM sanitary_applications WHERE reverses_application_id = p_application_id) THEN
    RAISE EXCEPTION 'sanitary application % was already reversed', p_application_id
      USING ERRCODE = 'P0003';
  END IF;

  -- Recommendation (Common Pitfalls #3 / Open Questions #1): negate all four numeric
  -- totals uniformly; applied_at = today (the reversal's own date), not the original's.
  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes,
    reverses_application_id
  ) VALUES (
    v_orig.composition_snapshot, v_orig.property_id, v_orig.lot_id, v_orig.lot_name,
    v_orig.dose_id, v_orig.dose_name, v_orig.dosage_per_kg, v_orig.dosage_per_ua,
    v_orig.cost_per_kg, v_orig.cost_per_ua, current_date, auth.uid(),
    -v_orig.animal_count, -v_orig.total_ua, -v_orig.total_volume,
    CASE WHEN v_orig.total_cost IS NULL THEN NULL ELSE -v_orig.total_cost END,
    v_orig.skipped_count, p_reason, v_orig.id
  ) RETURNING id INTO v_new_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_new_id);
END;
$$;

REVOKE ALL ON FUNCTION reverse_sanitary_application(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION reverse_sanitary_application(uuid, text) TO authenticated;
```

### 5. Isolation trigger (D-10, Pattern 3)
```sql
CREATE OR REPLACE FUNCTION enforce_sanitary_application_same_property()
RETURNS trigger LANGUAGE plpgsql SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM lots WHERE id = NEW.lot_id AND property_id = NEW.property_id) THEN
    RAISE EXCEPTION 'lot % does not belong to property %', NEW.lot_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM doses WHERE id = NEW.dose_id AND property_id = NEW.property_id) THEN
    RAISE EXCEPTION 'dose % does not belong to property %', NEW.dose_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;
  RETURN NEW;
END;
$$;

-- INSERT only — trg_snapshot_immutable (Phase 2) already blocks every UPDATE/DELETE
-- unconditionally, so there is no UPDATE path on this table to re-guard.
CREATE TRIGGER trg_sanitary_applications_same_property
  BEFORE INSERT ON sanitary_applications
  FOR EACH ROW
  EXECUTE FUNCTION enforce_sanitary_application_same_property();
```

### 6. SANI-05 lookup query (D-38, verified this session)
```sql
-- Postgres containment is recursive through array elements that are objects — a
-- partial-object match `{"animal_id": "..."}` against a longer object
-- `{"animal_id": "...", "number": 42, ...}` inside the array IS matched.
-- [VERIFIED: postgresql.org/docs/current/datatype-json.html "general principle" +
--  pgsql-hackers thread "Are we sufficiently clear that jsonb containment is nested?"]
SELECT *
  FROM sanitary_applications
 WHERE composition_snapshot @> jsonb_build_array(jsonb_build_object('animal_id', p_animal_id))
 ORDER BY applied_at DESC;
-- Uses sanitary_applications_composition_gin_idx (jsonb_path_ops).
```

### 7. Dart repository read (SANI-05)
```dart
// Source: mirrors AtfRepository.fetchReproductiveHistory's shape.
// .contains() maps to PostgREST's `cs` filter → SQL `@>`.
// [VERIFIED: Context7 /websites/supabase_reference_dart "Filter with contains"]
Future<List<SanitaryHistoryEntry>> fetchSanitaryHistory(String animalId) async {
  final rows = await _service.client
      .from('sanitary_applications')
      .select()
      .contains('composition_snapshot', [
        {'animal_id': animalId}
      ])
      .order('applied_at', ascending: false);
  return (rows as List)
      .map((r) => SanitaryApplication.fromJson(r as Map<String, dynamic>))
      .toList();
}
```

### 8. Dart exception mapping (D-35)
```dart
enum SanitaryApplicationErrorReason {
  forbidden,            // 42501
  compositionChanged,   // P0002 — e.message IS the exact pt-BR template, pass through
  alreadyReversed,      // P0003 (pre-check) or 23505 (unique-index backstop)
  invalidState,         // 23503 / 23514 / 22023 fallback
}

class SanitaryApplicationException implements Exception {
  const SanitaryApplicationException(this.reason, this.message);
  final SanitaryApplicationErrorReason reason;
  final String message;

  factory SanitaryApplicationException.fromPostgrest(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return const SanitaryApplicationException(
          SanitaryApplicationErrorReason.forbidden,
          'Apenas veterinários podem registrar aplicações sanitárias.',
        );
      case 'P0002':
        // The RPC's RAISE EXCEPTION message IS the UI-SPEC's exact copy template
        // ("[N] animais mudaram desde que a tela foi aberta — recarregue.") — no
        // static string needed here, just surface e.message.
        return SanitaryApplicationException(
          SanitaryApplicationErrorReason.compositionChanged,
          e.message,
        );
      case 'P0003':
      case '23505':
        return const SanitaryApplicationException(
          SanitaryApplicationErrorReason.alreadyReversed,
          'Esta aplicação já foi estornada.',
        );
      default:
        return const SanitaryApplicationException(
          SanitaryApplicationErrorReason.invalidState,
          'Não foi possível registrar a aplicação. Tente novamente.',
        );
    }
  }
}
```

### 9. Property model must add `kgPerUa` (integration point)
`DoseFormDialog`'s "Dosagem por UA (calculado)" field live-updates client-side as the user types (UI-SPEC field 4) — it needs `properties.kg_per_ua` on the client, not just server-side. Add to `lib/features/propriedades/data/propriedade_model.dart`:
```dart
const factory Property({
  required String id,
  required String name,
  String? owner,
  required DateTime createdAt,
  DateTime? deletedAt,
  @Default(400) double kgPerUa,   // D-12 — property-scoped, no UI this phase
}) = _Property;
```
Requires a `freezed`/`json_serializable` regen (`dart run build_runner build`) — same codegen step every prior phase has needed when a model gains a field.

## State of the Art

Not applicable in the "framework changed" sense — this is a single project's internal convention, not a public library. The one relevant "state of the art" fact is the JSONB containment behavior itself, which is stable across Postgres versions (documented since 9.4's jsonb introduction) and unaffected by this session's date.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Reversal row sign convention: negate `animal_count`/`total_ua`/`total_volume`/`total_cost` uniformly; `applied_at` on the reversal row = `CURRENT_DATE` (today), not the original's `applied_at` | Common Pitfalls #3, Code Examples §4 | If wrong, `AplicacaoHeaderCard`'s totals line or the estorno's position in date-sorted history lists could render confusingly (e.g., a negative-looking animal count, or the reversal appearing to have happened on the original's date rather than when it actually occurred). Low risk — purely cosmetic/ordering, not a data-integrity issue, but should be confirmed by the planner or user before locking, since CONTEXT.md D-28 does not spell out the exact columns |
| A2 | Custom ERRCODEs `P0002` (composition changed) and `P0003` (already reversed) are safe to introduce alongside the existing `P0001` (used by `prevent_snapshot_mutation`) | Code Examples §3/§4 | `P0xxx` is Postgres's reserved range for `plpgsql` `RAISE EXCEPTION` without an explicit code (default `P0001`); using `P0002`/`P0003` explicitly is standard practice for custom plpgsql errors and does not collide with any built-in Postgres error code — training-data knowledge, not verified against the Postgres error-codes table this session |

## Open Questions

1. **Reversal row's `applied_at` and sign convention (see Assumptions A1)**
   - What we know: D-28 requires "totais negativos" and D-06 requires `applied_at` for ordering; UI-SPEC's "Estornada em → date" implies the reversal has its own date.
   - What's unclear: whether `animal_count` specifically should be negative (a "count" being negative reads oddly in isolation) versus only the three monetary/volume/UA totals.
   - Recommendation: lock this explicitly in the plan (Code Examples §4 gives a concrete, internally-consistent default) rather than leaving it to the executor's judgment mid-implementation.

2. **`AnimalDetailScreen`'s existing `.length` check for empty `_ReproductiveHistorySection` vs. the new `_SanitaryHistorySection`**
   - What we know: D-37 requires the sanitary section to be built as a standalone widget with zero dependency on `AnimalDetailScreen`'s surrounding structure, exactly mirroring `_ReproductiveHistorySection`'s shell.
   - What's unclear: nothing blocking — this is confirmed straightforward by direct precedent (Code read in this session, `animal_detail_screen.dart` lines 370-443).
   - Recommendation: no action needed; flagged only to note the precedent was read and matches D-37's ask exactly.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI (linked, with DB password/TTY) | `supabase db push` for the new migration | ✗ | — | MCP `apply_migration` against live project `wrdwzychjhlpwpivfhhq` — same workaround used successfully for every migration since Phase 3 (STATE.md) |
| Docker (for `supabase test db` / local pgTAP) | Running `supabase/tests/06_sanitary_test.sql` | ✗ | — | MCP `execute_sql` in a `BEGIN...ROLLBACK` transaction against live PROD — proven pattern, used for `05_reproductive_test.sql` (34/35 assertions passed) per STATE.md |
| `04_movements_test.sql` (pgTAP suite) | D-42 — run alongside this phase's blocking wave | ✗ (never run) | — | Same MCP `execute_sql` workaround; D-42 explicitly schedules this in the same blocking plan since the MCP connection will already be open |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** Supabase CLI push and local pgTAP execution both have a proven MCP-based fallback already used successfully in Phases 3–5. The planner should schedule the migration push + both pgTAP suites (`06_sanitary_test.sql` + the still-unrun `04_movements_test.sql`, per D-41/D-42) as a dedicated blocking wave, exactly as Phase 5's `05-10-PLAN.md` did.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Dart unit/widget) + `pgTAP` (SQL, via Supabase CLI or MCP `execute_sql` fallback) |
| Config file | none dedicated — `pgTAP` suites live in `supabase/tests/*.sql`; Dart tests in `test/features/**/*_test.dart` |
| Quick run command | `flutter test test/features/sanitario/` (Dart, once created) |
| Full suite command | `flutter test` (Dart) + `supabase test db` or MCP `execute_sql` BEGIN/ROLLBACK replay (SQL) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SANI-01 | `valor_por_ua = valor_por_kg × kg_per_ua` computed correctly | unit | `flutter test test/features/sanitario/dose_calculations_test.dart` | ❌ Wave 0 |
| SANI-02 | UPDATE/DELETE blocked on `sanitary_applications` (extends existing) | SQL/pgTAP | MCP `execute_sql` replay of `06_sanitary_test.sql` | ❌ Wave 0 (extends `02_property_paddock_test.sql`'s existing 2 assertions) |
| SANI-02 | `register_sanitary_application` recomputes totals server-side, rejects tampered composition | SQL/pgTAP | same suite | ❌ Wave 0 |
| SANI-03 | Concurrency: animal removed from lot between load and confirm → RPC aborts whole transaction | SQL/pgTAP | same suite | ❌ Wave 0 |
| SANI-03 | UA/volume/cost totals: conversion kg→UA, filter estornadas, ordering by `applied_at` | unit | `flutter test test/features/sanitario/sanitary_calculations_test.dart` (D-40 — Dart tests cover ONLY calculation per explicit user decision) | ❌ Wave 0 |
| SANI-04/05 | GIN containment lookup returns correct rows for a moved animal | SQL/pgTAP | same suite | ❌ Wave 0 |
| Estorno | Unique reversal index blocks duplicate; reversal-of-reversal blocked | SQL/pgTAP | same suite | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/sanitario/` (fast, calculation-only per D-40)
- **Per wave merge:** full `flutter test` + the dedicated blocking wave's pgTAP replay (D-41)
- **Phase gate:** both `06_sanitary_test.sql` AND the still-outstanding `04_movements_test.sql` (D-42) green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `supabase/tests/06_sanitary_test.sql` — new pgTAP suite covering: immutability (extends `02_property_paddock_test.sql`'s existing assertions), reversal unique index, RLS isolation, RPC role rejection, concurrency abort, GIN containment lookup correctness (D-39)
- [ ] `test/features/sanitario/dose_calculations_test.dart` — pure kg→UA conversion, `valor_por_ua` formula (D-40)
- [ ] `test/features/sanitario/sanitary_calculations_test.dart` — total UA/volume/cost, estornada filtering, `applied_at` ordering (D-40)
- [ ] No new framework install needed — `flutter_test` and the project's `pgTAP` MCP-replay pattern are both already established.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no (unchanged from Phase 1) | Supabase Auth, already covers this module via `auth.uid()` |
| V3 Session Management | no (unchanged) | Supabase session handling, already established |
| V4 Access Control | yes | `is_member_of()` + `get_role() = 'veterinarian'` checks inside every SECURITY DEFINER RPC (Pattern 2), independent of the RLS SELECT-only policy on the mutated table |
| V5 Input Validation | yes | `p_animal_ids` JSONB array parsed via `jsonb_array_elements_text` + explicit `::uuid` cast (malformed input raises a Postgres cast error, not a silent no-op); `p_reason` NOT-blank check in `reverse_sanitary_application`; dose/lot existence checks before any computation |
| V6 Cryptography | no | not applicable — no new secrets/crypto in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Raw PostgREST INSERT bypassing the RPC's total-computation/concurrency logic | Tampering | Zero write policies on `sanitary_applications` — every mutation path is unreachable except through the two SECURITY DEFINER RPCs (Pattern 2, Anti-Patterns) |
| Client-submitted `total_ua`/`total_volume`/`total_cost` accepted at face value | Tampering | RPC recomputes every total from `animals.category` + `doses` + `properties.kg_per_ua` server-side; client never has a write path for these columns at all |
| TOCTOU: composition changes between screen-open and confirm | Tampering | RPC-side revalidation of every submitted animal id against current lot membership, whole-transaction abort on mismatch (D-32, Pitfall 2) |
| Double-reversal race (two concurrent estorno calls on the same application) | Tampering | Partial unique index `sanitary_applications_reversal_idx` (Pattern 4) — the actual guarantee; RPC's own `EXISTS` check is only for a legible error message |
| `anon` role UUID-existence oracle via RPC error codes | Information Disclosure | Pre-existing, tracked, low-severity gap (STATE.md, Common Pitfalls #4) — not introduced or worsened by this phase; do not attempt a local fix that diverges from the rest of the codebase's RPC structure |

## Sources

### Primary (HIGH confidence)
- Context7 `/websites/supabase_reference_dart` — `.contains()` filter for jsonb/array/range columns, confirmed maps to `@>`/`cs`
- `postgresql.org/docs/current/datatype-json.html` §8.14.3 (jsonb Containment and Existence) — "general principle" quote confirming recursive partial-match containment, including through array elements
- `postgresql.org/docs/current/gin.html` — `jsonb_path_ops` operator class support for `@>`, size/performance tradeoff vs. default `jsonb_ops`
- Direct codebase reads: `supabase/migrations/20260508_02_property_paddock.sql`, `20260514_03_lots_animals.sql`, `20260716_04_animal_lot_property_trigger.sql`, `20260804_05_reproductive_module.sql`, `20260805_05_atf_rpcs.sql`; `lib/features/reproducao/data/atf_repository.dart`; `lib/features/reproducao/presentation/atf_animal_selection_screen.dart`, `encerrar_atf_dialog.dart`; `lib/features/lotes/data/lote_repository.dart`, `presentation/lote_detail_screen.dart`; `lib/features/animais/presentation/animal_detail_screen.dart`, `data/animal_constants.dart`; `lib/core/router/routes.dart`, `router.dart`; `lib/features/propriedades/data/propriedade_model.dart`; `supabase/tests/02_property_paddock_test.sql`

### Secondary (MEDIUM confidence)
- pgsql-hackers mailing list thread "Are we sufficiently clear that jsonb containment is nested?" (postgresql.org/message-id) — corroborates the recursive object-in-array containment behavior with a real-world example, cross-checked against the official docs' "general principle" text
- pub.dev/documentation `intl` — `Intl.plural` signature (`required String other`)

### Tertiary (LOW confidence)
- Custom `P0002`/`P0003` ERRCODE convention (Assumptions A2) — training-data knowledge of Postgres's `P0xxx` reserved plpgsql-error range, not verified against the Postgres error-codes appendix this session
- Reversal-row sign/date convention (Assumptions A1) — a research-derived recommendation filling a genuine gap in CONTEXT.md D-28, not itself sourced from any document

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, everything is an established in-codebase pattern
- Architecture: HIGH — every mechanic (SECURITY DEFINER RPC, isolation trigger, partial unique index, immutability trigger) has a direct, working precedent read in this session
- Pitfalls: HIGH for #1/#2/#4 (grounded in direct codebase reads and STATE.md); MEDIUM for #3 (a genuine gap in locked decisions, flagged with a concrete recommendation rather than guessed silently)

**Research date:** 2026-08-06
**Valid until:** 30 days (stable internal-project conventions + stable Postgres semantics; re-verify only if CONTEXT.md/UI-SPEC change or a new Supabase major version ships)
