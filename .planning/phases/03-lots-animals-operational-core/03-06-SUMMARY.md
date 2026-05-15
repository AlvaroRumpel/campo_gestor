---
phase: 03-lots-animals-operational-core
plan: "06"
subsystem: animais-ui
tags:
  - flutter
  - ui
  - search
  - filters
  - dialog
  - role-gate
  - tdd
dependency_graph:
  requires:
    - "03-03"  # Animal + Lot models, AnimalRepository, providers
    - "03-04"  # Router /animais/:id wired, stub screens
  provides:
    - AnimaisScreen (search + filters + archived toggle)
    - AnimalDetailScreen (full record + vet actions)
    - AnimalEditDialog (breed / EC / observation)
    - BaixaDialog (reason + date soft-delete)
  affects:
    - /animais route (shell branch)
    - /animais/:id route (detail)
tech_stack:
  added: []
  patterns:
    - ConsumerStatefulWidget with Timer debounce (300ms)
    - In-memory filter pipeline on animalListByPropertyProvider
    - SegmentedButton for enum selection (BaixaReason)
    - DateFormat without locale arg to avoid initializeDateFormatting requirement
    - _canEdit helper (veterinarian role gate) matching PaddockDetailScreen pattern
    - Provider override pattern with concrete subclass extending Repository
key_files:
  created:
    - lib/features/animais/presentation/animal_edit_dialog.dart
    - lib/features/animais/presentation/baixa_dialog.dart
  modified:
    - lib/features/animais/presentation/animais_screen.dart
    - lib/features/animais/presentation/animal_detail_screen.dart
    - test/widget/animais_screen_test.dart
    - test/widget/animal_edit_dialog_test.dart
    - test/widget/baixa_dialog_test.dart
decisions:
  - "D-18: filter row order (FilterChips → Lote dropdown → Piquete dropdown) matches UI-SPEC"
  - "D-19: tile primary '#N · Categoria', secondary 'LotName · PaddockName'"
  - "D-20: debounce 300ms via dart:async Timer, cancel on dispose"
  - "D-21: archived toggle off by default; badge labels Vendido/Morto/Descartado"
  - "D-13: AnimalEditDialog edits only breed/EC/observation — number/category immutable"
  - "D-14: kBreeds hardcoded list, stored as text on animal row"
  - "D-16: EC expressed as 1–5 ChoiceChips, deselectable to null"
  - "D-17: BaixaReason enum sale/death/discard → labels Venda/Morte/Descarte"
  - "D-22: DateFormat('dd/MM/yyyy') without locale arg — avoids initializeDateFormatting runtime requirement in tests"
metrics:
  duration_minutes: 45
  completed_date: "2026-05-14"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 5
requirements:
  - ANIM-02
  - ANIM-04
  - ANIM-05
  - ANIM-06
  - PROP-05
---

# Phase 3 Plan 06: Animal UI — Search, Filters, Detail, Edit & Baixa Summary

**One-liner:** AnimaisScreen with 300ms debounce search + 8 filter chips + UA summary bar + archived toggle; AnimalDetailScreen with role-gated edit (AnimalEditDialog) and baixa (BaixaDialog) flows; all three Wave 0 widget-test stubs turned GREEN.

## What Was Built

### Task 1: AnimaisScreen (13 516 bytes)

Replaced the 12-line placeholder with a full `ConsumerStatefulWidget`:

- **SearchBar** — full-width, hint 'Buscar por número...', clear (X) icon when non-empty, 300ms `Timer` debounce (`_onSearchChanged`), `dispose()` cancels timer and disposes controller.
- **Filter row** — `SingleChildScrollView` with 8 `FilterChip`s ('Todas' + 7 from `kCategories`, single-select), `_LotDropdown` (derived from `animalListByPropertyProvider` lot names), `_PaddockDropdown` (from `paddockListProvider`).
- **SummaryBar** — `surfaceContainerHighest` container, 'N animais · UA,U UA total' computed via `calcTotalUa` on the filtered subset.
- **Archived toggle** — 'Mostrar arquivados' `Switch` right-aligned, default off; archived animals get `_ArchiveBadge` chip (Vendido/Morto/Descartado).
- **Two empty states** — 'Nenhum animal cadastrado' (property has no animals) vs 'Nenhum animal encontrado' (filters return zero).
- **List tile** (`_AnimalListTile`) — `Text.rich` primary line `#N` bold + ` · Categoria`, secondary `LotName · PaddockName`; tap routes `context.go(AppRoutes.animalDetail(id))`.

Provider set: `animalListByPropertyProvider` (always fetches active+archived) + `paddockListProvider`.

### Task 2: AnimalDetailScreen (12 479 bytes)

Replaced the Plan 04 stub (kept constructor signature `{required this.animalId}`):

- **AppBar** `'#N — Categoria'` from `animalByIdProvider(animalId)`.
- **AnimalInfoCard** — `surfaceContainerHighest` card with `_KvRow` rows for Número, Categoria, Raça, EC ('X / 5' or '—'), Lote atual (tappable → `/lotes/:id`), Piquete atual (tappable), Cadastrado em (dd/MM/yyyy), Status (green badge 'Ativo' or errorContainer 'Arquivado — Vendido/Morto/Descartado em DD/MM/YYYY').
- **Role-gated footer** — `_canEdit` checks veterinarian role via `memberPropertiesProvider`; shows `OutlinedButton('Editar animal')` always (if vet), `TextButton('Dar baixa', error color)` only when `animal.deletedAt == null` (T-3-22).
- **Two placeholder sections** — `_PlaceholderSection('Histórico Reprodutivo', 'Disponível na Fase 5.')` and `_PlaceholderSection('Histórico Sanitário', 'Disponível na Fase 6.')`.
- **Loading / error / null guards** on `animalByIdProvider` — null renders 'Animal não encontrado.' (T-3-24).

### AnimalEditDialog (5 986 bytes)

- Read-only display rows for Número (`#42`) and Categoria (`Vaca`).
- `DropdownButtonFormField<String?>` with `initialValue: _breed` for Raça (kBreeds + 'Sem raça').
- 5 `ChoiceChip`s for EC (1–5), deselectable to null.
- Multi-line `TextFormField` (`maxLines: 3`) for Observação.
- Submit calls `AnimalRepository.updateAnimal(id, breed, bodyCondition, observation)`, invalidates `animalByIdProvider(id)` and `animalListByPropertyProvider`, pops `true`.
- Error path: SnackBar 'Erro ao salvar animal. Tente novamente.'

### BaixaDialog (5 884 bytes)

- Title `'Confirmar baixa do animal #N?'`.
- Explanation text (italic): 'Esta ação registra o animal como arquivado. O histórico é preservado.'
- `SegmentedButton<BaixaReason>` with Venda / Morte / Descarte, `emptySelectionAllowed: true`.
- Date field (read-only `TextFormField`) with `DateFormat('dd/MM/yyyy')` (no locale arg — avoids `initializeDateFormatting` requirement), calendar `IconButton` suffix calls `showDatePicker`.
- `FilledButton` 'Confirmar baixa' with `backgroundColor: colorScheme.error`.
- Validates `_reason != null` before submit; shows SnackBar 'Selecione o motivo da baixa' on failure.
- Submit calls `AnimalRepository.registerBaixa(id, reason, date, observation)`.

## Wave 0 Test Transitions

| Test file | Tests | Before | After |
|-----------|-------|--------|-------|
| `animais_screen_test.dart` | 10 | all skip: true | GREEN |
| `animal_edit_dialog_test.dart` | 5 | all skip: true | GREEN |
| `baixa_dialog_test.dart` | 5 | all skip: true | GREEN |
| **Total** | **20** | **0 passing** | **20 passing** |

## Decisions Made

| Decision | Detail |
|----------|--------|
| D-13 | AnimalEditDialog edits only breed/EC/observation — Número and Categoria are immutable after creation |
| D-14 | kBreeds hardcoded list (17 breeds), stored as text on animal row, not a DB table |
| D-16 | EC 1–5 as ChoiceChips, deselectable to null (no EC = unknown) |
| D-17 | BaixaReason enum: sale→'Venda', death→'Morte', discard→'Descarte'; DB stores 'sale'/'death'/'discard' |
| D-18 | Filter row order: chips first (horizontal scroll), then Lote dropdown, then Piquete dropdown |
| D-19 | Tile primary '#N · Categoria', secondary 'LotName · PaddockName' (bodyMedium 60% opacity) |
| D-20 | Debounce 300ms via dart:async Timer; cancel in dispose() to prevent setState after unmount |
| D-21 | Archived toggle off by default; Chip badge uses baixaReason DB value for label mapping |
| D-22 | DateFormat('dd/MM/yyyy') without locale — avoids initializeDateFormatting runtime call in widget state constructor |

## Phase 3 SC-1..SC-5 End-to-End Path

| Success Criterion | Plan | Status |
|-------------------|------|--------|
| SC-1: Create lot with animals via RPC | 03-02 (migration) + 03-04 (LoteFormDialog) | Delivered |
| SC-2: List animals per property with context | 03-03 (AnimalRepository) + 03-06 (AnimaisScreen) | Delivered |
| SC-3: Search + filter animals | 03-06 (AnimaisScreen) | Delivered |
| SC-4: Edit animal breed/EC/observation | 03-06 (AnimalEditDialog) | Delivered |
| SC-5: Register baixa with reason + date | 03-06 (BaixaDialog) | Delivered |

All five Phase 3 success criteria have an end-to-end path through Plans 02–06.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DateFormat locale crash in widget tests**
- **Found during:** Task 2 test execution
- **Issue:** `DateFormat('dd/MM/yyyy', 'pt_BR')` in `_BaixaDialogState` field initializer throws `LocaleDataException` in tests because `initializeDateFormatting` hasn't been called.
- **Fix:** Changed to `DateFormat('dd/MM/yyyy')` (no locale arg). The `dd/MM/yyyy` pattern is numeric-only — locale doesn't change its output for date formatting.
- **Files modified:** `lib/features/animais/presentation/baixa_dialog.dart`, `test/widget/baixa_dialog_test.dart`
- **Commit:** dae686f

**2. [Rule 2 - Missing critical functionality] `initialValue` vs deprecated `value` on DropdownButtonFormField**
- **Found during:** Task 2 analysis
- **Issue:** `value:` on `DropdownButtonFormField` is deprecated after Flutter 3.33.0 — should use `initialValue:`.
- **Fix:** Changed to `initialValue: _breed`.
- **Files modified:** `lib/features/animais/presentation/animal_edit_dialog.dart`
- **Commit:** dae686f

**3. [Rule 3 - Blocking] Fake AnimalRepository approach in tests**
- **Found during:** Task 2 test compilation
- **Issue:** Initial `implements AnimalRepository` pattern failed — `AnimalRepository` is a concrete class, not an interface. `super._fake()` constructor doesn't exist.
- **Fix:** Used `extends AnimalRepository` with `super(SupabaseService())` — safe because fake overrides never call `_service`.
- **Files modified:** `test/widget/animal_edit_dialog_test.dart`, `test/widget/baixa_dialog_test.dart`
- **Commit:** dae686f

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| 'Disponível na Fase 5.' | animal_detail_screen.dart | ~85 | Histórico Reprodutivo — planned Phase 5 |
| 'Disponível na Fase 6.' | animal_detail_screen.dart | ~91 | Histórico Sanitário — planned Phase 6 |

These stubs are intentional placeholders — the plan explicitly requires them. They will be replaced in Phases 5 and 6 respectively.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. All DB access routes through existing `AnimalRepository` methods (`updateAnimal`, `registerBaixa`) which were already in scope for T-3-21/T-3-22 in the plan's threat model. Client-side search state never serialized to URL (T-3-23 accepted).

## Self-Check: PASSED

- `lib/features/animais/presentation/animais_screen.dart` — EXISTS, 13 516 bytes (> 6 000 ✓)
- `lib/features/animais/presentation/animal_detail_screen.dart` — EXISTS, 12 479 bytes (> 4 500 ✓)
- `lib/features/animais/presentation/animal_edit_dialog.dart` — EXISTS, 5 986 bytes ✓
- `lib/features/animais/presentation/baixa_dialog.dart` — EXISTS, 5 884 bytes ✓
- Task 1 commit `0a475c1` — EXISTS ✓
- Task 2 commit `dae686f` — EXISTS ✓
- `flutter analyze lib/features/animais` — No issues found ✓
- All 20 Wave 0 widget tests GREEN, zero `skip:` markers ✓
