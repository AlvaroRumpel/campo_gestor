# Phase 6: Sanitary Module (Snapshot) - Context

**Gathered:** 2026-08-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Módulo sanitário completo: cadastro de doses com dosagem e custo (SANI-01), registro de aplicação sanitária em lote com snapshot congelado da composição (SANI-02), desmarcação individual antes de confirmar (SANI-03), histórico sanitário do lote (SANI-04) e histórico sanitário do animal via lookup no snapshot (SANI-05).

Uma tabela nova (`doses`) + ativação da tabela skeleton `sanitary_applications` criada na Phase 2 (hoje só `id + composition_snapshot jsonb + created_at`, com `trg_snapshot_immutable` já funcionando e RLS habilitada sem policies) + uma coluna nova em `properties` (`kg_per_ua`).

Phase 5 (reprodutivo) já está completa e esta fase não toca nada dela. Phase 8 consolida a ficha do animal cruzando reprodutivo + sanitário — esta fase entrega só o bloco sanitário da ficha, num formato que a Phase 8 reaproveita sem reescrever (D-30).

</domain>

<decisions>
## Implementation Decisions

### Forma do snapshot (SANI-02)

- **D-01:** Snapshot é **um array JSONB numa linha só**, mantendo o skeleton `sanitary_applications` + `trg_snapshot_immutable` da Phase 2. Não criar tabela filha. Motivo: a imutabilidade fica com **um mecanismo só** (tabela filha exigiria trigger próprio + `FORCE ROW LEVEL SECURITY`, duas superfícies para errar); o ativo já existe e já tem assertion em `02_property_paddock_test.sql`; e a escala (centenas de animais, dezenas de aplicações/ano) não justifica normalizar. Custo aceito: agregação futura precisa de `jsonb_to_recordset` — relatórios são pós-MVP.
- **D-02:** Cada objeto do array carrega o **mínimo do SC-3**: `{animal_id, number, category, ua}`. Número e categoria congelados porque o animal é editável; UA congelado porque `kUaWeights` pode mudar. Custo por animal é derivável (`ua × dosagem_por_ua` / `× custo_por_ua`) — não duplicar.
- **D-03:** Dose congelada no cabeçalho como **FK + valores copiados**: `dose_id` + `dose_name` + `dosagem_por_kg` + `dosagem_por_ua` + `custo_por_kg` + `custo_por_ua`. Reajuste de preço ou renomeação não reescreve histórico; a FK preserva "todas as aplicações desta dose".
- **D-04:** Lote congelado do mesmo jeito: `lot_id` (FK) + `lot_name`. A ficha do animal mostra o nome que o lote tinha na época — que é o que faz sentido para animal já movido.
- **D-05:** Animal desmarcado (SANI-03) **não entra no array**; o cabeçalho grava `skipped_count`. Sabe-se que N ficaram de fora sem que o lookup do SANI-05 precise filtrar `applied=true` em todo lugar (classe de bug evitada por construção).
- **D-06:** **`applied_at date NOT NULL`** próprio, default hoje, editável antes de confirmar. `created_at` fica só como auditoria. Ordenação de SANI-04 e SANI-05 usa `applied_at`. Mesma lição do D-11 da Phase 5 (o vet lança depois do manejo).
- **D-07:** **Uma dose por aplicação.** Três produtos no mesmo dia = três registros com a mesma data e a mesma composição. Cabeçalho simples, custo trivial, histórico do animal já lista produto por produto.
- **D-08:** Totais **congelados no cabeçalho**: `animal_count`, `total_ua`, `total_volume`, `total_cost`. A linha é imutável, então cabeçalho e array não têm como divergir depois de gravados; listagens leem colunas simples em vez de agregar JSONB por linha.
- **D-09:** Cabeçalho também grava `applied_by uuid` (preenchido pelo RPC via `auth.uid()`) e `notes text NULL`.
- **D-10:** `property_id` obrigatório na tabela, com RLS `ENABLE` + `FORCE ROW LEVEL SECURITY` e trigger de isolamento — padrão D-21 da Phase 5 sem economia.

### Dose (SANI-01)

- **D-11:** Dose guarda **dosagem e custo separados**: dosagem em mL/kg (**obrigatória** — sem ela não dá para aplicar) e custo em R$/kg (**opcional** — o vet nem sempre sabe o preço do produto do cliente). Custo nulo faz a aplicação exibir volume e **omitir** a linha de custo, nunca "R$ 0,00".
- **D-12:** O fator kg/UA mora em **`properties.kg_per_ua numeric NOT NULL DEFAULT 400`** — UA varia por fazenda/região (400, 450, 500), então não é constante. **Sem UI nesta fase**: a coluna nasce com default e ninguém edita; virar configuração depois é só uma tela, zero migração de dados. Coluna `GENERATED ALWAYS AS` foi explicitamente descartada — expressão de coluna gerada não pode ler outra tabela, e trocar o fator exigiria DROP/recreate com recálculo retroativo.
- **D-13:** A tabela `doses` guarda **só os `*_por_kg`**. Os valores por UA são **derivados**: view/query para a lista de doses (SC-1 "sistema calcula e exibe") e o RPC calcula na hora de congelar. Um único lugar com a fórmula.
- **D-14:** Cadastro tem **nome comercial + princípio ativo** (princípio ativo opcional). Permite agrupar produtos diferentes com o mesmo princípio.
- **D-15:** Dose é **property-scoped + RLS**, **editável** (nome e valores) e tem **soft delete `deleted_at`**. Dose arquivada some do seletor de aplicação mas continua legível no histórico, porque nome e valores foram congelados (D-03). Mesmo padrão de lotes, animais e ATFs.

### Navegação

- **D-16:** O branch `/sanitario` (hoje `Center(child: Text('Sanitário'))`) vira o **módulo inteiro em abas**: lista de aplicações da propriedade + cadastro de doses.
- **D-17:** "Registrar aplicação" parte **de dois lugares**: FAB em `/sanitario` (passo extra de escolher o lote) e botão no `LoteDetailScreen` com o lote pré-selecionado. Mesma tela nos dois casos — só muda se o lote já vem resolvido.
- **D-18:** Botão no lote segue o gate do "Mover para piquete" (D-06 Phase 4): `lot.deletedAt == null && activeAnimalCount > 0 && _canEdit`. Controle **ausente**, não desabilitado.
- **D-19:** Rota de detalhe **`/aplicacoes/:id` root-level**, mesmo padrão de `/lotes/:loteId` (D-03 Phase 3) e `/atf/:atfId` (D-02 Phase 5). Linkável das três listas, deep-link funcional, botão voltar resolvido (lição F-04-05 / G-05-1-nav). Constantes em `AppRoutes` + helper `aplicacaoDetail(id)`.
- **D-20:** Histórico sanitário do lote (SANI-04) é **seção abaixo da lista de animais** no `LoteDetailScreen` — mesma estrutura de seção que a ficha do animal já usa. Cada linha: data, dose, nº de animais, custo. Tap → `/aplicacoes/:id`.
- **D-21:** Seleção de animais (SANI-03) é **tela cheia** com checkboxes, contador vivo (`"47 de 50 selecionados · 42,5 UA"`) e botão confirmar fixo. Mesmo padrão do `AtfAnimalSelectionScreen` (Phase 5) — 200 checkboxes em dialog rola mal no celular, que é onde o vet usa.
- **D-22:** Só animais **ativos** (`deleted_at IS NULL`) aparecem na seleção; arquivados são invisíveis. Fecha por construção o buraco do G-05-2 (Phase 5). O RPC revalida no servidor — a UI não é o último guarda (D-09 Phase 5 / lição Phase 4).
- **D-23:** Antes do INSERT, **dialog de resumo** com dose, data, nº de animais, UA total e custo total, mais aviso de que o registro é permanente. A gravação é irreversível por design; um toque errado vira registro definitivo.
- **D-24:** Pós-confirmação: **volta pra origem + SnackBar** `"Aplicação registrada — N animais"` + invalidação dos providers de histórico. Mesmo padrão de todos os dialogs de ação desde a Phase 4.
- **D-25:** Histórico na ficha do animal (SANI-05) — a seção `_PlaceholderSection('Histórico Sanitário', 'Disponível na Fase 6')` da `AnimalDetailScreen` vira conteúdo real. Cada linha: **data + dose + lote da época** (nome congelado), ordenada por `applied_at` desc, tap → `/aplicacoes/:id`. Espelha o bloco reprodutivo (D-14 Phase 5).
- **D-26:** Lista global em `/sanitario` filtra por **lote + dose + período** — mesmo idioma dos filtros de `/animais` (D-18 Phase 3).

### Estorno (aplicação registrada errada)

- **D-27:** Correção é feita por **linha de estorno**, não por edição: nova linha em `sanitary_applications` com `reverses_application_id uuid NULL` apontando para a original. O trigger fica intacto e o SC-3 fica intacto — nem um `cancelled_at` cabe, já que `trg_snapshot_immutable` barra UPDATE **e** DELETE. É como contabilidade trata lançamento imutável.
- **D-28:** A linha de estorno **copia a composição original** no `composition_snapshot` (a coluna é `NOT NULL`) e grava **totais negativos** no cabeçalho. Cada linha fica auto-contida e o lookup do SANI-05 enxerga tanto a aplicação quanto o estorno dela; a soma dos totais bate em zero naturalmente.
- **D-29:** Estornadas ficam **ocultas por padrão** nas três listas, com toggle "Mostrar estornadas" que as exibe riscadas com badge — mesmo gesto do "Mostrar arquivados" (D-21 Phase 3) e "Mostrar encerrados" (D-03 Phase 5). **Totais (custo, volume, contagem) sempre excluem estornadas.**
- **D-30:** Estorno é **role-gated veterinário, sem janela de tempo, com motivo obrigatório** gravado no `notes` da linha de estorno. Erro pode aparecer meses depois; a ação já é auditável por `applied_by` + `created_at`. Estorno de estorno é bloqueado.
- **D-31:** Estorno único garantido no banco: `CREATE UNIQUE INDEX ON sanitary_applications (reverses_application_id) WHERE reverses_application_id IS NOT NULL` — mesma técnica já provada no `animal_atf_memberships_active_idx`. O RPC checa antes só para devolver erro legível em vez de 23505. Confiar só no RPC foi exatamente a aposta desfeita nos gap cycles 04-06 e 04-07.

### Concorrência no registro

- **D-32:** O RPC **revalida cada `animal_id` recebido e aborta a transação inteira** se algum não estiver mais ativo naquele lote (movido ou com baixa entre carregar a tela e confirmar). Erro legível: `"3 animais mudaram desde que a tela foi aberta — recarregue"`. Nada meio-gravado num registro que nunca mais muda. Mesma classe do TOCTOU que virou WR-01 na Phase 4.
- **D-33:** Ao receber essa recusa, a tela **recarrega preservando as desmarcações** que ainda fazem sentido — o vet não perde o trabalho de desmarcar 200 animais. Quem saiu some da lista; quem entrou aparece marcado (default é todos).
- **D-34:** Aplicação duplicada (mesma dose + lote + data) **não é bloqueada** — segunda dose de reforço e aplicação dividida em turnos são cenários legítimos. Em vez disso, o dialog de resumo **detecta aplicação idêntica recente e pede confirmação extra**. Duplo toque é resolvido no cliente (botão desabilitado durante o envio).

### Erros e mensagens

- **D-35:** Uma exception de fase — `SanitaryApplicationException` com **enum de motivo**, mapeado dos ERRCODEs que o RPC levanta (42501 papel sem permissão, 23505 estorno duplicado, código próprio para composição mudada). Uma classe no Dart, mensagem pt-BR escolhida pelo motivo. Nem mar de exceptions, nem "erro inesperado" genérico, nem texto de banco vazando pra tela (lição WR-01 Phase 5).
- **D-36:** O erro aparece **dentro do dialog de resumo**, com o botão reabilitado e a ação de recuperação ("Recarregar") ao lado da mensagem. SnackBar fica reservado pro sucesso.

### Contrato com a Phase 8

- **D-37:** Esta fase entrega **`sanitaryHistoryByAnimalProvider(animalId)`** (lista já ordenada por `applied_at` desc) **+ um widget de seção autônomo**. A Phase 8 recompõe a ficha consolidada reaproveitando os blocos reprodutivo e sanitário como estão, sem tocar em query nem reescrever apresentação. Custo zero agora — é exatamente o que o SANI-05 já precisa construir.
- **D-38:** A migration desta fase cria o **índice GIN** sobre `composition_snapshot` (`jsonb_path_ops`) e o SANI-05 usa containment (`composition_snapshot @> '[{"animal_id":"…"}]'`). É o que torna o lookup viável para o SC-1 da Phase 8 (ficha em <1s no 4G); medir de verdade só faz sentido com volume real. Nenhuma estratégia de paginação decidida agora.

### Testes

- **D-39:** `supabase/tests/06_sanitary_test.sql` (pgTAP) versionado no git como nas outras fases, executado via MCP `execute_sql` em transação revertida (`BEGIN … ROLLBACK`) enquanto não houver Docker — mesmo caminho já validado na Phase 5. Cobre o que só o banco garante: UPDATE e DELETE barrados na `sanitary_applications`, índice de estorno único, RLS de isolamento, RPC recusando papel errado.
- **D-40:** Testes Dart cobrem **só cálculo**: conversão kg→UA, totais de volume e custo, filtro de estornadas, ordenação por `applied_at`. Decisão explícita do usuário — foi apresentado que gate de papel e visibilidade de arquivado foram justamente o que vazou pro UAT na Phase 5 (G-05-2/G-05-3), e ainda assim o recorte escolhido foi o menor.
- **D-41:** Push da migration + execução do pgTAP + checkpoint de UAT humano ficam num **plano bloqueante dedicado numa wave própria**, como o 05-10 fez na Phase 5. Deixa explícito que a fase não fecha sem o banco real batendo, em vez de o push virar tarefa 3 de um plano que "passou" (foi assim que ficou BLOCKED nas Phases 4 e 5).
- **D-42:** O mesmo plano bloqueante roda também o **`supabase/tests/04_movements_test.sql`**, nunca executado desde a Phase 4. A conexão MCP já vai estar aberta; se falhar, revela defeito real de migration.

### Claude's Discretion

- Nomes exatos de tabelas e colunas (`doses`, `dosagem_por_kg`, `custo_por_kg`, `total_volume` são sugestões).
- Estrutura interna do array JSONB (chaves em inglês vs português; se `ua` é `numeric` ou string).
- Se os valores por UA da lista de doses vêm de view SQL, de coluna calculada na query, ou do Dart lendo `properties.kg_per_ua`.
- Layout interno da tela de detalhe da aplicação (`data_table_2` vs ListView para a composição).
- Forma exata da detecção de "aplicação idêntica recente" (D-34) — janela de tempo e onde a query roda.
- Se o estorno é um RPC próprio ou um parâmetro do RPC de registro.
- Mecânica do toggle "Mostrar estornadas" nas três listas (estado local vs provider compartilhado).
- Estratégia de paginação/virtualização na tela de seleção e nas listas para propriedades grandes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements e escopo
- `.planning/REQUIREMENTS.md` §SANI-01…SANI-05 — 5 requisitos desta fase; business rules "Snapshot sanitário imutável após INSERT — sem UPDATE, sem DELETE via RLS", "dose.valor_por_ua = valor_por_kg × 400 (calculado, não editável)" (o × 400 agora vive em `properties.kg_per_ua`, D-12) e a tabela de UA por categoria
- `.planning/ROADMAP.md` §Phase 6 — goal e success criteria SC-1…SC-5
- `.planning/PROJECT.md` — "Snapshot congelado na aplicação sanitária" em Key Decisions; "Controle de estoque de medicamentos — apenas custo/aplicação" em Out of Scope; categorias e pesos UA
- `.planning/research/SUMMARY.md` — decisão aberta #4 (default da aplicação sanitária), já resolvida pelo SC-2 e reafirmada em D-05/D-21

### Schema existente
- `supabase/migrations/20260508_02_property_paddock.sql` §9 (linhas ~189-214) — skeleton `sanitary_applications` (`id`, `composition_snapshot jsonb NOT NULL`, `created_at`), função `prevent_snapshot_mutation()` e trigger `trg_snapshot_immutable` (BEFORE UPDATE OR DELETE), RLS habilitada **sem policies** ("Phase 6 owns this table"). Esta fase adiciona colunas de cabeçalho, `property_id`, policies de leitura e RPCs de escrita.
- `supabase/migrations/20260508_02_property_paddock.sql` §8 — `animal_atf_memberships_active_idx`, o partial unique index a espelhar em D-31
- `supabase/migrations/20260514_03_lots_animals.sql` — padrão de RPC SECURITY DEFINER com `is_member_of()` + `get_role()`, `RAISE EXCEPTION` com ERRCODE 42501; policies de `animals`/`lots`
- `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` — `trg_animals_lot_same_property`, o trigger de isolamento a espelhar (D-10)
- `supabase/migrations/20260805_05_atf_rpcs.sql` — RPCs SECURITY DEFINER da Phase 5, incluindo escrita multi-linha atômica; referência direta para o RPC de registro de aplicação
- `supabase/migrations/20260809_05_fix_register_baixa_null_guards.sql` — lição de guarda de NULL em parâmetro de RPC (`NOT IN` sobre NULL é NULL, não TRUE)

### Padrões de código a replicar
- `lib/features/reproducao/data/atf_repository.dart` — repository mais recente, com RPC, exceptions e providers no padrão atual
- `lib/features/reproducao/presentation/atf_animal_selection_screen.dart` — tela cheia de seleção de animais com contador, análogo direto do D-21
- `lib/features/lotes/data/lote_repository.dart` — `createLotWithAnimals` (RPC com params dict, criação pai+filhos atômica)
- `lib/features/lotes/presentation/lote_detail_screen.dart` — header card + lista de animais; onde entra a seção de histórico sanitário (D-20) e o botão de registrar (D-17/D-18)
- `lib/features/animais/presentation/animal_detail_screen.dart` — `_PlaceholderSection('Histórico Sanitário')` (linha ~106) a substituir por D-25; `_ReproductiveHistorySection` como modelo de forma para D-37; padrão `_canEdit`
- `lib/features/animais/presentation/animais_screen.dart` — filtros e toggle "Mostrar arquivados" a espelhar em D-26 e D-29
- `lib/features/sanitario/presentation/sanitario_screen.dart` — placeholder a substituir pelas abas (D-16)
- `lib/features/animais/data/animal_constants.dart` — `kUaWeights` (pesos UA por categoria) usado no cálculo congelado
- `lib/core/router/routes.dart` + `lib/core/router/router.dart` — onde registrar `/aplicacoes/:id` root-level (D-19)

### Testes
- `supabase/tests/02_property_paddock_test.sql` — assertions já existentes da imutabilidade do snapshot; estender, não refazer
- `supabase/tests/05_reproductive_test.sql` — modelo de suíte pgTAP da fase anterior (371 linhas, rodada via MCP)
- `supabase/tests/04_movements_test.sql` — suíte nunca executada, a ser rodada junto no plano bloqueante (D-42)

### Contexto anterior
- `.planning/phases/05-reproductive-module-loteatf/05-CONTEXT.md` — D-21 (padrão completo de isolamento multi-tenant), D-02 (rota root-level), D-14 (bloco de histórico na ficha), D-19 (efeito colateral da baixa)
- `.planning/phases/04-movements/04-CONTEXT.md` — padrão de dialog de ação, invalidação de providers, lição RPC + trigger no `<deferred>`
- `.planning/phases/03-lots-animals-operational-core/03-CONTEXT.md` — D-18 (filtros de /animais), D-21 (toggle arquivados), D-22 (ficha do animal e seções placeholder)
- `.planning/STATE.md` §Blockers — CLI Supabase desvinculada sem TTY (migrations vão via MCP `apply_migration`), Docker indisponível, `04_movements_test.sql` pendente

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `sanitary_applications` + `prevent_snapshot_mutation()` + `trg_snapshot_immutable` já existem e já foram validados na Phase 2 — **estender, não recriar**. Só faltam as colunas de cabeçalho, `property_id`, policies de leitura e RPCs.
- `animal_atf_memberships_active_idx`: técnica de partial unique index a espelhar no índice de estorno único (D-31).
- `AtfAnimalSelectionScreen` (Phase 5): tela cheia de seleção com contador — análogo direto da tela de seleção de animais para aplicação.
- Filtros e toggle "Mostrar arquivados" de `AnimaisScreen`: mesmo padrão para os filtros da lista global e o toggle "Mostrar estornadas".
- `_ReproductiveHistorySection` da `AnimalDetailScreen`: forma a espelhar no bloco sanitário, para que a Phase 8 receba dois blocos simétricos.
- `_canEdit` / role gate veterinário: mesmo guard para registrar aplicação, cadastrar dose e estornar.
- `kUaWeights` (`animal_constants.dart`): pesos UA por categoria usados no cálculo congelado.

### Established Patterns
- Repository nunca importa o SDK do Supabase direto — sempre via `SupabaseService`
- Riverpod 3.x (não 2.x — nota da Phase 0), `FutureProvider` / `FutureProvider.family`, `ref.invalidate` pós-sucesso
- Soft delete `deleted_at timestamptz` + `.isFilter('deleted_at', null)`
- Escrita multi-linha ou cross-entity → RPC SECURITY DEFINER + trigger de isolamento; **zero write policies** na tabela (D-21 Phase 5)
- Role gate na UI = controle **ausente**, não desabilitado
- pt-BR: `intl` para datas e moeda, `FilteringTextInputFormatter` para decimais
- Migrations aplicadas via MCP `apply_migration` (CLI desvinculada sem TTY); pgTAP rodado via MCP `execute_sql` em transação revertida

### Integration Points
- `sanitario_screen.dart`: substituir o placeholder pelas abas aplicações + doses (D-16)
- `router.dart` / `routes.dart`: nova rota root-level `/aplicacoes/:id` + helper `aplicacaoDetail(id)` (D-19)
- `lote_detail_screen.dart`: seção de histórico sanitário abaixo da lista de animais (D-20) + botão "Registrar aplicação" com gate (D-17/D-18)
- `animal_detail_screen.dart`: `_PlaceholderSection('Histórico Sanitário')` deixa de ser placeholder (D-25)
- `properties`: coluna nova `kg_per_ua` com default 400, sem UI (D-12)
- Nova migration Phase 6: tabela `doses`, extensão de `sanitary_applications`, índice GIN, índice de estorno único, policies de leitura, trigger de isolamento e RPCs de registro/estorno

</code_context>

<specifics>
## Specific Ideas

- UA não é constante universal — na zootecnia brasileira 1 UA = 450 kg é a convenção mais difundida, mas 400 e 500 aparecem conforme região e consultoria. Foi o próprio usuário quem levantou isso, e é a razão de `kg_per_ua` virar coluna de propriedade em vez de constante (D-12). O REQUIREMENTS.md registra 400 como regra de negócio; com a coluna configurável isso deixa de estar travado em schema.
- Dose fixa por animal (vacina de aftosa, brucelose, clostridiose) é a aplicação mais frequente numa fazenda e **não** cabe em mL/kg. Foi apresentado explicitamente e o usuário escolheu manter o escopo literal do SANI-01 — dosagem só por kg nesta fase. Está no `<deferred>`.
- O snapshot existe justamente para que "o que este animal recebeu" continue verdadeiro depois que ele mudar de lote, mudar de categoria, ou receber baixa. Por isso nome do lote e nome da dose são congelados (D-03/D-04) — mostrar o nome atual reescreveria o passado.
- A tabela `sanitary_applications` foi criada na Phase 2 como retirada de risco do snapshot JSONB, e `02_property_paddock_test.sql` já prova que UPDATE e DELETE são recusados. Não refazer esse teste — estender.
- Estorno por linha nova em vez de flag é como contabilidade trata lançamento imutável há séculos: não se apaga, se lança o contrário.

</specifics>

<deferred>
## Deferred Ideas

- **Dose fixa por animal** (mL por cabeça, não por kg) para vacinas — apresentada e recusada nesta fase por estar fora do texto do SANI-01. Implementação seria `dosing_mode ('per_kg' | 'per_animal')` + branch no cálculo do RPC. Reavaliar quando o módulo estiver rodando.
- **Tela de configuração de `kg_per_ua`** — a coluna nasce nesta fase com default 400, mas editá-la é capacidade de configuração de propriedade (PROP-01, Phase 2). Vira tela de settings quando fizer sentido.
- **UI "repetir esta aplicação com outra dose"** reaproveitando a seleção de animais recém-feita — oferecida e não escolhida; hoje o vet repete o fluxo por produto.
- **Congelar o piquete do lote na aplicação** — útil para cruzar com gastos por piquete (Phase 7), mas nenhum REQ desta fase pede.
- **Agregações e relatórios sanitários** (consumo por dose, custo por categoria, por safra) — exigiriam `jsonb_to_recordset`; relatórios e dashboards estão em Out of Scope no PROJECT.md, pós-MVP.
- **Ficha consolidada do animal** cruzando reprodutivo + sanitário num único view — **Phase 8** (ANIM-03). Esta fase entrega o bloco sanitário já no formato que ela consome (D-37).
- **Paginação/virtualização** da tela de seleção e das listas para propriedades muito grandes — decidir com dados reais.
- **Controle de estoque de medicamentos** — Out of Scope no PROJECT.md; esta fase registra custo e volume por aplicação, não saldo.

</deferred>

---

*Phase: 06-sanitary-module-snapshot*
*Context gathered: 2026-08-06*
