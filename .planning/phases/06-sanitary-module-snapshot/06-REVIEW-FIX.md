---
phase: 06-sanitary-module-snapshot
fixed_at: 2026-08-07T00:00:00Z
review_path: .planning/phases/06-sanitary-module-snapshot/06-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-08-07T00:00:00Z
**Source review:** .planning/phases/06-sanitary-module-snapshot/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (fix_scope: critical_warning — CR-01, CR-02, WR-01, WR-02, WR-03; IN-* findings excluded by scope)
- Fixed: 4
- Skipped: 1

## Fixed Issues

### CR-01: RLS policy silently blocks editing/restoring an archived dose

**Files modified:** `supabase/migrations/20260810_06_sanitary_module.sql`, `supabase/tests/06_sanitary_test.sql`
**Commit:** `ae08dba`
**Applied fix:** Dropped `AND deleted_at IS NULL` from the `veterinarian_can_update_active_dose` policy's `USING` clause (migration not yet pushed — migration ledger confirmed 0/2 Phase 6 migrations applied as of 06-12-SUMMARY.md, so editing the migration file in place was safe). Added pgTAP Group 12 (7 new assertions, `plan(74)` → `plan(81)`) exercising vet A1 archiving a dose, restoring it, and editing its name while archived, so a regression of this exact bug fails the suite going forward.

### CR-02: Reversal rows show raw negative totals in the UI

**Files modified:** `lib/features/sanitario/presentation/aplicacao_detail_screen.dart`, `lib/features/sanitario/presentation/sanitario_screen.dart`, `lib/features/sanitario/presentation/sanitary_history_section.dart`
**Commit:** `701a067`
**Applied fix:** Applied `.abs()` to `animalCount`, `totalUa`, `totalVolume`, and `totalCost` at all three render call sites (`_AplicacaoHeaderCard`, `_AplicacaoCard`, `_buildLoteRow`) per the review's suggested fix, applied verbatim since the cited line ranges matched current source exactly.

### WR-01: "Ver todas" query-param seeding only fires once per SanitarioScreen lifetime

**Files modified:** `lib/features/sanitario/presentation/sanitario_screen.dart`
**Commit:** `fd69741`
**Applied fix:** Replaced the one-shot `bool _filtersSeeded` guard with a `String? _lastSeededQuery` that tracks the last-seeded raw query string and reseeds whenever `GoRouterState.of(context).uri.query` changes — adapted from the review's suggested fix but kept direct field mutation (not `setState`) to match this method's existing in-build-mutation pattern instead of introducing an extra rebuild. Removed the now-stale field doc comment referencing the old one-shot behavior.

### WR-02: "Ver estorno" recovery link reads a stale cached provider in the exact race it exists to handle

**Files modified:** `lib/features/sanitario/presentation/estornar_aplicacao_dialog.dart`
**Commit:** `96536e8`
**Applied fix:** Added `ref.invalidate(sanitaryApplicationsByLotProvider(widget.lotId))` in `_submit`'s catch block when `exception.reason == SanitaryApplicationErrorReason.alreadyReversed`, before `_error` is set — forces `_ErrorSlot`'s `ref.watch` of the same provider to refetch and find the sibling reversal row the other user just created.

## Skipped Issues

### WR-03: Existence-leak between error codes in both sanitary RPCs

**File:** `supabase/migrations/20260811_06_sanitary_rpcs.sql:39-51`, `:149-160`
**Reason:** The finding itself, and the RPC file's own header comment, both state this guard sequence (resolve row → `is_member_of` → `get_role`) deliberately mirrors the established multi-phase convention used by `register_baixa`/`add_animals_to_atf` in `20260805_05_atf_rpcs.sql`. The review's own fix note downgrades this to "low priority" and calls it "likely an accepted tradeoff rather than newly introduced risk." Folding the membership check into the initial `SELECT` in only this file would make Phase 6's RPCs inconsistent with every prior-phase RPC using the same pattern, without fixing the same characteristic in those other files — that is a codebase-wide convention change, out of scope for a single-finding fix pass. Left for a deliberate follow-up decision (or explicit user instruction) rather than a partial, phase-local deviation.
**Original issue:** Both RPCs resolve the target row/lot as `SECURITY DEFINER` before checking membership, letting a caller in one property distinguish "id doesn't exist" (`23503`) from "id exists but I'm not a member" (`42501`) for a UUID in a different tenant — a low-risk, low-value existence-enumeration channel given random v4 UUIDs.

---

_Fixed: 2026-08-07T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
