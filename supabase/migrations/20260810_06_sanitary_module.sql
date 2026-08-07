-- 20260810_06_sanitary_module.sql
-- Phase 6 — Sanitary Module (Snapshot)
-- References: SANI-01, SANI-02, SANI-03, SANI-04, SANI-05
-- Decisions: D-01 (extend Phase 2 skeleton, no child table), D-10 (isolation trigger),
--            D-11..D-15 (doses), D-12 (properties.kg_per_ua), D-31 (reversal unique index),
--            D-38 (GIN containment index)
--
-- Adds: properties.kg_per_ua; doses table (property-scoped RLS CRUD, no RPC);
--       animal_ua_weight() helper mirroring lib/features/animais/data/animal_constants.dart
--       kUaWeights; ALTER-only extension of the Phase 2 sanitary_applications skeleton with
--       header columns, indexes, one SELECT policy and the cross-table isolation trigger.
--
-- Neither this migration nor the companion 20260811_06_sanitary_rpcs.sql is applied here —
-- 06-12 owns the push (see 06-02-PLAN.md critical_scope_note).

-- ============================================================
-- 1. properties.kg_per_ua (D-12) — property-scoped UA/kg factor, no UI this phase
-- ============================================================
ALTER TABLE properties
  ADD COLUMN kg_per_ua numeric NOT NULL DEFAULT 400 CHECK (kg_per_ua > 0);

-- ============================================================
-- 2. doses (SANI-01, D-11..D-15) — direct RLS CRUD, mirrors lots/atf_batches shape
-- ============================================================
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
  USING (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum)
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);

-- No DELETE policy — archival is a deleted_at update, same as lots/paddocks/atf_batches (D-15).

-- ============================================================
-- 3. animal_ua_weight() — UA weight helper
-- ============================================================
-- Mirrors lib/features/animais/data/animal_constants.dart kUaWeights EXACTLY, which itself
-- sources REQUIREMENTS.md's Business Rules UA-per-category table. No single source of truth
-- exists yet between Dart and Postgres for this table — pre-existing gap since Phase 3, not
-- introduced by this phase. If kUaWeights changes, this function must change too (06-RESEARCH.md
-- Common Pitfalls #1 / key_links).
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

-- ============================================================
-- 4. sanitary_applications — extend the Phase 2 skeleton (ALTER only)
-- ============================================================
-- The table is guaranteed empty in every environment: Phase 2 shipped it with RLS enabled and
-- zero policies ("Phase 6 owns this table" — 20260508_02_property_paddock.sql §9), so no row
-- could have been inserted through the app. The NOT NULL columns below therefore need no
-- backfill (same A-SCHEMA-01 precedent as Phase 5's animal_atf_memberships.property_id).
--
-- ALTER only — never drop and recreate. composition_snapshot, prevent_snapshot_mutation() and
-- trg_snapshot_immutable from Phase 2 survive untouched, and 02_property_paddock_test.sql
-- already proves their immutability.
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

-- A registration row is positive, a reversal row is negative — never zero (D-08, D-28).
ALTER TABLE sanitary_applications ADD CONSTRAINT sanitary_applications_animal_count_check
  CHECK (animal_count <> 0);

-- ============================================================
-- 5. Indexes
-- ============================================================
CREATE INDEX sanitary_applications_property_idx ON sanitary_applications (property_id);
CREATE INDEX sanitary_applications_lot_idx       ON sanitary_applications (lot_id, applied_at DESC);

-- D-31: estorno único, same technique as animal_atf_memberships_active_idx
-- (20260508_02_property_paddock.sql §8). This partial unique index is the actual guarantee;
-- reverse_sanitary_application's own pre-check only turns a raw 23505 into a legible P0003.
CREATE UNIQUE INDEX sanitary_applications_reversal_idx
  ON sanitary_applications (reverses_application_id)
  WHERE reverses_application_id IS NOT NULL;

-- D-38: GIN containment index for SANI-05's per-animal lookup
-- (composition_snapshot @> '[{"animal_id":"..."}]').
CREATE INDEX sanitary_applications_composition_gin_idx
  ON sanitary_applications USING GIN (composition_snapshot jsonb_path_ops);

-- ============================================================
-- 6. Row level security — one SELECT policy only
-- ============================================================
CREATE POLICY "members_can_read_sanitary_applications"
  ON sanitary_applications FOR SELECT TO authenticated
  USING (is_member_of(property_id));

-- Deliberately NO INSERT/UPDATE/DELETE policy. register_sanitary_application() and
-- reverse_sanitary_application() (companion migration 20260811_06_sanitary_rpcs.sql) are the
-- entire write surface. Adding a write policy here would let a raw PostgREST call skip total
-- computation and the concurrency revalidation (D-32) entirely — same class of bug as Phase 4's
-- CR-01/WR-02 and Phase 5's T-05-01/T-05-04. trg_snapshot_immutable (Phase 2) already blocks
-- every UPDATE/DELETE unconditionally, independent of RLS.

-- ============================================================
-- 7. Cross-table isolation trigger (D-10)
-- ============================================================
-- INSERT only — trg_snapshot_immutable (Phase 2) already blocks every UPDATE/DELETE
-- unconditionally, so there is no UPDATE path on this table left to guard. Re-checking the same
-- invariant in both the RPC and this trigger would be the exact drift pitfall this codebase has
-- already flagged once (05-RESEARCH Pitfall 2 / Anti-Patterns).
CREATE OR REPLACE FUNCTION enforce_sanitary_application_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
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

CREATE TRIGGER trg_sanitary_applications_same_property
  BEFORE INSERT ON sanitary_applications
  FOR EACH ROW
  EXECUTE FUNCTION enforce_sanitary_application_same_property();
