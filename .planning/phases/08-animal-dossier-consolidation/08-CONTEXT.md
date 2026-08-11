# Phase 8: Animal Dossier Consolidation - Context

**Gathered:** 2026-08-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Ficha consolidada do animal (ANIM-03): uma tela que cruza dados do animal + lote atual + piquete atual + histórico reprodutivo completo + histórico sanitário completo, usável pelo veterinário no celular em campo.

**Achado que define a fase:** a ficha **já existe quase inteira**. `lib/features/animais/presentation/animal_detail_screen.dart` já tem `AnimalInfoCard` (dados + lote atual + piquete atual, ambos tappable), `_ReproductiveHistorySection` (REPR-05, Phase 5) e `AnimalSanitaryHistorySection` (SANI-05, D-37 Phase 6). O SC-3 (ordenação desc nos dois blocos) já está cumprido.

Esta fase **fecha as lacunas dos success criteria**, não constrói do zero:

| SC | Lacuna real |
|---|---|
| SC-1 (<1s no 4G) | 5 requests, com waterfall lote → piquete |
| SC-2 (todos ATFs **com DGs**) | cada ATF mostra só o **último** DG (`lastDgResult`/`lastDgDate`) |
| SC-3 (ordem desc) | ✅ já cumprido nos dois blocos |
| SC-4 (baixa proeminente) | chip pequeno na última linha do card de dados |
| SC-5 (mobile 360px) | `_KvRow` com label fixo de 120px, nunca verificado em 360 |

**Fase 100% Flutter — nenhuma migration, nenhum objeto de banco novo.** É a primeira fase do projeto sem SQL. Nenhuma tabela, RPC, policy ou trigger é criado ou alterado.

</domain>

<decisions>
## Implementation Decisions

### Consulta e performance (SC-1)

- **D-01:** **Matar só o waterfall, mantendo os providers separados.** O piquete passa a vir embutido na query do lote (embed PostgREST) em vez de ser um segundo request disparado depois que `loteByIdProvider` resolve. 5 requests viram 4, todos em paralelo. O contrato D-37 da Phase 6 fica intacto: `AnimalSanitaryHistorySection` e o bloco reprodutivo continuam autônomos, cada um com seu provider, sem receber dado de fora. **RPC consolidada foi apresentada e recusada** — traria migration nova, quebraria o D-37 e duplicaria lógica que já existe em três repositories. Precedente pronto: `fetchAnimalsByProperty` já faz `lots!inner(name, paddock_id, paddocks!inner(id, name))`.
- **D-02:** **Render progressivo** (comportamento de hoje, agora explícito): o card do animal aparece assim que `animalByIdProvider` resolve; cada bloco de histórico mostra seu próprio spinner e preenche quando chega. É o que faz a ficha "abrir rápido" mesmo com o sanitário lento. Tela de loading única foi recusada por amarrar o tempo da ficha ao bloco mais lento. Skeleton foi recusado por ser padrão novo — nenhuma tela do app usa.
- **D-03:** **Sem cache — auto-dispose do Riverpod 3.x mantido.** Reabrir uma ficha refaz as queries. Ficha desatualizada em campo é pior que ficha lenta; `keepAlive` foi apresentado e recusado.
- **D-04:** **Retry por bloco.** Cada seção que falha mostra a mensagem + ação de recarregar **só aquele provider**. Hoje os textos de erro são mortos (`'Erro ao carregar histórico sanitário.'`) e a única saída é o vet descobrir sozinho que precisa sair e voltar. Mesma lição do D-36 da Phase 6 (recuperação ao lado da mensagem). Isso é ortogonal à retry policy app-wide do G-06-9 — aquela cobre falha transitória, esta cobre falha que persistiu.
- **D-05:** **Sem pull-to-refresh.** `RefreshIndicator` seria o primeiro do app; auto-dispose (D-03) já entrega dado fresco ao reabrir.
- **D-06:** **Truncamento assimétrico mantido:** sanitário corta em 10 + "Ver todas" (D-37 Phase 6), reprodutivo mostra tudo. Justificativa real: uma vaca entra em poucos ATFs na vida e recebe dezenas de aplicações. Cortar os dois exigiria destino para o "Ver todos" do reprodutivo — `/reproducao` não tem filtro por animal hoje.
- **D-07:** **SC-1 vira evidência via UAT humano com throttle 4G** no DevTools ("Fast 4G"), abrindo a ficha por busca de número e cronometrando. Mesmo caminho da SC-1 da Phase 0 (verificada manualmente no browser). Teste automatizado de tempo foi recusado porque `integration_test` não roda em web neste projeto (nota da Phase 0) — mediria em `-d windows` contra rede real, número que não representa 4G.

### Histórico reprodutivo (SC-2)

- **D-08:** **Todos os DGs, em linha expansível.** A linha do ATF continua como está (resumo do último DG); tocar na seta expande e lista **todos** os DGs daquele animal naquele ATF. Cumpre o SC-2 literal ("todos LoteATFs (com DGs)") sem poluir o caso comum, que é 1 DG por ATF.
- **D-09:** Cada linha de ATF passa a mostrar também **touro do ATF** e **data de implantação** (hoje só "insem. DD/MM"); cada DG expandido mostra **data + resultado + observação do DG**. O rótulo legível do touro já foi resolvido na Phase 5 (WR-01 / plano 05-13) — reusar, não reimplementar.
- **D-10:** **DGs vêm na mesma query.** `fetchReproductiveHistory` passa a embutir os `dg_records` do animal em cada ATF. O bloco continua sendo 1 request e a expansão é instantânea; o payload cresce pouco porque são os DGs de **um animal**, não do lote. Provider family por ATF disparado no toque foi apresentado e recusado (spinner dentro da expansão + mais um provider para invalidar e testar).
- **D-11:** **O bloco reprodutivo é extraído para `lib/features/reproducao/presentation/`**, público, espelhando `AnimalSanitaryHistorySection` (D-37 Phase 6). Hoje é `_ReproductiveHistorySection`, privado dentro de `animal_detail_screen.dart`. Depois disso a ficha vira composição de dois blocos simétricos, cada um pertencendo ao seu módulo, e o bloco reprodutivo fica testável isolado.

### Baixa (SC-4)

- **D-12:** **Banner no topo da ficha**, acima do card, em `errorContainer` com ícone: primeira coisa que o vet vê. Padrão que o app já tem no banner de ATF encerrado (Phase 5). Card inteiro em cor de erro foi recusado (prejudica a leitura dos dados que o vet foi consultar); badge na AppBar foi recusado (em 360px o título já trunca).
- **D-13:** O banner traz **motivo + data + observação da baixa**. O CR-01 da Phase 5 fez o `register_baixa` **anexar** a observação da baixa ao `observation` do animal — mostrar as três coisas juntas responde "o que houve com esse animal" sem caçar em outra linha.
- **D-14:** **Mesmo visual para os três motivos**, mudando só o texto (Vendido / Morto / Descartado). Ícone por motivo foi recusado: escolher 3 ícones é decisão de design que nenhuma outra tela do app tomou.
- **D-15:** **A linha "Status" sai do card.** Com o banner, o status de baixa passa a viver num lugar só — nada de mesma informação em duas formas na mesma tela, ainda mais numa tela que precisa caber em 360px.
- **D-16:** **Nada muda nos históricos para animal com baixa.** Reprodutivo e sanitário continuam completos e navegáveis — é justamente o histórico do animal vendido que precisa continuar consultável. As ações de escrita já somem hoje para arquivado; manter.
- **D-17:** **A busca por número encontra animal com baixa, sempre.** `/animais` carrega todos e filtra arquivados **em memória** pelo toggle "Mostrar arquivados" (`fetchAnimalsByProperty(..., includeArchived: true)` no provider). Buscar `#127` de um animal vendido tem que abrir a ficha mesmo com o toggle desligado — é exatamente o caso em que o vet quer o histórico. A busca por número exato passa por cima do toggle.

### Layout e organização (SC-5)

- **D-18:** **Ordem mantida: card → reprodutivo → sanitário.** O reprodutivo é o histórico curto (poucos ATFs por vida), então o vet vê o bloco inteiro sem rolar; o sanitário, que é longo, fica por último. Ordem por recência foi recusada — a ficha mudaria de forma entre um animal e outro e quebraria a memória muscular do vet.
- **D-19:** **Blocos sempre abertos, nunca colapsáveis.** O dossiê existe para mostrar tudo de uma vez; esconder atrás de um toque desfaz o propósito da fase e contradiz o texto do SC-2. O corte de 10 no sanitário (D-06) já dá teto ao scroll.
- **D-20:** **Bloco vazio aparece com mensagem** ("Nenhum ATF registrado para este animal.") — comportamento de hoje. A ausência é informação: prova que a ficha consultou e não há nada, em vez de deixar dúvida se carregou.
- **D-21:** **`_KvRow` empilha abaixo de ~400px de largura.** `LayoutBuilder`: acima do limiar, label à esquerda (120px) e valor à direita, como hoje; abaixo, label pequeno em cima e valor embaixo ocupando a largura toda. Nomes longos de lote e piquete param de ser espremidos em 200px. "Só reduzir o label" e "não mexer, só testar" foram recusados — "cabe sem estourar" não é o que o SC-5 pede.
- **D-22:** **Os blocos de histórico continuam read-only para todo papel** — mantém o D-13 da Phase 5. Nenhuma ação de registrar DG ou aplicação sanitária a partir da ficha. Atalhos de navegação para esses fluxos também foram recusados: os dois fluxos são **de lote**, então o vet cairia numa tela de 50 animais vindo da ficha de um. As ações do card (editar, dar baixa, mover) ficam como estão, com o gate vet-only existente.

### Testes e execução

- **D-23:** **Widget tests dos blocos + teste de largura 360px.** Cobre: banner de baixa aparecendo/sumindo com motivo e data corretos (SC-4), expansão dos DGs listando todos (SC-2), retry por bloco invalidando só o provider certo (D-04), e renderização sem overflow em 360px (SC-5). **Sem pgTAP** — nenhuma linha de SQL muda nesta fase. Recorte deliberadamente mais largo que o D-40 da Phase 6, no espírito do D-36 da Phase 7 (testar a regra nova, não só cálculo).
- **D-24:** **3 planos em 2 waves.** W1 (paralelo, sem sobreposição de arquivo): (a) camada de dados — embed do piquete na query do lote (D-01) + DGs completos em `fetchReproductiveHistory` (D-10) + campos novos no `ReproductiveHistoryEntry` (D-09); (b) extração do bloco reprodutivo para `reproducao/presentation/` (D-11). W2: ficha — banner de baixa (D-12..D-15), expansão de DGs (D-08), retry por bloco (D-04), `_KvRow` adaptativo (D-21) + os widget tests (D-23). **Não há plano bloqueante de migration** — pela primeira vez no projeto, a fase não depende de `apply_migration` via MCP.

### Claude's Discretion

- Forma exata do banner de baixa (widget próprio vs `MaterialBanner` vs `Container` estilizado) e sua posição precisa em relação ao card.
- Mecânica da expansão dos DGs (`ExpansionTile` vs estado local com `AnimatedSize`) e o formato exato da sub-linha de DG.
- Limiar exato do `_KvRow` adaptativo (~400px é referência, não contrato) e se o breakpoint é lido de `LayoutBuilder` ou `MediaQuery`.
- Forma do embed do piquete no lote (novo método no `LoteRepository` vs estender `loteByIdProvider`) — desde que não crie um segundo request.
- Nomes de arquivo e classe do bloco reprodutivo extraído (`AnimalReproductiveHistorySection` é sugestão, simétrico ao sanitário).
- Como a busca por número exato passa por cima do toggle de arquivados (D-17): filtro na tela vs provider dedicado.
- Onde mora a ação de retry por bloco (botão inline vs `TextButton` abaixo da mensagem) — desde que invalide só o provider daquele bloco.
- Se os widget tests de 360px usam `TestWidgetsFlutterBinding` com `physicalSize` fixo ou `MediaQuery` override.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requisitos e escopo
- `.planning/REQUIREMENTS.md` §ANIM-03 — único requisito desta fase: "Usuário pode visualizar ficha consolidada do animal (dados, lote atual, histórico reprodutivo, histórico sanitário)"; §ANIM-05 (busca por número) é o caminho de entrada do SC-1
- `.planning/ROADMAP.md` §Phase 8 — goal e success criteria SC-1…SC-5; §Notes — "ANIM-03 foi deliberadamente adiado para a Phase 8 porque cruza reprodutivo (Phase 5) e sanitário (Phase 6). Fases anteriores entregam fichas parciais; a Phase 8 finaliza"
- `.planning/PROJECT.md` — Core Value ("O histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo por quem toma decisões operacionais"); "Relatórios e dashboards avançados — pós-MVP" em Out of Scope

### Código a estender (todos os alvos desta fase)
- `lib/features/animais/presentation/animal_detail_screen.dart` — a tela inteira: `AnimalInfoCard` (linha ~130, com `_KvRow` de label 120px e o chip de status a remover pelo D-15), `_ReproductiveHistorySection` (linha ~377, a extrair pelo D-11 e estender pelos D-08/D-09), `_canEdit` (linha ~116)
- `lib/features/reproducao/data/atf_model.dart` §`ReproductiveHistoryEntry` (linha 65) — hoje só `lastDgResult`/`lastDgDate`; ganha os DGs completos (D-10), touro e data de implantação (D-09)
- `lib/features/reproducao/data/atf_repository.dart` §`fetchReproductiveHistory` / `reproductiveHistoryByAnimalProvider` (linha ~405) — origem do embed de `dg_records`
- `lib/features/lotes/data/lote_repository.dart` §`loteByIdProvider` — onde entra o embed do piquete (D-01)
- `lib/features/animais/data/animal_repository.dart` §`fetchAnimalsByProperty` (linha ~70) — **precedente exato do embed PostgREST**: `lots!inner(name, paddock_id, paddocks!inner(id, name))`; e o `includeArchived: true` do provider (linha ~246) que explica o D-17
- `lib/features/sanitario/presentation/sanitary_history_section.dart` — `AnimalSanitaryHistorySection`: a forma que o bloco reprodutivo extraído deve espelhar (shell de card outlined, corte em 10, `_VerTodasButton`, mensagens de vazio e erro). **Só recebe o retry do D-04 — não mudar query nem apresentação** (contrato D-37 Phase 6)

### Contexto anterior (decisões que continuam valendo)
- `.planning/phases/06-sanitary-module-snapshot/06-CONTEXT.md` — **D-37 (contrato explícito com esta fase: bloco sanitário autônomo, reaproveitado sem tocar query nem apresentação)**, D-38 (índice GIN + containment, o que torna o lookup do SANI-05 viável para o SC-1), D-25 (formato da linha do histórico na ficha), D-11 (custo nulo nunca vira "R$ 0,00")
- `.planning/phases/05-reproductive-module-loteatf/05-CONTEXT.md` — D-13 (blocos de histórico read-only para todo papel — base do D-22), D-14 (formato do bloco reprodutivo na ficha), D-02 (rota root-level `/atf/:atfId`, destino do tap)
- `.planning/phases/03-lots-animals-operational-core/03-CONTEXT.md` — D-22 (ficha do animal e as seções placeholder), D-18 (filtros de `/animais`), D-21 (toggle "Mostrar arquivados", que o D-17 contorna na busca por número)
- `.planning/phases/07-expenses-by-paddock/07-CONTEXT.md` — D-36 (recorte de teste mais largo quando há regra nova) e D-19 (desempate de ordenação, lição do G-05-4)
- `.planning/STATE.md` §Blockers — nenhum bloqueio se aplica a esta fase (não há migration); §Phase 0 Completion Notes — **Riverpod 3.x, não 2.x**, e `integration_test` sem suporte web (base do D-07)

### Testes
- `test/widget/` — suíte de widget tests existente, base para o D-23
- Nenhuma suíte pgTAP nova ou alterada nesta fase (D-23)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **A ficha inteira já existe** — `AnimalInfoCard` + `_ReproductiveHistorySection` + `AnimalSanitaryHistorySection` já compõem `animal_detail_screen.dart`. Esta fase estende; não reescreve nem recria nenhum dos três.
- `fetchAnimalsByProperty`: embed PostgREST aninhado (`lots!inner(... paddocks!inner ...)`) já em produção — a técnica do D-01, pronta para copiar.
- `AnimalSanitaryHistorySection` (Phase 6, D-37): shell de card outlined, corte em 10 + "Ver todas", toggle "Mostrar estornadas", mensagens de vazio/erro — a forma que o bloco reprodutivo extraído deve espelhar.
- Rótulo legível do touro (Phase 5, plano 05-13 / WR-01): resolvido, reusar no D-09.
- Banner de ATF encerrado (Phase 5): precedente visual do banner de baixa (D-12).
- `kCategoryLabels` e o mapeamento de `baixaReason` → rótulo pt-BR já existentes em `animal_detail_screen.dart` (linhas ~169-174) — mover para o banner, não duplicar.

### Established Patterns
- Riverpod 3.x com auto-dispose por padrão; `FutureProvider.family` para dados por id; `ref.invalidate` para recarregar
- Repository nunca importa o SDK do Supabase direto — sempre via `SupabaseService`
- Blocos de histórico são read-only para todo papel (D-13 Phase 5); role gate na UI = controle **ausente**, não desabilitado
- Congelamento: tudo que o bloco sanitário mostra vem da linha imutável, nunca do modelo vivo (D-03/D-04 Phase 6) — o mesmo vale para a ficha do animal já movido ou arquivado
- pt-BR: `intl` para datas e moeda
- Navegação root-level para detalhes: tap no ATF → `/atf/:atfId`, tap na aplicação → `/aplicacoes/:id`

### Integration Points
- `animal_detail_screen.dart`: banner de baixa acima do card (D-12), remoção da linha Status (D-15), `_KvRow` adaptativo (D-21), composição dos dois blocos extraídos
- `lib/features/reproducao/presentation/` (novo arquivo): bloco reprodutivo público extraído (D-11), com expansão de DGs (D-08)
- `atf_repository.dart` + `atf_model.dart`: DGs completos, touro e data de implantação na mesma query (D-09/D-10)
- `lote_repository.dart`: embed do piquete para matar o waterfall (D-01)
- `sanitary_history_section.dart`: **só** o retry por bloco (D-04) — nada mais
- Busca de `/animais`: override do toggle de arquivados para número exato (D-17)
- **Zero arquivos em `supabase/`** — nenhuma migration, nenhuma suíte pgTAP

</code_context>

<specifics>
## Specific Ideas

- O valor desta fase não é código novo, é **fechar o core value**: "o histórico técnico do animal individual, acessível em campo por quem toma decisões operacionais". Tudo que foi decidido aqui é subordinado a isso — por isso blocos sempre abertos (D-19), sem cache que sirva dado velho (D-03), retry por bloco em vez de tela morta (D-04), e busca que acha o animal vendido (D-17).
- O SC-2 diz "todos LoteATFs (**com DGs**)" e o código entrega só o último DG por ATF. Foi apresentado que dava para argumentar que o resultado corrente já satisfaz — e a escolha foi cumprir o texto literal, com a expansão (D-08) para não pagar em poluição visual no caso comum de 1 DG.
- A ordem card → reprodutivo → sanitário foi mantida por um motivo concreto, não por inércia: o reprodutivo é curto e cabe sem rolar; o sanitário é longo e por isso vai por último.
- A assimetria de truncamento (D-06) foi mantida conscientemente, com a justificativa biológica: poucos ATFs por vida, dezenas de aplicações.
- Esta é a primeira fase do projeto **sem SQL**. Todo o padrão de fase anterior — migration via MCP, plano bloqueante dedicado, replay de pgTAP — não se aplica. O plan-checker não deve cobrar plano de migration nem suíte pgTAP.

</specifics>

<deferred>
## Deferred Ideas

- **Registrar DG ou aplicação sanitária a partir da ficha do animal** — recusado no D-22. Os dois fluxos são de lote; registrar por animal isolado é capacidade nova, com regra própria (um DG avulso pertence a qual ATF? uma aplicação avulsa gera que snapshot?).
- **Atalhos de navegação da ficha para os fluxos de DG e aplicação** — recusados junto com o D-22: levariam o vet da ficha de um animal para uma tela de 50.
- **Exportar / compartilhar a ficha** (PDF, print, link) — nenhum REQ pede; `PROJECT.md` marca relatórios como pós-MVP.
- **Pull-to-refresh** — recusado no D-05; vira útil se algum dia o app tiver escrita concorrente entre dispositivos.
- **`keepAlive` / cache dos providers da ficha** — recusado no D-03; reavaliar só se o UAT do D-07 mostrar tempo ruim ao navegar ficha → ATF → ficha.
- **RPC/view consolidada da ficha** — recusada no D-01. É a saída se o UAT com throttle 4G (D-07) mostrar que 4 requests paralelos não cabem em 1s.
- **Corte + "Ver todos" no histórico reprodutivo** — recusado no D-06; exigiria filtro por animal em `/reproducao`, que não existe.
- **Skeleton loading** — recusado no D-02 por ser padrão novo; se algum dia o app adotar skeleton, esta tela é candidata natural.
- **Ordenação dos blocos por recência** — recusada no D-18 por instabilidade visual entre animais.

</deferred>

---

*Phase: 08-animal-dossier-consolidation*
*Context gathered: 2026-08-11*
