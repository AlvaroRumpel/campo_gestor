---
phase: 06-sanitary-module-snapshot
reviewed: 2026-08-07T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - lib/core/router/router.dart
  - lib/core/router/routes.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - lib/features/lotes/presentation/lote_detail_screen.dart
  - lib/features/propriedades/data/propriedade_model.dart
  - lib/features/sanitario/data/dose_model.dart
  - lib/features/sanitario/data/dose_repository.dart
  - lib/features/sanitario/data/sanitary_application_exception.dart
  - lib/features/sanitario/data/sanitary_application_model.dart
  - lib/features/sanitario/data/sanitary_application_repository.dart
  - lib/features/sanitario/data/sanitary_calculations.dart
  - lib/features/sanitario/presentation/aplicacao_detail_screen.dart
  - lib/features/sanitario/presentation/aplicacao_form_dialog.dart
  - lib/features/sanitario/presentation/dose_form_dialog.dart
  - lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart
  - lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart
  - lib/features/sanitario/presentation/sanitario_screen.dart
  - lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart
  - lib/features/sanitario/presentation/sanitary_history_section.dart
  - supabase/migrations/20260810_06_sanitary_module.sql
  - supabase/migrations/20260811_06_sanitary_rpcs.sql
  - supabase/tests/06_sanitary_test.sql
  - test/features/sanitario/dose_calculations_test.dart
  - test/features/sanitario/sanitary_calculations_test.dart
  - test/widget/aplicacao_form_dialog_test.dart
  - test/widget/sanitary_animal_selection_screen_test.dart
findings:
  critical: 2
  warning: 3
  info: 3
  total: 8
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-08-07T00:00:00Z
**Depth:** standard
**Files Reviewed:** 25 (+ 1 widget test file listed twice removed → 26 in scope, 25 reviewable Dart/SQL sources)
**Status:** issues_found

## Summary

Reviewed the Phase 6 sanitary module: two RPCs + supporting Flutter data/presentation layers, pgTAP suite, and unit/widget tests. The append-only snapshot design, concurrency revalidation (D-32), and reversal uniqueness (D-31) are all correctly implemented and covered by the pgTAP suite. However, two BLOCKER-level defects were found: (1) the `doses` UPDATE RLS policy's `USING` clause makes both dose editing and dose restoration silently no-op once a dose is archived, directly contradicting behavior the application code explicitly assumes; (2) reversal rows carry negated totals by design (D-28, for SUM() correctness) but at least three UI surfaces render those negative numbers raw to the user ("-3 animais", "-2,3 UA"), which is reachable through completely ordinary navigation (toggling "Mostrar estornadas", or tapping "Ver estorno"). Three warnings and three info-level findings are also included below.

## Critical Issues

### CR-01: RLS policy silently blocks editing/restoring an archived dose

**File:** `supabase/migrations/20260810_06_sanitary_module.sql:47-53` (policy), consumed by `lib/features/sanitario/data/dose_repository.dart:75-115` (`updateDose`, `restoreDose`)

**Issue:** The UPDATE policy is:
```sql
CREATE POLICY "veterinarian_can_update_active_dose" ON doses FOR UPDATE TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) = 'veterinarian'::role_enum
    AND deleted_at IS NULL
  )
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
```
The `USING` clause is evaluated against the **existing** row before the update is allowed to proceed. Because it requires `deleted_at IS NULL` on the pre-update row, PostgREST/RLS silently excludes any already-archived dose from being matched by an `UPDATE ... WHERE id = :id` statement — it does not raise an error, it just updates 0 rows.

This breaks two things the app explicitly relies on:
1. `DoseRepository.restoreDose()` (dose_repository.dart:110-115) sets `deleted_at = null` on an archived dose — but the row it targets already has `deleted_at IS NOT NULL`, so the `USING` clause excludes it from the very start. The "Reativar dose" button in `sanitario_screen.dart:155-177` will call this, get back a 200 with 0 rows affected (no exception, since neither call chains `.select().single()`), and the dose stays archived with no error shown to the user.
2. `DoseFormDialog`'s own docstring (dose_form_dialog.dart:12-14) explicitly documents "an edit can touch an archived dose (edit icon stays visible under 'Mostrar arquivadas')" — but `updateDose()` on an archived dose is blocked by the exact same `USING` clause, so editing an archived dose also silently no-ops.

No pgTAP test in `06_sanitary_test.sql` exercises an UPDATE against an archived dose, so this gap was not caught.

**Fix:** Drop `AND deleted_at IS NULL` from the `USING` clause (the archival/restoration action itself should be allowed regardless of current archived state — the app never lets a non-veterinarian or non-member reach this path anyway):
```sql
CREATE POLICY "veterinarian_can_update_active_dose" ON doses FOR UPDATE TO authenticated
  USING (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum)
  WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum);
```
Also add a pgTAP case: veterinarian restores/edits an archived dose and the row actually changes (`lives_ok` + a follow-up `is()` on the updated column), so this class of regression is caught going forward.

---

### CR-02: Reversal rows show raw negative totals in the UI

**Files:**
- `lib/features/sanitario/presentation/aplicacao_detail_screen.dart:174-183` (`_AplicacaoHeaderCard` totals line)
- `lib/features/sanitario/presentation/sanitario_screen.dart:468-478` (`_AplicacaoCard` subtitle)
- `lib/features/sanitario/presentation/sanitary_history_section.dart:201-214` (`_buildLoteRow`)

**Issue:** Per D-28 (documented in `20260811_06_sanitary_rpcs.sql:131-138`), a reversal row's `animal_count`, `total_ua`, `total_volume` and `total_cost` are all stored **negated**, specifically so that `SUM()` queries self-correct — this is a data-layer convention, not a display convention. None of the three UI call sites above account for this: they feed `app.animalCount`, `app.totalUa`, `app.totalVolume`, `app.totalCost` straight into `Intl.plural(...)`, `formatUa(...)`, `formatVolumeMl(...)`, `formatCurrencyBrl(...)` regardless of whether `app.isReversal` is true.

Concretely, viewing (or listing, with "Mostrar estornadas" on) a reversal row for the fixture in the pgTAP suite (3 animals, 2.25 UA, 900 mL, R$9000) renders:
- `AplicacaoDetailScreen`: `"-3 animais · -2,3 UA · -900 mL · R$ -9.000,00"`
- `SanitarioScreen`'s applications-tab card subtitle: `"... · -3 animais · -2,3 UA"`
- `LoteSanitaryHistorySection` row: `"... · -3 animais ... · R$ -9.000,00"`

This is directly reachable through ordinary use: toggling "Mostrar estornadas" anywhere, or tapping "Ver estorno" / "Estorno de" (both wired via `context.go(AppRoutes.aplicacaoDetail(...))` in `aplicacao_detail_screen.dart:267` and `:286`) navigates straight to a reversal row's own detail page, which always shows this totals line.

**Fix:** Take the absolute value of the four totals whenever rendering them (the sign only needs to matter for `SUM()` queries, never for a single row's display):
```dart
final totalsParts = <String>[
  Intl.plural(app.animalCount.abs(), one: '1 animal', other: '${app.animalCount.abs()} animais'),
  '${formatUa(app.totalUa.abs())} UA',
  formatVolumeMl(app.totalVolume.abs()),
  if (app.totalCost != null) formatCurrencyBrl(app.totalCost!.abs()),
];
```
Apply the same `.abs()` treatment in `_AplicacaoCard` (sanitario_screen.dart) and `_buildLoteRow`/`_buildAnimalRow` (sanitary_history_section.dart) — `_buildAnimalRow` doesn't currently render totals so it is unaffected, but `_buildLoteRow` needs the same fix as the other two.

## Warnings

### WR-01: "Ver todas" query-param seeding only fires once per SanitarioScreen lifetime

**File:** `lib/features/sanitario/presentation/sanitario_screen.dart:96-109`

**Issue:** `_seedFiltersFromQuery` guards itself with `if (_filtersSeeded) return;` so it only reads `GoRouterState.of(context).uri.queryParameters` exactly once. Because `SanitarioScreen` lives inside a `StatefulShellBranch` (`_shellSanitarioKey`, `router.dart:211-219`), its `State` is kept alive across navigations within that branch — it is not recreated on a second `context.go('/sanitario?...')`. So: if a user reaches `/sanitario?lote=X` once (via the lote history section's "Ver todas"), `_filtersSeeded` becomes `true` and `_lotFilterId` is set. A later visit to `/sanitario?animal=Y` (via the animal ficha's "Ver todas", `sanitary_history_section.dart:84`) will not update `_animalFilterId` or switch back to the applications tab — the guard silently drops the new query parameters, leaving the screen showing the stale lote filter instead of the requested animal filter.

**Fix:** Track the last-seeded query string (or watch `GoRouterState.of(context).uri.query` and reseed whenever it changes) instead of a one-shot boolean:
```dart
String? _lastSeededQuery;

void _seedFiltersFromQuery(BuildContext context) {
  final query = GoRouterState.of(context).uri.query;
  if (query == _lastSeededQuery) return;
  _lastSeededQuery = query;
  final queryParameters = GoRouterState.of(context).uri.queryParameters;
  final lote = queryParameters['lote'];
  final animal = queryParameters['animal'];
  setState(() {
    _lotFilterId = lote;
    _animalFilterId = animal;
  });
  if (lote != null || animal != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.animateTo(0);
    });
  }
}
```

### WR-02: "Ver estorno" recovery link reads a stale cached provider in the exact race it exists to handle

**File:** `lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart:173-184`

**Issue:** When `reverseApplication` fails with `alreadyReversed` (D-31 race — another user reversed the same application moments earlier), `_ErrorSlot` tries to resolve the sibling reversal row via `ref.watch(sanitaryApplicationsByLotProvider(lotId)).asData?.value`. This provider is a cached `FutureProvider.family` that was almost certainly already resolved (and not invalidated) before the race occurred — it was fetched when `AplicacaoDetailScreen`/`LoteDetailScreen` first rendered, well before the concurrent estorno happened. Nothing in the catch path invalidates or re-fetches `sanitaryApplicationsByLotProvider(lotId)` before this lookup runs, so in the actual race scenario the sibling row is very unlikely to be present, and the code falls back to "message-only" (dropping the "Ver estorno" link) in exactly the case it was built to handle.

**Fix:** `ref.invalidate(sanitaryApplicationsByLotProvider(lotId))` (or `ref.refresh(...)`) before/when building `_ErrorSlot` for the `alreadyReversed` reason, so the sibling reversal row created by the other user is actually visible.

### WR-03: Existence-leak between error codes in both sanitary RPCs

**File:** `supabase/migrations/20260811_06_sanitary_rpcs.sql:39-51` (`register_sanitary_application`), `:149-160` (`reverse_sanitary_application`)

**Issue:** Both RPCs resolve the target row/lot (bypassing RLS as `SECURITY DEFINER`) and only check `is_member_of`/`get_role` afterward. This means a caller who belongs to *some* property can distinguish "id doesn't exist / lot archived" (`23503`) from "id exists but I'm not a member of that property" (`42501`) for a UUID belonging to a completely different tenant — a minor cross-tenant existence-enumeration channel (practically low-risk given random v4 UUIDs, and this mirrors the guard-sequence convention used by prior-phase RPCs per the file header comment, so it is likely an accepted tradeoff rather than newly introduced risk).

**Fix:** If tightened, fold the membership check into the initial `SELECT` (e.g. `WHERE id = ... AND property_id IN (SELECT property_id FROM property_members WHERE user_id = auth.uid())`) so both "doesn't exist" and "not a member" collapse into the same `23503`/`42501` outcome. Low priority given the established codebase pattern.

## Info

### IN-01: `DoseRepository.fetchDose` is unused

**File:** `lib/features/sanitario/data/dose_repository.dart:40-48`

**Issue:** No caller found anywhere under `lib/` for `fetchDose`. Dead code.

**Fix:** Remove it, or if it is meant for a near-future screen, note that in a comment.

### IN-02: No-op `.order()` chained before `.maybeSingle()` in `fetchApplication`

**File:** `lib/features/sanitario/data/sanitary_application_repository.dart:68-78`

**Issue:** `fetchApplication(id)` filters with `.eq('id', id)` (at most one row can ever match) but still chains `.order('applied_at', ...).order('created_at', ...)` before `.maybeSingle()`. The ordering has no effect since there is only ever 0 or 1 row.

**Fix:** Drop the two `.order()` calls for clarity — they were presumably copy-pasted from `fetchApplicationsByProperty`/`fetchApplicationsByLot`.

### IN-03: `kg/UA` property-join helper duplicated across three files

**Files:** `lib/features/sanitario/presentation/dose_form_dialog.dart:94-101`, `lib/features/sanitario/presentation/sanitario_screen.dart:114-121`, `lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart:106-114`

**Issue:** The same ~6-line "resolve `currentPropertyProvider` id, look it up in `propertyListProvider`, default to 400" logic is copy-pasted verbatim (modulo variable names) in three different `ConsumerState`/`ConsumerStatefulWidget` classes.

**Fix:** Extract a small shared provider (e.g. `kgPerUaProvider` in `sanitary_calculations.dart` or a new tiny file) that all three read via `ref.watch`, rather than three independent copies that must be kept in sync by hand.

---

_Reviewed: 2026-08-07T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
