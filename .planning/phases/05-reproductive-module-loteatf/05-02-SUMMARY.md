---
phase: 05-reproductive-module-loteatf
plan: 02
subsystem: database
tags: [flutter, riverpod, freezed, supabase, reproductive]

# Dependency graph
requires:
  - phase: 05-reproductive-module-loteatf plan 01
    provides: atf_batches / dg_records schema, animal_atf_memberships extension, RLS, triggers (not read live — this plan is Dart-only and references table/column names from the plan spec, not a live DB)
provides:
  - "AtfBatch, DgRecord freezed models + AtfMembershipView / ReproductiveHistoryEntry view DTOs"
  - "summarizeDg / formatPrenhez — the single REPR-04 % prenhez implementation"
  - "AtfRepository with the full read + mutation surface for ATF batches, memberships, and DG records"
  - "8 Riverpod providers: atfRepositoryProvider, atfListByPropertyProvider, atfByIdProvider, atfMembershipsProvider, atfActiveMembershipsProvider, dgRecordsByAtfProvider, reproductiveHistoryByAnimalProvider, eligibleAnimalsForAtfProvider"
affects: [05-03, 05-05, 05-06, 05-07, 05-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DgSummary.percent as a nullable getter (null at total==0) — encodes the 'never show 0%' UI rule at the type level, not via a caller-side conditional"
    - "AtfRepository.fetchAtfSummaries mirrors LoteRepository.fetchLotsWithCountByProperty's two-query-and-group-in-Dart idiom rather than a SQL view"
    - "fetchEligibleAnimalsForAtf annotates blockedByAtfName instead of filtering — UI renders disabled rows, never silently drops animals"

key-files:
  created:
    - lib/features/reproducao/data/atf_model.dart
    - lib/features/reproducao/data/dg_record_model.dart
    - lib/features/reproducao/data/dg_summary.dart
    - lib/features/reproducao/data/atf_repository.dart
    - test/features/reproducao/atf_model_test.dart
    - test/features/reproducao/dg_summary_test.dart
    - test/features/reproducao/atf_repository_test.dart
  modified: []

key-decisions:
  - "summarizeDg ties on createdAt (insertion order), not examDate, per A-DG-ORDER (D-11 lets the vet override examDate, so it cannot be trusted as the ordering signal)"
  - "fetchMemberships/fetchReproductiveHistory sort in Dart after the query rather than via PostgREST embedded-resource ordering, matching this codebase's established group-in-Dart idiom"
  - "AtfRepository test file follows the lote_repository_test.dart contract-test style (method-exists assertions, no live query-builder mocking) — documented in the test file header"

patterns-established:
  - "Pattern: a nullable computed getter (DgSummary.percent) is the mechanism for 'never render a false zero' UI rules, reusable anywhere a ratio can have an empty denominator"

requirements-completed: [REPR-01, REPR-02, REPR-03, REPR-04, REPR-05]

coverage:
  - id: D1
    description: "AtfBatch and DgRecord freezed models round-trip Supabase's snake_case row shape; DgResult enum maps the three DG outcomes to pt-BR labels and DB values"
    requirement: "REPR-01"
    verification:
      - kind: unit
        ref: "test/features/reproducao/atf_model_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "summarizeDg computes % prenhez correctly for D-12 (most-recent-DG-per-animal), D-17 (duvidosa in denominator not numerator), D-18 (display format), and D-20 (baixa'd animal with a DG stays counted); formatPrenhez emits the exact 05-UI-SPEC strings including the E10 singular/plural resolution"
    requirement: "REPR-04"
    verification:
      - kind: unit
        ref: "test/features/reproducao/dg_summary_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "AtfRepository exposes every read (batches, memberships, DG records, summaries, reproductive history, eligible-animal picker) and mutation (createAtf direct insert; addAnimalsToAtf/removeAnimalFromAtf/saveDgRecords/closeAtf as named RPCs) the five presentation plans need"
    requirement: "REPR-02"
    verification:
      - kind: unit
        ref: "test/features/reproducao/atf_repository_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "fetchReproductiveHistory returns one entry per ATF the animal participated in (active or closed), most-recent DG per ATF, ordered by insemination date descending"
    requirement: "REPR-05"
    verification: []
    human_judgment: true
    rationale: "Grouping/ordering logic exercised only by the contract test (method-exists, no live query-builder mock per the established lote_repository_test.dart style) — no live Supabase project available this session to prove the actual query shape end-to-end. A widget-level or live-DB test in a later plan should close this gap."
  - id: D5
    description: "DG result vocabulary (pregnant/not_pregnant/doubtful) stays a database CHECK constraint on the SQL side; saveDgRecords only ever sends DgResult.dbValue strings, never a raw client value"
    requirement: "REPR-03"
    verification:
      - kind: unit
        ref: "test/features/reproducao/atf_model_test.dart#DgResult"
        status: pass
    human_judgment: false

duration: 13min
completed: 2026-08-04
status: complete
---

# Phase 5 Plan 02: Reproductive Data Layer Summary

**Freezed models, the single-source % prenhez formula, and the full AtfRepository + provider surface for the LoteATF reproductive module — Dart-only, zero UI, no live Supabase call.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-08-04T17:51:00Z
- **Completed:** 2026-08-04T18:04:24Z
- **Tasks:** 3
- **Files modified:** 7 (4 source, 3 test)

## Accomplishments
- `AtfBatch` / `DgRecord` freezed models plus `AtfMembershipView`, `ReproductiveHistoryEntry` view DTOs — all round-trip Supabase's snake_case row shape (REPR-01, REPR-03)
- `summarizeDg` / `formatPrenhez` — the one and only REPR-04 percentage implementation, with tests for every D-12/D-17/D-18/D-20 edge case named in the plan's backstop truth
- `AtfRepository` — 7 read methods and 5 mutation methods (all mutations except the single-row `createAtf` insert go through a named RPC), plus 8 Riverpod providers, giving the wave-3 presentation plans a complete, stable contract to build against without touching this file

## Task Commits

Each task was committed atomically:

1. **Task 1: Freezed models for AtfBatch, DgRecord, and the two view DTOs** - `c7eb36d` (feat)
2. **Task 2: summarizeDg — the % prenhez calculation (REPR-04)** - `5fde8e9` (feat)
3. **Task 3: AtfRepository and the reproductive Riverpod providers** - `b05eb64` (feat)

**Plan metadata:** committed alongside this SUMMARY (worktree mode — orchestrator finalizes STATE.md/ROADMAP.md after wave merge)

_Note: freezed's `.freezed.dart` / `.g.dart` generated parts are gitignored per this project's convention and are not part of any commit — they are regenerated by `dart run build_runner build` at checkout._

## Files Created/Modified
- `lib/features/reproducao/data/atf_model.dart` - `AtfBatch` freezed model, `AtfMembershipView`, `ReproductiveHistoryEntry`
- `lib/features/reproducao/data/dg_record_model.dart` - `DgRecord` freezed model, `DgResult` enum
- `lib/features/reproducao/data/dg_summary.dart` - `DgSummary`, `summarizeDg()`, `formatPrenhez()`
- `lib/features/reproducao/data/atf_repository.dart` - `AtfRepository`, `AtfSummary`, `EligibleAnimal`, and all 8 providers
- `test/features/reproducao/atf_model_test.dart` - model round-trip + `DgResult` mapping tests
- `test/features/reproducao/dg_summary_test.dart` - REPR-04 formula tests (11 cases)
- `test/features/reproducao/atf_repository_test.dart` - contract tests (12 cases)

## Decisions Made
- **A-DG-ORDER honored as written:** `summarizeDg`'s and `fetchReproductiveHistory`'s "most recent DG" tie-breaker is `createdAt`, not `examDate` — carried directly from the plan's flagged assumption, not re-litigated. If the veterinarian domain expert prefers `examDate`, this is a one-line change in both places (already isolated behind `summarizeDg`/`fetchReproductiveHistory`, no callers to touch).
- **fetchMemberships/fetchReproductiveHistory sort client-side after the embedded-resource query** rather than attempting PostgREST foreign-table `.order()` syntax, matching the established `fetchLotsWithCountByProperty` group-in-Dart idiom used throughout this codebase.
- **`// ignore_for_file: use_null_aware_elements` added to atf_repository.dart**, mirroring the identical suppression already present in `animal_repository.dart` — the `'key'?: value` map-literal syntax the linter suggests is not valid in this project's pinned Dart 3.11, so the `if (x != null) 'key': x` idiom is kept.

## Deviations from Plan

None - plan executed exactly as written. All method signatures, provider names, and table/column references match the plan's `<action>` blocks verbatim.

## Issues Encountered
- `05-PATTERNS.md`, referenced in this plan's `<context>` block, does not exist on disk in this worktree (only `05-CONTEXT.md`, `05-RESEARCH.md`, `05-UI-SPEC.md`, `05-DISCUSSION-LOG.md`, `05-VALIDATION.md` are present alongside the 10 plan files). Proceeded using `05-RESEARCH.md`'s Architecture Patterns section instead, which contains the equivalent content (Pattern 1–4, the same file/method shapes this plan's `<action>` blocks describe) — no gap in coverage, just a missing filename.
- The `20260804_05_reproductive_module.sql` migration this plan's RPC calls reference (created by sibling plan 05-01, running in a separate wave-1 worktree) is not present in this worktree and was not queried live — this plan is Dart-only by design (`autonomous: true`, no live-DB verification step), so all table/column/RPC names were taken from 05-01-PLAN.md's `<action>` spec and 05-RESEARCH.md's code examples, not from a live schema introspection.

## User Setup Required

None - no external service configuration required. `supabase db push` for the underlying schema is owned by plan 05-01/05-10, not this plan.

## Next Phase Readiness
- The complete `AtfRepository` + provider contract is in place; plans 05-05 through 05-08 (the five presentation plans) can each build their screen against this file without editing it, as designed.
- Live-DB verification of the RPC parameter shapes (`p_animal_ids` as jsonb array, `p_records` as jsonb) and the embedded-resource query joins (`animals(number, category)`, `atf_batches(id, name, insemination_date, active)`) is deferred to whichever plan first runs against a linked Supabase project — flagged as coverage item D4's rationale above, consistent with the STATE.md blocker carried from Phase 4 (Supabase CLI unlinked this session).

---
*Phase: 05-reproductive-module-loteatf*
*Completed: 2026-08-04*

## Self-Check: PASSED

All 7 claimed source/test files verified present on disk. All 4 commits
(`c7eb36d`, `5fde8e9`, `b05eb64`, `90af235`) verified present in `git log`.
