---
phase: 10
slug: gest-o-de-membros-e-ciclo-de-vida-da-propriedade
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-14
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) + pgTAP (SQL, arquivo autorado; suite executada via round-trip transacional no PROD quando não há stack local) |
| **Config file** | pubspec.yaml (flutter_test); supabase/tests/ (pgTAP) |
| **Quick run command** | `flutter test test/widget` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (preenchido pelo planner ao gerar os PLAN.md) | — | — | MEMB-01..03, PROPV-01..02 | — | RPCs SECURITY DEFINER com validação de papel; guarda de último vet | unit/widget/pgTAP | `flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `supabase/tests/10_membership_test.sql` — pgTAP para RPCs de convite/membro (invite/accept/decline/revoke/remove/update_role/leave + guarda de último vet)
- [ ] `test/widget/membros_screen_test.dart` — stubs para MEMB-02 (lista, gates por papel)

*Existing infrastructure (flutter_test + fixtures em test/) covers the rest.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Convite aparece para usuário recém-cadastrado com o e-mail convidado | MEMB-01 | exige 2 contas reais no Supabase Auth | Convidar e-mail sem conta → criar conta com esse e-mail → ver convite em /sem-acesso |
| Redirect pós-aceite (sem-acesso → dashboard da fazenda) | MEMB-01 | fluxo de sessão/router real | Aceitar convite e observar redirect + propriedade ativa |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
