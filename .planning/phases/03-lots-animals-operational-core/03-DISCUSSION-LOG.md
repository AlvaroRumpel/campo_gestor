# Phase 3: Lots & Animals - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 03-lots-animals-operational-core
**Areas discussed:** Navegação de lotes, Escopo de numeração do animal, Formulário de criação do lote (batch), Tela /animais (busca e filtro)

---

## Navegação de Lotes

| Option | Description | Selected |
|--------|-------------|----------|
| Dentro de /piquetes/:id | Seção no PaddockDetailScreen, não tela separada | ✓ |
| Tela própria fora do shell | Similar a /propriedades | |
| No tab /animais (unificado) | Explorer hierárquico dentro do tab | |

**Layout PaddockDetailScreen:**

| Option | Description | Selected |
|--------|-------------|----------|
| Info no topo + lista de lotes abaixo | Header card + lista + FAB | ✓ |
| Tabs no PaddockDetailScreen | Tab "Info" + Tab "Lotes" | |

**Rota LoteDetailScreen:**

| Option | Description | Selected |
|--------|-------------|----------|
| /lotes/:loteId raiz | GoRoute root-level independente | ✓ |
| /piquetes/:paddockId/lotes/:loteId | Aninhada, URL expressa hierarquia | |

**LoteDetailScreen content:**

| Option | Description | Selected |
|--------|-------------|----------|
| Nome + lista de animais | Header com UA/categoria + lista de animais + FAB | ✓ |
| Apenas composição agregada | Só totais, sem lista individual | |

---

## Escopo de Numeração do Animal

**Escopo de unicidade:**

| Option | Description | Selected |
|--------|-------------|----------|
| Por propriedade (global) | #42 único na fazenda, inteiro simples | ✓ |
| Por (propriedade, categoria) | Vaca #1 e Novilha #1 coexistem | |

**Notes:** User confirmou: "o animal deve ser único por propriedade, então pode existir a vaca #42 na propriedade X e outra vaca #42 na propriedade Y".

**Formato de exibição:**

| Option | Description | Selected |
|--------|-------------|----------|
| Número inteiro simples | 42 | ✓ |
| Com prefixo de categoria | V-42 | |

**Reutilização após baixa — discussão extensa:**

User perguntou se números poderiam ser reutilizados após venda/morte. Após explicar que o histórico sanitário é IMUTÁVEL por trigger no banco (impossível deletar), e que o core value do produto é exatamente esse histórico, chegamos a:

| Option | Description | Selected |
|--------|-------------|----------|
| Override manual (B) | Auto MAX+1; override manual permite reutilizar número de animal arquivado | ✓ |
| Não reutilizável (A) | Sempre MAX+1 estritamente | |
| Reutilizável com deleção de histórico | Inviável por trigger de imutabilidade | |

**"Iniciar do número" no batch:**

| Option | Description | Selected |
|--------|-------------|----------|
| Campo opcional no form | Gera a partir do número, pulando ativos | ✓ |
| Não, só MAX+1 | Geração sempre automática | |

**Notes:** User sugeriu este campo para o caso de brincos físicos preexistentes. Também destacou que batch deve usar MAX global (não sequência cronológica) para evitar conflitos com overrides manuais.

---

## Formulário de Criação do Lote (Batch)

| Option | Description | Selected |
|--------|-------------|----------|
| 6 categorias sempre exibidas com contador | Uma linha por categoria, raça opcional | ✓ |
| Seleção dinâmica | Adicionar categorias sob demanda | |

**Validação:**

| Option | Description | Selected |
|--------|-------------|----------|
| Nome + ao menos 1 animal | Soma > 0 obrigatória | ✓ |
| Só nome obrigatório | Lote vazio permitido | |

**Editabilidade do lote:**

| Option | Description | Selected |
|--------|-------------|----------|
| Só nome editável | Piquete imutável, composição via baixa/mov | ✓ |
| Imutável | Só delete | |

**Criar animal avulso:**

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 3 | FAB no LoteDetailScreen | ✓ |
| Phase 4 somente via movimentação | Mais restritivo | |

**Raça:**

User pediu lista predefinida com search-select. Após apresentar lista de raças bovinas comuns no Brasil, user aprovou:
Nelore, Angus, Brahman, Gir, Guzerá, Tabapuã, Canchim, Brangus, Simental, Charolês, Limousin, Hereford, Girolando, Wagyu, Caracu, Sindi, Pé-duro/Curraleiro.

Armazenamento: constante hardcoded no Flutter (não tabela no banco).

**Raça no batch:**

| Option | Description | Selected |
|--------|-------------|----------|
| Batch permite raça por categoria (opcional) | Todos animais da categoria herdam a raça | ✓ |
| Só na edição individual | Raça vazia no batch | |

**EC display:**

| Option | Description | Selected |
|--------|-------------|----------|
| Chips/botões 1-5 | Toggle row, toque imediato | ✓ |
| Slider | Menos preciso em mobile | |

**Motivos de baixa:**

| Option | Description | Selected |
|--------|-------------|----------|
| Venda, Morte, Descarte | Enum: sale/death/discard | ✓ |
| Mais motivos | — | |

---

## Tela /animais (Busca e Filtro)

| Option | Description | Selected |
|--------|-------------|----------|
| Lista global com filtros | Todos animais + chips categoria + dropdowns lote/piquete | ✓ |
| Agrupado por lote | Hierarquizado, duplica LoteDetailScreen | |

**Busca:**

| Option | Description | Selected |
|--------|-------------|----------|
| Filtro em tempo real com debounce | Lista filtra ao digitar, debounce ≥300ms | ✓ |
| Busca dedicada com resultado único | Busca exata, navega direto | |

**Notes:** User especificou: "filtro em tempo real na lista, mas use um debouncer também".

**Item da lista:**

| Option | Description | Selected |
|--------|-------------|----------|
| Número + Categoria + Lote (sem raça) | Compacto, raça só na ficha | ✓ |
| Número + Categoria + Raça + Lote | Mais info, mais espaço | |

**Animais arquivados:**

| Option | Description | Selected |
|--------|-------------|----------|
| Ocultos por padrão, toggle "Mostrar arquivados" | Default limpo, badge de motivo | ✓ |
| Tela separada /animais/arquivados | Sub-rota dedicada | |

**Ficha do animal Phase 3:**

| Option | Description | Selected |
|--------|-------------|----------|
| Dados básicos + placeholders de histórico | Com seções "disponível em breve" | ✓ |
| Só dados básicos sem placeholders | Tela mais limpa | |

---

## Claude's Discretion

- Layout interno do LoteDetailScreen (cards vs list tiles para animais)
- Estratégia de paginação/virtualização na lista de /animais
- Estrutura exata do RPC de criação batch (atômico vs chamadas separadas)
- Animação/feedback visual durante geração batch

## Deferred Ideas

- Filtro por raça em ANIM-06 — diferir para quando volume justificar
- Histórico de baixas com dados comerciais — módulo contábil futuro
- Importação em planilha — fora do MVP
- MOV-01, MOV-02 — Phase 4
