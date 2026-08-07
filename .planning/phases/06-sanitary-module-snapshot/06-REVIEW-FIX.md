---
phase: 06-sanitary-module-snapshot
fixed_at: 2026-08-07T19:46:50Z
review_path: .planning/phases/06-sanitary-module-snapshot/06-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 6: Code Review Fix Report

**Fixed at:** 2026-08-07T19:46:50Z
**Source review:** .planning/phases/06-sanitary-module-snapshot/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (critical_warning scope — CR-01, WR-01..WR-05; IN-01..IN-03 excluded)
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: Dose cost field silently drops a malformed value instead of rejecting it

**Files modified:** `lib/features/sanitario/presentation/dose_form_dialog.dart`
**Commit:** `5cff3d6`
**Applied fix:** Added a `validator` to the `_costCtrl` `TextFormField` mirroring the dosage field's
pattern — blank input is accepted (optional field), but a non-empty value that fails
`_parseDouble` now returns `'Custo (R$/kg) inválido'` instead of silently being saved as `null`.

### WR-01: AplicacaoDetailScreen checks the wrong property's role for the estorno action

**Files modified:** `lib/features/sanitario/presentation/aplicacao_detail_screen.dart`
**Commit:** `2cb0031`
**Applied fix:** `_canEdit` now takes `app.propertyId` (the frozen application's own property)
instead of the currently active property. Removed the now-unused `currentPropertyProvider` read
and its import from this file — `memberPropertiesProvider`/`PropertyMembership` (same import) are
still used and were kept.

### WR-02: Dose dosage field accepts 0, which the database rejects

**Files modified:** `lib/features/sanitario/presentation/dose_form_dialog.dart`
**Commit:** `6f140c7`
**Applied fix:** Dosage validator now rejects values `<= 0` with `'Dosagem (mL/kg) deve ser maior
que zero'`, mirroring the DB's `CHECK (dosage_per_kg > 0)` constraint. Left the existing
blank/unparsable message text untouched (that wording issue is IN-02, out of scope for this
fix_scope).

### WR-03: SanitaryAnimalSelectionScreen._reload() has no error handling or busy guard

**Files modified:** `lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart`
**Commit:** `f9471d3`
**Applied fix:** Wrapped `_reload()` in try/catch/finally with a user-visible SnackBar on failure,
and added a `_reloading` flag that disables the "Continuar" button while a reload is in flight —
preventing a second concurrent `ResumoAplicacaoDialog`/reload from firing on re-tap.

### WR-04: DoseRepository.archiveDose/restoreDose don't verify the update actually matched a row

**Files modified:** `lib/features/sanitario/data/dose_repository.dart`
**Commit:** `bbe0981`
**Applied fix:** Both `archiveDose` and `restoreDose` now chain `.select().single()`, which throws
when the UPDATE matches zero rows (RLS silently filtering, a stale id, or a concurrent delete),
surfacing the failure through `_toggleArchive`'s existing try/catch/SnackBar in
`sanitario_screen.dart` instead of silently no-op'ing.

### WR-05: `kgPerUa` resolution logic is copy-pasted verbatim in three files

**Files modified:** `lib/features/sanitario/data/kg_per_ua_resolver.dart` (new),
`lib/features/sanitario/presentation/dose_form_dialog.dart`,
`lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart`,
`lib/features/sanitario/presentation/sanitario_screen.dart`
**Commit:** `ae0f6b1`
**Applied fix:** Extracted the identical `currentPropertyProvider` + `propertyListProvider` join
(with its 400 fallback) into a single `double resolveActiveKgPerUa(WidgetRef ref)` function in a
new file, `kg_per_ua_resolver.dart`. Replaced all three private `_kgPerUa`/`_resolveKgPerUa`
methods with calls to the shared helper and removed now-unused imports
(`propriedade_repository.dart` in `sanitario_screen.dart`; `current_property_provider.dart` and
`propriedade_repository.dart` in `resumo_aplicacao_dialog.dart`, where `currentPropertyProvider`
had no other use site).

## Skipped Issues

None — all in-scope findings were fixed.

## Notes

- Fix scope was `critical_warning` (default); Info-tier findings IN-01, IN-02, IN-03 from
  06-REVIEW.md were intentionally left untouched per scope and remain available for a future
  `fix_scope: all` pass.
- Verification: each fix was re-read in place (Tier 1) and the sanitary module was analyzed with
  `dart analyze` after `flutter pub get` (Tier 2, informal — Dart isn't in the strict
  verification-strategy table). The only errors surfaced were pre-existing "undefined getter" on
  freezed model fields (`Dose`, `Animal`, `SanitaryApplication`), caused by this worktree never
  having run `build_runner` to generate `.freezed.dart`/`.g.dart` files — an environment gap
  present uniformly across the whole module, not introduced by any of these fixes.

---

_Fixed: 2026-08-07T19:46:50Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
