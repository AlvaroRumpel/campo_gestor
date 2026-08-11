---
phase: 8
slug: animal-dossier-consolidation
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-11
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded by plan-phase from `08-RESEARCH.md` § Validation Architecture. Task IDs are
> filled by `/gsd-validate-phase` once PLAN.md task numbering is final.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` + `mocktail` (already project-wide dev deps) |
| **Config file** | none — Flutter test discovery is directory-based (`test/`) |
| **Quick run command** | `flutter test test/widget/animal_detail_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15s quick / ~90s full (312+ tests as of Phase 7) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget/animal_detail_screen_test.dart` (plus any new reproductive-section test file once it exists)
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green. D-07's manual 4G UAT is a separate human checkpoint, not part of the automated gate.
- **Max feedback latency:** 15 seconds (quick), 90 seconds (full)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 1 | ANIM-03 / D-01 | — | Lote+piquete embed respects RLS (property-scoped) | widget + contract | `flutter test test/features/lotes/lote_repository_test.dart` | ❌ W0 — extend | ⬜ pending |
| TBD | TBD | 2 | ANIM-03 / SC-2 (D-08) | — | N/A | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ W0/W2 — extend or new `animal_reproductive_history_section_test.dart` | ⬜ pending |
| TBD | TBD | 2 | ANIM-03 / SC-3 | — | N/A | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ✅ existing (`renders one row per entry, in the order supplied`) — must stay green after D-11 move | ⬜ pending |
| TBD | TBD | 2 | ANIM-03 / SC-4 | — | Baixa data readable only within property scope | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ W2 — new test group | ⬜ pending |
| TBD | TBD | 2 | ANIM-03 / SC-5 | — | N/A | widget (360px viewport) | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ W2 — first width-constrained test in repo | ⬜ pending |
| TBD | TBD | 2 | D-04 (retry per block) | — | Retry re-issues an RLS-scoped read, no cross-property leak | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ W2 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **360px-width widget test harness** — no existing test in `test/widget/` sets `tester.view.physicalSize`. The first plan needing it establishes the pattern once for reuse: `tester.view.physicalSize = const Size(360, 800)`, `tester.view.devicePixelRatio = 1.0`, `addTearDown(tester.view.resetPhysicalSize)`.
- [ ] `test/features/lotes/lote_repository_test.dart` — extend with a contract-test line for the new lote+paddock fetch method, matching the file's existing method-exists "contract" style (not full query mocking).
- [ ] `test/features/reproducao/atf_repository_test.dart` — verify current coverage of the reproductive-history fetch; update for the new DG records field.

*No framework install needed — `flutter_test` / `mocktail` are already dev dependencies.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Ficha opens in <1s under 4G | ANIM-03 / SC-1 (D-07) | Repo's repository tests are shallow contract tests; request-count and wall-clock under throttled network are not assertable in that convention (RESEARCH Pitfall 3) | Chrome DevTools → Network → "Fast 4G" throttle → open a ficha from the animal list → stopwatch to first fully-painted dossier. Record request count (target: 4). |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
