---
phase: "02-property-paddock-structure"
plan: "04"
subsystem: "propriedades-ui"
tags: ["flutter", "ui", "riverpod", "screens", "PROP-01", "wave-2"]
dependency_graph:
  requires:
    - "02-02 (PropertyRepository + propertyListProvider)"
    - "02-03 (PaddockRepository — consumed by Plan 05)"
  provides:
    - "PropriedadesScreen with empty state, property list, role-gated FAB"
    - "PropertyFormDialog AlertDialog for create/edit"
    - "AppRoutes.propriedades = '/propriedades' constant"
    - "GoRoute /propriedades registered root-level outside AppShell"
    - "PropertySelector 'Gerenciar fazendas' navigation (single + multi-property)"
  affects:
    - "05 (PiquetesScreen — next Wave 2 plan)"
    - "PropertySelector (now navigates to /propriedades)"
tech_stack:
  added: []
  patterns:
    - "ConsumerWidget + ref.watch(propertyListProvider) for async list"
    - "Role gate via memberPropertiesProvider membership lookup"
    - "showDialog<bool> pattern for create/edit/delete flows"
    - "PopupMenuItem with null value + onTap for navigation items"
key_files:
  created:
    - "lib/features/propriedades/presentation/propriedades_screen.dart"
    - "lib/features/propriedades/presentation/property_form_dialog.dart"
  modified:
    - "lib/core/router/routes.dart"
    - "lib/core/router/router.dart"
    - "lib/core/widgets/property_selector.dart"
decisions:
  - "PopupMenuItem value=null + onTap used for Gerenciar fazendas in multi-prop dropdown — null value prevents onSelected from firing while onTap handles navigation"
  - "Single-property selector wraps text in Column with InkWell link below rather than TextButton — matches visual hierarchy without extra padding"
  - "separatorBuilder uses named params (context, index) to satisfy unnecessary_underscores lint"
metrics:
  duration: "~7 min"
  completed_date: "2026-05-08"
  tasks_completed: 2
  files_created: 2
  files_modified: 3
---

# Phase 02 Plan 04: Properties UI Summary

**One-liner:** PropriedadesScreen with empty state + role-gated FAB + PropertyFormDialog, wired to /propriedades route and accessible from PropertySelector "Gerenciar fazendas" link.

## Files Created / Modified

| File | Type | Description |
|------|------|-------------|
| `lib/features/propriedades/presentation/propriedades_screen.dart` | Created | `PropriedadesScreen`: empty state, property list with edit/delete, role-gated FAB |
| `lib/features/propriedades/presentation/property_form_dialog.dart` | Created | `PropertyFormDialog`: AlertDialog with Name (required) + Owner (optional) fields |
| `lib/core/router/routes.dart` | Modified | Added `AppRoutes.propriedades = '/propriedades'`; `all` list stays 5 entries |
| `lib/core/router/router.dart` | Modified | Added PropriedadesScreen import + GoRoute for /propriedades root-level |
| `lib/core/widgets/property_selector.dart` | Modified | Added go_router import + "Gerenciar fazendas" for single and multi-property cases |

## Route Wiring Summary

- `AppRoutes.propriedades = '/propriedades'` added to routes.dart (outside `all` list — not a shell branch)
- GoRoute registered BEFORE StatefulShellRoute.indexedStack, alongside auth routes
- Auth redirect in router.dart already gates all non-auth routes — /propriedades is protected
- PropertySelector: single-property shows InkWell "Gerenciar fazendas" below property name; multi-property shows PopupMenuDivider + PopupMenuItem with settings icon

## Test Results

```
flutter test test/core/router_test.dart test/widget/propriedades_screen_test.dart
00:01 +2: All tests passed!

flutter test test/
00:08 +32 -1: Some tests failed.
```

- `test/widget/propriedades_screen_test.dart` — 1 test GREEN (was RED Wave 0 stub)
- `test/core/router_test.dart` — 1 test GREEN (AppRoutes.all.length == 5, no regression)
- `test/widget/piquetes_screen_test.dart` — 1 test RED (intentional Wave 0 stub; Plan 05 will fix)
- All other tests: 31/32 passing

`flutter analyze lib/core/ lib/features/propriedades/` — 2 pre-existing info items (out of scope):
- `unintended_html_in_doc_comment` in `app_config.dart` (pre-existing)
- `use_null_aware_elements` in `propriedade_repository.dart` (pre-existing from Plan 02-02)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Build runner needed for freezed generated files**
- **Found during:** Task 1 first test run
- **Issue:** `propriedade_model.freezed.dart` and `propriedade_model.g.dart` not present in worktree (gitignored generated files); test compilation failed
- **Fix:** Ran `flutter pub run build_runner build` — generated 6 outputs in 56s
- **Files modified:** `lib/features/propriedades/data/propriedade_model.freezed.dart`, `.g.dart` (generated, gitignored)
- **Commit:** Part of 3c70e32

**2. [Rule 1 - Bug] Fixed unnecessary_underscores lint in separatorBuilder**
- **Found during:** Task 2 `flutter analyze` run
- **Issue:** `separatorBuilder: (_, __) =>` triggers `unnecessary_underscores` lint
- **Fix:** Changed to named params `(context, index) =>`
- **Files modified:** `lib/features/propriedades/presentation/propriedades_screen.dart`
- **Commit:** e509d89

### Worktree Setup Deviation

**[Rule 3 - Blocking] Worktree working tree needed checkout to match HEAD**
- The worktree branch started from main branch HEAD (0c2c28de) instead of the expected 2f37ae3 (EXPECTED_BASE). After `git reset --soft 2f37ae3`, the working tree was restored with `git checkout HEAD -- lib/ test/ supabase/` to match the 2f37ae3 commit state (which contains the English rename refactoring). The staged changes from the stale router test fix (0c2c28de) were included in the first task commit; they were deletions of SUMMARY files from other plan branches that don't belong in this worktree branch.

## Known Stubs

None. Both PropriedadesScreen and PropertyFormDialog are fully wired to `PropertyRepository` and `propertyListProvider`. No placeholder data or hardcoded values.

## Threat Flags

None. No new network endpoints beyond what the threat model registers. `/propriedades` route is gated by the existing auth redirect (T-02-22 mitigated by Phase 1 router guard).

## Self-Check: PASSED

- [x] `lib/features/propriedades/presentation/propriedades_screen.dart` exists with class `PropriedadesScreen`
- [x] Screen contains 'Nenhuma fazenda cadastrada' and 'Crie sua primeira fazenda para começar a organizar o rebanho.'
- [x] `lib/features/propriedades/presentation/property_form_dialog.dart` exists with class `PropertyFormDialog`
- [x] `lib/core/router/routes.dart` contains `static const propriedades = '/propriedades'`
- [x] `lib/core/router/routes.dart` `all` list has exactly 5 entries
- [x] `lib/core/router/router.dart` imports `PropriedadesScreen` and registers GoRoute for `AppRoutes.propriedades`
- [x] `lib/core/widgets/property_selector.dart` contains 'Gerenciar fazendas'
- [x] Commits 3c70e32 and e509d89 exist
- [x] `flutter test test/widget/propriedades_screen_test.dart` — 1 test GREEN
- [x] `flutter test test/core/router_test.dart` — 1 test GREEN
- [x] Full suite: 31/32 passing (1 intentional RED stub remains for Plan 05)
