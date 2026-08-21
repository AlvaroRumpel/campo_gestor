# Retrospective — Campo Gestor

## Milestone: v1.0 — MVP

**Shipped:** 2026-08-21
**Phases:** 12 | **Plans:** 76

### What Was Built

App completo de gestão de pecuária (Flutter web + Supabase): estrutura Propriedade → Piquete → Lote → Animal com RLS multi-tenant, módulo reprodutivo IATF, módulo sanitário com snapshot imutável, ficha consolidada do animal (core value), gastos por piquete, membros/convites, redesign "musgo evoluído" e planilhas export/import/grade.

### What Worked

- RPCs SECURITY DEFINER + triggers de isolamento como dupla camada: nenhum vazamento cross-tenant encontrado em review ou UAT.
- pgTAP replay em PROD dentro de `BEGIN…ROLLBACK` como substituto do Docker (que não roda na máquina) — 81/81 e 15/15 nas suítes maiores.
- Ciclo review → gap-closure → UAT por fase pegou dezenas de bugs antes do usuário (ex.: CR-01 da baixa em ATF ativo).
- Quick tasks para feedback de QA em produção (260815-h9w, 260819-mk7) mantiveram o ritmo sem abrir fase.

### What Was Inefficient

- Fases 9 e 11 executadas fora do fluxo plan/execute → registro retroativo só com SUMMARY, sem verificação formal; STATE.md ficou ~5 dias defasado do git.
- `gsd-executor` sem tools de Supabase MCP → todo plano com migration voltava BLOCKED e exigia aplicação manual pelo orquestrador.
- Nyquist validation praticamente abandonada após a Fase 3.
- Redesign (Fase 9) deixou 2 seções pré-redesign (históricos sanitário/reprodutivo) que viraram a maior inconsistência visual do app.

### Patterns Established

- Escrita em massa só via RPCs `bulk_*` (convenção no CLAUDE.md).
- `SheetSchema` como fonte única de colunas por entidade.
- Soft-delete em tudo; guardas de arquivamento em cadeia (piquete↛lote ativo, lote↛animal ativo).
- `showAdaptiveForm` (sheet <600px / dialog) como contrato de formulário.

### Key Lessons

- Trabalho fora do GSD acumula dívida de bookkeeping rápido — registrar retroativo no mesmo dia, não no fechamento do milestone.
- Verificação visual precisa de auditoria dedicada: consistência não emerge de fases feature-a-feature (auditoria 2026-08-21 achou ~10 categorias de deriva).

## Cross-Milestone Trends

| Milestone | Fases | Planos | Duração |
|---|---|---|---|
| v1.0 | 12 | 76 | 2026-05-06 → 2026-08-20 |
