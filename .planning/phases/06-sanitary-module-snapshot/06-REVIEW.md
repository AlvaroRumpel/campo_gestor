---
phase: 06-sanitary-module-snapshot
reviewed: 2026-08-07T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - supabase/migrations/20260812_06_fix_dose_update_policy.sql
  - lib/features/sanitario/data/sanitary_application_repository.dart
  - lib/main.dart
  - test/features/sanitario/sanitary_application_repository_test.dart
  - test/core/retry_policy_test.dart
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase 6: Code Review Report (scoped re-review — 06-13/06-14 gap closure)

**Reviewed:** 2026-08-07T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Scoped re-review of the two gap-closure plans only: 06-13 (forward-only `doses` UPDATE
RLS policy fix) and 06-14 (jsonb containment filter JSON-encoding fix + app-wide
`PostgrestException` retry suppression).

Both fixes were independently verified against the actual dependency source, not just
read for plausibility:

- **06-13 migration**: `DROP POLICY IF EXISTS` + `CREATE POLICY` body verbatim-matches
  `20260810_06_sanitary_module.sql:47-49`, confirmed idempotent on fresh environments, and
  is already backed by a pgTAP regression (`supabase/tests/06_sanitary_test.sql` Group 12,
  lines 546-575) that archives a dose, restores it, and edits it while archived — exactly
  the scenario the live-PROD drift broke. No issues found.
- **06-14 `.contains()` fix**: verified against `postgrest-2.7.0`'s actual
  `PostgrestFilterBuilder.contains()` implementation
  (`postgrest_filter_builder.dart:267-281`). Confirmed the original `List` argument hit the
  array-literal branch (`_cleanFilterArray`, curly-brace Postgres array syntax — invalid
  for a jsonb array), and the `jsonEncode(...)` fix hits the `String` branch, which forwards
  the value verbatim as `cs.<value>` — producing valid jsonb array syntax on the wire. The
  regression test captures the real HTTP request via a loopback server rather than mocking
  the query builder, which is the right level to catch this class of bug. No issues found
  here either.

One real gap surfaced in the 06-14 retry policy: it is broader than the "statement
timeout" ceiling the code's own doc comment calls out — see WR-01.

## Warnings

### WR-01: `providerRetryPolicy` also kills retry for transient infra failures, not just deterministic ones

**File:** `lib/main.dart:41-44`

**Issue:** The policy blanket-suppresses retry for *every* `PostgrestException`:

```dart
Duration? providerRetryPolicy(int retryCount, Object error) {
  if (error is PostgrestException) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}
```

The doc comment above it already flags one ceiling (a Postgres `statement_timeout`
surfaces as `PostgrestException` and gets misclassified). Tracing into
`postgrest-2.7.0`'s `_parseResponse` (`postgrest_builder.dart:325-348`) shows the
misclassification is broader than that single case: **any non-2xx HTTP response** —
including a 502/503/504 from Supabase's edge/gateway, a PgBouncer connection-pool
refusal, or a cold-start timeout — is wrapped into a `PostgrestException` too. When the
error body isn't parseable JSON (exactly what an infra-layer HTML error page or a bare
gateway timeout returns), the code falls into the generic `catch (_)` branch
(`postgrest_builder.dart:340-344`) and still throws `PostgrestException` with the HTTP
status code as `code`.

postgrest-dart's own internal retry (`_executeWithRetry`, lines 204-238) only covers
GET/HEAD requests for status `{503, 520}`, for a maximum of 3 attempts before the
response even reaches `_parseResponse`. Every other transient-but-not-that response
shape — and every RPC/mutation call, which is POST and gets zero internal retries by
design — depends entirely on the Riverpod-level retry to recover. `providerRetryPolicy`
now takes that away for the exact class of error (infra transients) the fix's own doc
comment says should "still get [ProviderContainer.defaultRetry]'s backoff." This
directly undermines the stated intent of G-06-9, not just an accepted edge case: a
`sanitaryApplicationListByPropertyProvider` read (idempotent GET) that hits a momentary
502 during a Supabase deploy now fails on the first attempt with no backoff, instead of
recovering silently as it did before this fix (when it *would* retry, just wastefully
for the deterministic-error case the fix was written for).

**Fix:** Distinguish deterministic PostgREST/Postgres errors (a real SQLSTATE or a
4xx-shaped PostgREST error code — malformed filter, RLS denial, constraint violation)
from HTTP-transport-shaped codes, and only suppress retry for the former:

```dart
Duration? providerRetryPolicy(int retryCount, Object error) {
  if (error is PostgrestException) {
    // PostgREST/Postgres error codes are 4-5 digit SQLSTATEs or PostgREST's own
    // codes (PGRST...); a bare HTTP status string ('502', '503', '504') means the
    // request never reached Postgres — that's transport-transient, not deterministic.
    final code = error.code;
    final isTransportStatus =
        code != null && RegExp(r'^(50[0-9]|52[0-9])$').hasMatch(code);
    if (!isTransportStatus) return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}
```

Adjust the regex/allowlist to whatever `code` values are actually observed in
practice — the point is not to treat every `PostgrestException` as equivalent.

## Info

### IN-01: `fetchApplication` orders a single-row query before `.maybeSingle()`

**File:** `lib/features/sanitario/data/sanitary_application_repository.dart:70-80`

**Issue:** Not part of the 06-13/06-14 diff, but visible in the reviewed file:

```dart
Future<SanitaryApplication?> fetchApplication(String id) async {
  final row = await _service.client
      .from('sanitary_applications')
      .select()
      .eq('id', id)
      .order('applied_at', ascending: false)
      .order('created_at', ascending: false)
      .maybeSingle();
  ...
```

`id` is the primary key, so at most one row can ever match `.eq('id', id)`. The two
`.order()` calls are dead — they can't change which row comes back — and read as if
multiple rows were expected here, which is misleading to a future reader mirroring this
method for a non-unique filter.

**Fix:** Drop both `.order()` calls; they do nothing given a PK-equality filter.
