# Roadmap — Campo Gestor

**Created:** 2026-04-24
**Granularity:** fine (8-12 phases)
**Total v1 requirements:** 26
**Coverage:** 26/26 mapped

---

## Phases

- [x] **Phase 0: Foundation** — Flutter scaffold, Supabase init, AppShell, currentPropertyProvider; sem features de domínio
- [ ] **Phase 1: Auth & Multi-tenancy Core** — Login email/senha, perfis, vínculo veterinário↔propriedade, propriedade ativa, RLS completo
- [ ] **Phase 2: Property & Paddock Structure** — CRUD de propriedade e piquete; protótipos de risco (numeração RPC, snapshot JSONB, ATF partial unique index)
- [ ] **Phase 3: Lots & Animals (Operational Core)** — Lote operacional CRUD, criação em batch de animais via RPC, edição e ficha do animal, busca/filtro, baixa
- [x] **Phase 4: Movements** — Mover animal entre lotes, mover lote inteiro entre piquetes (atômico via RPC) (completed 2026-08-04)
- [ ] **Phase 5: Reproductive Module (LoteATF)** — CRUD LoteATF, validação 1 ATF ativo/animal, DG, % prenhez, histórico reprodutivo na ficha
- [ ] **Phase 6: Sanitary Module (Snapshot)** — Doses, aplicação sanitária com snapshot congelado, desmarcar individuais, histórico por lote e por animal
- [ ] **Phase 7: Expenses by Paddock** — Lançamento de gasto vinculado a piquete, total por período
- [ ] **Phase 8: Animal Dossier Consolidation** — Ficha consolidada do animal cruzando lote atual + histórico reprodutivo + histórico sanitário num único view

---

## Phase Details

### Phase 0: Foundation

**Goal:** Aplicação Flutter web roda localmente conectada ao Supabase, com shell de navegação e gerenciamento de estado pronto para receber features de domínio.
**Depends on:** Nothing (first phase)
**Requirements:** (none — pure infrastructure, prerequisite for all)
**Success Criteria** (what must be TRUE):

  1. Desenvolvedor consegue rodar `flutter run -d chrome` (ou `-d edge`) e ver a app shell renderizada (header, navegação lateral, área de conteúdo) em <2s de TTI em 4G simulado
  2. Migrações SQL versionadas no git executam contra Supabase local (`supabase db reset`) sem erro
  3. `currentPropertyProvider` (Riverpod) está implementado e disponível em qualquer feature, mesmo que ainda retorne null
  4. GoRouter está configurado com rotas web-friendly (URLs deep-linkables, back button funcional) e guards de auth ainda permissivos (placeholder)
  5. Camada de Repository/Service base implementada — features futuras nunca importam Supabase SDK diretamente

**Plans:** 5/6 plans executed
Plans:

- [x] 00-01-PLAN.md — Wave 0 test scaffolding + verification scripts + analysis_options
- [x] 00-02-PLAN.md — Environment prereqs (Supabase CLI install) + .gitignore + launch.json.example + README
- [x] 00-03-PLAN.md — pubspec.yaml full Phase 0 stack + codegen pipeline validation
- [x] 00-04-PLAN.md — Core scaffolding (theme, env, SupabaseService, currentPropertyProvider, GoRouter, 5 placeholder screens)
- [x] 00-05-PLAN.md — Adaptive AppShell (NavigationRail/NavigationBar) + PropertySelector + wire into router
- [x] 00-06-PLAN.md — main.dart bootstrap + supabase init/start + SC-2 db reset + SC-1 integration smoke test

**UI hint:** yes

### Phase 1: Auth & Multi-tenancy Core

**Goal:** Usuário se cadastra, faz login, vê apenas dados das propriedades às quais pertence, e troca a propriedade ativa quando tem acesso a múltiplas.
**Depends on:** Phase 0
**Requirements:** AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05
**Success Criteria** (what must be TRUE):

  1. Usuário pode se cadastrar com email/senha, receber email de confirmação e fazer login; sessão persiste entre reloads
  2. Usuário com 0 propriedades vê tela de "sem acesso"; com 1 propriedade entra direto; com N propriedades vê seletor e pode trocar a propriedade ativa via UI
  3. Tabela `property_members` define perfil (proprietário/veterinário/leitor) por (user_id, property_id); UI consulta o perfil ativo
  4. Teste negativo automatizado prova que usuário A NÃO consegue ler/escrever dados da propriedade do usuário B via API direta (RLS fechada em todas tabelas com `FORCE ROW LEVEL SECURITY`)
  5. Logout limpa sessão e redireciona para tela de login

**Plans:** TBD
**UI hint:** yes

### Phase 2: Property & Paddock Structure

**Goal:** Usuário (proprietário) estrutura sua fazenda criando a propriedade e seus piquetes; protótipos críticos validados em ambiente real.
**Depends on:** Phase 1
**Requirements:** PROP-01, PROP-02
**Success Criteria** (what must be TRUE):

  1. Usuário pode criar, editar, listar e dar soft-delete em propriedades das quais é proprietário
  2. Dentro de uma propriedade ativa, usuário pode criar/editar/listar piquetes com nome, área (ha) e capacidade
  3. RPC de numeração de animais existe, foi testada sob concorrência simulada (2+ requests paralelos) e nunca produz número duplicado
  4. Estrutura de coluna JSONB para snapshot está definida com triggers que bloqueiam UPDATE/DELETE no nível do banco
  5. Partial unique index `WHERE deleted_at IS NULL` para ATF uniqueness está criado e validado com teste que tenta inserir 2 ATFs ativos para o mesmo animal e recebe erro de banco

**Plans:** TBD
**UI hint:** yes

### Phase 3: Lots & Animals (Operational Core)

**Goal:** Usuário cria lote operacional informando composição inicial e o sistema gera os animais individualmente; usuário consulta, edita, busca, filtra e dá baixa em animais.
**Depends on:** Phase 2
**Requirements:** PROP-03, PROP-04, PROP-05, ANIM-01, ANIM-02, ANIM-04, ANIM-05, ANIM-06
**Success Criteria** (what must be TRUE):

  1. Ao criar lote informando "10 vacas, 8 terneiros, 1 touro", o sistema gera 19 animais com números únicos e contínuos por categoria via RPC; lote aparece na lista com composição correta
  2. Usuário pode editar atributos individuais do animal (raça, estado corporal 1–5, observação) e ver mudanças refletidas imediatamente
  3. Usuário pode buscar animal por número dentro da propriedade ativa e o resultado abre a ficha (mesmo que ainda parcial — sem reprodutivo/sanitário)
  4. Usuário pode filtrar lista de animais por categoria, lote e piquete combinadamente, e ver contagem por categoria + UA total atualizada
  5. Usuário pode registrar baixa de animal com motivo (venda/morte/descarte) e data; animal sai da composição ativa do lote mas permanece referenciável em históricos

**Plans:** 6 plans
Plans:

- [x] 03-01-PLAN.md — Wave 0 test scaffolds (7 stub files for Nyquist sampling)
- [x] 03-02-PLAN.md — Migration: lots table + animals extension + generate_animal_number fix + create_lot_with_animals RPC + db push
- [x] 03-03-PLAN.md — Data layer: Lot/Animal freezed models, repositories, providers, animal_constants (kBreeds/kUaWeights/BaixaReason)
- [x] 03-04-PLAN.md — Routing (/lotes/:id root + /animais/:id nested) + PaddockDetailScreen expansion + LoteFormDialog (batch creation)
- [x] 03-05-PLAN.md — LoteDetailScreen (header + animal list + FAB) + AnimalFormDialog (individual creation) + lot-card subtitle composition
- [x] 03-06-PLAN.md — AnimaisScreen (search + filters + archived toggle) + AnimalDetailScreen + AnimalEditDialog + BaixaDialog

**UI hint:** yes

### Phase 4: Movements

**Goal:** Usuário move animais entre lotes e lotes inteiros entre piquetes sem nunca observar estados parciais ou perder dados.
**Depends on:** Phase 3
**Requirements:** MOV-01, MOV-02
**Success Criteria** (what must be TRUE):

  1. Usuário pode mover um animal individual para outro lote da mesma propriedade; composição dos dois lotes atualiza imediatamente
  2. Usuário pode mover um lote inteiro para outro piquete via uma única ação; todos animais migram atomicamente (RPC) — falha em qualquer passo reverte tudo
  3. Movimentações são bloqueadas para usuários com perfil "leitor"
  4. Tentativa de mover animal para lote de propriedade diferente é rejeitada pelo RLS/RPC com erro claro

**Plans:** 7/7 plans complete
Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Wave 0 Nyquist test scaffolds (5 new + 1 extended test file)
- [x] 04-02-PLAN.md — MOV-01: AnimalRepository.moveAnimal + loteListByPropertyProvider + MoverAnimalDialog + AnimalDetailScreen button wiring
- [x] 04-04-PLAN.md — [gap] SC-4: move_animal_to_lot SECURITY DEFINER RPC (cross-property rejection) + moveAnimal rewire + push both Phase-4 migrations
- [x] 04-05-PLAN.md — [gap] WR-01..04 dialog fixes (invalidations, mounted guard, pt-BR plural) + submit-flow behavior tests for both dialogs
- [x] 04-06-PLAN.md — [gap] SC-4 (reopened): BEFORE INSERT/UPDATE trigger enforcing animals.lot_id ∈ property_id (access-path-independent) + WR-01 deleted_at re-check + pgTAP; lots.paddock_id bypass documented-deferred
- [x] 04-07-PLAN.md — [gap] MOV-02: BEFORE INSERT/UPDATE trigger enforcing lots.paddock_id ∈ property_id (mirrors animals trigger) — closes the previously-deferred lots.paddock_id raw-PATCH bypass + pgTAP lots assertions

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-03-PLAN.md — MOV-02: move_lot_to_paddock RPC migration + LoteRepository.moveLot + MoverLoteDialog + LoteDetailScreen button wiring + supabase db push

**UI hint:** yes

### Phase 5: Reproductive Module (LoteATF)

**Goal:** Usuário gerencia ciclos reprodutivos criando LoteATF, registrando DGs por animal e consultando o histórico reprodutivo de cada animal.
**Depends on:** Phase 3 (animais existem)
**Requirements:** REPR-01, REPR-02, REPR-03, REPR-04, REPR-05
**Success Criteria** (what must be TRUE):

  1. Usuário cria LoteATF informando nome, data de implantação, data de inseminação, touro e observação
  2. Ao adicionar animais ao LoteATF, sistema só apresenta vacas e novilhas; sistema rejeita animais já em outro ATF ativo com mensagem clara
  3. Usuário registra DG por animal (prenha / não-prenha / duvidosa + data + observação); registros são editáveis até encerramento manual do lote
  4. % de prenhez é exibido no LoteATF e atualiza automaticamente conforme DGs vão sendo registrados (= prenhas / total DG realizados × 100)
  5. Histórico reprodutivo do animal mostra todos LoteATFs em que participou com respectivos resultados de DG

**Plans:** 2/10 plans executed

Plans:
**Wave 1**

- [x] 05-01-PLAN.md — DB schema: atf_batches, dg_records, animal_atf_memberships activation, RLS, isolation/category/baixa triggers
- [x] 05-02-PLAN.md — Dart data layer: freezed models, summarizeDg (% prenhez), AtfRepository + providers

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 05-03-PLAN.md — SECURITY DEFINER write surface: add/remove animals, save DGs, close ATF, register_baixa
- [ ] 05-04-PLAN.md — Root-level /atf/:atfId route + AtfDetailScreen shell and header card

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 05-05-PLAN.md — ReproducaoScreen ATF list + AtfFormDialog creation form (REPR-01)
- [ ] 05-06-PLAN.md — AtfAnimalSelectionScreen + composition management (REPR-02)
- [ ] 05-07-PLAN.md — Reproductive history on the animal ficha (REPR-05) + registerBaixa RPC rewire

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 05-08-PLAN.md — DG mass-entry section with session date and chip rows (REPR-03/REPR-04)

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 05-09-PLAN.md — Manual encerramento: banner, AppBar action, EncerrarAtfDialog

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 05-10-PLAN.md — [BLOCKING] supabase db push + pgTAP run + human UAT checkpoint

**UI hint:** yes

### Phase 6: Sanitary Module (Snapshot)

**Goal:** Usuário cadastra doses, registra aplicações sanitárias em lotes com snapshot imutável da composição, e consulta histórico por lote e por animal.
**Depends on:** Phase 3 (animais existem) — paralelizável com Phase 5
**Requirements:** SANI-01, SANI-02, SANI-03, SANI-04, SANI-05
**Success Criteria** (what must be TRUE):

  1. Usuário cadastra dose com nome e valor por kg; sistema calcula e exibe `valor_por_ua = valor_por_kg × 400` (campo não editável)
  2. Ao registrar aplicação em um lote, sistema mostra todos animais ativos do lote pré-selecionados; usuário pode desmarcar individuais antes de confirmar
  3. Após confirmação, snapshot da composição (animais aplicados + categorias + UA + dose) é gravado e nunca mais muda — tentativa de UPDATE/DELETE é bloqueada pelo banco
  4. Usuário visualiza histórico sanitário do lote ordenado por data com lista de aplicações
  5. Usuário visualiza histórico sanitário de um animal específico via lookup nos snapshots, mesmo que o animal já tenha sido movido para outro lote

**Plans:** TBD
**UI hint:** yes

### Phase 7: Expenses by Paddock

**Goal:** Usuário lança gastos vinculados a piquetes e consulta totais por período.
**Depends on:** Phase 2 (piquetes existem) — paralelizável com Phases 3–6
**Requirements:** GAST-01, GAST-02
**Success Criteria** (what must be TRUE):

  1. Usuário pode lançar gasto vinculado a um piquete com categoria, valor, data e descrição
  2. Usuário pode visualizar lista de gastos de um piquete filtrada por intervalo de datas
  3. Total agregado do período é exibido no topo da lista e atualiza ao mudar o filtro
  4. Gastos respeitam isolamento multi-tenant via RLS (mesmo padrão das outras tabelas)

**Plans:** TBD
**UI hint:** yes

### Phase 8: Animal Dossier Consolidation

**Goal:** Veterinário em campo abre a ficha do animal e vê em uma única tela todos os dados, lote atual, histórico reprodutivo completo e histórico sanitário completo — entregando o core value do produto.
**Depends on:** Phases 5 and 6
**Requirements:** ANIM-03
**Success Criteria** (what must be TRUE):

  1. Ficha do animal abre via busca por número (ANIM-05) ou clique na lista, em <1s sob conexão 4G
  2. Ficha exibe: dados do animal, lote operacional atual, piquete atual, todos LoteATFs (com DGs), todas aplicações sanitárias (via snapshot lookup)
  3. Histórico reprodutivo e sanitário são ordenados por data decrescente
  4. Animal com baixa registrada mostra status, motivo e data de baixa de forma proeminente
  5. Layout funciona em mobile web (largura mínima 360px) — veterinário consulta em campo pelo celular

**Plans:** TBD
**UI hint:** yes

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Foundation | 6/6 | Complete | 2026-05-03 |
| 1. Auth & Multi-tenancy Core | 0/0 | Not started | - |
| 2. Property & Paddock Structure | 0/0 | Not started | - |
| 3. Lots & Animals | 0/6 | Not started | - |
| 4. Movements | 7/7 | Complete    | 2026-08-04 |
| 5. Reproductive Module | 2/10 | In Progress|  |
| 6. Sanitary Module | 0/0 | Not started | - |
| 7. Expenses by Paddock | 0/0 | Not started | - |
| 8. Animal Dossier Consolidation | 0/0 | Not started | - |

---

## Coverage Map

| Requirement | Phase |
|---|---|
| AUTH-01 | Phase 1 |
| AUTH-02 | Phase 1 |
| AUTH-03 | Phase 1 |
| AUTH-04 | Phase 1 |
| AUTH-05 | Phase 1 |
| PROP-01 | Phase 2 |
| PROP-02 | Phase 2 |
| PROP-03 | Phase 3 |
| PROP-04 | Phase 3 |
| PROP-05 | Phase 3 |
| ANIM-01 | Phase 3 |
| ANIM-02 | Phase 3 |
| ANIM-03 | Phase 8 |
| ANIM-04 | Phase 3 |
| ANIM-05 | Phase 3 |
| ANIM-06 | Phase 3 |
| MOV-01 | Phase 4 |
| MOV-02 | Phase 4 |
| REPR-01 | Phase 5 |
| REPR-02 | Phase 5 |
| REPR-03 | Phase 5 |
| REPR-04 | Phase 5 |
| REPR-05 | Phase 5 |
| SANI-01 | Phase 6 |
| SANI-02 | Phase 6 |
| SANI-03 | Phase 6 |
| SANI-04 | Phase 6 |
| SANI-05 | Phase 6 |
| GAST-01 | Phase 7 |
| GAST-02 | Phase 7 |

**Total mapped:** 26/26 v1 requirements (100%)
**Orphans:** 0

---

## Parallelization Notes

- **Phase 5 (Reprodutivo)** and **Phase 6 (Sanitário)** can be executed in parallel after Phase 3
- **Phase 7 (Gastos)** is independent of Phases 3–6 and can be slotted at any time after Phase 2
- **Phase 4 (Movements)** ideally runs before 5/6 so reproductive/sanitary modules can rely on stable lot composition

---

## Notes

- Phase 0 has no requirement IDs because it is pure infrastructure prerequisite — without it, no other phase can begin. Validated by SUMMARY.md ("pré-requisito de tudo").
- ANIM-03 (ficha consolidada) was deliberately deferred to Phase 8 because it cross-cuts reproductive (Phase 5) and sanitary (Phase 6). Earlier phases deliver partial fichas; Phase 8 finalizes the consolidated view that delivers the core value.
- Phase 2 absorbs the "risk-retirement prototypes" requested in the brief: numbering RPC, snapshot JSONB structure, and ATF partial unique index. They are validated here even though only PROP-01/PROP-02 are formally consumed by user-facing features in this phase.
- 6 open decisions from research/SUMMARY.md must be resolved before Phase 1 coding (numbering scope, soft-delete reusability, ATF closure mode, sanitary default selection, auth method, Supabase plan).
