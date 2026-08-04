# Phase 5: Reproductive Module (LoteATF) - Context

**Gathered:** 2026-08-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Ciclo reprodutivo completo: criar LoteATF (REPR-01), selecionar animais elegíveis com validação de 1 ATF ativo por animal (REPR-02), registrar DG por animal (REPR-03), calcular e exibir % de prenhez (REPR-04), e exibir o histórico reprodutivo na ficha do animal (REPR-05).

Duas tabelas novas de domínio (`atf_batches`, `dg_records`) + ativação da tabela skeleton `animal_atf_memberships` criada na Phase 2 (hoje sem policies, sem `property_id`, sem FKs).

Phase 6 (sanitário) roda em paralelo e não toca nada disto. Phase 8 consolida a ficha do animal cruzando reprodutivo + sanitário — esta fase entrega só o bloco reprodutivo da ficha.

</domain>

<decisions>
## Implementation Decisions

### Navegação e escopo do ATF

- **D-01:** Lista de ATFs vive no branch `/reproducao` do AppShell (hoje placeholder vazio em `lib/features/reproducao/presentation/reproducao_screen.dart`). Escopo property-level — ATF não pertence a piquete nem a lote, animais de vários lotes podem entrar no mesmo ATF. FAB "Criar ATF" role-gated veterinário (controle ausente para leitor/proprietário, padrão estabelecido).
- **D-02:** Rota de detalhe `/atf/:atfId` **root-level** (GoRoute de nível superior, fora do branch), mesmo padrão de `/lotes/:loteId` (D-03 Phase 3). Necessário porque o histórico reprodutivo na ficha do animal (D-14) linka direto pro ATF. Adicionar constantes em `AppRoutes` + helper `atfDetail(id)`.
- **D-03:** Lista separa ativos de encerrados por **toggle "Mostrar encerrados"** (mesmo padrão de D-21 Phase 3 para animais arquivados), não por abas. Encerrados aparecem com badge de status e % prenhez final.
- **D-04:** Card do ATF na lista: nome + data de implantação + data de inseminação + nº de animais + % prenhez. Ex: `"ATF Primavera — impl. 12/09 · insem. 22/09 · 48 animais · 62% prenhez (31/50 DG)"`.
- **D-05:** Campo **touro** (REPR-01) é híbrido: FK opcional para `animals` (categoria `touro`) da propriedade **ou** texto livre quando o sêmen é externo. UI: search-select dos touros ativos da propriedade + opção "Outro / sêmen externo" que libera campo de texto. Schema: `bull_animal_id uuid NULL` + `bull_name text NULL` (pelo menos um preenchido).

### Seleção de animais no ATF

- **D-06:** Fluxo de seleção = **lote operacional inteiro + adicionar avulsos**. Vet escolhe um lote, o sistema traz todas as vacas e novilhas ativas dele pré-marcadas, ele desmarca o que não quer, e pode adicionar animais de outros lotes via busca/filtro (reaproveitar os filtros de `/animais`, D-18 Phase 3).
- **D-07:** Animal já em outro ATF ativo aparece na lista **desabilitado com motivo** — linha acinzentada `"#42 · Vaca — já em ATF Primavera"`. Não some da lista (SC-2 pede mensagem clara). Selecionável nunca; o partial unique index `animal_atf_memberships_active_idx` é a garantia final.
- **D-08:** Composição do ATF é **editável enquanto o lote está ativo**: botão "+ Animais" no detalhe e remoção individual. Remoção permitida enquanto o animal não tiver DG registrado naquele ATF; com DG, só via encerramento. Realidade de campo: animal entra atrasado ou sai do protocolo.
- **D-09:** Regra "apenas vacas e novilhas" (REPR-02) aplicada **na UI e no banco**. UI filtra a lista (vet nunca vê touro/terneiro); CHECK constraint ou trigger no banco rejeita categoria inválida na membership. Lição direta da Phase 4: a UI não é o último guarda — um PATCH cru no PostgREST contorna.

### Registro de DG

- **D-10:** DG é registrado em **lista em massa na tela de detalhe do ATF**: cada animal é uma linha com 3 chips toggle (Prenha / Não-prenha / Duvidosa), mesmo idioma visual dos chips de EC 1–5 (D-16 Phase 3). Vet passa o rebanho no curral marcando linha por linha e salva de uma vez.
- **D-11:** **Data do DG é uma só para a sessão** (campo no topo, default = hoje), aplicada a todos os animais marcados naquela leva, com possibilidade de sobrescrever num animal específico. Não usar `created_at` como data do DG — o vet lança no sistema depois da palpação.
- **D-12:** Um animal **pode ter múltiplos DGs no mesmo ATF** (duvidosa vira prenha no reexame 30 dias depois). Requer tabela `dg_records` própria em vez de colunas na membership. **O DG mais recente por animal é o que vale** para o % prenhez e para a exibição.
- **D-13:** DG **não é registrável a partir da ficha do animal** — a seção reprodutiva da ficha é somente leitura. DG é operação de curral em lote, não consulta individual. Menos superfície de escrita para proteger.

### Histórico reprodutivo na ficha (REPR-05)

- **D-14:** A seção placeholder "Histórico Reprodutivo" da `AnimalDetailScreen` (D-22 Phase 3) vira conteúdo real: lista de todos os ATFs em que o animal participou, cada linha com nome do ATF, data de inseminação, resultado do **último** DG com badge colorido, e status do ATF (ativo/encerrado). Ordenado por data decrescente. Tap navega para `/atf/:atfId` (justifica a rota root-level do D-02). A timeline completa de DGs de cada ciclo não é expandida aqui.

### Encerramento e % prenhez

- **D-15:** ATF encerra **manualmente**, via botão "Encerrar ATF" role-gated veterinário, **com alerta quando todos os animais já têm DG** (banner sugerindo encerrar). Resolve a decisão aberta #3 de `research/SUMMARY.md` exatamente como recomendado. Nunca automático — pode faltar reexame de duvidosa.
- **D-16:** Encerrar seta todas as memberships do ATF para `active = false`, o que solta os animais no partial unique index e os torna elegíveis para o próximo ciclo. Histórico preservado integralmente (a membership continua existindo, só inativa). O ATF encerrado **não** vira somente-leitura no banco — correção de digitação segue possível.
- **D-17:** `% prenhez = prenhas / total de DGs realizados × 100` (fórmula literal do REPR-04 e SC-4). **Duvidosa conta no denominador, não no numerador** — puxa o índice para baixo até o reexame resolver. Considera só o DG mais recente de cada animal (D-12).
- **D-18:** Exibição com DGs pendentes: **% parcial + progresso**, ex. `"62% prenhez (31/50 DG · 12 pendentes)"`. Atualiza conforme os DGs são registrados (SC-4 exige isso). Nunca esconder o % até o fechamento.

### Baixa de animal em ATF ativo

- **D-19:** Dar baixa (venda/morte/descarte) num animal que está em ATF ativo **seta a membership para `active = false` na mesma transação**, sem bloqueio e sem dialog extra. O animal some da lista de DGs pendentes, mas o ATF registra que ele participou. Vaca morre no meio do protocolo — o sistema não pode impedir de registrar isso.
- **D-20:** Animal com baixa **conta no denominador do % prenhez se já tinha DG registrado**. Se morreu antes do DG, não tem DG e simplesmente não entra na conta. Isso mantém o % de um ATF estável ao longo do tempo em vez de mudar retroativamente.

### Isolamento multi-tenant

- **D-21:** Padrão **Phase 4 completo**, sem economia:
  1. `property_id` em `atf_batches` (e derivável/validável nas tabelas filhas), RLS `ENABLE` + `FORCE ROW LEVEL SECURITY` em todas as tabelas do módulo;
  2. trigger `BEFORE INSERT OR UPDATE` garantindo que `animal_id` e `atf_batch_id` pertencem à mesma propriedade — espelhando `trg_animals_lot_same_property` (`20260716_04_animal_lot_property_trigger.sql`);
  3. escritas multi-linha (criar ATF com N animais, salvar N DGs de uma sessão, encerrar ATF) via **RPC SECURITY DEFINER**, atômicas.
  Motivo: RLS `WITH CHECK` não inspeciona FK de destino, e um veterinário membro de duas propriedades tem JWT válido para as duas — isso reabriu duas vezes no code review da Phase 4 (04-06, 04-07).

### Claude's Discretion

- Nomes exatos das tabelas e colunas (`atf_batches` / `dg_records` são sugestões).
- Se `dg_records` referencia a membership ou o par (atf_batch_id, animal_id) diretamente.
- Se o % prenhez é calculado em view/função SQL ou no cliente a partir dos DGs carregados.
- Layout interno do detalhe do ATF (ordem dos blocos header/composição/DG, uso de `data_table_2` vs ListView).
- Mecânica exata do alerta de "todos os DGs preenchidos" (banner, badge no botão, SnackBar).
- Estratégia de paginação/virtualização na lista de DG para ATFs grandes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements e escopo
- `.planning/REQUIREMENTS.md` §REPR-01…REPR-05 — 5 requisitos desta fase; business rules "LoteATF aceita apenas vacas e novilhas" e "Animal pode estar em no máximo 1 LoteATF ativo simultaneamente (partial unique index)"
- `.planning/ROADMAP.md` §Phase 5 — goal e success criteria SC-1…SC-5
- `.planning/PROJECT.md` — "Lote ATF como entidade separada" em Key Decisions; categorias e pesos UA
- `.planning/research/SUMMARY.md` — decisão aberta #3 (modo de encerramento do ATF), resolvida em D-15

### Schema existente
- `supabase/migrations/20260508_02_property_paddock.sql` §8 (linhas ~172-187) — skeleton `animal_atf_memberships` (id, animal_id, atf_batch_id, active, created_at), partial unique index `animal_atf_memberships_active_idx ON (animal_id) WHERE active = true`, RLS habilitada **sem policies** ("Phase 5 owns this table"). Esta fase precisa adicionar `property_id`, FKs e policies.
- `supabase/migrations/20260514_03_lots_animals.sql` — padrão de RPC SECURITY DEFINER com `is_member_of()` + `get_role()`, `RAISE EXCEPTION` com ERRCODE 42501; policies de `animals`/`lots`
- `supabase/migrations/20260716_04_animal_lot_property_trigger.sql` — `trg_animals_lot_same_property`, o trigger de isolamento a espelhar (D-21)
- `supabase/migrations/20260717_04_lot_paddock_property_trigger.sql` — mesmo padrão aplicado a `lots.paddock_id`
- `supabase/migrations/20260715_04_gap_move_animal_to_lot.sql` — RPC `move_animal_to_lot`, referência de RPC que valida propriedade de destino

### Padrões de código a replicar
- `lib/features/animais/data/animal_repository.dart` — padrão de repository, exception tipada, providers `FutureProvider.family`, chamada `.rpc()`
- `lib/features/lotes/data/lote_repository.dart` — `createLotWithAnimals` (RPC com params dict, criação pai+filhos atômica) — analog direto de "criar ATF com N animais"
- `lib/features/lotes/presentation/lote_form_dialog.dart` — dialog de criação com validação e `ref.invalidate` pós-sucesso
- `lib/features/animais/presentation/animal_detail_screen.dart` — seção placeholder "Histórico Reprodutivo" (linha ~102) a substituir por D-14; padrão `_canEdit` de role gate
- `lib/features/animais/presentation/baixa_dialog.dart` — fluxo de baixa a estender com o efeito colateral do D-19
- `lib/features/reproducao/presentation/reproducao_screen.dart` — placeholder a substituir pela lista de ATFs (D-01)
- `lib/core/router/routes.dart` + `lib/core/router/router.dart` — onde registrar `/atf/:atfId` root-level (D-02)

### Contexto anterior
- `.planning/phases/03-lots-animals-operational-core/03-CONTEXT.md` — D-03 (rota root-level), D-16 (chips EC), D-18 (filtros de /animais), D-21 (toggle arquivados), D-22 (ficha do animal e seções placeholder)
- `.planning/phases/04-movements/04-CONTEXT.md` — padrão de dialog de ação, invalidation de providers, e a lição de RPC + trigger no `<deferred>`
- `.planning/phases/04-movements/04-VERIFICATION.md` — verificação da fase anterior

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `animal_atf_memberships` já existe no banco com o partial unique index que implementa a regra "1 ATF ativo por animal" — não recriar, estender (adicionar `property_id`, FKs, policies, coluna de auditoria se preciso).
- `createLotWithAnimals` RPC (`lote_repository.dart`): padrão exato de "criar entidade pai + N filhos atomicamente" — reusar a forma para `create_atf_with_animals`.
- Chips de EC 1–5 (`animal_edit_dialog`): mesmo componente visual para os 3 chips de resultado de DG.
- Filtros e busca por número de `AnimaisScreen`: reusar para o passo "adicionar avulsos" (D-06).
- Toggle "Mostrar arquivados" de `AnimaisScreen`: mesmo padrão para "Mostrar encerrados" (D-03).
- `_canEdit` / role gate veterinário: mesmo guard para FAB de criar ATF, salvar DG e encerrar.

### Established Patterns
- Repository nunca importa o SDK do Supabase direto — sempre via `SupabaseService`
- Riverpod 3.x (não 2.x — ver notas da Phase 0), `FutureProvider` / `FutureProvider.family`, `ref.invalidate` pós-sucesso
- Soft delete `deleted_at timestamptz` + `.isFilter('deleted_at', null)`; ATF usa **`active` boolean** na membership (já no schema) além do soft delete do batch
- pt-BR: `intl` para datas, `FilteringTextInputFormatter` para decimais
- Escrita multi-linha ou cross-entity → RPC SECURITY DEFINER + trigger de isolamento (Phase 4)

### Integration Points
- `reproducao_screen.dart`: substituir placeholder pela lista de ATFs + FAB
- `router.dart` / `routes.dart`: nova rota root-level `/atf/:atfId`
- `animal_detail_screen.dart`: seção "Histórico Reprodutivo" deixa de ser placeholder
- `baixa_dialog.dart` / `AnimalRepository.baixa`: passa a desativar membership ATF ativa na mesma transação (D-19) — provavelmente move a baixa para um RPC se hoje for UPDATE direto
- Nova migration Phase 5: `atf_batches`, `dg_records`, extensão de `animal_atf_memberships`, policies, triggers de isolamento e categoria, RPCs

</code_context>

<specifics>
## Specific Ideas

- IATF na prática: o vet chega na fazenda, passa o rebanho no curral e faz DG de dezenas de vacas numa sessão só. Por isso a data única da sessão (D-11) e a lista em massa (D-10) — qualquer fluxo de 1 dialog por animal é inviável em campo.
- "Duvidosa" não é um resultado final, é um pendente disfarçado — daí o histórico de múltiplos DGs (D-12) e o fato de contar no denominador puxando o % pra baixo (D-17). O número só fica bonito quando o reexame confirma.
- O ATF frequentemente mistura animais de mais de um lote operacional (as vacas aptas estão espalhadas), por isso o "lote inteiro + avulsos" do D-06 em vez de amarrar o ATF a um lote.
- A tabela `animal_atf_memberships` foi criada na Phase 2 justamente como retirada de risco do partial unique index — o teste `supabase/tests/02_property_paddock_test.sql` já prova que 2 ATFs ativos para o mesmo animal são rejeitados pelo banco. Não refazer esse teste, estender.

</specifics>

<deferred>
## Deferred Ideas

- Ficha consolidada do animal cruzando reprodutivo + sanitário num único view — **Phase 8** (ANIM-03). Esta fase entrega só o bloco reprodutivo.
- Timeline expandida de todos os DGs de cada ciclo dentro da ficha do animal — considerada e descartada em D-14 (ficha ficaria longa demais); reconsiderar na Phase 8.
- Congelar ATF encerrado como somente-leitura no banco — descartado em D-16 para permitir correção de digitação. Se virar requisito de auditoria, é trigger novo.
- Métricas reprodutivas agregadas (taxa de prenhez por touro, por lote, por safra) — relatórios/dashboards estão em Out of Scope no PROJECT.md, pós-MVP.
- Protocolo hormonal / cronograma de manejo do IATF (D0, D8, D10…) — não está em nenhum REQ; seria módulo novo.
- Repasse com touro de monta natural após o ATF — fora dos 5 REQs desta fase.

</deferred>

---

*Phase: 05-reproductive-module-loteatf*
*Context gathered: 2026-08-04*
