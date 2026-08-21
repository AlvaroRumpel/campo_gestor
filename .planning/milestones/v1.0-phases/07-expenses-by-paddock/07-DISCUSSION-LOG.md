# Phase 7: Expenses by Paddock - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-11
**Phase:** 07-expenses-by-paddock
**Areas discussed:** Categorias de gasto, Onde o módulo mora, Período e totais, Correção e permissão, Gasto sem piquete, Cruzamento com sanitário, Anexo de comprovante, Estrutura de planos

---

## Categorias de gasto

### Como as categorias devem ser definidas?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Constante no Dart | Lista fechada em `expense_constants.dart`, padrão `kBreeds`/`BaixaReason`. Zero tela de cadastro, zero migration extra | ✓ |
| Tabela cadastrável | `expense_categories` property-scoped com RLS + soft delete, padrão `doses`. Cada fazenda define as suas | |
| Texto livre | Campo texto sem lista. 'Ração'/'ração'/'Racao' viram 3 categorias | |

**Notas:** Custo aceito — mudar a lista exige deploy do Flutter.

### Qual lista de categorias inicial?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| 8 categorias operacionais | Ração/Suplementação, Sanidade/Medicamentos, Mão de obra, Manutenção, Pastagem/Adubação, Combustível, Arrendamento, Outros | ✓ |
| 5 categorias enxutas | Ração, Sanidade, Mão de obra, Manutenção, Outros | |
| Você decide | Claude escolhe na pesquisa | |

### O banco deve validar a categoria?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Só Dart (padrão breed) | Coluna `text` sem CHECK, igual `animals.breed`. Mudança de lista = só deploy | ✓ |
| CHECK no banco (padrão baixa_reason) | `CHECK (category IN (...))`. Lixo impossível, mas cada mudança vira migration | |

### Quais campos são obrigatórios?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Descrição opcional | Piquete + categoria + valor + data obrigatórios; `description text NULL` | ✓ |
| Todos obrigatórios | `description NOT NULL` com trim > 0 | |
| Descrição e categoria opcionais | Só valor + data + piquete | |

### Identidade visual da categoria

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Só texto | Label pt-BR sem ícone nem cor, como o resto do app | |
| Ícone por categoria | Um `Icons.*` por categoria | ✓ |
| Ícone + cor | Ícone e cor de chip; 8 cores para light e dark | |

### Comportamento do dropdown

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Ordem fixa, sem default | Ordem da constante, campo vazio, obrigatório. Padrão `AnimalFormDialog` | ✓ |
| Ordem fixa, default na 1ª | Começa em 'Ração/Suplementação' | |
| Última usada no topo | Lembra a última categoria do piquete | |

### Filtro por categoria além do período

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Sim, filtro por categoria | Idioma de `/animais` e `/sanitario`; total respeita os dois filtros | ✓ |
| Não, só período | Escopo literal do GAST-02 | |

---

## Onde o módulo mora

### Onde vive a lista de gastos?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Tela dedicada root-level | `/gastos/:paddockId`, padrão já usado 3x. FAB livre pra 'Novo gasto' | ✓ |
| Seção no PaddockDetailScreen | Terceira seção abaixo de Lotes, padrão D-20 Phase 6 | |
| 6ª branch no shell | Aba 'Gastos' com filtro de piquete; aperta a bottom bar no mobile | |

### Entrada a partir do PaddockDetailScreen

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Card com total resumo | Total do mês corrente, tap abre a tela. Um `FutureProvider.family` a mais | ✓ |
| ListTile simples com chevron | Sem número, zero query extra | |
| Ação no AppBar | Ícone de carteira; padrão novo no app | |

### De onde se lança um gasto novo

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Só FAB em /gastos/:paddockId | Uma porta, piquete resolvido pela rota. 4 toques em campo | ✓ |
| FAB na tela + FAB no piquete | Um toque a menos; o FAB do piquete já é 'Novo lote' | |
| FAB na tela + entrada global | Padrão D-17 Phase 6; não existe tela global onde caberia | |

### Dialog ou tela cheia

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Dialog | Padrão unânime do app para formulário curto | ✓ |
| Tela cheia | Rota própria, deep-linkável; 4 campos não enchem uma tela | |

### Tap num gasto da lista

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Abre dialog de edição | Sem rota nova; o card já mostra os 4 campos | ✓ |
| Expande o card in-place | Estado de expansão por item; padrão novo | |
| Rota /gastos/item/:id | Não justificada para 4 campos linkados de 1 origem | |

### Empty state

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Empty state contextual | Distingue 'nunca teve' de 'filtro escondeu', com ação de limpar filtro | ✓ |
| Empty state único | Uma mensagem só; usuário conclui que perdeu lançamentos | |

### Cabeçalho da tela

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Nome do piquete no AppBar | 'Gastos — {piquete}' + botão voltar. Lição F-04-05 e G-05-1-nav | ✓ |
| Só 'Gastos' | Deep-link sem contexto | |

---

## Período e totais

### Intervalo default

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Mês corrente | Casa com o card de resumo do piquete; ciclo rural é mensal | ✓ |
| Últimos 12 meses | Total diverge do card; lista longa no celular | |
| Tudo (sem filtro) | Mesma divergência; lista cresce sem teto | |

### Como trocar o período

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Presets + intervalo custom | Chips + `showDateRangePicker`. Caso comum em 1 toque, zero dependência nova | ✓ |
| Só showDateRangePicker | 'Mês passado' vira 4 toques no calendário | |
| Dois campos de data soltos | Exige validação cruzada | |

### O que o total mostra

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Total em R$ + contagem | Escopo literal do GAST-02; contagem é de graça | ✓ |
| Total + custo por hectare | Usa `paddock.area_ha`; indicador listado como v2 | |
| Total + breakdown por categoria | Requisito v2 explícito no REQUIREMENTS.md | |

### Onde o total é somado

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| No cliente, sobre a lista | Uma query, função pura testável. Teto: paginação quebraria | ✓ |
| No servidor, query separada | RPC/view com `SUM`; duas queries que podem discordar | |

### Ordenação e agrupamento

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Data desc, sem agrupamento | Espelha o histórico sanitário; desempate por `created_at` (lição G-05-4) | ✓ |
| Agrupado por mês | Com default de mês corrente sempre haveria um grupo só | |
| Data desc + toggle por valor | Mais um controle num cabeçalho já cheio | |

### Entrada e exibição de moeda

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| TextField pt-BR + NumberFormat | Igual `DoseFormDialog`; coluna `numeric(14,2)` | ✓ |
| Máscara de moeda viva | Exigiria package novo ou formatter customizado | |

### Persistência do filtro

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Não — reseta pro default | Estado local, igual aos filtros de `/animais` e `/sanitario` | ✓ |
| Sim — durante a sessão | Filtro grudado explica mal a divergência com o card | |

---

## Correção e permissão

### Como corrigir um gasto errado

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Editar + soft delete | UPDATE nos 4 campos + `deleted_at`, com toggle 'Mostrar excluídos' | ✓ |
| Linha de estorno imutável | Padrão D-27 Phase 6; dobraria a fase para corrigir digitação | |
| Editar, sem excluir | Duplicidade viraria 'R$ 0,01 IGNORAR' na lista | |

### Quem escreve

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Só veterinário | Mesmo `_canEdit` de todo o app; uma regra só | |
| Veterinário + proprietário | Gasto é dado financeiro do dono. Primeiro gate divergente do projeto | ✓ |
| Só proprietário | Gate invertido em relação ao app inteiro | |

**Notas:** consequência registrada no CONTEXT.md — `_canEdit` não serve, e o `PaddockDetailScreen` passa a ter dois gates convivendo.

### Quem lê

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Sim — reader lê, não escreve | `SELECT` = `is_member_of`, igual às outras tabelas. Uma exceção de papel, não duas | ✓ |
| Não — gasto é fechado | Segunda divergência de padrão na mesma fase | |

### Caminho de escrita no banco

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Tabela direta + RLS policies | Precedente `DoseRepository`; `.select().single()` para no-op (lição G-06-2) | ✓ |
| RPC SECURITY DEFINER | Sem escrita multi-linha que a justifique | |

### Trigger de isolamento paddock_id ∈ property_id

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Sim — BEFORE INSERT/UPDATE | Espelha `trg_lots_paddock_same_property`; buraco que reabriu 2x na Phase 4 | ✓ |
| Não — só RLS + FK | 'property_id meu + paddock_id de outra propriedade' passaria | |

### Auditoria

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| created_by com default auth.uid() | Papel do `applied_by` da Phase 6 | |
| created_by + updated_by | Também registra quem editou, via trigger | ✓ |
| Nada além de created_at | Com dois papéis escrevendo, 'quem lançou' fica sem resposta | |

### Confirmação ao excluir

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| AlertDialog com valor e data | Mesma intenção do dialog de resumo da Phase 6 (D-23) | ✓ |
| Swipe + SnackBar 'Desfazer' | Swipe acidental é comum; padrão inexistente no app | |
| Sem confirmação | Recuperação exige saber que o toggle existe | |

### Recorte de testes

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| pgTAP + Dart cálculo e gate | Cobre o gate de dois papéis, regra nova sem precedente | ✓ |
| pgTAP + Dart só cálculo | Mesmo recorte da Phase 6 (D-40); gate cairia no UAT humano | |
| Só pgTAP | Soma e filtro ficariam sem verificação | |

### Plano bloqueante para push + pgTAP + UAT

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Sim — plano bloqueante dedicado | Padrão 05-10 / 06-12 | ✓ |
| Não — push junto da migration | Arranjo que deixou Phases 4 e 5 com migration não aplicada | |

---

## Gasto sem piquete

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| paddock_id NOT NULL — fora do escopo | Escopo literal do GAST-01; relaxar depois é migration de uma linha | ✓ |
| paddock_id NULL permitido | Exigiria tela global de gastos da propriedade — capacidade nova | |
| Rateio entre piquetes | Fase inteira sozinha | |

**Notas:** "Arrendamento" segue na lista de categorias — arrendamento de piquete específico existe.

---

## Cruzamento com sanitário

### O custo sanitário entra no total do piquete?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Não — só lançamento manual | Recomendada. Zero acoplamento; o vet lança em 'Sanidade/Medicamentos' | |
| Sim — somado ao total | Custo real sem lançamento duplicado. Exige congelar o piquete na aplicação | ✓ |
| Sim — exibido em separado | Mesmo problema de precisão histórica, mais uma query cross-módulo | |

**Notas:** escolhida contra a recomendação, com o custo apresentado (acoplamento + migration em tabela de outra fase). O usuário foi avisado de que isso quebra a propriedade "total = soma da lista" e as duas perguntas seguintes fecharam as consequências.

### Como atribuir uma aplicação a um piquete

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Congelar paddock na aplicação | `paddock_id` + `paddock_name` em `sanitary_applications`, preenchidos pelo RPC; backfill das 2 linhas de PROD | ✓ |
| Join por lots.paddock_id atual | Mover um lote reescreveria o custo passado dos dois piquetes | |
| Só aplicações novas | As 2 aplicações de UAT sumiriam da conta em silêncio | |

### A lista mostra as aplicações?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Sim — lista unificada, linha read-only | Restaura 'total = soma da tela'; 'Sanitário' vira pseudo-categoria no filtro | ✓ |
| Não — só uma linha no total | Total maior que a soma visível | |
| Voltar atrás: não somar sanitário | Desfaria a decisão anterior | |

### Aplicação estornada aparece?

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Não — nem a original nem o estorno | Aplica o D-29 da Phase 6 ('totais sempre excluem estornadas') | ✓ |
| Sim — as duas, riscadas | Duas linhas que se anulam no meio do mês | |

---

## Anexo de comprovante

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| Não — deferred consciente | Storage traria bucket, policies, upload web, limite de tamanho e ciclo de vida | ✓ |
| Sim — uma foto por gasto | Primeira integração com Storage do projeto | |

---

## Estrutura de planos

| Opção | Descrição | Escolhida |
|--------|-------------|----------|
| 4 planos, 3 waves | W1 migration ‖ dados Dart; W2 UI; W3 bloqueante (apply + pgTAP + UAT) | ✓ |
| 5 planos, 4 waves | Isola a migration do módulo sanitário num plano próprio | |
| Você decide | Planner define o recorte | |

---

## Claude's Discretion

- Aplicação sanitária com custo NULL na lista unificada — resolução recomendada registrada no CONTEXT.md ("—" no valor, contribui 0, conta na contagem), com instrução de justificar caso o planner divirja
- Nomes exatos de tabela e colunas
- Ícones por categoria e rótulos pt-BR finais
- Forma do modelo unificado da lista (sealed class vs view model plano)
- Provider do card de resumo: reuso vs próprio
- Onde mora o helper de gate `owner + veterinarian`
- Nomes dos presets de período; se "Ano" é ano civil ou últimos 12 meses
- Paginação/virtualização se a lista crescer

## Deferred Ideas

- Gasto de propriedade sem piquete (arrendamento da fazenda, salário, imposto)
- Rateio de gasto entre piquetes por ha ou por UA
- Anexo de comprovante via Supabase Storage
- Breakdown de gastos por categoria no piquete (v2)
- Custo por hectare e indicadores consolidados (v2)
- Tabela `expense_categories` cadastrável por propriedade
- CHECK constraint na categoria
- Ordenação por valor / agrupamento por mês
- Persistência do filtro entre visitas
- Agregação do total no servidor (RPC/view com SUM)
- RPC de escrita para gastos
- UI de configuração das categorias
