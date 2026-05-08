---
phase: "02-property-paddock-structure"
plan: "02"
subsystem: "propriedades-data-layer"
tags: ["freezed", "riverpod", "supabase", "repository", "soft-delete", "rls"]
dependency_graph:
  requires:
    - "02-01 (schema migration — propriedades.proprietario + deleted_at columns, property_members table)"
  provides:
    - "Propriedade freezed data class (id, nome, proprietario, createdAt, deletedAt)"
    - "PropriedadeRepository with 4 CRUD methods (PROP-01)"
    - "propriedadeRepositoryProvider + propriedadeListProvider"
    - "PropertyRepository soft-delete filter (Pitfall 1 / T-02-10 closed)"
  affects:
    - "04 (PropriedadesScreen — consumes propriedadeListProvider)"
    - "memberPropertiesProvider (PropertySelector now filters deleted propriedades)"
tech_stack:
  added: []
  patterns:
    - "freezed 3.x sealed class with class-level @JsonSerializable(fieldRename: FieldRename.snake)"
    - "Two-step propriedade + property_members INSERT with T-02-12 orphan acceptance"
    - "PostgREST !inner join + embedded isFilter for soft-delete exclusion"
key_files:
  created:
    - "lib/features/propriedades/data/propriedade_model.dart"
    - "lib/features/propriedades/data/propriedade_repository.dart"
    - "test/features/propriedades/propriedade_repository_test.dart"
  modified:
    - "lib/features/auth/data/property_repository.dart"
decisions:
  - "sealed class required for freezed 3.x single-union: mixin _$Propriedade declares abstract getters; non-sealed class fails Dart analysis"
  - "@JsonSerializable at class level (not constructor) avoids invalid_annotation_target lint warning"
  - "T-02-12 orphan on two-step write accepted for MVP: RLS blocks orphan reads; future phase wraps atomically"
  - "propriedadeListProvider watches authNotifierProvider to invalidate on login/logout"
metrics:
  duration: "~20 min"
  completed_date: "2026-05-08"
  tasks_completed: 2
  files_created: 3
  files_modified: 1
---

# Phase 02 Plan 02: Propriedade Data Layer Summary

**One-liner:** Freezed sealed model + Supabase CRUD repository for propriedades with soft-delete filter closing PropertySelector Pitfall 1.

## Files Created / Modified

| File | Type | Description |
|------|------|-------------|
| `lib/features/propriedades/data/propriedade_model.dart` | Created | `@freezed sealed class Propriedade` with 5 fields, snake_case JSON, soft-delete support |
| `lib/features/propriedades/data/propriedade_repository.dart` | Created | `PropriedadeRepository` with 4 CRUD methods + `propriedadeRepositoryProvider` + `propriedadeListProvider` |
| `test/features/propriedades/propriedade_repository_test.dart` | Created | Wave 0 RED stub (depends_on 02-01) — made GREEN by this plan |
| `lib/features/auth/data/property_repository.dart` | Modified | `fetchMemberProperties()` now uses `propriedades!inner` + `.isFilter('propriedades.deleted_at', null)` |

## Build Runner Output

Codegen succeeded in 15s. Outputs:
- `lib/features/propriedades/data/propriedade_model.freezed.dart` (generated, gitignored)
- `lib/features/propriedades/data/propriedade_model.g.dart` (generated, gitignored)

Key JSON mapping verified in `.g.dart`: `created_at` → `createdAt`, `deleted_at` → `deletedAt`.

Initial codegen attempt failed with `json_serializable: Cannot populate required constructor argument`. Fixed by using `sealed class` (freezed 3.x requirement) and moving `@JsonSerializable` to class level.

## Test Results

```
flutter test test/features/
00:02 +11: All tests passed!
```

- `test/features/propriedades/propriedade_repository_test.dart` — 2 tests GREEN (Wave 0 RED resolved)
- `test/features/auth/property_repository_test.dart` — 2 tests still GREEN (modification did not break)
- `test/features/auth/auth_repository_test.dart` — 5 tests GREEN
- `test/features/auth/login_screen_test.dart` — 2 tests GREEN

`flutter analyze lib/features/propriedades/ lib/features/auth/data/property_repository.dart` — No issues found.

## Two-Step Propriedade + Membership Insert Pattern

**Rationale (D-04 + T-02-12):**

`createPropriedadeWithMembership` performs two sequential inserts:
1. `INSERT INTO propriedades` → returns created row
2. `INSERT INTO property_members (user_id, property_id, perfil='veterinario')`

This is intentionally **not** wrapped in a Postgres transaction for MVP. If step 2 fails, an orphan `propriedades` row remains — but it is invisible via RLS (no `property_members` row means `is_member_of()` returns false → no SELECT access). Accepted risk T-02-12.

Future phase: wrap both inserts in a `CREATE FUNCTION create_propriedade_with_membership(...)` PL/pgSQL function that uses a single transaction.

## PropertySelector Soft-Delete Filter (Pitfall 1 / T-02-10)

The modification to `PropertyRepository.fetchMemberProperties()`:

```dart
// Before:
.select('perfil, propriedades(id, nome)')

// After:
.select('perfil, propriedades!inner(id, nome, deleted_at)')
.isFilter('propriedades.deleted_at', null)
```

- `!inner` converts to INNER JOIN → rows with inaccessible propriedade are dropped server-side
- `.isFilter('propriedades.deleted_at', null)` uses PostgREST embedded resource filter to exclude soft-deleted rows
- Soft-deleted propriedades no longer appear in the PropertySelector dropdown

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created Wave 0 test stub (02-01 dependency not yet merged)**
- **Found during:** Task 1 verification setup
- **Issue:** `test/features/propriedades/propriedade_repository_test.dart` does not exist in this worktree (depends_on 02-01 runs in parallel worktree agent-ac8c2b9dc9ae6d51d)
- **Fix:** Created the test file with identical content to what Wave 0 agent produced (confirmed by reading agent-ac8c2b9dc9ae6d51d worktree)
- **Files modified:** `test/features/propriedades/propriedade_repository_test.dart`
- **Commit:** 3b53786

**2. [Rule 1 - Bug] Fixed freezed 3.x class declaration for sealed union**
- **Found during:** Task 1 codegen + test run
- **Issue:** `class Propriedade with _$Propriedade` fails Dart analysis — freezed 3.x mixin declares abstract getters that require `sealed class` keyword
- **Fix:** Changed to `sealed class Propriedade with _$Propriedade`; moved `@JsonSerializable` to class level to avoid `invalid_annotation_target` lint warning
- **Files modified:** `lib/features/propriedades/data/propriedade_model.dart`
- **Commit:** 3b53786 (part of Task 1 commit)

## Known Stubs

None. All repository methods are fully wired to Supabase PostgREST. No placeholder data. The repository is not yet consumed by a UI screen (that is Plan 04).

## Threat Flags

None. No new network endpoints or auth paths introduced beyond what the threat model registers.

## Self-Check: PASSED

- [x] `lib/features/propriedades/data/propriedade_model.dart` exists
- [x] `lib/features/propriedades/data/propriedade_repository.dart` exists
- [x] `test/features/propriedades/propriedade_repository_test.dart` exists
- [x] `lib/features/auth/data/property_repository.dart` modified (contains `propriedades!inner`)
- [x] Commits 3b53786 and 03cab7d exist
- [x] `flutter test test/features/` — 11 tests, all passed
- [x] `flutter analyze` — no issues
