---
phase: 3
slug: lots-animals-operational-core
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-14
audited: 2026-05-19
tests_total: 44
tests_green: 44
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK), mocktail ^1.0.5 |
| **Config file** | none (standard Flutter test runner) |
| **Quick run command** | `flutter test test/features/lotes/ test/features/animais/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/lotes/ test/features/animais/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-W0-01 | migration | 0 | PROP-03, ANIM-01 | T-3-01 | RPC validates `is_member_of(property_id)` | unit | `flutter test test/features/lotes/lote_repository_test.dart` | ✅ | ✅ green |
| 3-W0-02 | migration | 0 | PROP-03 | — | N/A | unit | `flutter test test/features/animais/animal_model_test.dart` | ✅ | ✅ green |
| 3-W0-03 | migration | 0 | PROP-05 | — | N/A | unit | `flutter test test/features/animais/ua_calculation_test.dart` | ✅ | ✅ green |
| 3-W0-04 | migration | 0 | PROP-04 | T-3-02 | Form rejects invalid composition | widget | `flutter test test/widget/lote_form_dialog_test.dart` | ✅ | ✅ green |
| 3-W0-05 | migration | 0 | ANIM-02 | — | N/A | widget | `flutter test test/widget/animal_edit_dialog_test.dart` | ✅ | ✅ green |
| 3-W0-06 | migration | 0 | ANIM-04 | — | N/A | widget | `flutter test test/widget/baixa_dialog_test.dart` | ✅ | ✅ green |
| 3-W0-07 | migration | 0 | ANIM-05, ANIM-06 | — | N/A | widget | `flutter test test/widget/animais_screen_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/features/lotes/lote_repository_test.dart` — stubs for PROP-03
- [x] `test/features/animais/animal_model_test.dart` — stubs for ANIM-01
- [x] `test/features/animais/ua_calculation_test.dart` — stubs for PROP-05
- [x] `test/widget/lote_form_dialog_test.dart` — stubs for PROP-04
- [x] `test/widget/animal_edit_dialog_test.dart` — stubs for ANIM-02
- [x] `test/widget/baixa_dialog_test.dart` — stubs for ANIM-04
- [x] `test/widget/animais_screen_test.dart` — stubs for ANIM-05, ANIM-06

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `supabase db push` applies migration cleanly | PROP-03 | Requires live Supabase CLI + DB connection | Run `supabase db push` on dev project; verify no errors; check `lots` and `animals` tables exist with correct schema |
| RLS blocks cross-property writes | PROP-03 | Requires two authenticated users in dev | Login as user A, attempt to create lot under user B's property_id; expect 403/RLS error |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

## Validation Audit 2026-05-19

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 7 |
| Escalated | 0 |
| Tests total | 44 |
| Tests green | 44 |

**Approval:** verified 2026-05-19
