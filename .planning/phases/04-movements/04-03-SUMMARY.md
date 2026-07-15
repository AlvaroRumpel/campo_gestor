---
phase: 04-movements
plan: 03
subsystem: database
tags: [flutter, riverpod, supabase, migration, rpc, movements, plpgsql]

requires:
  - phase: 04-movements
    provides: "Wave 0 red test scaffolds (lote_repository_test.dart moveLot contract, mover_lote_dialog_test.dart, lote_detail_screen_test.dart) gating this plan; loteListByPropertyProvider plain-provider pattern established in Plan 04-02"
provides:
  - "move_lot_to_paddock(uuid, uuid) plpgsql RPC — SECURITY DEFINER, atomic single-row UPDATE with 5 validations"
  - "LoteRepository.moveLot — calls the RPC"
  - "MoverLoteDialog widget (480w, 320h paddock picker, excludes current paddock)"
  - "'Mover para piquete' OutlinedButton.icon on LoteDetailScreen header, gated canEdit && lot.deletedAt == null && activeAnimalCount > 0"
affects: [05-reproductive-module, 06-sanitary-module, 08-animal-dossier]

tech-stack:
  added: []
  patterns:
    - "RPC validation order established by move_lot_to_paddock: existence+active check first (via SELECT ... WHERE deleted_at IS NULL), then membership, then role, then business-rule guards (source!=dest), then cross-entity FK alignment — matches create_lot_with_animals template from Phase 3"
    - "Dialog result contract: MoverLoteDialog returns Map<String,String>? ({'paddockName': name}) on success / null on cancel, mirroring MoverAnimalDialog's {'lotName': ...} pattern from Plan 04-02 — parent screen owns the SnackBar"

key-files:
  created:
    - supabase/migrations/20260519_04_movements.sql
    - lib/features/lotes/presentation/mover_lote_dialog.dart
  modified:
    - lib/features/lotes/data/lote_repository.dart
    - lib/features/lotes/presentation/lote_detail_screen.dart
    - test/widget/lote_form_dialog_test.dart

key-decisions:
  - "Task 5 (supabase db push) could not be executed — this session's Supabase CLI is unlinked/unauthenticated (`supabase db push --dry-run` fails with 'Cannot find project ref. Have you run supabase link?'). Marked BLOCKED per plan's own escape hatch; migration file is authored and verified on disk, RPC body reviewed against the create_lot_with_animals template."

patterns-established:
  - "_FakeLoteRepository (implements LoteRepository, in lote_form_dialog_test.dart) must gain a stub override every time a new method is added to LoteRepository — flagged here because this is the second plan in a row (04-02, 04-03) to trip this; a future refactor to `extends` + selective override, or a shared test double, would remove this recurring maintenance tax."

requirements-completed: [MOV-02]

coverage:
  - id: D1
    description: "move_lot_to_paddock RPC migration: SECURITY DEFINER, validates lot active, membership, veterinarian role, source!=destination, destination active+same-property; REVOKE public + GRANT authenticated"
    requirement: "MOV-02"
    verification:
      - kind: other
        ref: "node acceptance-check script over supabase/migrations/20260519_04_movements.sql — all 9 required substrings present"
        status: pass
    human_judgment: true
    rationale: "Migration file content is verified on disk (static check) but the RPC has NOT been applied to a live Postgres instance in this session — supabase db push could not authenticate (see Deviations). A human must run the push and re-verify pg_proc + exercise the RPC live before this deliverable is fully proven."
  - id: D2
    description: "LoteRepository.moveLot({lotId, newPaddockId}) calling move_lot_to_paddock RPC"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "test/features/lotes/lote_repository_test.dart — 'moveLot exists and is callable (MOV-02 contract)'"
        status: pass
    human_judgment: false
  - id: D3
    description: "MoverLoteDialog: title with lot name, animal-count info text, disabled confirm until paddock selected, current paddock excluded from picker"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "test/widget/mover_lote_dialog_test.dart — MoverLoteDialog (MOV-02) group, 4 tests"
        status: pass
    human_judgment: false
  - id: D4
    description: "'Mover para piquete' button gate on LoteDetailScreen: visible for veterinarian on active lot with >0 active animals, hidden for reader, hidden when archived, hidden when 0 active animals"
    requirement: "MOV-02"
    verification:
      - kind: unit
        ref: "test/widget/lote_detail_screen_test.dart — LoteDetailScreen Mover para piquete button group, 4 tests"
        status: pass
    human_judgment: false
  - id: D5
    description: "End-to-end move flow (confirm → RPC call → provider invalidation → SnackBar with destination paddock name) against a live Supabase dev project, plus RPC-level rejection of cross-property/role-escalation attempts"
    verification: []
    human_judgment: true
    rationale: "Requires the migration applied to a live dev Postgres instance with a veterinarian session and 2+ paddocks/lots — not exercisable from widget-level Riverpod-override tests. Task 5 (schema push) is BLOCKED pending manual `supabase db push` from a machine with dev credentials; this must run before any UAT for MOV-02."

duration: 20min
completed: 2026-07-15
status: complete
---

# Phase 4 Plan 03: Move Lot to Another Paddock Summary

**move_lot_to_paddock atomic RPC (5-validation SECURITY DEFINER plpgsql function) wired through LoteRepository.moveLot, a new MoverLoteDialog paddock picker, and a 4th-condition-gated button on LoteDetailScreen; schema push to dev Supabase left BLOCKED pending manual credentials.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-15T22:25:00Z (approx, continuing directly after 04-02)
- **Completed:** 2026-07-15T22:45:00Z
- **Tasks:** 5 (4 completed, 1 BLOCKED — manual push pending)
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `move_lot_to_paddock(p_lot_id, p_paddock_id)` — SECURITY DEFINER plpgsql RPC in a new migration. Validates, in order: lot exists + active, caller membership (`is_member_of`), caller role = veterinarian (`get_role`), source paddock ≠ destination (no-op guard), destination paddock belongs to same property + is active. Raises `ERRCODE 42501` (permission), `23503` (FK/not-found), or `23514` (check violation) on failure. `REVOKE ALL ... FROM public` + `GRANT EXECUTE ... TO authenticated`.
- `LoteRepository.moveLot({lotId, newPaddockId})` — thin wrapper calling `_service.client.rpc('move_lot_to_paddock', params: {...})`.
- `MoverLoteDialog` — 480px AlertDialog, 320px-max-height scrollable paddock picker (via existing `paddockListProvider`) excluding the lot's current paddock, info text `"{N} animais serão transferidos... A operação é atômica — ou todos movem ou nenhum."`, confirm disabled until a paddock is picked. On success invalidates `loteByIdProvider`, both old and new `loteListByPaddockProvider` (D-12), returns `{'paddockName': name}`.
- `LoteDetailScreen` / `_LoteHeaderCard` — new `OutlinedButton.icon` "Mover para piquete" (swap_horiz icon), footer-right aligned, gated `canEdit && lot.deletedAt == null && activeCount > 0`; on dialog success invalidates `loteByIdProvider(loteId)` and shows `SnackBar('Lote movido para {paddockName}')`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create migration with move_lot_to_paddock RPC** - `92bc4e8` (feat)
2. **Task 2: Add LoteRepository.moveLot method calling the RPC** - `bd458bf` (feat)
3. **Task 3: Create MoverLoteDialog widget** - `d0c042d` (feat)
4. **Task 4: Wire 'Mover para piquete' button into _LoteHeaderCard** - `d337d28` (feat)
4b. **Fix: _FakeLoteRepository missing overrides for new LoteRepository methods** - `a90abd4` (fix, see Deviations)
5. **Task 5: [BLOCKING] Apply Supabase schema push** - **BLOCKED — manual push pending** (no commit; see below)

_Note: Tasks 2–4 are `type="auto" tdd="true"` against pre-existing Wave 0 RED tests — no separate test/feat/refactor commits were needed since the tests already existed from Plan 04-01._

## Task 5 Status: BLOCKED — manual push pending

This execution session runs with an **unauthenticated, non-interactive Supabase CLI** — no TTY for a DB password and no linked project ref. Verification:

```
$ supabase db push --dry-run
Cannot find project ref. Have you run supabase link?
```

Per the plan's own escape hatch (Task 5 action block, final paragraph), this is an accepted BLOCKED outcome, not a plan failure. Tasks 1–4 (migration file authored on disk + Dart implementation + all Wave 0 gate tests green) are the completable deliverable in this environment.

**Verifier instructions — REQUIRED as the first step of any MOV-02 UAT:**
1. From a machine with dev Supabase credentials, run `supabase link --project-ref <dev-project-ref>` (if not already linked) then `supabase db push`.
2. Confirm the function landed: `supabase db remote query "SELECT proname FROM pg_proc WHERE proname = 'move_lot_to_paddock';"` — expect one row.
3. Only then proceed with the manual UAT steps in `04-03-PLAN.md`'s `<verification>` block (steps 1–9).

## Files Created/Modified
- `supabase/migrations/20260519_04_movements.sql` - New migration: `move_lot_to_paddock` RPC (SECURITY DEFINER, 5 validations, REVOKE/GRANT)
- `lib/features/lotes/data/lote_repository.dart` - `moveLot({lotId, newPaddockId})` method
- `lib/features/lotes/presentation/mover_lote_dialog.dart` - New `MoverLoteDialog` + private `_PaddockPickerList` widgets
- `lib/features/lotes/presentation/lote_detail_screen.dart` - `_LoteHeaderCard` gains `canEdit`/`onMover` params + footer button; call site wires `MoverLoteDialog` + SnackBar
- `test/widget/lote_form_dialog_test.dart` - `_FakeLoteRepository` gains stub overrides for `fetchLotsWithCountByProperty` and `moveLot` (Rule 1 fix, see Deviations)

## Decisions Made
- **Task 5 marked BLOCKED rather than attempting repeated pushes or inventing credentials** — the environment has no TTY and no linked project; retrying would not change the outcome and risks masking a real blocker behind noisy failed attempts. One `--dry-run` attempt was sufficient to confirm the CLI is unlinked.
- **`_FakeLoteRepository` maintenance tax flagged** — this `implements LoteRepository` test double in `lote_form_dialog_test.dart` has now needed a stub-override patch in both 04-02 (`fetchLotsWithCountByProperty`) and 04-03 (`moveLot`). Documented as a `patterns-established` note for whoever next touches `LoteRepository`'s public surface; not fixed here (out of this plan's scope to refactor the test double's inheritance strategy).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `_FakeLoteRepository` in lote_form_dialog_test.dart missing overrides, breaking full-suite compile**
- **Found during:** Post-Task-4 full regression run (`flutter test`)
- **Issue:** `test/widget/lote_form_dialog_test.dart` defines `class _FakeLoteRepository implements LoteRepository`. Because `implements` requires every abstract member, this broke as soon as `LoteRepository` gained `fetchLotsWithCountByProperty` (Plan 04-02) and `moveLot` (this plan, Task 2) — the file failed to compile, taking down the entire `flutter test` run (1 compile-failing file, `Some tests failed.`). This predates this plan (04-02 already introduced the first missing method) but was only surfaced now because this is the first time the full suite was run since 04-02 landed.
- **Fix:** Added `@override Future<List<LotWithPaddockCount>> fetchLotsWithCountByProperty(String propertyId) async => [];` and `@override Future<void> moveLot({required String lotId, required String newPaddockId}) async {}` stubs to `_FakeLoteRepository`.
- **Files modified:** test/widget/lote_form_dialog_test.dart
- **Verification:** `flutter test test/widget/lote_form_dialog_test.dart` — 5/5 pass; full `flutter test` — 93/93 pass (was failing to compile before the fix).
- **Committed in:** `a90abd4` (fix, after Task 4 commit)

---

**Total deviations:** 1 auto-fixed (1 bug, blocking full-suite compile)
**Impact on plan:** Necessary to restore a green full-suite baseline before handoff. No scope creep — only added missing interface stubs, no behavior change to `LoteFormDialog` itself.

## Issues Encountered
Task 5 (schema push) could not complete in this session — see "Task 5 Status" above. This is an accepted, plan-sanctioned outcome, not an unresolved issue; explicit verifier instructions are provided.

## User Setup Required

**Manual Supabase schema push required before UAT.** No `USER-SETUP.md` was generated (single blocking step, documented inline above):
1. Run `supabase link --project-ref <dev-project-ref>` (if not already linked) from a machine with dev Supabase credentials.
2. Run `supabase db push`.
3. Verify: `supabase db remote query "SELECT proname FROM pg_proc WHERE proname = 'move_lot_to_paddock';"` — expect one row.

## Next Phase Readiness
- Phase 4 (Movements) plans 01–03 are all code-complete: MOV-01 (move animal) and MOV-02 (move lot) both fully implemented and test-green.
- **Blocker for Phase 4 UAT:** the `move_lot_to_paddock` migration is authored but not yet applied to the dev Supabase project. `/gsd-verify-work` for MOV-02 cannot exercise the live RPC path until a human runs the push (see "User Setup Required").
- Full regression: `flutter test` — 93/93 passing, including all Phase 3 (lots/animals) and Phase 4 (MOV-01, MOV-02) suites.
- `flutter analyze` clean on all 5 touched files except one pre-existing, out-of-scope warning (`test/widget/lote_form_dialog_test.dart:4` — unused `animal_model.dart` import, present before this plan, not caused by this plan's changes — left untouched per scope boundary).
- No other blockers.

---
*Phase: 04-movements*
*Completed: 2026-07-15*

## Self-Check: PASSED

All 5 code/test files + SUMMARY.md verified present on disk. All 5 task commit hashes (92bc4e8, bd458bf, d0c042d, d337d28, a90abd4) verified present in git log.
