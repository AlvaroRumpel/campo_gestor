---
phase: 04-movements
verified: 2026-07-16T00:00:00Z
status: human_needed
score: 9/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 9/9
  gaps_closed:
    - "The identical raw-write bypass on lots.paddock_id (MOV-02), previously left open as a documented/accepted MVP deferral (04-CONTEXT.md, T-4-08: accept), is now CLOSED by a new BEFORE INSERT OR UPDATE trigger trg_lots_paddock_same_property on `lots` (supabase/migrations/20260717_04_lot_paddock_property_trigger.sql), mirroring trg_animals_lot_same_property exactly. Per explicit user decision (2026-07-16) the scope was reversed: T-4-08 disposition moved accept → mitigate. This was not a previously-failed must-have (it was an accepted deferral, not a gap) — recorded here as a scope expansion the user requested for this session, now closed at the code level."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Run `supabase link --project-ref <dev-project-ref>` then `supabase db push` from a machine with dev Supabase credentials, applying all FOUR unpushed Phase-4 migrations (20260519_04_movements.sql, 20260715_04_gap_move_animal_to_lot.sql, 20260716_04_animal_lot_property_trigger.sql, 20260717_04_lot_paddock_property_trigger.sql) in filename order."
    expected: "All four migrations apply cleanly; `supabase db diff` reports no drift."
    why_human: "This session's Supabase CLI is unlinked (`supabase db push --dry-run` → 'Cannot find project ref. Have you run supabase link?') and the local Postgres container is not running (`supabase status` → 'supabase_db_campo_gestor container is not running: exited'). Independently re-confirmed during this re-verification pass (both commands re-run just now). No live Postgres instance is reachable from this environment to push against."
  - test: "After the push, run `supabase test db` and confirm supabase/tests/04_movements_test.sql passes 5/5 — animals cross-property→23503, animals same-property→lives_ok, NULL-lot_id INSERT→lives_ok, lots cross-property→23503, lots same-property→lives_ok."
    expected: "pgTAP reports 5/5 assertions passed. Both throws_ok assertions (animals, lots) confirm their respective triggers reject the bypass at the trigger level, with RLS bypassed as postgres superuser — proving each trigger alone (not RLS) closes its gap."
    why_human: "Requires the live database from the item above; cannot run pgTAP against a database that does not exist yet in this environment."
  - test: "SC-4 raw-write UAT: as a two-property veterinarian, issue a raw `PATCH /rest/v1/animals?id=eq.<animalInPropertyA>` with body `{\"lot_id\":\"<lotInPropertyB>\"}` using the app's publishable key (bypassing AnimalRepository.moveAnimal and the UI entirely)."
    expected: "HTTP error response carrying SQLSTATE 23503 ('lot ... does not belong to property ... or is archived'); the animal's lot_id is unchanged."
    why_human: "Requires a live pushed database, a real two-property test account, and a raw HTTP client — the exact access-path-independent scenario 04-REVIEW.md CR-01 identified, observed against a running system, not inferred from source."
  - test: "MOV-02 raw-write UAT: as a two-property veterinarian, issue a raw `PATCH /rest/v1/lots?id=eq.<lotInPropertyA>` with body `{\"paddock_id\":\"<paddockInPropertyB>\"}` using the app's publishable key (bypassing LoteRepository.moveLot and the UI entirely)."
    expected: "HTTP error response carrying SQLSTATE 23503 ('paddock ... does not belong to property ... or is archived'); the lot's paddock_id is unchanged."
    why_human: "Requires a live pushed database, a real two-property test account, and a raw HTTP client — the exact access-path-independent scenario 04-REVIEW.md WR-02/CR-01-parallel identified, observed against a running system, not inferred from source."
  - test: "UI happy paths (MOV-01 move animal, MOV-02 move lot) end-to-end in a running app + role/archived/zero-animal gate checks + pt-BR singular/plural rendering of the animal-count info text."
    expected: "Both move dialogs complete successfully with correct SnackBars and list refreshes; buttons are hidden for non-veterinarian roles, archived lots, and lots with 0 active animals; count text reads '1 animal ativo' vs 'N animais ativos' correctly."
    why_human: "Visual/UX confirmation of a real running app; automated widget tests cover the mechanics (see Behavioral Spot-Checks) but not the human-observed end-to-end feel."
---

# Phase 4: Movements Verification Report

**Phase Goal:** Mover animal entre lotes (MOV-01), mover lote inteiro entre piquetes de forma atômica via RPC (MOV-02). ROADMAP SC-4: cross-property ANIMAL move rejected server-side. Plus (self-imposed this session, gap closure #3): the identical cross-property LOT move (MOV-02's `lots.paddock_id`) is now also rejected server-side.
**Verified:** 2026-07-16
**Status:** human_needed
**Re-verification:** Yes — after gap closure #3 (plan 04-07: lots.paddock_id cross-property trigger, MOV-02)

## What changed since the last verification pass

The prior verification (2026-07-16, status `human_needed`, 9/9) left `lots.paddock_id` cross-property enforcement as a **deliberate, user-accepted MVP deferral** (T-4-08: `accept`), not a gap — SC-4 (animals only) was already code-VERIFIED. This session's plan 04-07 reversed that scope decision per an explicit user instruction (2026-07-16): the lots-side bypass is now **closed**, not deferred.

Read directly against the current files:

1. `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` — new. Defines `enforce_lot_paddock_same_property()` + `BEFORE INSERT OR UPDATE ON lots` trigger `trg_lots_paddock_same_property`. Structurally verified line-by-line against its template, `trg_animals_lot_same_property`:
   - Guard: `NEW.paddock_id IS NOT NULL AND (TG_OP = 'INSERT' OR NEW.paddock_id IS DISTINCT FROM OLD.paddock_id OR NEW.property_id IS DISTINCT FROM OLD.property_id)` — fires on INSERT, paddock_id change, or property_id change. Correctly mirrors the animals trigger's guard shape.
   - Body: `IF NOT EXISTS (SELECT 1 FROM paddocks WHERE id = NEW.paddock_id AND property_id = NEW.property_id AND deleted_at IS NULL) THEN RAISE EXCEPTION ... USING ERRCODE = '23503'`. Correct table (`paddocks`), correct columns, correct ERRCODE, clear message.
   - The `NEW.paddock_id IS NOT NULL` guard is documented as structurally unreachable (`lots.paddock_id` is `NOT NULL` per `20260514_03_lots_animals.sql:14`) but intentionally kept for byte-for-byte symmetry with the animals template — confirmed correct and harmless (dead branch, not a defect).
   - `SECURITY INVOKER` (default, no `SECURITY DEFINER` declared) — same as the animals trigger, correct: the EXISTS check is pinned to `NEW.property_id`, so RLS cannot weaken it regardless of invoker/definer.
   - Comment correctly notes `softDeleteLot` (UPDATEs `deleted_at` only) does not re-trigger this guard — no false-positive on archival.
   - This closes exactly the bug class described in 04-REVIEW.md WR-02/CR-01-parallel: `veterinarian_can_update_active_lot`'s `WITH CHECK` (`20260514_03_lots_animals.sql:47-50`) validates only `is_member_of(property_id)` + veterinarian role and never inspects `paddock_id`, so a raw `PATCH /lots {paddock_id: <foreign paddock>}` previously succeeded. The trigger closes this on every write path (RPC, raw PATCH, future callers) because it is attached to the table, not to any caller.

2. `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` — unchanged since prior pass, re-read and re-confirmed correct (see truth #4 below).

3. `supabase/tests/04_movements_test.sql` — extended from `plan(3)` to `plan(5)`. Two new assertions added, both structurally sound:
   - Fixture: new `Paddock A2` (`99999999-...`) in property A, giving a valid same-property destination distinct from lot A1's current paddock (so the `IS DISTINCT FROM` guard is actually exercised, not skipped as a no-op).
   - Assertion 4: `UPDATE lots SET paddock_id = <paddock B> WHERE id = <lot A1>` → `throws_ok(..., '23503', ...)`. Lot A1 is in property A, paddock B is in property B — correctly exercises the cross-property rejection.
   - Assertion 5: `UPDATE lots SET paddock_id = <paddock A2> WHERE id = <lot A1>` → `lives_ok(...)`. Paddock A2 is in property A — correctly exercises the same-property success path.
   - Both new assertions reference real fixture ids already present in the file (no guessed columns); `INSERT INTO paddocks (id, property_id, name, area_ha, ua_capacity)` matches the real DDL.
   - File header comment updated to describe both gap cycles (#2 animals, #3 lots) and honestly states the suite is authored + committed but **not executed** in this environment.

4. `.planning/phases/04-movements/04-CONTEXT.md` — the `lots.paddock_id` Deferred Ideas bullet was rewritten (confirmed by direct read, line 110): "aceito como risco MVP" → **"FECHADO no gap cycle #3 (plan 04-07, decisão do usuário 2026-07-16, reversão do escopo travado anterior)"**, naming `trg_lots_paddock_same_property` and the new migration, and cross-referencing 04-REVIEW.md WR-02/CR-01-parallel. No deferral for animals or lots cross-property isolation remains open in this document.

5. `04-07-PLAN.md`'s threat register (T-4-08) records disposition `mitigate` (was `accept` in 04-06-PLAN.md) — confirmed by direct read of both plan files.

6. No Dart/Flutter files were touched by either 04-06 or 04-07 (`git show --stat` on both commits: only `.sql` and `.md` files). Full Flutter suite re-run this pass: **96/96 passed**, unchanged.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can move an individual animal to another lot of the same property; both lot compositions update immediately (ROADMAP SC-1) | ✓ VERIFIED | Unchanged since prior pass. `AnimalRepository.moveAnimal` routes through `move_animal_to_lot` RPC; tap-to-confirm path exercised by `test/widget/mover_animal_dialog_test.dart`. Full suite green (96/96, re-confirmed this pass). |
| 2 | User can move an entire lot to another paddock via a single atomic action (RPC); all animals migrate atomically, any-step failure rolls back everything (ROADMAP SC-2) | ✓ VERIFIED (code+behavior); DB push pending | Unchanged since prior pass. `move_lot_to_paddock` migration is a single-statement atomic UPDATE; tap-to-confirm path exercised by `test/widget/mover_lote_dialog_test.dart` with fetch-counting invalidation proof. RPC itself not yet applied to any live database (human verification). |
| 3 | Movements are blocked for "leitor" (reader) role (ROADMAP SC-3) | ✓ VERIFIED | Unchanged since prior pass. UI gate tests green; DB-side `get_role(...) <> 'veterinarian'` checks inside both RPCs. |
| 4 | Attempt to move an animal to a lot of a different property is rejected by RLS/RPC with a clear error (ROADMAP SC-4) | ✓ VERIFIED (code); live DB proof pending | Unchanged since prior pass, re-confirmed by direct re-read this pass. `trg_animals_lot_same_property` (`20260716_04_animal_lot_property_trigger.sql`) raises `23503` when `NEW.lot_id` points at a lot not in `NEW.property_id` or archived; fires on INSERT/lot_id-change/property_id-change; correctly skips `NEW.lot_id IS NULL`. `move_animal_to_lot` RPC additionally checks the same invariant (defense-in-depth) and carries the WR-01 `deleted_at`/`NOT FOUND` re-check. Not yet proven against a live Postgres instance (CLI unlinked, local container not running — reconfirmed independently this pass). |
| 5 (new) | Attempt to move a lot to a paddock of a different property is rejected by a trigger with a clear error, closing the identical MOV-02 raw-write bypass (self-imposed scope, gap closure #3) | ✓ VERIFIED (code); live DB proof pending | `trg_lots_paddock_same_property` (`20260717_04_lot_paddock_property_trigger.sql`), confirmed by direct read this pass: raises `23503` when `NEW.paddock_id` points at a paddock not in `NEW.property_id` or archived; fires on INSERT/paddock_id-change/property_id-change; structurally mirrors the animals trigger exactly (table/column substitutions only, verified field-by-field). `lots.paddock_id` is `NOT NULL` (confirmed `20260514_03_lots_animals.sql:14`), so the `IS NOT NULL` guard is a documented, harmless, unreachable branch kept for template symmetry. Not yet proven against a live Postgres instance — pgTAP assertions 4-5 authored (`04_movements_test.sql`) but not run (same environmental block as truth #4). |
| 6 | Picker shows all active lots of the current property except the animal's current lot; each item shows lot name + paddock name + active animal count; confirm disabled until selection (MOV-01, plan must-have) | ✓ VERIFIED | Unchanged. `test/widget/mover_animal_dialog_test.dart` — 5/5 relevant tests pass. |
| 7 | Picker shows all active paddocks of the current property except the lot's current paddock; info text with animal count shown (correct pt-BR singular/plural); confirm disabled until selection (MOV-02, plan must-have) | ✓ VERIFIED | Unchanged. `test/widget/mover_lote_dialog_test.dart` — 6/6 relevant tests pass. |
| 8 | "Mover animal" button hidden when role != veterinarian OR animal.deletedAt != null (MOV-01, plan must-have) | ✓ VERIFIED | Unchanged. `test/widget/animal_detail_screen_test.dart` — 3/3 tests pass. |
| 9 | "Mover para piquete" button hidden when role != veterinarian OR lot archived OR 0 active animals (MOV-02, plan must-have) | ✓ VERIFIED | Unchanged. `test/widget/lote_detail_screen_test.dart` — 4/4 tests pass. |
| 10 | move_lot_to_paddock RPC validates lot active + membership + veterinarian role + destination-paddock-same-property-and-active + source != destination (MOV-02, plan must-have) | ✓ VERIFIED (static) | Unchanged. Migration file contains all 5 checks with correct ERRCODEs, `SECURITY DEFINER`, correct REVOKE/GRANT. Not yet proven live (see human verification). |

**Score:** 9/9 counted must-haves verified (0 present-but-behavior-unverified); truth #5 is a new addition tracked this session and is also code-VERIFIED, bringing total observable truths to 10/10 with the same DB-live caveat that already applied to truth #4. No regressions found in any previously-verified truth.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` | `enforce_animal_lot_same_property` trigger function + `trg_animals_lot_same_property` trigger | ✓ VERIFIED | Re-read this pass, unchanged, correct. |
| `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` | `enforce_lot_paddock_same_property` trigger function + `trg_lots_paddock_same_property` trigger | ✓ VERIFIED | New. Read in full this pass — correct guard, correct EXISTS check against `paddocks`, correct ERRCODE 23503, correct message, no stub/placeholder patterns, mirrors template field-by-field. |
| `supabase/tests/04_movements_test.sql` | pgTAP: animals (3 assertions) + lots (2 assertions) = plan(5) | ✓ VERIFIED (authored) | Read in full this pass. `plan(5)` set; 5 assertions present and internally consistent with the fixture set (2 properties, 3 paddocks, 3 lots, 1+1 animals); new Paddock A2 fixture correctly gives assertion 5 a valid distinct same-property destination. Not yet executed against a live database — human verification item, honestly disclosed in the file's own header comment. |
| `.planning/phases/04-movements/04-CONTEXT.md` | Deferred Ideas records lots.paddock_id bypass as CLOSED (not deferred) | ✓ VERIFIED | Line 110, read directly: bullet rewritten to "FECHADO no gap cycle #3 (plan 04-07...)", names the trigger + migration, cross-references 04-REVIEW.md. No lingering "accepted risk" language for lots cross-property isolation. |
| `04-07-PLAN.md` threat register | T-4-08 disposition `mitigate` (was `accept`) | ✓ VERIFIED | Read directly, line 162: `T-4-08 | ... | mitigate | BEFORE INSERT OR UPDATE trigger trg_lots_paddock_same_property ... Moves from accept ... to mitigate per user decision 2026-07-16.` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `move_lot_to_paddock` RPC | `trg_lots_paddock_same_property` trigger | Both mutate `lots.paddock_id` via `UPDATE`; the trigger fires on that UPDATE regardless of caller | ✓ WIRED (code); not yet live | The RPC's own EXISTS check (`20260519_04_movements.sql`) and the trigger's EXISTS check are independent and redundant — defense-in-depth as designed, same pattern as the animals RPC/trigger pair. Not yet live. |
| Raw PostgREST `PATCH /lots` | `trg_lots_paddock_same_property` trigger | Trigger attached directly to the `lots` table, fires on any `UPDATE` regardless of the calling endpoint | ✓ WIRED (code); not yet live | This is the specific bypass path 04-REVIEW.md WR-02/CR-01-parallel identified as unprotected — now closed at the table level, independent of RLS `WITH CHECK`, which the review confirmed never inspects `paddock_id`. Live proof requires push + raw-PATCH UAT. |
| `mover_lote_dialog.dart` / `lote_repository.dart` / dialogs (all other links) | — | — | ✓ WIRED | Unchanged from prior pass — no Dart files touched by 04-06 or 04-07 (confirmed via `git show --stat` on both gap-closure commits). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full Flutter suite | `rtk flutter test` | 96/96 passed | ✓ PASS |
| Static analysis on new lots trigger | direct read of `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` | Guard fires on INSERT/paddock_id-change/property_id-change; ERRCODE 23503 present; EXISTS check against correct table/columns (`paddocks`, `id`, `property_id`, `deleted_at`); `SECURITY INVOKER` (deliberate, pinned to NEW.property_id) | ✓ PASS |
| Structural mirror check: lots trigger vs animals trigger | side-by-side read, substitution-by-substitution (animals→lots, lots→paddocks, lot_id→paddock_id) | All substitutions correct and complete; no leftover animals-table references in the lots trigger; no missed substitution | ✓ PASS |
| pgTAP fixture alignment (new assertions) | cross-referenced assertions 4-5 in `04_movements_test.sql` against fixture ids and `lots`/`paddocks` DDL | Lot A1 (property A) → paddock B (property B) correctly triggers cross-property throw; Lot A1 → new Paddock A2 (property A) correctly triggers same-property success; no guessed columns | ✓ PASS |
| Supabase CLI link/push status | `npx supabase status`, `npx supabase db push --dry-run` | `supabase_db_campo_gestor container is not running: exited` / `Cannot find project ref. Have you run supabase link?` | ✗ CONFIRMED BLOCKED (independently re-run this pass) |
| Debt-marker scan (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) on files touched by 04-07 | grep | No matches in `20260717_04_lot_paddock_property_trigger.sql`, `20260716_04_animal_lot_property_trigger.sql`, `04_movements_test.sql` | ✓ PASS |
| `git show --stat` on 04-06/04-07 commits | `git show --stat 6dfc2e5 0580a34 33c1af3 76d5831` | Only `.sql` and `.md` files touched across all four gap-closure commits — no `lib/` or `test/` files | ✓ PASS (confirms no Dart regressions possible from these plans) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist in this repo. The equivalent role is filled by the pgTAP suite (`supabase/tests/04_movements_test.sql`, run via `supabase test db`), documented above as authored-but-not-yet-executed (human verification item) — not silently credited as passing.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| MOV-01 | 04-02, 04-04, 04-05, 04-06 | Usuário pode mover animal individual para outro lote da mesma propriedade | ✓ SATISFIED | Unchanged from prior pass — happy path, role gate, and cross-property server-side rejection (SC-4) are all present and code-correct; live-DB proof is a human-verification item, not an unmet requirement. |
| MOV-02 | 04-03, 04-05, 04-07 | Usuário pode mover lote inteiro para outro piquete; todos os animais movem atomicamente via RPC | ✓ SATISFIED | RPC atomicity and wiring unchanged and correct. This session's scope addition — cross-property `paddock_id` rejection, previously an accepted deferral — is now also code-correct and closed at the trigger level, mirroring MOV-01/SC-4's fix exactly. Live-DB proof is a human-verification item, not an unmet requirement. |

No orphaned requirement IDs — REQUIREMENTS.md maps exactly MOV-01 and MOV-02 to Phase 4, both marked `Complete` (lines 128-129), both declared across plan frontmatter (including 04-07's `requirements: [MOV-02]`).

### Anti-Patterns Found

None found in the files touched by gap closure #3 (04-07): the new trigger migration, the pgTAP extension, and the CONTEXT.md update are all substantive, correctly structured, and free of debt markers, placeholders, or stub patterns. No previously-closed warnings (WR-01 through WR-04) regressed — none of the files they touch were modified by 04-06 or 04-07 beyond the SC-4/MOV-02 trigger work itself.

### Human Verification Required

See `human_verification` in frontmatter for the full structured list. Summary:

1. **Supabase schema push** — `supabase link` + `supabase db push`, now applying **FOUR** unpushed Phase-4 migrations (was three). Independently reconfirmed blocked in this environment this pass (`supabase status`: container not running; `supabase db push --dry-run`: project unlinked).
2. **pgTAP run** — `supabase test db`, confirm `04_movements_test.sql` passes **5/5** (was 3/3) — both the animals cross-property `23503` rejection (SC-4) and the new lots cross-property `23503` rejection (MOV-02) must pass, with RLS bypassed as superuser.
3. **SC-4 raw-PATCH UAT** (animals) — as a two-property veterinarian, `PATCH /rest/v1/animals {lot_id:<foreign lot>}` → must return SQLSTATE 23503.
4. **MOV-02 raw-PATCH UAT** (lots, new this pass) — as a two-property veterinarian, `PATCH /rest/v1/lots {paddock_id:<foreign paddock>}` → must return SQLSTATE 23503.
5. **UI happy paths** — MOV-01/MOV-02 move dialogs end-to-end, role/archived/zero-animal gates, pt-BR singular/plural rendering.

These are environmental (no live database reachable from this session), not code gaps — both trigger migrations were read in full this pass and are correct: guard logic, NULL/NOT-NULL handling, ERRCODEs, and the EXISTS checks against the correct tables all check out, and they mirror each other exactly where the plan required.

## Gaps Summary

No gaps. This re-verification confirms that gap closure #3 (plan 04-07) did exactly what it claimed: it added a second, structurally-mirrored `BEFORE INSERT OR UPDATE` trigger (`trg_lots_paddock_same_property`) that closes the previously-**deferred** (not previously-failed) `lots.paddock_id` cross-property bypass on `lots`, per an explicit user decision to reverse that scope. Both triggers — `trg_animals_lot_same_property` (animals, gap cycle #2) and `trg_lots_paddock_same_property` (lots, gap cycle #3) — were read in full this pass and independently confirmed to enforce their respective same-property invariants correctly: same guard shape, same EXISTS pattern against the correct target table, same ERRCODE 23503, same NULL/NOT-NULL handling appropriate to each column's own NOT NULL constraint.

`.planning/phases/04-movements/04-CONTEXT.md` no longer records any accepted/deferred cross-property isolation risk for either animals or lots — the lots bullet was rewritten to FECHADO (closed), confirmed by direct read, not by trusting the SUMMARY's claim. The threat register in 04-07-PLAN.md correctly reflects T-4-08's disposition move from `accept` to `mitigate`.

The pgTAP suite (`supabase/tests/04_movements_test.sql`) was extended from 3 to 5 assertions with a new fixture (Paddock A2) that correctly gives the same-property lot-move assertion a valid, distinct destination — the assertions are structurally sound and reference real fixture ids, but (as the file's own header comment honestly states) they have not yet been executed, because this environment's Supabase CLI remains unlinked and the local Postgres container is not running — independently re-confirmed this pass via `supabase status` and `supabase db push --dry-run`.

The Flutter test suite is confirmed unchanged and green (96/96) — neither 04-06 nor 04-07 touched any Dart source or test file (confirmed via `git show --stat` on all four gap-closure commits), so no regression risk exists from this session's work.

What remains is exclusively environmental, now covering four migrations and two raw-PATCH UAT scenarios instead of three migrations and one: no live Supabase/Postgres instance is reachable from this session. This routes to `human_needed`, not `gaps_found`, because the blocking factor is the environment, not missing or incorrect code — both the previously-verified animals trigger and the newly-added lots trigger check out on direct reading.

---

_Verified: 2026-07-16_
_Verifier: Claude (gsd-verifier)_
