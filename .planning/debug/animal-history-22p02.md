---
status: resolved
trigger: "G-06-9: Animal ficha Histórico Sanitário — PostgREST 22P02 'invalid input syntax for type json, Expected \":\", but found \"}\"' on composition_snapshot containment query; infinite spinner with ~10 retries"
created: 2026-08-07T00:00:00Z
updated: 2026-08-07T00:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — postgrest-dart's .contains() treats a Dart List value as a Postgres ARRAY literal (`cs.{...}` via _cleanFilterArray, which stringifies each element with Map.toString), never JSON-encoding it. The animal-history query passes `[{'animal_id': id}]`, producing the malformed filter `cs.{"{animal_id: <uuid>}"}`.
test: Read postgrest-2.7.0 source (contains + _cleanFilterArray) and reproduced the exact generated filter string with a standalone Dart script
expecting: n/a — hypothesis confirmed, root cause found
next_action: none — goal is find_root_cause_only; hand off to plan-phase --gaps

reasoning_checkpoint:
  hypothesis: "fetchSanitaryHistoryByAnimal passes a Dart List to .contains(); postgrest-2.7.0 encodes List values as Postgres array literals ('cs.{...}' with Map.toString elements), yielding non-JSON that Postgres rejects with 22P02"
  confirming_evidence:
    - "postgrest_filter_builder.dart:273-275 — `value is List` branch emits 'cs.{${_cleanFilterArray(value)}}', never json.encode"
    - "postgrest_builder.dart:413-419 — _cleanFilterArray wraps non-num elements as '\"$s\"' — Dart Map.toString, unquoted keys, no JSON colons-in-strings"
    - "Standalone Dart repro prints exactly: cs.{\"{animal_id: 123e4567-...}\"} — Postgres parsing '{\"{animal_id: ...}\"}' as JSON hits open-brace, string key, then '}' where ':' is expected — verbatim the observed error 'Expected \":\", but found \"}\"'"
  falsification_test: "If the request URL had contained valid JSON (cs.[{\"animal_id\":\"...\"}]) the error would be impossible; the repro shows it cannot — the List branch is unconditional"
  fix_rationale: "n/a — diagnose-only mode; fix direction recorded in Resolution"
  blind_spots: "Did not replay the request against live Supabase (not needed — encoding is deterministic and error text matches exactly)"

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Animal ficha's Histórico Sanitário loads real rows via PostgREST cs (contains) filter `composition_snapshot @> [{"animal_id": "<uuid>"}]` served by GIN jsonb_path_ops index on sanitary_applications.composition_snapshot
actual: DevTools Network shows repeated failing GETs to sanitary_applications?select=... Each returns 22P02. Histórico Sanitário section stuck on infinite spinner, ~10 retries visible.
errors: 'PostgREST/Postgres 22P02 — invalid input syntax for type json, details: Expected ":", but found "}".' — the JSON literal in the filter is malformed
reproduction: Test 9 in .planning/phases/06-sanitary-module-snapshot/06-UAT.md — open any animal detail (ficha) with app against live Supabase, watch Network tab
started: Discovered during UAT 2026-08-07. Lote-level history (same shared widget, different provider/query) works fine — only the per-animal containment path fails.

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: Widget passes wrong provider/args (AnimalSanitaryHistorySection at fault)
  evidence: sanitary_history_section.dart:48-50 correctly watches sanitaryHistoryByAnimalProvider(widget.animalId); the lote variant watches sanitaryApplicationsByLotProvider — widget layer is correct
  timestamp: 2026-08-07
- hypothesis: Server-side issue (index, column type, RLS) breaks containment
  evidence: Error is 22P02 JSON *parse* failure of the filter literal itself, before any planning/index use; lote path (.eq, no containment) works against the same table
  timestamp: 2026-08-07

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-07
  checked: .planning/debug/knowledge-base.md
  found: does not exist — no known-pattern candidates
  implication: proceed with fresh hypothesis formation
- timestamp: 2026-08-07
  checked: lib/features/sanitario/data/sanitary_application_repository.dart:85-99
  found: fetchSanitaryHistoryByAnimal calls .contains('composition_snapshot', [{'animal_id': animalId}]) — a Dart List<Map>
  implication: filter value shape depends entirely on how postgrest-dart encodes a List
- timestamp: 2026-08-07
  checked: pubspec.lock
  found: postgrest 2.7.0 (transitive via supabase_flutter 2.12.4); flutter_riverpod 3.3.1
  implication: inspect postgrest-2.7.0 source; Riverpod 3 (not 2.x as CLAUDE.md claims) — v3 auto-retry defaults apply
- timestamp: 2026-08-07
  checked: pub cache postgrest-2.7.0/lib/src/postgrest_filter_builder.dart:267-281
  found: contains() — String passes through; List → 'cs.{${_cleanFilterArray(value)}}' (Postgres array literal); only non-String non-List → json.encode. A List NEVER gets JSON-encoded.
  implication: jsonb array containment via a Dart List is impossible with this API — must pre-encode to a JSON string
- timestamp: 2026-08-07
  checked: pub cache postgrest-2.7.0/lib/src/postgrest_builder.dart:413-419
  found: _cleanFilterArray wraps each non-num element as '"$s"' — interpolation calls Map.toString(), producing {animal_id: uuid} (no quoted keys, no JSON)
  implication: generated filter is cs.{"{animal_id: <uuid>}"}
- timestamp: 2026-08-07
  checked: standalone Dart repro of the library's exact encoding logic (scratchpad/repro_cs_filter.dart)
  found: 'query param value : cs.{"{animal_id: 123e4567-e89b-12d3-a456-426614174000}"}' — Postgres then parses {"{animal_id: ...}"} as JSON: open object, string key, then '}' where ':' is required
  implication: exact reproduction of observed error 'Expected ":", but found "}"' / 22P02 — root cause confirmed
- timestamp: 2026-08-07
  checked: lib/features/sanitario/presentation/sanitary_history_section.dart:42-91
  found: widget is correct; error branch exists ('Erro ao carregar histórico sanitário.'). flutter_riverpod 3.3.1's default automatic retry (~10 attempts, exponential backoff) re-executes the failing FutureProvider — matches "~10 retries visible" and keeps the section in loading between attempts
  implication: infinite-spinner/retry behavior is Riverpod 3 default retry on a deterministic (non-transient) failure — secondary finding, not the gap's root cause

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: |
  In fetchSanitaryHistoryByAnimal (lib/features/sanitario/data/sanitary_application_repository.dart:88-95), the jsonb containment filter is built with `.contains('composition_snapshot', [{'animal_id': animalId}])`. postgrest-dart 2.7.0 encodes any List value as a Postgres ARRAY literal — `cs.{${_cleanFilterArray(value)}}` — and _cleanFilterArray stringifies each element via Dart's Map.toString(). The request therefore carries `composition_snapshot=cs.{"{animal_id: <uuid>}"}`. For a jsonb column, Postgres parses the cs value as JSON: `{` opens an object, `"{animal_id: <uuid>}"` reads as a string key, and the next character is `}` where `:` is required → 22P02 "invalid input syntax for type json — Expected \":\", but found \"}\"". Only a String value bypasses this encoding (passed through verbatim); a List can never express jsonb-array containment with this client API.
fix: |
  (Not applied — diagnose-only.) Direction: pass a pre-encoded JSON string so postgrest's String branch forwards it verbatim:
    .contains('composition_snapshot', jsonEncode([{'animal_id': animalId}]))
  → produces composition_snapshot=cs.[{"animal_id":"<uuid>"}], the exact @> shape the GIN jsonb_path_ops index serves.
  Secondary (optional): 22P02 is deterministic — Riverpod 3's default retry pointlessly re-issues it ~10 times; consider retry: null/custom on the provider or global retry policy for non-transient PostgrestExceptions.
verification: |
  APPLIED. lib/features/sanitario/data/sanitary_application_repository.dart:88-104 now calls
  `.contains('composition_snapshot', jsonEncode([{'animal_id': animalId}]))` with the G-06-9
  rationale recorded inline (lines 90-93). The String branch forwards the pre-encoded JSON
  verbatim, producing `cs.[{"animal_id":"<uuid>"}]` — the @> shape the GIN jsonb_path_ops index
  serves. Confirmed live by Phase 8 UAT (08-UAT.md, 15/15 pass, 2026-08-11): the animal ficha's
  Histórico Sanitário renders real rows with no spinner and no 22P02.
  Secondary (Riverpod retry) also addressed — main.dart carries an app-wide providerRetryPolicy
  (see 08-03 decision in STATE.md).
files_changed:
  - lib/features/sanitario/data/sanitary_application_repository.dart
closed: 2026-08-11 (milestone v1.0 close)
