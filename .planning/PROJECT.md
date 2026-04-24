# Campo Gestor

## What This Is

App de gestão de propriedades rurais voltado para pecuária. Permite estruturar a propriedade em piquetes, organizar lotes, controlar animais individualmente, registrar histórico reprodutivo e sanitário, e oferecer visão operacional e gerencial do rebanho. Atende veterinários e proprietários de fazenda.

## Core Value

O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo por quem toma decisões operacionais.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Estruturar propriedade com piquetes e lotes (hierarquia Propriedade → Piquete → Lote → Animal)
- [ ] Gerar e controlar animais individualmente por lote
- [ ] Registrar e consultar histórico reprodutivo (lote ATF, DG, % prenhez)
- [ ] Registrar e consultar histórico sanitário (aplicações com snapshot congelado)
- [ ] Controlar gastos por piquete
- [ ] Autenticar usuários com perfis: proprietário, veterinário, leitor

### Out of Scope

- Mapa e geolocalização — fora da fase inicial, adiciona complexidade desnecessária agora
- Compra e venda de animais — módulo separado, não é prioridade do MVP
- Controle de estoque de medicamentos — apenas custo/aplicação por ora
- Histórico detalhado de composição passada do lote — apenas composição atual importa
- Permissões granulares por módulo — perfis simples no MVP
- Relatórios e dashboards avançados — pós-MVP

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
*Last updated: 2026-04-24 after initialization*
