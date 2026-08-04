---
phase: 05-reproductive-module-loteatf
fixed_at: 2026-08-04T21:00:00Z
review_path: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-08-04
**Source review:** .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (CR-01, WR-01, WR-02, WR-03)
- Fixed: 4
- Skipped: 0

**Frontmatter miscount note:** 05-REVIEW.md's frontmatter claims `critical: 2`, but the report
body contains exactly one critical finding (CR-01). There is no CR-02 anywhere in the document.
Worked from the body per the fixer's instructions; the frontmatter count appears to be an
authoring error in the review itself and is called out here rather than silently corrected.

**Migration constraint:** Both Phase 5 migrations
(`20260804_05_reproductive_module.sql`, `20260805_05_atf_rpcs.sql`) are already applied to the
live Supabase project. Per the task's explicit constraint, neither was edited in place. All SQL
fixes (CR-01, WR-02) are new forward-only corrective migrations using `DROP TRIGGER IF EXISTS` /
`CREATE TRIGGER` and `CREATE OR REPLACE FUNCTION`, safe to `supabase db push` once a human
authorizes it. **This agent did not apply anything to the live database** — that step is left to
the orchestrator/user.

## Fixed Issues

### CR-01: `register_baixa` always throws for an animal in an active ATF

**Files modified:** `supabase/migrations/20260806_05_fix_atf_membership_trigger_scope.sql` (new)
**Commit:** `ef89470`
**Applied fix:** Confirmed the review's root-cause chain against the migration source
(`trg_animals_baixa_deactivates_atf`'s nested `UPDATE animal_atf_memberships SET active = false`
re-fires the unconditional `BEFORE UPDATE` trigger, which re-checks `animals.deleted_at IS NULL`
— already false at that point in the same transaction — and raises `23503`, aborting the whole
`register_baixa` transaction). New migration drops and recreates `trg_atf_membership_valid` scoped
to `BEFORE INSERT OR UPDATE OF animal_id, atf_batch_id, property_id` — the only columns any write
path in the module ever changes on an existing row. A pure `active` flip no longer re-fires
validation. `enforce_atf_membership_valid()` itself is untouched.
**Test suite:** `supabase/tests/05_reproductive_test.sql:99-112` (assertions 8/9, D-19
baixa-deactivates-membership) already expresses the corrected behavior unchanged — `lives_ok` on
the baixa `UPDATE` and `active = false` afterward both still hold with the fix in place. No
suite update was needed for this finding. The suite could not be executed here (no Docker/local
Supabase) — this is a pre-existing, documented gap, not new from this fix.

### WR-01: Stale Riverpod providers after ATF-touching mutations

**Files modified:** `lib/features/animais/presentation/baixa_dialog.dart`,
`lib/features/reproducao/presentation/atf_detail_screen.dart`,
`lib/features/reproducao/presentation/atf_animal_selection_screen.dart`,
`lib/features/reproducao/presentation/encerrar_atf_dialog.dart`
**Commit:** `ed2219c`
**Applied fix:** Added `ref.invalidate(reproductiveHistoryByAnimalProvider(...))` at each of the
four sites the review named, mirroring the pattern already correct in `_DgSection._save()`:
- `BaixaDialog._submit`: invalidates for `widget.animal.id` (the minimal variant the review
  offered — same screen the dialog opens from; did not additionally chase down which ATF the
  animal belonged to before baixa, since the dialog has no cheap access to that membership).
- `_CompositionSection._confirmRemove`: invalidates for `membership.animalId`.
- `AtfAnimalSelectionScreen._confirm`: invalidates for every id in `_selectedIds` (the
  newly-added animals).
- `EncerrarAtfDialog._submit`: snapshots `atfActiveMembershipsProvider`'s current value into
  `memberIds` before calling `closeAtf` (since `close_atf` deactivates every one of them), then
  invalidates `reproductiveHistoryByAnimalProvider` for each id after success.
**Note on commit boundaries:** `git commit -m ... -- <pathspec>` commits both staged AND unstaged
changes restricted to the given paths (not only what was `git add -p`'d). As a result, one hunk
of `atf_detail_screen.dart` that belongs to WR-03 (the `_dateOnlyFmt` field and the `exam_date`
line in `_DgSection._save`) was swept into this WR-01 commit rather than the WR-03 commit below.
The content is correct and covered by the same test run; only the commit grouping is imperfect.
Documented here for traceability rather than rewriting history.

### WR-02: `remove_animal_from_atf` silently no-ops with no matching active membership

**Files modified:** `supabase/migrations/20260807_05_fix_remove_animal_from_atf_notfound.sql`
(new), `supabase/tests/05_reproductive_test.sql`
**Commit:** `e90026e`
**Applied fix:** New corrective migration (`CREATE OR REPLACE FUNCTION`) adds an
`IF NOT FOUND THEN RAISE EXCEPTION ... USING ERRCODE = '23503'` check immediately after the
guarded `DELETE`, mirroring the pattern `close_atf`/`register_baixa` already use elsewhere in the
same file. Re-verified against D-08/D-16 before editing: the fix only adds a post-check on the
existing hard-`DELETE` — it does not touch the row-existence distinction `save_dg_records` relies
on to tell a D-08 removal (row absent) apart from a D-16/D-19 deactivation (row present,
`active = false`).
**Test suite extension:** Since this changes observable behavior (silent success →
exception), added one new `throws_ok` assertion (animal 776, never a member of ATF A1, now raises
`23503` when removal is attempted) and bumped `plan(26)` to `plan(27)`. Not executed here for the
same reason noted under CR-01 (no local Docker/Supabase).

### WR-03: `.toUtc()` before date-only truncation can shift the stored calendar date

**Files modified:** `lib/features/reproducao/data/atf_repository.dart`,
`lib/features/animais/data/animal_repository.dart`, plus one hunk of
`lib/features/reproducao/presentation/atf_detail_screen.dart` (see WR-01's note above)
**Commit:** `784c9b1` (two files) + `ed2219c` (the `atf_detail_screen.dart` hunk, committed early)
**Applied fix:** Replaced `date.toUtc().toIso8601String().substring(0, 10)` with a module-level
`final _dateOnlyFmt = DateFormat('yyyy-MM-dd');` and `_dateOnlyFmt.format(date)` at all four call
sites the review named: `AtfRepository.createAtf` (`implantation_date`/`insemination_date`),
`_DgSectionState._save` (`exam_date`), and the pre-existing instance in
`AnimalRepository.registerBaixa` (`p_date`) that the review flagged as worth fixing at the source.
No timezone conversion — matches the field's date-only semantics exactly.

## Verification

- `dart run build_runner build` — ran once after all Dart edits were staged; regenerated 6
  outputs, 0 errors.
- `flutter analyze` — 4 issues, all pre-existing and pre-approved (app_config.dart
  `unintended_html_in_doc_comment`, propriedade_repository.dart `use_null_aware_elements`, two
  `unused_import` in `animais_screen_test.dart`/`lote_form_dialog_test.dart`). **No new issues.**
- `flutter test` — **204/204 passed.** The `exam_date` test in `atf_detail_screen_test.dart`
  (`test/widget/atf_detail_screen_test.dart:527`) computes its own expected `today` string via
  `DateTime.now().toUtc().toIso8601String().substring(0, 10)`, which is no longer byte-identical
  in derivation to the fixed `_dateOnlyFmt.format(DateTime.now())` production code — but both
  produced the same string in this run (test environment's local offset did not straddle the UTC
  boundary at run time), so no test update was required to keep the suite green. This is a latent
  fragility worth a human's attention if that test ever runs in a UTC-ahead CI environment or near
  local midnight, but it was out of scope to touch a passing test file for a finding that did not
  require it.
- pgTAP suite (`supabase/tests/05_reproductive_test.sql`) — could not be executed (no local
  Docker/Supabase instance), a pre-existing and documented gap in this project's execution
  environment, unrelated to this fix session. Both the CR-01 assertion (unchanged, still expresses
  the corrected expectation) and the new WR-02 assertion were reasoned through manually against
  the corrected function bodies.

## Skipped Issues

None — all four in-scope findings (CR-01, WR-01, WR-02, WR-03) were fixed.

---

_Fixed: 2026-08-04_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
