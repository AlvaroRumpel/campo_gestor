# Phase 7: Expenses by Paddock - Research

**Researched:** 2026-08-11
**Domain:** Flutter/Riverpod/Supabase CRUD feature + cross-phase schema extension (sanitary snapshot freeze)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Categorias de gasto

- **D-01:** Categorias são **constante no Dart**, não tabela. Um `expense_constants.dart` no padrão de `kBreeds` / `BaixaReason` (`animal_constants.dart`). Zero tela de cadastro, zero migration extra, dropdown direto. Custo aceito: mudar a lista exige deploy do Flutter — categoria de gasto rural muda pouco. Tabela cadastrável `expense_categories` (padrão `doses`) foi apresentada e recusada por quase dobrar o tamanho da fase; texto livre foi recusado por matar o breakdown por categoria do v2.
- **D-02:** Lista inicial de **8 categorias operacionais**: Ração/Suplementação, Sanidade/Medicamentos, Mão de obra, Manutenção (cerca/aguada/benfeitoria), Pastagem/Adubação, Combustível, Arrendamento, Outros. Cobre o gasto rural típico sem virar plano de contas.
- **D-03:** Coluna `category text NOT NULL` **sem CHECK constraint** — padrão de `animals.breed` com `kBreeds`, não de `animals.baixa_reason`. Adicionar ou renomear categoria é só deploy do Flutter, zero migration. Custo aceito e conhecido: um PATCH cru pode gravar categoria fora da lista (dado sujo, não brecha de segurança) e o breakdown por categoria (v2) tende a fazer a lista mexer.
- **D-04:** Obrigatórios: `paddock_id`, `category`, `amount`, `expense_date`. **`description text NULL`** — a categoria já diz o que é, e exigir texto trava o lançamento rápido em campo. Mesma lógica do custo opcional da dose (D-11 Phase 6).
- **D-05:** Cada categoria tem um **`IconData`** próprio (mapa constante ao lado de `kExpenseCategories`), exibido no card da lista. Sem cor por categoria — 8 cores que funcionem em light e dark seriam decisão de design que nenhuma outra tela do app tomou.
- **D-06:** Dropdown de categoria no formulário: **ordem fixa da constante** (operação → estrutura → "Outros" por último), **começa vazio**, valida como obrigatório. Mesmo comportamento do dropdown de categoria em `AnimalFormDialog`. "Última usada" foi recusada por exigir estado que nenhuma tela do app mantém.
- **D-07:** A lista tem **filtro por categoria além do filtro de período**, combináveis, no idioma de filtros de `/animais` (D-18 Phase 3) e `/sanitario` (D-26 Phase 6). O total do topo respeita os dois filtros.

#### Navegação e telas

- **D-08:** Lista vive em **`/gastos/:paddockId` root-level**, fora do `AppShell` — quarto uso do padrão já estabelecido (`/lotes/:loteId` D-03 Phase 3, `/atf/:atfId` D-02 Phase 5, `/aplicacoes/:id` D-19 Phase 6). Constante em `AppRoutes` + helper `gastosPorPiquete(id)`. Seção dentro do `PaddockDetailScreen` foi recusada (filtro + total dentro de um `ListView` que já tem card e lotes fica apertado, e o FAB de lá já é "Novo lote"); 6ª branch no shell foi recusada (aperta a bottom bar no mobile, M3 recomenda 3–5, e mexeria em `AppShell._navItems` + `AppRoutes.all` + os testes que contam navegação).
- **D-09:** Entrada a partir do `PaddockDetailScreen` é um **card "Gastos" com o total do mês corrente**, abaixo do `_PaddockInfoCard`, tap abre a tela. Responde "quanto esse piquete custou" sem toque nenhum. Custo aceito: um `FutureProvider.family` a mais na tela de detalhe.
- **D-10:** Lançar gasto é **um FAB só, dentro de `/gastos/:paddockId`**. O piquete já vem resolvido pela rota — o campo "piquete" nem aparece no formulário. FAB duplo no `PaddockDetailScreen` foi recusado (o FAB de lá já é "Novo lote"; FAB expansível é padrão que o app não tem).
- **D-11:** Formulário de lançamento é **dialog** (`showDialog`), não tela cheia. Padrão unânime do app para formulário curto: `DoseFormDialog`, `LoteFormDialog`, `PaddockFormDialog`, `AnimalFormDialog`. Tela cheia foi usada só para seleção de 200 checkboxes (D-21 Phase 6).
- **D-12:** Tap num gasto da lista **abre o mesmo dialog em modo edição**. Sem rota de detalhe: o gasto tem 4 campos e o card já mostra todos. `/aplicacoes/:id` existe porque uma aplicação tem snapshot de 50 animais e é linkada de 3 origens — um gasto não justifica.
- **D-13:** **Empty state contextual**, distinguindo os dois casos: "Nenhum gasto lançado neste piquete" (nunca teve) vs "Nenhum gasto no período selecionado" com ação de limpar filtro (tem, mas o filtro escondeu). O total segue visível como R$ 0,00. Mesma classe do `_EmptyState` de `PiquetesScreen`.
- **D-14:** AppBar da tela mostra **"Gastos — {nome do piquete}"** com botão voltar explícito. Rota root-level acessada por deep-link não tem contexto sem isso, e o beco sem saída do botão voltar já foi achado 2x no UAT (F-04-05 Phase 4, G-05-1-nav Phase 5).

#### Período, ordenação e totais

- **D-15:** Intervalo default ao abrir: **mês corrente** (dia 1 até hoje). Casa com o card de resumo do piquete (D-09) — o número que o usuário viu antes de tocar é o mesmo que aparece depois. Ciclo de custo rural é mensal.
- **D-16:** Troca de período por **chips de preset + intervalo custom**: "Mês atual / Mês passado / Últimos 3 meses / Ano / Personalizado", com o último abrindo `showDateRangePicker` (já vem no Material, zero dependência nova). Caso comum em 1 toque.
- **D-17:** Total no topo mostra **valor em R$ + contagem de lançamentos**, respeitando período e categoria filtrados. Escopo literal do GAST-02. Custo por hectare e breakdown por categoria foram apresentados e recusados por serem requisitos v2 explícitos do REQUIREMENTS.md.
- **D-18:** Total é **somado no cliente**, sobre a lista já carregada, em função pura testável (mesmo recorte de `sanitary_calculations.dart`, D-40 Phase 6). Total e lista não têm como divergir por construção. **Teto conhecido:** se a lista virar paginada, a soma passa a ser da página — aí vira RPC de agregação. Registrar como comentário no código.
- **D-19:** Lista ordenada por **data do gasto decrescente, sem agrupamento**, com desempate por `created_at`. Espelha o histórico sanitário (`applied_at` desc, D-25 Phase 6). O desempate é lição direta do G-05-4, onde dois registros na mesma data embaralhavam.
- **D-20:** Valor: entrada em `TextField` com `FilteringTextInputFormatter` aceitando vírgula decimal, exibição via `NumberFormat.currency(locale: 'pt_BR')` — exatamente o que `DoseFormDialog` já faz com custo por kg. Coluna **`numeric(14,2)`** no banco, nunca float. Máscara de moeda viva foi recusada (exigiria package novo).
- **D-21:** Filtro **não persiste** entre visitas — toda entrada abre no mês corrente sem categoria. Estado local da tela, igual aos filtros de `/animais` e `/sanitario` hoje. Filtro grudado invisível explicaria mal por que o total diverge do card do piquete.

#### Correção, permissão e integridade

- **D-22:** Correção é **editar (UPDATE nos 4 campos) + soft delete (`deleted_at`)**, com toggle "Mostrar excluídos". Mesmo padrão de doses, lotes, animais e ATFs. Gasto **não** é histórico congelado — nada o lê como verdade imutável, ao contrário do snapshot sanitário. Linha de estorno imutável (padrão D-27 Phase 6) foi apresentada e recusada por dobrar a fase para corrigir erro de digitação.
- **D-23:** **Escrita liberada para `owner` E `veterinarian`.** Primeiro gate do projeto que não é `role == 'veterinarian'` puro — gasto é dado financeiro do dono da fazenda e ele precisa lançar o próprio gasto. Consequência: `_canEdit` **não** serve aqui; a fase precisa de um helper próprio (`_canManageExpenses` ou equivalente), e o `PaddockDetailScreen` passa a ter dois gates diferentes convivendo (FAB "Novo lote" = vet; card de gastos = vet + owner). Enum no banco é `role_enum ('owner','veterinarian','reader')`.
- **D-24:** **Leitura liberada a todo membro**, `reader` incluído: `SELECT` policy = `is_member_of(property_id)`, igual a todas as outras tabelas. Uma exceção de papel na fase, não duas. O leitor já vê rebanho e custo sanitário hoje.
- **D-25:** Escrita vai por **tabela direta + RLS policies**, não RPC. Precedente `DoseRepository`: escrita de linha única numa entidade só é totalmente coberta por policy; RPC SECURITY DEFINER é para escrita multi-linha ou cross-entity (D-21 Phase 5). Policies checam `is_member_of(property_id)` + `role IN ('owner','veterinarian')`. Usar **`.select().single()`** em todo UPDATE — PostgREST responde 2xx num UPDATE de 0 linhas, o silent no-op que virou G-06-2.
- **D-26:** **Trigger `BEFORE INSERT OR UPDATE` garantindo `expenses.paddock_id` ∈ `expenses.property_id`**, espelhando `trg_lots_paddock_same_property` (`20260717_04_lot_paddock_property_trigger.sql`). A RLS `WITH CHECK` olha `property_id` e não inspeciona `paddock_id`; um vet membro de 2 propriedades tem JWT válido para as duas e pode montar PATCH cru no PostgREST. Foi exatamente esse buraco que reabriu duas vezes na Phase 4 (04-06, 04-07). Não é opcional.
- **D-27:** Auditoria: **`created_by`** (`uuid NOT NULL DEFAULT auth.uid()`, FK para `auth.users`) **e `updated_by`** (via trigger `BEFORE UPDATE`). O cliente não envia nenhum dos dois. Com dois papéis podendo escrever (D-23), "quem lançou isso" importa de verdade. Sem UI nesta fase — as colunas nascem preenchidas.
- **D-28:** Excluir gasto pede **`AlertDialog` com valor e data** ("Excluir gasto de R$ 1.240,00 de 03/08?"). É soft delete recuperável, mas apagar lançamento financeiro por toque errado no celular é o que o dialog de resumo da Phase 6 (D-23) existe para evitar. Swipe-to-dismiss foi recusado (padrão inexistente no app, swipe acidental é comum em lista rolada).

#### Cruzamento com o módulo sanitário

- **D-29:** **O total do piquete inclui o custo das aplicações sanitárias daquele piquete.** Decisão explícita do usuário, tomada com o custo apresentado (acoplamento entre módulos + migration em tabela de outra fase). Alternativa "só lançamento manual, com o vet lançando o sanitário na categoria Sanidade/Medicamentos" foi apresentada como recomendada e recusada.
- **D-30:** Atribuição por **congelamento**: a migration desta fase acrescenta **`paddock_id` + `paddock_name` a `sanitary_applications`**, preenchidos pelo RPC de registro no momento da gravação. É exatamente o item "congelar o piquete do lote na aplicação" que a Phase 6 deixou no `<deferred>` citando esta fase. Historicamente correto — lote movido depois não reescreve o passado. **Join por `lots.paddock_id` atual foi explicitamente recusado**: mover um lote mudaria retroativamente o custo de agosto em setembro, a classe de bug que o snapshot da Phase 6 inteira existe para evitar.
- **D-31:** As aplicações **já existentes em PROD** (2 linhas criadas no UAT da Phase 6) recebem **backfill** via `lots.paddock_id` atual. É a única informação disponível para elas; documentar no cabeçalho da migration que essas duas linhas têm atribuição aproximada, não congelada.
- **D-32:** A lista de gastos é **unificada**: aplicações sanitárias aparecem como linhas na mesma lista ordenada por data, com ícone de sanidade, valor e badge "Sanitário", **read-only** (sem editar, sem excluir; tap → `/aplicacoes/:id`). Isso preserva a propriedade do D-18 — o total volta a ser a soma do que está na tela. O filtro de categoria trata "Sanitário" como pseudo-categoria.
- **D-33:** **Aplicações estornadas ficam fora da lista e do total** — nem a original, nem a linha de estorno. Aplica o D-29 da Phase 6 ("Totais sempre excluem estornadas") a esta tela. A soma bateria zero de qualquer jeito; mostrar as duas linhas só confunde quem confere na mão.

#### Escopo, testes e execução

- **D-34:** **`paddock_id NOT NULL`.** Escopo literal do GAST-01 — todo gasto tem piquete. Sem caso especial em query, filtro nem total. Gasto de fazenda inteira (arrendamento, salário, imposto) e rateio proporcional entre piquetes vão para o `<deferred>`; relaxar a coluna para NULL depois é migration de uma linha sem backfill, o contrário não é verdade.
- **D-35:** **Sem anexo de comprovante nesta fase.** Nenhum REQ pede, o CLAUDE.md marca Supabase Storage como "verificar a necessidade antes de adicionar", e o módulo já cresceu com o D-29. Storage traria bucket, policies próprias, upload no web, limite de tamanho e ciclo de vida do arquivo — superfície inteira nova.
- **D-36:** Testes: **pgTAP + Dart de cálculo E de gate de papel.** `supabase/tests/07_expenses_test.sql` cobre o que só o banco garante (trigger de isolamento cross-property, policy de escrita recusando `reader`, `SELECT` liberado a todo membro, soft delete). Dart cobre soma do total + filtro de período/categoria **e o gate de dois papéis** — regra nova sem precedente no app, exatamente a classe que vazou para o UAT nas Phases 5 e 6 (G-05-2/3, G-06-2). Recorte deliberadamente mais largo que o D-40 da Phase 6.
- **D-37:** **4 planos em 3 waves.** W1 (paralelo): (a) migration — tabela `expenses` + policies + trigger de isolamento + `paddock_id`/`paddock_name` em `sanitary_applications` + backfill + ajuste do RPC de registro; (b) camada de dados Dart — model freezed, `expense_constants.dart`, repository, providers, função pura de total. W2: UI — tela `/gastos/:paddockId` + dialog de formulário + card no `PaddockDetailScreen`. W3: **plano bloqueante dedicado** — `apply_migration` via MCP + replay de `07_expenses_test.sql` em transação revertida + checkpoint de UAT humano. Mesmo padrão do 05-10 e do 06-12: nas Phases 4 e 5 o push era tarefa 3 de um plano que "passou", e ficou BLOCKED com código em master sem banco por trás.

### Claude's Discretion

- **Aplicação sanitária sem custo** (`cost_per_kg` é NULL — D-11 Phase 6). Resolução recomendada, coerente com o D-11 ("nunca R$ 0,00"): a linha aparece na lista unificada com **"—"** no lugar do valor, contribui **0** no total e **conta** na contagem de itens. Se o planner divergir, registrar o porquê — não deixar o total silenciosamente menor sem sinal na tela.
- Nomes exatos de tabela e colunas (`expenses`, `amount`, `expense_date`, `category` são sugestões).
- Ícones exatos por categoria (D-05) e rótulos pt-BR finais das 8 categorias.
- Forma do modelo unificado da lista (D-32): sealed class freezed com duas variantes vs uma view model plana com um discriminador.
- Se o card de resumo do piquete (D-09) reusa o mesmo provider da tela ou tem um próprio com escopo de mês.
- Onde mora o helper de gate `owner + veterinarian` (D-23): utilitário em `core/` vs privado da feature.
- Nomes dos presets de período (D-16) e se "Ano" é ano civil ou últimos 12 meses.
- Estratégia de paginação/virtualização se a lista crescer — nada decidido agora (ver teto do D-18).

### Deferred Ideas (OUT OF SCOPE)

- **Gasto de propriedade sem piquete** (arrendamento da fazenda, salário, imposto) — `paddock_id` nasce `NOT NULL` (D-34). Relaxar para NULL depois é migration de uma linha sem backfill, mas exigiria uma tela global de gastos da propriedade, que é capacidade nova.
- **Rateio de gasto entre piquetes** (proporcional por ha ou por UA) — fase inteira sozinha: regra de rateio, lançamentos derivados, e o que acontece quando um piquete some.
- **Anexo de comprovante** (foto da nota via Supabase Storage) — D-35. Exigiria bucket, policies de storage, upload no web, limite de tamanho e ciclo de vida do arquivo. Primeira integração com Storage do projeto.
- **Breakdown de gastos por categoria no piquete** — requisito v2 explícito no REQUIREMENTS.md; oferecido e recusado (D-17). O filtro por categoria (D-07) já entrega a pergunta pontual.
- **Custo por hectare e demais indicadores consolidados** (UA/ha por piquete, custo por animal) — v2 no REQUIREMENTS.md; oferecido e recusado (D-17), mesmo com `paddock.area_ha` disponível.
- **Tabela `expense_categories` cadastrável por propriedade** — recusada em D-01. Vira migration + tela de CRUD se as 8 categorias fixas apertarem.
- **CHECK constraint na categoria** — recusada em D-03 em favor da flexibilidade de deploy; adicionar depois exigiria limpar valores fora da lista antes.
- **Ordenação por valor / agrupamento por mês na lista** — recusados em D-19 por acrescentarem controle numa tela que já tem filtro de período, de categoria e o total.
- **Persistência do filtro entre visitas** — recusada em D-21 por divergir do card de resumo do piquete.
- **Agregação do total no servidor** (RPC/view com `SUM`) — só quando a lista virar paginada; é o teto explícito do D-18.
- **RPC de escrita para gastos** — desnecessário enquanto for linha única em entidade só (D-25). Vira necessário se surgir lançamento em lote ou rateio.
- **UI de configuração das categorias** — sem tela nesta fase, a lista vive em constante Dart (D-01).

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GAST-01 | Usuário pode lançar gasto vinculado a um piquete (categoria, valor, data, descrição) | `ExpenseRepository` (Pattern 1) + `expenses` table/RLS/trigger (Code Examples) + `ExpenseFormDialog` mirroring `DoseFormDialog` (D-11/D-20); role gate `canManageExpenses` (Pattern 5) enforces who may create; trigger (Pattern 2) enforces `paddock_id ∈ property_id` |
| GAST-02 | Usuário pode visualizar total de gastos de um piquete por período (filtro por data) | Pure `expense_calculations.dart` total function (Pattern 3), unified-list merge (Pattern 4) folding in sanitary cost per D-29/D-30/D-32/D-33, period filter mirroring `SanitarioScreen._pickDateRange`/`_buildFilterRow` |
</phase_requirements>

## Summary

Phase 7 is a standard property-scoped CRUD feature (`expenses` table) with one real technical
wrinkle: D-29..D-33 pull the Phase 6 sanitary module into scope so the piquete total includes
sanitary cost. That wrinkle is almost entirely resolved by the CONTEXT.md decisions already — the
only piece research adds that CONTEXT.md did not surface is a **schema-level blocker**: Phase 2's
`prevent_snapshot_mutation()` trigger blocks *every* `UPDATE` on `sanitary_applications`
unconditionally (`BEFORE UPDATE OR DELETE`), so the D-31 backfill of `paddock_id`/`paddock_name`
on the 2 existing PROD rows cannot be a plain `UPDATE` statement — it will raise
`prevent_snapshot_mutation()`'s exception. The migration must disable/re-enable
`trg_snapshot_immutable` around the backfill `UPDATE`, inside the same transaction. This is
Common Pitfall #1 below and it changes the shape of the Wave 1(a) migration task.

Everything else in this phase has a direct precedent already committed in this codebase:
`DoseRepository` for the property-scoped single-table CRUD shape, `trg_lots_paddock_same_property`
for the isolation trigger, `sanitary_calculations.dart` for the pure total-calculation module, and
`SanitarioScreen`'s filter row / toggle / empty-state idiom for the UI. No new package is needed —
zero `pubspec.yaml` changes this phase (D-01, D-16, D-20, D-35 all resolve to already-installed
capability: Dart constants, `showDateRangePicker`, `FilteringTextInputFormatter`, no Storage).

**Primary recommendation:** Copy `DoseRepository`'s shape verbatim for `ExpenseRepository`
(direct-table CRUD, `.select().single()` on every UPDATE, `includeArchived` switch), copy
`trg_lots_paddock_same_property` verbatim for the new `expenses` isolation trigger, and handle the
`sanitary_applications` backfill with an explicit `DISABLE TRIGGER … UPDATE … ENABLE TRIGGER`
block inside the Phase 7 migration transaction.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Expense CRUD (create/edit/soft-delete) | API/Backend (Postgres RLS + direct table) | Frontend (Flutter form validation) | Single-row, single-entity write — RLS policies are the full guarantee (D-25); Dart validation is UX-only, never the security boundary |
| Cross-property isolation (`paddock_id ∈ property_id`) | Database (trigger) | — | RLS `WITH CHECK` only inspects `property_id`, not the `paddock_id`↔`property_id` pairing — the exact gap class that reopened twice in Phase 4 (04-06/04-07); only a trigger closes it (D-26) |
| Role gate (owner + veterinarian can write) | Database (RLS `get_role()`) | Frontend (control visibility only) | "Role gate na UI = controle ausente, não desabilitado" — established project principle; RLS is the enforcement, UI hiding is convenience |
| Period/category filtering | Frontend (Flutter, in-memory) | — | Mirrors `SanitarioScreen`/`AnimaisScreen` — filters run client-side over an already-fetched property-scoped list, no server-side filter param |
| Total aggregation (R$ + count) | Frontend (Flutter, pure function) | — | D-18: client-side sum over the loaded list, in a pure testable function — explicit ceiling documented for pagination |
| Sanitary-cost freeze (`paddock_id`/`paddock_name` on `sanitary_applications`) | Database (RPC write-time freeze) | — | Historical correctness requires the RPC to freeze the paddock at write time, not a live join through `lots.paddock_id` (D-30) |
| Unified list merge (manual + sanitary rows) | Frontend (Flutter, pure function over two already-fetched lists) | — | Both source lists (`expenses`, `sanitary_applications`) are already property/paddock-scoped fetches; merging and sorting is presentation logic, not a query concern |

## Standard Stack

### Core

No new package this phase. Every capability D-01 through D-37 requires is already satisfied by
the stack established in Phases 0–6:

| Library | Version (from `pubspec.yaml`, verified) | Purpose in this phase | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | `>=3.0.0 <4.0.0` | `FutureProvider`/`FutureProvider.family` for expense list, paddock summary card | Already the project's exclusive state layer (STATE.md: "all future phases must use Riverpod 3.x") |
| `supabase_flutter` | `^2.12.0` | `expenses` table CRUD, RPC edit for `register_sanitary_application`/`reverse_sanitary_application` | Existing client — no new endpoint type introduced |
| `freezed_annotation` / `freezed` | `^3.0.0` / `^3.2.0` | `Expense` model, `ExpenseListItem` sealed union (manual/sanitary) | Matches `SanitaryApplication`'s existing sealed-class shape |
| `json_serializable` | `^6.13.0` | `Expense.fromJson`/`toJson`, snake_case bridge to Postgres | Same `@JsonSerializable(fieldRename: FieldRename.snake)` idiom as every other model |
| `intl` | `^0.20.0` | pt-BR date/currency formatting, `Intl.plural` for "N lançamento(s)" | Already in use throughout `sanitario`/`piquetes` |
| `go_router` | `^17.2.0` | Root-level route `/gastos/:paddockId` (D-08) | Same pattern as `/lotes/:loteId`, `/atf/:atfId`, `/aplicacoes/:id` |

### Supporting

Nothing new. `showDateRangePicker` (Material, zero dependency) and
`FilteringTextInputFormatter` (`flutter/services.dart`, SDK-bundled) cover D-16/D-20 without a
package addition — both already used verbatim in `sanitario_screen.dart`/`dose_form_dialog.dart`.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Client-side total sum (D-18) | Postgres `SUM()` RPC/view | Only justified once the list is paginated — explicit documented ceiling, not needed at current scale |
| Direct table CRUD (D-25) | RPC `SECURITY DEFINER` for expense writes | Only needed for multi-row/cross-entity writes (this is single-row, single-entity — RLS covers it, mirrors `DoseRepository`) |
| `category text` no CHECK (D-03) | `expense_categories` cadastrable table | Recused explicitly — nearly doubles phase size, deferred |

**Installation:** none — no `pubspec.yaml` change this phase.

**Version verification:** All versions above read directly from the project's own
`F:\_geral\Projetos\campo_gestor\pubspec.yaml` (not re-fetched from the registry — this is an
already-installed, already-pinned stack, so registry re-verification would only restate what the
lockfile already guarantees). `[VERIFIED: pubspec.yaml]`.

## Package Legitimacy Audit

**Not applicable — this phase installs zero new packages.** `expense_constants.dart` follows the
existing `animal_constants.dart` pattern (plain Dart `const` collections), and every UI/date
control needed (`showDateRangePicker`, `FilteringTextInputFormatter`, `Intl.plural`) ships with
the Flutter SDK or the already-installed `intl` package. No `npm install` / `flutter pub add`
step exists in this phase's plan.

**Packages removed due to [SLOP] verdict:** none (N/A)
**Packages flagged as suspicious [SUS]:** none (N/A)

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────┐    ┌──────────────────────────────────┐
│ PaddockDetailScreen          │    │ /gastos/:paddockId (root-level)  │
│  _PaddockInfoCard            │    │  AppBar "Gastos — {piquete}"     │
│  LotsSection                 │    │  Filter row (period + category)  │
│  ┌─────────────────────────┐ │    │  Total header (R$ + count)       │
│  │ Expense summary card    │─┼───▶│  Unified list (ListView.builder) │
│  │ FutureProvider.family    │ │    │  FAB "Novo gasto"                │
│  │ (current-month scope)   │ │    └───────────────┬───────────────────┘
│  └─────────────────────────┘ │                    │ tap row
└───────────────────────────────┘                    ▼
                                          ┌────────────────────────┐
                                          │ ExpenseFormDialog        │
                                          │ (create/edit, D-11/D-12) │
                                          └───────────┬───────────────┘
                                                       │ submit
                                                       ▼
                          ┌────────────────────────────────────────────────┐
                          │ ExpenseRepository (direct table CRUD, D-25)     │
                          │  insert / update / archive / restore            │
                          └───────────────────┬──────────────────────────────┘
                                               ▼
        ┌───────────────────────────────────────────────────────────────────┐
        │ Postgres: expenses table                                          │
        │  RLS SELECT: is_member_of(property_id)                            │
        │  RLS INSERT/UPDATE: is_member_of + get_role IN (owner, vet) (D-23)│
        │  BEFORE INSERT/UPDATE trigger: paddock_id ∈ property_id (D-26)    │
        │  BEFORE UPDATE trigger: updated_by/updated_at (D-27)              │
        └───────────────────────────────────────────────────────────────────┘

        (unified list, read-only side, D-32/D-33)
        ┌───────────────────────────────────────────────────────────────────┐
        │ sanitary_application_repository.dart (Phase 6, unchanged reads)    │
        │  fetchApplicationsByProperty → filtered client-side to this        │
        │  paddock via SanitaryApplication.paddockId (new frozen column)     │
        └───────────────────────────────┬─────────────────────────────────────┘
                                         ▼
        ┌───────────────────────────────────────────────────────────────────┐
        │ Postgres: sanitary_applications (Phase 6, extended)                │
        │  + paddock_id uuid NOT NULL, + paddock_name text NOT NULL (D-30)   │
        │  frozen by register_sanitary_application at INSERT time            │
        │  (never a live join through lots.paddock_id — D-30 explicit)       │
        │  trg_snapshot_immutable still blocks all UPDATE/DELETE (Pitfall 1) │
        └───────────────────────────────────────────────────────────────────┘

Merge point (pure Dart, no I/O): both fetches (expenses-for-paddock,
sanitary-applications-for-paddock) feed one `List<ExpenseListItem>` sealed-union merge/sort/filter
function — the client never issues a joined SQL query for the unified list.
```

### Recommended Project Structure

```
lib/features/gastos/                    # pt-BR feature naming, matches sanitario/piquetes/lotes/animais/reproducao
├── data/
│   ├── expense_model.dart              # Expense (freezed) + ExpenseListItem sealed union
│   ├── expense_constants.dart          # kExpenseCategories, kExpenseCategoryIcons (D-01/D-05)
│   ├── expense_repository.dart         # direct-table CRUD, mirrors dose_repository.dart
│   └── expense_calculations.dart       # pure: totalAmount(), itemCount(), sortByDateDesc()
└── presentation/
    ├── gastos_screen.dart              # /gastos/:paddockId — filter row, total header, list, FAB
    ├── expense_form_dialog.dart        # create/edit dialog, mirrors dose_form_dialog.dart
    └── _expense_list_item_card.dart    # renders both ManualExpenseItem and SanitaryExpenseItem

supabase/migrations/
└── 20260813_07_expenses_module.sql     # expenses table + policies + triggers + sanitary_applications ALTER + RPC edits + backfill

supabase/tests/
└── 07_expenses_test.sql                # pgTAP, mirrors 06_sanitary_test.sql structure (D-36)
```

`lib/core/auth/role_gates.dart` (new, recommended location — see Claude's Discretion resolution
below) houses `canManageExpenses(current, members)`, the first non-`_canEdit` (vet-only) role
predicate in the project.

### Pattern 1: Property-scoped single-table CRUD (`DoseRepository` precedent)

**What:** A repository class wrapping `_service.client.from('table')` calls directly — no RPC —
for create/read/update/soft-delete of a single-row, single-entity resource.
**When to use:** Any write that touches exactly one row of exactly one table and whose invariants
are fully expressible as RLS policies + a `CHECK`/trigger. This is `expenses`' exact shape.
**Example (from the actual codebase, `lib/features/sanitario/data/dose_repository.dart:107-124`):**
```dart
/// `.select().single()` forces a thrown error when RLS or a stale/wrong id
/// silently matches zero rows — PostgREST otherwise answers 2xx on a 0-row
/// UPDATE, the exact silent no-op class fixed server-side for the dose
/// UPDATE policy in `20260812_06_fix_dose_update_policy.sql` (G-06-2).
Future<void> archiveDose(String id) async {
  await _service.client
      .from('doses')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id)
      .select()
      .single();
}
```
`ExpenseRepository.archiveExpense`/`restoreExpense`/`updateExpense` must use this exact
`.select().single()` idiom — every write.

### Pattern 2: Cross-table isolation trigger (`trg_lots_paddock_same_property` precedent)

**What:** A `BEFORE INSERT OR UPDATE` trigger that re-validates a foreign-key pairing RLS cannot
see, because RLS `WITH CHECK` on the child table only evaluates columns literally present in the
policy expression (`property_id`), never a join to the parent to confirm `paddock_id` belongs to
that same `property_id`.
**When to use:** Any table that has both (a) a direct RLS write policy (no RPC gate) and (b) two
FK columns that must agree on tenancy (`paddock_id` + `property_id` here). `expenses` has exactly
this shape (D-25: direct table, not RPC).
**Example (from `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql`, to mirror
literally for `expenses.paddock_id`):**
```sql
CREATE OR REPLACE FUNCTION enforce_expenses_paddock_same_property()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.paddock_id IS NOT NULL AND (
    TG_OP = 'INSERT'
    OR NEW.paddock_id IS DISTINCT FROM OLD.paddock_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM paddocks
       WHERE id = NEW.paddock_id
         AND property_id = NEW.property_id
         AND deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'paddock % does not belong to property % or is archived',
        NEW.paddock_id, NEW.property_id USING ERRCODE = '23503';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_expenses_paddock_same_property
  BEFORE INSERT OR UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION enforce_expenses_paddock_same_property();
```
The `IS DISTINCT FROM OLD.*` guard is deliberate (mirrors the lots trigger comment): a soft-delete
`UPDATE` on `expenses` touches only `deleted_at`, never `paddock_id`/`property_id`, so it does not
re-fire this validation and cannot false-positive on an archival/restore.

### Pattern 3: Pure calculation module, dependency-free (`sanitary_calculations.dart` precedent)

**What:** A file with zero Flutter/Riverpod/Supabase imports — plain functions over plain models —
so it runs under bare `flutter_test` with no widget harness.
**When to use:** Any total/aggregate the UI displays and a test must independently verify (D-18's
client-side sum, D-36's "Dart cobre soma do total").
**Example (from `lib/features/sanitario/data/sanitary_calculations.dart:56-61`):**
```dart
/// BRL symbol concatenated with a pattern-formatted number, rather than
/// `NumberFormat.currency` — the currency constructor inserts a
/// non-breaking space in some intl releases, which would make an
/// exact-string assertion environment-dependent.
String formatCurrencyBrl(double value) =>
    'R\$ ${_currencyDigitsFmt.format(value)}';
```
**Reuse this exact function** for `expenses` currency display — do not reintroduce
`NumberFormat.currency(locale: 'pt_BR')` as CONTEXT.md D-20 suggests in passing; the already-
committed `formatCurrencyBrl` avoids the non-breaking-space test-fragility issue documented right
in its own comment. Import it from `sanitary_calculations.dart` rather than duplicating the
formatter — the "computed field" tint idiom (`colorScheme.primary`) and the string shape must
match every other currency figure in the app pixel-for-pixel.

### Pattern 4: Sealed-union unified list, merged client-side

**What:** A freezed sealed class with two variants over two independently-fetched, already-scoped
lists, merged and sorted in a pure function — never a server-side `UNION`.
**When to use:** D-32's unified list (manual expenses + read-only sanitary rows). This mirrors
`SanitaryApplication`'s own sealed-class shape and the project's established preference for
Dart 3.5 pattern matching on domain unions (CLAUDE.md: "sealed unions ... perfect for domain
events").
**Recommended shape (new code, following the codebase's freezed idiom):**
```dart
@freezed
sealed class ExpenseListItem with _$ExpenseListItem {
  const factory ExpenseListItem.manual(Expense expense) = ManualExpenseItem;
  const factory ExpenseListItem.sanitary(SanitaryApplication application) =
      SanitaryExpenseItem;
}

DateTime dateOf(ExpenseListItem item) => switch (item) {
      ManualExpenseItem(:final expense) => expense.expenseDate,
      SanitaryExpenseItem(:final application) => application.appliedAt,
    };

/// Sanitary rows with a NULL cost contribute 0.0 — never coerced elsewhere,
/// mirroring D-11/`totalCost`'s null-propagation rule (Claude's Discretion
/// resolution in 07-CONTEXT.md).
double amountOf(ExpenseListItem item) => switch (item) {
      ManualExpenseItem(:final expense) => expense.amount,
      SanitaryExpenseItem(:final application) =>
        application.totalCost?.abs() ?? 0.0,
    };
```
Build the merged list as: fetch `expenses` for the paddock (excluding soft-deleted unless the
toggle is on), fetch `sanitary_applications` for the property and filter to
`app.paddockId == paddockId` client-side (no new repository method needed — `paddockId` is a
plain column on the existing model once D-30 lands), run `visibleApplications(rows,
showReversed: false)` (already exists, D-33) to drop reversed/reversal rows, wrap each side in its
`ExpenseListItem` variant, concatenate, sort by `dateOf` descending with a `createdAt` tiebreak
(mirrors `sortByAppliedAtDesc`).

### Pattern 5: Non-`_canEdit` role gate (D-23's genuine novelty)

**What:** Every existing gate in the codebase (`PiquetesScreen._canEdit`,
`PaddockDetailScreen._canEdit`, `SanitarioScreen._canEdit`, `AnimaisScreen`'s equivalent) is the
identical 10-line private method checking `role == 'veterinarian'`. `expenses` is the first
capability where **two** roles can write.
**Recommendation (Claude's Discretion — no existing precedent to copy verbatim):** extract a
public helper into `lib/core/auth/role_gates.dart`:
```dart
bool canManageExpenses(
  SelectedProperty? current,
  List<PropertyMembership>? members,
) {
  if (current == null || members == null) return false;
  final role = members
      .where((m) => m.property.id == current.id)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian' || role == 'owner';
}
```
Placed in `core/` (not feature-private) because **two** features consume it:
`PaddockDetailScreen`'s summary card visibility/tap-affordance and `/gastos/:paddockId`'s own FAB
— the same cross-feature reuse reason `is_member_of()`/`get_role()` live at the database level
rather than duplicated per-table. `PaddockDetailScreen` keeps its existing private `_canEdit`
(vet-only, gates "Novo lote") **unchanged** — the two gates coexist deliberately per D-23.

### Anti-Patterns to Avoid

- **Reusing `_canEdit` for expenses:** `_canEdit` is vet-only by construction in 4 existing
  screens. D-23 explicitly needs owner+veterinarian. Copy-pasting `_canEdit` and forgetting to add
  `'owner'` is the single most likely mistake in this phase — flag it in the plan checklist.
- **Live-joining `lots.paddock_id` for the sanitary cost total instead of the frozen column:**
  D-30 explicitly rejected this — it would retroactively change a past month's total when a lot
  is moved later, exactly the class of bug the whole Phase 6 snapshot model exists to prevent.
- **A server-side `UNION` query for the unified list:** unnecessary I/O coupling between two
  otherwise-independent tables; the merge is presentation logic (Pattern 4).
- **Restating the RLS `deleted_at IS NULL` predicate in the UPDATE policy's `USING`/`WITH CHECK`:**
  this is the exact G-06-2 regression (`20260812_06_fix_dose_update_policy.sql`) — a
  restore/edit-while-archived operation silently becomes a 0-row no-op. `expenses`' UPDATE policy
  must check only `is_member_of` + `get_role`, nothing about `deleted_at`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Currency parsing (comma decimal) | A custom currency `TextInputFormatter`/mask | `FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))` + manual `,`→`.` replace on submit | Exact idiom already in `dose_form_dialog.dart._parseDouble` — a live-mask package was explicitly recused in D-20 ("exigiria package novo") |
| Date-range picking | Custom calendar widget | `showDateRangePicker` (Material, SDK) | Zero dependency, already used in `sanitario_screen.dart._pickDateRange` |
| pt-BR pluralization ("1 lançamento" / "N lançamentos") | String interpolation with manual `if (n == 1)` | `Intl.plural(n, one: ..., other: ..., locale: 'pt_BR')` | Exact idiom in `_AplicacaoCard`'s animal-count string |
| Server aggregation for the total | A `SUM()` RPC/view | Client-side pure-function sum (Pattern 3) | Explicit documented ceiling (D-18) — only build the RPC once the list paginates |
| Category taxonomy | Admin CRUD screen for categories | `const List`/`Map` in `expense_constants.dart` | D-01 — deploy-time flexibility beats a whole cadastro screen for 8 rural categories |

**Key insight:** Every "don't hand-roll" instinct in this phase resolves to "there's already an
identical pattern three files away in `sanitario`" — the phase's actual technical risk is not
missing infrastructure, it is the trigger/backfill interaction in Common Pitfall #1 below.

## Runtime State Inventory

> Included because D-30/D-31 modify a table (`sanitary_applications`) that already holds live PROD
> data from Phase 6's own UAT run, requiring a backfill — not a pure greenfield addition.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **2 live rows in `sanitary_applications` on PROD project `wrdwzychjhlpwpivfhhq`** (created during Phase 6 UAT, per STATE.md §Blockers "PROD now holds 2 real UAT rows"). Both will get `paddock_id`/`paddock_name` = NULL immediately after `ALTER TABLE … ADD COLUMN`, before backfill runs. | **Data migration**, not just a code edit — a single `UPDATE … FROM lots JOIN paddocks` inside the same migration transaction (D-31), joined via `lots.paddock_id` *at migration time* (the only information available for pre-existing rows; documented in the migration header as approximate/non-frozen per D-31). |
| Live service config | None — no n8n/external dashboards/Datadog in this project's stack. | None. |
| OS-registered state | None — no Task Scheduler/pm2/launchd tasks reference this table or these column names. | None. |
| Secrets/env vars | None — no secret or env var references `paddock_id`/`paddock_name`/`expenses`. | None. |
| Build artifacts / installed packages | None new — no package installed, no build artifact carries a stale name. | None. |
| **Trigger-blocked write path (found beyond the standard 5 categories — see Common Pitfall #1)** | `trg_snapshot_immutable` (`BEFORE UPDATE OR DELETE ON sanitary_applications`, unconditional, from `20260508_02_property_paddock.sql:207-210`) will reject the D-31 backfill `UPDATE` as written. | The migration must wrap the backfill in `ALTER TABLE sanitary_applications DISABLE TRIGGER trg_snapshot_immutable;` → `UPDATE …` → `ALTER TABLE sanitary_applications ENABLE TRIGGER trg_snapshot_immutable;`, all inside the same transaction so no other session ever observes the trigger disabled. |

## Common Pitfalls

### Pitfall 1: The D-31 backfill will be rejected by `trg_snapshot_immutable` unless the trigger is disabled around it

**What goes wrong:** A plain `UPDATE sanitary_applications SET paddock_id = …, paddock_name = …
WHERE paddock_id IS NULL` raises `prevent_snapshot_mutation()`'s exception
(`'snapshot is immutable — sanitary_applications rows cannot be modified or deleted'`) and aborts
the whole migration transaction.
**Why it happens:** `prevent_snapshot_mutation()` fires on `BEFORE UPDATE OR DELETE` for **every**
row, unconditionally — it was written in Phase 2 specifically so no application code path can ever
mutate a frozen snapshot, and it has no carve-out for a schema-migration backfill because none was
anticipated at the time.
**How to avoid:**
```sql
ALTER TABLE sanitary_applications
  ADD COLUMN paddock_id   uuid REFERENCES paddocks(id),   -- nullable first
  ADD COLUMN paddock_name text;

ALTER TABLE sanitary_applications DISABLE TRIGGER trg_snapshot_immutable;

UPDATE sanitary_applications sa
   SET paddock_id   = l.paddock_id,
       paddock_name = p.name
  FROM lots l
  JOIN paddocks p ON p.id = l.paddock_id
 WHERE sa.lot_id = l.id AND sa.paddock_id IS NULL;

ALTER TABLE sanitary_applications ENABLE TRIGGER trg_snapshot_immutable;

ALTER TABLE sanitary_applications
  ALTER COLUMN paddock_id   SET NOT NULL,
  ALTER COLUMN paddock_name SET NOT NULL;
```
The disable/enable pair must sit inside the same migration transaction as the backfill `UPDATE` —
`apply_migration` (MCP) runs the whole file as one transaction, so no concurrent session can ever
observe the trigger disabled.
**Warning signs:** If the migration is written as a bare `UPDATE` and applied via MCP
`apply_migration`, it will fail immediately with the `prevent_snapshot_mutation()` error text —
easy to catch at apply time, but worth flagging in the plan so the task isn't authored, reviewed,
and only *then* discovered broken at Wave 3's `apply_migration` step.

### Pitfall 2: Copy-pasting `_canEdit` instead of using the new two-role gate

**What goes wrong:** `PaddockDetailScreen`'s existing `_canEdit` (line ~84) is vet-only. If a plan
task copies it for the "Gastos" summary card or the `/gastos/:paddockId` FAB without adding
`'owner'`, an owner (the person most likely to be logging their own farm's expenses, per D-23's own
rationale) is silently locked out of the feature the decision was made specifically to unlock for
them.
**Why it happens:** every other role gate in the codebase (4 of them) is vet-only; muscle memory
copies the wrong one.
**How to avoid:** use the shared `canManageExpenses()` helper (Pattern 5) everywhere expenses are
written; never a fresh copy of `_canEdit`.
**Warning signs:** a widget test logged in as `owner` cannot see the "Novo gasto" FAB or edit
controls — this must be one of the Wave 0 gate tests (D-36).

### Pitfall 3: RLS `USING`/`WITH CHECK` restating `deleted_at IS NULL` (G-06-2 regression class)

**What goes wrong:** An UPDATE policy that filters `USING (… AND deleted_at IS NULL)` evaluates
against the **pre-update** row. Restoring an archived expense (`deleted_at: null`) or editing an
archived one is evaluated against a row where `deleted_at IS NOT NULL`, the policy rejects it, zero
rows match, and PostgREST answers `2xx` anyway — a silent no-op indistinguishable from success in
the UI.
**Why it happens:** this is the exact bug fixed live in `20260812_06_fix_dose_update_policy.sql`
after it shipped once already in Phase 6 — a genuinely recurring temptation when writing an
"active-only" UPDATE policy.
**How to avoid:** the `expenses` UPDATE policy checks only `is_member_of(property_id) AND
get_role(property_id) IN ('owner', 'veterinarian')` — no `deleted_at` predicate anywhere in
`USING` or `WITH CHECK`. Combined with `.select().single()` client-side (Pattern 1), a genuine
0-row match (wrong id, wrong tenant) still throws instead of silently succeeding.
**Warning signs:** a pgTAP assertion restoring/editing a soft-deleted fixture row returns 0 rows
affected instead of 1 — include this exact case in `07_expenses_test.sql` (it is precisely what
`06_sanitary_test.sql`'s Group 12 assertions added after G-06-2, per STATE.md).

### Pitfall 4: Forgetting to extend `register_sanitary_application`'s lot lookup to also resolve the paddock

**What goes wrong:** The RPC's existing lookup is `SELECT property_id, name INTO v_property_id,
v_lot_name FROM lots WHERE id = p_lot_id`. If the paddock resolution isn't added to this same
query (or a sibling one), every **new** sanitary application registered after this migration ships
will insert `paddock_id`/`paddock_name` as `NULL` — violating the `NOT NULL` constraint added in
Pitfall 1's final step and hard-failing every future `register_sanitary_application` call.
**How to avoid:** extend the lookup:
```sql
SELECT l.property_id, l.name, p.id, p.name
  INTO v_property_id, v_lot_name, v_paddock_id, v_paddock_name
  FROM lots l JOIN paddocks p ON p.id = l.paddock_id
 WHERE l.id = p_lot_id AND l.deleted_at IS NULL;
```
and add `v_paddock_id, v_paddock_name` to both the `INSERT` column list and the `VALUES` tuple.
`reverse_sanitary_application` needs the parallel one-line addition — copying
`v_orig.paddock_id, v_orig.paddock_name` alongside its existing `v_orig.lot_id, v_orig.lot_name`
copy. Both functions are `CREATE OR REPLACE FUNCTION` with an unchanged signature — this is a
forward-only edit to an already-applied migration's *runtime object*, the same technique already
used four times in this project (`20260806_05`, `20260807_05`, `20260808_05`, `20260809_05`), never
an in-place edit of the original `.sql` file on disk.

### Pitfall 5: `expenses.amount` without a positivity check invites a silent-zero data entry

**What goes wrong:** Nothing in D-01..D-37 explicitly mandates `CHECK (amount > 0)` on
`expenses.amount` (D-20 only locks the `numeric(14,2)` type). Without it, a form bug or a raw
PATCH could write `amount = 0` or negative, which would then silently subtract from the piquete
total with no visible signal.
**How to avoid:** add `CHECK (amount > 0)` at the table level, mirroring `doses.dosage_per_kg > 0`
and `doses.cost_per_kg >= 0`'s existing precedent for numeric domain columns in this schema. This is
a research recommendation, not a CONTEXT.md lock — flagged in Assumptions Log A3 for explicit
confirmation.

## Code Examples

### `expenses` table + RLS + triggers (new migration, D-01..D-27)

```sql
-- Source: mirrors doses (20260810_06) for shape, trg_lots_paddock_same_property
-- (20260717_04) for the isolation trigger, veterinarian_can_update_active_dose fixed
-- form (20260812_06) for the UPDATE policy shape.

CREATE TABLE expenses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id   uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  paddock_id    uuid NOT NULL REFERENCES paddocks(id),
  category      text NOT NULL CHECK (length(trim(category)) > 0),
  amount        numeric(14,2) NOT NULL CHECK (amount > 0),
  expense_date  date NOT NULL,
  description   text,
  created_by    uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
  updated_by    uuid REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE INDEX expenses_property_idx ON expenses (property_id);
CREATE INDEX expenses_paddock_date_idx ON expenses (paddock_id, expense_date DESC);

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_expenses" ON expenses FOR SELECT TO authenticated
  USING (is_member_of(property_id));

CREATE POLICY "owner_vet_can_insert_expense" ON expenses FOR INSERT TO authenticated
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
  );

CREATE POLICY "owner_vet_can_update_expense" ON expenses FOR UPDATE TO authenticated
  USING (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
  )
  WITH CHECK (
    is_member_of(property_id)
    AND get_role(property_id) IN ('owner'::role_enum, 'veterinarian'::role_enum)
  );
-- Deliberately NO deleted_at predicate (Pitfall 3 / G-06-2). No DELETE policy —
-- archival is a deleted_at UPDATE only, same as doses/lots/paddocks/atf_batches.

CREATE OR REPLACE FUNCTION set_expenses_updated_by()
RETURNS trigger LANGUAGE plpgsql SET search_path = public
AS $$
BEGIN
  NEW.updated_by := auth.uid();
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_expenses_set_updated_by
  BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION set_expenses_updated_by();

-- Isolation trigger: see Pattern 2 above for the full function body
-- (enforce_expenses_paddock_same_property / trg_expenses_paddock_same_property).
```

### `ExpenseRepository` skeleton (mirrors `DoseRepository` 1:1)

```dart
// Source: lib/features/sanitario/data/dose_repository.dart, adapted
class ExpenseRepository {
  ExpenseRepository(this._service);
  final SupabaseService _service;

  Future<List<Expense>> fetchExpensesByPaddock(
    String paddockId, {
    bool includeArchived = false,
  }) async {
    var query = _service.client
        .from('expenses')
        .select()
        .eq('paddock_id', paddockId);
    if (!includeArchived) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query.order('expense_date', ascending: false)
        .order('created_at', ascending: false); // D-19 tie-break
    return (rows as List)
        .map((r) => Expense.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> archiveExpense(String id) async {
    await _service.client
        .from('expenses')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single(); // Pitfall 3 backstop
  }

  // createExpense / updateExpense / restoreExpense mirror dose_repository.dart exactly.
}
```

## State of the Art

No drift to document — this phase extends a stack that is 6 phases deep into internal consistency
(Riverpod 3.x, freezed 3.x, direct RLS CRUD vs. RPC decision tree already established). There is no
"old approach vs. current approach" axis internal to this project; the only external-facing
technique introduced (`DISABLE TRIGGER`/`ENABLE TRIGGER` around a backfill) is standard Postgres
DDL, not a stack version concern.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Category icon mapping (`Icons.grass` for Ração, `Icons.medical_services` for Sanidade, `Icons.engineering` for Mão de obra, `Icons.construction` for Manutenção, `Icons.eco` for Pastagem/Adubação, `Icons.local_gas_station` for Combustível, `Icons.description` for Arrendamento, `Icons.more_horiz` for Outros) | Code Examples / D-05 discretion | Cosmetic only — a UI reviewer can swap any icon with zero schema/logic impact |
| A2 | "Ano" preset (D-16) interpreted as **calendar year** (Jan 1 → today/Dec 31 of current year), not a rolling 12-month window | Architecture Patterns, D-16 discretion | If the user meant rolling 12 months, the displayed total for that preset differs — low risk (both are one `DateTimeRange` literal, a one-line change) but user-visible, worth confirming in discuss/plan review |
| A3 | `expenses.amount` should carry `CHECK (amount > 0)` at the table level | Common Pitfalls #5, Code Examples | Not locked by any D-01..D-37 decision. If a future correction workflow needs a negative/credit line item, a hard `> 0` check blocks it — cheap to relax later (single `ALTER TABLE … DROP CONSTRAINT`), asymmetric with the cost of NOT having it now (silent zero/negative entries) |
| A4 | Feature module lives at `lib/features/gastos/` (pt-BR, matches route naming) | Recommended Project Structure | D-08 locks the URL (`/gastos/:paddockId`) but not the Dart folder name — if the planner prefers `despesas` or `expenses` as the folder, it is a pure rename with no behavior change |
| A5 | `enforce_sanitary_application_same_property()` (Phase 6's existing trigger) is *not* extended to also validate the new `paddock_id`/`paddock_name` columns | Pitfall 4 discussion | Safe as-is: `sanitary_applications` has zero direct INSERT/UPDATE RLS policies (only the two RPCs can write), so there is no raw-PATCH attack surface for `paddock_id` the way there was for `lots.paddock_id`/`animals.lot_id`. Extending the trigger anyway is optional defense-in-depth, not a correctness requirement — low risk either way |

**If this table is empty:** N/A — see rows above; all are low-risk/cosmetic or easily reversible,
none block planning.

## Open Questions

1. **Should the `sanitary_applications` backfill (Pitfall 1) live in the same migration file as
   the `expenses` table creation, or as a separate file?**
   - What we know: Phase 6's own corrective migrations (`20260806_05` through `20260812_06`) are
     each a dedicated small file per fix, but those were *post-hoc* corrections to an
     already-applied migration. This backfill is *part of* the original Phase 7 rollout, not a
     correction discovered after the fact.
   - What's unclear: whether D-37's "W1(a) migration" plan task intends one file or two.
   - Recommendation: one file (`20260813_07_expenses_module.sql`) covering the new `expenses`
     table, the `sanitary_applications` `ALTER`+backfill+`NOT NULL`, and the RPC edits — all of it
     must land in the live database atomically anyway (a half-applied state where `expenses`
     exists but `sanitary_applications.paddock_id` doesn't would leave the unified list unable to
     render sanitary rows). Splitting the RPC edits into their own migration file is fine either
     way since `CREATE OR REPLACE FUNCTION` is independently idempotent.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI (linked) | Applying `supabase/migrations/*.sql` locally | ✗ (unlinked, no TTY for DB password — unchanged since Phase 3) | — | MCP `apply_migration` against live PROD project `wrdwzychjhlpwpivfhhq` (established path, Wave 3 of D-37) |
| Local Docker / `supabase test db` | Running `07_expenses_test.sql` via pgTAP locally | ✗ (Docker socket unreachable on this Windows host, unchanged since Phase 0) | — | MCP `execute_sql` replay of the suite inside `BEGIN … ROLLBACK` against live PROD (established path since Phase 4, used for `04_movements_test.sql`, `05_reproductive_test.sql`, `06_sanitary_test.sql`) |
| `flutter test` (unit/widget) | `expense_calculations_test.dart`, `expense_form_dialog_test.dart` | ✓ | matches project SDK constraint `>=3.24.0 <4.0.0` | — |

**Missing dependencies with no fallback:** none — every gap already has the established MCP-based
fallback this project has used successfully for 4 consecutive phases.

**Missing dependencies with fallback:** Supabase CLI linkage, local Docker (both covered above).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (unit + widget) `^` bundled with SDK; pgTAP `1.3.3` via `supabase test db` (local, unavailable) / MCP `execute_sql` replay (live, established fallback) |
| Config file | none dedicated — `dart_test.yaml` absent, tests run via `flutter test <path>` per-file, matching every prior phase |
| Quick run command | `flutter test test/features/gastos/expense_calculations_test.dart` |
| Full suite command | `flutter test` (Dart) + MCP-replayed `supabase/tests/07_expenses_test.sql` in a rolled-back transaction |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GAST-01 | Lançar gasto com categoria/valor/data/descrição, validação de campos obrigatórios | widget | `flutter test test/features/gastos/expense_form_dialog_test.dart` | ❌ Wave 0 |
| GAST-01 | RLS: `reader` não pode INSERT; `owner`/`veterinarian` podem | pgTAP | replayed `supabase/tests/07_expenses_test.sql` (MCP `execute_sql`) | ❌ Wave 0 |
| GAST-01 | Trigger: `paddock_id` de outra propriedade é rejeitado | pgTAP | same suite | ❌ Wave 0 |
| GAST-02 | Total agregado soma corretamente sobre lista mista (manual + sanitário), inclui linha sanitária com custo NULL como 0 e conta no N | unit | `flutter test test/features/gastos/expense_calculations_test.dart` | ❌ Wave 0 |
| GAST-02 | Filtro de período/categoria combináveis produzem o subconjunto correto | unit | same file | ❌ Wave 0 |
| GAST-02 | `SELECT` liberado a `reader` | pgTAP | same suite | ❌ Wave 0 |
| — (D-23, no REQ id but new pattern) | `canManageExpenses` gate: owner sim, veterinarian sim, reader não | widget | `flutter test test/features/gastos/role_gates_test.dart` (or embedded in `gastos_screen_test.dart`) | ❌ Wave 0 |
| — (D-31/D-30 backfill) | Backfilled PROD rows carry correct `paddock_id`/`paddock_name`; new registrations via RPC populate both NOT NULL | pgTAP + manual catalog read | same suite + `SELECT paddock_id, paddock_name FROM sanitary_applications` via MCP post-apply | ❌ Wave 0 (suite) / manual check at Wave 3 |

### Sampling Rate

- **Per task commit:** `flutter test test/features/gastos/` (quick, feature-scoped)
- **Per wave merge:** `flutter test` (full Dart suite) — mirrors every prior phase
- **Phase gate:** Full Dart suite green + `07_expenses_test.sql` replayed 0 failures before
  `/gsd-verify-work`, matching the D-37 W3 "plano bloqueante dedicado" pattern from Phases 4/5/6

### Wave 0 Gaps

- [ ] `supabase/tests/07_expenses_test.sql` — new suite, authored in Wave 0 against not-yet-applied
      schema (same deliberate red-state pattern as `06_sanitary_test.sql`, D-39/D-41 precedent)
- [ ] `test/features/gastos/` directory — does not exist yet, needs creation
- [ ] `test/features/gastos/expense_calculations_test.dart` — pure-function total/filter tests
- [ ] `test/features/gastos/expense_form_dialog_test.dart` — widget test, mirrors
      `dose_form_dialog_test.dart` if one exists (check `test/features/sanitario/` for the
      equivalent widget-test file before authoring from scratch)
- [ ] `lib/core/auth/role_gates.dart` + its test — first non-`_canEdit` gate in the project (D-23),
      no existing file to extend

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Unchanged — existing Supabase Auth session, no new auth surface this phase |
| V3 Session Management | no | Unchanged |
| V4 Access Control | yes | RLS policies: `is_member_of(property_id)` for SELECT; `is_member_of(property_id) AND get_role(property_id) IN ('owner','veterinarian')` for INSERT/UPDATE (D-23/D-24/D-25) |
| V5 Input Validation | yes | `CHECK` constraints (`amount > 0`, non-empty `category`), Dart `TextFormField` validators mirroring `DoseFormDialog`'s pattern |
| V6 Cryptography | no | No cryptographic operation introduced this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant IDOR via raw PostgREST `PATCH` bypassing intended isolation (`paddock_id` from a different `property_id` than the row's own) | Tampering / Elevation of Privilege | `BEFORE INSERT OR UPDATE` trigger re-checking `paddock_id ∈ property_id` — RLS `WITH CHECK` alone cannot see this pairing (D-26; this is the exact bug class that reopened twice in Phase 4, 04-06/04-07) |
| Role escalation via client-side-only gating | Tampering | RLS `get_role()` is the sole enforcement; `canManageExpenses()` in Dart only controls widget visibility, never trusted as a security boundary — established project principle |
| Silent no-op `UPDATE` masking a rejected write as success | Tampering (data integrity) / availability of correct state | `.select().single()` on every client-side UPDATE forces a thrown error on 0-row match; RLS UPDATE policy must never restate `deleted_at IS NULL` in `USING` (G-06-2 regression, Pitfall 3) |
| Financial total silently diverging from what's displayed | Repudiation-adjacent (auditability) | `created_by`/`updated_by` columns (D-27) record who wrote each row; the unified-list total is a pure, independently-testable function (D-18) rather than a value trusted from an untested code path |
| Immutable historical record accidentally mutated by a maintenance script | Tampering | `trg_snapshot_immutable` blocks all `UPDATE`/`DELETE` on `sanitary_applications` even from a migration — Pitfall 1's disable/enable pattern must be scoped as tightly as possible (single transaction, single backfill statement) to avoid normalizing "just disable the immutability trigger" as a casual maintenance habit |

## Sources

### Primary (HIGH confidence)
- `F:\_geral\Projetos\campo_gestor\lib\features\sanitario\data\dose_repository.dart` — direct-table CRUD shape
- `F:\_geral\Projetos\campo_gestor\lib\features\sanitario\data\sanitary_calculations.dart` — pure calculation module + `formatCurrencyBrl`
- `F:\_geral\Projetos\campo_gestor\lib\features\sanitario\data\sanitary_application_repository.dart` / `sanitary_application_model.dart` — unified-list source data shape, `visibleApplications`/`sortByAppliedAtDesc`
- `F:\_geral\Projetos\campo_gestor\lib\features\piquetes\presentation\paddock_detail_screen.dart` — `_canEdit`, card placement (D-09)
- `F:\_geral\Projetos\campo_gestor\lib\features\sanitario\presentation\sanitario_screen.dart` / `dose_form_dialog.dart` — filter row, empty states, currency input idiom
- `F:\_geral\Projetos\campo_gestor\supabase\migrations\20260810_06_sanitary_module.sql` — `doses` table shape, `sanitary_applications` ALTER pattern, isolation trigger
- `F:\_geral\Projetos\campo_gestor\supabase\migrations\20260811_06_sanitary_rpcs.sql` — `register_sanitary_application`/`reverse_sanitary_application` full bodies (Pitfall 4 basis)
- `F:\_geral\Projetos\campo_gestor\supabase\migrations\20260717_04_lot_paddock_property_trigger.sql` — isolation trigger literal template (Pattern 2)
- `F:\_geral\Projetos\campo_gestor\supabase\migrations\20260812_06_fix_dose_update_policy.sql` — G-06-2 regression, RLS UPDATE policy shape (Pitfall 3)
- `F:\_geral\Projetos\campo_gestor\supabase\migrations\20260508_02_property_paddock.sql` — `sanitary_applications` skeleton + `trg_snapshot_immutable` (Pitfall 1 basis)
- `F:\_geral\Projetos\campo_gestor\supabase\migrations\20260504_01_auth_multitenancy.sql` — `role_enum`, `is_member_of()`
- `F:\_geral\Projetos\campo_gestor\pubspec.yaml` — all package versions
- `F:\_geral\Projetos\campo_gestor\.planning\STATE.md` — Supabase CLI/Docker blockers, PROD row counts

### Secondary (MEDIUM confidence)
- None used — no external documentation lookup was needed; every claim above traces to a file read
  from this repository this session (see `[VERIFIED: pubspec.yaml]`/file-path citations throughout).

### Tertiary (LOW confidence)
- Category icon choices (A1), "Ano" preset interpretation (A2), `amount > 0` CHECK (A3), feature
  folder name (A4) — all flagged in Assumptions Log, all low-risk/reversible.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, every version read directly from `pubspec.yaml`
- Architecture: HIGH — every pattern has a literal file-and-line precedent already committed and
  UAT-verified in this exact repository
- Pitfalls: HIGH — Pitfall 1 (trigger-blocked backfill) and Pitfall 4 (RPC lookup extension) were
  derived by reading the actual `trg_snapshot_immutable` definition and the actual
  `register_sanitary_application` body, not inferred from CONTEXT.md's prose

**Research date:** 2026-08-11
**Valid until:** 2026-09-10 (30 days — stable internal stack, no external API surface introduced)
