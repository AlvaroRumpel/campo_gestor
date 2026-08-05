---
phase: 05-reproductive-module-loteatf
reviewed: 2026-08-05T00:00:00Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - lib/core/router/router.dart
  - lib/core/router/routes.dart
  - lib/features/animais/data/animal_repository.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - lib/features/animais/presentation/baixa_dialog.dart
  - lib/features/reproducao/data/atf_model.dart
  - lib/features/reproducao/data/atf_repository.dart
  - lib/features/reproducao/data/dg_record_model.dart
  - lib/features/reproducao/data/dg_summary.dart
  - lib/features/reproducao/presentation/atf_animal_selection_screen.dart
  - lib/features/reproducao/presentation/atf_detail_screen.dart
  - lib/features/reproducao/presentation/atf_form_dialog.dart
  - lib/features/reproducao/presentation/encerrar_atf_dialog.dart
  - lib/features/reproducao/presentation/reproducao_screen.dart
  - supabase/migrations/20260804_05_reproductive_module.sql
  - supabase/migrations/20260805_05_atf_rpcs.sql
  - supabase/tests/05_reproductive_test.sql
  - test/core/router_test.dart
  - test/features/animais/animal_repository_test.dart
  - test/features/reproducao/atf_model_test.dart
  - test/features/reproducao/atf_repository_test.dart
  - test/features/reproducao/dg_summary_test.dart
  - test/widget/animal_detail_screen_test.dart
  - test/widget/atf_animal_selection_screen_test.dart
  - test/widget/atf_detail_screen_test.dart
  - test/widget/atf_form_dialog_test.dart
  - test/widget/baixa_dialog_test.dart
  - test/widget/reproducao_screen_test.dart
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 26 (files listed above; two widget test files supplied in the file list —
`test/widget/atf_animal_selection_screen_test.dart` and `test/widget/atf_form_dialog_test.dart` —
were spot-checked for reliability only, per scope rules)
**Status:** issues_found

## Summary

This is a re-review of the Phase 5 (LoteATF) source set. A prior pass (`05-REVIEW.md`, now
superseded by this file, plus `05-REVIEW-FIX.md`) found CR-01 (baixa-in-active-ATF transaction
abort), WR-01 (stale Riverpod providers after ATF mutations), WR-02 (`remove_animal_from_atf`
silent no-op), and WR-03 (`.toUtc()` date-shift risk). All four are verified fixed in the current
code: `20260806_05_fix_atf_membership_trigger_scope.sql` and
`20260807_05_fix_remove_animal_from_atf_notfound.sql` (both present in the repo, though outside
this review's file list) correct the SQL-side issues; `baixa_dialog.dart`,
`atf_detail_screen.dart`, `atf_animal_selection_screen.dart`, and `encerrar_atf_dialog.dart` now
all invalidate `reproductiveHistoryByAnimalProvider` (and, in `baixa_dialog.dart`'s case, the
whole `atfActiveMembershipsProvider`/`atfMembershipsProvider`/`atfListByPropertyProvider` family)
after their respective mutations, confirmed against `test/widget/baixa_dialog_test.dart`'s
`G-05-1` regression harness. A subsequent live-UAT regression (G-05-1: stale ATF providers after
baixa; G-05-1-nav: missing back button on `/atf/:atfId`) is also fixed — `_backButton()` is wired
into all four `AtfDetailScreen` `AppBar` states, and `BaixaDialog._submit` invalidates the ATF
provider family.

This pass found one new data-integrity defect (baixa's optional observation silently overwrites,
rather than appends to, the animal's general notes field) and one new UI defect (an ATF created
with a real touro selected from the dropdown displays the touro's raw UUID instead of a readable
label, because `bullName` is never populated for that path). Both are new findings not present in
the prior review.

## Critical Issues

### CR-01: `register_baixa` silently overwrites the animal's general `observation` field instead of appending to it — data loss

**File:** `supabase/migrations/20260805_05_atf_rpcs.sql:310-314` (the `UPDATE animals` statement
inside `register_baixa`)
**Also affects:** `lib/features/animais/presentation/baixa_dialog.dart:170-179` (the "Observação"
field, hint text `'Observações adicionais (opcional)'`)

**Issue:**

`animals.observation` is a single shared free-text column — the same field `AnimalEditDialog`
(ANIM-02) lets a vet fill in as a general note about the animal, and the same field the DG
observation UI is unrelated to. `register_baixa`'s final `UPDATE` is:

```sql
UPDATE animals
   SET baixa_reason = p_reason,
       baixa_date   = p_date,
       deleted_at   = now(),
       observation  = COALESCE(p_observation, observation)
 WHERE id = p_animal_id
   AND deleted_at IS NULL;
```

`COALESCE(p_observation, observation)` means: if the vet types anything at all into
`BaixaDialog`'s "Observação" field, the animal's *entire* prior `observation` value is replaced by
whatever was typed at baixa time — not appended to it. `BaixaDialog`'s field is labeled generically
"Observação" with hint text `"Observações adicionais (opcional)"` ("*additional* observations,
optional"), which explicitly signals to the user that this text supplements existing notes. It does
not. A vet who baixas an animal and adds a one-line note ("vendido para fazenda X") silently
destroys any prior general observation recorded on that animal (health notes, body-condition
remarks, etc.) with no confirmation, no merge, and no way to recover the prior text (the row is
about to become read-only/archived, so this is effectively permanent).

**Fix:** Either (a) give baixa its own column (e.g. `baixa_observation text`) so it never collides
with the general notes field, or (b) append rather than replace:

```sql
observation = CASE
  WHEN p_observation IS NULL THEN observation
  WHEN observation IS NULL OR observation = '' THEN p_observation
  ELSE observation || E'\n' || p_observation
END
```

Option (a) is preferable — it also lets a future "Motivo da baixa" detail view show the baixa note
distinctly from the animal's general history, and avoids a second special-case string-concatenation
migration touching a column that other RPCs (`updateAnimal`'s direct `.update()`) also write.

## Warnings

### WR-01: ATF header shows the bull's raw animal UUID instead of a readable label when an existing touro (not "Outro / sêmen externo") is selected

**File:** `lib/features/reproducao/presentation/atf_form_dialog.dart:115-119` (`_submit`, the
`createAtf` call), `lib/features/reproducao/presentation/atf_detail_screen.dart:286-300`
(`AtfHeaderCard._buildBullValue`)

**Issue:** `AtfFormDialog._submit` sends `bullAnimalId`/`bullName` as mutually exclusive fields:

```dart
bullAnimalId: _selectedBull != null && _selectedBull != kOtherBull
    ? _selectedBull
    : null,
bullName:
    _selectedBull == kOtherBull ? _bullNameCtrl.text.trim() : null,
```

When the vet picks a real touro from the dropdown (the common path — the dropdown is populated
from the property's own touro animals, showing `#<number> — <breed>`), `bullAnimalId` is set and
`bullName` stays `null` forever (no write path in this module ever backfills it — `AtfRepository`
never joins `atf_batches.bull_animal_id` against `animals` on read either). But
`AtfHeaderCard._buildBullValue` renders:

```dart
Text(
  atf.bullName ?? atf.bullAnimalId!,
  ...
)
```

Since `bullName` is always null for this path, the header permanently displays the raw animal UUID
(e.g. `a1b2c3d4-5678-...`) instead of the `#<number>` the vet selected — a regression from the
readable label shown in the dropdown itself moments earlier. `test/widget/atf_detail_screen_test.dart:292-312`
("bull link: bullAnimalId set renders a tappable InkWell") never catches this because its fixture
sets **both** `bullAnimalId: 'animal-9'` and `bullName: 'Trovão'` simultaneously — a combination the
production `createAtf` call never actually produces, so the test only exercises the (never-hit)
happy path and leaves the real defect uncovered.

**Fix:** Either resolve the bull's display label at read time (join `animals(number, breed)` on
`bull_animal_id` in `fetchAtf`/`fetchAtfBatchesByProperty` and build the label the same way the
dropdown does), or populate `bullName` at create time from the selected touro's number/breed so it
round-trips without a join. Add a test fixture that mirrors the actual `createAtf` call shape
(`bullAnimalId` set, `bullName` null) to close the coverage gap.

### WR-02: `add_animals_to_atf` does not deduplicate `p_animal_ids`, turning a client-side duplicate into an opaque unique-violation for the whole batch

**File:** `supabase/migrations/20260805_05_atf_rpcs.sql:62-64`

**Issue:**

```sql
INSERT INTO animal_atf_memberships (animal_id, atf_batch_id, active, property_id)
SELECT (elem)::uuid, p_atf_batch_id, true, v_property_id
  FROM jsonb_array_elements_text(p_animal_ids) AS elem;
```

If `p_animal_ids` contains the same UUID twice (e.g. a client-side double-tap race in
`AtfAnimalSelectionScreen._toggle`/`_selectedIds` that slips a duplicate into the `Set` — unlikely
given `Set` semantics client-side, but nothing server-side defends against a malformed or replayed
request), the single `INSERT ... SELECT` attempts two active-membership rows for the same animal in
one statement and trips `animal_atf_memberships_active_idx`'s partial unique constraint,
failing the entire batch (including every other, valid animal in the same call) with a raw
`23505` the Dart layer surfaces only as the generic "Erro ao adicionar animais" — no
distinguishing message pointing at which animal or why. This is a minor robustness gap, not a
security issue (the RPC's authorization and cross-property checks are unaffected), but is
inconsistent with the module's general pattern of validating inputs defensively before hitting a
constraint (`save_dg_records` validates `result` explicitly rather than relying solely on the
`CHECK` constraint, for example).

**Fix:** De-duplicate defensively, e.g. `SELECT DISTINCT (elem)::uuid FROM
jsonb_array_elements_text(p_animal_ids) AS elem`, or leave as-is if a duplicate in this request
shape is considered client-code-only and therefore acceptable to fail loudly — worth an explicit
comment either way, matching this file's convention of documenting every other deliberate
non-obvious choice.

## Info

### IN-01: `AnimalRepository`/`AtfRepository` contract tests assert only `isA<Function>()`, not behavior

**File:** `test/features/animais/animal_repository_test.dart:24-55`,
`test/features/reproducao/atf_repository_test.dart:26-78`

**Issue:** Every test in both files reduces to `expect(repo.someMethod, isA<Function>())`, which
is true for any method regardless of its parameter types, return type, or behavior — these tests
cannot fail for any change short of deleting the method entirely (e.g. they would not catch a
regression that dropped a required parameter, changed a return type, or introduced a logic bug in
`AtfRepository.fetchAtfSummaries`'s grouping). This mirrors a pre-existing project-wide convention
(explicitly called out in both files' header comments as intentional, given how brittle mocking
the full Supabase query-builder chain is), so it is not a regression introduced by this phase, but
the density of these tautological assertions (12 across the two files) inflates the visible test
count without adding regression coverage. `dg_summary_test.dart` in the same phase demonstrates the
alternative already available for pure-logic code (`summarizeDg`/`formatPrenhez` get real
value-based assertions) — the repository methods that aren't pure Supabase passthroughs (e.g.
`fetchReproductiveHistory`'s per-ATF most-recent-DG reduction, `fetchEligibleAnimalsForAtf`'s
blocking-map construction) would benefit from being factored out and tested the same way
`dg_summary.dart` is, rather than only exercised indirectly through the RPC/query layer.

**Fix:** No action required for this phase; flagged for awareness. If `AtfRepository` grows more
non-trivial in-memory logic (as `fetchEligibleAnimalsForAtf` and `fetchReproductiveHistory` already
have), factor that logic into standalone functions and give them `dg_summary_test.dart`-style
value assertions.

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
