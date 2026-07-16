---
phase: 04-movements
verified: 2026-07-16T00:00:00Z
status: human_needed
score: 9/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 5/9
  gaps_closed:
    - "Tentativa de mover animal para lote de propriedade diferente é rejeitada pelo RLS/RPC com erro claro (ROADMAP SC-4) — now enforced by BEFORE INSERT OR UPDATE trigger trg_animals_lot_same_property on `animals`, access-path-independent (RPC, raw PostgREST PATCH, any future caller). Migration: supabase/migrations/20260716_04_animal_lot_property_trigger.sql."
    - "MoverAnimalDialog tap-to-confirm success path (SnackBar + provider invalidations) — now exercised by test/widget/mover_animal_dialog_test.dart#'tapping Confirmar movimentação submits the move and shows the success SnackBar (IN-01)'."
    - "MoverLoteDialog tap-to-confirm success path (SnackBar + 5 provider invalidations, including the two WR-01/WR-02 additions) — now exercised by test/widget/mover_lote_dialog_test.dart#'tapping Confirmar movimentação submits the move, invalidates animalListByPropertyProvider + loteListByPropertyProvider, and shows the success SnackBar (IN-01, proves WR-01/WR-02)', using fetch-counting probes that fail if either invalidation is removed."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Run `supabase link --project-ref <dev-project-ref>` then `supabase db push` from a machine with dev Supabase credentials, applying all three unpushed Phase-4 migrations (20260519_04_movements.sql, 20260715_04_gap_move_animal_to_lot.sql, 20260716_04_animal_lot_property_trigger.sql) in filename order."
    expected: "All three migrations apply cleanly; `supabase db diff` reports no drift."
    why_human: "This session's Supabase CLI is unlinked (`supabase db push --dry-run` → 'Cannot find project ref. Have you run supabase link?') and Docker Desktop is unreachable (`supabase status` fails with a named-pipe connect error). Independently re-confirmed during this verification pass. No live Postgres instance is reachable from this environment to push against."
  - test: "After the push, run `supabase test db` and confirm supabase/tests/04_movements_test.sql passes 3/3 — cross-property lot_id UPDATE throws 23503, same-property lot_id UPDATE succeeds, NULL-lot_id INSERT succeeds."
    expected: "pgTAP reports 3/3 assertions passed, with the cross-property throws_ok assertion confirming trg_animals_lot_same_property actually rejects the bypass at the trigger level (RLS bypassed as postgres superuser, so this proves the trigger alone closes the gap)."
    why_human: "Requires the live database from the item above; cannot run pgTAP against a database that does not exist yet in this environment."
  - test: "Log in as a veterinarian who is a member of two properties (Property A active, Property B not active) and issue a raw `PATCH /rest/v1/animals?id=eq.<animalInPropertyA>` with body `{\"lot_id\":\"<lotInPropertyB>\"}` using the app's publishable key (bypassing AnimalRepository.moveAnimal and the UI entirely)."
    expected: "HTTP error response carrying SQLSTATE 23503 ('lot ... does not belong to property ... or is archived'); the animal's lot_id is unchanged."
    why_human: "Requires a live pushed database (see above), a real two-property test account, and a raw HTTP client — this is the exact access-path-independent scenario 04-REVIEW.md CR-01 identified as the unclosed door, and it must be observed against a running system, not inferred from source."
---

# Phase 4: Movements Verification Report

**Phase Goal:** Mover animal entre lotes (MOV-01), mover lote inteiro entre piquetes de forma atômica via RPC (MOV-02).
**Verified:** 2026-07-16
**Status:** human_needed
**Re-verification:** Yes — after gap closure #2 (SC-4 trigger, plan 04-06)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can move an individual animal to another lot of the same property; both lot compositions update immediately (ROADMAP SC-1) | ✓ VERIFIED | `AnimalRepository.moveAnimal` routes through `move_animal_to_lot` RPC (`lib/features/animais/data/animal_repository.dart:178-192`). Tap-to-confirm path is now exercised by an actual test: `test/widget/mover_animal_dialog_test.dart` — "tapping Confirmar movimentação submits the move and shows the success SnackBar (IN-01)" asserts `repo.capturedId`/`capturedNewLotId`, dialog dismissal, and SnackBar text. Full suite green (96/96). |
| 2 | User can move an entire lot to another paddock via a single atomic action (RPC); all animals migrate atomically, any-step failure rolls back everything (ROADMAP SC-2) | ✓ VERIFIED (code+behavior); DB push pending | `move_lot_to_paddock` migration (`supabase/migrations/20260519_04_movements.sql`) is a single-statement atomic UPDATE with 5 validations. Tap-to-confirm path exercised by `test/widget/mover_lote_dialog_test.dart` — "tapping Confirmar movimentação submits the move, invalidates animalListByPropertyProvider + loteListByPropertyProvider, and shows the success SnackBar (IN-01, proves WR-01/WR-02)" using fetch-counting probes (`animalFetchCount`/`loteFetchCount` go from 1→2, proving the invalidations actually trigger refetches, not just declare them). RPC itself is not yet applied to any live database in this environment (see human verification). |
| 3 | Movements are blocked for "leitor" (reader) role (ROADMAP SC-3) | ✓ VERIFIED | UI gate tests green (`animal_detail_screen_test.dart`, `lote_detail_screen_test.dart`). DB: `veterinarian_can_update_active_animal` RLS policy + `get_role(...) <> 'veterinarian'` check inside both `move_animal_to_lot` and `move_lot_to_paddock` reject non-veterinarian roles server-side. |
| 4 | Attempt to move an animal to a lot of a different property is rejected by RLS/RPC with a clear error (ROADMAP SC-4) | ✓ VERIFIED (code); live DB proof pending | `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` defines `enforce_animal_lot_same_property()`, a `BEFORE INSERT OR UPDATE ON animals` trigger (`trg_animals_lot_same_property`) that raises `ERRCODE 23503` when `NEW.lot_id IS NOT NULL` and no row exists in `lots` with `id = NEW.lot_id AND property_id = NEW.property_id AND deleted_at IS NULL`. Fires on INSERT, on any `lot_id` change, and on any `property_id` change — closes the exact CR-01 bypass (raw PostgREST `PATCH` skipping the RPC), since the trigger runs on **every** write path, independent of RLS. `move_animal_to_lot` RPC (`20260715_04_gap_move_animal_to_lot.sql`) additionally checks the same invariant itself (defense-in-depth, fast clear error before the trigger even fires) and was amended for WR-01 (final `UPDATE` now `AND deleted_at IS NULL` + `IF NOT FOUND` guard, closing a TOCTOU where a concurrent `registerBaixa` archives the animal mid-move). `NEW.lot_id IS NULL` is correctly excluded from the guard (unassigned animals remain valid). `animals.property_id` is `NOT NULL` (confirmed in `20260508_02_property_paddock.sql:119`), so the trigger's property comparison can never spuriously pass/fail on a null. Not yet proven against a live Postgres instance — pgTAP suite authored (`supabase/tests/04_movements_test.sql`, 3 assertions) but not run (CLI unlinked, Docker unreachable, reconfirmed independently in this pass). |
| 5 | Picker shows all active lots of the current property except the animal's current lot; each item shows lot name + paddock name + active animal count; confirm disabled until selection (MOV-01, plan must-have) | ✓ VERIFIED | `test/widget/mover_animal_dialog_test.dart` — 5/5 relevant tests pass (title, buttons, disabled-confirm, current-lot exclusion, submit flow). |
| 6 | Picker shows all active paddocks of the current property except the lot's current paddock; info text with animal count shown (correct pt-BR singular/plural); confirm disabled until selection (MOV-02, plan must-have) | ✓ VERIFIED | `test/widget/mover_lote_dialog_test.dart` — 6/6 relevant tests pass (title, info text with count incl. WR-04 singular fix, disabled-confirm, current-paddock exclusion, submit flow). |
| 7 | "Mover animal" button hidden when role != veterinarian OR animal.deletedAt != null (MOV-01, plan must-have) | ✓ VERIFIED | `test/widget/animal_detail_screen_test.dart` — 3/3 tests pass. |
| 8 | "Mover para piquete" button hidden when role != veterinarian OR lot archived OR 0 active animals (MOV-02, plan must-have) | ✓ VERIFIED | `test/widget/lote_detail_screen_test.dart` — 4/4 tests pass. |
| 9 | move_lot_to_paddock RPC validates lot active + membership + veterinarian role + destination-paddock-same-property-and-active + source != destination (MOV-02, plan must-have) | ✓ VERIFIED (static) | Migration file contains all 5 checks with correct ERRCODEs (42501, 23503, 23514), `SECURITY DEFINER`, `REVOKE ALL ... FROM public` + `GRANT EXECUTE ... TO authenticated`. Not yet proven live (see human verification). |

**Score:** 9/9 truths verified (0 present-but-behavior-unverified). All must-haves have code-level and (where applicable) automated-behavioral evidence. Three items remain that only a live pushed database can prove — routed to human verification, not counted as gaps because the enforcement code itself is present, correct, and independently reviewed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/animais/data/animal_repository.dart` | `moveAnimal` routes through `move_animal_to_lot` RPC | ✓ VERIFIED | Lines 178-192: `_service.client.rpc('move_animal_to_lot', params: {...})`, then re-fetches and returns the updated row. Doc comment correctly describes server-side enforcement and supersession of the earlier direct-UPDATE approach. |
| `lib/features/lotes/data/lote_repository.dart` | `moveLot` RPC call | ✓ VERIFIED | Unchanged from prior pass; still correct. |
| `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` | `move_animal_to_lot` RPC | ✓ VERIFIED | Present, substantive: membership check, role check, source≠destination guard, same-property/active destination-lot check, WR-01-amended final UPDATE (`AND deleted_at IS NULL` + `IF NOT FOUND` raise), correct REVOKE/GRANT. |
| `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` | `enforce_animal_lot_same_property` trigger function + `trg_animals_lot_same_property` trigger | ✓ VERIFIED | Present, substantive: correct guard condition (skips NULL lot_id, fires on INSERT/lot_id-change/property_id-change), correct ERRCODE 23503, clear error message, mirrors the project's existing `prevent_snapshot_mutation` idiom. Confirmed by direct read — no stub patterns, no placeholder logic. |
| `supabase/tests/04_movements_test.sql` | pgTAP: cross-property→23503, same-property ok, NULL ok | ✓ VERIFIED (authored) | 3 assertions present and structurally correct (`plan(3)`, `throws_ok(... '23503' ...)`, 2× `lives_ok`, `finish()`, wrapped in `BEGIN`/`ROLLBACK`). Fixture INSERTs align with actual table DDL (checked against `20260514_03_lots_animals.sql` and `20260508_02_property_paddock.sql`). Not yet executed against a live database — human verification item. |
| `lib/features/animais/presentation/mover_animal_dialog.dart` | `MoverAnimalDialog` widget | ✓ VERIFIED | Present, wired, tap-to-confirm path now covered by test. |
| `lib/features/animais/presentation/animal_detail_screen.dart` | 3rd action button + onMover wiring | ✓ VERIFIED | Unchanged from prior pass; gated `isActive && canEdit`, SnackBar wired. |
| `lib/features/lotes/presentation/mover_lote_dialog.dart` | `MoverLoteDialog` widget | ✓ VERIFIED | WR-01/WR-02 invalidations added and test-proven (fetch-counting probe); WR-03 mounted-guard reordered; WR-04 pt-BR singular/plural fixed. |
| `lib/features/lotes/presentation/lote_detail_screen.dart` | `_LoteHeaderCard.canEdit/onMover` + button | ✓ VERIFIED | Unchanged from prior pass. |
| `.planning/phases/04-movements/04-CONTEXT.md` | Deferred Ideas records the lots.paddock_id bypass as accepted MVP risk | ✓ VERIFIED | Line 110: bullet documents `veterinarian_can_update_active_lot` never inspecting `paddock_id`, references 04-REVIEW.md WR-02/CR-01-parallel, notes the remedy (same trigger pattern on `lots`) for a future cycle. Matches the intentional-deferral scope stated in the plan (animals only, this cycle). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `animal_detail_screen.dart` | `mover_animal_dialog.dart` | `showDialog<Map<String,String>>(... MoverAnimalDialog(animal: animal))` | ✓ WIRED | Confirmed. |
| `mover_animal_dialog.dart` | `animal_repository.dart` | `ref.read(animalRepositoryProvider).moveAnimal(...)` | ✓ WIRED | Confirmed. |
| `animal_repository.dart` | `move_animal_to_lot` RPC | `_service.client.rpc('move_animal_to_lot', params: {'p_animal_id': id, 'p_lot_id': newLotId})` | ✓ WIRED (code); not yet live | Correct param names match the RPC signature `(p_animal_id uuid, p_lot_id uuid)`. Function does not exist in any live database yet — see human verification. |
| `move_animal_to_lot` RPC | `trg_animals_lot_same_property` trigger | Both mutate `animals.lot_id` via `UPDATE`; the trigger fires on that UPDATE regardless of caller | ✓ WIRED (code) | The RPC's own EXISTS check and the trigger's EXISTS check are independent, redundant, and both correct — defense-in-depth as designed. Not yet live. |
| `lote_detail_screen.dart` | `mover_lote_dialog.dart` | `showDialog<Map<String,String>>(... MoverLoteDialog(lot: lot, ...))` | ✓ WIRED | Confirmed. |
| `mover_lote_dialog.dart` | `lote_repository.dart` | `ref.read(loteRepositoryProvider).moveLot(...)` | ✓ WIRED | Confirmed. |
| `mover_lote_dialog.dart` | 5 providers on success | `ref.invalidate(...)` × 5 (3 original + WR-01/WR-02's `animalListByPropertyProvider` + `loteListByPropertyProvider`) | ✓ WIRED | Proven by fetch-counting test, not just declared (see truth #2 evidence). |
| `lote_repository.dart` | `supabase/migrations/20260519_04_movements.sql` | `_service.client.rpc('move_lot_to_paddock', ...)` | ⚠️ PARTIAL (not live) | Dart-side call correct; server-side function not yet applied to any live DB in this environment. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full Flutter suite | `rtk flutter test` | 96/96 passed | ✓ PASS |
| Static analysis on trigger migration | direct read of `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` | NULL-lot_id skip present; ERRCODE 23503 present; fires on INSERT/lot_id-change/property_id-change; SECURITY INVOKER (deliberate — pinned to NEW.property_id so RLS can't weaken it) | ✓ PASS |
| Static analysis on WR-01 amendment | direct read of `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` lines 72-83 | `AND deleted_at IS NULL` present on final UPDATE; `IF NOT FOUND THEN RAISE EXCEPTION ... 23503` present | ✓ PASS |
| pgTAP fixture alignment | cross-referenced `supabase/tests/04_movements_test.sql` INSERT column lists against `lots`/`animals`/`paddocks` DDL | All INSERTs use real columns (no guessed columns); 2 properties, 2 paddocks, 3 lots (2 in property A, 1 in property B), 1 animal in lot A1 | ✓ PASS |
| Supabase CLI link/push status | `npx supabase status`, `npx supabase db push --dry-run` | "failed to inspect container health ... dockerDesktopLinuxEngine" / "Cannot find project ref. Have you run supabase link?" | ✗ CONFIRMED BLOCKED (independently reconfirmed this pass, matches 04-06-SUMMARY.md) |
| Debt-marker scan (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) on all files touched since prior verification | grep | No matches in `20260716_04_animal_lot_property_trigger.sql`, `20260715_04_gap_move_animal_to_lot.sql` (post-amend), `04_movements_test.sql`, `mover_lote_dialog.dart`, `mover_animal_dialog.dart` | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist in this repo, and no plan/SUMMARY references a probe script by that convention. The equivalent role in this phase is filled by the pgTAP suite (`supabase/tests/04_movements_test.sql`, run via `supabase test db`), which is documented above as authored-but-not-yet-executed (human verification item) — not silently credited as passing.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| MOV-01 | 04-02, 04-04, 04-05, 04-06 | Usuário pode mover animal individual para outro lote da mesma propriedade | ✓ SATISFIED | Happy path, role gate, and cross-property server-side rejection (SC-4) are all present and code-correct; SC-4's live-DB proof is a human-verification item, not an unmet requirement. |
| MOV-02 | 04-03, 04-05 | Usuário pode mover lote inteiro para outro piquete; todos os animais movem atomicamente via RPC | ✓ SATISFIED | RPC is atomic, well-validated, and correctly wired; dialog invalidations fixed and test-proven. Not yet deployed to a live database — human-verification item, not an unmet requirement. |

No orphaned requirement IDs — REQUIREMENTS.md maps exactly MOV-01 and MOV-02 to Phase 4, both marked `Complete` (lines 128-129), both declared across plan frontmatter.

### Anti-Patterns Found

None found in the files touched by gap closure #2 (04-05, 04-06). The prior pass's blocker finding — the `animal_repository.dart` doc comment self-documenting an "accepted MVP gap" that contradicted SC-4 — no longer applies: the doc comment now correctly states the RPC enforces cross-property rejection server-side (lines 170-177), and that claim is now backed by the trigger as well.

The prior pass's warnings (WR-01/WR-02 missing invalidations, WR-03 mounted-before-invalidate ordering, WR-04 pt-BR plural bug) were all closed in plan 04-05 and are test-proven — see truths #1/#2 and key-link evidence above.

### Human Verification Required

See `human_verification` in frontmatter for the full structured list. Summary:

1. **Supabase schema push** — `supabase link` + `supabase db push` from a machine with dev credentials, applying all three unpushed Phase-4 migrations. Independently reconfirmed blocked in this environment (Docker unreachable, project unlinked).
2. **pgTAP run** — `supabase test db`, confirm `04_movements_test.sql` passes 3/3, proving `trg_animals_lot_same_property` rejects cross-property moves at the trigger level (with RLS bypassed as superuser — the exact scenario CR-01 identified).
3. **Raw-PATCH UAT** — as a two-property veterinarian, issue a raw `PATCH /rest/v1/animals` with a foreign-property `lot_id` and confirm SQLSTATE 23503 is returned. This is the definitive proof that SC-4 is closed access-path-independently, not just at the RPC/UI layer.

These three items are environmental (no live database reachable from this session), not code gaps — the enforcement code (trigger + RPC) was read in full and is correct: guard logic, NULL-skip, ERRCODEs, and REVOKE/GRANT all check out. All are also required before the phase can be considered UAT-complete.

## Gaps Summary

No gaps. ROADMAP Phase 4 Success Criterion 4 — previously FAILED in the initial verification pass — is now closed at the code level by an access-path-independent database trigger (`trg_animals_lot_same_property`), which fixes the exact bypass identified in 04-REVIEW.md CR-01 (a raw PostgREST `PATCH` skipping the `move_animal_to_lot` RPC entirely). The trigger fires on every write path because it is attached to the table itself, not to any particular caller — this is the correct architectural fix for a gap that a voluntary RPC could never fully close, and it was verified here by direct reading of the SQL, not by trusting the SUMMARY's claim.

Both previously-flagged behavior-unverified truths (MoverAnimalDialog and MoverLoteDialog tap-to-confirm success paths) are now backed by real, regression-sensitive widget tests authored in plan 04-05 — confirmed by reading the test assertions and by the plan's own documented manual regression check (temporarily removing an invalidation call and confirming the test fails).

What remains is exclusively environmental: no live Supabase/Postgres instance is reachable from this session (Docker Desktop down, CLI unlinked — reconfirmed independently in this pass, not just cited from a prior SUMMARY). Three migrations are authored, reviewed, and internally consistent but unproven against a running database. This routes to `human_needed`, not `gaps_found`, because the blocking factor is the environment, not missing or incorrect code.

The identical raw-write bypass on `lots.paddock_id` (MOV-02) remains open by deliberate, documented, user-accepted scope decision (04-CONTEXT.md Deferred Ideas, 04-06 threat model T-4-08: `accept`) — this is an intentional deferral, not a gap, and is not re-litigated here.

---

_Verified: 2026-07-16_
_Verifier: Claude (gsd-verifier)_
