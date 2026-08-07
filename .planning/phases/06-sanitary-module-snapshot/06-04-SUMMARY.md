---
phase: 06-sanitary-module-snapshot
plan: 04
subsystem: database
tags: [flutter, riverpod, freezed, json_serializable, supabase, postgrest, jsonb]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot (06-01)
    provides: sanitary_calculations_test.dart placeholder group marker (D-40)
  - phase: 06-sanitary-module-snapshot (06-02)
    provides: sanitary_applications header columns, register_sanitary_application/reverse_sanitary_application RPCs, GIN + reversal indexes (both authored on disk, unapplied)
provides:
  - "SanitaryApplication/SanitaryCompositionEntry freezed models (frozen-row contract every wave 3-5 screen consumes)"
  - "visibleApplications/sortByAppliedAtDesc/reversedApplicationIds — the single D-29 reversal-visibility + D-06 ordering implementation"
  - "SanitaryApplicationException + asSanitaryException — the D-35 four-reason ERRCODE-to-pt-BR error vocabulary"
  - "SanitaryApplicationRepository — both RPCs, four read shapes, D-34 duplicate-detection query, five named providers"
  - "sanitaryHistoryByAnimalProvider(animalId) — the D-37 contract Phase 8 imports unchanged"
affects: [06-05, 06-06, 06-07, 06-08, 06-09, 06-10, 06-11, 06-12, phase-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Frozen-row freezed model with a private constructor (SanitaryApplication._()) adding a derived getter (isReversal) alongside the const factory — first phase-owned use of this idiom"
    - "List-level visibility/ordering helpers as top-level functions in the model file, not repository methods, so widgets and tests can call them without a provider"
    - "Phase-owned exception class with an enum-of-ERRCODE-reasons + required named fallback message, routed through a single asSanitaryException() catch-all helper"

key-files:
  created:
    - lib/features/sanitario/data/sanitary_application_model.dart
    - lib/features/sanitario/data/sanitary_application_exception.dart
    - lib/features/sanitario/data/sanitary_application_repository.dart
  modified:
    - test/features/sanitario/sanitary_calculations_test.dart

key-decisions:
  - "SanitaryApplication is a sealed freezed class with a private const constructor (`SanitaryApplication._()`) so `isReversal` can be added as a getter alongside the generated const factory — mirrors AppConfig's `._()` idiom, first freezed model in this codebase to combine the two"
  - "The two RPC calls build their params map as a separate local variable and call `.rpc('name', params: params)` on one line, rather than the multi-line `dart format`-wrapped call AtfRepository uses — kept the RPC name string on the same source line as `.rpc(` so the plan's acceptance-criteria grep (`rpc('register_sanitary_application'`) matches; functionally identical to the wrapped form"
  - "fetchApplication(id) and findRecentIdenticalApplication both call the same `sanitary_applications` table with different .select() projections — fetchApplication still applies the applied_at/created_at ordering per the plan's explicit 'every one of them' instruction, even though a single-row lookup by id does not semantically need it"

patterns-established:
  - "Pattern: visibleApplications(rows, {required bool showReversed}) is the one place the reversed-row-hiding logic lives — the global list, the lote section (06-06) and the animal ficha (06-07) all call this instead of re-deriving it"

requirements-completed: [SANI-02, SANI-03, SANI-04, SANI-05]

coverage:
  - id: D1
    description: "SanitaryApplication/SanitaryCompositionEntry freezed models with typed composition array, isReversal getter, and the three list-level helpers (sortByAppliedAtDesc, reversedApplicationIds, visibleApplications), proven by 6 new unit tests"
    requirement: "SANI-04"
    verification:
      - kind: unit
        ref: "test/features/sanitario/sanitary_calculations_test.dart#reversal visibility and ordering (SANI-04)"
        status: pass
    human_judgment: false
  - id: D2
    description: "SanitaryApplicationException with a four-value enum mapping 42501/P0002/P0003/23505 to authored pt-BR sentences, plus asSanitaryException() catch-all helper"
    requirement: "SANI-02"
    verification:
      - kind: other
        ref: "node structural gate (06-04-PLAN.md Task 2 <verify>) — flutter analyze clean, grep checks for case count, enum arity, factory signature, e.message scope all pass"
        status: pass
    human_judgment: true
    rationale: "The SQLSTATE-to-message mapping is only exercisable against a live PostgrestException from the actual RPCs, which are authored on disk but not yet applied to any database (06-02's critical_scope_note, owned by the 06-12 blocking wave). Structural correctness (case coverage, enum arity, no restated database text) is proven; end-to-end correctness against a live 42501/P0002/P0003/23505 requires 06-12."
  - id: D3
    description: "SanitaryApplicationRepository with register_sanitary_application/reverse_sanitary_application RPC calls, four read methods (property, lot, single, per-animal containment), findRecentIdenticalApplication (D-34), and five named Riverpod providers including sanitaryHistoryByAnimalProvider (D-37)"
    requirement: "SANI-05"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/sanitario/ (0 issues) + flutter test (248/248 passing, repo-wide)"
        status: pass
    human_judgment: true
    rationale: "Repository methods compile and analyze clean against the frozen model, and the query shapes (containment filter, ordering, RPC param names) are asserted structurally against 06-02's migration text, but no live Supabase call has been made — the underlying tables/RPCs are not yet applied to any database. End-to-end correctness (RLS, GIN containment returning correct rows, RPC round-trip) is owned by 06-12's pgTAP + live verification wave."

# Metrics
duration: 40min
completed: 2026-08-06
status: complete
---

# Phase 6 Plan 04: Sanitary Application Data Layer Summary

**SanitaryApplication frozen-row model with D-29 reversal-visibility/D-06 ordering helpers, a four-reason SanitaryApplicationException mapping every RPC SQLSTATE to an authored pt-BR sentence, and SanitaryApplicationRepository exposing both freeze RPCs, four read shapes, and the D-37 `sanitaryHistoryByAnimalProvider` contract Phase 8 will import unchanged**

## Performance

- **Duration:** ~40 min
- **Tasks:** 3
- **Files modified:** 4 (3 created, 1 appended)

## Accomplishments
- `sanitary_application_model.dart`: `SanitaryCompositionEntry` + `SanitaryApplication` freezed models with snake_case JSON mapping, an `isReversal` getter derived from `reversesApplicationId`, and three top-level list helpers (`sortByAppliedAtDesc`, `reversedApplicationIds`, `visibleApplications`) — the single D-29 "Mostrar estornadas" implementation every sanitary surface in waves 3-5 will call
- `sanitary_application_exception.dart`: `SanitaryApplicationErrorReason` (exactly 4 values) + `SanitaryApplicationException.fromPostgrest`/`asSanitaryException` mapping 42501/P0002/P0003/23505 to the UI-SPEC's locked pt-BR strings, passing the server's own P0002 message through verbatim
- `sanitary_application_repository.dart`: `SanitaryApplicationRepository` with `registerApplication`/`reverseApplication` RPC calls, `fetchApplicationsByProperty`/`fetchApplicationsByLot`/`fetchApplication`/`fetchSanitaryHistoryByAnimal` reads (all ordered `applied_at desc, created_at desc`), `findRecentIdenticalApplication` (D-34), and five named providers
- 6 new tests appended to `sanitary_calculations_test.dart` under a "reversal visibility and ordering (SANI-04)" group — 21/21 tests in the sanitario test directory pass, 248/248 repo-wide

## Task Commits

Each task was committed atomically:

1. **Task 1: SanitaryApplication models, visibility and ordering helpers, plus their tests** - `83f9f3b` (feat)
2. **Task 2: SanitaryApplicationException with the ERRCODE to pt-BR mapping** - `804cc61` (feat)
3. **Task 3: SanitaryApplicationRepository with both RPCs, the four reads, and the providers** - `cdce913` (feat)

**Plan metadata:** committed with this SUMMARY (worktree mode — orchestrator finalizes plan-level metadata after merge)

## Files Created/Modified
- `lib/features/sanitario/data/sanitary_application_model.dart` - `SanitaryCompositionEntry`, `SanitaryApplication` (freezed), `sortByAppliedAtDesc`, `reversedApplicationIds`, `visibleApplications`
- `lib/features/sanitario/data/sanitary_application_exception.dart` - `SanitaryApplicationErrorReason` enum, `SanitaryApplicationException`, `asSanitaryException`
- `lib/features/sanitario/data/sanitary_application_repository.dart` - `SanitaryApplicationRepository` (6 methods) + 5 providers
- `test/features/sanitario/sanitary_calculations_test.dart` - appended `_fixture` helper + 6 tests under "reversal visibility and ordering (SANI-04)"

## Decisions Made
- `SanitaryApplication` uses a private `._()` constructor alongside its freezed const factory so `isReversal` can be a getter rather than a top-level function taking the row as a parameter — mirrors `AppConfig`'s `._()` idiom (the only prior use of this pattern in the codebase), applied here for the first time to a freezed model.
- The two RPC calls (`registerApplication`, `reverseApplication`) build their params as a local `params` map and invoke `.rpc('name', params: params)` on a single source line, rather than accepting `dart format`'s default multi-line wrap (which would split the RPC name string onto its own line) — functionally identical to `AtfRepository`'s wrapped style, chosen so the plan's acceptance-criteria grep for `rpc('register_sanitary_application'` matches directly.
- `fetchApplication(id)` (single-row lookup) still applies the `applied_at`/`created_at` ordering the plan specifies for "every" read method, even though ordering a single row is a no-op at runtime — kept for acceptance-criteria compliance (`order('applied_at', ascending: false)` count ≥ 4) and consistency with the other three read methods.

## Deviations from Plan

None — plan executed exactly as written. All node-gate acceptance criteria (composition entry present in generated decoder, `visibleApplications` declared exactly once, exception case/enum-arity/factory-signature checks, zero `supabase_flutter` import in the repository, `contains(` inside the per-animal method, `order('applied_at', ascending: false)` count ≥ 4, both RPC names matched exactly once) verified directly via grep after implementation.

## Issues Encountered

None. `flutter analyze lib/features/sanitario/` reports 0 issues; `flutter analyze` repo-wide reports only 4 pre-existing issues in unrelated files (`app_config.dart`, `propriedade_repository.dart`, two test files), none touched by this plan. `flutter test` passes 248/248 repo-wide.

## User Setup Required

None - no external service configuration required. All work is Dart source; no migration was applied (06-02's migrations remain on-disk-only, owned by the 06-12 blocking wave per the phase's critical_scope_note).

## Next Phase Readiness
- The frozen-row contract (`SanitaryApplication`), the five-provider surface, and the four-reason exception vocabulary are all in place for waves 3-5 (`06-05`..`06-11`) to build the dose CRUD, registration flow, history screens, and estorno dialog against.
- `sanitaryHistoryByAnimalProvider(animalId)` is the exact D-37 signature Phase 8 will import unchanged — no further scaffolding needed on the Dart side.
- End-to-end correctness of the RPC calls, the containment lookup, and the exception mapping against live SQLSTATEs is unverified until 06-12 applies both migrations and runs `06_sanitary_test.sql` — this plan's `coverage` entries D2/D3 flag that gap explicitly for the verifier.
- Sibling plan 06-03 (parallel wave, `dose_model.dart`/`dose_repository.dart`/`propriedade_model.dart` `kgPerUa` field) was not touched by this plan, per the sibling-awareness boundary in this plan's prompt.

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-06*

## Self-Check: PASSED

All created/modified files verified present on disk (`sanitary_application_model.dart`, `sanitary_application_exception.dart`, `sanitary_application_repository.dart`, `sanitary_calculations_test.dart`, this SUMMARY). All three task commit hashes (`83f9f3b`, `804cc61`, `cdce913`) verified present in `git log --oneline --all`.
