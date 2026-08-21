# Phase 8: Animal Dossier Consolidation - Pattern Map

**Mapped:** 2026-08-11
**Files analyzed:** 9 (2 new, 7 modified)
**Analogs found:** 9 / 9 (2 with "no precedent, nearest structural analog" flag — see below)

**Delta-phase note:** This phase is 100% Flutter, zero SQL. The dossier screen, both history
sections, and every repository touched already exist and ship in production. Every row below is
either an extraction of already-shipped code or a surgical addition to a shipped file — there is no
greenfield screen or repository in this phase.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` (NEW — extraction) | component | request-response | `lib/features/sanitario/presentation/sanitary_history_section.dart` (`AnimalSanitaryHistorySection`) | exact (explicit precedent named in CONTEXT D-11 and UI-SPEC) |
| `lib/features/lotes/data/lote_repository.dart` (add `fetchLotWithPaddockName` / new provider) | service (repository method) | CRUD (single-row read, PostgREST embed) | `lib/features/animais/data/animal_repository.dart` (`fetchAnimalsByProperty`) for the embed shape; `fetchLotsWithCountByProperty` in the same file for the wrapper-class convention | exact |
| `lib/features/reproducao/data/atf_repository.dart` (`fetchReproductiveHistory`, extend) | service (repository method) | CRUD (read, grouping) | itself (extend in place) — closest sibling pattern is its own existing `lastDgByAtf` grouping loop | exact (self-extension) |
| `lib/features/reproducao/data/atf_model.dart` (`ReproductiveHistoryEntry`, extend) | model | transform | itself (extend fields) — convention precedent is `AtfMembershipView` / `LotWithPaddockCount` (plain wrapper class, not a Supabase row) | exact |
| `lib/features/animais/presentation/animal_detail_screen.dart` (baixa banner, `_KvRow` adaptive, remove Status row, swap in extracted section) | component | request-response | banner: `_EncerrarBanner` in `lib/features/reproducao/presentation/atf_detail_screen.dart`; `_KvRow` breakpoint: `AppShell`'s `LayoutBuilder` in `lib/core/widgets/app_shell.dart` | role-match (banner), partial (LayoutBuilder — different widget shape, same mechanism) |
| `lib/features/sanitario/presentation/sanitary_history_section.dart` (retry button ONLY, D-04) | component | request-response | Riverpod `ref.invalidate(family(id))` pattern — no in-repo retry-button precedent exists yet; this is the first one. Structural analog for "where to put it" is the file's own existing `error:` branch | partial — **new mechanism, first instance in repo** |
| `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` (DG `ExpansionTile`, D-08) | component | request-response | **No `ExpansionTile` anywhere in this codebase** `[CONFIRMED: grep across lib/ found zero matches]` — nearest structural analog is the sanitary section's own `Switch`-driven `setState` toggle (`_showReversed`) for "local UI-only expand/collapse state via plain `setState`, no Riverpod" | no analog — confirmed absent, use stdlib `ExpansionTile` directly per UI-SPEC |
| `lib/features/animais/presentation/animal_detail_screen.dart` (`_KvRow` `LayoutBuilder` breakpoint, D-21) | component | transform | **No width-breakpoint `LayoutBuilder` on a row/leaf widget anywhere in this codebase** `[CONFIRMED: grep found only `app_shell.dart`'s screen-level nav breakpoint]` — nearest analog is `AppShell`'s `LayoutBuilder` (same mechanism, coarser granularity: switches `NavigationRail` vs `NavigationBar` for the whole shell, not a single row) | no analog — confirmed absent, adapt the mechanism, not the widget shape |
| `test/widget/animal_reproductive_history_section_test.dart` and/or extended `animal_detail_screen_test.dart` (360px width harness, D-23) | test | request-response | `test/widget/animal_detail_screen_test.dart` (file layout, provider-override harness) for structure; **no existing test sets `tester.view.physicalSize`** `[CONFIRMED: grep across test/ found zero matches]` | role-match (file layout) / no-analog (physicalSize mechanism) |
| `test/features/lotes/lote_repository_test.dart` (extend with `fetchLotWithPaddockName` contract test) | test | CRUD | itself — shallow "contract test" convention already in file (method-exists assertions via `expect(repo.method, isA<Function>())`) | exact (same file, same convention) |

## Pattern Assignments

### `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` (component, request-response) — NEW FILE

**Analog:** `lib/features/sanitario/presentation/sanitary_history_section.dart`

**Imports pattern** (sanitary_history_section.dart lines 1-9):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_application_repository.dart';
```
Adapt to `reproducao/`: import `atf_model.dart`, `atf_repository.dart`, `dg_record_model.dart`, `../../../core/router/routes.dart`.

**Widget contract — public `ConsumerWidget`, id-only constructor** (sanitary lines 32-40, mirrored per D-37/D-11):
```dart
class AnimalSanitaryHistorySection extends ConsumerStatefulWidget {
  const AnimalSanitaryHistorySection({super.key, required this.animalId});
  final String animalId;
  @override
  ConsumerState<AnimalSanitaryHistorySection> createState() =>
      _AnimalSanitaryHistorySectionState();
}
```
New class: `AnimalReproductiveHistorySection extends ConsumerWidget` (stateless is fine unless D-08's expansion needs `ConsumerStatefulWidget` for a `Set<String> expandedAtfIds` — see Pattern below). Existing `_ReproductiveHistorySection` in `animal_detail_screen.dart` (lines 377-442, current file) is already a `ConsumerWidget` — copy its `build()` body verbatim as the starting point, then layer D-08 expansion on `_ReproductiveHistoryRow` (lines 447-519).

**Card shell to reuse exactly** (already used by both `_ReproductiveHistorySection` today and `_SanitaryHistoryCardShell`):
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
  ),
  color: theme.colorScheme.surface,
  child: Padding(padding: const EdgeInsets.all(16), child: /* ... */),
)
```

**Error handling / empty pattern** (sanitary lines 55-58, mirrored today by `_ReproductiveHistorySection` lines 411-426):
```dart
loading: () => const _SectionSpinner(),
error: (err, st) => const _SectionMessage('Erro ao carregar histórico sanitário.'),
```
D-04 adds a `TextButton` under this `Text` — see Pattern 3 below.

**Move, do not rewrite:** `_ReproductiveHistoryRow` (lines 447-519 of current `animal_detail_screen.dart`) moves into the new file essentially unchanged, gaining only the D-08 `ExpansionTile` wrapper and D-09's bull name / implantation date fields in the summary line.

**Test file placement analog:** `test/widget/animal_detail_screen_test.dart` already overrides `reproductiveHistoryByAnimalProvider` (see its imports of `atf_model.dart`/`atf_repository.dart`, lines 11-13) — when the section is extracted, either move that override + a new `test/widget/animal_reproductive_history_section_test.dart` mirrors the file layout, or keep testing composition through `animal_detail_screen_test.dart` and add a sibling test file for the section's own unit behavior (DG expansion). No existing standalone test file for `sanitary_history_section.dart` was found in the grep sweep — if one exists, it is the layout precedent to copy; otherwise `animal_detail_screen_test.dart`'s provider-override harness (see below) is the only precedent.

---

### `lib/features/lotes/data/lote_repository.dart` — new `fetchLotWithPaddockName` (service, CRUD) (D-01)

**Analog:** `lib/features/animais/data/animal_repository.dart` (`fetchAnimalsByProperty`, lines 68-93) for the embed; `LoteRepository.fetchLotsWithCountByProperty`'s `LotWithPaddockCount` (lines 134-171, 212-220) for the wrapper-class convention.

**Embed pattern to copy verbatim** (`animal_repository.dart` lines 72-74, exact precedent named in CONTEXT.md D-01):
```dart
var query = _service.client
    .from('animals')
    .select('*, lots!inner(name, paddock_id, paddocks!inner(id, name))')
    .eq('property_id', propertyId);
```

**Wrapper-class convention to copy** (`lote_repository.dart` lines 212-220, `LotWithPaddockCount`):
```dart
class LotWithPaddockCount {
  const LotWithPaddockCount({
    required this.lot,
    required this.paddockName,
    required this.activeAnimalCount,
  });
  final Lot lot;
  final String paddockName;
  final int activeAnimalCount;
}
```
New type `LotWithPaddockName` drops `activeAnimalCount`, keeps `lot` + `paddockName`.

**Single-row embed shape** (adapt `fetchLotsWithCountByProperty`'s `paddocks!inner(name)`, lines 138-143, to a single-id `.maybeSingle()` read matching `fetchLot`'s existing single-row style, lines 30-32):
```dart
Future<LotWithPaddockName?> fetchLotWithPaddockName(String id) async {
  final row = await _service.client
      .from('lots')
      .select('*, paddocks!inner(name)')
      .eq('id', id)
      .isFilter('deleted_at', null)
      .maybeSingle();
  if (row == null) return null;
  final paddockJson = row['paddocks'] as Map<String, dynamic>;
  final clean = Map<String, dynamic>.from(row)..remove('paddocks');
  return LotWithPaddockName(lot: Lot.fromJson(clean), paddockName: paddockJson['name'] as String);
}
```

**Provider registration pattern to copy** (`lote_repository.dart` lines 186-190, `loteByIdProvider`):
```dart
final loteByIdProvider =
    FutureProvider.family<Lot?, String>((ref, id) async {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLot(id);
});
```
New: `loteWithPaddockByIdProvider` follows the identical `FutureProvider.family` shape.

**AnimalInfoCard integration point:** replace the two chained watches (`animal_detail_screen.dart` lines 152-156 — `loteByIdProvider` then a derived `paddockByIdProvider(paddockId)`) with a single `ref.watch(loteWithPaddockByIdProvider(animal.lotId))`. This is the exact waterfall this pattern kills.

---

### `lib/features/reproducao/data/atf_repository.dart` §`fetchReproductiveHistory` (service, CRUD) — extend in place (D-10)

**Current code to extend** (atf_repository.dart lines 176-225, already read in full):
```dart
final dgRows = await _service.client
    .from('dg_records')
    .select()
    .eq('animal_id', animalId)
    .order('created_at');
final dgRecords = (dgRows as List)
    .map((r) => DgRecord.fromJson(r as Map<String, dynamic>))
    .toList();

final lastDgByAtf = <String, DgRecord>{};
for (final dg in dgRecords) {
  final current = lastDgByAtf[dg.atfBatchId];
  if (current == null || isLaterDg(dg, current)) {
    lastDgByAtf[dg.atfBatchId] = dg;
  }
}
```
D-10 adds a second grouping pass (additive — do not remove `lastDgByAtf`, it still drives the collapsed-row summary):
```dart
final dgsByAtf = <String, List<DgRecord>>{};
for (final dg in dgRecords) {
  dgsByAtf.putIfAbsent(dg.atfBatchId, () => []).add(dg);
}
// per entry, at construction time:
dgRecords: (dgsByAtf[atfBatchId] ?? const [])
  ..sort((a, b) => b.examDate.compareTo(a.examDate)), // SC-3 desc
```
`bullName`/`implantationDate` (D-09) come from `atf_batches` columns already selected via the joined embed (`atf_batches(id, name, insemination_date, active)`, line 182) — extend that select list to also request `bull_name, implantation_date` (both already exist on `AtfBatch`, see `atf_model.dart` lines 18-19).

---

### `lib/features/reproducao/data/atf_model.dart` §`ReproductiveHistoryEntry` (model) — extend fields (D-09/D-10)

**Current shape** (atf_model.dart lines 65-82, read in full — plain wrapper class, not `@freezed`, matches `AtfMembershipView`'s convention lines 35-56):
```dart
class ReproductiveHistoryEntry {
  const ReproductiveHistoryEntry({
    required this.atfBatchId,
    required this.atfName,
    required this.inseminationDate,
    required this.atfActive,
    required this.lastDgResult,
    required this.lastDgDate,
  });
  final String atfBatchId;
  final String atfName;
  final DateTime inseminationDate;
  final bool atfActive;
  final DgResult? lastDgResult;
  final DateTime? lastDgDate;
}
```
Add `required this.dgRecords, this.bullName, required this.implantationDate` + matching fields (`final List<DgRecord> dgRecords; final String? bullName; final DateTime implantationDate;`). Keep it a plain constructor class — do not convert to `@freezed` (breaks convention; `AtfMembershipView` sets the precedent of "plain class for embedded-select results").

---

### `lib/features/animais/presentation/animal_detail_screen.dart` — baixa banner (component) (D-12/D-13)

**Analog:** `_EncerrarBanner` in `lib/features/reproducao/presentation/atf_detail_screen.dart` (lines 545-609, read in full).

**Styling precedent to copy the shape of, NOT the color role** (lines 576-590):
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: colorScheme.tertiaryContainer,   // <- baixa banner uses errorContainer instead, per D-12/UI-SPEC
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Expanded(child: Text('...', style: theme.textTheme.bodyMedium
          ?.copyWith(color: colorScheme.onTertiaryContainer))),
      // _EncerrarBanner has a TextButton + IconButton(close) here —
      // baixa banner has NEITHER: no action button, no dismiss (UI-SPEC:
      // "this state is informational-about-the-past ... no action button and no dismiss").
    ],
  ),
)
```
Key difference to respect: `_EncerrarBanner` is `StatefulWidget` because it's dismissible (`_dismissed` flag). The baixa banner has no dismiss affordance per UI-SPEC — it can be a plain `StatelessWidget`/inline conditional, not stateful. Use `Icons.info_outline` per UI-SPEC (not `_EncerrarBanner`'s iconless `Row`).

**Data source — already on the model, zero new request** (`animal.deletedAt`, `animal.baixaReason`, `animal.baixaDate`, `animal.observation` already read today at `animal_detail_screen.dart` lines 158, 169-181). The existing reason-label switch (lines 169-174) moves into the banner verbatim — do not duplicate it:
```dart
final reasonLabel = switch (animal.baixaReason) {
  'sale' => 'Vendido',
  'death' => 'Morto',
  'discard' => 'Descartado',
  _ => 'Arquivado',
};
```

**Placement:** first child of the `ListView` (`animal_detail_screen.dart` line 67-69), before `AnimalInfoCard`, with `SizedBox(height: 16)` after — matching the existing `SizedBox(height: 16)` rhythm already used between the two history sections (lines 105, 107).

**Deletion paired with this:** the "Status" `_KvRow` (lines 282-301) and its `statusLabel`/`statusBgColor`/`statusTextColor` local variables (lines 160-181) are removed entirely per D-15 — the reason-label switch moves to the banner, it does not stay duplicated in the card.

---

### `_KvRow` adaptive breakpoint (component, transform) (D-21)

**Analog (mechanism only, different granularity):** `LayoutBuilder` in `lib/core/widgets/app_shell.dart` (line 54-56):
```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final isWide = constraints.maxWidth >= _breakpoint;
    // ... branches into NavigationRail vs NavigationBar shell
  },
);
```
This is the only `LayoutBuilder` in the codebase — confirmed via grep (`lib/core/widgets/app_shell.dart` is the sole match). It operates at the whole-shell level (nav rail vs bottom nav), not on a single row, so it is a "borrow the mechanism, not the widget shape" analog, exactly as RESEARCH.md and UI-SPEC already conclude.

**Current `_KvRow` to modify** (`animal_detail_screen.dart` lines 339-367, read in full):
```dart
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: /* labelMedium, onSurface@0.6 */)),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}
```
Wrap the existing `Row` return in a `LayoutBuilder`, branch at `constraints.maxWidth < 400` per UI-SPEC's locked breakpoint (not "~400px reference" — UI-SPEC calls it locked at exactly `< 400`), producing a `Column` (label above, `SizedBox(height: 2)`, value) below the threshold, keeping the existing `Row` unchanged above it. Full target shape already spelled out in RESEARCH.md Pattern 4 (verified against this exact file/line range) — copy that block directly.

---

### Retry-per-block (component) (D-04) — first instance of this exact widget in the repo

**No in-repo `TextButton`-retry precedent exists yet.** The nearest reusable piece is the Riverpod mechanism itself, already documented and used app-wide for invalidation (e.g., `animal_detail_screen.dart` lines 79, 88, 98 — `ref.invalidate(animalByIdProvider(animalId))` after dialog success, same family-instance-invalidate idiom, just triggered by a different event).

**Target shape** (RESEARCH.md Pattern 3, UI-SPEC Layout Contract "Retry affordance" — both agree on this exact shape):
```dart
error: (err, st) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Erro ao carregar histórico sanitário.', style: /* existing muted style */),
    TextButton(
      onPressed: () => ref.invalidate(sanitaryHistoryByAnimalProvider(widget.animalId)),
      child: const Text('Tentar novamente'),
    ),
  ],
),
```
Apply the identical shape to the reproductive block's `error:` branch with `reproductiveHistoryByAnimalProvider(animalId)`. **Only** the `error:` branches of both `_AnimalSanitaryHistorySectionState.build()` (sanitary_history_section.dart line 57-58) and the new reproductive section change in `sanitary_history_section.dart` — no other line in that file. `AnimalInfoCard`'s lote/piquete rows keep the current silent `'—'` fallback (`animal_detail_screen.dart` lines 224, 252) — no retry UI added there (explicit scope boundary, UI-SPEC Layout Contract + Open Question 2).

---

### DG row expansion (component) (D-08) — confirmed no `ExpansionTile` precedent

**Confirmed via grep:** zero matches for `ExpansionTile` across `lib/`. This is the first use of this Flutter SDK widget in the project. UI-SPEC explicitly mandates using it directly (native Material 3 widget, not a custom `AnimatedSize` toggle) — there is nothing to copy from this codebase for the *widget itself*.

**Nearest structural analog for "local, ephemeral UI toggle state, no Riverpod":** `_AnimalSanitaryHistorySectionState._showReversed` (`sanitary_history_section.dart` lines 42-54) — confirms the codebase convention that expand/collapse-style UI state is plain `ConsumerState`/`setState`, never a Riverpod provider:
```dart
class _AnimalSanitaryHistorySectionState
    extends ConsumerState<AnimalSanitaryHistorySection> {
  bool _showReversed = false;
  // ...
  onShowReversedChanged: (v) => setState(() => _showReversed = v),
}
```
`ExpansionTile` manages its own expand/collapse state internally (no external `setState` needed at all) — simpler than even this analog. Show the chevron only when `entry.dgRecords.length > 1` per UI-SPEC's explicit assumption (record it as an assumption in the plan, per UI-SPEC's own note).

---

### 360px-width widget test harness (test) (D-23) — confirmed no `physicalSize` precedent

**Confirmed via grep:** zero matches for `physicalSize` across `test/`. This is the first width-constrained widget test in the project.

**File-layout analog:** `test/widget/animal_detail_screen_test.dart` (read lines 1-90) — its structure to copy:
```dart
import 'package:campo_gestor/features/animais/presentation/animal_detail_screen.dart';
// ... provider imports
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

final _activeAnimal = Animal(/* ... */);
// sample-data constants at top of file, ProviderScope override builder
// function (`_buildScreen({required animal, required role, ...})`) that
// wires ProviderScope overrides + returns a routed MaterialApp/GoRouter tree.
```
Add the width harness inside individual `testWidgets` bodies (not the shared builder), following the standard Flutter SDK idiom:
```dart
addTearDown(tester.view.resetPhysicalSize);
tester.view.physicalSize = const Size(360, 800);
tester.view.devicePixelRatio = 1.0;
```
This is stdlib `TestWidgetsFlutterBinding`/`FlutterView` API — no new package. Establish it once in whichever test file needs it first (ficha composition test or the extracted reproductive-section test); later plans/phases in this repo can copy the same three lines.

---

### Repository contract tests (test, CRUD) (D-23/D-24) — reuse existing shallow convention

**Analog:** `test/features/lotes/lote_repository_test.dart` (read in full, 92 lines).

**Convention to copy exactly** — method-exists assertions, not full Supabase query-builder mocking (file's own header comment explains why, lines 1-8):
```dart
test('fetchLotsByPaddock returns active lots filtered by paddock_id and ordered by name', () {
  // Contract: method exists and is callable (returns Future).
  expect(repo.fetchLotsByPaddock, isA<Function>());
});
```
Add an identical line for `fetchLotWithPaddockName` in this same file:
```dart
test('fetchLotWithPaddockName exists and is callable (D-01 contract)', () {
  expect(repo.fetchLotWithPaddockName, isA<Function>());
});
```
**Planner note:** do not over-specify test depth here — mocking `.from().select().eq().isFilter().maybeSingle()` chains is explicitly called "brittle" in this file's own header comment and RESEARCH.md Pitfall 3. The contract-test line above is the entire scope for this file. Same applies to any extension of `test/features/reproducao/atf_repository_test.dart` for the `dgRecords` field — check current coverage first, extend only with a contract-level assertion if the method signature changes, not a full-payload mock.

---

## Shared Patterns

### Riverpod family-instance invalidation (retry, D-04)
**Source:** `animal_detail_screen.dart` lines 79/88/98 (`ref.invalidate(animalByIdProvider(animalId))`)
**Apply to:** `sanitary_history_section.dart` error branch, new reproductive section error branch
```dart
ref.invalidate(<providerFamily>(<id>)); // family instance, never the bare family
```

### Outlined-card section shell
**Source:** shared by `_ReproductiveHistorySection` (current `animal_detail_screen.dart` 389-396) and `_SanitaryHistoryCardShell` (`sanitary_history_section.dart` 251-258) — byte-identical shape
**Apply to:** the new `AnimalReproductiveHistorySection` file (copy verbatim, do not restyle)

### pt-BR date formatting
**Source:** `DateFormat('dd/MM/yyyy', 'pt_BR')` used throughout `animal_detail_screen.dart`; `sanitary_history_section.dart` uses the numeric-only `DateFormat('dd/MM/yyyy')` without locale symbols (comment at line 11-13 explains why — no locale symbol data needed for a purely numeric pattern)
**Apply to:** any new date formatting in the extracted reproductive section / banner

### Plain wrapper class for PostgREST embedded-select results
**Source:** `AtfMembershipView` (`atf_model.dart` 35-56), `LotWithPaddockCount` (`lote_repository.dart` 212-220), `AnimalWithContext` (referenced in `animal_repository.dart`)
**Apply to:** new `LotWithPaddockName` class — plain constructor class, not `@freezed`, not a Supabase row

## No Analog Found

| File/Concern | Role | Data Flow | Reason |
|---|---|---|---|
| `ExpansionTile` usage (D-08) | component (interaction) | request-response | Confirmed via grep: zero uses anywhere in `lib/`. First use of this stdlib Material 3 widget in the project. UI-SPEC mandates it directly — no in-repo analog needed, this is intentional first-adoption of a native widget, not a gap. |
| Row-level `LayoutBuilder` breakpoint (D-21) | component (layout) | transform | Confirmed via grep: only one `LayoutBuilder` exists in `lib/` (`app_shell.dart`, whole-shell nav breakpoint). No row/leaf-widget breakpoint precedent. Borrow the *mechanism* from `app_shell.dart`, not the widget composition — RESEARCH.md Pattern 4 already supplies the exact target code. |
| `tester.view.physicalSize` widget-test harness (D-23) | test | request-response | Confirmed via grep: zero matches in `test/`. First width-constrained widget test in the project. This is a 3-line stdlib `TestWidgetsFlutterBinding`/`FlutterView` addition, not a new package — see the "360px-width widget test harness" section above for the exact lines to add. |
| Retry `TextButton` widget itself (D-04) | component | request-response | No existing retry-button widget in the codebase (the only retry mechanism today is app-wide auto-retry via `providerRetryPolicy` in `main.dart`, which never surfaces UI). The *pattern* (Riverpod `ref.invalidate(family(id))`) is well-established; only the visible button is new — trivial, not a gap worth flagging as risk. |

## Hard Boundaries (do not plan work into these)

- **D-37 (Phase 6 contract), reaffirmed for Phase 8:** `lib/features/sanitario/presentation/sanitary_history_section.dart` — the ONLY permitted edit this phase is adding the D-04 retry `TextButton` inside the two existing `error:` branches (`_AnimalSanitaryHistorySectionState.build()` line ~57-58, `_LoteSanitaryHistorySectionState.build()` line ~121-123). `_buildAnimalRow`, `_buildLoteRow`, `visibleApplications`, `reversedApplicationIds`, `_SanitaryHistoryCardShell`, `_HistoryRowShell`, `sanitaryHistoryByAnimalProvider` and its repository method are locked — no query change, no restyle, no "make it consistent with the new reproductive block" pass. A diff touching `sanitary_application_repository.dart` in this phase is out of scope by definition (zero SQL, zero migrations).
- **No plan for "apply migration" or pgTAP** — this phase has no `supabase/` changes at all (D-23, D-24, confirmed by CONTEXT.md "Fase 100% Flutter").
- **No network-call-count automated test** — SC-1 evidence is the D-07 manual UAT with DevTools "Fast 4G" throttle; do not plan an automated request-counting test (RESEARCH.md Pitfall 3 — this project's repository tests are deliberately shallow contract tests, not full query-builder mocks).

## Metadata

**Analog search scope:** `lib/features/animais/`, `lib/features/reproducao/`, `lib/features/sanitario/`, `lib/features/lotes/`, `lib/core/widgets/`, `test/widget/`, `test/features/lotes/`
**Files scanned:** 12 read in full or targeted range (animal_detail_screen.dart, sanitary_history_section.dart, atf_model.dart, atf_repository.dart, animal_repository.dart, lote_repository.dart, atf_detail_screen.dart §_EncerrarBanner, lote_repository_test.dart, animal_detail_screen_test.dart, app_shell.dart §LayoutBuilder) + 4 grep sweeps (ExpansionTile/LayoutBuilder/physicalSize across lib/ and test/)
**Pattern extraction date:** 2026-08-11
