---
phase: 06-sanitary-module-snapshot
reviewed: 2026-08-07T00:00:00Z
depth: standard
files_reviewed: 30
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
  - lib/main.dart
  - supabase/migrations/20260810_06_sanitary_module.sql
  - supabase/migrations/20260811_06_sanitary_rpcs.sql
  - supabase/migrations/20260812_06_fix_dose_update_policy.sql
  - supabase/tests/06_sanitary_test.sql
  - test/core/retry_policy_test.dart
  - test/features/sanitario/dose_calculations_test.dart
  - test/features/sanitario/sanitary_application_repository_test.dart
  - test/features/sanitario/sanitary_calculations_test.dart
  - test/widget/aplicacao_form_dialog_test.dart
  - test/widget/sanitary_animal_selection_screen_test.dart
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-08-07T00:00:00Z
**Depth:** standard
**Files Reviewed:** 30
**Status:** issues_found

## Summary

Reviewed the sanitary module (doses, sanitary applications, register/reverse RPCs) plus its
touch points in the animal ficha, lote ficha and router. The server side (RPCs, RLS, triggers,
pgTAP suite) is solid: composition snapshots are frozen and immutable, the concurrency
revalidation (D-32) aborts the whole transaction, the reversal uniqueness index and role/tenant
guards are correctly ordered, and the pgTAP plan count matches the 81 assertions actually
written. The `20260812` corrective migration for the dose-update policy is itself correct.

The client side has one real data-loss bug (an unvalidated cost field that silently drops the
typed value instead of blocking the save), a permission-check that reads the wrong property's
role on a root-level detail route, a recovery path with no error handling, and a few
maintainability nits (copy-pasted `kgPerUa` resolution logic, dead `.order()` calls on a
single-row query). None of the client-side issues are exploitable past the server's own RLS/RPC
guards, but the cost-field bug is a genuine silent data-loss risk for end users.

## Critical Issues

### CR-01: Dose cost field silently drops a malformed value instead of rejecting it

**File:** `lib/features/sanitario/presentation/dose_form_dialog.dart:241-253` (field), `lib/features/sanitario/presentation/dose_form_dialog.dart:84-88` (`_parseDouble`), `lib/features/sanitario/presentation/dose_form_dialog.dart:122` (`_submit`)

**Issue:** The `_costCtrl` `TextFormField` has no `validator`, unlike `_dosageCtrl` two fields above
it. Its `inputFormatters` allow both `,` and `.` freely (`RegExp(r'[0-9.,]')`), so a user can type
something like `8,,50` or `1.2.3` — a value that survives the character filter but fails
`double.tryParse` after the comma→period normalization in `_parseDouble`:

```dart
double? _parseDouble(String v) {
  final normalized = v.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);   // returns null for "1..50" etc.
}
```

Because `cost` is only ever read as `_parseDouble(_costCtrl.text)` (line 122) and no validator
exists to catch this on `_formKey.currentState!.validate()`, the malformed text is silently
treated as "no cost" (`null`) and the dose is saved without any indication to the user that the
value they typed was dropped — a silent data-loss path with no error message, no confirmation,
nothing. This is exactly the "R$ 0,00 never reaches a screen" contract (D-11) working against the
user: a real intended value quietly becomes "unknown" instead of surfacing an error.

**Fix:** Add a validator mirroring the dosage field's pattern — reject (don't silently null out)
whenever the field is non-empty but unparsable:

```dart
TextFormField(
  controller: _costCtrl,
  // ...
  validator: (v) {
    if (v == null || v.trim().isEmpty) return null; // optional field
    if (_parseDouble(v) == null) return 'Custo (R\$/kg) inválido';
    return null;
  },
),
```

## Warnings

### WR-01: AplicacaoDetailScreen checks the wrong property's role for the estorno action

**File:** `lib/features/sanitario/presentation/aplicacao_detail_screen.dart:82-85`, `125-132`

**Issue:** `AplicacaoDetailScreen` is explicitly documented (and routed) as root-level, reachable
from three different origins including deep links, and its own header comment says every value
must read the frozen row rather than current state. Despite that, `canEdit` — which gates the
"Estornar aplicação" button — is computed from the *currently active* property, not the
*application's own* `propertyId`:

```dart
final currentPropAsync = ref.watch(currentPropertyProvider);
final membersAsync = ref.watch(memberPropertiesProvider);
final canEdit = _canEdit(
  currentPropAsync.asData?.value,
  membersAsync.asData?.value,
);
```

`_canEdit` then filters `members` by `m.property.id == current.id` — `current` is the active
property, not `app.propertyId`. If a user reaches this route for an application that belongs to a
property other than the one currently active (bookmarked URL, browser back/forward after
switching properties, or a link shared between vets on different properties they both belong to),
the button visibility reflects their role on the *wrong* property. The `reverse_sanitary_application`
RPC re-validates `get_role(v_orig.property_id)` server-side, so this cannot be exploited into an
actual unauthorized reversal — but it does mean a reader-on-property-B who happens to be a
veterinarian-on-property-A (currently active) sees an enabled "Estornar" button that will fail
with a generic error, and the inverse case (vet-on-B, reader-on-A active) hides a button they are
actually entitled to use.

**Fix:** Resolve the role against `app.propertyId`, not the active property:

```dart
bool _canEdit(String appPropertyId, List<PropertyMembership>? members) {
  if (members == null) return false;
  final role = members
      .where((m) => m.property.id == appPropertyId)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian';
}
// call site: _canEdit(app.propertyId, membersAsync.asData?.value)
```

### WR-02: Dose dosage field accepts 0, which the database rejects

**File:** `lib/features/sanitario/presentation/dose_form_dialog.dart:220-228`

**Issue:** The dosage validator only checks for blank/unparsable input:

```dart
validator: (v) {
  if (v == null || v.trim().isEmpty) return 'Dosagem (mL/kg) é obrigatória';
  if (_parseDouble(v) == null) return 'Dosagem (mL/kg) é obrigatória';
  return null;
},
```

It never rejects `0` (or `0,0`), but `supabase/migrations/20260810_06_sanitary_module.sql:30`
constrains `dosage_per_kg NOT NULL CHECK (dosage_per_kg > 0)`. A user who types `0` passes client
validation, then hits an opaque server error mapped through `asSanitaryException`'s generic
fallback ("Não foi possível salvar a dose. Verifique os dados e tente novamente.") with no
indication of which field or rule was violated.

**Fix:** Mirror the DB constraint client-side:

```dart
if (_parseDouble(v) == null || _parseDouble(v)! <= 0) {
  return 'Dosagem (mL/kg) deve ser maior que zero';
}
```

### WR-03: SanitaryAnimalSelectionScreen._reload() has no error handling or busy guard

**File:** `lib/features/sanitario/presentation/sanitary_animal_selection_screen.dart:98-113`, `115-136`, `239`

**Issue:** `_reload()` is the D-32/D-33 recovery path fired after the RPC rejects a stale
composition:

```dart
Future<void> _reload() async {
  ref.invalidate(animalListByLotProvider(widget.lotId));
  final fresh = await ref.read(animalListByLotProvider(widget.lotId).future);
  ...
}
```

It has no `try`/`catch`. `_continue()` (lines 115-136) `await`s it without one either, and the
`onPressed` callback that ultimately calls `_continue()` (line 239) is fire-and-forget from the
framework's perspective. If the re-fetch fails (network blip, RLS edge case), the exception
becomes an unhandled async error — no error message is shown, and the screen is left in a
state with no visible feedback that anything happened. There is also no "loading"/disabled state
during `_reload()`, so nothing stops the user from tapping "Continuar" again while the reload is
in flight, which can spawn a second `ResumoAplicacaoDialog` (and a second read of `_selectedIds`)
concurrently with the first reload's `setState` mutating that same set.

**Fix:** Wrap the reload in try/catch with a user-visible SnackBar on failure, and guard the
button against re-entry while a reload is pending (e.g., a `_reloading` flag disabling
"Continuar").

### WR-04: DoseRepository.archiveDose/restoreDose don't verify the update actually matched a row

**File:** `lib/features/sanitario/data/dose_repository.dart:102-115`

**Issue:**

```dart
Future<void> archiveDose(String id) async {
  await _service.client
      .from('doses')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);
}
```

Neither `archiveDose` nor `restoreDose` chains `.select()` or otherwise checks the affected row
count. PostgREST returns 2xx even when RLS silently filters the target row to zero matches — this
is precisely the failure class documented and fixed for the dose UPDATE policy in
`supabase/migrations/20260812_06_fix_dose_update_policy.sql` (G-06-2: "PostgREST answers 2xx
anyway — the silent no-op"). The policy itself is now fixed, but the repository still has no
defense if a future policy regression, a stale id, or a concurrently-deleted dose causes a 0-row
update: `_toggleArchive` in `sanitario_screen.dart` will invalidate providers and report success
even though nothing changed.

**Fix:** Chain `.select().single()` (or check the returned row list is non-empty) and throw when
zero rows are affected, so this failure mode surfaces instead of silently no-op'ing again.

### WR-05: `kgPerUa` resolution logic is copy-pasted verbatim in three files

**File:** `lib/features/sanitario/presentation/dose_form_dialog.dart:94-101` (`_kgPerUa`), `lib/features/sanitario/presentation/resumo_aplicacao_dialog.dart:106-114` (`_resolveKgPerUa`), `lib/features/sanitario/presentation/sanitario_screen.dart:118-125` (`_kgPerUa`)

**Issue:** All three methods are functionally identical — same join through
`currentPropertyProvider` + `propertyListProvider`, same 400 fallback:

```dart
double _kgPerUa() {
  final selected = ref.watch(currentPropertyProvider).asData?.value;
  if (selected == null) return 400;
  final properties = ref.watch(propertyListProvider).asData?.value ?? const [];
  final match = properties.where((p) => p.id == selected.id);
  return match.isNotEmpty ? match.first.kgPerUa : 400;
}
```

Unlike the codebase's documented `_KvRow` duplication (called out explicitly as an accepted
per-file convention, "A-KVROW-DUP"), this is pure lookup logic with no widget-tree coupling — a
natural candidate for a single shared provider or top-level function. Three copies means a future
change to the fallback value or join strategy has to be made (and tested) three times.

**Fix:** Extract to a single `double resolveActiveKgPerUa(WidgetRef ref)` helper (or a derived
Riverpod provider) in a shared location and call it from all three sites.

## Info

### IN-01: Dead `.order()` calls before `.maybeSingle()`

**File:** `lib/features/sanitario/data/sanitary_application_repository.dart:70-80`

**Issue:** `fetchApplication` orders by `applied_at`/`created_at` before calling `.maybeSingle()`
on a query already filtered `.eq('id', id)` — at most one row can ever match, so the ordering is
meaningless (likely copy-pasted from `fetchApplicationsByProperty` above it).

**Fix:** Drop the two `.order()` calls from `fetchApplication`.

### IN-02: Dosage validator error message is misleading for a non-empty invalid value

**File:** `lib/features/sanitario/presentation/dose_form_dialog.dart:220-227`

**Issue:** Both the "blank" and "unparsable" branches return the same message, `'Dosagem (mL/kg)
é obrigatória'` ("required"), even though the second branch is reached only when the field is
non-empty but fails to parse (e.g. `1.2.3`). The wording tells the user the field is missing when
it is actually malformed.

**Fix:** Use a distinct message for the unparsable case, e.g. `'Dosagem (mL/kg) inválida'`.

### IN-03: RPC "not found" vs "forbidden" ordering leaks cross-property object existence

**File:** `supabase/migrations/20260811_06_sanitary_rpcs.sql:39-51` (`register_sanitary_application`), `149-160` (`reverse_sanitary_application`)

**Issue:** Both RPCs resolve the target row (lot, or the application via `SELECT * INTO v_orig`)
*before* checking `is_member_of`. An authenticated user of Property B who passes a Property A
`lot_id`/`application_id` gets `forbidden: not a member of property %` rather than `not found`,
letting them distinguish "this id exists somewhere in the system" from "this id doesn't exist" —
a minor tenant-boundary information leak. This mirrors the pre-existing `register_baixa` pattern
elsewhere in the codebase, so it isn't a regression introduced by this phase, but it's worth
flagging since it's exercised twice more here.

**Fix (optional, low priority):** If tightened, check `is_member_of` using a property_id resolved
without exposing existence (e.g., a single query that returns "not found" uniformly for both
nonexistent and inaccessible rows). Given this matches an established codebase-wide precedent,
treat as a backlog item rather than a phase-blocking fix.

---

_Reviewed: 2026-08-07T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
