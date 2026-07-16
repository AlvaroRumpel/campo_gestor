---
status: testing
phase: 04-movements
source: [04-VERIFICATION.md]
started: 2026-07-16T00:00:00Z
updated: 2026-07-16T00:00:00Z
---

## Current Test

number: 1
name: Apply the four Phase-4 migrations to the dev database
expected: |
  `supabase link --project-ref <dev-ref>` then `supabase db push` applies
  20260519, 20260715, 20260716, 20260717 cleanly; `supabase db diff`
  reports no drift.
awaiting: user response

## Tests

### 1. Apply migrations (prerequisite for everything below)
expected: From a machine with dev Supabase credentials — `supabase link --project-ref <dev-ref>`, then `supabase db push` applies all FOUR unpushed Phase-4 migrations in filename order (20260519_04_movements.sql, 20260715_04_gap_move_animal_to_lot.sql, 20260716_04_animal_lot_property_trigger.sql, 20260717_04_lot_paddock_property_trigger.sql) with no error; `supabase db diff` shows no drift.
result: [pending]

### 2. Run the pgTAP suite
expected: `supabase test db` runs `supabase/tests/04_movements_test.sql` — all 5 assertions pass: animal cross-property → 23503; animal same-property ok; animal NULL lot_id ok; lot cross-property paddock → 23503; lot same-property paddock ok.
result: [pending]

### 3. SC-4 raw-write enforcement — ANIMALS (test the API directly, not just UI)
expected: As a veterinarian who is a member of BOTH Fazenda A and Fazenda B, issue `PATCH /rest/v1/animals?id=eq.<A-animal>` with `{"lot_id":"<lot in Fazenda B>"}` (curl with the vet JWT, or a direct `UPDATE animals SET lot_id=...` in the SQL editor). The trigger `trg_animals_lot_same_property` must REJECT it with `23503`; the animal's lot_id stays unchanged.
result: [pending]

### 4. MOV-02 raw-write enforcement — LOTS (test the API directly)
expected: As the same two-property veterinarian, issue `PATCH /rest/v1/lots?id=eq.<A-lot>` with `{"paddock_id":"<paddock in Fazenda B>"}` (or a direct `UPDATE lots SET paddock_id=...`). The trigger `trg_lots_paddock_same_property` must REJECT it with `23503`; the lot's paddock_id stays unchanged.
result: [pending]

### 5. MOV-01 happy path (move animal, same property)
expected: As a veterinarian, open an animal → "Mover animal" (3rd button) → picker shows only lots of the SAME property → select → confirm → SnackBar "Animal movido para {lote}"; animal appears under the new lot, gone from the old.
result: [pending]

### 6. MOV-02 happy path (move lot between paddocks)
expected: As a veterinarian, open a lot with active animals → "Mover para piquete" → picker excludes the current paddock → select → "Confirmar movimentação" → SnackBar "Lote movido para {piquete}"; lot leaves the old paddock's list, appears in the new one; header refreshes.
result: [pending]

### 7. Role + state gates
expected: Reader role → no "Mover animal" / "Mover para piquete" buttons. Archived lot → no "Mover para piquete". Lot with 0 active animals → no "Mover para piquete".
result: [pending]

### 8. pt-BR singular/plural copy
expected: MoverLoteDialog info text reads "1 animal será transferido" for a single-animal lot, "N animais serão transferidos" for N>1.
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
