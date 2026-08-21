# Phase 6: Sanitary Module (Snapshot) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-06
**Phase:** 6-sanitary-module-snapshot
**Areas discussed:** Forma do snapshot, Semântica da dose, Navegação, Aplicação errada, Concorrência no registro, Estratégia de teste, Contrato pra Phase 8, Erros e mensagens

---

## Forma do snapshot

### Como o snapshot fica gravado no banco?

| Option | Description | Selected |
|--------|-------------|----------|
| JSONB array | Mantém o skeleton da Phase 2; uma linha por aplicação, índice GIN para o lookup | ✓ |
| Tabela filha | Uma linha por animal + trigger de imutabilidade espelhado | |
| Híbrido | JSONB canônico + tabela filha indexada para lookup | |

**User's choice:** JSONB array
**Notes:** O usuário pediu a análise antes de escolher ("qual seria melhor e pq?"). Argumentos apresentados: imutabilidade com um mecanismo só (tabela filha exigiria trigger próprio + FORCE RLS, duas superfícies para errar); ativo já existe e já tem assertion em `02_property_paddock_test.sql`; escala não justifica normalizar; ausência de FK é feature num registro congelado. Custo aceito explicitamente: agregação futura precisa de `jsonb_to_recordset`, e relatórios são pós-MVP.

### O que vai dentro de cada objeto do array?

| Option | Description | Selected |
|--------|-------------|----------|
| Mínimo do SC-3 | `{animal_id, number, category, ua}`; custo derivável do cabeçalho | ✓ |
| Mínimo + custo por animal | Grava o custo calculado por animal (redundante) | |
| Mínimo + ficha do momento | Inclui raça e estado corporal | |

**User's choice:** Mínimo do SC-3

### Como a dose fica congelada na aplicação?

| Option | Description | Selected |
|--------|-------------|----------|
| FK + valores congelados | `dose_id` + nome e valores copiados no momento | ✓ |
| Só FK | Tela busca nome e valor atuais | |
| Só valores congelados | Sem FK, snapshot auto-contido | |

**User's choice:** FK + valores congelados

### Animal desmarcado entra no snapshot?

| Option | Description | Selected |
|--------|-------------|----------|
| Só os aplicados | Array com quem recebeu; desmarcados não aparecem em lugar nenhum | |
| Todos com flag applied | Lote inteiro com `applied: true/false` | |
| Aplicados + contagem no cabeçalho | Array só com aplicados + `skipped_count` | ✓ |

**User's choice:** Aplicados + contagem no cabeçalho
**Notes:** Preserva a informação de que N ficaram de fora sem criar a dependência de filtrar `applied=true` em todo lookup.

### Data da aplicação — campo próprio ou created_at?

| Option | Description | Selected |
|--------|-------------|----------|
| Coluna própria | `applied_at date`, default hoje, editável; created_at vira auditoria | ✓ |
| Só created_at | Uma coluna a menos | |

**User's choice:** Coluna própria

### Uma aplicação = uma dose, ou várias?

| Option | Description | Selected |
|--------|-------------|----------|
| Uma dose por aplicação | 3 produtos no mesmo dia = 3 registros | ✓ |
| Várias doses por aplicação | Um evento de manejo com N doses | |
| Uma dose + repetir composição | UI oferece repetir com outra dose | |

**User's choice:** Uma dose por aplicação
**Notes:** A conveniência de "repetir com outra dose" foi oferecida e não escolhida — registrada como ideia diferida.

### Vínculo com o lote no cabeçalho

| Option | Description | Selected |
|--------|-------------|----------|
| FK + nome congelado | `lot_id` + `lot_name` | ✓ |
| Só FK | Nome resolvido por JOIN | |
| FK + nome + piquete congelado | Também congela o piquete | |

**User's choice:** FK + nome congelado

### Totais — congelados ou derivados?

| Option | Description | Selected |
|--------|-------------|----------|
| Congelados no cabeçalho | `animal_count`, `total_ua`, `total_cost` | ✓ |
| Derivados do array | Calculados na leitura | |

**User's choice:** Congelados no cabeçalho

### Auditoria e observação

| Option | Description | Selected |
|--------|-------------|----------|
| applied_by + observação | `applied_by` via `auth.uid()` + `notes` livre | ✓ |
| Só applied_by | Sem campo livre | |
| Nenhum dos dois | Cabeçalho mínimo | |

**User's choice:** applied_by + observação

---

## Semântica da dose

### `valor por kg × 400` — custo ou dosagem?

| Option | Description | Selected |
|--------|-------------|----------|
| Custo em R$ | R$/kg de peso vivo | |
| Dosagem em mL | mL/kg de peso vivo | |
| Os dois campos | Dosagem e custo separados, ambos congelados e totalizados | ✓ |

**User's choice:** Os dois campos
**Notes:** A ambiguidade veio do próprio REQUIREMENTS.md ("valor por kg") cruzado com o "apenas custo/aplicação" do PROJECT.md.

### Os dois obrigatórios?

| Option | Description | Selected |
|--------|-------------|----------|
| Dosagem obrigatória, custo opcional | Custo nulo omite a linha de custo | ✓ |
| Os dois obrigatórios | Alimenta a Phase 7 direto | |
| Os dois opcionais | Só o nome obrigatório | |

**User's choice:** Dosagem obrigatória, custo opcional

### Onde mora o kg/UA?

| Option | Description | Selected |
|--------|-------------|----------|
| properties.kg_per_ua | Coluna na propriedade, default 400, sem UI nesta fase | ✓ |
| Constante única no código | Const em `animal_constants.dart` espelhada no RPC | |
| properties.kg_per_ua + tela na Fase 6 | Coluna + campo editável já nesta fase | |

**User's choice:** properties.kg_per_ua
**Notes:** **O usuário levantou a questão**, perguntando se o fator não deveria ficar num lugar que pudesse virar configuração por fazenda. Está correto: 1 UA = 450 kg é a convenção mais difundida na zootecnia brasileira, com 400 e 500 também em uso. Isso invalidou a recomendação inicial (coluna `GENERATED ALWAYS AS`), porque expressão de coluna gerada não pode ler outra tabela e trocar o fator exigiria DROP/recreate com recálculo retroativo. Solução: coluna na propriedade, dose guarda só os `*_por_kg`, por-UA derivado na leitura e congelado pelo RPC.

### Ciclo de vida da dose

| Option | Description | Selected |
|--------|-------------|----------|
| Property-scoped, editável, soft delete | Mesmo padrão das outras entidades | ✓ |
| Editável, sem remoção | Dose nunca sai da lista | |
| Imutável após primeira aplicação | Trava edição quando já usada | |

**User's choice:** Property-scoped, editável, soft delete

### Um campo de nome ou dois?

| Option | Description | Selected |
|--------|-------------|----------|
| Um campo de nome | Leitura literal do SC-1 | |
| Nome comercial + princípio ativo | Dois campos, princípio ativo opcional | ✓ |

**User's choice:** Nome comercial + princípio ativo

### Como a dosagem é expressa?

| Option | Description | Selected |
|--------|-------------|----------|
| Só mL/kg (escopo literal) | Fiel ao SANI-01; vacina de dose fixa fica de fora | ✓ |
| mL/kg + dose fixa por animal | `dosing_mode` cobrindo vacina | |
| Só mL/kg agora, dose fixa na Phase 8+ | Fecha o escopo e registra como diferida | |

**User's choice:** Só mL/kg (escopo literal)
**Notes:** Foi apresentado explicitamente que vacina (aftosa, brucelose, clostridiose) é dose fixa por cabeça e é a aplicação mais frequente numa fazenda, portanto o módulo não representa o caso mais comum. O usuário escolheu manter o escopo literal do SANI-01 mesmo assim. Registrado no `<deferred>` com o motivo.

---

## Navegação

### O que vive no branch /sanitario?

| Option | Description | Selected |
|--------|-------------|----------|
| Aplicações + doses em abas | Módulo inteiro na aba | ✓ |
| Só cadastro de doses | Histórico vive no lote e na ficha | |
| Só lista de aplicações | Doses em rota separada | |

**User's choice:** Aplicações + doses em abas

### De onde parte "Registrar aplicação"?

| Option | Description | Selected |
|--------|-------------|----------|
| Dos dois | FAB no /sanitario + botão no LoteDetailScreen | ✓ |
| Só do LoteDetailScreen | Uma superfície só | |
| Só do /sanitario | Fluxo centralizado com picker | |

**User's choice:** Dos dois

### Tela de detalhe da aplicação?

| Option | Description | Selected |
|--------|-------------|----------|
| Rota root-level /aplicacoes/:id | Mesmo padrão de /lotes/:loteId e /atf/:atfId | ✓ |
| Expansão inline | ExpansionTile nas três listas | |
| Dialog modal | Snapshot em dialog | |

**User's choice:** Rota root-level /aplicacoes/:id

### Histórico do lote (SANI-04) — onde?

| Option | Description | Selected |
|--------|-------------|----------|
| Seção abaixo da lista de animais | Mesma estrutura da ficha do animal | ✓ |
| Abas no LoteDetailScreen | TabBar Animais / Sanitário | |
| Só na lista global | Filtro por lote no /sanitario | |

**User's choice:** Seção abaixo da lista de animais

### Seleção de animais — dialog ou tela cheia?

| Option | Description | Selected |
|--------|-------------|----------|
| Tela cheia | Rota própria com contador vivo, padrão do AtfAnimalSelectionScreen | ✓ |
| Dialog | AlertDialog com lista rolável | |
| Formulário único em duas etapas | Uma tela com estado em duas etapas | |

**User's choice:** Tela cheia

### Histórico na ficha do animal (SANI-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Data + dose + lote da época | Nome do lote congelado; tap → /aplicacoes/:id | ✓ |
| Data + dose + lote + dosagem do animal | Acrescenta o volume recebido | |
| Data + dose apenas | Linha mínima | |

**User's choice:** Data + dose + lote da época

### Filtros da lista global

| Option | Description | Selected |
|--------|-------------|----------|
| Lote + dose + período | Mesmo idioma dos filtros de /animais | ✓ |
| Só ordenação por data | Lista simples | |
| Só período | Um controle só | |

**User's choice:** Lote + dose + período

### Animais elegíveis na seleção

| Option | Description | Selected |
|--------|-------------|----------|
| Só ativos, arquivados invisíveis | `deleted_at IS NULL`; RPC revalida | ✓ |
| Arquivados visíveis e desabilitados | Acinzentados com badge, padrão D-07 Phase 5 | |

**User's choice:** Só ativos, arquivados invisíveis
**Notes:** Fecha por construção o mesmo buraco do G-05-2 (Phase 5).

### Confirmação antes de gravar

| Option | Description | Selected |
|--------|-------------|----------|
| Dialog de resumo | Dose, data, nº animais, totais + aviso de permanência | ✓ |
| Botão direto + SnackBar com desfazer | Desfazer exigiria adiar o INSERT | |
| Botão direto, sem confirmação | Menos fricção no curral | |

**User's choice:** Dialog de resumo

### Pós-confirmação

| Option | Description | Selected |
|--------|-------------|----------|
| Volta pra origem + SnackBar | Padrão de todos os dialogs desde a Phase 4 | ✓ |
| Navega pro /aplicacoes/:id novo | Confirma visualmente o que foi congelado | |

**User's choice:** Volta pra origem + SnackBar

---

## Aplicação errada

### Vet registra no lote errado — o que acontece?

| Option | Description | Selected |
|--------|-------------|----------|
| Linha de estorno | Nova linha com `reverses_application_id`, também imutável | ✓ |
| Vive com o erro | Nenhum caminho de correção | |
| Tabela irmã de cancelamento | Cancelamento fora da tabela principal | |

**User's choice:** Linha de estorno
**Notes:** O trigger `trg_snapshot_immutable` barra UPDATE e DELETE, então nem um `cancelled_at` cabe sem enfraquecer a garantia que o SC-3 exige.

### Como a estornada aparece nas listas?

| Option | Description | Selected |
|--------|-------------|----------|
| Oculta + toggle | Escondida por padrão; toggle exibe riscada com badge | ✓ |
| Sempre visível riscada | Transparência máxima | |
| Oculta sem toggle | Só a linha de estorno aparece | |

**User's choice:** Oculta + toggle
**Notes:** Totais sempre excluem estornadas, independente da exibição.

### Quem estorna, com que restrição?

| Option | Description | Selected |
|--------|-------------|----------|
| Veterinário, sem prazo, motivo obrigatório | Motivo no `notes` da linha de estorno | ✓ |
| Veterinário, janela de 7 dias | Limita estorno tardio | |
| Veterinário, sem prazo, motivo opcional | Menos fricção | |

**User's choice:** Veterinário, sem prazo, motivo obrigatório

### O que a linha de estorno grava no snapshot?

| Option | Description | Selected |
|--------|-------------|----------|
| Cópia da composição original | Auto-contida, totais negativos, lookup por animal enxerga | ✓ |
| Array vazio | Só marcador apontando pra original | |
| Só os ids dos animais | Array reduzido | |

**User's choice:** Cópia da composição original

### O que impede estornar duas vezes?

| Option | Description | Selected |
|--------|-------------|----------|
| Índice parcial + checagem no RPC | Banco garante; RPC dá erro legível | ✓ |
| Só checagem no RPC | Suficiente sem write policy | |
| Só índice | Erro cru na tela | |

**User's choice:** Índice parcial + checagem no RPC
**Notes:** Confiar só no RPC foi exatamente a aposta desfeita nos gap cycles 04-06 e 04-07.

---

## Concorrência no registro

### Animal saiu do lote entre carregar e confirmar

| Option | Description | Selected |
|--------|-------------|----------|
| Revalida e recusa tudo | Aborta a transação com erro legível | ✓ |
| Revalida e ignora os inválidos | Grava só quem ainda está ativo | |
| Congela como estava na tela | Sem revalidação | |

**User's choice:** Revalida e recusa tudo
**Notes:** Mesma classe do TOCTOU que virou WR-01 na Phase 4.

### Como a tela reage à recusa?

| Option | Description | Selected |
|--------|-------------|----------|
| Recarrega mantendo as desmarcações | Vet não perde o trabalho | ✓ |
| Recarrega do zero | Volta ao default | |
| Só informa o erro | Sem recuperação | |

**User's choice:** Recarrega mantendo as desmarcações

### Aplicações duplicadas

| Option | Description | Selected |
|--------|-------------|----------|
| Aceita | Reforço e turnos divididos são legítimos | |
| Barra dose+lote+data idênticos | Índice único | |
| Avisa e deixa confirmar | Detecta idêntica recente e pede confirmação extra | ✓ |

**User's choice:** Avisa e deixa confirmar

### Gate do botão no lote

| Option | Description | Selected |
|--------|-------------|----------|
| Lote arquivado ou sem ativos + role | Mesmo gate do "Mover para piquete" | ✓ |
| Só role e lote ativo | Permite abrir com 0 animais | |

**User's choice:** Lote arquivado ou sem ativos + role

---

## Estratégia de teste

### Como provar as garantias de banco?

| Option | Description | Selected |
|--------|-------------|----------|
| pgTAP versionado + rodado via MCP | `06_sanitary_test.sql` no git, executado em transação revertida | ✓ |
| Só testes Dart | Sem pgTAP | |
| pgTAP + integração Dart contra o dev | Dois níveis | |

**User's choice:** pgTAP versionado + rodado via MCP
**Notes:** Docker indisponível (`docker info` e `supabase status` falham); a Phase 5 já validou o caminho MCP `execute_sql`.

### O que os testes Dart cobrem?

| Option | Description | Selected |
|--------|-------------|----------|
| Cálculo + fluxos de tela | Unit + widget, recorte que pegou G-05-2/G-05-3 | |
| Só cálculo | UA, volume, custo, filtro de estornadas, ordenação | ✓ |
| Cálculo + tela + repositório com fake | Acrescenta mapeamento do JSONB | |

**User's choice:** Só cálculo
**Notes:** Foi apresentado na própria opção que gate de papel e visibilidade de arquivado foram exatamente o que vazou pro UAT na Phase 5; o usuário escolheu o recorte menor mesmo assim.

### Onde o push e o pgTAP entram no ciclo?

| Option | Description | Selected |
|--------|-------------|----------|
| Plano bloqueante dedicado | Wave própria, como o 05-10 | ✓ |
| Junto da migration | Feedback mais cedo | |
| No final, junto do UAT | Um plano a menos | |

**User's choice:** Plano bloqueante dedicado

### Roda o `04_movements_test.sql` pendente?

| Option | Description | Selected |
|--------|-------------|----------|
| Roda junto no plano bloqueante | Conexão MCP já estará aberta | ✓ |
| Deixa como está | Dívida da Phase 4 | |

**User's choice:** Roda junto no plano bloqueante

---

## Contrato pra Phase 8

### O que esta fase entrega pra Phase 8?

| Option | Description | Selected |
|--------|-------------|----------|
| Provider reutilizável + seção própria | Provider ordenado + widget autônomo | ✓ |
| Só o provider | Phase 8 monta a apresentação | |
| Sem contrato explícito | Phase 8 resolve | |

**User's choice:** Provider reutilizável + seção própria

### Performance do lookup por animal

| Option | Description | Selected |
|--------|-------------|----------|
| Índice GIN agora, medir depois | `jsonb_path_ops` + containment | ✓ |
| Índice GIN + limite de linhas na ficha | Últimas N com "ver todas" | |
| Só o índice, sem decidir mais nada | Paginação fica pra Phase 8 | |

**User's choice:** Índice GIN agora, medir depois

---

## Erros e mensagens

### Como os erros do RPC chegam na tela?

| Option | Description | Selected |
|--------|-------------|----------|
| Uma exception da fase + ERRCODE por caso | `SanitaryApplicationException` com enum de motivo | ✓ |
| Exception tipada por caso | Uma classe por erro | |
| Exception genérica com mensagem do banco | Repassa o texto do RAISE | |

**User's choice:** Uma exception da fase + ERRCODE por caso

### Onde o erro aparece?

| Option | Description | Selected |
|--------|-------------|----------|
| Dentro do dialog de resumo | Botão reabilitado, recuperação ao lado da mensagem | ✓ |
| SnackBar | Padrão de feedback do resto do app | |

**User's choice:** Dentro do dialog de resumo

---

## Claude's Discretion

- Nomes exatos de tabelas e colunas (`doses`, `dosagem_por_kg`, `custo_por_kg`, `total_volume`)
- Estrutura interna do array JSONB (idioma das chaves, tipo de `ua`)
- Se os valores por UA da lista de doses vêm de view SQL, query calculada ou Dart
- Layout interno da tela de detalhe da aplicação (`data_table_2` vs ListView)
- Forma exata da detecção de "aplicação idêntica recente" (janela e onde a query roda)
- Se o estorno é RPC próprio ou parâmetro do RPC de registro
- Mecânica do toggle "Mostrar estornadas" (estado local vs provider compartilhado)
- Paginação/virtualização da tela de seleção e das listas

## Deferred Ideas

- Dose fixa por animal (mL por cabeça) para vacinas — apresentada e recusada; fora do texto do SANI-01
- Tela de configuração de `kg_per_ua` — a coluna nasce nesta fase, editá-la é capacidade de PROP-01
- UI "repetir esta aplicação com outra dose" — oferecida e não escolhida
- Congelar o piquete do lote na aplicação — útil pra Phase 7, nenhum REQ pede
- Agregações e relatórios sanitários — Out of Scope no PROJECT.md
- Ficha consolidada cruzando reprodutivo + sanitário — Phase 8 (ANIM-03)
- Paginação/virtualização para propriedades muito grandes — decidir com dados reais
- Controle de estoque de medicamentos — Out of Scope no PROJECT.md
