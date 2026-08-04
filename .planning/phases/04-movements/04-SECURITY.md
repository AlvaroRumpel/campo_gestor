---
phase: 04
slug: movements
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-04
---

# Phase 04 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Register consolidated from the `<threat_model>` blocks of all 7 phase plans (04-01 … 04-07). Threat IDs were reused across plans for different threats; collisions are disambiguated below with an `a/b/c` suffix and the originating plan.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Flutter web client (publishable/anon key) → PostgREST RPC | Authenticated JWT but untrusted `p_animal_id` / `p_lot_id` / `p_paddock_id`. A vet who is a member of multiple properties holds a valid JWT for each. | Entity UUIDs, tenant assignment |
| Flutter web client → PostgREST raw PATCH | Client can bypass repository methods and RPCs entirely and write `animals.lot_id` / `lots.paddock_id` directly. RLS `WITH CHECK` never inspects those columns. | Tenant-scoped FK columns |
| PostgREST / RPC → Postgres tables | RLS policies + BEFORE INSERT/UPDATE triggers are the last line for cross-entity invariants. | Row writes |
| Active-property selector → viewed entity | `currentPropertyProvider` can differ from the viewed animal's `propertyId` (deep link / stale selection), so UI scoping is not a sufficient guard. | Tenant context |
| Browser → list/picker providers | Reads scoped by RLS membership policies (`members_can_read_lots`, paddocks policy from Phase 2). | Lot/paddock/animal rows |
| Test harness (Wave 0) | Local, no network, no auth. `SupabaseService()` constructed but `client` never invoked. | None |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-4-01 | Tampering / EoP | `animals.lot_id` — cross-property assignment | critical | mitigate | RPC destination check `move_animal_to_lot` ([20260715_04_gap_move_animal_to_lot.sql:65-69](supabase/migrations/20260715_04_gap_move_animal_to_lot.sql#L65-L69)) **+** defense-in-depth trigger `trg_animals_lot_same_property` ([20260716_04_animal_lot_property_trigger.sql:60](supabase/migrations/20260716_04_animal_lot_property_trigger.sql#L60)) covering raw PATCH. pgTAP [04_movements_test.sql:51](supabase/tests/04_movements_test.sql#L51). | closed |
| T-4-02 | Elevation of Privilege | Reader role invokes either move RPC | high | mitigate | `get_role(v_property_id) <> 'veterinarian' → ERRCODE 42501` in both RPCs ([20260519:50](supabase/migrations/20260519_04_movements.sql#L50), [20260715:49](supabase/migrations/20260715_04_gap_move_animal_to_lot.sql#L49)). UI `canEdit` gate is secondary ([lote_detail_screen.dart:221](lib/features/lotes/presentation/lote_detail_screen.dart#L221), [animal_detail_screen.dart:299](lib/features/animais/presentation/animal_detail_screen.dart#L299)). | closed |
| T-4-03 | Tampering | Move an archived (soft-deleted) animal or lot | high | mitigate | Source loaded `WHERE ... AND deleted_at IS NULL` → `ERRCODE 23503` ([20260519:36](supabase/migrations/20260519_04_movements.sql#L36), [20260715:35](supabase/migrations/20260715_04_gap_move_animal_to_lot.sql#L35)). UI hides button when `deletedAt != null`. | closed |
| T-4-04 | Tampering | Destination lot/paddock archived or in another property | high | mitigate | RPC `EXISTS (... property_id = v_property_id AND deleted_at IS NULL)` → `23503` ([20260519:66-70](supabase/migrations/20260519_04_movements.sql#L66-L70), [20260715:65-69](supabase/migrations/20260715_04_gap_move_animal_to_lot.sql#L65-L69)). Pickers filter archived rows via `.isFilter('deleted_at', null)` ([lote_repository.dart:142](lib/features/lotes/data/lote_repository.dart#L142), [piquete_repository.dart:22](lib/features/piquetes/data/piquete_repository.dart#L22)). | closed |
| T-4-05a *(04-02)* | Spoofing | Stale UI shows old lot after move | low | mitigate | 4 providers invalidated synchronously post-await; `oldLotId` captured **before** the async call ([mover_animal_dialog.dart:53-56](lib/features/animais/presentation/mover_animal_dialog.dart#L53-L56)). | closed |
| T-4-05b *(04-04)* | Elevation of Privilege | `move_animal_to_lot` — caller not a member | high | mitigate | `IF NOT is_member_of(v_property_id) → ERRCODE 42501` ([20260715:43-45](supabase/migrations/20260715_04_gap_move_animal_to_lot.sql#L43-L45)). | closed |
| T-4-06 | Tampering | No-op move (source == destination) | low | mitigate | `ERRCODE 23514` guard in both RPCs ([20260519:58](supabase/migrations/20260519_04_movements.sql#L58), [20260715:57](supabase/migrations/20260715_04_gap_move_animal_to_lot.sql#L57)). UI filters current target from picker. | closed |
| T-4-07a *(04-03)* | Spoofing | RPC executes despite caller losing membership mid-session | medium | mitigate | `is_member_of()` re-checked on every invocation against the current JWT `auth.uid()` ([20260519:44](supabase/migrations/20260519_04_movements.sql#L44)); SECURITY DEFINER is pinned with `SET search_path = public`. | closed |
| T-4-07b *(04-05)* | Tampering (stale cache) | `MoverLoteDialog._submit` cross-feature invalidations | low | mitigate | `animalListByPropertyProvider` + `loteListByPropertyProvider` invalidated ([mover_lote_dialog.dart:60-61](lib/features/lotes/presentation/mover_lote_dialog.dart#L60-L61)). | closed |
| T-4-08a *(04-03)* | Repudiation | No audit trail of who moved a lot | low | **accept** | Audit table deferred post-MVP (04-CONTEXT.md "Deferred Ideas"). See Accepted Risks. | closed |
| T-4-08b *(04-05)* | Repudiation / false-failure | `mounted` ordering in both dialogs | low | mitigate | `if (!mounted) return;` before every post-await `ref` use ([mover_animal_dialog.dart:51](lib/features/animais/presentation/mover_animal_dialog.dart#L51), [mover_lote_dialog.dart:54](lib/features/lotes/presentation/mover_lote_dialog.dart#L54)). | closed |
| T-4-08c *(04-06 → 04-07)* | Tampering / EoP | `lots.paddock_id` — cross-property assignment via raw PATCH | high | mitigate | Disposition reversed `accept → mitigate` per user decision 2026-07-16. Trigger `trg_lots_paddock_same_property` ([20260717_04_lot_paddock_property_trigger.sql:63](supabase/migrations/20260717_04_lot_paddock_property_trigger.sql#L63)). pgTAP [04_movements_test.sql:73](supabase/tests/04_movements_test.sql#L73). | closed |
| T-4-09 *(04-06)* | Tampering | `animals.property_id` — full column immutability | low | **accept** | Lot-alignment consequence closed by the trigger's `property_id IS DISTINCT FROM` clause; standalone property_id pinning out of scope. See Accepted Risks. | closed |
| T-4-W0-01 *(04-01)* | Tampering | Wave 0 stubs pass without implementation | low | mitigate | Tests assert symbols absent until Plans 02/03 land (`repo.moveAnimal`, `MoverAnimalDialog`) — RED enforced by compilation failure. Symbols now exist and tests are green. | closed |
| T-4-W0-02 *(04-01)* | Information Disclosure | Test fakes leak production Supabase credentials | low | **accept** | `SupabaseService()` constructed but `client` getter never invoked (all repo methods overridden); no env vars read. See Accepted Risks. | closed |
| T-4-SC *(04-04/04-05)* | Tampering | Supply chain — package installs | low | **accept** | No new npm/pub/cargo packages added across the gap-closure cycles — SQL + Dart edits only. See Accepted Risks. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` (= high) count toward `threats_open`*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-04-01 | T-4-W0-02 | Test fakes override every repo method; `SupabaseService.client` is never touched and no env var is read. Same pattern as the pre-existing `baixa_dialog_test.dart`. | Plan 04-01 | 2026-05-XX |
| AR-04-02 | T-4-08a | Movement audit trail (who/when) deferred to post-MVP; recorded in 04-CONTEXT.md "Deferred Ideas". Residual: no non-repudiation for lot/animal moves in MVP. | 04-CONTEXT.md | 2026-05-XX |
| AR-04-03 | T-4-09 | Standalone `animals.property_id` pinning out of scope this cycle. Residual bounded: RLS still requires membership in the target property, and the cross-property lot consequence is closed by `trg_animals_lot_same_property`. | Plan 04-06 | 2026-07-16 |
| AR-04-04 | T-4-SC | No new third-party dependencies introduced in Phase 4 — nothing to audit. | Plans 04-04 / 04-05 | 2026-07-15 |

*Accepted risks do not resurface in future audit runs.*

---

## Residual Verification Items

Not blocking threats — deployment/observation gaps carried into UAT:

- Trigger + RPC mitigations are verified **in source and pgTAP**. Live confirmation on the cloud project (`campo_gestor`, deployed in `c084403`) is tracked by the 8 outstanding UAT items in [04-UAT.md](.planning/phases/04-movements/04-UAT.md) (4 migrations, 2 raw-PATCH probes).
- T-4-08c's raw-PATCH rejection on `lots` was the last gap closed (gap cycle #3) and has had the least live exercise.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-04 | 16 | 16 | 0 | /gsd-secure-phase (orchestrator, ASVS L1 grep-depth) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-04
