---
phase: "03"
plan: "03"
subsystem: data-layer
tags:
  - flutter
  - freezed
  - riverpod
  - repository
  - tdd
  - data-layer
dependency_graph:
  requires:
    - "03-01"  # Wave-0 test stubs
    - "03-02"  # lots table + animals extension migration
  provides:
    - LoteRepository (fetchLotsByPaddock, fetchLot, createLotWithAnimals, updateLotName, softDeleteLot)
    - AnimalRepository (fetchAnimalsByLot, fetchAnimalsByProperty, fetchAnimal, generateAnimalNumber, createAnimal, updateAnimal, registerBaixa)
    - Lot freezed model + json adapter
    - Animal freezed model + json adapter + AnimalWithContext DTO
    - animal_constants (kCategories, kUaWeights, kBreeds, BaixaReason, calcTotalUa)
    - 7 Riverpod providers (loteRepository, loteListByPaddock, loteById, animalRepository, animalListByLot, animalListByProperty, animalById)
  affects:
    - "03-04"  # PaddockDetailScreen lots section (consumes LoteRepository + loteListByPaddockProvider)
    - "03-05"  # AnimaisScreen (consumes AnimalRepository + animalListByPropertyProvider)
    - "03-06"  # LoteDetailScreen + dialogs (consumes both repos + providers)
tech_stack:
  added: []
  patterns:
    - "freezed @JsonSerializable(fieldRename: FieldRename.snake) on sealed classes"
    - "FutureProvider.family<T, String> for by-id and by-foreign-key providers"
    - "AnimalNumberConflictException wrapping PostgrestException(code=23505)"
    - "AnimalWithContext DTO assembled from PostgREST embedded join (lots!inner + paddocks!inner)"
    - "// ignore_for_file: use_null_aware_elements to suppress Dart 3.11 lint false-positive"
key_files:
  created:
    - lib/features/lotes/data/lote_model.dart
    - lib/features/lotes/data/lote_repository.dart
    - lib/features/animais/data/animal_model.dart
    - lib/features/animais/data/animal_repository.dart
    - lib/features/animais/data/animal_constants.dart
  modified:
    - test/features/animais/animal_model_test.dart
    - test/features/animais/ua_calculation_test.dart
    - test/features/lotes/lote_repository_test.dart
decisions:
  - "Contract tests chosen over full chain-mocking for LoteRepository (brittle fluent Supabase API) — integration tests deferred to a future plan"
  - "ignore_for_file: use_null_aware_elements added to animal_repository.dart — linter suggests Dart 3.7+ syntax that causes compiler errors in Dart 3.11.4 stable"
  - "animalListByPropertyProvider always fetches all (active + archived) — AnimaisScreen filters in-memory (Pitfall 6 mitigation)"
metrics:
  duration_minutes: 28
  completed_date: "2026-05-15"
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 3
---

# Phase 03 Plan 03: Data Layer — Lots + Animals Models, Repositories, Constants Summary

**One-liner:** Typed Flutter data layer for lots and animals: freezed models with snake_case JSON adapters, two repositories wrapping all PostgREST/RPC calls, UA weight constants, BaixaReason enum, and 14 Wave-0 unit tests turned GREEN.

---

## What Was Built

### Task 1: Freezed Models + Constants + Codegen

**`lib/features/lotes/data/lote_model.dart`** — `sealed class Lot with _$Lot`
- `@JsonSerializable(fieldRename: FieldRename.snake)` matching `piquete_model.dart` pattern
- Fields: id, propertyId, paddockId, name, createdAt, deletedAt (nullable)
- `Lot.fromJson` / `Lot.toJson` round-trip via generated `.g.dart`

**`lib/features/animais/data/animal_model.dart`** — `sealed class Animal with _$Animal` + `class AnimalWithContext`
- Animal: id, propertyId, lotId, category, number (required int), breed, bodyCondition, observation, baixaReason, baixaDate (all nullable), createdAt, deletedAt
- `AnimalWithContext`: plain Dart class (not freezed) — assembles animal + lotName + paddockId + paddockName from PostgREST embedded join for AnimaisScreen
- `Animal.fromJson` / `Animal.toJson` with snake_case field rename

**`lib/features/animais/data/animal_constants.dart`**
- `kCategories` — 7 valid category strings in display order
- `kCategoryLabels` / `kCategoryLabelsPlural` — pt-BR display strings
- `kUaWeights` — 7 entries: vaca=1.0, novilha=0.75, terneiro=0.5, terneira=0.5, touro=1.5, boi=1.5, novilho=0.75
- `kBreeds` — 17 hardcoded breeds from D-14 (no DB table)
- `enum BaixaReason { sale, death, discard }` with `dbValue`, `label`, `fromDb`
- `double calcTotalUa(Iterable<Animal>)` — top-level UA summation function

**Codegen:** `dart run build_runner build --delete-conflicting-outputs` — generated `.freezed.dart` + `.g.dart` for both models. Files are gitignored per project convention (regenerated locally on each clone).

### Task 2: Repositories + Providers

**`lib/features/lotes/data/lote_repository.dart`** — `LoteRepository` + 3 providers
- `fetchLotsByPaddock(paddockId)` — active lots ordered by name
- `fetchLot(id)` — single lot, null if soft-deleted
- `createLotWithAnimals(...)` — calls `create_lot_with_animals` RPC (atomic, advisory-locked)
- `updateLotName({id, name})` — name column only (D-12)
- `softDeleteLot(id)` — sets `deleted_at = now()`
- Providers: `loteRepositoryProvider`, `loteListByPaddockProvider(paddockId)`, `loteByIdProvider(id)`

**`lib/features/animais/data/animal_repository.dart`** — `AnimalRepository` + 4 providers + `AnimalNumberConflictException`
- `fetchAnimalsByLot(lotId, {includeArchived})` — active-only by default
- `fetchAnimalsByProperty(propertyId, {includeArchived})` — embedded join `lots!inner(name, paddock_id, paddocks!inner(id, name))`, assembles `AnimalWithContext`
- `fetchAnimal(id)` — single animal
- `generateAnimalNumber(propertyId)` — calls `generate_animal_number` RPC (advisory-locked global sequence)
- `createAnimal(...)` — catches `PostgrestException(code=23505)` → `AnimalNumberConflictException` (T-3-10)
- `updateAnimal({id, breed?, bodyCondition?, observation?})` — sends ONLY provided fields (T-3-12)
- `registerBaixa({id, reason, date, observation?})` — sets baixa_reason + baixa_date + deleted_at atomically
- Providers: `animalRepositoryProvider`, `animalListByLotProvider(lotId)`, `animalListByPropertyProvider` (watches `currentPropertyProvider`, always loads all), `animalByIdProvider(id)`

### Wave 0 Test Transitions (3 files → 0 skips, 14 tests GREEN)

| File | Tests | Before | After |
|------|-------|--------|-------|
| `test/features/animais/animal_model_test.dart` | 4 | 4 skipped | 4 GREEN |
| `test/features/animais/ua_calculation_test.dart` | 4 | 4 skipped | 4 GREEN |
| `test/features/lotes/lote_repository_test.dart` | 6 | 4 skipped | 6 GREEN |

**`animal_model_test.dart`:** fromJson round-trip, toJson snake_case keys, nullable fields support, number is int.

**`ua_calculation_test.dart`:** empty list = 0.0, mixed 10-vaca+8-terneiro+1-touro = 15.5, unknown category = 0.0 contribution, kUaWeights all 7 entries with exact values.

**`lote_repository_test.dart`:** 4 contract tests (method existence via mocktail-mocked SupabaseService) + 2 Lot model round-trip tests (fromJson + toJson snake_case). Full chain-mocking deferred — see Deviations.

---

## Codegen Result

```
Built with build_runner/aot in 50s; wrote 12 outputs.
- 4 new outputs: lote_model.freezed.dart, lote_model.g.dart, animal_model.freezed.dart, animal_model.g.dart
```

---

## Verification Results

```
flutter analyze lib/features/lotes lib/features/animais
→ No issues found!

flutter test test/features/lotes/ test/features/animais/
→ +14: All tests passed!
```

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `const Animal(...)` with `DateTime.utc()` compile error**
- **Found during:** Task 1 first test run
- **Issue:** `animal_model_test.dart` used `const Animal(...)` with `DateTime.utc(2026)` — `DateTime.utc` is not a const constructor, causing compile failure
- **Fix:** Changed `const Animal(...)` to `final animal = Animal(...)` in two test cases
- **Files modified:** `test/features/animais/animal_model_test.dart`
- **Commit:** f150c1d (included in Task 1 commit)

**2. [Rule 3 - Blocking] `null as dynamic` doesn't pass SupabaseService type check**
- **Found during:** Task 2 first test run
- **Issue:** Contract tests tried `LoteRepository(null as dynamic)` — Dart runtime rejects the cast since `SupabaseService` is a concrete class
- **Fix:** Introduced `MockSupabaseService extends Mock implements SupabaseService` via mocktail; tests now instantiate `LoteRepository(mockService)` which passes the type check
- **Files modified:** `test/features/lotes/lote_repository_test.dart`
- **Commit:** 5e1d53c

**3. [Rule 1 - Bug] `'key'?: value` null-aware map syntax causes compiler errors**
- **Found during:** Task 2 flutter analyze (info hints)
- **Issue:** The `use_null_aware_elements` lint rule suggested `'key'?: value` map entry syntax, which is not valid in Dart 3.11.4 stable (proposed feature, not finalized in compiler)
- **Fix:** Reverted to `if (x != null) 'key': x` pattern (correct Dart idiom) and added `// ignore_for_file: use_null_aware_elements` with explanation
- **Files modified:** `lib/features/animais/data/animal_repository.dart`
- **Commit:** 5e1d53c

### Plan Concession (documented, not a deviation)

**LoteRepository tests — contract tests instead of full chain mocking**

The plan explicitly documents: "If chain mocking is too brittle, replace those tests with contract tests... Document this concession in the test file's top comment so a Plan 04 task can later add real integration tests." This was applied. The 4 original stub tests became 4 contract tests (method existence via mocktail) + 2 additional `Lot` model round-trip tests (fromJson/toJson). The test file top comment explains the rationale and defers integration tests to a future plan.

---

## Known Stubs

None. All repository methods are fully implemented. No placeholder data flows to UI (no presentation code in this plan).

---

## Threat Flags

No new network endpoints, auth paths, or file access patterns beyond those in the plan's `<threat_model>`. T-3-09, T-3-10, T-3-11, T-3-12 mitigations were applied as specified.
