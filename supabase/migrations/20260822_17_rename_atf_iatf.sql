-- 20260822_17_rename_atf_iatf.sql — ajustes 2026-08-20, item 1.
-- ATF → IATF em todo o banco: tabelas, colunas, funções, triggers e
-- mensagens. Corpos das funções são as definições finais vigentes com o
-- rename textual aplicado; funções e triggers antigos são dropados na mesma
-- transação (o front com os nomes novos deploya junto).

-- ============================================================
-- 1. Renames de tabela e coluna
-- ============================================================
ALTER TABLE atf_batches RENAME TO iatf_batches;
ALTER TABLE animal_atf_memberships RENAME TO animal_iatf_memberships;
ALTER TABLE animal_iatf_memberships RENAME COLUMN atf_batch_id TO iatf_batch_id;
ALTER TABLE dg_records RENAME COLUMN atf_batch_id TO iatf_batch_id;

-- ============================================================
-- 2. Drop dos triggers e funções com nome antigo
-- ============================================================
DROP TRIGGER IF EXISTS trg_atf_membership_valid ON animal_iatf_memberships;
DROP TRIGGER IF EXISTS trg_animals_baixa_deactivates_atf ON animals;
DROP TRIGGER IF EXISTS trg_animals_category_atf_guard ON animals;
DROP TRIGGER IF EXISTS trg_dg_records_same_property ON dg_records;

DROP FUNCTION IF EXISTS add_animals_to_atf(uuid, jsonb);
DROP FUNCTION IF EXISTS remove_animal_from_atf(uuid, uuid);
DROP FUNCTION IF EXISTS close_atf(uuid);
DROP FUNCTION IF EXISTS enforce_atf_membership_valid();
DROP FUNCTION IF EXISTS deactivate_atf_membership_on_baixa();
DROP FUNCTION IF EXISTS enforce_animal_category_atf_guard();
-- save_dg_records mantém o nome mas o parâmetro renomeia
-- (p_atf_batch_id → p_iatf_batch_id) — CREATE OR REPLACE não permite mudar
-- nome de parâmetro, então drop + recreate + grant.
DROP FUNCTION IF EXISTS save_dg_records(uuid, jsonb);
-- register_baixa / enforce_dg_record_same_property mantêm nome e assinatura;
-- só o corpo é recriado abaixo (referências às tabelas renomeadas).

-- ============================================================
-- 3. Funções recriadas com nomes/corpos novos
-- ============================================================

-- ── add_animals_to_iatf (fonte: 20260808_05_fix_baixa_observation_and_iatf_dedup.sql) ──
CREATE OR REPLACE FUNCTION add_animals_to_iatf(
  p_iatf_batch_id uuid,
  p_animal_ids   jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM iatf_batches
   WHERE id = p_iatf_batch_id
     AND active = true
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'iatf_batch % not found or is not active', p_iatf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can compose an IATF'
      USING ERRCODE = '42501';
  END IF;

  -- Category eligibility (vaca/novilha) and cross-property alignment are NOT re-checked here —
  -- trg_iatf_membership_valid (20260804_05_reproductive_module.sql) fires on this INSERT and is the
  -- single place those invariants live. Duplicating them here would be exactly the "belt and
  -- suspenders drifting out of sync" pitfall 05-RESEARCH.md warns against (Pitfall 2). No
  -- pg_advisory_xact_lock either — nothing here generates a sequence; the pre-existing partial
  -- unique index animal_iatf_memberships_active_idx is the sole concurrency guard needed
  -- (RESEARCH Pitfall 3).
  --
  -- WR-02: DISTINCT collapses a uuid repeated within THIS payload into one row. Duplicates
  -- across IATFs (the animal already sits in another active IATF) are still rejected by
  -- animal_iatf_memberships_active_idx with 23505 — that constraint is REPR-02's actual
  -- guarantee and is deliberately not weakened by an ON CONFLICT clause here.
  INSERT INTO animal_iatf_memberships (animal_id, iatf_batch_id, active, property_id)
  SELECT DISTINCT (elem)::uuid, p_iatf_batch_id, true, v_property_id
    FROM jsonb_array_elements_text(p_animal_ids) AS elem;
END;
$$;

-- ── remove_animal_from_iatf (fonte: 20260807_05_fix_remove_animal_from_iatf_notfound.sql) ──
CREATE OR REPLACE FUNCTION remove_animal_from_iatf(
  p_iatf_batch_id uuid,
  p_animal_id    uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM iatf_batches
   WHERE id = p_iatf_batch_id
     AND active = true
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'iatf_batch % not found or is not active', p_iatf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can remove an animal from an IATF'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1 FROM dg_records
     WHERE iatf_batch_id = p_iatf_batch_id
       AND animal_id = p_animal_id
  ) THEN
    RAISE EXCEPTION
      'animal % already has a DG record in IATF % — cannot remove; use encerramento (close_iatf) to close it out instead',
      p_animal_id, p_iatf_batch_id
      USING ERRCODE = '23514';
  END IF;

  -- Hard DELETE, not a soft `active = false` — deliberately, and this is the single most important
  -- distinction in this migration. save_dg_records tells "removed before any DG, never accept a
  -- DG again" (D-08, this DELETE) apart from "closed, correction still allowed" (D-16, close_iatf's
  -- UPDATE) purely by whether this membership row EXISTS. Do not "harmonize" this into a soft
  -- deactivation — that would silently reopen D-08's guarantee.
  DELETE FROM animal_iatf_memberships
   WHERE iatf_batch_id = p_iatf_batch_id
     AND animal_id = p_animal_id
     AND active = true;

  -- WR-02: mirrors the IF NOT FOUND re-check close_iatf/register_baixa already use elsewhere in
  -- this migration file — a 0-row DELETE (stale double-submit, concurrent removal) now surfaces
  -- as an error instead of a silent no-op success.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'animal % is not an active member of iatf %', p_animal_id, p_iatf_batch_id
      USING ERRCODE = '23503';
  END IF;
END;
$$;

-- ── close_iatf (fonte: 20260805_05_iatf_rpcs.sql) ──
CREATE OR REPLACE FUNCTION close_iatf(
  p_iatf_batch_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM iatf_batches
   WHERE id = p_iatf_batch_id
     AND active = true
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'iatf_batch % not found or is already closed', p_iatf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can close an IATF'
      USING ERRCODE = '42501';
  END IF;

  UPDATE iatf_batches
     SET active = false
   WHERE id = p_iatf_batch_id;

  -- Deactivating every membership of this batch is what frees each animal's slot in
  -- animal_iatf_memberships_active_idx for a new cycle (D-16). The rows themselves stay — history
  -- and DG correction (save_dg_records) survive an encerramento.
  UPDATE animal_iatf_memberships
     SET active = false
   WHERE iatf_batch_id = p_iatf_batch_id
     AND active = true;
END;
$$;

-- ── save_dg_records (fonte: 20260805_05_iatf_rpcs.sql) ──
CREATE OR REPLACE FUNCTION save_dg_records(
  p_iatf_batch_id uuid,
  p_records      jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
  v_record      jsonb;
  v_animal_id   uuid;
  v_result      text;
  v_exam_date   date;
  v_observation text;
BEGIN
  -- Deliberately NO `active = true` filter here, unlike add_animals_to_iatf/remove_animal_from_iatf/
  -- close_iatf above — D-16 requires DG correction to stay possible after encerramento closes the
  -- batch, so an already-closed iatf_batches row must still resolve here.
  SELECT property_id
    INTO v_property_id
    FROM iatf_batches
   WHERE id = p_iatf_batch_id;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'iatf_batch % not found', p_iatf_batch_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can save DG records'
      USING ERRCODE = '42501';
  END IF;

  FOR v_record IN SELECT * FROM jsonb_array_elements(p_records) LOOP
    v_animal_id   := (v_record ->> 'animal_id')::uuid;
    v_result      := v_record ->> 'result';
    v_exam_date   := (v_record ->> 'exam_date')::date;
    v_observation := v_record ->> 'observation';

    IF v_result NOT IN ('pregnant', 'not_pregnant', 'doubtful') THEN
      RAISE EXCEPTION 'invalid DG result % for animal %', v_result, v_animal_id
        USING ERRCODE = '22023';
    END IF;

    -- Existence guard: check only that a membership row exists for this (iatf_batch, animal) pair —
    -- deliberately NOT filtering on `active`. This single condition is what makes all three
    -- deactivation paths behave correctly: a D-08 removal hard-deleted the row so a DG is refused
    -- (23503 below), while a D-16 closure or D-19 baixa left the row present (inactive) so a
    -- correction is accepted.
    IF NOT EXISTS (
      SELECT 1 FROM animal_iatf_memberships
       WHERE iatf_batch_id = p_iatf_batch_id
         AND animal_id = v_animal_id
    ) THEN
      RAISE EXCEPTION 'animal % is not a member of IATF %', v_animal_id, p_iatf_batch_id
        USING ERRCODE = '23503';
    END IF;

    -- Only INSERT — never UPDATE or DELETE an existing dg_records row. D-12 makes the DG history
    -- additive; the most recent record wins at read time. The whole function body is one
    -- transaction, so a bad record anywhere in the batch rolls the entire batch back (the
    -- atomicity 05-UI-SPEC's DG Batch Save contract requires).
    INSERT INTO dg_records (property_id, iatf_batch_id, animal_id, result, exam_date, observation)
    VALUES (v_property_id, p_iatf_batch_id, v_animal_id, v_result, v_exam_date, v_observation);
  END LOOP;
END;
$$;

-- ── register_baixa (fonte: 2026081410_medium_hardening.sql) ──
CREATE OR REPLACE FUNCTION register_baixa(
  p_animal_id   uuid,
  p_reason      text,
  p_date        date,
  p_observation text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property_id uuid;
BEGIN
  SELECT property_id
    INTO v_property_id
    FROM animals
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF v_property_id IS NULL THEN
    RAISE EXCEPTION 'animal % not found or already archived', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT is_member_of(v_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', v_property_id
      USING ERRCODE = '42501';
  END IF;

  IF get_role(v_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can register a baixa'
      USING ERRCODE = '42501';
  END IF;

  -- WR-01: `NULL NOT IN (...)` is NULL, not TRUE — plpgsql's `IF NULL THEN` takes the false
  -- branch, so an explicit `p_reason IS NULL` check is required; the allow-list NOT IN alone
  -- silently let a NULL reason through.
  IF p_reason IS NULL OR p_reason NOT IN ('sale', 'death', 'discard') THEN
    RAISE EXCEPTION 'invalid baixa reason %', p_reason
      USING ERRCODE = '22023';
  END IF;

  -- WR-01: p_date had no NULL guard at all — without this, a direct RPC call could archive an
  -- animal with baixa_date = NULL.
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'baixa date is required'
      USING ERRCODE = '22023';
  END IF;

  -- T-g9j-04: baixa não pode ser registrada com data no futuro — corromperia
  -- relatório de período.
  IF p_date > current_date THEN
    RAISE EXCEPTION 'baixa date cannot be in the future: %', p_date
      USING ERRCODE = '22023';
  END IF;

  -- Guarded by deleted_at IS NULL, followed by the IF NOT FOUND re-check below — the WR-01 fix
  -- from move_animal_to_lot (20260715_04_gap_move_animal_to_lot.sql) reused here so two concurrent
  -- baixas on the same animal cannot both report success.
  --
  -- CR-01 (05-REVIEW-FIX.md, 20260808 migration): the observation assignment below appends the
  -- new note to the existing one with a newline separator, treating NULL or empty-string
  -- p_observation as a strict no-op on the existing text.
  UPDATE animals
     SET baixa_reason = p_reason,
         baixa_date   = p_date,
         deleted_at   = now(),
         observation  = CASE
                           WHEN p_observation IS NULL OR p_observation = '' THEN observation
                           WHEN observation IS NULL OR observation = '' THEN p_observation
                           ELSE observation || E'\n' || p_observation
                         END
   WHERE id = p_animal_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'animal % was archived concurrently', p_animal_id
      USING ERRCODE = '23503';
  END IF;

  -- Deliberately NO second UPDATE against animal_iatf_memberships here — plan 05-01's
  -- trg_animals_baixa_deactivates_iatf trigger (AFTER UPDATE OF deleted_at ON animals) fires on the
  -- UPDATE above and performs the D-19 deactivation on every access path, including a raw
  -- PostgREST PATCH that never reaches this function. This omission is deliberate, not a gap.
END;
$$;

-- ── deactivate_iatf_membership_on_baixa (fonte: 2026081409_multitenant_hardening.sql) ──
CREATE OR REPLACE FUNCTION deactivate_iatf_membership_on_baixa()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE animal_iatf_memberships
     SET active = false
   WHERE animal_id = NEW.id
     AND active = true;

  RETURN NEW;
END;
$$;

-- ── enforce_iatf_membership_valid (fonte: 20260804_05_reproductive_module.sql) ──
CREATE OR REPLACE FUNCTION enforce_iatf_membership_valid()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_animal_category    text;
  v_animal_property_id uuid;
  v_iatf_property_id    uuid;
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
    RAISE EXCEPTION 'animal category % is not eligible for an IATF (only vaca/novilha)', v_animal_category
      USING ERRCODE = '23514';
  END IF;

  SELECT property_id INTO v_iatf_property_id
    FROM iatf_batches
   WHERE id = NEW.iatf_batch_id;

  IF v_iatf_property_id IS NULL OR v_iatf_property_id <> NEW.property_id THEN
    RAISE EXCEPTION 'iatf_batch % does not belong to property %', NEW.iatf_batch_id, NEW.property_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

-- ── enforce_animal_category_iatf_guard (fonte: 2026081409_multitenant_hardening.sql) ──
CREATE OR REPLACE FUNCTION enforce_animal_category_iatf_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.category NOT IN ('vaca', 'novilha') AND EXISTS (
    SELECT 1 FROM animal_iatf_memberships
     WHERE animal_id = NEW.id
       AND active = true
  ) THEN
    RAISE EXCEPTION
      'animal % has an active IATF membership; remove it from the IATF before '
      'changing its category to %', NEW.id, NEW.category
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

-- ── enforce_dg_record_same_property (fonte: 20260804_05_reproductive_module.sql) ──
CREATE OR REPLACE FUNCTION enforce_dg_record_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_iatf_property_id    uuid;
  v_animal_property_id uuid;
BEGIN
  SELECT property_id INTO v_iatf_property_id
    FROM iatf_batches
   WHERE id = NEW.iatf_batch_id;

  IF v_iatf_property_id IS NULL OR v_iatf_property_id <> NEW.property_id THEN
    RAISE EXCEPTION 'iatf_batch % does not belong to property %', NEW.iatf_batch_id, NEW.property_id
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

-- ============================================================
-- 4. Grants das RPCs renomeadas + triggers novos
-- ============================================================
REVOKE ALL ON FUNCTION add_animals_to_iatf(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION add_animals_to_iatf(uuid, jsonb) TO authenticated;
REVOKE ALL ON FUNCTION remove_animal_from_iatf(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION remove_animal_from_iatf(uuid, uuid) TO authenticated;
REVOKE ALL ON FUNCTION close_iatf(uuid) FROM public;
GRANT EXECUTE ON FUNCTION close_iatf(uuid) TO authenticated;
REVOKE ALL ON FUNCTION save_dg_records(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION save_dg_records(uuid, jsonb) TO authenticated;

CREATE TRIGGER trg_iatf_membership_valid
  BEFORE INSERT OR UPDATE OF animal_id, iatf_batch_id, property_id
  ON animal_iatf_memberships
  FOR EACH ROW
  EXECUTE FUNCTION enforce_iatf_membership_valid();

CREATE TRIGGER trg_animals_baixa_deactivates_iatf
  AFTER UPDATE OF deleted_at ON animals
  FOR EACH ROW
  WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
  EXECUTE FUNCTION deactivate_iatf_membership_on_baixa();

CREATE TRIGGER trg_animals_category_iatf_guard
  BEFORE UPDATE OF category ON animals
  FOR EACH ROW
  WHEN (NEW.category IS DISTINCT FROM OLD.category)
  EXECUTE FUNCTION enforce_animal_category_iatf_guard();

CREATE TRIGGER trg_dg_records_same_property
  BEFORE INSERT OR UPDATE ON dg_records
  FOR EACH ROW
  EXECUTE FUNCTION enforce_dg_record_same_property();
