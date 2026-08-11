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

-- ============================================================
-- 2. sanitary_applications paddock freeze (D-30, D-31)
-- ============================================================
-- Nullable first — the two live PROD rows created during Phase 6 UAT need a backfill
-- before these columns can be locked NOT NULL.
ALTER TABLE sanitary_applications
  ADD COLUMN paddock_id   uuid REFERENCES paddocks(id),
  ADD COLUMN paddock_name text;

-- trg_snapshot_immutable (20260508_02_property_paddock.sql) fires BEFORE UPDATE OR
-- DELETE on every row unconditionally, with no migration carve-out, because no schema
-- backfill was anticipated when it was written in Phase 2. A bare UPDATE here would
-- raise prevent_snapshot_mutation()'s exception and abort this whole migration file.
-- Disabling it around exactly one UPDATE, inside this same migration transaction
-- (MCP apply_migration runs the whole file as one transaction — no other session ever
-- observes the trigger disabled), is the only way to backfill these two columns.
ALTER TABLE sanitary_applications DISABLE TRIGGER trg_snapshot_immutable;

-- D-31: the 2 rows backfilled here (created during Phase 6 UAT, already live in PROD)
-- receive APPROXIMATE attribution derived from lots.paddock_id AT MIGRATION TIME — this
-- is the only information available for them, since no paddock_id/paddock_name existed
-- at the time they were written. Every row inserted after this migration is frozen at
-- write time by the RPC edits below (D-30) — a live join through lots.paddock_id was
-- explicitly rejected as the general mechanism because moving a lot later would
-- retroactively rewrite a closed period's cost, the exact bug class the whole snapshot
-- model exists to prevent.
UPDATE sanitary_applications sa
   SET paddock_id   = l.paddock_id,
       paddock_name = p.name
  FROM lots l
  JOIN paddocks p ON p.id = l.paddock_id
 WHERE sa.lot_id = l.id AND sa.paddock_id IS NULL;

ALTER TABLE sanitary_applications ENABLE TRIGGER trg_snapshot_immutable;

ALTER TABLE sanitary_applications
  ALTER COLUMN paddock_id   SET NOT NULL,
  ALTER COLUMN paddock_name SET NOT NULL;

-- Not extending enforce_sanitary_application_same_property() to cover the new columns
-- (RESEARCH Assumption A5): sanitary_applications has zero direct INSERT/UPDATE RLS
-- policies, so only the two SECURITY DEFINER RPCs below can write it — there is no
-- raw-PATCH surface for paddock_id on this table.

-- ============================================================
-- 3. register_sanitary_application — forward-only edit (Pitfall 4)
-- ============================================================
-- CREATE OR REPLACE FUNCTION with an unchanged signature — a forward-only correction to
-- the already-applied 20260811_06_sanitary_rpcs.sql runtime object, the same technique
-- already used four times in this project (20260806_05, 20260807_05, 20260808_05,
-- 20260809_05). The original file on disk is never edited. Body copied verbatim from
-- 20260811_06_sanitary_rpcs.sql except: (1) two new DECLARE variables, (2) the lot
-- lookup widened to also resolve the lot's current paddock, (3) paddock_id/paddock_name
-- added to the INSERT column list and VALUES tuple. Every other line — membership
-- check, veterinarian gate, dose lookup, NULL guards, dedup, concurrency revalidation,
-- snapshot aggregation, totals, returned to_jsonb — is byte-identical.
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
  v_property_id     uuid;
  v_lot_name        text;
  v_paddock_id      uuid;
  v_paddock_name    text;
  v_dose            record;
  v_kg_per_ua       numeric;
  v_distinct_ids    jsonb;
  v_selected_count  integer;
  v_valid_count     integer;
  v_active_count    integer;
  v_snapshot        jsonb;
  v_total_ua        numeric;
  v_total_volume    numeric;
  v_total_cost      numeric;
  v_app_id          uuid;
BEGIN
  SELECT l.property_id, l.name, p.id, p.name
    INTO v_property_id, v_lot_name, v_paddock_id, v_paddock_name
    FROM lots l JOIN paddocks p ON p.id = l.paddock_id
   WHERE l.id = p_lot_id AND l.deleted_at IS NULL;
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

  -- Guard NULL parameters before any array operation — a null jsonb parameter must not
  -- silently become an empty selection (lesson of 20260809_05_fix_register_baixa_null_guards).
  IF p_applied_at IS NULL THEN
    RAISE EXCEPTION 'applied_at is required' USING ERRCODE = '22023';
  END IF;
  IF p_animal_ids IS NULL THEN
    RAISE EXCEPTION 'animal_ids is required' USING ERRCODE = '22023';
  END IF;

  -- Deduplicate the submitted id array before counting — a repeated uuid in the payload is a
  -- no-op rather than a spurious count mismatch (lesson of
  -- 20260808_05_fix_baixa_observation_and_atf_dedup).
  SELECT jsonb_agg(DISTINCT elem) INTO v_distinct_ids
    FROM jsonb_array_elements_text(p_animal_ids) elem;

  v_selected_count := COALESCE(jsonb_array_length(v_distinct_ids), 0);
  IF v_selected_count = 0 THEN
    RAISE EXCEPTION 'at least 1 animal must be selected' USING ERRCODE = '23514';
  END IF;

  -- D-32: concurrency revalidation — the whole transaction aborts if any submitted animal is no
  -- longer active in this exact lot. Never a partial write.
  SELECT count(*) INTO v_valid_count
    FROM animals a
    JOIN jsonb_array_elements_text(v_distinct_ids) elem(id) ON a.id = elem.id::uuid
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
    JOIN jsonb_array_elements_text(v_distinct_ids) elem(id) ON a.id = elem.id::uuid;

  v_total_volume := v_total_ua * v_dose.dosage_per_kg * v_kg_per_ua;
  v_total_cost   := CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL
                          ELSE v_total_ua * v_dose.cost_per_kg * v_kg_per_ua END;

  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes,
    paddock_id, paddock_name
  ) VALUES (
    v_snapshot, v_property_id, p_lot_id, v_lot_name, v_dose.id, v_dose.name,
    v_dose.dosage_per_kg, v_dose.dosage_per_kg * v_kg_per_ua, v_dose.cost_per_kg,
    CASE WHEN v_dose.cost_per_kg IS NULL THEN NULL ELSE v_dose.cost_per_kg * v_kg_per_ua END,
    p_applied_at, auth.uid(), v_selected_count, v_total_ua, v_total_volume, v_total_cost,
    v_active_count - v_selected_count, p_notes,
    v_paddock_id, v_paddock_name
  ) RETURNING id INTO v_app_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_app_id);
END;
$$;

REVOKE ALL ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) FROM public;
GRANT EXECUTE ON FUNCTION register_sanitary_application(uuid, uuid, date, jsonb, text) TO authenticated;

-- ============================================================
-- 4. reverse_sanitary_application — forward-only edit (Pitfall 4)
-- ============================================================
-- Same forward-only technique. Body copied verbatim except paddock_id/paddock_name
-- added to the INSERT column list and VALUES tuple, copied from v_orig alongside its
-- existing lot_id/lot_name copy. All negation logic, the reversal-of-reversal guard,
-- the reason guard and the already-reversed guard stay byte-identical.
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

  -- Explicit trim(coalesce(...)) comparison rather than a bare NULL test — a whitespace-only
  -- reason must also be rejected.
  IF trim(coalesce(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'reversal reason is required' USING ERRCODE = '22023';
  END IF;

  -- D-31: legible pre-check before the unique index's 23505 backstop is the real guarantee.
  IF EXISTS (SELECT 1 FROM sanitary_applications WHERE reverses_application_id = p_application_id) THEN
    RAISE EXCEPTION 'sanitary application % was already reversed', p_application_id
      USING ERRCODE = 'P0003';
  END IF;

  INSERT INTO sanitary_applications (
    composition_snapshot, property_id, lot_id, lot_name, dose_id, dose_name,
    dosage_per_kg, dosage_per_ua, cost_per_kg, cost_per_ua, applied_at, applied_by,
    animal_count, total_ua, total_volume, total_cost, skipped_count, notes,
    reverses_application_id, paddock_id, paddock_name
  ) VALUES (
    v_orig.composition_snapshot, v_orig.property_id, v_orig.lot_id, v_orig.lot_name,
    v_orig.dose_id, v_orig.dose_name, v_orig.dosage_per_kg, v_orig.dosage_per_ua,
    v_orig.cost_per_kg, v_orig.cost_per_ua, current_date, auth.uid(),
    -v_orig.animal_count, -v_orig.total_ua, -v_orig.total_volume,
    CASE WHEN v_orig.total_cost IS NULL THEN NULL ELSE -v_orig.total_cost END,
    v_orig.skipped_count, p_reason, v_orig.id, v_orig.paddock_id, v_orig.paddock_name
  ) RETURNING id INTO v_new_id;

  RETURN (SELECT to_jsonb(s) FROM sanitary_applications s WHERE s.id = v_new_id);
END;
$$;

REVOKE ALL ON FUNCTION reverse_sanitary_application(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION reverse_sanitary_application(uuid, text) TO authenticated;
