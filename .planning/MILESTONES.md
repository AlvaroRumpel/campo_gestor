# Milestones

## v1.0 MVP (Shipped: 2026-08-21)

**Phases completed:** 12 fases (0–11), 76 planos, 161 tasks
**Timeline:** 2026-05-06 → 2026-08-20
**Closeout:** override_closeout — fases 9 e 11 registradas retroativamente (só SUMMARY), fase 10 sem VERIFICATION.md formal (UAT humana 2026-08-15 com 4 gaps fechados na quick 260815-h9w). Audit `milestones/v1.0-MILESTONE-AUDIT.md` cobre fases 0–8 (veredito tech_debt, 30/30 requisitos).

**Key accomplishments:**

- App completo de gestão de pecuária (Flutter web + Supabase): propriedades multi-tenant com RLS, piquetes, lotes, animais com numeração única por propriedade, movimentações atômicas via RPCs SECURITY DEFINER.
- Módulo reprodutivo (IATF): lotes de IATF com composição elegível, DG em massa (Prenhe/Vazia/Duvidosa), % prenhez, encerramento manual — invariantes garantidos por triggers no banco.
- Módulo sanitário com snapshot imutável: aplicações congelam composição/dose/custo no registro; estorno com motivo; histórico por animal e por lote.
- Ficha consolidada do animal (core value): timeline única reprodutivo + sanitário acessível em campo, com gastos por piquete integrados.
- Gestão de membros e ciclo de vida: convites in-app com papéis (vet/proprietário/leitor), guarda de último veterinário, arquivar/restaurar fazenda com confirmação forte — pgTAP 81/81.
- Redesign completo "musgo evoluído" (tokens AppColors, tema M3, shell responsivo rail/bottom-nav) + feature Planilhas: export/import .xlsx/.csv, edição em grade com colar do Excel, RPCs bulk_* transacionais (pgTAP 15/15).

**Known deferred items** (registrados no STATE.md e no audit):

- Supabase Auth Site URL/redirects ainda em localhost (bloqueia onboarding real).
- `anon` com EXECUTE em RPCs SECURITY DEFINER (oráculo de existência de UUID); `/gsd-secure-phase` nunca rodado.
- `_canEdit` duplicado em 8 telas; header do histórico sanitário estoura em 360px (D-37); fallback 400kg transitório no `kg_per_ua_resolver`; 2 debug sessions em `diagnosed`.
- Nyquist: só a Fase 3 compliant.

---
