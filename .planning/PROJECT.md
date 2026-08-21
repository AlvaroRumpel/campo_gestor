# Campo Gestor

## What This Is

App de gestão de propriedades rurais voltado para pecuária. Permite estruturar a propriedade em piquetes, organizar lotes, controlar animais individualmente, registrar histórico reprodutivo e sanitário, e oferecer visão operacional e gerencial do rebanho. Atende veterinários e proprietários de fazenda.

## Core Value

O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo por quem toma decisões operacionais.

## Requirements

### Validated

- [x] Estruturar propriedade com piquetes e lotes (hierarquia Propriedade → Piquete → Lote → Animal) — Validated in Phase 2
- [x] Gerar e controlar animais individualmente por lote — Validated in Phase 3: lote operacional com composição inicial, numeração única global, edição individual, busca, filtros combinados, baixa com soft-delete
- [x] Movimentar animais entre lotes e lotes entre piquetes — Validated in Phase 4: MOV-01 (animal → outro lote da mesma propriedade) e MOV-02 (lote inteiro → outro piquete, atomicamente). Ambos via RPC SECURITY DEFINER, com triggers de isolamento multi-tenant que valem em qualquer caminho de escrita (inclusive PATCH cru)
- [x] Registrar e consultar histórico reprodutivo (lote ATF, DG, % prenhez) — Validated in Phase 5: REPR-01..05 (criação de LoteATF, composição restrita a vacas/novilhas com bloqueio de ATF duplicado, DG por animal editável até encerramento manual, % prenhez auto-atualizado, histórico reprodutivo na ficha do animal). 5 rodadas de gap-closure (UAT + review) até UAT limpo com 0 issues.

- [x] Autenticar usuários com perfis: proprietário, veterinário, leitor — Validated in Phase 1: AUTH-01..05 (email/senha, sessão persistente, `property_members` define perfil por (user_id, property_id), seletor de propriedade ativa, RLS `FORCE ROW LEVEL SECURITY` em todas as tabelas com teste negativo cross-tenant). UAT 4/4.
- [x] Registrar e consultar histórico sanitário (aplicações com snapshot congelado) — Validated in Phase 6: SANI-01..03, snapshot JSONB imutável por trigger + RLS sem policy de write, estorno por índice único parcial, histórico por lote e por animal. UAT 11/11, pgTAP 80/81.
- [x] Controlar gastos por piquete — Validated in Phase 7: lançamento vinculado a piquete, total por período (com "Ano" = ano calendário), `sanitary_applications.paddock_id/paddock_name` congelados no snapshot. UAT 7/7, pgTAP 42/42.
- [x] **Core value entregue** — ficha consolidada do animal (ANIM-03) — Validated in Phase 8: dados do animal + lote/piquete atual (um único select embedded), histórico reprodutivo completo com todos os DGs expansíveis, e histórico sanitário completo, numa única tela; banner de baixa proeminente; layout 360px. UAT 15/15, verification 7/7.

- [x] Perfis alcançáveis + ciclo de vida da propriedade — Validated in Phase 10: convites in-app com papel (vet/proprietário/leitor), gestão de membros, guarda de último veterinário, arquivar/restaurar fazenda. pgTAP 81/81, UAT 2026-08-15.
- [x] Redesign "musgo evoluído" — Validated in Phase 9: tokens AppColors, tema M3, shell responsivo, UAT visual 2026-08-15.
- [x] Planilhas (export/import/grade estilo Excel) — Validated in Phase 11: .xlsx/.csv, import 3 passos, EditableGrid com colar do Excel, RPCs bulk transacionais (pgTAP 15/15).

### Active (v1.1 — em definição)

- [ ] Acesso a edição de piquete/lote no desktop (board sem onTap; renomear/arquivar lote escondidos)
- [ ] Consistência visual do app (auditoria 2026-08-21: históricos pré-redesign, contraste de chips, tema de botões, FABs, confirmações destrutivas) + alinhamento da tela Sanitário
- [ ] Hub Planilhas "modo Excel" — grades para todas as entidades (lotes, piquetes, gastos, IATF) num menu próprio

### Out of Scope

- Mapa e geolocalização — fora da fase inicial, adiciona complexidade desnecessária agora
- Compra e venda de animais — módulo separado, não é prioridade do MVP
- Controle de estoque de medicamentos — apenas custo/aplicação por ora
- Histórico detalhado de composição passada do lote — apenas composição atual importa
- Permissões granulares por módulo — perfis simples no MVP
- Relatórios e dashboards avançados — pós-MVP

## Current State

**v1.0 MVP shipped 2026-08-21** — 12 fases, 76 planos. App completo em PROD (Supabase `wrdwzychjhlpwpivfhhq`): multi-tenant com RLS, módulos reprodutivo (IATF) e sanitário (snapshot imutável), ficha consolidada do animal, gastos por piquete, membros/convites, redesign musgo, planilhas export/import/grade. ~Flutter web, Riverpod 3.x, migrations ledger 24.

**Débitos conhecidos ao fechar v1.0** (ver `MILESTONES.md`): Site URL do Auth em localhost; `anon` com EXECUTE em RPCs; `_canEdit` duplicado em 8 telas; fases 9/11 retroativas sem verificação formal.

## Context

**Domínio:** Pecuária de corte e reprodutiva. Usuários primários são veterinários que acompanham múltiplas fazendas e proprietários que acompanham o rebanho.

**Hierarquia principal:**
```
Propriedade → Piquete → Lote (operacional) → Animal
LoteATF (lote de inseminação) — entidade reprodutiva independente
```

**Categorias de animal e UA:**
- vacas (1.0), terneiros/as (0.5), touros (1.5), bois (1.5), novilhos (0.75), novilhas (0.75)

**Estado corporal:** escala 1–5 (muito magro → muito gordo)

**Lote ATF:** aceita apenas vacas e novilhas. Animal não pode estar em 2 ATFs ativos simultaneamente.

**Snapshot sanitário:** composição do lote é congelada no momento da aplicação. Imutável após criação.

**Numeração de animais:** único por propriedade, gerado automaticamente ao criar lote (incremental por categoria).

**Multipropriedade:** um veterinário pode estar vinculado a várias propriedades via tabela de permissões.

## Constraints

- **Stack**: Flutter web-first + Supabase (PostgreSQL + Auth + RLS) — decisão tomada antes do MVP
- **Offline**: não é requisito no MVP — sistema assume conectividade
- **Plataformas**: web primário, mobile (android/iOS) secundário
- **Numeração**: número do animal único por propriedade, gerado via sequence/lock no banco

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Supabase como backend | Auth + RLS + PostgreSQL prontos, sem servidor para manter no MVP | — Pending |
| Lote ATF como entidade separada | Reprodutivo é ciclo temporal, não estrutura física — não misturar com lote operacional | — Pending |
| Snapshot congelado na aplicação sanitária | Histórico não pode ser alterado por mudanças futuras na composição do lote | — Pending |
| Categoria resolve sexo | Simplifica model — categoria já carrega o sexo implícito no domínio | — Pending |
| Numeração única por propriedade | Veterinário precisa referenciar animal pelo número sem ambiguidade entre piquetes | — Pending |
| Soft delete em todas entidades | Histórico reprodutivo e sanitário precisa de referências históricas intactas | — Pending |
| Movimentação via RPC SECURITY DEFINER, não UPDATE direto | RLS `WITH CHECK` não inspeciona `lot_id`/`paddock_id`, então um UPDATE direto não consegue validar o destino. O RPC valida origem ativa, associação, papel, no-op e destino na mesma propriedade | Phase 4 — Validated (UAT 8/8) |
| Trigger de isolamento além do RPC | Um veterinário membro de várias propriedades tem JWT válido para cada uma e pode montar PATCH cru direto no PostgREST, contornando o RPC. `trg_animals_lot_same_property` e `trg_lots_paddock_same_property` são a última linha, independentes do caminho de escrita | Phase 4 — Validated (provado com UPDATE superuser, que ignora RLS e mesmo assim é barrado) |
| Lotes só acessíveis descendo por piquete (D-03) | Rota `/lotes/:loteId` é root-level e não há lista de lotes; `AppRoutes.lotes` segue constante morta | Phase 4 — Questionado no UAT (F-04-05). Botão voltar resolveu o beco sem saída; a lista própria segue em aberto no roadmap |

## Evolution

Este documento evolui a cada transição de fase e milestone.

**Após cada transição de fase** (via `/gsd-transition`):
1. Requisitos invalidados? → Mover para Out of Scope com motivo
2. Requisitos validados? → Mover para Validated com referência da fase
3. Novos requisitos emergiram? → Adicionar em Active
4. Decisões a registrar? → Adicionar em Key Decisions
5. "What This Is" ainda preciso? → Atualizar se divergiu

**Após cada milestone** (via `/gsd-complete-milestone`):
1. Revisão completa de todas as seções
2. Checar Core Value — ainda é a prioridade certa?
3. Auditar Out of Scope — motivos ainda válidos?
4. Atualizar Context com estado atual

---
*Last updated: 2026-08-21 after v1.0 milestone*
