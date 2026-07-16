---
status: testing
phase: 04-movements
source: [04-VERIFICATION.md]
started: 2026-07-16T00:00:00Z
updated: 2026-07-16T00:00:00Z
---

## Current Test

number: 1
name: Apply the three Phase-4 migrations to the dev database
expected: |
  `supabase link --project-ref <dev-ref>` then `supabase db push` applies
  20260519_04_movements.sql, 20260715_04_gap_move_animal_to_lot.sql, and
  20260716_04_animal_lot_property_trigger.sql cleanly; `supabase db diff`
  reports no drift.
awaiting: user response

## Tests

### 1. Apply migrations (prerequisite for everything below)
expected: From a machine with dev Supabase credentials — `supabase link --project-ref <dev-ref>`, then `supabase db push` applies all three unpushed Phase-4 migrations (20260519, 20260715, 20260716) in filename order with no error; `supabase db diff` shows no drift.
result: [pending]

### 2. Run the pgTAP suite
expected: `supabase test db` runs `supabase/tests/04_movements_test.sql` — all assertions pass: cross-property lot assignment raises `23503`; same-property assignment succeeds; inserting an animal with NULL `lot_id` succeeds.
result: [pending]

### 3. SC-4 raw-write enforcement (THE core check — must test the API directly, not just the UI)
expected: As a veterinarian who is a member of BOTH Fazenda A and Fazenda B, issue a raw request `PATCH /rest/v1/animals?id=eq.<A-animal>` with body `{"lot_id":"<a lot in Fazenda B>"}` (e.g. via curl with the vet's JWT, or the Supabase SQL editor doing a direct `UPDATE animals SET lot_id=... WHERE id=...`). The database TRIGGER must REJECT it with error `23503` ("lot ... does not belong to property ..."). The animal's lot_id must remain unchanged. This proves the bypass is closed at the DB, not just in the app.
result: [pending]

### 4. MOV-01 happy path (move animal, same property)
expected: As a veterinarian, open an animal → "Mover animal" (3rd button) → picker shows only lots of the SAME property → select a lot → confirm → SnackBar "Animal movido para {lote}"; the animal appears under the new lot and is gone from the old one.
result: [pending]

### 5. MOV-02 happy path (move lot between paddocks)
expected: As a veterinarian, open a lot with active animals → "Mover para piquete" → picker excludes the current paddock → select a paddock → "Confirmar movimentação" → SnackBar "Lote movido para {piquete}"; the lot disappears from the old paddock's list and appears in the new one; header refreshes.
result: [pending]

### 6. Role + state gates
expected: Logged in as a reader → no "Mover animal" / "Mover para piquete" buttons. On an archived lot → no "Mover para piquete" button. On a lot with 0 active animals → no "Mover para piquete" button.
result: [pending]

### 7. pt-BR singular/plural copy
expected: MoverLoteDialog info text reads "1 animal será transferido" for a single-animal lot, and "N animais serão transferidos" for N>1.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
