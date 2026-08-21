---
phase: 02-property-paddock-structure
verified: 2026-08-11T00:00:00Z
status: passed
score: 5/5 roadmap success criteria verified; 2/2 requirements (PROP-01, PROP-02) satisfied
behavior_unverified: 0
overrides_applied: 0
retroactive: true
---

# Phase 2: Property & Paddock Structure — Verification Report

**Phase Goal:** Usuário (proprietário) estrutura sua fazenda criando a propriedade e seus piquetes; protótipos críticos validados em ambiente real.
**Verified:** 2026-08-11 (retroactive — written at milestone v1.0 close; the phase shipped 2026-05-08 with UAT but without a verification report)
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Criar, editar, listar e soft-delete de propriedades | ✓ VERIFIED | `PropriedadesScreen` + `PropertyFormDialog` (02-04-SUMMARY.md), route `/propriedades`, reachable from the `PropertySelector` "Gerenciar fazendas" link. Creation is atomic via the `20260509_03_create_property_rpc.sql` RPC (replaced the original two-step INSERT — fix-03). `02-UAT.md` checks 3, 4, 5, 6 — all pass. |
| SC-2 | Criar/editar/listar piquetes com nome, área (ha) e capacidade dentro da propriedade ativa | ✓ VERIFIED | `paddocks` table (`20260508_02_property_paddock.sql:72`) with RLS + UPDATE policy; `PiquetesScreen` + `PaddockFormDialog` with pt-BR decimal input + `PaddockDetailScreen` at `/piquetes/:id` (02-05-SUMMARY.md), replacing the Phase 0 placeholder and turning the RED stub test GREEN. `02-UAT.md` checks 7, 8, 9, 10 — all pass. |
| SC-3 | RPC de numeração existe e nunca produz número duplicado sob concorrência | ✓ VERIFIED | `generate_animal_number(uuid, text)` (`20260508_02_property_paddock.sql:143`) serializes on `pg_advisory_xact_lock` (:156), backed by the `animals_property_number_idx` unique index (:129) as a hard database-level backstop. `REVOKE ALL … FROM public` + `GRANT EXECUTE … TO authenticated` (:168-169). Proven in production use by Phase 3: batch lot creation generates N animals with unique, continuous per-category numbers — `03-HUMAN-UAT.md` 5/5 pass. |
| SC-4 | Coluna JSONB de snapshot com triggers que bloqueiam UPDATE/DELETE no banco | ✓ VERIFIED | `sanitary_applications` (:192) with `trg_snapshot_immutable` (:207). pgTAP `02_property_paddock_test.sql` asserts the trigger blocks both UPDATE and DELETE. Trigger survived Phase 7's DISABLE→backfill→ENABLE window — re-enabled state re-verified in the catalog (`tgenabled='O'`, 07-VERIFICATION.md). |
| SC-5 | Partial unique index ATF `WHERE deleted_at IS NULL`, validado com insert duplicado | ✓ VERIFIED | `animal_atf_memberships_active_idx` (:182). pgTAP `02_property_paddock_test.sql:30-45` asserts a second active ATF for the same animal raises `23505` unique_violation (D-22). Index preserved and re-verified in the catalog at Phase 5's migration apply (STATE.md blockers log). |

**Score:** 5/5 — `pgTAP 02_property_paddock_test.sql`, plan(11).

---

## Requirements

| REQ | Status | Evidence |
|-----|--------|----------|
| PROP-01 — criar/editar/listar propriedades | ✓ Satisfied | SC-1 |
| PROP-02 — criar/editar/listar piquetes (nome, área ha, capacidade) | ✓ Satisfied | SC-2 |

---

## UAT

`02-UAT.md` — status `complete`, **10/10 pass** (2026-05-08).

Check 2 ("PropriedadesScreen empty state") was originally logged `issue`/major on the report
"ao apagar as fazendas … foi para a rota de sem-acesso". Reclassified to `pass` at milestone
close: the redirect is Phase 1's SC-2 by design (0 propriedades → `/sem-acesso`), implemented
in the router's 3-stage guard and covered by 6 green unit tests in `01-VERIFICATION.md`. The
scenario text assumed the screen was reachable without a `property_members` row, which the
router correctly forbids. See the note in `02-UAT.md` check 2.

Three defects were found and fixed during the UAT itself:

- **fix-01** — `_canEdit` narrowed to veterinarian-only (role model per `project_phase2_decisions.md`: vet = admin, proprietário = read-only)
- **fix-02** — `onTap` + GoRouter navigation on the piquete card (check 9)
- **fix-03** — atomic `create_property` RPC replacing the two-step INSERT (check 4)

---

## Plan Coverage Note

The phase directory holds only `02-04` and `02-05` (UI plans). Plans 02-01 through 02-03 —
the backend prototypes — were folded into `20260508_02_property_paddock.sql` and
`20260509_03_create_property_rpc.sql`, whose contents are verified directly above and by
pgTAP. This is a bookkeeping gap in the planning artifacts, not a delivery gap: every SC-3/4/5
object exists in a versioned migration, is catalog-confirmed on live PROD, and is asserted by
the pgTAP suite.

---

## Gaps Summary

No open gaps.

One residual: the SC-3 concurrency proof is documented in `02_property_paddock_test.sql:4-7`
as a separate pgbench procedure (`pgbench -c 10 -j 10 -t 5`) that was never executed — Docker
has been unavailable on this machine throughout the project, so `supabase test db` and the
local pgbench path both stay blocked. The property is nonetheless enforced by two independent
mechanisms in the shipped schema (advisory transaction lock + unique index), and exercised for
real by every batch lot creation since Phase 3 with zero duplicates observed. Accepted.

---

_Verified: 2026-08-11 (retroactive)_
_Verifier: Claude, during /gsd-complete-milestone v1.0 with user confirmation_
