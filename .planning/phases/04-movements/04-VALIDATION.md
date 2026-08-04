---
phase: 4
slug: movements
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-19
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail |
| **Config file** | none — flutter standard test runner |
| **Quick run command** | `flutter test test/features/animais/ test/features/lotes/ test/widget/mover_animal_dialog_test.dart test/widget/mover_lote_dialog_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/animais/ test/features/lotes/ test/widget/mover_animal_dialog_test.dart test/widget/mover_lote_dialog_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 0 | MOV-01 | — | N/A | unit | `flutter test test/features/animais/animal_repository_test.dart` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 0 | MOV-01 | — | N/A | widget | `flutter test test/widget/mover_animal_dialog_test.dart` | ❌ W0 | ⬜ pending |
| 4-01-03 | 01 | 0 | MOV-01, SC-3 | — | Button absent when canEdit=false | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 0 | MOV-02 | — | N/A | unit | `flutter test test/features/lotes/lote_repository_test.dart` | ✅ extend | ⬜ pending |
| 4-02-02 | 02 | 0 | MOV-02 | — | N/A | widget | `flutter test test/widget/mover_lote_dialog_test.dart` | ❌ W0 | ⬜ pending |
| 4-02-03 | 02 | 0 | MOV-02, SC-3 | — | Button absent when canEdit=false | widget | `flutter test test/widget/lote_detail_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/animais/animal_repository_test.dart` — new file; covers MOV-01 `moveAnimal()` contract test (mirrors `lote_repository_test.dart` structure)
- [ ] `test/widget/mover_animal_dialog_test.dart` — new file; covers MOV-01 dialog rendering + picker interaction (mirrors `baixa_dialog_test.dart` structure)
- [ ] `test/widget/mover_lote_dialog_test.dart` — new file; covers MOV-02 dialog rendering + picker interaction
- [ ] `test/widget/animal_detail_screen_test.dart` — new file; covers 3rd button presence/absence (canEdit gate)
- [ ] `test/widget/lote_detail_screen_test.dart` — new file; covers "Mover para piquete" button gate conditions
- [ ] `test/features/lotes/lote_repository_test.dart` — EXTEND existing; add `moveLot` contract test

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SnackBar shows correct lot name after move animal | MOV-01 | SnackBar content hard to assert in widget tests | Open animal detail, press Mover, select a lot, confirm. Verify SnackBar reads "Animal movido para [nome do lote destino]". |
| SnackBar shows correct paddock name after move lot | MOV-02 | SnackBar content hard to assert in widget tests | Open lot detail, press Mover para piquete, select paddock, confirm. Verify SnackBar reads "Lote movido para [nome do piquete destino]". |
| Supabase push applied to dev | MOV-02 | DB migration requires CLI | Run `supabase db push` and verify `move_lot_to_paddock` function exists in dev DB. |
| Cross-property rejection visible to user | SC-4 | API-level scenario not reachable via UI | Via Supabase Studio or direct API call, attempt to set `lot_id` to a lot from a different property. Verify error returned. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
