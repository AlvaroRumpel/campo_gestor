---
phase: 08-animal-dossier-consolidation
reviewed: 2026-08-11T22:00:00Z
depth: deep
files_reviewed: 7
files_reviewed_list:
  - lib/features/lotes/data/lote_repository.dart
  - lib/features/reproducao/data/atf_model.dart
  - lib/features/reproducao/data/atf_repository.dart
  - lib/features/reproducao/presentation/animal_reproductive_history_section.dart
  - lib/features/animais/presentation/animal_detail_screen.dart
  - lib/features/animais/presentation/animais_screen.dart
  - lib/features/sanitario/presentation/sanitary_history_section.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-08-11T22:00:00Z
**Depth:** deep
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed all production commits of 08-01 through 08-05 against the primary files in scope,
cross-referenced against `supabase/migrations/*.sql` for RLS, and ran `flutter analyze` +
the phase's widget/unit test suites (all green, 0 analyzer issues on the reviewed files).

The five specific risk areas called out in the review brief all check out clean:

1. **DG list sort-on-const-list crash (item 1):** `atf_repository.dart:220-226` copies into a
   growable `List<DgRecord>.from(...)` before `..sort()`. The fallback `?? const []` only feeds
   that copy constructor, never sorted in place. No crash risk.
2. **DG ordering comparator reuse (item 2):** the sort correctly calls the shared `isLaterDg`
   (from `dg_summary.dart`) instead of re-implementing an `examDate`/`createdAt` comparison — no
   fourth drifted copy.
3. **Retry scoping (item 3):** both the sanitary (`13e10e3`) and reproductive (`b6f8d8b`) retry
   buttons call `ref.invalidate(provider(specificId))` — the family instance, not the bare family.
   Verified by a widget test that asserts a sibling provider is not re-invoked.
4. **`_AnimalListTile` badge fix (item 4):** `showArchived` was fully removed — no dangling
   references in `animais_screen.dart` or its test file; the badge now correctly depends only on
   `isArchived`.
5. **`ExpansionTile` gesture arena (item 5):** the inner `InkWell` (navigation) is nested inside
   the outer `ExpansionTile`'s tap-to-expand region; Flutter resolves nested tap recognizers to
   the innermost hit, so a tap on the summary text navigates and a tap on the chevron (outside the
   inner `InkWell`'s bounds) expands. Confirmed correct by a dedicated widget test
   (`animal_reproductive_history_section_test.dart`, "navigation vs expansion coexist" group).
6. **`_KvRow`'s `LayoutBuilder` (item 6):** receives a bounded `maxWidth` from its `Card > Padding
   > Column > ListView` ancestry — no unbounded-constraint risk, no layout loop (single
   `LayoutBuilder`, no nested ones measuring the same axis).
7. **Null/empty handling on new fields (item 7):** `dgRecords` defaults to `const []` copied into
   a fresh growable list per entry; `bullName` is a nullable cast guarded everywhere it's read
   (`hasBull` check before rendering); `implantationDate` is a `required DateTime` matching the
   non-null DB column. No null-related crash paths found.

The new PostgREST embed in `lote_repository.dart` (`lots` joined with `paddocks!inner(name)`)
was checked against `supabase/migrations/20260508_02_property_paddock.sql` and
`20260514_03_lots_animals.sql`: both tables have `FORCE ROW LEVEL SECURITY` with
`is_member_of(property_id)`-scoped SELECT policies, so the embed cannot leak data across
properties — consistent with the existing `fetchLot`/`fetchAtf` convention of trusting RLS
rather than re-filtering `property_id` in Dart.

Two real gaps remain, both quality/robustness rather than functional bugs found in the shipped
behavior — see below.

## Warnings

### WR-01: `ExpansionTile` rows have no stable key — expand state can bleed across a re-sorted list

**File:** `lib/features/reproducao/presentation/animal_reproductive_history_section.dart:112-113`
**Issue:** The `for (final entry in entries) _ReproductiveHistoryRow(entry: entry, dateFmt: dateFmt)`
loop builds each row without a `key:`. `entries` is freshly sorted by `inseminationDate` descending
every time `reproductiveHistoryByAnimalProvider` refetches (initial load, retry, or a future
navigation-back-refresh). If a new ATF with a later insemination date is added — or any change
shifts an existing ATF's position in the list — Flutter's default element reconciliation matches
old-to-new widgets by **position**, not identity. A user who had expanded the `ExpansionTile` for
ATF X at index 1 can end up looking at ATF Y's row still shown expanded (or ATF X silently
collapsed) after a refetch reorders the list, because `ExpansionTile`'s internal `_isExpanded`
state is owned by the `State` object at that tree position, and Dart-level equality of the widget
doesn't factor into whether Flutter reuses that `State`.
This is not exercised by the current test suite — every widget test builds a fixed, single-fetch
entry list and never triggers a reordering refetch while a tile is expanded.
**Fix:**
```dart
for (final entry in entries)
  _ReproductiveHistoryRow(
    key: ValueKey(entry.atfBatchId),
    entry: entry,
    dateFmt: dateFmt,
  ),
```

### WR-02: DG grouping/sort logic in `fetchReproductiveHistory` has no behavioral test coverage

**File:** `lib/features/reproducao/data/atf_repository.dart:196-244`
**Issue:** This is exactly the code path flagged in the plan as a real runtime-crash risk (sorting
a `const []` in place) — and the shipped fix is correct (see Summary, item 1). But nothing in the
test suite actually exercises `AtfRepository.fetchReproductiveHistory` with more than one DG
record per ATF through a fake/mocked Supabase response:
- `test/features/reproducao/atf_repository_test.dart` only asserts
  `expect(repo.fetchReproductiveHistory, isA<Function>())` (contract test, no execution).
- `test/widget/animal_reproductive_history_section_test.dart` and
  `test/widget/animal_detail_screen_test.dart` both override
  `reproductiveHistoryByAnimalProvider` and hand-construct pre-sorted `ReproductiveHistoryEntry`
  fixtures directly (e.g. `dgRecords: [_dg1, _dg2, _dg3]` already in the expected order) — they
  never call the repository method, so the grouping (`dgsByAtf`) and sort logic underneath it is
  never executed by any automated test.
A future edit that reintroduces the `(map[id] ?? const [])..sort(...)` pattern, or that swaps the
comparator back to a hand-rolled one, would ship with all tests green.
**Fix:** Add one unit test in `atf_repository_test.dart` that stubs the Supabase client (or reuses
whatever fake-client pattern is available) to return 2+ `dg_records` rows for a single
`atf_batch_id` and asserts `fetchReproductiveHistory` (a) does not throw and (b) returns
`dgRecords` sorted most-recent-first per `isLaterDg`. If mocking the full PostgREST chain is
judged too brittle for this repo's convention (per the file's own header comment), at minimum
extract the grouping+sort block into a small pure function (mirroring `summarizeDg` in
`dg_summary.dart`) that can be unit-tested without a Supabase client at all.

## Info

### IN-01: Baixa-reason label mapping duplicated across two files

**File:** `lib/features/animais/presentation/animal_detail_screen.dart:314-319` (new in 08-04,
`_BaixaBanner`) vs. `lib/features/animais/presentation/animais_screen.dart:330-335`
(pre-existing, `_ArchiveBadge._label`, untouched this phase)
**Issue:** Both places independently switch on `animal.baixaReason` /
`'sale' | 'death' | 'discard' | _` → `'Vendido' | 'Morto' | 'Descartado' | 'Arquivado'`. The
08-04 commit message for `_BaixaBanner` says "moved... not duplicated," which is true *within*
`animal_detail_screen.dart` (it replaced that file's own old copy), but the cross-file duplicate
in `animais_screen.dart` was left standing. This is exactly the failure mode `dg_summary.dart`'s
header comment warns about (`isLaterDg` "previously drifted and one was lost from tracking docs
entirely") — low risk today since both copies list the same 4 branches, but a future change to
one (e.g. adding a 5th `baixaReason` value) has no compiler-enforced reason to touch the other.
**Fix:** Extract to a single top-level function, e.g. `String baixaReasonLabel(String? reason)` in
`animal_constants.dart` (which already documents `BaixaReason` per the `DgResult` doc comment's
cross-reference), and call it from both `_BaixaBanner` and `_ArchiveBadge`.

---

_Reviewed: 2026-08-11T22:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
