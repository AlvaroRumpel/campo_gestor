---
status: partial
phase: 03-lots-animals-operational-core
source: [03-VERIFICATION.md]
started: 2026-05-15T00:00:00Z
updated: 2026-05-15T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Batch creation end-to-end
expected: Create lot with "10 vacas, 8 terneiros, 1 touro" → system generates 19 animals with unique continuous numbers via `create_lot_with_animals` RPC; LoteDetailScreen shows composition chips with correct counts and UA total
result: [pending]

### 2. Animal edit flow
expected: Open animal, tap Editar, change raça/EC/observação, confirm → changes immediately reflected in AnimalDetailScreen (provider invalidation works, no stale data)
result: [pending]

### 3. Search debounce
expected: Type partial number in AnimaisScreen search bar → 300ms after last keystroke, list filters to matching animals; clear (X) button resets list
result: [pending]

### 4. Combined filter + SummaryBar
expected: Select FilterChip (e.g. "Vaca") + Lote dropdown → list shows only matching animals; SummaryBar UA total updates to reflect filtered subset only
result: [pending]

### 5. Baixa registration
expected: Open animal, tap Dar baixa, select Venda, pick date, confirm → animal disappears from LoteDetailScreen active list; AnimalDetailScreen shows archived badge; archived toggle in AnimaisScreen reveals it with Vendido tag
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
