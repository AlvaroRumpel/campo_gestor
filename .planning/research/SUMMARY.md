# Research Summary — Campo Gestor

**Synthesized:** 2026-04-26
**Source files:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Overall confidence:** HIGH on architecture/stack, MEDIUM on domain features (no primary user research yet)

---

## Recommended Stack

- **Flutter 3.24+ + Riverpod 2.x (codegen) + GoRouter** — web-first, Riverpod's `AsyncValue` maps 1:1 to Supabase query states; GoRouter handles web URL semantics natively
- **Supabase (PostgreSQL + Auth + RLS)** — single backend: auth, multi-tenancy via RLS, all atomic ops via PL/pgSQL RPCs; skip Edge Functions for MVP
- **freezed + json_serializable** — immutable domain models with Supabase snake_case mapping
- **Feature-first folder structure** (Flutter team's MVVM): View → ViewModel → Repository → Service; widgets never import Supabase SDK directly
- **DO NOT add**: BLoC, dio, GetX, Hive/Isar, Realtime (MVP), Edge Functions (MVP), JWT custom claims for perfil

---

## Table Stakes Features (v1 must-haves)

| Category | Features |
|---|---|
| Estrutura | Propriedade + Piquete + Lote CRUD; numeração automática de animal |
| Animal | Cadastro individual, categorias + UA, estado corporal 1–5, ficha consolidada |
| Movimentação | Mover animal entre lotes; mover lote entre piquetes (atômico via RPC) |
| Reprodutivo | Lote ATF; validação 1 ATF ativo/animal; DG por animal; % prenhez automático; histórico |
| Sanitário | Aplicação sanitária; **snapshot congelado e imutável** por lote; histórico por animal e lote |
| Financeiro | Gasto por piquete; total por período/categoria |
| Auth | Login email/senha; perfis proprietário/veterinário/leitor; vet multifazenda nativo |

---

## Architecture Approach

Flutter feature-first MVVM com Supabase como único backend. **Todo isolamento multi-tenant via RLS**, ancorado na tabela `property_members` + função `app.is_member_of()`. Operações atômicas críticas (numeração, snapshot, mover lote, start ATF) vivem em **PL/pgSQL RPCs** — cliente Flutter nunca faz essas operações diretamente. `property_id` é desnormalizado em todas as tabelas filhas para manter políticas RLS performáticas e simples.

---

## Build Order

| Fase | Conteúdo | Dependências |
|---|---|---|
| **0 — Foundation** | Flutter scaffold + Riverpod + GoRouter + Supabase init; Auth flow; AppShell; `currentPropertyProvider`; migrações-como-código | Nada — pré-requisito de tudo |
| **1 — Multi-tenant core** | Propriedades + `property_members` + RLS completo; Piquetes CRUD; **spikes de risco**: numeração, snapshot, ATF uniqueness | Fase 0 |
| **2 — Hierarquia operacional** | Lotes CRUD; Animais + criação em batch (RPC); mover animal/lote | Fase 1 |
| **3a — Reprodutivo** | LoteATF + memberships + DG + % prenhez; histórico reprodutivo | Fase 2 |
| **3b — Sanitário** | Aplicação sanitária com snapshot congelado; histórico por animal/lote | Fase 2 (paralelo a 3a) |
| **3c — Gastos** | Gasto por piquete; totais; categorias | Fase 1 (independente) |
| **4 — Polish** | Realtime (opcional), indicadores UA/ha, empty states, leitores | Fases 3a/3b/3c |

**Paralelizável:** 3a e 3b independentes entre si. 3c pode ser encaixado junto a qualquer fase anterior.

---

## Top Pitfalls to Avoid

| # | Pitfall | Prevenção em 1 linha |
|---|---|---|
| CP-1 | Race condition na numeração de animais | RPC PL/pgSQL com `SELECT ... FOR UPDATE` — nunca gerar número no Dart |
| CP-2 | Snapshot sanitário mutado acidentalmente | Trigger proibindo UPDATE/DELETE + sem RLS de update na tabela |
| CP-3 | Vazamento multi-tenant (user A vê dados de fazenda B) | RLS em TODAS as tabelas + `FORCE ROW LEVEL SECURITY` + testes negativos em CI |
| CP-4 | Soft delete conflita com unique constraints | Partial unique indexes `WHERE deleted_at IS NULL`; decidir se número é reutilizável |
| CP-5 | Mover lote não é transacional | Toda movimentação via RPC atômico, nunca loop de updates no Dart |
| DT-1 | Confundir `lote` operacional com `lote_atf` | Duas tabelas separadas — nunca um `tipo` enum numa tabela só |
| DT-4 | Ambiguidade no escopo do número único | **Decidir agora:** `(propriedade, numero)` global OU `(propriedade, categoria, numero)` |
| CP-7 | Flutter web 5MB cold start | Deferred imports, loading screen no index.html, medir TTI em 4G |
| MP-6 | Schema diverge entre ambientes | Migrações SQL no git desde o dia 1, nunca editar via dashboard Supabase |

---

## Open Decisions (Needed Before Phase 1 Coding)

| Decisão | Opções | Recomendação |
|---|---|---|
| **Escopo do número de animal** | (A) único por propriedade global OU (B) único por (propriedade + categoria) | Confirmar com veterinário do domínio; PITFALLS sugere Opção B |
| **Número reutilizável após soft delete?** | Sim / Não | Não — animal deletado existe em históricos; reutilizar cria ambiguidade forense |
| **Encerramento do LoteATF** | Manual / Automático ao registrar DG de todos | Manual com alerta quando todos DGs preenchidos |
| **Aplicação sanitária: por lote inteiro ou por animal selecionado?** | Todos do lote / Seleção individual | Default = todos do lote; permitir desmarcar indivíduos antes de confirmar |
| **Auth primeiro: email/senha apenas?** | Sim / Também magic link | Email/senha apenas para MVP |
| **Supabase plan** | Free / Pro | Confirmar disponibilidade de `pg_cron` e Realtime no plano alvo |

---

## Confidence Summary

| Área | Nível | Observação |
|---|---|---|
| Stack técnico (Riverpod, GoRouter, Supabase RLS) | HIGH | Padrões estáveis e bem documentados; versões a verificar com `flutter pub outdated` |
| Arquitetura (feature-first MVVM, RLS, RPCs) | HIGH | Baseado em docs oficiais Flutter + padrões Supabase consolidados |
| Features table stakes (estrutura, reprodutivo, sanitário) | HIGH | Alinhado com PROJECT.md e domínio estabelecido de pecuária brasileira |
| Diferenciadores e análise de concorrentes | MEDIUM | WebSearch indisponível; validar com pesquisa primária |
| Build order e dependências entre fases | HIGH | Derivado de dependências técnicas explícitas |
| Pitfalls técnicos (RLS, snapshot, numeração) | HIGH | Padrões PostgreSQL/Supabase/Flutter bem conhecidos |
| Pitfalls de domínio (DG math, UA calc, gastos) | MEDIUM | Validar com veterinário real antes de Phase 3 |

---

## Next Step

Rodar `/gsd-plan-phase 1` após definir os requisitos de v1.
Antes de Phase 1 coding: resolver as 6 decisões abertas acima (30 minutos com stakeholder).
