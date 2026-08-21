---
phase: 03-lots-animals-operational-core
plan: 04
subsystem: lots-ui
tags:
  - flutter
  - ui
  - routing
  - dialog
  - role-gate
  - tdd
dependency_graph:
  requires:
    - "03-03: LoteRepository, AnimalRepository, lote_model, animal_constants"
    - "03-02: lots table migration, create_lot_with_animals RPC"
  provides:
    - "AppRoutes.loteById, loteDetail(), animalDetail() helpers"
    - "GoRoute /lotes/:loteId (root-level, D-03)"
    - "GoRoute /animais/:id (nested under /animais shell branch)"
    - "LoteFormDialog: batch create + edit-name modes"
    - "LotsSection: lots list with empty state + LotCard"
    - "PaddockDetailScreen: expanded with info card + lots section + FAB"
    - "LoteDetailScreen stub (Plan 05 fills)"
    - "AnimalDetailScreen stub (Plan 06 fills)"
  affects:
    - "lib/core/router/router.dart"
    - "lib/core/router/routes.dart"
    - "lib/features/piquetes/presentation/paddock_detail_screen.dart"
tech_stack:
  added: []
  patterns:
    - "AlertDialog pattern with SizedBox(480) content — same as PaddockFormDialog"
    - "_canEdit(SelectedProperty?, List<PropertyMembership>?) private helper — copied from PiquetesScreen"
    - "AnimalNumberConflictException typed catch — surfaces e.message as SnackBar"
    - "ref.invalidate(loteListByPaddockProvider(paddockId)) after create/update"
key_files:
  created:
    - lib/core/router/routes.dart (modified — Phase 3 constants added)
    - lib/features/lotes/presentation/lote_detail_screen.dart
    - lib/features/animais/presentation/animal_detail_screen.dart
    - lib/features/lotes/presentation/lote_form_dialog.dart
    - lib/features/lotes/presentation/_lots_section.dart
  modified:
    - lib/core/router/router.dart
    - lib/features/piquetes/presentation/paddock_detail_screen.dart
    - test/widget/lote_form_dialog_test.dart
decisions:
  - "Lot-card subtitle is 'Toque para ver composição' (placeholder) — composition counts deferred to Plan 05 when LoteDetailScreen wires animalListByLotProvider per lot"
  - "LotsSection named public (not _LotsSection) because Dart cannot export underscore-prefixed classes across files — imported from paddock_detail_screen.dart"
  - "DropdownButtonFormField uses initialValue (not deprecated value) per Flutter 3.33+ API"
  - "build_runner run to generate lote_model.freezed.dart + animal_model.freezed.dart (gitignored, must run locally after checkout)"
metrics:
  duration_minutes: ~35
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 5
  files_modified: 3
---

# Phase 03 Plan 04: Routing + LoteFormDialog + PaddockDetailScreen Expansion Summary

**One-liner:** Root `/lotes/:loteId` GoRoute + nested `/animais/:id` sub-route wired; batch creation dialog ships with 7 category rows, breed dropdowns, role-gated FAB on expanded PaddockDetailScreen; 5 Wave-0 widget tests turned GREEN.

---

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Wire routes + create stub detail screens | b630f9f | routes.dart, router.dart, lote_detail_screen.dart, animal_detail_screen.dart |
| 2 | LoteFormDialog + LotsSection + expanded PaddockDetailScreen + tests GREEN | a3ffb73 | lote_form_dialog.dart, _lots_section.dart, paddock_detail_screen.dart, lote_form_dialog_test.dart |

---

## Routes Added

| Route | Type | File:Line | Notes |
|-------|------|-----------|-------|
| `/lotes/:loteId` | Root GoRoute (before StatefulShellRoute) | router.dart ~131 | D-03: accessible from any context |
| `/animais/:id` | Sub-route inside `/animais` shell branch | router.dart ~164 | Nested — preserves shell navigation state |

**AppRoutes constants added:**
- `AppRoutes.lotes = '/lotes'`
- `AppRoutes.loteById = '/lotes/:loteId'` (GoRoute template)
- `AppRoutes.animalById = ':id'` (relative sub-route)
- `AppRoutes.loteDetail(String id)` → `'/lotes/$id'`
- `AppRoutes.animalDetail(String id)` → `'/animais/$id'`

---

## LoteFormDialog Behavior

**Create mode** (`existing == null`):
- Title: 'Novo lote'
- Name TextFormField (autofocus, required — 'Nome do lote é obrigatório')
- Section label 'Animais por categoria' (titleMedium)
- 7 `_CategoryCompositionRow` widgets — one per `kCategories` entry (vaca → novilho)
  - Each row: label | decrement | qty display | increment | breed DropdownButtonFormField (7 breeds + null option)
  - Min touch target 44×44px per UI-SPEC
- 'Iniciar do número' optional TextFormField (hint: 'Ex: 101 (deixe vazio para auto)', digitsOnly)
- Validation: name required; on submit if total qty == 0 → SnackBar 'Informe ao menos 1 animal...'
- Submit: calls `LoteRepository.createLotWithAnimals` → `ref.invalidate(loteListByPaddockProvider(paddockId))` → `Navigator.pop(context, true)`
- AnimalNumberConflictException → SnackBar with `e.message`
- Generic exception → SnackBar 'Não foi possível criar o lote. Verifique os dados e tente novamente.'
- During save: `LinearProgressIndicator` replaces title; `CircularProgressIndicator(strokeWidth:2)` in FilledButton

**Edit mode** (`existing != null`, D-12):
- Title: 'Editar lote'
- Only name field shown — composition rows and start-number field are HIDDEN
- Submit: calls `LoteRepository.updateLotName` → invalidate → pop

---

## PaddockDetailScreen Layout Change

**Before (Plan 03-03):** Simple ListView with 3 ListTiles (nome, área, capacidade).

**After (Plan 03-04):**
```
AppBar: 'Piquete'
Body (ListView):
  ├── _PaddockInfoCard (Card with 3 ListTiles — same pt-BR formatting)
  ├── SizedBox(8)
  ├── Padding(horizontal:16) Text('Lotes', titleMedium)
  ├── SizedBox(4)
  └── LotsSection(paddockId, canEdit, propertyId)
FAB: FloatingActionButton('Novo lote') — visible only when canEdit (veterinarian role)
```

`_canEdit` logic: copied verbatim from `PiquetesScreen` — checks `role == 'veterinarian'` for the active property.

---

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `subtitle: const Text('Toque para ver composição')` | `lib/features/lotes/presentation/_lots_section.dart` | ~130 | Composition counts (X vacas · Y UA) require per-lot animal data from `animalListByLotProvider`. Will be wired in Plan 05 when `LoteDetailScreen` provides the data. Using N queries per lot card in a list causes N+1 issues — deferring to Plan 05 which owns the detail screen and can optimize. |

---

## Test Transitions

`test/widget/lote_form_dialog_test.dart` — 5 tests, all `skip: true` → all GREEN:

| Test | Before | After |
|------|--------|-------|
| renders 7 category counter rows | skip | PASS |
| rejects submit when name is empty | skip | PASS |
| rejects submit when sum == 0 | skip | PASS |
| shows "Iniciar do número" field | skip | PASS |
| shows raça dropdown per category row | skip | PASS |

---

## Decision References

- **D-01:** Lots live inside PaddockDetailScreen, no standalone lots listing page
- **D-02:** PaddockDetailScreen layout: info card top, lots section below, FAB role-gated
- **D-03:** `/lotes/:loteId` = root-level GoRoute (not nested under /piquetes) — accessible from any context
- **D-09:** Optional "Iniciar do número" in batch form — auto-generates from MAX+1 if empty
- **D-10:** 7 always-visible category rows in create form
- **D-11:** name required + total > 0 enforced client-side (RPC also validates server-side)
- **D-12:** Edit mode shows only name field — composition immutable after creation

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing freezed/json_serializable generated files**
- **Found during:** Task 2 — flutter analyze reported `uri_does_not_exist` for `lote_model.freezed.dart` and `animal_model.freezed.dart`
- **Issue:** Generated files are gitignored and were missing in the worktree. Worktree was branched from an older commit that predated 03-03's codegen output.
- **Fix:** Ran `dart run build_runner build` in the worktree — generated `lote_model.freezed.dart`, `lote_model.g.dart`, `animal_model.freezed.dart`, `animal_model.g.dart`, and the piquete variants.
- **Files modified:** `lib/features/lotes/data/lote_model.freezed.dart`, `lote_model.g.dart`, `lib/features/animais/data/animal_model.freezed.dart`, `animal_model.g.dart` (gitignored — not committed)

**2. [Rule 1 - Bug] DropdownButtonFormField `value` deprecated**
- **Found during:** Task 2 — flutter analyze info warning `deprecated_member_use` on `value:` param
- **Issue:** `DropdownButtonFormField.value` deprecated in Flutter 3.33.0+ in favor of `initialValue`
- **Fix:** Changed `value: breed` → `initialValue: breed` in `_CategoryCompositionRow`
- **Files modified:** `lib/features/lotes/presentation/lote_form_dialog.dart`

**3. [Rule 1 - Bug] Underscore lambda parameters trigger lint warnings**
- **Found during:** Task 2 — `unnecessary_underscores` and `no_leading_underscores_for_local_identifiers` info warnings
- **Fix:** Replaced `(_, __) =>` with named params `(err, st) =>` and `(ctx, idx) =>` in separatorBuilder callbacks
- **Files modified:** `lib/features/lotes/presentation/_lots_section.dart`, `lib/features/piquetes/presentation/paddock_detail_screen.dart`

---

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| (none) | — | No new network endpoints introduced. All data access flows through existing LoteRepository/AnimalRepository. Role gate (FAB/popup absent for non-veterinarians) implemented per T-3-13. Generic error catch prevents DB stack traces leaking via SnackBar (T-3-15). |

---

## Self-Check: PASSED

Files created/modified:
- [x] `lib/core/router/routes.dart` — EXISTS
- [x] `lib/core/router/router.dart` — EXISTS  
- [x] `lib/features/lotes/presentation/lote_detail_screen.dart` — EXISTS
- [x] `lib/features/animais/presentation/animal_detail_screen.dart` — EXISTS
- [x] `lib/features/lotes/presentation/lote_form_dialog.dart` — EXISTS
- [x] `lib/features/lotes/presentation/_lots_section.dart` — EXISTS
- [x] `lib/features/piquetes/presentation/paddock_detail_screen.dart` — EXISTS
- [x] `test/widget/lote_form_dialog_test.dart` — EXISTS (5 tests GREEN)

Commits verified:
- [x] b630f9f — feat(03-04): wire routes + stub screens
- [x] a3ffb73 — feat(03-04): LoteFormDialog + LotsSection + expanded PaddockDetailScreen
