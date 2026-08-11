-- 20260813_07_expenses_module.sql
-- Phase 7 — Expenses by Paddock
-- References: GAST-01, GAST-02
-- Decisions: D-03 (no category CHECK), D-04 (description nullable), D-20 (numeric(14,2)),
--            D-22 (soft delete, no DELETE policy), D-23 (owner+veterinarian write),
--            D-24 (all-member read), D-25 (direct-table CRUD, no RPC), D-26 (isolation
--            trigger), D-27 (created_by/updated_by auditing), D-30 (paddock freeze on
--            sanitary_applications), D-31 (approximate backfill of pre-existing rows),
--            D-34 (paddock_id NOT NULL)
--
-- Single migration file covering the `expenses` table, the `sanitary_applications`
-- paddock-freeze extension + backfill, and both sanitary RPC replacements. Resolves
-- 07-RESEARCH.md § Open Questions #1: a half-applied state where `expenses` exists but
-- `sanitary_applications.paddock_id` does not would leave the unified expense list
-- unable to render sanitary rows, and MCP `apply_migration` runs one file as one
-- transaction — a single file is the only way to make the whole rollout atomic.
--
-- Not applied by this plan — 07-08 owns the push (D-37, dedicated blocking plan).

-- ============================================================
-- 1. expenses (GAST-01, D-03, D-04, D-20, D-22..D-27, D-34)
-- ============================================================
CREATE TABLE expenses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id   uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  paddock_id    uuid NOT NULL REFERENCES paddocks(id),
  category      text NOT NULL CHECK (length(trim(category)) > 0),
  -- amount positivity: RESEARCH Assumption A3 recommendation, not a locked D-NN decision.
  -- Relaxing it later is a single `ALTER TABLE expenses DROP CONSTRAINT
  -- expenses_amount_check;` — no data migration required.
  amount        numeric(14,2) NOT NULL CHECK (amount > 0),
  expense_date  date NOT NULL,
  description   text,
  created_by    uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
  updated_by    uuid REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);
-- No CHECK on `category` values (D-03) — the list lives in Dart's expense_constants.dart,
-- deploy-time flexibility over a migration for every new/renamed category.

CREATE INDEX expenses_property_idx ON expenses (property_id);
CREATE INDEX expenses_paddock_date_idx ON expenses (paddock_id, expense_date DESC);

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_expenses" ON expenses FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "owner_vet_can_insert_expense" ON expenses FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
  );

-- G-06-2 avoidance (20260812_06_fix_dose_update_policy.sql): a soft-delete-aware
-- predicate in USING evaluates against the PRE-update row. Restoring an archived
-- expense (setting deleted_at back to NULL) would then be checked against a row that
-- is still archived, the predicate would reject it, zero rows would match, and
-- PostgREST would still answer 2xx — a silent no-op. This policy checks only
-- membership + role, nothing about the archival state, in both USING and WITH CHECK.
CREATE POLICY "owner_vet_can_update_expense" ON expenses FOR UPDATE TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
  )
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
  );

-- No DELETE policy — archival is a deleted_at UPDATE only (D-22), same as
-- doses/lots/paddocks/atf_batches. A financial record is never permanently destroyable
-- through this table's write surface.

CREATE OR REPLACE FUNCTION set_expenses_updated_by()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_by := auth.uid();
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_expenses_set_updated_by
  BEFORE UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION set_expenses_updated_by();

-- Isolation trigger (D-26) — copied verbatim from enforce_lot_paddock_same_property()
-- (20260717_04_lot_paddock_property_trigger.sql), substituting expenses for lots. RLS
-- WITH CHECK above only inspects property_id; it cannot see whether paddock_id actually
-- belongs to that property_id. A veterinarian or owner who is a member of two
-- properties holds a valid JWT for both and could otherwise craft a raw PostgREST PATCH
-- pairing a valid property_id with a foreign-property paddock_id — the exact bypass
-- class that reopened twice in Phase 4 (04-06, 04-07).
CREATE OR REPLACE FUNCTION enforce_expenses_paddock_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Fires on INSERT, on a paddock_id change, or on a property_id change. A soft-delete
  -- UPDATE touches only deleted_at, never paddock_id/property_id, so it does not
  -- re-trigger this validation and cannot false-positive on an archival/restore.
  IF NEW.paddock_id IS NOT NULL AND (
    TG_OP = 'INSERT'
    OR NEW.paddock_id IS DISTINCT FROM OLD.paddock_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM paddocks
       WHERE id = NEW.paddock_id
         AND property_id = NEW.property_id
         AND deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION
        'paddock % does not belong to property % or is archived',
        NEW.paddock_id, NEW.property_id USING ERRCODE = '23503';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_expenses_paddock_same_property
  BEFORE INSERT OR UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION enforce_expenses_paddock_same_property();
