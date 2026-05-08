---
phase: 2
slug: property-paddock-structure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-08
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + pgTAP via `supabase test db` |
| **Config file** | `pubspec.yaml` (flutter_test SDK), `supabase/config.toml` (pgTAP) |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test test/ && supabase test db` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test test/ && supabase test db`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 0 | PROP-01 | — | N/A | unit stub | `flutter test test/features/propriedades/` | ❌ Wave 0 | ⬜ pending |
| 2-01-02 | 01 | 0 | PROP-02 | — | N/A | unit stub | `flutter test test/features/piquetes/` | ❌ Wave 0 | ⬜ pending |
| 2-01-03 | 01 | 0 | D-07 | T-2-01 | Non-veterinário INSERT piquete rejected by RLS | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 | ⬜ pending |
| 2-01-04 | 01 | 0 | D-20 | — | gerar_numero_animal returns non-duplicate | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 | ⬜ pending |
| 2-01-05 | 01 | 0 | D-21 | — | composicao_snapshot trigger blocks UPDATE/DELETE | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 | ⬜ pending |
| 2-01-06 | 01 | 0 | D-22 | — | ATF partial unique index blocks duplicate active ATF | SQL (pgTAP) | `supabase test db` | ❌ Wave 0 | ⬜ pending |
| 2-02-01 | 02 | 1 | PROP-01 | — | N/A | widget | `flutter test test/widget/propriedades_screen_test.dart` | ❌ Wave 0 | ⬜ pending |
| 2-03-01 | 03 | 2 | PROP-02 | — | N/A | widget | `flutter test test/widget/piquetes_screen_test.dart` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/propriedades/propriedade_repository_test.dart` — compile-assert stubs for PropriedadeRepository surface (PROP-01)
- [ ] `test/features/piquetes/piquete_repository_test.dart` — compile-assert stubs for PiqueteRepository + Piquete model (PROP-02)
- [ ] `test/widget/propriedades_screen_test.dart` — empty state + list rendering with mocked provider (PROP-01)
- [ ] `test/widget/piquetes_screen_test.dart` — empty state + list rendering with mocked provider (PROP-02)
- [ ] `supabase/tests/` directory — does not exist yet, must be created
- [ ] `supabase/tests/02_property_paddock_test.sql` — pgTAP: RLS policies, gerar_numero_animal concurrency, composicao_snapshot trigger, ATF partial unique index

*All Wave 0 gaps must be created before Wave 1 tasks begin.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| gerar_numero_animal concurrency (pgbench) | D-20 | pgTAP runs serially — true parallel calls cannot be tested in single transaction | Run: `pgbench -c 10 -j 10 -n -q -f <script.sql> <db>` where script calls `SELECT gerar_numero_animal(...)`. Verify no duplicate numbers in output. |
| PropertySelector hides soft-deleted propriedades | D-11 | Requires manual UI verification after soft-delete | 1. Create propriedade. 2. Soft-delete it. 3. Verify it no longer appears in PropertySelector dropdown. |
| FAB/edit/delete absent for proprietário role | D-06 | Role-based widget tree requires manual verification | 1. Login as proprietário. 2. Open piquetes screen. 3. Confirm no FAB visible. 4. Open piquete detail. 5. Confirm no edit/delete buttons. |
| pt-BR decimal comma accepted in form | D-18 | Requires manual input testing | 1. Open piquete create form. 2. Enter "12,5" in area_ha field. 3. Submit. 4. Verify value saved as 12.5 (not 0 or error). |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
