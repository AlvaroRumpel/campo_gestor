# Phase 5: Reproductive Module (LoteATF) - Research

**Researched:** 2026-08-04
**Domain:** Postgres/Supabase RLS+RPC schema design and Flutter/Riverpod feature module — 100% internal pattern replication, zero new external dependencies
**Confidence:** HIGH

## Summary

Phase 5 is a **pure pattern-replication phase**: every architectural building block it needs
(RPC-guarded multi-row writes, property-alignment triggers, RLS with `FORCE ROW LEVEL SECURITY`,
Riverpod repository/provider layering, `AlertDialog` form templates, `ChoiceChip` selection rows)
already exists in `supabase/migrations/` and `lib/features/{animais,lotes}/` from Phases 2–4. No
new pub.dev package is required — the DG chips, date pickers, dropdowns, and lists are all
Material 3 SDK widgets already in use. The research value of this phase is not "which library" but
**"which exact schema/RPC shape closes the gaps the codebase has already been burned by twice"**
(Phase 4's CR-01/WR-02: RLS `WITH CHECK` does not inspect a *different* row's FK, so a raw
PostgREST `PATCH` bypasses app-level business rules unless a trigger or RPC blocks the write path
itself).

The single hardest design decision in this phase — not fully resolved by CONTEXT.md/UI-SPEC — is
**how the DB distinguishes three different ways an `animal_atf_memberships` row stops being
"active"**: manual removal before any DG (D-08), ATF closure (D-16), and animal baixa (D-19). All
three end with the animal no longer counted as "in the DG queue," but D-16 explicitly requires DG
**correction to remain possible after closure**, while D-08 requires a removed-before-DG animal to
**never** resurface in the DG list. Resolving this (see Architecture Patterns, Pattern 3) is the
single highest-value finding of this research: get it wrong and either SC-3 (DG editable until
closure) or D-08 (clean removal) silently breaks.

**Primary recommendation:** One migration file (`atf_batches`, `dg_records`, extend
`animal_atf_memberships` with `property_id`/FKs, 2 property-alignment+category triggers, RLS with
**zero direct INSERT/UPDATE/DELETE grants on the two junction tables** — every mutation after
`atf_batches` creation goes through a `SECURITY DEFINER` RPC), mirroring
`20260514_03_lots_animals.sql` + the Phase-4 gap-closure trio exactly. No new Flutter dependency.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ATF header CRUD (create) | API / Backend (Postgres RLS INSERT policy) | — | Single-row insert, no cross-entity validation needed — same as `paddocks`/`lots` INSERT (direct policy, no RPC) |
| Animal selection eligibility (vaca/novilha only, not-already-active) | Database / Storage (trigger + partial unique index) | Browser / Client (UI pre-filter, D-09) | UI filter is a courtesy; the trigger + unique index are the actual guarantee — Phase 4 lesson |
| Add/remove animals to ATF composition | API / Backend (`SECURITY DEFINER` RPC) | — | Multi-row / cross-entity write (D-21 point 3) |
| DG batch entry | API / Backend (`SECURITY DEFINER` RPC) | Browser / Client (staged local state before save, D-11) | Atomic multi-row insert; client only stages, never partial-commits |
| % prenhez calculation | Browser / Client (Dart, computed from loaded `dg_records`) | — | Resolves CONTEXT.md's open discretion item — see Pattern 4. Bounded dataset (farm-scale), matches existing `fetchLotsWithCountByProperty` 2-query-and-group-in-Dart convention; no new SQL view needed |
| ATF closure | API / Backend (`SECURITY DEFINER` RPC) | — | Bulk deactivation of N membership rows, role-gated |
| Baixa side-effect (deactivate ATF membership) | API / Backend (`SECURITY DEFINER` RPC, extends existing `registerBaixa`) | — | Now touches 2 tables atomically (D-19) — must convert from the current direct `UPDATE` to an RPC |
| Reproductive history read (ficha do animal) | API / Backend (RLS SELECT) | Browser / Client (group-by-animal, most-recent-DG-per-ATF) | Read-only, no write surface (D-13) |

## Package Legitimacy Audit

**Not applicable.** Phase 5 introduces **zero new pub.dev dependencies** — confirmed against
`pubspec.yaml` (read this session) and the UI-SPEC's `## Registry Safety` section, which already
states "Phase 5 introduces zero new pub.dev dependencies." All widgets used (`showDatePicker`,
`ChoiceChip`, `DropdownButtonFormField`, `CheckboxListTile`, `MaterialBanner`) are Flutter SDK
built-ins already in use elsewhere in the codebase (`animal_edit_dialog.dart`, `baixa_dialog.dart`,
`lote_form_dialog.dart`).

## Standard Stack

### Core (all reused, all `[VERIFIED: pubspec.yaml]` — read directly this session, no registry lookup needed)

| Library | Version (pinned in `pubspec.yaml`) | Purpose in Phase 5 | Confidence |
|---------|------|---------------------|------------|
| `flutter_riverpod` | `>=3.0.0 <4.0.0` | `FutureProvider`/`FutureProvider.family` for ATF list/detail/history providers | VERIFIED |
| `go_router` | `^17.2.0` | Root-level `/atf/:atfId` route (D-02), mirrors `loteById` | VERIFIED |
| `supabase_flutter` | `^2.12.0` | `.rpc()` calls for every mutating operation this phase | VERIFIED |
| `freezed_annotation` / `freezed` | `^3.0.0` / `^3.2.0` | `AtfBatch`, `DgRecord`, `AnimalAtfMembership` (or combined DTOs) freezed models | VERIFIED |
| `intl` | `^0.20.0` | `DateFormat('dd/MM/yyyy', 'pt_BR')` for implantation/insemination/session dates | VERIFIED |

### Supporting

None new. `data_table_2` (already a dependency, `^2.7.0`) is **not used this phase** — UI-SPEC's
Screen Inventory locks every list (ATF cards, composition rows, DG rows) to `ListView.builder` /
`ListTile`, resolving CONTEXT.md's open "data_table_2 vs ListView" discretion item in favor of
`ListView` (consistent with mobile-first 360px DG entry screen — `data_table_2` is a desktop-grid
tool and doesn't fit the corral-entry use case).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SQL view for % prenhez aggregation | Client-side computation from loaded `dg_records` (recommended) | A view is more efficient at scale but introduces a new abstraction the codebase doesn't otherwise use; farm-scale data (dozens of ATFs, hundreds of DGs) makes the Dart grouping trivially fast and matches the existing `fetchLotsWithCountByProperty` idiom exactly |
| RLS-only enforcement (`WITH CHECK` subqueries) for membership add/remove | `SECURITY DEFINER` RPC (recommended) | Phase 4 proved `WITH CHECK` cannot inspect a *different* row's FK reliably in a way the team trusts after two review cycles (CR-01, WR-02) — RPC keeps validation in one auditable place |

**Installation:** None — no new packages.

**Version verification:** All versions above were read directly from the project's `pubspec.yaml`
this session (not looked up on pub.dev) — this is stronger than a registry check since it reflects
the exact resolved versions already building in CI, not a hypothetical "latest."

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ Flutter (Riverpod)                                                   │
│                                                                       │
│  ReproducaoScreen ──tap──▶ AtfDetailScreen ◀──create──AtfFormDialog  │
│       │  (list, toggle          │  (header, composition,             │
│       │   encerrados)           │   DG mass-entry, encerrar)         │
│       │                          │                                    │
│       │                    ┌─────┴─────┐                             │
│       │                    ▼           ▼                             │
│       │         AtfAnimalSelectionScreen  EncerrarAtfDialog          │
│       │         (D-06 lote+avulsos picker) (D-15 manual closure)     │
│       │                                                               │
│  AnimalDetailScreen                                                  │
│   └─ _ReproductiveHistorySection (read-only, D-13/D-14)              │
└───────────────────────┬───────────────────────────────────────────┘
                         │ AtfRepository (via SupabaseService — never
                         │ imports supabase_flutter directly, T-3-09 rule)
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Supabase (Postgres)                                                  │
│                                                                       │
│  Direct INSERT (RLS-gated, veterinarian-only, single row):           │
│    atf_batches  ─────────────────────────────────────────┐          │
│                                                             │          │
│  SECURITY DEFINER RPCs (all cross-entity / multi-row writes):        │
│    add_animals_to_atf(atf_id, animal_ids[])  ──▶ animal_atf_memberships
│    remove_animal_from_atf(atf_id, animal_id) ──▶ (hard-delete, D-08) │
│    save_dg_records(atf_id, records jsonb[])  ──▶ dg_records          │
│    close_atf(atf_id)                          ──▶ memberships.active=false
│    register_baixa(animal_id, ...)  [extends Phase 3 RPC] ──▶ animals +
│                                                    animal_atf_memberships
│                                                                       │
│  Triggers (access-path-independent, mirrors Phase 4 pattern):        │
│    trg_atf_membership_valid — property match + category ∈ {vaca,novilha}
│    trg_dg_records_same_property — property match across FKs          │
│                                                                       │
│  RLS: SELECT-only for all authenticated members on the 2 junction    │
│  tables — no direct write grant, forcing every mutation through the  │
│  RPCs above (stronger than lots/animals precedent, justified because │
│  every write here is cross-entity by nature)                         │
└─────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/features/reproducao/
├── data/
│   ├── atf_model.dart              # AtfBatch freezed model
│   ├── dg_record_model.dart        # DgRecord freezed model
│   └── atf_repository.dart         # AtfRepository — all RPC calls + reads
├── presentation/
│   ├── reproducao_screen.dart      # replaces placeholder (D-01)
│   ├── atf_form_dialog.dart        # header-only create dialog (D-01, D-05)
│   ├── atf_detail_screen.dart      # header + composition + DG + encerrar
│   ├── atf_animal_selection_screen.dart  # lote+avulsos picker (D-06/D-07)
│   └── encerrar_atf_dialog.dart    # closure confirm (D-15)

supabase/migrations/
└── 20260804_05_reproductive_module.sql   # single migration, mirrors Phase 3's one-file convention
```

### Pattern 1: RPC-only mutation surface for junction tables

**What:** `atf_batches` gets a normal RLS `INSERT` policy (single-row, no cross-entity risk — same
shape as `veterinarian_can_insert_paddock`). But `animal_atf_memberships` and `dg_records` get
**only a `SELECT` policy**. No `INSERT`/`UPDATE`/`DELETE` grant exists on either table for the
`authenticated` role — every write happens inside a `SECURITY DEFINER` function.

**When to use:** Any table whose every legitimate write requires cross-entity validation (does
this animal belong to this property? is this animal's category eligible? is this ATF still open?).
This is stricter than the `lots`/`animals` precedent (which allow direct single-entity `UPDATE`)
because, unlike a lot's `name` field, there is no legitimate direct write to a membership or DG row
that doesn't require checking a sibling table first.

**Example:**
```sql
-- Source: mirrors supabase/migrations/20260715_04_gap_move_animal_to_lot.sql pattern
CREATE OR REPLACE FUNCTION add_animals_to_atf(
  p_atf_batch_id uuid,
  p_animal_ids   uuid[]
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id
    FROM atf_batches WHERE id = p_atf_batch_id AND active = true;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf % not found or already closed', p_atf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can add animals to an ATF'
      USING ERRCODE = '42501';
  END IF;

  -- Bulk insert — the trg_atf_membership_valid trigger (Pattern below) rejects
  -- any animal_id with the wrong property or an ineligible category; the
  -- partial unique index (animal_atf_memberships_active_idx, Phase 2) rejects
  -- any animal already active elsewhere. Both fire per-row inside this loop.
  INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, active, property_id)
  SELECT a, p_atf_batch_id, true, v_property_id
  FROM unnest(p_animal_ids) AS a;
END;
$$;

REVOKE ALL ON FUNCTION add_animals_to_atf(uuid, uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION add_animals_to_atf(uuid, uuid[]) TO authenticated;
```

### Pattern 2: Property-alignment + category trigger on `animal_atf_memberships`

**What:** A single `BEFORE INSERT` trigger (memberships are never `UPDATE`d after insert in this
design — see Pattern 3) that enforces D-09's "apenas vacas e novilhas" **at the database boundary**,
not just in the UI's `AtfAnimalSelectionScreen` filter. Mirrors
`enforce_animal_lot_same_property` exactly, extended with the category check.

**Example:**
```sql
-- Source: mirrors supabase/migrations/20260716_04_animal_lot_property_trigger.sql
CREATE OR REPLACE FUNCTION enforce_atf_membership_valid()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_category text;
  v_animal_property uuid;
BEGIN
  SELECT category, property_id INTO v_category, v_animal_property
    FROM animals WHERE id = NEW.animal_id AND deleted_at IS NULL;

  IF v_animal_property IS NULL THEN
    RAISE EXCEPTION 'animal % not found or is archived', NEW.animal_id
      USING ERRCODE = '23503';
  END IF;
  IF v_animal_property IS DISTINCT FROM NEW.property_id THEN
    RAISE EXCEPTION 'animal % does not belong to property %',
      NEW.animal_id, NEW.property_id USING ERRCODE = '23503';
  END IF;
  IF v_category NOT IN ('vaca', 'novilha') THEN
    RAISE EXCEPTION 'category % is not eligible for ATF (only vaca/novilha)',
      v_category USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atf_membership_valid
  BEFORE INSERT ON animal_atf_memberships
  FOR EACH ROW
  EXECUTE FUNCTION enforce_atf_membership_valid();
```

### Pattern 3: Removal vs. closure vs. baixa — three states, ONE `active` flag, TWO mechanisms

**This is the load-bearing design decision of the phase — read carefully.**

D-08 (remove before DG), D-16 (closure, DG still correctable), and D-19 (baixa) all end with an
animal no longer "active" in an ATF. But they have **different implications for whether a new DG
can still be recorded for that animal**:

| Event | Membership row | New DG recordable afterward? |
|-------|----------------|-------------------------------|
| D-08 removal (only allowed when animal has zero DG) | **Hard-deleted** — nothing to preserve, no DG was ever taken | No — row is gone, `save_dg_records` correctly rejects it |
| D-16 ATF closure | Soft-deactivated (`active = false`), row stays | **Yes** — D-16 explicitly requires DG correction to remain possible |
| D-19 baixa | Soft-deactivated (`active = false`), row stays | Not expected in practice, but not technically blocked (harmless — a dead/sold animal simply won't be walked through the corral again) |

**The guard `save_dg_records` must use is therefore "does a membership row exist for this
(atf_batch_id, animal_id) pair" — NOT "is the membership currently active."** This single query
shape resolves all three decisions correctly without any extra flag or state machine:

```sql
-- Inside save_dg_records, per record in the batch:
IF NOT EXISTS (
  SELECT 1 FROM animal_atf_memberships
   WHERE atf_batch_id = p_atf_batch_id AND animal_id = v_animal_id
) THEN
  RAISE EXCEPTION 'animal % was never a member of atf %, or was removed',
    v_animal_id, p_atf_batch_id USING ERRCODE = '23503';
END IF;
```

This also resolves the `_DgSection` animal-list query on the client: **list every membership row
for the ATF regardless of `active`** (closed ATFs still show their full roster for correction),
while `_CompositionSection`'s add/remove UI uses **`active = true` only** (correctly hides
already-removed/closed rows from the "N animais" composition count going forward). `remove_animal_from_atf`
therefore does a real `DELETE`, not an `UPDATE ... SET active = false`:

```sql
CREATE OR REPLACE FUNCTION remove_animal_from_atf(
  p_atf_batch_id uuid,
  p_animal_id    uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id FROM atf_batches
   WHERE id = p_atf_batch_id AND active = true;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf % not found or already closed', p_atf_batch_id USING ERRCODE = '23503';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can remove animals' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM dg_records WHERE atf_batch_id = p_atf_batch_id AND animal_id = p_animal_id) THEN
    RAISE EXCEPTION 'animal % already has a DG in this atf — cannot remove, only encerramento closes it',
      p_animal_id USING ERRCODE = '23514';
  END IF;
  DELETE FROM animal_atf_memberships
   WHERE atf_batch_id = p_atf_batch_id AND animal_id = p_animal_id AND active = true;
END;
$$;
```

### Pattern 4: % prenhez computed client-side from loaded `dg_records`

**What:** Resolves CONTEXT.md's open discretion item ("view/função SQL ou no cliente"). Recommend
client-side, matching `LoteRepository.fetchLotsWithCountByProperty`'s established 2-query-and-group
idiom (avoids introducing a new SQL-view abstraction the codebase doesn't otherwise use).

**Example (Dart, per-ATF or per-property depending on caller):**
```dart
// Source: pattern mirrors LoteRepository.fetchLotsWithCountByProperty grouping logic
class DgSummary {
  const DgSummary({required this.pregnant, required this.total, required this.pendingCount});
  final int pregnant; // D-17: numerator — only 'pregnant', doubtful excluded
  final int total;    // D-17: denominator — distinct animals with >=1 DG (any result)
  final int pendingCount; // composition count minus `total`
}

DgSummary summarizeDg(List<DgRecord> records, int compositionCount) {
  // D-12: most-recent DG per animal wins. created_at DESC is the tie-breaker
  // (not exam_date — D-11 allows the vet to override exam_date per animal,
  // so insertion order is the only reliable "most recent" signal).
  final byAnimal = <String, DgRecord>{};
  for (final r in records..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
    byAnimal[r.animalId] = r; // later insertion overwrites — last write wins
  }
  final pregnant = byAnimal.values.where((r) => r.result == 'pregnant').length;
  return DgSummary(
    pregnant: pregnant,
    total: byAnimal.length,
    pendingCount: compositionCount - byAnimal.length,
  );
}
```

### Anti-Patterns to Avoid

- **Reusing `active` as a tri-state flag (e.g. adding a `removed` boolean):** Don't. The
  exists-vs-not-exists distinction (Pattern 3) already carries all the information needed — an
  extra column would duplicate state and risk drifting out of sync.
- **Letting the client compute and persist a cached `% prenhez` column on `atf_batches`:** Don't
  denormalize this. It's cheap to recompute from `dg_records` on every read (Pattern 4) and a
  cached column would need invalidation on every DG save — unnecessary complexity for farm-scale
  data volumes.
- **Trusting a client-supplied `property_id` parameter in any RPC:** Every RPC in this phase must
  derive `property_id` server-side from a FK lookup (`atf_batches.property_id`, `animals.property_id`),
  never accept it as a raw parameter to be trusted — mirrors `move_animal_to_lot`'s pattern exactly
  (loads `v_property_id` from the row, never from a param).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Most recent DG per animal" | A `is_latest` boolean column maintained by triggers | `ORDER BY created_at DESC` + take-first in Dart (Pattern 4) | Simpler, no trigger-maintained denormalized state to get wrong on concurrent writes |
| Cross-property FK tampering guard | Trusting RLS `WITH CHECK` alone | `SECURITY DEFINER` RPC + property-alignment trigger (Pattern 1/2) | Directly the Phase 4 CR-01/WR-02 lesson — already proven insufficient twice in this codebase |
| Touro (bull) picker data source | A new query/table | Filter the already-loaded `animalListByPropertyProvider` client-side by `category == 'touro' && deletedAt == null` | Zero new backend surface; data is already fetched for `/animais` |
| DG mass-entry chip row | A new custom multi-select widget | `ChoiceChip` in a `Wrap`, same shape as `AnimalEditDialog`'s EC 1–5 row, restyled per UI-SPEC's semantic color mapping | Established, tested pattern in this exact codebase |

**Key insight:** Every "don't hand-roll" here is really "don't re-derive a pattern this codebase
already has a working, reviewed answer for." Phase 5 has no genuinely novel technical problem —
its risk is entirely in getting the state-machine details (Pattern 3) and the RLS/RPC boundary
(Pattern 1) exactly right, not in picking new tools.

## Common Pitfalls

### Pitfall 1: Conflating "removed" with "closed/baixa'd" using a single `active` flag naively
**What goes wrong:** If `remove_animal_from_atf` does `UPDATE ... SET active = false` (instead of
`DELETE`) like `close_atf` and the baixa RPC do, then `save_dg_records`'s guard cannot distinguish
"removed before any DG, should never accept a DG" from "closed, correction still allowed" — both
look identical (`active = false`, row present).
**Why it happens:** `active = false` is the idiom used everywhere else in this codebase for
soft-deactivation (lots, animals via `deleted_at`), so it's tempting to reuse it uniformly here too.
**How to avoid:** Pattern 3 above — removal is the one case that hard-deletes because D-08 only
allows it when zero DG exists (nothing to preserve). Closure and baixa always soft-deactivate.
**Warning signs:** A widget test where a removed-then-re-added-elsewhere animal still shows a
"ghost" DG row from its earlier (removed) ATF, or where DG correction on a closed ATF silently
fails with a "not found" error.

### Pitfall 2: Category check placed only in the trigger, never mirrored server-side in the RPC
**What goes wrong:** Not really a pitfall — the trigger alone is sufficient and access-path
independent (fires on the RPC's `INSERT` too). Flagging this explicitly so the plan does NOT
duplicate the category check inside `add_animals_to_atf`'s plpgsql body "for clarity" — the
trigger already covers it, and Phase 4's own migrations show duplicating a check in both the RPC
and the trigger is acceptable defense-in-depth but not required. Keep the RPC lean; let the trigger
own this invariant, matching `move_animal_to_lot`'s division of labor (RPC owns role/membership/
no-op checks, trigger owns cross-table FK-alignment).

### Pitfall 3: Advisory lock cargo-culted from `generate_animal_number`/`create_lot_with_animals`
**What goes wrong:** Those RPCs need `pg_advisory_xact_lock` because they generate a *sequential
number* under contention. Nothing in Phase 5 generates a sequence — `add_animals_to_atf` and
`save_dg_records` are plain bulk inserts with no shared counter. Adding an advisory lock here would
be unnecessary serialization with zero correctness benefit.
**How to avoid:** Don't add `pg_advisory_xact_lock` to any Phase 5 RPC. The partial unique index
(`animal_atf_memberships_active_idx`) already handles the one real concurrency hazard (two
concurrent adds of the same animal to two different ATFs) — Postgres's own row-level locking on
the unique index is sufficient, exactly as it was proven sufficient in `02_property_paddock_test.sql`.

### Pitfall 4: Forgetting `animal_atf_memberships` currently has NO FK on `animal_id`/`atf_batch_id`
**What goes wrong:** CONTEXT.md's canonical refs explicitly note the Phase 2 skeleton has
`animal_id uuid NOT NULL` and `atf_batch_id uuid NOT NULL` with **no `REFERENCES` clause** ("sem
FKs"). If the Phase 5 migration only adds `property_id` and forgets to also `ADD CONSTRAINT ...
FOREIGN KEY`, orphaned membership rows become possible (e.g. after a hard `DELETE` of an animal —
though animals only soft-delete, so this is a smaller risk, but `atf_batches` rows created and then
somehow removed would orphan memberships).
**How to avoid:** The migration must explicitly `ALTER TABLE animal_atf_memberships ADD CONSTRAINT
... FOREIGN KEY (animal_id) REFERENCES animals(id)` and the same for `atf_batch_id →
atf_batches(id)`, in addition to the `property_id` column addition. Verify with `\d
animal_atf_memberships` (or an information_schema query) before considering the migration done —
this is a good pgTAP `has_fk` assertion to add to the Phase 5 test file.

### Pitfall 5: `dg_records` accepting a `not-yet-existing membership` via a stale composition list
**What goes wrong:** `_DgSection`'s row list on the client is built from the already-loaded
composition data (D-10: "mesma lista, não uma query separada" per UI-SPEC). If the vet has the
`AtfDetailScreen` open in one tab while another vet removes an animal in another tab, a stale
client could still submit a DG for the now-removed animal.
**How to avoid:** This is exactly what Pattern 3's `EXISTS` guard inside `save_dg_records` catches
server-side — the RPC must loop per-record and skip/reject any `animal_id` with no membership row,
returning a clear error rather than silently succeeding partially. Reject the whole batch
atomically (plpgsql function body is already one transaction) rather than partially applying —
matches the "atomic or nothing" requirement already stated in D-21/UI-SPEC's DG Batch Save section.

## Code Examples

### `save_dg_records` — the core mass-entry RPC (D-10, D-11, D-12, D-21)
```sql
-- Source: pattern combines create_lot_with_animals' jsonb_each loop style
-- (20260514_03_lots_animals.sql) with move_animal_to_lot's validation shape.
CREATE OR REPLACE FUNCTION save_dg_records(
  p_atf_batch_id uuid,
  p_records      jsonb   -- [{"animal_id": "...", "result": "pregnant", "exam_date": "2026-08-04", "observation": null}, ...]
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
  v_rec         jsonb;
  v_animal_id   uuid;
  v_result      text;
BEGIN
  SELECT property_id INTO v_property_id FROM atf_batches WHERE id = p_atf_batch_id;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf % not found', p_atf_batch_id USING ERRCODE = '23503';
  END IF;
  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can record DG' USING ERRCODE = '42501';
  END IF;

  -- D-15 is intentionally NOT checked here: DG correction stays possible
  -- after closure (D-16) — this RPC does not gate on atf_batches.active.

  FOR v_rec IN SELECT * FROM jsonb_array_elements(p_records) LOOP
    v_animal_id := (v_rec ->> 'animal_id')::uuid;
    v_result := v_rec ->> 'result';

    IF v_result NOT IN ('pregnant', 'not_pregnant', 'doubtful') THEN
      RAISE EXCEPTION 'invalid DG result: %', v_result USING ERRCODE = '22023';
    END IF;

    -- Pattern 3 guard: row must exist (active or not) — see Architecture Patterns.
    IF NOT EXISTS (
      SELECT 1 FROM animal_atf_memberships
       WHERE atf_batch_id = p_atf_batch_id AND animal_id = v_animal_id
    ) THEN
      RAISE EXCEPTION 'animal % is not (or is no longer) a member of atf %',
        v_animal_id, p_atf_batch_id USING ERRCODE = '23503';
    END IF;

    INSERT INTO dg_records (property_id, atf_batch_id, animal_id, result, exam_date, observation)
    VALUES (
      v_property_id, p_atf_batch_id, v_animal_id, v_result,
      (v_rec ->> 'exam_date')::date, v_rec ->> 'observation'
    );
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION save_dg_records(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION save_dg_records(uuid, jsonb) TO authenticated;
```

### `close_atf` — manual closure (D-15, D-16)
```sql
CREATE OR REPLACE FUNCTION close_atf(p_atf_batch_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id FROM atf_batches
   WHERE id = p_atf_batch_id AND active = true;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'atf % not found or already closed', p_atf_batch_id USING ERRCODE = '23503';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can close an ATF' USING ERRCODE = '42501';
  END IF;

  UPDATE atf_batches SET active = false WHERE id = p_atf_batch_id;
  -- D-16: frees every animal's slot in the partial unique index for a new cycle.
  UPDATE animal_atf_memberships SET active = false
   WHERE atf_batch_id = p_atf_batch_id AND active = true;
END;
$$;
```

### `register_baixa` — extends the Phase 3 direct-UPDATE into an RPC (D-19)
```dart
// Source: pattern mirrors AnimalRepository.moveAnimal's rpc() call shape.
// AnimalRepository.registerBaixa CHANGES from a direct .update() to:
Future<void> registerBaixa({
  required String id,
  required BaixaReason reason,
  required DateTime date,
  String? observation,
}) async {
  await _service.client.rpc('register_baixa', params: {
    'p_animal_id': id,
    'p_reason': reason.dbValue,
    'p_date': date.toUtc().toIso8601String().substring(0, 10),
    if (observation != null) 'p_observation': observation,
  });
}
```
```sql
CREATE OR REPLACE FUNCTION register_baixa(
  p_animal_id uuid, p_reason text, p_date date, p_observation text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_property_id uuid;
BEGIN
  SELECT property_id INTO v_property_id FROM animals WHERE id = p_animal_id AND deleted_at IS NULL;
  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or already archived', p_animal_id USING ERRCODE = '23503';
  END IF;
  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register baixa' USING ERRCODE = '42501';
  END IF;

  UPDATE animals SET
    baixa_reason = p_reason, baixa_date = p_date, deleted_at = now(),
    observation = COALESCE(p_observation, observation)
   WHERE id = p_animal_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'animal % was archived concurrently', p_animal_id USING ERRCODE = '23503';
  END IF;

  -- D-19: deactivate any active ATF membership in the SAME transaction, no dialog, no block.
  UPDATE animal_atf_memberships SET active = false
   WHERE animal_id = p_animal_id AND active = true;
END;
$$;
```
**Note:** `register_baixa` lives in the Phase 5 migration but modifies `lib/features/animais/data/animal_repository.dart`
(Phase 3/4 file) — flagged explicitly since it's a cross-feature edit easy to miss in planning.

## State of the Art

Not applicable — this phase makes no framework-version or library-currency decisions (see Standard
Stack: zero new dependencies, all versions read directly from the pinned `pubspec.yaml`).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | PostgREST/`supabase_flutter`'s `.rpc()` correctly serializes a Dart `List<String>` to a Postgres `uuid[]` RPC parameter | Pattern 1 (`add_animals_to_atf`) | Low — well-established `postgrest-dart` behavior, but not verified against a **live** Supabase instance this session (STATE.md's blocker: Supabase CLI unlinked/unauthenticated). If wrong, swap `p_animal_ids uuid[]` for a `jsonb` array param (same shape as `p_category_qtys` in the Phase 3 RPC) — trivial fallback, no architecture change needed. **Add a Wave 0 smoke-test task that exercises this RPC against the dev project before building the full UI around it.** |
| A2 | `created_at DESC` (insertion order) is an acceptable tie-breaker for "most recent DG," rather than `exam_date DESC` | Pattern 4, Code Examples | Medium — D-11 explicitly allows the vet to override the session date per-animal, meaning `exam_date` could theoretically be set *earlier* than a prior record's `exam_date` for a legitimate reexam (rare but not impossible field scenario: reexam logged with a manually-corrected earlier date). If this matters to the vet domain expert, switch the tie-breaker to `exam_date DESC, created_at DESC`. Flagged in STATE.md's existing "Confirm with veterinarian domain expert before Phase 5/6" open TODO — this is likely the concrete question to ask. |
| A3 | `atf_batches` needs no `UPDATE` RLS policy at all (closure is the only post-create state change, always via `close_atf` RPC) | Pattern 1, Architectural Responsibility Map | Low — if a future requirement needs "edit ATF header after creation" (not in REPR-01..05 scope), a `veterinarian_can_update_active_atf` policy can be added later without touching this phase's other decisions. |

## Open Questions

1. **Should `save_dg_records` reject writes for a `not_pregnant`/`doubtful` reexam that would
   *decrease* pregnancy count on an already-`pregnant`-marked animal?**
   - What we know: D-12 says "most recent DG wins," implying any override is allowed (a
     pregnant→doubtful correction is a legitimate typo fix per D-16).
   - What's unclear: whether the vet domain expert wants a confirmation step for downgrades
     specifically (not currently in UI-SPEC — no such dialog specified).
   - Recommendation: Ship without a special confirmation (matches the "additive, no extra
     friction" philosophy stated throughout D-10..D-12); revisit only if UAT surfaces confusion.

2. **`AtfAnimalSelectionScreen`'s "já em ATF [nome]" lookup — property-wide or excluding the
   currently-open ATF?**
   - What we know: An animal already added to *this* ATF should not appear in the picker's
     "avulsos" search at all (already in composition).
   - What's unclear: UI-SPEC doesn't explicitly state the exclusion filter for animals already in
     the current ATF vs. a different active one.
   - Recommendation: The eligibility query should exclude animals whose active membership
     `atf_batch_id = current atf` from the pickable list entirely (they're already composed, no
     action needed), and disable-with-reason animals whose active membership is a *different*
     `atf_batch_id` (D-07). This is an implementation detail for the repository method, not a
     schema question — flag for the planner to encode explicitly in the eligibility query's
     `WHERE` clause.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI (linked + authenticated) | `supabase db push` for the new migration | ✗ (per STATE.md Blockers, carried over from Phase 4: "unlinked/unauthenticated, no TTY for a DB password") | — | Author the migration file and verify it locally via `supabase test db` if a local stack is reachable; mark the live push as a `checkpoint:human-verify`/blocked task, exactly as Phases 4's 04-03/04-06/04-07 did |
| Local Supabase stack (Docker) | pgTAP tests (`supabase test db`) for the new triggers/RPCs | Unknown — not probed this session (no shell access to Docker confirmed) | — | If unavailable, pgTAP test file can still be authored and reviewed; execution deferred to whoever has the linked CLI, same as prior phases |
| Flutter SDK / `flutter test` | Widget + repository tests | ✓ (project builds and has passing tests through Phase 4, per STATE.md "23/23 plans complete") | matches `pubspec.yaml` `sdk: ^3.11.4` | — |

**Missing dependencies with no fallback:** None — the CLI blocker has an established fallback
(author + defer push) already used successfully in Phase 4.

**Missing dependencies with fallback:** Supabase CLI push (fallback: author migration, defer push
to a human with credentials, same pattern as 04-03/04-06/04-07).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` + `mocktail: ^1.0.5` (Dart/widget); `pgTAP` via `supabase test db` (SQL) |
| Config file | none dedicated — no `dart_test.yaml`; tests run via default `flutter test` discovery under `test/` |
| Quick run command | `flutter test test/features/reproducao test/widget/atf_*_test.dart` |
| Full suite command | `flutter test` (Dart) + `supabase test db` (pgTAP, requires local stack) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REPR-01 | Create ATF with header fields, bull hybrid validation (D-05) | widget | `flutter test test/widget/atf_form_dialog_test.dart` | ❌ Wave 0 |
| REPR-02 | Eligible-animal filter + disabled-row rendering + partial-unique-index rejection | widget + pgTAP | `flutter test test/widget/atf_animal_selection_screen_test.dart` / `supabase test db` | ❌ Wave 0 |
| REPR-03 | DG batch save, additive multi-DG per animal, editable pre-closure and post-closure | widget + pgTAP | `flutter test test/widget/atf_detail_screen_test.dart` / `supabase test db` | ❌ Wave 0 |
| REPR-04 | % prenhez formula (duvidosa in denominator not numerator, most-recent-wins, baixa'd-with-DG counted) | unit | `flutter test test/features/reproducao/dg_summary_test.dart` | ❌ Wave 0 |
| REPR-05 | Reproductive history read-only list on `AnimalDetailScreen`, ordered by insemination date desc | widget | `flutter test test/widget/animal_detail_screen_test.dart` (extend existing file) | Partial — file exists, needs new test group |

### Sampling Rate
- **Per task commit:** `flutter test test/features/reproducao` (and the relevant modified widget test file)
- **Per wave merge:** `flutter test` (full Dart suite) + `supabase test db` (if local stack reachable)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/features/reproducao/atf_repository_test.dart` — contract tests for `AtfRepository` (mirrors `lote_repository_test.dart`'s Wave 1 contract-test style: method-exists + model round-trip, no live Supabase call)
- [ ] `test/features/reproducao/dg_summary_test.dart` — pure unit test for `summarizeDg()` (Pattern 4): zero-DG → null/"—" (E10 backstop), duvidosa-in-denominator-not-numerator (D-17), most-recent-per-animal (D-12), baixa'd-animal-with-DG counted (D-20)
- [ ] `test/widget/atf_form_dialog_test.dart`, `atf_detail_screen_test.dart`, `atf_animal_selection_screen_test.dart`, `encerrar_atf_dialog_test.dart` — new widget test files, `_Fake*Repository` pattern per `mover_animal_dialog_test.dart`/`lote_form_dialog_test.dart`
- [ ] `supabase/tests/05_reproductive_test.sql` — pgTAP: partial unique index still enforced after Phase 5's `property_id` column addition (regression check on the Phase 2 test), category-trigger rejection (touro/terneiro), property-mismatch trigger rejection, `save_dg_records` exists-guard (Pattern 3) via `throws_ok`
- [ ] Framework install: none — `flutter_test`/`mocktail`/pgTAP all already present from Phase 0–4

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No — unchanged from Phase 1 | — |
| V3 Session Management | No — unchanged | — |
| V4 Access Control | **Yes** | RLS `FORCE ROW LEVEL SECURITY` on all 3 tables + `SECURITY DEFINER` RPCs re-deriving `property_id`/role server-side, never trusting client params (Pattern 1) |
| V5 Input Validation | **Yes** | `CHECK` constraints (`dg_records.result`, date ordering), `enforce_atf_membership_valid` trigger (category), plpgsql `RAISE EXCEPTION` on malformed `jsonb` batch payloads |
| V6 Cryptography | No | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Cross-tenant IDOR via raw PostgREST `PATCH`/`POST` bypassing app-level ATF business rules | Tampering | No direct `INSERT`/`UPDATE`/`DELETE` RLS grant on `animal_atf_memberships`/`dg_records` — the write surface IS the RPC (Pattern 1); this is a structural fix, not a detection, of the exact bug class Phase 4 found twice (CR-01, WR-02) |
| Category bypass (adding a `touro`/`terneiro` to an ATF via direct write) | Tampering | `enforce_atf_membership_valid` trigger (Pattern 2), fires regardless of access path |
| Mass assignment via a client-supplied `property_id` param trusted at face value | Elevation of Privilege | Every RPC derives `property_id` from a FK lookup on the row being referenced, never accepts it as a raw trusted param (matches `move_animal_to_lot`'s established shape) |
| TOCTOU race between concurrent `register_baixa` and `save_dg_records` on the same animal | Tampering (race condition) | `register_baixa`'s `UPDATE ... WHERE deleted_at IS NULL` + `IF NOT FOUND` re-check mirrors the WR-01 fix already applied to `move_animal_to_lot`; `save_dg_records`'s exists-guard runs inside the same transaction as the insert, so a concurrent removal mid-batch would raise on the next iteration rather than silently succeed |

## Sources

### Primary (HIGH confidence — direct codebase read, this session)
- `supabase/migrations/20260508_02_property_paddock.sql` — `animal_atf_memberships` skeleton, partial unique index, `get_role()`
- `supabase/migrations/20260514_03_lots_animals.sql` — `create_lot_with_animals` RPC shape (jsonb loop, advisory lock precedent)
- `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql`, `20260716_04_animal_lot_property_trigger.sql`, `20260717_04_lot_paddock_property_trigger.sql` — RPC + trigger patterns this phase mirrors directly
- `supabase/tests/02_property_paddock_test.sql` — proves the partial unique index behavior to preserve
- `lib/features/animais/data/animal_repository.dart`, `lib/features/lotes/data/lote_repository.dart` — repository/provider conventions
- `lib/features/animais/presentation/{baixa_dialog,animal_edit_dialog,mover_animal_dialog,animal_detail_screen,animais_screen}.dart`, `lib/features/lotes/presentation/lote_form_dialog.dart` — dialog/form/list widget templates
- `.planning/phases/05-reproductive-module-loteatf/05-UI-SPEC.md` — locked visual/interaction contract (all layout/copy decisions already made, not re-litigated here)
- `pubspec.yaml` — exact pinned dependency versions

### Secondary (MEDIUM confidence)
- None — no external documentation lookups were needed; this phase's entire technical surface is internal-pattern replication.

### Tertiary (LOW confidence / flagged as assumptions)
- A1, A2, A3 in Assumptions Log above.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, all versions read from `pubspec.yaml` directly
- Architecture: HIGH — every pattern mirrors an existing, tested migration/repository/widget file in this exact codebase
- Pitfalls: HIGH for Pitfalls 1–4 (derived from direct close-reading of CONTEXT.md's decisions against each other, not external knowledge); MEDIUM for Pitfall 5 (plausible race condition, not observed in this codebase yet)

**Research date:** 2026-08-04
**Valid until:** No expiry driver — this research has no external-library currency dependency (0 new packages). Re-derive only if CONTEXT.md's decisions D-08/D-16/D-19 change.
