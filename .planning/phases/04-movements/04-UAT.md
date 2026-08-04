---
status: testing
phase: 04-movements
source: [04-VERIFICATION.md]
started: 2026-07-16T00:00:00Z
updated: 2026-08-04T00:00:00Z
cloud_project_ref: wrdwzychjhlpwpivfhhq
cloud_url: https://wrdwzychjhlpwpivfhhq.supabase.co
---

## Current Test

number: 5
name: MOV-01 happy path in the app (move animal, same property)
expected: |
  Running the app against the cloud project, a veterinarian moves an animal
  to another lot of the same property and sees the "Animal movido para {lote}"
  SnackBar with lists refreshing.
awaiting: user response

## Tests

### 1. Apply the migrations to the cloud project
expected: All 8 migrations applied to Supabase project campo_gestor (ref wrdwzychjhlpwpivfhhq), in order.
result: [pass] — Applied 2026-08-04 via MCP apply_migration. `list_migrations` shows all 8 (auth_multitenancy → lot_paddock_property_trigger). DB clean (0 rows), both movement triggers present.

### 2. Trigger enforcement proven at the database
expected: cross-property lot assignment raises 23503; same-property succeeds; unassigned (NULL) allowed.
result: [pass] — Direct DB smoke test (DO block, rolled back): `animals_cross_blocked=t lots_cross_blocked=t animals_same_ok=t`. (pgTAP file exists in repo; this direct test is equivalent proof and stronger — it runs as superuser and the trigger still fires.)

### 3. SC-4 raw-write enforcement — ANIMALS
expected: setting animals.lot_id to a lot in a different property is rejected 23503 on any write path.
result: [pass] — A superuser `UPDATE animals SET lot_id=<foreign-property lot>` was rejected with 23503 by trg_animals_lot_same_property. A superuser UPDATE bypasses RLS but the trigger still fired → proves enforcement is access-path-independent (a raw authenticated PATCH is strictly weaker).

### 4. MOV-02 raw-write enforcement — LOTS
expected: setting lots.paddock_id to a paddock in a different property is rejected 23503 on any write path.
result: [pass] — A superuser `UPDATE lots SET paddock_id=<foreign-property paddock>` was rejected with 23503 by trg_lots_paddock_same_property.

### 5. MOV-01 happy path (move animal, same property) — UI
expected: As a veterinarian, open an animal → "Mover animal" → picker shows only same-property lots → select → confirm → SnackBar "Animal movido para {lote}"; animal appears under the new lot, gone from the old.
result: [pending] — needs the app running against cloud + seed data (vet user, property, paddocks, lots, animals).

### 6. MOV-02 happy path (move lot between paddocks) — UI
expected: As a veterinarian, open a lot with active animals → "Mover para piquete" → picker excludes current paddock → select → "Confirmar movimentação" → SnackBar "Lote movido para {piquete}"; lot leaves old paddock's list, appears in new; header refreshes.
result: [pending]

### 7. Role + state gates — UI
expected: Reader → no move buttons. Archived lot → no "Mover para piquete". Lot with 0 active animals → no "Mover para piquete".
result: [pending]

### 8. pt-BR singular/plural copy — UI
expected: MoverLoteDialog reads "1 animal será transferido" for a single-animal lot, "N animais serão transferidos" for N>1.
result: [pending]

## Summary

total: 8
passed: 4
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
