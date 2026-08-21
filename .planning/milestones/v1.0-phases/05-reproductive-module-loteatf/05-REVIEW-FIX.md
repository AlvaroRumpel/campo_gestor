---
phase: 05-reproductive-module-loteatf
fixed_at: 2026-08-05T07:45:00Z
review_path: .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-08-05
**Source review:** .planning/phases/05-reproductive-module-loteatf/05-REVIEW.md
**Iteration:** 1

**Note:** This report corresponds to the re-review pass dated 2026-08-05 (05-REVIEW.md,
"targeted re-review of the corrective work" following the earlier 2026-08-04 fix session). It
overwrites this file's prior contents, which documented fixes for a now-superseded review that
found a different CR-01/WR-01/WR-02/WR-03 set. That earlier fix history remains intact in git log
(commits `ef89470`, `ed2219c`, `e90026e`, `784c9b1`) — only this report file is replaced.

**Summary:**
- Findings in scope: 2 (CR-01 critical, WR-01 warning)
- Fixed: 2
- Skipped: 0

## Fixed Issues

### CR-01: `_DgSection` batch save silently drops a typed observation for any row whose DG result did not change

**Files modified:** `lib/features/reproducao/presentation/atf_detail_screen.dart`, `test/widget/atf_detail_screen_test.dart`
**Commit:** `f6f70d5`

**Applied fix:**

- `_changedAnimalIds()` now also includes any animal id whose observation controller has
  non-empty trimmed text, guarded on a resolvable DG result (`_staged.containsKey(animalId) ||
  _mostRecentDg(animalId) != null`). The guard beyond the review's literal suggestion was
  necessary: `dg_records.result` is `NOT NULL` in the schema, and a row with no DG history at all
  plus no staged chip has nothing valid to persist — including it unconditionally would force-
  unwrap a null `DgResult` and crash instead of silently dropping data (a regression worse than
  the original bug).
- `_save()`'s record builder now resolves `result` via `(_staged[animalId] ??
  _mostRecentDg(animalId))!.dbValue` instead of force-unwrapping `_staged[animalId]!`, since an
  obs-only row (chip never touched) has no `_staged` entry.
- Additionally wired an `onObservationChanged` callback (`_DgChipRow` → `setState(() {})`) on the
  observation `TextFormField`'s `onChanged`. This was required for the fix to be reachable through
  the actual UI: typing into a `TextEditingController` does not itself trigger a widget rebuild, so
  without this the "Salvar DGs" button's `changedCount` stayed stale and the button remained
  disabled for the review's own reproduction case (re-confirming an already-correct DG with just a
  note, no other row changed) — the logic fix would have been correct but practically unreachable
  without also wiring this.
- Added a widget test (`CR-01: typing an observation on a row whose chip is never touched still
  saves that row, carrying the existing DG result forward`) proving: an animal with an existing DG
  result, no chip re-tap, only a typed observation, still enables "Salvar DGs" and carries
  `{animal_id, result: <existing>, observation}` into the RPC payload.

**Verification:**
- `flutter test test/widget/atf_detail_screen_test.dart` — 39/39 passed (new test included).
- `flutter analyze lib/features/reproducao/presentation/atf_detail_screen.dart` — no issues found.

### WR-01: `register_baixa` accepts `p_reason IS NULL` because `NULL NOT IN (...)` is `NULL`, not `TRUE`

**Files modified:** `supabase/migrations/20260809_05_fix_register_baixa_null_guards.sql` (new),
`supabase/tests/05_reproductive_test.sql`
**Commit:** `6df936d`

**Applied fix:**

- New forward-only corrective migration `20260809_05_fix_register_baixa_null_guards.sql`, per this
  phase's established convention (`20260806`/`20260807`/`20260808`): `CREATE OR REPLACE FUNCTION
  register_baixa` with the full current body (including the 20260808 CR-01 observation-append
  `CASE` and the `IF NOT FOUND` concurrent-archive re-check), changing only the guard clauses:
  - `IF p_reason NOT IN (...)` → `IF p_reason IS NULL OR p_reason NOT IN (...)`
  - Added `IF p_date IS NULL THEN RAISE EXCEPTION ...` (no prior guard existed at all for this
    parameter).
  Both raise `22023`, matching the existing reason-check's error code convention.
- Did **not** edit the already-applied `20260808_...sql` migration in place — that file is
  untouched.
- Added two pgTAP assertions (34, 35) to `supabase/tests/05_reproductive_test.sql`: a `throws_ok`
  for `register_baixa(..., NULL, '2026-03-03', NULL)` and for `register_baixa(..., 'sale', NULL,
  NULL)`, both expecting `22023`. Bumped `plan(33)` → `plan(35)` and added a dedicated fixture
  animal (`...781`) so these assertions don't couple to animals used by other test sections.

**Verification:**
- Tier 1 (re-read): migration body and new test assertions confirmed present and syntactically
  consistent with the file's existing PREPARE/throws_ok pattern (checked for `PREPARE` name
  collisions across the whole file — none found).
- Tier 2/pgTAP execution was **not run** — no local Supabase/Docker stack was available in this
  environment (`supabase status` failed: Docker not reachable). This mirrors the same
  "authored + committed now; not executed" caveat this test file's own header already carries for
  the rest of its assertions.

**Follow-up checkpoint (required before this fix takes effect in production):**
This migration has **not** been applied to the live Supabase project, per this task's explicit
instruction. A human must run:
```
supabase db push
supabase test db
```
and confirm all 35 pgTAP assertions pass (up from 33) before `register_baixa`'s NULL-guard fix is
live. Until then, the pre-existing gap (a NULL `p_reason` or `p_date` silently passing this
`SECURITY DEFINER` RPC) remains active in production.

## Skipped Issues

None — both in-scope findings (CR-01, WR-01) were fixed. Info findings IN-01/IN-02 were out of
scope for this run (`fix_scope: critical_warning`).

---

_Fixed: 2026-08-05_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
