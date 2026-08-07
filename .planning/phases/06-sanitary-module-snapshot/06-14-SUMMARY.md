---
phase: 06-sanitary-module-snapshot
plan: 14
subsystem: api
tags: [flutter, riverpod, supabase, postgrest, jsonb, dart]

# Dependency graph
requires:
  - phase: 06-sanitary-module-snapshot
    provides: sanitary_applications schema, composition_snapshot jsonb GIN index, SANI-05 per-animal history query
provides:
  - "fetchSanitaryHistoryByAnimal sends a valid JSON containment filter (cs.[{\"animal_id\":\"<uuid>\"}]) instead of a malformed Postgres array literal"
  - "App-wide providerRetryPolicy on ProviderScope stops retrying deterministic PostgrestException failures, letting error branches render on first failure"
affects: [08-consolidated-ficha]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Request-level regression test via a loopback dart:io HttpServer + directly constructed SupabaseClient, instead of mocking the query-builder chain — for asserting the exact wire-level filter string postgrest-dart emits"
    - "App-wide Riverpod retry policy: classify PostgrestException as non-transient (no retry), delegate everything else to ProviderContainer.defaultRetry"

key-files:
  created:
    - test/features/sanitario/sanitary_application_repository_test.dart
    - test/core/retry_policy_test.dart
  modified:
    - lib/features/sanitario/data/sanitary_application_repository.dart
    - lib/main.dart

key-decisions:
  - "jsonEncode the containment value before calling .contains() so postgrest-dart's String branch forwards it verbatim, instead of letting the List branch stringify it via Map.toString into an invalid Postgres array literal"
  - "Retry policy is a public top-level function (providerRetryPolicy) tear-off passed to ProviderScope.retry, keeping the ProviderScope construction const and the function independently testable without a widget harness"
  - "Retry policy delegates to ProviderContainer.defaultRetry rather than reimplementing backoff, so only the PostgrestException branch changes and every other failure keeps framework-default behavior"

patterns-established:
  - "Loopback HttpServer + directly-constructed SupabaseClient harness for repository tests that must assert wire-level request shape (query params, filter encoding) without mocking the Supabase query-builder chain"

requirements-completed: [SANI-05]

coverage:
  - id: D1
    description: "fetchSanitaryHistoryByAnimal sends the composition_snapshot containment filter as valid JSON (cs.[{\"animal_id\":\"<uuid>\"}]), matching the GIN jsonb_path_ops index shape, instead of the malformed Postgres array literal that produced 22P02"
    requirement: SANI-05
    verification:
      - kind: unit
        ref: "test/features/sanitario/sanitary_application_repository_test.dart#fetchSanitaryHistoryByAnimal sends the containment filter as JSON (G-06-9)"
        status: pass
    human_judgment: false
  - id: D2
    description: "App-wide provider retry policy returns null (no retry) for a PostgrestException and delegates ordinary exceptions to Riverpod's default backoff, so a deterministic backend error reaches its error branch on the first attempt instead of spinning through ~10 retries"
    requirement: SANI-05
    verification:
      - kind: unit
        ref: "test/core/retry_policy_test.dart#providerRetryPolicy (G-06-9) returns null for a PostgrestException — no retry"
        status: pass
      - kind: unit
        ref: "test/core/retry_policy_test.dart#providerRetryPolicy (G-06-9) delegates an ordinary Exception to ProviderContainer.defaultRetry"
        status: pass
    human_judgment: false
  - id: D3
    description: "Manual UAT re-run: open an animal ficha with at least one sanitary application and confirm the Histórico Sanitário section resolves to rows; open one with none and confirm it resolves to the empty-state sentence rather than spinning"
    verification: []
    human_judgment: true
    rationale: "Requires a live Supabase connection and a real browser render — the plan itself defers this to the UAT re-run, not to this executor"

duration: 35min
completed: 2026-08-07
status: complete
---

# Phase 06 Plan 14: Fix G-06-9 Animal Ficha Histórico Sanitário Spinner Summary

**Encoded the per-animal sanitary-history containment filter as JSON via `jsonEncode` (fixing the 22P02 Postgres parse error) and added an app-wide Riverpod retry policy that stops retrying `PostgrestException`s, so deterministic backend errors reach the UI's error branch on the first attempt.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 completed
- **Files modified:** 4 (2 source, 2 new test files)

## Accomplishments
- `fetchSanitaryHistoryByAnimal` now sends `composition_snapshot=cs.[{"animal_id":"<uuid>"}]`, valid JSON the GIN `jsonb_path_ops` index serves, instead of the Map.toString-stringified Postgres array literal that produced PostgREST 22P02
- A request-level regression test (loopback `HttpServer` + directly constructed `SupabaseClient`, no query-builder mocking) proves the emitted filter parses as JSON and structurally matches `[{"animal_id": "<uuid>"}]`
- A new public `providerRetryPolicy` wired into `ProviderScope.retry` returns `null` for any `PostgrestException` (no retry) and delegates every other error to `ProviderContainer.defaultRetry`, so the Histórico Sanitário section's error branch renders on the first deterministic failure instead of after ~10 retries behind a spinner
- Both fixes are covered by RED→GREEN TDD commits; `flutter analyze` is clean and the full 262-test suite passes

## Task Commits

Each task was committed with a RED test commit followed by a GREEN implementation commit:

1. **Task 1: Encode the containment filter as JSON** — `4381738` (test), `be02d59` (fix)
2. **Task 2: Stop retrying deterministic PostgREST failures app-wide** — `17877d6` (test), `23b1d86` (fix)

**Plan metadata:** committed as part of this SUMMARY (worktree mode — orchestrator finalizes docs commit after merge)

_Note: Both tasks are TDD (`tdd="true"`); each has a RED test commit and a GREEN implementation commit, confirmed red-before-green by manually reverting each implementation and re-running its test before restoring the fix._

## Files Created/Modified
- `lib/features/sanitario/data/sanitary_application_repository.dart` — `fetchSanitaryHistoryByAnimal` now `jsonEncode`s the containment value; `dart format` also reformatted two unrelated RPC calls in the same file (no behavior change)
- `test/features/sanitario/sanitary_application_repository_test.dart` — new request-level regression test (loopback HTTP server, no query-builder mocking)
- `lib/main.dart` — added public `providerRetryPolicy(retryCount, error)` and wired it into `ProviderScope(retry: providerRetryPolicy, ...)`
- `test/core/retry_policy_test.dart` — new unit test covering both retry-policy branches

## Decisions Made
- `jsonEncode` the containment list before passing it to `.contains()` so postgrest-dart's String branch (which forwards the value verbatim) is used instead of its List branch (which stringifies elements via Dart's `Map.toString`, producing invalid JSON) — this is the only change to the query; select/order/mapping are untouched
- Made `providerRetryPolicy` a public top-level function so `test/core/retry_policy_test.dart` can call it directly without a widget harness, while its tear-off keeps `ProviderScope(...)` a const expression
- Delegated the non-PostgrestException branch to `ProviderContainer.defaultRetry` rather than reimplementing backoff — keeps the change to exactly the classification logic the plan asked for

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ran `build_runner` to generate missing freezed/json_serializable output**
- **Found during:** Task 1, first `flutter test` run
- **Issue:** No `*.freezed.dart` or `*.g.dart` files existed anywhere in `lib/` in this worktree checkout, so the entire `sanitary_application_model.dart` failed to compile (constructors, `fromJson`, and generated getters all missing) before the new test could even run
- **Fix:** Ran `flutter pub run build_runner build` to generate the missing codegen output (pre-existing, unrelated to this plan's source changes; not committed as part of a task — codegen output is `.gitignore`d in this project)
- **Files modified:** none tracked (generated files are gitignored)
- **Verification:** `flutter analyze` and `flutter test` both compile and run afterward

---

**Total deviations:** 1 auto-fixed (1 blocking — missing codegen output, unrelated to this plan's edits)
**Impact on plan:** No scope creep; codegen was a pre-existing environment gap in this worktree that blocked any test run, not something introduced by this plan.

## Issues Encountered
None beyond the codegen gap documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- G-06-9 is closed: `flutter analyze` clean on touched files, full 262-test suite passes, both new regression tests pass
- Manual UAT re-run (open an animal ficha with and without applications) is deferred to the UAT pass per the plan's own verification section — not something this executor can perform without a live Supabase connection
- No blockers for Phase 8's consolidated ficha, which imports `AnimalSanitaryHistorySection` unchanged (D-37 contract, untouched by this plan)

---
*Phase: 06-sanitary-module-snapshot*
*Completed: 2026-08-07*
