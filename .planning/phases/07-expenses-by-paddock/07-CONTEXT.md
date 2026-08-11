# Phase 7: Expenses by Paddock - Context

**Gathered:** 2026-08-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Lançamento de gastos vinculados a piquete (GAST-01: categoria, valor, data, descrição) e consulta da lista do piquete filtrada por período com total agregado no topo (GAST-02).

Uma tabela nova (`expenses`), uma rota nova (`/gastos/:paddockId`), um dialog de formulário, um card de resumo no `PaddockDetailScreen`.

**Extensão consciente do escopo (decisão explícita do usuário, D-32):** o total do piquete também soma o custo das aplicações sanitárias daquele piquete. Isso obriga a fase a tocar o módulo sanitário da Phase 6 — acrescentando `paddock_id` + `paddock_name` congelados em `sanitary_applications` (item que a própria Phase 6 deixou no deferred citando esta fase) e fazendo backfill das linhas já existentes. É o único ponto em que esta fase modifica código de outra fase.

Fase independente das Phases 3–6 no papel (só depende de piquetes, Phase 2), mas D-32/D-33 criam uma dependência real do módulo sanitário. Nada aqui alimenta a Phase 8 (ficha consolidada do animal) — gasto é do piquete, não do animal.

</domain>

<decisions>
## Implementation Decisions

### Categorias de gasto

- **D-01:** Categorias são **constante no Dart**, não tabela. Um `expense_constants.dart` no padrão de `kBreeds` / `BaixaReason` (`animal_constants.dart`). Zero tela de cadastro, zero migration extra, dropdown direto. Custo aceito: mudar a lista exige deploy do Flutter — categoria de gasto rural muda pouco. Tabela cadastrável `expense_categories` (padrão `doses`) foi apresentada e recusada por quase dobrar o tamanho da fase; texto livre foi recusado por matar o breakdown por categoria do v2.
- **D-02:** Lista inicial de **8 categorias operacionais**: Ração/Suplementação, Sanidade/Medicamentos, Mão de obra, Manutenção (cerca/aguada/benfeitoria), Pastagem/Adubação, Combustível, Arrendamento, Outros. Cobre o gasto rural típico sem virar plano de contas.
- **D-03:** Coluna `category text NOT NULL` **sem CHECK constraint** — padrão de `animals.breed` com `kBreeds`, não de `animals.baixa_reason`. Adicionar ou renomear categoria é só deploy do Flutter, zero migration. Custo aceito e conhecido: um PATCH cru pode gravar categoria fora da lista (dado sujo, não brecha de segurança) e o breakdown por categoria (v2) tende a fazer a lista mexer.
- **D-04:** Obrigatórios: `paddock_id`, `category`, `amount`, `expense_date`. **`description text NULL`** — a categoria já diz o que é, e exigir texto trava o lançamento rápido em campo. Mesma lógica do custo opcional da dose (D-11 Phase 6).
- **D-05:** Cada categoria tem um **`IconData`** próprio (mapa constante ao lado de `kExpenseCategories`), exibido no card da lista. Sem cor por categoria — 8 cores que funcionem em light e dark seriam decisão de design que nenhuma outra tela do app tomou.
- **D-06:** Dropdown de categoria no formulário: **ordem fixa da constante** (operação → estrutura → "Outros" por último), **começa vazio**, valida como obrigatório. Mesmo comportamento do dropdown de categoria em `AnimalFormDialog`. "Última usada" foi recusada por exigir estado que nenhuma tela do app mantém.
- **D-07:** A lista tem **filtro por categoria além do filtro de período**, combináveis, no idioma de filtros de `/animais` (D-18 Phase 3) e `/sanitario` (D-26 Phase 6). O total do topo respeita os dois filtros.

### Navegação e telas

- **D-08:** Lista vive em **`/gastos/:paddockId` root-level**, fora do `AppShell` — quarto uso do padrão já estabelecido (`/lotes/:loteId` D-03 Phase 3, `/atf/:atfId` D-02 Phase 5, `/aplicacoes/:id` D-19 Phase 6). Constante em `AppRoutes` + helper `gastosPorPiquete(id)`. Seção dentro do `PaddockDetailScreen` foi recusada (filtro + total dentro de um `ListView` que já tem card e lotes fica apertado, e o FAB de lá já é "Novo lote"); 6ª branch no shell foi recusada (aperta a bottom bar no mobile, M3 recomenda 3–5, e mexeria em `AppShell._navItems` + `AppRoutes.all` + os testes que contam navegação).
- **D-09:** Entrada a partir do `PaddockDetailScreen` é um **card "Gastos" com o total do mês corrente**, abaixo do `_PaddockInfoCard`, tap abre a tela. Responde "quanto esse piquete custou" sem toque nenhum. Custo aceito: um `FutureProvider.family` a mais na tela de detalhe.
- **D-10:** Lançar gasto é **um FAB só, dentro de `/gastos/:paddockId`**. O piquete já vem resolvido pela rota — o campo "piquete" nem aparece no formulário. FAB duplo no `PaddockDetailScreen` foi recusado (o FAB de lá já é "Novo lote"; FAB expansível é padrão que o app não tem).
- **D-11:** Formulário de lançamento é **dialog** (`showDialog`), não tela cheia. Padrão unânime do app para formulário curto: `DoseFormDialog`, `LoteFormDialog`, `PaddockFormDialog`, `AnimalFormDialog`. Tela cheia foi usada só para seleção de 200 checkboxes (D-21 Phase 6).
- **D-12:** Tap num gasto da lista **abre o mesmo dialog em modo edição**. Sem rota de detalhe: o gasto tem 4 campos e o card já mostra todos. `/aplicacoes/:id` existe porque uma aplicação tem snapshot de 50 animais e é linkada de 3 origens — um gasto não justifica.
- **D-13:** **Empty state contextual**, distinguindo os dois casos: "Nenhum gasto lançado neste piquete" (nunca teve) vs "Nenhum gasto no período selecionado" com ação de limpar filtro (tem, mas o filtro escondeu). O total segue visível como R$ 0,00. Mesma classe do `_EmptyState` de `PiquetesScreen`.
- **D-14:** AppBar da tela mostra **"Gastos — {nome do piquete}"** com botão voltar explícito. Rota root-level acessada por deep-link não tem contexto sem isso, e o beco sem saída do botão voltar já foi achado 2x no UAT (F-04-05 Phase 4, G-05-1-nav Phase 5).

### Período, ordenação e totais

- **D-15:** Intervalo default ao abrir: **mês corrente** (dia 1 até hoje). Casa com o card de resumo do piquete (D-09) — o número que o usuário viu antes de tocar é o mesmo que aparece depois. Ciclo de custo rural é mensal.
- **D-16:** Troca de período por **chips de preset + intervalo custom**: "Mês atual / Mês passado / Últimos 3 meses / Ano / Personalizado", com o último abrindo `showDateRangePicker` (já vem no Material, zero dependência nova). Caso comum em 1 toque.
- **D-17:** Total no topo mostra **valor em R$ + contagem de lançamentos**, respeitando período e categoria filtrados. Escopo literal do GAST-02. Custo por hectare e breakdown por categoria foram apresentados e recusados por serem requisitos v2 explícitos do REQUIREMENTS.md.
- **D-18:** Total é **somado no cliente**, sobre a lista já carregada, em função pura testável (mesmo recorte de `sanitary_calculations.dart`, D-40 Phase 6). Total e lista não têm como divergir por construção. **Teto conhecido:** se a lista virar paginada, a soma passa a ser da página — aí vira RPC de agregação. Registrar como comentário no código.
- **D-19:** Lista ordenada por **data do gasto decrescente, sem agrupamento**, com desempate por `created_at`. Espelha o histórico sanitário (`applied_at` desc, D-25 Phase 6). O desempate é lição direta do G-05-4, onde dois registros na mesma data embaralhavam.
- **D-20:** Valor: entrada em `TextField` com `FilteringTextInputFormatter` aceitando vírgula decimal, exibição via `NumberFormat.currency(locale: 'pt_BR')` — exatamente o que `DoseFormDialog` já faz com custo por kg. Coluna **`numeric(14,2)`** no banco, nunca float. Máscara de moeda viva foi recusada (exigiria package novo).
- **D-21:** Filtro **não persiste** entre visitas — toda entrada abre no mês corrente sem categoria. Estado local da tela, igual aos filtros de `/animais` e `/sanitario` hoje. Filtro grudado invisível explicaria mal por que o total diverge do card do piquete.

### Correção, permissão e integridade

- **D-22:** Correção é **editar (UPDATE nos 4 campos) + soft delete (`deleted_at`)**, com toggle "Mostrar excluídos". Mesmo padrão de doses, lotes, animais e ATFs. Gasto **não** é histórico congelado — nada o lê como verdade imutável, ao contrário do snapshot sanitário. Linha de estorno imutável (padrão D-27 Phase 6) foi apresentada e recusada por dobrar a fase para corrigir erro de digitação.
- **D-23:** **Escrita liberada para `owner` E `veterinarian`.** Primeiro gate do projeto que não é `role == 'veterinarian'` puro — gasto é dado financeiro do dono da fazenda e ele precisa lançar o próprio gasto. Consequência: `_canEdit` **não** serve aqui; a fase precisa de um helper próprio (`_canManageExpenses` ou equivalente), e o `PaddockDetailScreen` passa a ter dois gates diferentes convivendo (FAB "Novo lote" = vet; card de gastos = vet + owner). Enum no banco é `role_enum ('owner','veterinarian','reader')`.
- **D-24:** **Leitura liberada a todo membro**, `reader` incluído: `SELECT` policy = `is_member_of(property_id)`, igual a todas as outras tabelas. Uma exceção de papel na fase, não duas. O leitor já vê rebanho e custo sanitário hoje.
- **D-25:** Escrita vai por **tabela direta + RLS policies**, não RPC. Precedente `DoseRepository`: escrita de linha única numa entidade só é totalmente coberta por policy; RPC SECURITY DEFINER é para escrita multi-linha ou cross-entity (D-21 Phase 5). Policies checam `is_member_of(property_id)` + `role IN ('owner','veterinarian')`. Usar **`.select().single()`** em todo UPDATE — PostgREST responde 2xx num UPDATE de 0 linhas, o silent no-op que virou G-06-2.
- **D-26:** **Trigger `BEFORE INSERT OR UPDATE` garantindo `expenses.paddock_id` ∈ `expenses.property_id`**, espelhando `trg_lots_paddock_same_property` (`20260717_04_lot_paddock_property_trigger.sql`). A RLS `WITH CHECK` olha `property_id` e não inspeciona `paddock_id`; um vet membro de 2 propriedades tem JWT válido para as duas e pode montar PATCH cru no PostgREST. Foi exatamente esse buraco que reabriu duas vezes na Phase 4 (04-06, 04-07). Não é opcional.
- **D-27:** Auditoria: **`created_by`** (`uuid NOT NULL DEFAULT auth.uid()`, FK para `auth.users`) **e `updated_by`** (via trigger `BEFORE UPDATE`). O cliente não envia nenhum dos dois. Com dois papéis podendo escrever (D-23), "quem lançou isso" importa de verdade. Sem UI nesta fase — as colunas nascem preenchidas.
- **D-28:** Excluir gasto pede **`AlertDialog` com valor e data** ("Excluir gasto de R$ 1.240,00 de 03/08?"). É soft delete recuperável, mas apagar lançamento financeiro por toque errado no celular é o que o dialog de resumo da Phase 6 (D-23) existe para evitar. Swipe-to-dismiss foi recusado (padrão inexistente no app, swipe acidental é comum em lista rolada).

### Cruzamento com o módulo sanitário

- **D-29:** **O total do piquete inclui o custo das aplicações sanitárias daquele piquete.** Decisão explícita do usuário, tomada com o custo apresentado (acoplamento entre módulos + migration em tabela de outra fase). Alternativa "só lançamento manual, com o vet lançando o sanitário na categoria Sanidade/Medicamentos" foi apresentada como recomendada e recusada.
- **D-30:** Atribuição por **congelamento**: a migration desta fase acrescenta **`paddock_id` + `paddock_name` a `sanitary_applications`**, preenchidos pelo RPC de registro no momento da gravação. É exatamente o item "congelar o piquete do lote na aplicação" que a Phase 6 deixou no `<deferred>` citando esta fase. Historicamente correto — lote movido depois não reescreve o passado. **Join por `lots.paddock_id` atual foi explicitamente recusado**: mover um lote mudaria retroativamente o custo de agosto em setembro, a classe de bug que o snapshot da Phase 6 inteira existe para evitar.
- **D-31:** As aplicações **já existentes em PROD** (2 linhas criadas no UAT da Phase 6) recebem **backfill** via `lots.paddock_id` atual. É a única informação disponível para elas; documentar no cabeçalho da migration que essas duas linhas têm atribuição aproximada, não congelada.
- **D-32:** A lista de gastos é **unificada**: aplicações sanitárias aparecem como linhas na mesma lista ordenada por data, com ícone de sanidade, valor e badge "Sanitário", **read-only** (sem editar, sem excluir; tap → `/aplicacoes/:id`). Isso preserva a propriedade do D-18 — o total volta a ser a soma do que está na tela. O filtro de categoria trata "Sanitário" como pseudo-categoria.
- **D-33:** **Aplicações estornadas ficam fora da lista e do total** — nem a original, nem a linha de estorno. Aplica o D-29 da Phase 6 ("Totais sempre excluem estornadas") a esta tela. A soma bateria zero de qualquer jeito; mostrar as duas linhas só confunde quem confere na mão.

### Escopo, testes e execução

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requisitos e escopo
- `.planning/REQUIREMENTS.md` §GAST-01, §GAST-02 — os 2 requisitos desta fase; §v2 Requirements lista "Breakdown de gastos por categoria no piquete" e "Indicadores consolidados: UA/ha por piquete, custo por animal" como v2 (ambos oferecidos e recusados, D-17)
- `.planning/ROADMAP.md` §Phase 7 — goal e success criteria SC-1…SC-4; §Parallelization Notes (a fase é independente das 3–6 no papel — D-29 quebra isso na prática)
- `.planning/PROJECT.md` — "Controlar gastos por piquete" em Active; "Relatórios e dashboards avançados — pós-MVP" em Out of Scope

### Schema existente a espelhar ou estender
- `supabase/migrations/20260504_01_auth_multitenancy.sql` — `role_enum ('owner','veterinarian','reader')`, `property_members`, `is_member_of()` SECURITY DEFINER; base das policies do D-23/D-24
- `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` — `trg_lots_paddock_same_property`, o trigger a espelhar literalmente no D-26
- `supabase/migrations/20260508_02_property_paddock.sql` — tabela `paddocks` (`area_ha`, `ua_capacity`), alvo da FK `expenses.paddock_id`
- `supabase/migrations/20260810_06_sanitary_module.sql` — `sanitary_applications`: colunas de cabeçalho, `total_cost`, `reverses_application_id`, `trg_snapshot_immutable`, `trg_sanitary_applications_same_property`. **Esta fase acrescenta `paddock_id` + `paddock_name` aqui (D-30)** — atenção ao trigger de imutabilidade, que barra UPDATE, ao planejar o backfill do D-31
- `supabase/migrations/20260811_06_sanitary_rpcs.sql` — RPC de registro de aplicação, que precisa passar a preencher `paddock_id`/`paddock_name` (D-30)
- `supabase/migrations/20260812_06_fix_dose_update_policy.sql` — lição G-06-2: policy de UPDATE com `deleted_at IS NULL` no `USING` faz restore virar no-op silencioso; evitar a mesma armadilha nas policies de `expenses`

### Padrões de código a replicar
- `lib/features/sanitario/data/dose_repository.dart` — precedente direto do D-25: CRUD de linha única via tabela direta, `.select().single()` para detectar no-op, soft delete + restore, `includeArchived` como um switch de filtro numa query só, providers resolvendo `currentPropertyProvider` internamente
- `lib/features/sanitario/presentation/dose_form_dialog.dart` — dialog de formulário com campo de valor pt-BR (D-11, D-20)
- `lib/features/piquetes/presentation/paddock_detail_screen.dart` — `_PaddockInfoCard` + `LotsSection` + FAB "Novo lote" + o helper `_canEdit` (linha ~84) que o D-23 **não** pode reusar; onde entra o card de gastos (D-09)
- `lib/features/piquetes/presentation/piquetes_screen.dart` — `_EmptyState` e `_PaddockCard`, forma a espelhar em D-13 e nos cards da lista
- `lib/features/animais/presentation/animais_screen.dart` — filtros combináveis + toggle "Mostrar arquivados", idioma a espelhar em D-07, D-16 e D-22
- `lib/features/sanitario/presentation/sanitario_screen.dart` — filtros de lote/dose/período e o toggle "Mostrar estornadas" (D-29 Phase 6), referência direta para D-33
- `lib/features/sanitario/data/sanitary_calculations.dart` — módulo de cálculo puro, forma a espelhar na soma do total (D-18)
- `lib/features/sanitario/data/sanitary_application_repository.dart` — providers e modelo da aplicação, fonte das linhas sanitárias da lista unificada (D-32)
- `lib/features/animais/data/animal_constants.dart` — `kBreeds` (constante sem CHECK no banco, precedente do D-03) e `BaixaReason` (enum com `dbValue`/`label`, forma alternativa); base do `expense_constants.dart`
- `lib/core/router/routes.dart` + `lib/core/router/router.dart` — onde registrar `/gastos/:paddockId` root-level e o helper (D-08); ver o bloco de comentário das rotas Phase 5/Phase 6

### Testes
- `supabase/tests/06_sanitary_test.sql` — modelo de suíte pgTAP mais recente (81 asserções), incluindo grupos de RLS e de policy por papel; base para `07_expenses_test.sql` (D-36)
- `supabase/tests/04_movements_test.sql` — asserções dos triggers `*_same_property`, o padrão exato a replicar para `expenses` (D-26)

### Contexto anterior
- `.planning/phases/06-sanitary-module-snapshot/06-CONTEXT.md` — D-11 (custo opcional na dose, origem do caso NULL em Claude's Discretion), D-23 (dialog de confirmação antes de gravação sensível), D-25/D-29 (ordenação por data e exclusão de estornadas), e o `<deferred>` "Congelar o piquete do lote na aplicação — útil para cruzar com gastos por piquete (Phase 7)" que o D-30 executa
- `.planning/phases/04-movements/04-CONTEXT.md` — padrão de dialog de ação, invalidação de providers, e a lição RPC + trigger que fundamenta o D-26
- `.planning/phases/03-lots-animals-operational-core/03-CONTEXT.md` — D-18 (filtros), D-21 (toggle arquivados), D-03 (rota root-level)
- `.planning/STATE.md` §Blockers — CLI Supabase desvinculada sem TTY (migrations vão via MCP `apply_migration`), Docker indisponível (pgTAP roda via MCP `execute_sql` em transação revertida), `anon` pode EXECUTE os SECURITY DEFINER

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DoseRepository` (Phase 6): o análogo mais próximo do repository desta fase — CRUD de entidade property-scoped por tabela direta, com soft delete, restore, `includeArchived` e providers sem parâmetro de propriedade. Copiar a forma, não reinventar.
- `trg_lots_paddock_same_property` (`20260717_04`): trigger de isolamento pronto, ~15 linhas, a espelhar em `expenses` (D-26).
- `is_member_of()` + `property_members.role`: base pronta das policies; a novidade é só o `role IN ('owner','veterinarian')` do D-23.
- `sanitary_calculations.dart`: precedente de módulo de cálculo puro isolado da UI, testável sem widget.
- `_EmptyState` de `PiquetesScreen` e os filtros de `AnimaisScreen`/`SanitarioScreen`: formas prontas para D-13, D-07 e D-16.
- `showDateRangePicker` do Material: cobre o intervalo custom do D-16 sem dependência nova.
- `NumberFormat.currency(locale: 'pt_BR')` + `FilteringTextInputFormatter`, já em uso no `DoseFormDialog`.

### Established Patterns
- Repository nunca importa o SDK do Supabase direto — sempre via `SupabaseService`
- Riverpod 3.x (não 2.x), `FutureProvider` / `FutureProvider.family`, `ref.invalidate` pós-sucesso
- Soft delete `deleted_at timestamptz` + `.isFilter('deleted_at', null)`; toggle "Mostrar arquivados/excluídos" como sibling provider
- Escrita de linha única em entidade só → tabela direta + RLS policies; multi-linha ou cross-entity → RPC SECURITY DEFINER + trigger de isolamento
- `.select().single()` em UPDATE para transformar no-op de 0 linhas em erro
- Role gate na UI = controle **ausente**, não desabilitado
- pt-BR: `intl` para datas e moeda
- Migrations aplicadas via MCP `apply_migration`; pgTAP via MCP `execute_sql` em `BEGIN … ROLLBACK`

### Integration Points
- `routes.dart` / `router.dart`: rota root-level `/gastos/:paddockId` + helper (D-08)
- `paddock_detail_screen.dart`: card de resumo com total do mês (D-09); atenção — o `_canEdit` local desta tela é vet-only e **não** serve ao gate do D-23
- `sanitary_applications` + RPC de registro (Phase 6): colunas `paddock_id`/`paddock_name` congeladas + backfill (D-30/D-31). **Único ponto em que esta fase modifica outra fase.**
- `sanitary_application_repository.dart`: fonte das linhas sanitárias da lista unificada (D-32), filtrando estornadas (D-33)
- Nova migration Phase 7: tabela `expenses`, policies de leitura/escrita, trigger de isolamento, trigger de `updated_by`, índices `(property_id)` e `(paddock_id, expense_date)`
- `supabase/tests/07_expenses_test.sql`: suíte nova (D-36)

</code_context>

<specifics>
## Specific Ideas

- O usuário puxou o cruzamento com o sanitário para dentro da fase sabendo o custo (acoplamento + migration em tabela de outra fase). O que motiva isso é a pergunta real de gestão: "quanto esse piquete me custou no mês" — e um custo de piquete que ignora o sanitário responde errado. A Phase 6 já tinha antecipado esse desejo ao deixar "congelar o piquete do lote na aplicação" no deferred citando explicitamente a Phase 7.
- Pelo mesmo motivo o join por `lots.paddock_id` atual foi recusado: a Phase 6 inteira existe em torno da ideia de que histórico não se reescreve. Somar custo sanitário via piquete *atual* do lote faria o total de agosto mudar quando alguém move um lote em setembro — seria trair a premissa do módulo que está sendo consumido.
- "Arrendamento" ficou na lista de 8 categorias mesmo com `paddock_id NOT NULL` (D-34): arrendamento de piquete específico existe e é lançável. O arrendamento da fazenda inteira é que foi para o deferred.
- O gate de dois papéis (D-23) é a primeira divergência real do `_canEdit` no projeto. Foi escolhido conscientemente contra a alternativa "uma regra só no app inteiro", com o argumento de que gasto é dado financeiro do dono. É também a razão do recorte de teste mais largo do D-36 e do `created_by`/`updated_by` do D-27.
- O usuário rejeitou puxar "custo por hectare" e "breakdown por categoria" para o total, ambos requisitos v2 — sinal de que o corte v1/v2 do REQUIREMENTS.md é para ser respeitado, mesmo quando o dado já está à mão (`paddock.area_ha` existe).

</specifics>

<deferred>
## Deferred Ideas

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

</deferred>

---

*Phase: 07-expenses-by-paddock*
*Context gathered: 2026-08-11*
