---
phase: 05-reproductive-module-loteatf
reviewed: 2026-08-04T00:00:00Z
depth: deep
files_reviewed: 12
files_reviewed_list:
  - supabase/migrations/20260804_05_reproductive_module.sql
  - supabase/migrations/20260805_05_atf_rpcs.sql
  - supabase/tests/05_reproductive_test.sql
  - lib/features/reproducao/data/atf_model.dart
  - lib/features/reproducao/data/dg_record_model.dart
  - lib/features/reproducao/data/dg_summary.dart
  - lib/features/reproducao/data/atf_repository.dart
  - lib/features/reproducao/presentation/reproducao_screen.dart
  - lib/features/reproducao/presentation/atf_form_dialog.dart
  - lib/features/reproducao/presentation/atf_detail_screen.dart
  - lib/features/reproducao/presentation/atf_animal_selection_screen.dart
  - lib/features/reproducao/presentation/encerrar_atf_dialog.dart
  - lib/features/animais/data/animal_repository.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - lib/features/animais/presentation/baixa_dialog.dart
  - lib/core/router/routes.dart
  - lib/core/router/router.dart
findings:
  critical: 2
  warning: 3
  info: 0
  total: 5
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-08-04
**Depth:** deep
**Files Reviewed:** 17 (12 primary source files across SQL + Dart, plus 5 cross-referenced call sites)
**Status:** issues_found

## Summary

Phase 5 replicates the Phase 3/4 patterns competently — RPC-only mutation surface, property-alignment
triggers, `SECURITY DEFINER` with server-derived `property_id`, and a single `summarizeDg()` function
that every UI caller routes through (no divergent % prenhez math found anywhere: `_AtfCard`,
`AtfHeaderCard`, `_CompositionSection`/`_DgSection`'s shared computation, and `AtfRepository.fetchAtfSummaries`
all call the same function with the same `compositionCount` semantics). D-17/D-20's percentage rules
(doubtful in denominator only, baixa'd-with-DG counted, no division by zero) are implemented correctly
in `dg_summary.dart`. Multi-tenant isolation is sound: every RPC derives `property_id` from a server-side
row lookup and never accepts it as a trusted parameter.

However, the phase's single load-bearing design decision — distinguishing D-08 removal / D-16 closure /
D-19 baixa purely by whether an `animal_atf_memberships` row exists — is undermined by a trigger scoping
bug that makes **`register_baixa` unconditionally fail for the exact scenario D-19 was built for** (an
animal currently in an active ATF). This is provable by tracing the trigger chain, and is independently
corroborated by the project's own (never-executed) pgTAP assertion, which would fail if the suite were
run. A second cross-cutting issue is inconsistent Riverpod provider invalidation after ATF-touching
mutations, which the task brief specifically flagged as the exact way "atualiza automaticamente" breaks
silently — confirmed present in 4 of the 5 mutation call sites.

## Critical Issues

### CR-01: `register_baixa` always throws for an animal in an active ATF — D-19's exact scenario is completely broken

**File:** `supabase/migrations/20260804_05_reproductive_module.sql:164-167` (trigger scope), `:117-159`
(`enforce_atf_membership_valid`), `:212-231` (`deactivate_atf_membership_on_baixa` /
`trg_animals_baixa_deactivates_atf`)
**Also affects:** `supabase/migrations/20260805_05_atf_rpcs.sql:268-328` (`register_baixa`, the entry
point that surfaces the failure), `lib/features/animais/data/animal_repository.dart:205-217`
(`AnimalRepository.registerBaixa`, the Dart call site that will report "Erro ao registrar baixa")

**Issue:**

`trg_atf_membership_valid` is declared unconditionally on both INSERT and UPDATE:

```sql
CREATE TRIGGER trg_atf_membership_valid
  BEFORE INSERT OR UPDATE ON animal_atf_memberships
  FOR EACH ROW
  EXECUTE FUNCTION enforce_atf_membership_valid();
```

`enforce_atf_membership_valid()` re-validates the referenced animal on *every* row write, including a
pure `active` flag flip, and its very first check is:

```sql
SELECT category, property_id INTO v_animal_category, v_animal_property_id
  FROM animals WHERE id = NEW.animal_id AND deleted_at IS NULL;
IF v_animal_property_id IS NULL THEN
  RAISE EXCEPTION 'animal % not found or is archived', NEW.animal_id USING ERRCODE = '23503';
END IF;
```

`register_baixa` first sets `animals.deleted_at = now()`. That `UPDATE` fires the `AFTER UPDATE OF
deleted_at` trigger `trg_animals_baixa_deactivates_atf`, whose body is:

```sql
UPDATE animal_atf_memberships SET active = false WHERE animal_id = NEW.id AND active = true;
```

This nested `UPDATE` only touches a row when the animal currently has an active ATF membership — i.e.
exactly the D-19 scenario ("vaca morre no meio do protocolo"). When it fires, it in turn fires the
`BEFORE UPDATE` trigger above. At that point in the same transaction, `animals.deleted_at` is **already
non-NULL** (the outer `UPDATE animals` already committed its effect earlier in the same transaction, and
Postgres statements see earlier writes from the same transaction). So `enforce_atf_membership_valid`'s
`WHERE deleted_at IS NULL` lookup returns nothing, `v_animal_property_id IS NULL`, and it raises `'animal
% not found or is archived'`. The exception propagates out of the nested trigger, aborts the `UPDATE
animals` statement, and rolls back the entire `register_baixa` transaction.

Net effect: **any attempt to register a baixa for an animal that is currently an active member of an ATF
fails with an exception**, every time, deterministically. For any animal with no active ATF membership,
the nested `UPDATE` affects 0 rows so the row-level trigger never fires and baixa works fine — which is
exactly why this only manifests for the one scenario D-19 exists to handle, and why it would be easy to
miss in ad hoc testing that doesn't specifically baixa an animal mid-protocol.

**Corroboration:** `supabase/tests/05_reproductive_test.sql:99-112` independently exercises this exact
path with a raw `UPDATE animals SET deleted_at = now()` (not even going through the RPC) against an
animal with an active membership (inserted at line 79), and asserts `lives_ok`. That assertion would
fail if the suite were ever executed — the test file is honest that it has never been run (`supabase test
db` requires a linked/local Supabase instance not available this session), so this defect has never been
caught.

**Fix:** No existing write path in this migration ever changes `animal_id`, `atf_batch_id`, or
`property_id` on an `UPDATE` — every `UPDATE` in the phase (`close_atf`, the baixa trigger) is a pure
`active` deactivation. Scope the trigger to skip re-validation on those updates:

```sql
CREATE TRIGGER trg_atf_membership_valid
  BEFORE INSERT ON animal_atf_memberships
  FOR EACH ROW
  EXECUTE FUNCTION enforce_atf_membership_valid();

CREATE TRIGGER trg_atf_membership_valid_on_update
  BEFORE UPDATE ON animal_atf_memberships
  FOR EACH ROW
  WHEN (
    NEW.animal_id IS DISTINCT FROM OLD.animal_id
    OR NEW.atf_batch_id IS DISTINCT FROM OLD.atf_batch_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
  )
  EXECUTE FUNCTION enforce_atf_membership_valid();
```

(or simply drop `OR UPDATE` from the single trigger declaration, since no code path needs it today —
but the `WHEN` guard above is safer against future UPDATE-based composition changes).

## Warnings

### WR-01: Stale Riverpod providers after ATF-touching mutations — "atualiza automaticamente" silently breaks in 4 of 5 mutation paths

**File:** `lib/features/animais/presentation/baixa_dialog.dart:84-85`,
`lib/features/reproducao/presentation/atf_detail_screen.dart:361-363` (`_confirmRemove`),
`lib/features/reproducao/presentation/atf_animal_selection_screen.dart:119-121` (`_confirm`),
`lib/features/reproducao/presentation/encerrar_atf_dialog.dart:44-47` (`_submit`)

**Issue:** None of the providers in `lib/features/reproducao/data/atf_repository.dart` (or
`animal_repository.dart`) are declared `.autoDispose` (confirmed: no `autoDispose` usage anywhere in
`lib/`), so a `FutureProvider`/`FutureProvider.family` result is cached indefinitely until something
explicitly calls `ref.invalidate`. Only `_DgSection._save()` (atf_detail_screen.dart:700-705) gets this
right, invalidating `reproductiveHistoryByAnimalProvider` for every affected animal after a DG save. Every
other mutation that changes ATF membership state misses at least one provider that displays that exact
state elsewhere in the app:

- `BaixaDialog._submit` (baixa_dialog.dart:84-85) invalidates only `animalByIdProvider` and
  `animalListByPropertyProvider`. It now has a documented cross-table side effect (D-19 deactivates the
  animal's ATF membership) but never invalidates `reproductiveHistoryByAnimalProvider(id)` — the exact
  provider `_ReproductiveHistorySection` on the *same screen* (`animal_detail_screen.dart:381-383`)
  renders — nor any of `atfActiveMembershipsProvider`/`atfMembershipsProvider`/`atfListByPropertyProvider`
  for the ATF the animal belonged to. A vet who baixas an animal from its ficha, then opens the ATF it
  was in, sees the animal still listed as an active member with a stale % prenhez/composition count
  until an unrelated navigation happens to invalidate that provider (which nothing here does).
- `_confirmRemove` (atf_detail_screen.dart:355-364) invalidates the three ATF-side providers but not
  `reproductiveHistoryByAnimalProvider(membership.animalId)` for the removed animal.
- `_confirm` in the animal-selection screen (atf_animal_selection_screen.dart:113-121) invalidates the
  ATF-side providers but not `reproductiveHistoryByAnimalProvider` for the newly-added animals, whose
  ficha should now show this ATF.
- `EncerrarAtfDialog._submit` (encerrar_atf_dialog.dart:41-48) invalidates the ATF-side providers but not
  `reproductiveHistoryByAnimalProvider` for every member, whose history row's status badge (Ativo →
  Encerrado) goes stale.

**Fix:** Add the missing `ref.invalidate(reproductiveHistoryByAnimalProvider(id))` call(s) at each site
above (looping over affected animal ids, mirroring the pattern already correct in `_DgSection._save()`),
and have `BaixaDialog._submit` also invalidate the ATF providers for whatever ATF membership existed
before baixa (or, at minimum, `reproductiveHistoryByAnimalProvider(widget.animal.id)` since that's the
provider rendered on the same screen the dialog is opened from).

### WR-02: `remove_animal_from_atf` silently no-ops when there is no matching active membership

**File:** `supabase/migrations/20260805_05_atf_rpcs.sql:123-127`

**Issue:** Unlike `close_atf` (`:153-156`) and `register_baixa` (`:318-321`), which both re-check
`IF NOT FOUND` after their guarded UPDATE and raise `23503`, `remove_animal_from_atf`'s final statement:

```sql
DELETE FROM animal_atf_memberships
 WHERE atf_batch_id = p_atf_batch_id
   AND animal_id = p_animal_id
   AND active = true;
```

has no post-check. If `p_animal_id` has no active membership in `p_atf_batch_id` (e.g. a stale client
double-submits a remove action, or two vets remove the same animal concurrently), the `DELETE` affects 0
rows and the function returns success silently — the caller has no way to distinguish "removed" from
"was never there to remove."

**Fix:**
```sql
DELETE FROM animal_atf_memberships
 WHERE atf_batch_id = p_atf_batch_id AND animal_id = p_animal_id AND active = true;

IF NOT FOUND THEN
  RAISE EXCEPTION 'animal % is not an active member of atf %', p_animal_id, p_atf_batch_id
    USING ERRCODE = '23503';
END IF;
```

### WR-03: `.toUtc()` before date-only truncation can shift the stored calendar date for positive-UTC-offset locales

**File:** `lib/features/reproducao/data/atf_repository.dart:283-286` (`createAtf`'s
`implantation_date`/`insemination_date`), `lib/features/reproducao/presentation/atf_detail_screen.dart:684-687`
(`_DgSection._save`'s `exam_date`)

**Issue:** Both sites format a date-only value as `date.toUtc().toIso8601String().substring(0, 10)`. A
`DateTime` produced by `showDatePicker` is midnight in the device's *local* time zone. `.toUtc()` shifts
it by the local UTC offset before truncating to `yyyy-MM-dd`. For any offset that is *ahead* of UTC
(e.g., testing from a European/Asian time zone, or a misconfigured device clock), midnight local time
shifts backward across midnight into the previous UTC day, and the truncated string silently reports the
wrong calendar date. Brazil's offset is always behind UTC, so this specific defect will not manifest for
the app's real users in production, but it is a repeated new instance (in Phase 5 code) of an anti-pattern
also present pre-existing in `animal_repository.dart:214` — worth fixing at the source rather than
propagating further.

**Fix:** Use `DateFormat('yyyy-MM-dd').format(date)` (no timezone conversion) instead of
`date.toUtc().toIso8601String().substring(0, 10)` for any value that represents a date-only field, at
every one of these call sites (this phase's two, plus the pre-existing one in `animal_repository.dart`).

---

_Reviewed: 2026-08-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
