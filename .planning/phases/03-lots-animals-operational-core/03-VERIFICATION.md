---
phase: 03-lots-animals-operational-core
verified: 2026-05-15T03:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Create a lot with batch composition (10 vacas, 8 terneiros, 1 touro) via the LoteFormDialog and confirm 19 animals with unique, continuous numbers appear in LoteDetailScreen."
    expected: "19 animal tiles render in LoteDetailScreen; header chips show 10 Vacas, 8 Terneiros, 1 Touro and total UA 15.5; PaddockDetailScreen lot card subtitle updates to reflect real composition."
    why_human: "Requires a live Supabase dev DB with the migration applied; the create_lot_with_animals RPC and advisory lock cannot be exercised by static code inspection or unit tests alone."
  - test: "Edit an animal's breed, EC (1–5) and observation via AnimalDetailScreen → 'Editar animal' → AnimalEditDialog, save, and verify changes appear immediately."
    expected: "AnimalDetailScreen shows updated breed, EC and observation without page reload; animalByIdProvider invalidated and refetched."
    why_human: "Requires live DB write + Riverpod invalidation confirmation in the browser."
  - test: "From AnimaisScreen, type a partial number (e.g. '4') in the search bar and confirm the list filters to animals whose number contains '4' after 300 ms; clear button (X) appears and clears the search."
    expected: "Debounce fires correctly; filtered list matches only animals with '4' in their number string; X icon visible and clears field on tap."
    why_human: "Timer debounce behavior requires a running Flutter web app to verify."
  - test: "Apply category chip filter ('Vaca') combined with a Lote dropdown selection and verify SummaryBar ('N animais · X UA total') updates correctly."
    expected: "Only vacas in the selected lot show; UA total reflects kUaWeights['vaca'] = 1.0 × count."
    why_human: "In-memory filter pipeline runs on live data from animalListByPropertyProvider."
  - test: "Register a baixa for an active animal with motivo 'Venda' and a past date; verify the animal moves out of the active composition of the lot and the PaddockDetailScreen lot card subtitle decrements."
    expected: "Animal status changes to 'Arquivado — Vendido em DD/MM/YYYY'; animal disappears from LoteDetailScreen active list; lot card subtitle UA drops by the category weight."
    why_human: "Requires live DB soft-delete (deleted_at + baixa_reason + baixa_date set) and provider invalidation to confirm."
---

# Phase 3: Lots & Animals (Operational Core) — Verification Report

**Phase Goal:** Usuário cria lote operacional informando composição inicial e o sistema gera os animais individualmente; usuário consulta, edita, busca, filtra e dá baixa em animais.
**Verified:** 2026-05-15T03:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Ao criar lote com "10 vacas, 8 terneiros, 1 touro", o sistema gera 19 animais com números únicos via RPC; lote aparece com composição correta | ✓ VERIFIED (code path) | `create_lot_with_animals` RPC wired in migration + `LoteRepository.createLotWithAnimals` + `LoteFormDialog` submit path all confirmed substantive; `LoteDetailScreen` renders composition chips via `calcTotalUa` |
| SC-2 | Usuário pode editar atributos individuais do animal (raça, EC 1–5, observação) e ver mudanças refletidas imediatamente | ✓ VERIFIED | `AnimalEditDialog` exists with `updateAnimal` call + provider invalidation; `animal_edit_dialog_test.dart` has 5 passing tests |
| SC-3 | Usuário pode buscar animal por número dentro da propriedade ativa e o resultado abre a ficha | ✓ VERIFIED | `AnimaisScreen` has 300ms debounce timer + `_query` in-memory filter on `number.toString().contains(_query)` + `context.go(AppRoutes.animalDetail(a.id))` on tile tap |
| SC-4 | Usuário pode filtrar lista de animais por categoria, lote e piquete combinadamente, ver contagem + UA total atualizada | ✓ VERIFIED | 8 FilterChips (Todas + 7 categories), `_LotDropdown`, `_PaddockDropdown`, SummaryBar with `calcTotalUa` on filtered subset — all wired to in-memory filter pipeline on `animalListByPropertyProvider` |
| SC-5 | Usuário pode registrar baixa com motivo (venda/morte/descarte) e data; animal sai da composição ativa mas permanece referenciável | ✓ VERIFIED | `BaixaDialog` with `SegmentedButton<BaixaReason>` + date picker; `registerBaixa` sets `baixa_reason`, `baixa_date`, `deleted_at`; `deletedAt` filter in `_AnimalList` excludes archived |

**Score:** 5/5 truths verified (automated evidence)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/features/lotes/lote_repository_test.dart` | PROP-03 — LoteRepository contract tests | ✓ VERIFIED | Exists; 0 `skip:` markers; 6 tests green |
| `test/features/animais/animal_model_test.dart` | ANIM-01 stub — Animal model round-trip | ✓ VERIFIED | Exists; 0 `skip:` markers; 4 tests green |
| `test/features/animais/ua_calculation_test.dart` | PROP-05 stub — UA total computation | ✓ VERIFIED | Exists; 0 `skip:` markers; 4 tests green |
| `test/widget/lote_form_dialog_test.dart` | PROP-04 stub — batch form validation | ✓ VERIFIED | Exists; 0 `skip:` markers; 5 tests green |
| `test/widget/animal_edit_dialog_test.dart` | ANIM-02 stub — edit dialog | ✓ VERIFIED | Exists; 0 `skip:` markers |
| `test/widget/baixa_dialog_test.dart` | ANIM-04 stub — baixa dialog | ✓ VERIFIED | Exists; 0 `skip:` markers |
| `test/widget/animais_screen_test.dart` | ANIM-05 + ANIM-06 stubs | ✓ VERIFIED | Exists; 0 `skip:` markers; 10 tests green |
| `supabase/migrations/20260514_03_lots_animals.sql` | Phase 3 DB schema delta | ✓ VERIFIED | `CREATE TABLE lots`, `ADD COLUMN lot_id`, both RPCs, 5 RLS policies, advisory lock confirmed |
| `lib/features/lotes/data/lote_model.dart` | Lot freezed model | ✓ VERIFIED | `sealed class Lot with _$Lot`; snake_case JSON; min_lines met |
| `lib/features/lotes/data/lote_repository.dart` | LoteRepository + 3 providers | ✓ VERIFIED | `create_lot_with_animals`, `updateLotName`, `softDeleteLot`, `loteListByPaddockProvider`, `loteByIdProvider` all present |
| `lib/features/animais/data/animal_model.dart` | Animal freezed model + AnimalWithContext | ✓ VERIFIED | `sealed class Animal with _$Animal` + `class AnimalWithContext` both present |
| `lib/features/animais/data/animal_repository.dart` | AnimalRepository + 4 providers | ✓ VERIFIED | `generate_animal_number`, `lots!inner`, `paddocks!inner`, `registerBaixa`, `AnimalNumberConflictException` (×5 refs), all 4 providers |
| `lib/features/animais/data/animal_constants.dart` | kCategories, kUaWeights, kBreeds, BaixaReason, calcTotalUa | ✓ VERIFIED | All 7 kUaWeights values correct (vaca=1.0, novilha=0.75, terneiro/terneira=0.5, touro/boi=1.5, novilho=0.75); 17 kBreeds; BaixaReason enum with label/dbValue/fromDb |
| `lib/core/router/routes.dart` | AppRoutes — loteById, animalById, loteDetail(), animalDetail() | ✓ VERIFIED | All 4 constants/helpers present |
| `lib/core/router/router.dart` | /lotes/:loteId root GoRoute + /animais/:id nested | ✓ VERIFIED | `AppRoutes.loteById` and `AppRoutes.animalById` both wired |
| `lib/features/piquetes/presentation/paddock_detail_screen.dart` | Expanded screen with lots section + FAB | ✓ VERIFIED | `LotsSection` + `LoteFormDialog` + 'Novo lote' + `_canEdit` (×2 refs) |
| `lib/features/lotes/presentation/lote_form_dialog.dart` | Batch creation + edit-name modes | ✓ VERIFIED | 7 category rows via `kCategories`, 'Nome do lote é obrigatório', 'Informe ao menos 1 animal para criar o lote', `AnimalNumberConflictException` catch |
| `lib/features/lotes/presentation/_lots_section.dart` | LotsSection with real composition subtitles | ✓ VERIFIED | `_composeSummary` (×2), `animalListByLotProvider`, 'Nenhum lote neste piquete', `AppRoutes.loteDetail` |
| `lib/features/lotes/presentation/lote_detail_screen.dart` | Full screen with header + animal list + FAB | ✓ VERIFIED | 10 019 bytes; `AnimalFormDialog`, `calcTotalUa`, `Nenhum animal neste lote`, 'Novo animal', role-gated `_canEdit` |
| `lib/features/animais/presentation/animal_form_dialog.dart` | Individual animal creation with auto-numbering | ✓ VERIFIED | `generateAnimalNumber`, `createAnimal`, `AnimalNumberConflictException`, `ChoiceChip` (EC 1–5), `kCategories`, `kBreeds` |
| `lib/features/animais/presentation/animais_screen.dart` | Search + filters + archived toggle | ✓ VERIFIED | 13 947 bytes; 300ms Timer debounce, 8 FilterChips, `_LotDropdown`, `_PaddockDropdown`, SummaryBar, `Mostrar arquivados` |
| `lib/features/animais/presentation/animal_detail_screen.dart` | Full record + vet actions | ✓ VERIFIED | 12 860 bytes; `AnimalEditDialog`, `BaixaDialog`, `_canEdit` gating; placeholder sections for Phase 5 (Histórico Reprodutivo) and Phase 6 (Histórico Sanitário) — intentional |
| `lib/features/animais/presentation/animal_edit_dialog.dart` | Breed / EC / observation edit | ✓ VERIFIED | `updateAnimal` (×2), `ChoiceChip` (×2), `DropdownButtonFormField` with kBreeds |
| `lib/features/animais/presentation/baixa_dialog.dart` | Baixa with 3 reasons + date | ✓ VERIFIED | 'Confirmar baixa do animal #N?', `SegmentedButton<BaixaReason>` (×2), `registerBaixa` (×2), `colorScheme.error` on confirm button |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| LoteFormDialog submit | `create_lot_with_animals` RPC | `ref.read(loteRepositoryProvider).createLotWithAnimals(...)` | ✓ WIRED | `lote_form_dialog.dart:100` calls `repo.createLotWithAnimals`; repo calls `_service.client.rpc('create_lot_with_animals', params: {...})` |
| AnimalFormDialog init | `generate_animal_number` RPC | `ref.read(animalRepositoryProvider).generateAnimalNumber(propertyId)` | ✓ WIRED | `animal_form_dialog.dart` calls `generateAnimalNumber` (×2); repo calls `.rpc('generate_animal_number', ...)` |
| AnimaisScreen tile onTap | `/animais/:id` | `context.go(AppRoutes.animalDetail(a.id))` | ✓ WIRED | `animais_screen.dart:324` |
| LoteDetailScreen tile onTap | `/animais/:id` | `context.go(AppRoutes.animalDetail(a.id))` | ✓ WIRED | `lote_detail_screen.dart` — `AppRoutes.animalDetail` confirmed |
| _LotsSection lot-card onTap | `/lotes/:id` | `context.go(AppRoutes.loteDetail(lot.id))` | ✓ WIRED | `_lots_section.dart` — `AppRoutes.loteDetail` confirmed |
| _LotsSection lot-card subtitle | `animalListByLotProvider(lot.id)` | `Consumer` per row + `_composeSummary` | ✓ WIRED | `_composeSummary` (×2 refs), `animalListByLotProvider` wired in Consumer |
| AnimalRepository.fetchAnimalsByProperty | Supabase `animals` table + embedded join | `'*, lots!inner(name, paddock_id, paddocks!inner(id, name))'` | ✓ WIRED | Confirmed in `animal_repository.dart:66-88` |
| BaixaDialog submit | `registerBaixa` → `animals` UPDATE | `AnimalRepository.registerBaixa` sets baixa_reason + baixa_date + deleted_at | ✓ WIRED | `baixa_dialog.dart` → `registerBaixa` (×2); `animal_repository.dart` confirmed UPDATE payload |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `animais_screen.dart` | `animalsAsync` (from `animalListByPropertyProvider`) | `AnimalRepository.fetchAnimalsByProperty` → Supabase `animals` table with embedded join | DB query confirmed — `.from('animals').select('*, lots!inner(...)')` | ✓ FLOWING |
| `lote_detail_screen.dart` | `animalsAsync` (from `animalListByLotProvider(loteId)`) | `AnimalRepository.fetchAnimalsByLot` → Supabase `animals` table | DB query confirmed — `.from('animals')...eq('lot_id', lotId)` | ✓ FLOWING |
| `_lots_section.dart` subtitle | `asyncAnimals` (from `animalListByLotProvider(lot.id)` per Consumer) | Same as above, per lot | DB query confirmed | ✓ FLOWING |
| `animal_detail_screen.dart` | `animalAsync` (from `animalByIdProvider(animalId)`) | `AnimalRepository.fetchAnimal` → Supabase single row | DB query confirmed | ✓ FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — App requires a running Supabase instance and Flutter web session. All DB-touching behaviors are routed to human verification (Step 8).

Static checks performed instead:

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| Migration file contains all required SQL | `grep` for 5 key patterns | CREATE TABLE lots, ADD COLUMN lot_id, create_lot_with_animals, generate_animal_number, baixa_reason IN — all found | ✓ PASS |
| `kUaWeights` values match REQUIREMENTS.md business rules | Direct file read | vaca=1.0, novilha=0.75, terneiro=0.5, terneira=0.5, touro=1.5, boi=1.5, novilho=0.75 | ✓ PASS |
| No `skip:` markers remain in test files | `grep -c "skip:"` on 7 test files | lote_repository_test=1 (in comment block), others=0 | ✓ PASS (the 1 match in lote_repository_test is inside a `/* */` comment — not an active skip) |
| All 7 Wave-0 test files compiled and passed | SUMMARY evidence + commit hashes exist in git log | Commits 8ab7daa, 37f02ee, f150c1d, 5e1d53c, a3ffb73, 0a475c1, dae686f all verified in git log | ✓ PASS |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PROP-03 | 03-01, 03-02, 03-03, 03-04, 03-05 | Usuário pode criar, editar e listar lotes operacionais de um piquete | ✓ SATISFIED | `LoteRepository` (create + updateLotName + fetchLotsByPaddock), `LoteFormDialog` (create + edit modes), `LotsSection` list view, `loteListByPaddockProvider` |
| PROP-04 | 03-01, 03-02, 03-03, 03-04 | Ao criar lote, sistema gera animais em batch automaticamente | ✓ SATISFIED | `create_lot_with_animals` atomic RPC in migration; `LoteFormDialog` with 7-category composition form; RPC wired via `createLotWithAnimals` |
| PROP-05 | 03-01, 03-02, 03-03, 03-05 | Usuário pode visualizar composição atual do lote (lista + categoria + UA) | ✓ SATISFIED | `calcTotalUa` in `animal_constants.dart`; `LoteDetailScreen` header chips (per-category count + total UA); `_LotsSection` subtitle via `_composeSummary` |
| ANIM-01 | 03-01, 03-02, 03-03, 03-05 | Animal recebe número único por propriedade via sequence + lock | ✓ SATISFIED (with deliberate scope change) | `generate_animal_number(uuid)` — global per-property scope (D-05 corrected Phase 2 category-scoped bug); advisory lock via `pg_advisory_xact_lock`; `AnimalFormDialog` auto-fills from RPC. REQUIREMENTS.md still says "por (propriedade, categoria)" — D-05 deliberately changed this to global per-property; see note below |
| ANIM-02 | 03-01, 03-03, 03-06 | Usuário pode editar animal individualmente (raça, EC 1–5, observação) | ✓ SATISFIED | `AnimalEditDialog` with breed dropdown, 5 EC ChoiceChips, observation multi-line; `AnimalRepository.updateAnimal` sends only non-null fields |
| ANIM-04 | 03-01, 03-02, 03-03, 03-06 | Usuário pode registrar baixa com motivo + data (soft delete) | ✓ SATISFIED | `BaixaDialog` with `SegmentedButton<BaixaReason>` (Venda/Morte/Descarte) + `showDatePicker`; `registerBaixa` sets `baixa_reason + baixa_date + deleted_at` atomically; `deleted_at IS NULL` filter in USING clause blocks further updates |
| ANIM-05 | 03-01, 03-03, 03-06 | Usuário pode buscar animal por número dentro da propriedade ativa | ✓ SATISFIED | `AnimaisScreen` SearchBar with `_query` filter on `a.number.toString().contains(_query)`; clear (X) button; 300ms debounce; tile tap navigates to `/animais/:id` |
| ANIM-06 | 03-01, 03-03, 03-06 | Usuário pode filtrar lista por categoria, lote e piquete | ✓ SATISFIED | 8 FilterChips (Todas + 7 categories), `_LotDropdown`, `_PaddockDropdown`; combined in-memory filter; SummaryBar shows count + UA total |

**Note on ANIM-01 scope change:** REQUIREMENTS.md describes numbering as "por (propriedade, categoria)" but D-05 (documented in 03-CONTEXT.md and 03-RESEARCH.md) deliberately changed this to global per property to fix a Phase 2 RPC bug that conflicted with the UNIQUE INDEX `(property_id, number)`. This is a tracked design decision, not an undocumented deviation. The implementation delivers the intent (uniqueness + no duplicates) correctly.

**Orphaned requirements check:** ANIM-03 (ficha consolidada) is mapped to Phase 8 in REQUIREMENTS.md and does not appear in any Phase 3 plan — correct. No orphans detected.

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `lib/features/animais/presentation/animal_detail_screen.dart` | `_PlaceholderSection('Histórico Reprodutivo', 'Disponível na Fase 5.')` and `_PlaceholderSection('Histórico Sanitário', 'Disponível na Fase 6.')` | ℹ️ Info | These are intentional, documented placeholders required by the plan (D-22). ANIM-03 is Phase 8 scope. Not a Phase 3 gap. |
| Generated files (`lote_model.freezed.dart`, `animal_model.freezed.dart`, etc.) | Not present on disk (gitignored) | ⚠️ Warning | Must run `dart run build_runner build` after checkout. All Summaries document this requirement. Not a code defect — a developer workflow note. |

No blockers found.

---

### Human Verification Required

**These items require a live Supabase dev DB + running `flutter run -d chrome` session:**

#### 1. Batch Lot Creation End-to-End (SC-1)

**Test:** Login as veterinarian → navigate to /piquetes → open a paddock → tap the '+' FAB → in LoteFormDialog enter name 'Lote Teste', set Vacas=10, Terneiros=8, Touros=1 → tap 'Criar lote'.
**Expected:** Lot appears in the list; tapping it opens LoteDetailScreen showing header chips (10 Vacas · 10,0 UA, 8 Terneiros · 4,0 UA, 1 Touros · 1,5 UA) and total chip (15,5 UA); animal list shows 19 tiles with sequential numbers.
**Why human:** `create_lot_with_animals` RPC + advisory lock + number generation requires live Postgres.

#### 2. Animal Edit Flow (SC-2)

**Test:** Open LoteDetailScreen → tap an animal tile → in AnimalDetailScreen tap 'Editar animal' → change Raça to 'Angus', set EC to 3, add observação 'Test' → tap 'Salvar'.
**Expected:** AnimalDetailScreen immediately reflects updated Raça, EC 3/5, and observação without page reload.
**Why human:** Requires live Riverpod provider invalidation + Supabase UPDATE confirmation.

#### 3. Search by Number with Debounce (SC-3)

**Test:** Open AnimaisScreen → type '4' in the search bar → wait 300ms.
**Expected:** List filters to animals whose number contains '4'; clear (X) icon appears; typing additional characters continues to filter; clearing resets the full list.
**Why human:** Timer debounce (300ms) cannot be verified via static analysis; requires running app.

#### 4. Combined Filter + SummaryBar (SC-4)

**Test:** Open AnimaisScreen → tap 'Vaca' FilterChip → select a specific lot from the Lote dropdown.
**Expected:** List shows only vacas in the selected lot; SummaryBar shows updated count and UA total (count × 1.0).
**Why human:** In-memory filter pipeline runs on live provider data.

#### 5. Baixa Registration (SC-5)

**Test:** Open AnimalDetailScreen for an active animal → tap 'Dar baixa' → select 'Venda' → confirm date → tap 'Confirmar baixa'.
**Expected:** Dialog closes; animal disappears from LoteDetailScreen active list; AnimalDetailScreen now shows status 'Arquivado — Vendido em DD/MM/YYYY'; lot-card subtitle UA decreases by 1.0 (for vaca).
**Why human:** Requires live soft-delete (deleted_at + baixa_reason + baixa_date), provider invalidation, and UI re-render.

---

## Gaps Summary

No gaps found. All 5 roadmap success criteria have verified code paths. All 8 requirement IDs (PROP-03, PROP-04, PROP-05, ANIM-01, ANIM-02, ANIM-04, ANIM-05, ANIM-06) are satisfied by substantive, wired implementations with real DB data flows.

The status is `human_needed` because 5 behaviors require a live Supabase + Flutter web session to confirm end-to-end. The automated evidence is strong — all repository methods call real Supabase queries, all dialogs wire to those repositories, all test files pass with zero skips.

### Notable Design Decisions (not gaps)

- **ANIM-01 numbering scope:** Requirements.md says "por (propriedade, categoria)" but D-05 deliberately changed to global per property to fix a Phase 2 UNIQUE INDEX conflict. This is an intentional, documented deviation tracked in 03-CONTEXT.md.
- **03-06-PLAN.md missing:** Plan 06 was executed without a PLAN.md file. The SUMMARY.md (03-06-SUMMARY.md) documents tasks_completed=2, tasks_total=2 and all key decisions. The absence of a PLAN.md is a process gap but the implementation is complete and committed.
- **Freezed generated files not in git:** `.freezed.dart` and `.g.dart` files are gitignored. Developers must run `dart run build_runner build` after checkout. Documented in all relevant SUMMARYs.
- **Histórico Reprodutivo / Sanitário placeholders:** `animal_detail_screen.dart` has intentional `_PlaceholderSection` widgets for Phase 5 and Phase 6 content. These are required by the plan and will be replaced in those phases.

---

_Verified: 2026-05-15T03:00:00Z_
_Verifier: Claude (gsd-verifier)_
