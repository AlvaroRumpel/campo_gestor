---
phase: 05-reproductive-module-loteatf
reviewed: 2026-08-05T02:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql
  - supabase/tests/05_reproductive_test.sql
  - lib/features/reproducao/presentation/atf_form_dialog.dart
  - lib/features/reproducao/presentation/atf_detail_screen.dart
  - test/widget/atf_form_dialog_test.dart
  - test/widget/atf_detail_screen_test.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - test/widget/animal_detail_screen_test.dart
findings:
  critical: 1
  warning: 1
  info: 2
  total: 4
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This is a targeted re-review of the corrective work closing the previous `05-REVIEW.md`'s CR-01
(baixa observation data loss) and WR-02 (`add_animals_to_atf` payload duplication), plus the WR-01
bull-label fix and the quick-task 260805-3mr observation-display gap.

The corrective SQL migration (`20260808_...sql`) correctly fixes both defects it targets:
`register_baixa`'s `CASE` expression genuinely appends rather than replaces (verified against the
new pgTAP assertions, which are logically sound and match `plan(33)`'s count), and
`add_animals_to_atf`'s `SELECT DISTINCT` correctly collapses an in-payload duplicate while leaving
the cross-ATF unique-constraint guarantee (REPR-02) intact. The WR-01 bull-label fix
(`_bullLabel`, `_buildBullValue`'s `'Ver touro'` fallback) and the animal-ficha observation display
are both correctly implemented and covered by tests that would fail if reverted.

While verifying this corrective work, this pass found one new defect in `_DgSection` (unrelated to
the three items this patch targets, but present in a file fully in scope): a batch DG save can
silently discard a vet's typed observation for any animal whose chip selection did not change,
even though the "DGs registrados." success confirmation gives no indication anything was
dropped. It also found a missing NULL-guard in `register_baixa`'s reason validation that predates
this migration but is carried forward unchanged into the full function body this migration
redeclares.

## Critical Issues

### CR-01: `_DgSection` batch save silently drops a typed observation for any row whose DG result did not change

**File:** `lib/features/reproducao/presentation/atf_detail_screen.dart:659-665, 707-721`

**Issue:**

`_save()` builds its RPC payload only from `_changedAnimalIds()`:

```dart
Set<String> _changedAnimalIds() {
  final changed = <String>{};
  for (final entry in _staged.entries) {
    if (entry.value != _mostRecentDg(entry.key)) changed.add(entry.key);
  }
  return changed;
}
```

An animal id only enters `changed` when its **staged chip selection differs from the
already-persisted DG result**. The observation field, however, is attached per-row inside the same
loop that iterates `changed`:

```dart
final records = [
  for (final animalId in changed)
    {
      'animal_id': animalId,
      'result': _staged[animalId]!.dbValue,
      'exam_date': ...,
      if ((_obsControllers[animalId]?.text.trim() ?? '').isNotEmpty)
        'observation': _obsControllers[animalId]!.text.trim(),
    },
];
```

If a vet opens the "Adicionar observação" field for an animal whose chip selection they never
change (e.g. re-confirming an already-correct "Prenha" with a note, or typing a note on one animal
while only actually changing a *different* animal's result in the same session), that animal's id
is never in `changed`, so its record — observation included — is never built, never sent to
`saveDgRecords`, and never persisted.

This is reachable without any error surfacing: as long as **at least one other animal** in the same
batch has a genuine chip change, `changedCount > 0`, the "Salvar DGs" button is enabled, the save
succeeds, and the UI shows `SnackBar(content: Text('DGs registrados.'))` — a success confirmation
that gives the vet no indication the observation they typed for the unchanged-result animal was
silently discarded. Re-tapping the *same* already-selected chip does not rescue this either:
`ChoiceChip`'s `onSelected: canEdit ? (_) => onSelect(r) : null` ignores the toggle boolean and
always restages the same value `r`, so `_staged[animalId] == _mostRecentDg(animalId)` remains true
and the row still never enters `changed`.

No test in `atf_detail_screen_test.dart` exercises "type an observation on a row whose chip is
never touched, save, then reload" — the existing observation test
(`'a row with an observation entered carries it in the payload'`) always taps a chip first,
which is exactly the condition that hides this gap.

**Fix:** Include any animal with non-empty staged observation text in `changed`, and stop
force-unwrapping `_staged[animalId]` when building the result (an obs-only row has no staged
entry):

```dart
Set<String> _changedAnimalIds() {
  final changed = <String>{};
  for (final entry in _staged.entries) {
    if (entry.value != _mostRecentDg(entry.key)) changed.add(entry.key);
  }
  for (final entry in _obsControllers.entries) {
    if (entry.value.text.trim().isNotEmpty) changed.add(entry.key);
  }
  return changed;
}
```

```dart
for (final animalId in changed)
  {
    'animal_id': animalId,
    'result': (_staged[animalId] ?? _mostRecentDg(animalId))!.dbValue,
    'exam_date': ...,
    if ((_obsControllers[animalId]?.text.trim() ?? '').isNotEmpty)
      'observation': _obsControllers[animalId]!.text.trim(),
  },
```

## Warnings

### WR-01: `register_baixa` accepts `p_reason IS NULL` because `NULL NOT IN (...)` is `NULL`, not `TRUE`

**File:** `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql:132-135`

**Issue:**

```sql
IF p_reason NOT IN ('sale', 'death', 'discard') THEN
  RAISE EXCEPTION 'invalid baixa reason %', p_reason
    USING ERRCODE = '22023';
END IF;
```

In SQL (and plpgsql), `NULL NOT IN (...)` evaluates to `NULL`, and `IF NULL THEN ... END IF` takes
the false branch. If an authenticated veterinarian calls this `SECURITY DEFINER` RPC directly
(via `supabase-js`/PostgREST, not necessarily through `BaixaDialog`) with `p_reason => NULL`, the
validation is silently skipped and the subsequent `UPDATE` archives the animal with
`baixa_reason = NULL` — bypassing the very check this `IF` exists to enforce. `p_date` has the same
gap (no NULL guard), letting a baixa be recorded with `baixa_date = NULL`. This function is a trust
boundary (`SECURITY DEFINER`, directly callable by any `authenticated` user who is a member+vet of
the property) and reused unchanged by this migration's `CREATE OR REPLACE`, so it is being carried
forward rather than newly introduced — but it is present, unguarded, in the exact function body
this migration re-declares in full.

**Fix:**

```sql
IF p_reason IS NULL OR p_reason NOT IN ('sale', 'death', 'discard') THEN
  RAISE EXCEPTION 'invalid baixa reason %', p_reason
    USING ERRCODE = '22023';
END IF;

IF p_date IS NULL THEN
  RAISE EXCEPTION 'baixa date is required'
    USING ERRCODE = '22023';
END IF;
```

## Info

### IN-01: Two unrelated fixes are both labeled "WR-02" in committed comments, making the id ambiguous for future traceability

**File:** `supabase/migrations/20260808_05_fix_baixa_observation_and_atf_dedup.sql:22-28`,
`supabase/tests/05_reproductive_test.sql:271-281`

**Issue:** This migration's header labels the `add_animals_to_atf` dedup fix "WR-02" (matching the
superseded `05-REVIEW.md`'s WR-02). But `05_reproductive_test.sql:271-281` already uses the same
"WR-02" label for an unrelated, earlier fix — `remove_animal_from_atf` raising on a 0-row delete
instead of silently no-op'ing. Both are legitimately fixed, but grepping this codebase for "WR-02"
now returns two unrelated defects from two different review passes, which will confuse whoever
next greps for it to understand what a comment is referring to.

**Fix:** No code change needed. When referencing finding ids from a prior review pass in new
comments/migrations, qualify with the source document (e.g. "05-REVIEW.md#WR-02" is already done
in the migration header — the test file's older "WR-02" reference should similarly be qualified,
e.g. "WR-02 (05-REVIEW-FIX.md)", to disambiguate).

### IN-02: `AtfFormDialog._submit` can still write `bullAnimalId` with a null `bullName` if `animalListByPropertyProvider`'s data changes between dropdown selection and submit

**File:** `lib/features/reproducao/presentation/atf_form_dialog.dart:118-132`

**Issue:** `_submit()` re-resolves the selected touro from a freshly-read provider value rather than
reusing the list the dropdown was built from:

```dart
final animals = ref.read(animalListByPropertyProvider).asData?.value ??
    const <AnimalWithContext>[];
final selectedBull =
    animals.where((aw) => aw.animal.id == _selectedBull).firstOrNull;
...
bullAnimalId: _selectedBull != null && _selectedBull != kOtherBull
    ? _selectedBull
    : null,
bullName: _selectedBull == kOtherBull
    ? _bullNameCtrl.text.trim()
    : (selectedBull != null ? _bullLabel(selectedBull) : null),
```

If the provider's cached list changes between the user's dropdown pick and the tap on "Criar ATF"
(e.g. `ref.invalidate(animalListByPropertyProvider)` fires from elsewhere while this dialog is
open), `selectedBull` can resolve to `null` while `_selectedBull` (the id) is still non-null and
not `kOtherBull` — writing `bullAnimalId` set with `bullName` null, the exact row shape WR-01 was
written to prevent. In practice this is mitigated by `AtfHeaderCard._buildBullValue`'s `'Ver
touro'` fallback (no raw UUID ever renders), so this is not a WR-01 regression, just a narrower
edge case that loses the specific bull's label. Low likelihood given no realtime/background
refresh exists in this MVP, but worth a defensive comment or an assertion given how deliberately
`_bullLabel`'s single-source-of-truth docstring frames this exact risk.

**Fix:** Capture the matching `AnimalWithContext` at selection time (`onChanged`) instead of
re-resolving it from a possibly-stale list at submit time, e.g. store `AnimalWithContext?
_selectedBullAnimal` alongside `_selectedBull` in `setState`.

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
