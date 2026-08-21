---
phase: 04-movements
plan: 04
subsystem: database
tags: [flutter, riverpod, supabase, migration, rpc, movements, plpgsql, multi-tenancy]

requires:
  - phase: 04-movements
    provides: "move_lot_to_paddock RPC template (20260519_04_movements.sql) and its Dart .rpc() call pattern (LoteRepository.moveLot) established in Plans 04-01/02/03"
provides:
  - "move_animal_to_lot(uuid, uuid) plpgsql RPC — SECURITY DEFINER, atomic single-row UPDATE with 6 validations including cross-property destination check"
  - "AnimalRepository.moveAnimal — now routes through the RPC instead of a bare PostgREST UPDATE"
affects: [05-reproductive-module, 06-sanitary-module, 08-animal-dossier]

tech-stack:
  added: []
  patterns:
    - "move_animal_to_lot mirrors move_lot_to_paddock's validation order exactly (existence+active, membership, role, no-op guard, cross-entity destination-property+active check, atomic UPDATE) — second instance of this RPC template, now an established pattern for guarded cross-entity writes"

key-files:
  created:
    - supabase/migrations/20260715_04_gap_move_animal_to_lot.sql
  modified:
    - lib/features/animais/data/animal_repository.dart

key-decisions:
  - "Task 3 (supabase db push) could not be executed — this session's Supabase CLI is unlinked/unauthenticated (`supabase db push --dry-run` fails with 'Cannot find project ref. Have you run supabase link?'), same as 04-03. Marked BLOCKED per the plan's own escape hatch after one attempt; migration file is authored and verified on disk."
  - "moveAnimal re-fetches the animal row after the RPC call (RPC returns void) to preserve the public Future<Animal> contract — avoids touching test fakes/callers outside this plan's scope (04-05 owns those files)."

patterns-established: []

requirements-completed: [MOV-01]

coverage:
  - id: D1
    description: "move_animal_to_lot RPC migration: SECURITY DEFINER, validates source animal active, membership, veterinarian role, no-op guard, destination lot same-property+active; REVOKE public + GRANT authenticated"
    requirement: "MOV-01"
    verification:
      - kind: other
        ref: "grep -cE substring check over supabase/migrations/20260715_04_gap_move_animal_to_lot.sql — all 14 required substrings present"
        status: pass
    human_judgment: true
    rationale: "Migration file content is verified on disk (static check) but the RPC has NOT been applied to a live Postgres instance in this session — supabase db push is unlinked/unauthenticated (see Deviations). A human must run the push and re-verify pg_proc + exercise the RPC live (including a cross-property rejection attempt) before this deliverable is fully proven."
  - id: D2
    description: "AnimalRepository.moveAnimal({id, newLotId}) calling move_animal_to_lot RPC, public signature and re-fetch preserved"
    requirement: "MOV-01"
    verification:
      - kind: unit
        ref: "test/features/animais/animal_repository_test.dart — 5/5 pass"
        status: pass
      - kind: unit
        ref: "test/widget/mover_animal_dialog_test.dart — 4/4 pass"
        status: pass
      - kind: other
        ref: "flutter analyze lib/features/animais/data/animal_repository.dart — No issues found"
        status: pass
      - kind: other
        ref: "flutter test (full suite) — 93/93 passed"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-07-16
status: complete
---

# Phase 4 Plan 04: Cross-Property Move Enforcement (Gap Closure) Summary

**move_animal_to_lot SECURITY DEFINER RPC closing the SC-4 gap (moveAnimal previously did a bare UPDATE with no destination-property check); AnimalRepository.moveAnimal rewired to call it with signature preserved; schema push to dev Supabase left BLOCKED pending manual credentials, same as 04-03.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-16T00:00:00Z (approx)
- **Completed:** 2026-07-16T00:25:00Z
- **Tasks:** 3 (2 completed with commits, 1 BLOCKED — manual push pending, no commit)
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- `move_animal_to_lot(p_animal_id, p_lot_id)` — new SECURITY DEFINER plpgsql RPC. Validates, in order: source animal exists + active, caller membership (`is_member_of`), caller role = veterinarian (`get_role`), source lot ≠ destination lot (no-op guard), **destination lot belongs to the same property as the animal AND is active** (the SC-4 fix — the check that was previously missing entirely). Raises `ERRCODE 23503` (not-found/archived, x2), `42501` (permission, x2), or `23514` (check violation) on failure. `REVOKE ALL ... FROM public` + `GRANT EXECUTE ... TO authenticated`.
- `AnimalRepository.moveAnimal` — public signature unchanged (`Future<Animal> moveAnimal({required String id, required String newLotId})`); body now calls `_service.client.rpc('move_animal_to_lot', params: {...})` then re-fetches the row by id to preserve the `Future<Animal>` contract. Doc comment rewritten: no longer frames cross-property moves as an "accepted MVP gap" — it now documents the RPC's server-side enforcement and references MOV-01/ROADMAP SC-4/T-4-01, explicitly superseding D-04.
- ROADMAP.md Success Criterion 4 ("tentativa de mover animal para lote de propriedade diferente é rejeitada pelo RLS/RPC com erro claro") is now satisfied server-side by the new RPC — the previously-failed 04-VERIFICATION.md truth #4 / 04-REVIEW.md CR-01 finding is closed at the code level, pending live DB push (see Task 3 status).

## Task Commits

1. **Task 1: Author move_animal_to_lot SECURITY DEFINER RPC (new migration)** - `aca8b2a` (feat)
2. **Task 2: Rewire AnimalRepository.moveAnimal to call the RPC** - `cf5a4dc` (feat)
3. **Task 3: [BLOCKING] Push both Phase-4 migrations to the dev DB** - **BLOCKED — manual push pending** (no commit; see below)

## Task 3 Status: BLOCKED — manual push pending

This execution session runs with an **unauthenticated, non-interactive Supabase CLI** — no TTY for a DB password and no linked project ref, identical to the 04-03 finding. Verification (single attempt, per plan's escape hatch — not retried):

```
$ supabase db push --dry-run
Cannot find project ref. Have you run supabase link?
```

Per the plan's own escape hatch (Task 3 action block), this is an accepted BLOCKED outcome, not a plan failure. Tasks 1–2 (both migration files authored on disk + Dart implementation, both fully committed) are the completable deliverable in this environment.

**Verifier instructions — REQUIRED as the first step of any SC-4 / MOV-01 / MOV-02 UAT:**
1. From a machine with dev Supabase credentials (Docker running), run `supabase link --project-ref <dev-project-ref>` then `supabase db push`. This applies **both** unpushed Phase-4 migrations together:
   - `supabase/migrations/20260519_04_movements.sql` (`move_lot_to_paddock`, still unpushed per 04-03/04-VERIFICATION.md)
   - `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` (`move_animal_to_lot`, new in this plan)
2. Confirm both functions landed: `supabase db remote query "SELECT proname FROM pg_proc WHERE proname IN ('move_lot_to_paddock','move_animal_to_lot') ORDER BY proname;"` — expect two rows.
3. Only then proceed with live UAT, including the ROADMAP SC-4 cross-property rejection check: attempt to move an animal to a lot in a different property and confirm the RPC raises `ERRCODE 23503` with the "belongs to a different property" message.

## Files Created/Modified
- `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` - New migration: `move_animal_to_lot` RPC (SECURITY DEFINER, 6 validations including cross-property destination check, REVOKE/GRANT)
- `lib/features/animais/data/animal_repository.dart` - `moveAnimal` rewired to call the RPC + re-fetch; doc comment updated to reflect server-side enforcement (D-04 superseded)

## Decisions Made
- **Task 3 marked BLOCKED after one attempt, not retried** — the environment has no TTY and no linked project; a second attempt would not change the outcome. Mirrors the 04-03 precedent exactly.
- **moveAnimal re-fetches instead of returning the RPC's own result** — `move_animal_to_lot` returns `void` (matching `move_lot_to_paddock`'s pattern), so the Dart method issues a follow-up `select().eq('id', id).single()` to keep its `Future<Animal>` return type stable for existing callers/tests, keeping this plan's blast radius to one file.

## Deviations from Plan

None - plan executed exactly as written, including the pre-authorized BLOCKED escape hatch for Task 3.

## Issues Encountered

Task 3 (schema push) could not complete in this session — see "Task 3 Status" above. This is an accepted, plan-sanctioned outcome, not an unresolved issue; explicit verifier instructions are provided and mirror the 04-03 precedent (both migrations must be pushed together).

## User Setup Required

**Manual Supabase schema push required before UAT.** No `USER-SETUP.md` generated (single blocking step, documented inline above):
1. Run `supabase link --project-ref <dev-project-ref>` (if not already linked) from a machine with dev Supabase credentials.
2. Run `supabase db push` — applies both `20260519_04_movements.sql` and `20260715_04_gap_move_animal_to_lot.sql`.
3. Verify: `supabase db remote query "SELECT proname FROM pg_proc WHERE proname IN ('move_lot_to_paddock','move_animal_to_lot') ORDER BY proname;"` — expect two rows.

## Next Phase Readiness
- ROADMAP Phase 4 Success Criterion 4 (cross-property move rejection) is now code-complete: `move_animal_to_lot` RPC authored with the destination-property check that was previously entirely absent; `moveAnimal` routes through it.
- Full regression: `flutter test` — 93/93 passing (includes all previously-existing Phase 3/4 suites plus the two named 04-04 target tests).
- `flutter analyze lib/features/animais/data/animal_repository.dart` — no issues.
- **Blocker for live SC-4 UAT (same root cause as MOV-02's 04-03 blocker):** neither `move_lot_to_paddock` nor `move_animal_to_lot` is applied to any live database in this environment. A human must run `supabase link` + `supabase db push` before either RPC can be exercised end-to-end. This is now a single combined push covering both Phase-4 migrations.
- No other blockers. Plan 04-05 (dialog + tests work referenced in the 04-VERIFICATION.md behavior_unverified_items — tap-to-confirm paths, provider invalidation, WR-01/02/03/04 findings) is unaffected by this plan's changes and remains separately scoped.

---
*Phase: 04-movements*
*Completed: 2026-07-16*

## Self-Check: PASSED

All 3 files (migration, animal_repository.dart, SUMMARY.md) verified present on disk. All 3 commit hashes (aca8b2a, cf5a4dc, a7bcbf6) verified present in git log.
