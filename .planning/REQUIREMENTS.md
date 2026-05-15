# Requirements — Campo Gestor

**Scoped:** 2026-04-26
**Status:** v1 requirements defined and scoped

---

## v1 Requirements

### Authentication & Multi-tenancy (AUTH)

- [ ] **AUTH-01**: Usuário pode se cadastrar e fazer login com email e senha
- [ ] **AUTH-02**: Sistema suporta 3 perfis por propriedade: proprietário, veterinário, leitor
- [ ] **AUTH-03**: Veterinário pode ser vinculado a múltiplas propriedades via tabela de permissões
- [ ] **AUTH-04**: Usuário com múltiplas propriedades pode selecionar a propriedade ativa na UI
- [ ] **AUTH-05**: Isolamento de dados por propriedade via RLS (usuário nunca vê dados de outra fazenda)

### Propriedade / Piquete / Lote (PROP)

- [ ] **PROP-01**: Usuário pode criar, editar e listar propriedades (nome, proprietário)
- [ ] **PROP-02**: Usuário pode criar, editar e listar piquetes de uma propriedade (nome, área em ha, capacidade)
- [ ] **PROP-03**: Usuário pode criar, editar e listar lotes operacionais de um piquete (nome, piquete)
- [ ] **PROP-04**: Ao criar lote, usuário informa composição inicial por categoria e sistema gera animais em batch automaticamente
- [ ] **PROP-05**: Usuário pode visualizar composição atual do lote (lista de animais com contagem por categoria e total de UA)

### Animal (ANIM)

- [ ] **ANIM-01**: Cada animal gerado recebe número único por (propriedade, categoria) via sequence + lock no banco
- [ ] **ANIM-02**: Usuário pode editar animal individualmente (raça, estado corporal 1–5, observação)
- [ ] **ANIM-03**: Usuário pode visualizar ficha consolidada do animal (dados, lote atual, histórico reprodutivo, histórico sanitário)
- [ ] **ANIM-04**: Usuário pode registrar baixa de animal com motivo (venda/morte/descarte) e data (soft delete)
- [ ] **ANIM-05**: Usuário pode buscar animal por número dentro da propriedade
- [ ] **ANIM-06**: Usuário pode filtrar lista de animais por categoria, lote e piquete

### Movimentação (MOV)

- [ ] **MOV-01**: Usuário pode mover animal individual para outro lote da mesma propriedade
- [ ] **MOV-02**: Usuário pode mover lote inteiro para outro piquete; todos os animais movem atomicamente via RPC

### Reprodutivo — LoteATF (REPR)

- [ ] **REPR-01**: Usuário pode criar LoteATF com nome, data implantação, data inseminação, touro, observação
- [ ] **REPR-02**: Ao criar LoteATF, usuário seleciona animais (apenas vacas e novilhas aceitas); sistema valida que nenhum já está em ATF ativo
- [ ] **REPR-03**: Usuário pode registrar DG por animal do LoteATF (prenha / não-prenha / duvidosa + data + observação)
- [ ] **REPR-04**: Sistema calcula automaticamente % de prenhez = prenhas / total DG realizados × 100
- [ ] **REPR-05**: Usuário pode visualizar histórico reprodutivo de um animal (todos ATFs e DGs que participou)

### Sanitário (SANI)

- [ ] **SANI-01**: Usuário pode cadastrar princípios ativos / doses (nome, valor por kg); valor por UA calculado automaticamente (valor/kg × 400)
- [ ] **SANI-02**: Usuário pode registrar aplicação sanitária em um lote; sistema captura snapshot congelado da composição no momento (imutável após criação)
- [ ] **SANI-03**: Ao registrar aplicação, usuário pode desmarcar animais individuais antes de confirmar (default = todos do lote)
- [ ] **SANI-04**: Usuário pode visualizar histórico sanitário de um lote (todas aplicações por data)
- [ ] **SANI-05**: Usuário pode visualizar histórico sanitário de um animal na ficha (via lookup no snapshot das aplicações)

### Gastos por Piquete (GAST)

- [ ] **GAST-01**: Usuário pode lançar gasto vinculado a um piquete (categoria, valor, data, descrição)
- [ ] **GAST-02**: Usuário pode visualizar total de gastos de um piquete por período (filtro por data)

---

## v2 Requirements (Deferred)

- Registro de parto e vínculo mãe↔cria
- Histórico de peso (série temporal)
- Calendário sanitário e protocolos agendados
- Exportação CSV/Excel
- Breakdown de gastos por categoria no piquete
- Indicadores consolidados: UA/ha por piquete, custo por animal
- Notificações in-app (DG pendente, etc.)

---

## Out of Scope

- Mapa e geolocalização — complexidade não justificada no MVP
- Compra e venda de animais — módulo contábil separado
- Controle de estoque de medicamentos — apenas custo/aplicação
- Histórico detalhado de composição passada do lote — apenas composição atual
- Permissões granulares por módulo — 3 perfis resolvem MVP
- Relatórios e dashboards avançados — pós-MVP
- Offline-first com sincronização — sistema assume conectividade
- App mobile nativo dedicado — web responsivo no MVP
- Notificações push — pós-MVP
- Importação de planilha — pós-MVP

---

## Business Rules (Constraints on Requirements)

| Regra | REQ relacionado |
|---|---|
| Animal.numero único por (propriedade, categoria) — não reutilizável após soft delete | ANIM-01, ANIM-04 |
| Animal obrigatoriamente pertence a 1 lote; nunca existe sem lote | PROP-04, MOV-01 |
| LoteATF aceita apenas vacas e novilhas | REPR-02 |
| Animal pode estar em no máximo 1 LoteATF ativo simultaneamente (partial unique index) | REPR-02 |
| Snapshot sanitário imutável após INSERT — sem UPDATE, sem DELETE via RLS | SANI-02 |
| dose.valor_por_ua = valor_por_kg × 400 (calculado, não editável) | SANI-01 |
| Mover lote = operação atômica; falha parcial não permitida | MOV-02 |
| UA por categoria: vaca=1.0, terneiro=0.5, touro=1.5, boi=1.5, novilho=0.75, novilha=0.75 | PROP-05, SANI-02 |

---

## Traceability

**Roadmap:** see `.planning/ROADMAP.md`
**Updated:** 2026-04-24

| Requirement | Phase | Status |
|---|---|---|
| AUTH-01 | Phase 1 — Auth & Multi-tenancy Core | Pending |
| AUTH-02 | Phase 1 — Auth & Multi-tenancy Core | Pending |
| AUTH-03 | Phase 1 — Auth & Multi-tenancy Core | Pending |
| AUTH-04 | Phase 1 — Auth & Multi-tenancy Core | Pending |
| AUTH-05 | Phase 1 — Auth & Multi-tenancy Core | Pending |
| PROP-01 | Phase 2 — Property & Paddock Structure | Pending |
| PROP-02 | Phase 2 — Property & Paddock Structure | Pending |
| PROP-03 | Phase 3 — Lots & Animals | Pending |
| PROP-04 | Phase 3 — Lots & Animals | Pending |
| PROP-05 | Phase 3 — Lots & Animals | Pending |
| ANIM-01 | Phase 3 — Lots & Animals | Pending |
| ANIM-02 | Phase 3 — Lots & Animals | Pending |
| ANIM-03 | Phase 8 — Animal Dossier Consolidation | Pending |
| ANIM-04 | Phase 3 — Lots & Animals | Pending |
| ANIM-05 | Phase 3 — Lots & Animals | Pending |
| ANIM-06 | Phase 3 — Lots & Animals | Pending |
| MOV-01 | Phase 4 — Movements | Pending |
| MOV-02 | Phase 4 — Movements | Pending |
| REPR-01 | Phase 5 — Reproductive Module | Pending |
| REPR-02 | Phase 5 — Reproductive Module | Pending |
| REPR-03 | Phase 5 — Reproductive Module | Pending |
| REPR-04 | Phase 5 — Reproductive Module | Pending |
| REPR-05 | Phase 5 — Reproductive Module | Pending |
| SANI-01 | Phase 6 — Sanitary Module | Pending |
| SANI-02 | Phase 6 — Sanitary Module | Pending |
| SANI-03 | Phase 6 — Sanitary Module | Pending |
| SANI-04 | Phase 6 — Sanitary Module | Pending |
| SANI-05 | Phase 6 — Sanitary Module | Pending |
| GAST-01 | Phase 7 — Expenses by Paddock | Pending |
| GAST-02 | Phase 7 — Expenses by Paddock | Pending |

**Coverage:** 26/26 v1 requirements mapped (100%)
**Orphans:** 0
**Note:** Phase 0 (Foundation) has no requirement IDs — pure infrastructure prerequisite per research/SUMMARY.md.
