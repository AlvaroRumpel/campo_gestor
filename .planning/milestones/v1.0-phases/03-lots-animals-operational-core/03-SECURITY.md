---
phase: 03
slug: lots-animals-operational-core
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-19
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Flutter UI → Supabase PostgREST | All reads/writes go through the supabase_flutter client under JWT auth | Animal and lot CRUD payloads, animal numbers, search queries |
| Flutter UI → Postgres RPC | Batch creation and number generation via SECURITY DEFINER functions | p_property_id, p_paddock_id, p_name, category quantities, start number |
| Postgres RLS | Row-level policies enforce property membership and veterinarian role for every table mutation | lots INSERT/UPDATE, animals INSERT/UPDATE; SELECT gated by is_member_of() |
| SECURITY DEFINER RPCs | create_lot_with_animals and generate_animal_number run with elevated privilege; caller identity re-validated inside via is_member_of() + get_role() | Lot and animal rows created in a single advisory-locked transaction |
| Client state → URL / analytics | Search/filter state held in Flutter StatefulWidget memory only | Animal numbers, filter values — never serialized to URL or sent externally |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-3-01 | Tampering | lots INSERT — horizontal privilege escalation | mitigate | RLS policy `veterinarian_can_insert_lot` uses `WITH CHECK (is_member_of(property_id) AND get_role(property_id) = 'veterinarian'::role_enum)` — migration line 33–37 | CLOSED |
| T-3-02 | Tampering | create_lot_with_animals RPC — mass assignment | mitigate | RPC checks `is_member_of(p_property_id)` then `get_role(p_property_id) <> 'veterinarian'::role_enum`; raises ERRCODE 42501 on failure — migration lines 153–160 | CLOSED |
| T-3-03 | Tampering/DoS | Duplicate (property_id, number) | mitigate | `animals_property_number_idx` UNIQUE INDEX (WHERE deleted_at IS NULL) exists in migration 20260508_02; `createAnimal` catches `PostgrestException(code='23505')` and rethrows `AnimalNumberConflictException` — animal_repository.dart lines 135–142 | CLOSED |
| T-3-04 | Tampering/DoS | Batch RPC partial failure leaving orphan lot row | mitigate | RPC is plpgsql with no explicit transaction; any RAISE EXCEPTION rolls back all inserts atomically — migration lines 130–232 (single implicit transaction) | CLOSED |
| T-3-05 | Tampering | Updating archived animal to bypass soft-delete | mitigate | `veterinarian_can_update_active_animal` USING clause includes `AND deleted_at IS NULL`; same guard on `veterinarian_can_update_active_lot` — migration lines 79–89, 40–50 | CLOSED |
| T-3-06 | Tampering | Cross-property paddock attachment | mitigate | RPC validates `EXISTS (SELECT 1 FROM paddocks WHERE id = p_paddock_id AND property_id = p_property_id AND deleted_at IS NULL)` before INSERT — migration lines 163–169 | CLOSED |
| T-3-07 | Information Disclosure | Reading other properties' lots/animals | mitigate | `members_can_read_lots` SELECT policy uses `USING (is_member_of(property_id))` — migration line 30; `members_can_read_animals` policy was established in Phase 2 migration (same pattern) | CLOSED |
| T-3-08 | DoS | Concurrent batches generating duplicate numbers | mitigate | `pg_advisory_xact_lock(hashtextextended(p_property_id::text, 0))` acquired before number computation in both `create_lot_with_animals` (line 181) and `generate_animal_number` (line 113) | CLOSED |
| T-3-09 | Tampering | Flutter caller spoofing propertyId | mitigate | RPC enforces `is_member_of(p_property_id)` server-side; `animalListByPropertyProvider` reads propertyId from `currentPropertyProvider` (server-derived via JWT) — animal_repository.dart lines 104–109, 204–208 | CLOSED |
| T-3-10 | Tampering | Number conflict surfaces as raw SQL error | mitigate | `createAnimal` catches `PostgrestException` where `e.code == '23505'` and throws `AnimalNumberConflictException` with a fixed pt-BR user message — animal_repository.dart lines 135–142 | CLOSED |
| T-3-11 | Information Disclosure | Embedded join leaks lot/paddock data | accept | (Accepted risk — see Accepted Risks Log) | CLOSED |
| T-3-12 | Tampering | Mass-assignment via updateAnimal payload | mitigate | `updateAnimal` builds payload with only `breed`, `body_condition`, `observation` keys; category, number, property_id, lot_id are never included — animal_repository.dart lines 155–162 | CLOSED |
| T-3-13 | Tampering | Non-vet triggers create-lot | mitigate | `_canEdit` returns `role == 'veterinarian'` in both `PaddockDetailScreen` and `LoteDetailScreen`; FAB is `null` when `canEdit == false`; RLS enforces at DB level — paddock_detail_screen.dart lines 84–94, lote_detail_screen.dart lines 88–98 | CLOSED |
| T-3-14 | Tampering | Edit mode mutates paddock_id/property_id | mitigate | `LoteRepository.updateLotName` sends only `{'name': name}` — lote_repository.dart lines 72–83 | CLOSED |
| T-3-15 | Information Disclosure | Generic exception leaks DB internals | mitigate | `lote_form_dialog.dart` catch block shows fixed pt-BR string; `AnimalNumberConflictException` surfaces only its own user message; all other exceptions show generic text — lote_form_dialog.dart lines 121–130, animal_form_dialog.dart lines 110–113 | CLOSED |
| T-3-16 | Tampering | Deep-link to /lotes/<other-tenant-id> | mitigate | `loteByIdProvider` calls `fetchLot` which uses PostgREST SELECT under RLS + `.maybeSingle()`; `LoteDetailScreen` renders 'Lote não encontrado.' when result is null — lote_repository.dart lines 29–38, lote_detail_screen.dart lines 42–45 | CLOSED |
| T-3-17 | Tampering | Non-vet uses devtools to call AnimalFormDialog | mitigate | RLS `veterinarian_can_insert_animal` policy WITH CHECK requires veterinarian role; INSERT rejected by Postgres regardless of UI — migration lines 69–74 | CLOSED |
| T-3-18 | Information Disclosure | Number conflict surfaces raw constraint name | mitigate | `AnimalFormDialog` catches `AnimalNumberConflictException` and shows only `e.message` (the fixed pt-BR user string) in SnackBar — animal_form_dialog.dart lines 106–109 | CLOSED |
| T-3-19 | Tampering | LoteDetailScreen via deep link to other tenant's lot | mitigate | Same as T-3-16: `loteByIdProvider` returns null for non-member; screen shows 'Lote não encontrado.' — lote_detail_screen.dart line 44 | CLOSED |
| T-3-20 | DoS | Auto-number RPC called on every dialog open | accept | (Accepted risk — see Accepted Risks Log) | CLOSED |
| T-3-21 | Tampering | Non-vet uses devtools to call AnimalEditDialog/BaixaDialog | mitigate | RLS `veterinarian_can_update_active_animal` USING clause requires vet role + `deleted_at IS NULL`; UPDATE rejected by Postgres — migration lines 79–89 | CLOSED |
| T-3-22 | Tampering | BaixaDialog reused on already-archived animal (double-baixa) | mitigate | 'Dar baixa' button rendered only inside `if (isActive) [...]` where `isActive = animal.deletedAt == null` — animal_detail_screen.dart lines 292–301; RLS UPDATE policy enforces `deleted_at IS NULL` as second layer | CLOSED |
| T-3-23 | Information Disclosure | Search query leaks via URL or analytics | accept | (Accepted risk — see Accepted Risks Log) | CLOSED |
| T-3-24 | Tampering | AnimalDetailScreen via deep link to other tenant's animal | mitigate | `animalByIdProvider` calls `fetchAnimal` which uses PostgREST SELECT under RLS + `.maybeSingle()`; `AnimalDetailScreen` renders 'Animal não encontrado.' when null — animal_repository.dart lines 90–98, animal_detail_screen.dart lines 46–51 | CLOSED |
| T-3-W0-01 | Tampering | test scaffolds | accept | (Accepted risk — see Accepted Risks Log) | CLOSED |
| T-3-25 | DoS | Filter computation on 10k+ animals | accept | (Accepted risk — see Accepted Risks Log) | CLOSED |

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-3-01 | T-3-W0-01 | Test files cannot affect production behavior; CI prevents shipping skip: tests. | phase-architect | 2026-05-19 |
| AR-3-02 | T-3-11 | RLS on lots and paddocks restricts SELECT to members; PostgREST embedded joins inherit those policies — only joinable rows the user can already SELECT will be returned. | phase-architect | 2026-05-19 |
| AR-3-03 | T-3-20 | One advisory-locked RPC call per dialog open is acceptable; the lock is per-property and short-lived (single SELECT MAX). | phase-architect | 2026-05-19 |
| AR-3-04 | T-3-23 | Search is client-side state only; never serialized to URL or sent to analytics. No PII in numbers. | phase-architect | 2026-05-19 |
| AR-3-05 | T-3-25 | MVP property sizes are hundreds to low thousands. Server-side .ilike search is the documented fallback if needed. | phase-architect | 2026-05-19 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-19 | 25 | 25 | 0 | gsd-security-auditor |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter
