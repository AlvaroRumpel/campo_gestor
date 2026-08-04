-- 20260804_05_reproductive_module.sql
-- Phase 5 — Reproductive Module (LoteATF)
-- References: REPR-01, REPR-02, REPR-03
-- Decisions: D-05 (hybrid bull field on atf_batches), D-09 (only vaca/novilha eligible for ATF),
--            D-19 (baixa deactivates active ATF membership in the same transaction), D-21 (RLS +
--            FORCE ROW LEVEL SECURITY on all three module tables, cross-property alignment triggers)
--
-- Creates atf_batches and dg_records, and activates the animal_atf_memberships skeleton
-- from 20260508_02_property_paddock.sql (property_id + foreign keys + policies). REPR-02's two
-- business rules ("apenas vacas e novilhas", "no máximo 1 ATF ativo") and D-21's multi-tenant
-- isolation are enforced at the database boundary — Phase 4's code review reopened this exact bug
-- class twice (CR-01, WR-02) via raw PostgREST writes bypassing RPC-only validation.

-- ============================================================
-- 1. atf_batches (REPR-01, D-05)
-- ============================================================
CREATE TABLE atf_batches (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id        uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name               text NOT NULL,
  implantation_date  date NOT NULL,
  insemination_date  date NOT NULL,
  bull_animal_id     uuid REFERENCES animals(id),
  bull_name          text,
  observation        text,
  active             boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  deleted_at         timestamptz,
  CONSTRAINT atf_batches_bull_required
    CHECK (bull_animal_id IS NOT NULL OR bull_name IS NOT NULL),
  CONSTRAINT atf_batches_date_order
    CHECK (insemination_date >= implantation_date)
);

CREATE INDEX atf_batches_property_idx ON atf_batches (property_id);

-- ============================================================
-- 2. dg_records (REPR-03, D-10, D-12)
-- ============================================================
CREATE TABLE dg_records (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id  uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  atf_batch_id uuid NOT NULL REFERENCES atf_batches(id) ON DELETE CASCADE,
  animal_id    uuid NOT NULL REFERENCES animals(id),
  result       text NOT NULL,
  exam_date    date NOT NULL,
  observation  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dg_records_result_check
    CHECK (result IN ('pregnant', 'not_pregnant', 'doubtful'))
);

-- No unique constraint on (atf_batch_id, animal_id) — D-12 requires multiple additive DG rows
-- per animal per ATF (corrections stay retrievable, never overwritten).
CREATE INDEX dg_records_atf_animal_idx ON dg_records (atf_batch_id, animal_id, created_at DESC);
CREATE INDEX dg_records_animal_idx ON dg_records (animal_id);

-- ============================================================
-- 3. animal_atf_memberships — activate the Phase 2 skeleton
-- ============================================================
-- The table is currently empty in every environment (created with no policies in Phase 2, so no
-- row could have been inserted through the app) — the NOT NULL column is added directly without a
-- backfill (A-SCHEMA-01).
ALTER TABLE animal_atf_memberships
  ADD COLUMN property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  ADD CONSTRAINT animal_atf_memberships_animal_fk FOREIGN KEY (animal_id) REFERENCES animals(id),
  ADD CONSTRAINT animal_atf_memberships_atf_fk FOREIGN KEY (atf_batch_id) REFERENCES atf_batches(id) ON DELETE CASCADE;

CREATE INDEX animal_atf_memberships_property_idx ON animal_atf_memberships (property_id);
CREATE INDEX animal_atf_memberships_atf_idx ON animal_atf_memberships (atf_batch_id);
-- animal_atf_memberships_active_idx already exists (20260508_02_property_paddock.sql) — the
-- REPR-02 "no máximo 1 ATF ativo" guarantee. Not recreated here.

-- ============================================================
-- 4. Row level security (D-21 point 1)
-- ============================================================
ALTER TABLE atf_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE atf_batches FORCE ROW LEVEL SECURITY;

ALTER TABLE dg_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE dg_records FORCE ROW LEVEL SECURITY;
-- animal_atf_memberships already has ENABLE + FORCE ROW LEVEL SECURITY from Phase 2.

CREATE POLICY "members_can_read_atf_batches"
  ON atf_batches FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "veterinarian_can_insert_atf_batch"
  ON atf_batches FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
  );

-- Deliberately NO INSERT, UPDATE, or DELETE policy on animal_atf_memberships or dg_records, and
-- NO UPDATE policy on atf_batches (RESEARCH Pattern 1). Every mutation on those three surfaces goes
-- through a SECURITY DEFINER RPC added in plan 05-03 (add_animals_to_atf, remove_animal_from_atf,
-- save_dg_records, close_atf, register_baixa). Do NOT "fix" this by adding a write policy — a raw
-- PostgREST INSERT/UPDATE/DELETE must be unreachable regardless of RLS state (T-05-01, T-05-04).
CREATE POLICY "members_can_read_atf_memberships"
  ON animal_atf_memberships FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "members_can_read_dg_records"
  ON dg_records FOR SELECT TO authenticated
  USING (is_member_of(property_id));

-- ============================================================
-- 5. Access-path-independent triggers (REPR-02, D-19, D-21 point 2)
-- ============================================================
-- Mirrors the project idiom for unconditional invariants: trg_animals_lot_same_property /
-- trg_lots_paddock_same_property (20260716/20260717_04_*.sql). RLS WITH CHECK only evaluates the
-- row being written, never a referenced row's property_id — so category eligibility and
-- cross-property alignment must be enforced here, independent of the write path (RPC vs raw
-- PostgREST PATCH).

CREATE OR REPLACE FUNCTION enforce_atf_membership_valid()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_animal_category    text;
  v_animal_property_id uuid;
  v_atf_property_id    uuid;
BEGIN
  SELECT category, property_id
    INTO v_animal_category, v_animal_property_id
    FROM animals
   WHERE id = NEW.animal_id
     AND deleted_at IS NULL;

  IF v_animal_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or is archived', NEW.animal_id
      USING ERRCODE = '23503';
  END IF;

  IF v_animal_property_id <> NEW.property_id THEN
    RAISE EXCEPTION 'animal % does not belong to property %', NEW.animal_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;

  IF v_animal_category NOT IN ('vaca', 'novilha') THEN
    RAISE EXCEPTION 'animal category % is not eligible for an ATF (only vaca/novilha)', v_animal_category
      USING ERRCODE = '23514';
  END IF;

  SELECT property_id INTO v_atf_property_id
    FROM atf_batches
   WHERE id = NEW.atf_batch_id;

  IF v_atf_property_id IS NULL OR v_atf_property_id <> NEW.property_id THEN
    RAISE EXCEPTION 'atf_batch % does not belong to property %', NEW.atf_batch_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

-- No pg_advisory_xact_lock here — nothing here generates a sequence; the pre-existing partial
-- unique index animal_atf_memberships_active_idx already handles the one real concurrency hazard
-- (RESEARCH Pitfall 3).
CREATE TRIGGER trg_atf_membership_valid
  BEFORE INSERT OR UPDATE ON animal_atf_memberships
  FOR EACH ROW
  EXECUTE FUNCTION enforce_atf_membership_valid();

CREATE OR REPLACE FUNCTION enforce_dg_record_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_atf_property_id    uuid;
  v_animal_property_id uuid;
BEGIN
  SELECT property_id INTO v_atf_property_id
    FROM atf_batches
   WHERE id = NEW.atf_batch_id;

  IF v_atf_property_id IS NULL OR v_atf_property_id <> NEW.property_id THEN
    RAISE EXCEPTION 'atf_batch % does not belong to property %', NEW.atf_batch_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;

  SELECT property_id INTO v_animal_property_id
    FROM animals
   WHERE id = NEW.animal_id;

  IF v_animal_property_id IS NULL OR v_animal_property_id <> NEW.property_id THEN
    RAISE EXCEPTION 'animal % does not belong to property %', NEW.animal_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_dg_records_same_property
  BEFORE INSERT OR UPDATE ON dg_records
  FOR EACH ROW
  EXECUTE FUNCTION enforce_dg_record_same_property();

-- D-19's "na mesma transação" requirement is implemented as an AFTER UPDATE OF deleted_at trigger
-- on animals rather than as a second UPDATE inside the register_baixa RPC (05-RESEARCH.md's code
-- sample). Deliberate divergence: the trigger holds on any write path — including a raw PostgREST
-- PATCH of animals.deleted_at — which an RPC-only implementation would not, and it removes a
-- statement from the RPC. Per D-16 the membership is soft-deactivated, never deleted, so the
-- animal's DG history in that ATF stays queryable and correctable (A-BAIXA-01: today baixa is the
-- only path that sets animals.deleted_at, so no other soft-delete path is affected yet).
CREATE OR REPLACE FUNCTION deactivate_atf_membership_on_baixa()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE animal_atf_memberships
     SET active = false
   WHERE animal_id = NEW.id
     AND active = true;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_animals_baixa_deactivates_atf
  AFTER UPDATE OF deleted_at ON animals
  FOR EACH ROW
  WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
  EXECUTE FUNCTION deactivate_atf_membership_on_baixa();
