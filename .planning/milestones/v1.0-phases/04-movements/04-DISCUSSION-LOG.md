# Phase 4: Movements - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-19
**Phase:** 04-movements
**Areas discussed:** Move animal — entry point e picker, Move lote — entry point e confirmação, Pós-move: navegação e feedback

---

## Move animal — entry point e picker

| Option | Description | Selected |
|--------|-------------|----------|
| AnimalDetailScreen — 3º botão | Ao lado de Editar e Dar baixa. Consistente com o padrão já estabelecido na ficha do animal. | ✓ |
| LoteDetailScreen — swipe/menu no item | Swipe left no animal dentro do LoteDetailScreen abre opções. | |
| Ambos | Duplica o ponto de entrada. | |

**User's choice:** AnimalDetailScreen — 3º botão

---

| Option | Description | Selected |
|--------|-------------|----------|
| Dialog com lista de todos os lotes ativos da propriedade | Simples, uma única scroll. Mostra nome e piquete pai. | |
| Dropdown dentro do dialog de confirmação | Um único dialog: dropdown no topo, botão confirmar. | |
| Seletor em 2 níveis: piquete primeiro, lote depois | Primeiro choose o piquete, depois o lote desse piquete. | |
| Dialog com lista de todos os lotes ativos da propriedade (chosen) | Com nome do lote + piquete + contagem de animais | ✓ |

**User's choice:** Dialog com lista, item = Nome do lote + piquete pai + contagem de animais ativos

---

| Option | Description | Selected |
|--------|-------------|----------|
| Nome do lote + piquete pai | Ex: 'Lote Bravo — Piquete Norte'. | |
| Nome do lote + piquete + contagem de animais | Ex: 'Lote Bravo — Piquete Norte (32 animais)'. | ✓ |
| Só nome do lote | Mais simples. | |

**User's choice:** Nome do lote + piquete + contagem de animais

---

| Option | Description | Selected |
|--------|-------------|----------|
| UPDATE direto no animals.lot_id com RLS | Simples: UPDATE animals SET lot_id = :target. RLS valida. | ✓ |
| RPC move_animal para garantir validações server-side | Função plpgsql com validações explícitas. | |

**User's choice:** UPDATE direto com RLS

---

| Option | Description | Selected |
|--------|-------------|----------|
| Não — botão Mover ausente se animal arquivado | Consistente com padrão do botão Baixa. | ✓ |
| Sim — mover arquivado é permitido | | |

**User's choice:** Não — botão ausente para arquivados

---

## Move lote — entry point e confirmação

| Option | Description | Selected |
|--------|-------------|----------|
| LoteDetailScreen — botão no header/card do lote | Role-gated veterinarian. Consistente com onde outros metadados vivem. | ✓ |
| LoteDetailScreen — overflow menu (3 pontos) | Menos visível. | |
| PaddockDetailScreen — swipe/menu no card do lote | Sem entrar no detalhe. | |

**User's choice:** LoteDetailScreen — botão no header/card do lote

---

| Option | Description | Selected |
|--------|-------------|----------|
| Picker de piquete destino + contagem de animais | Ex: 'Mover Lote Alpha para: [picker] \n 42 animais serão transferidos.' | ✓ |
| Só picker de piquete destino sem contagem | Mais simples. | |
| Lista completa dos animais + picker de piquete | Verbose para lotes grandes. | |

**User's choice:** Picker de piquete + contagem de animais que serão movidos

---

| Option | Description | Selected |
|--------|-------------|----------|
| RPC move_lot_to_paddock | Cumpre business rule "atômico via RPC" do REQUIREMENTS.md. | ✓ |
| UPDATE direto em lots.paddock_id com RLS | Tecnicamente atômico mas contradiz REQUIREMENTS.md. | |

**User's choice:** RPC move_lot_to_paddock

---

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — excluir piquete atual | Lista só mostra destinos válidos. | ✓ |
| Não — manter na lista, RPC rejeita se igual | | |

**User's choice:** Sim — excluir piquete atual do picker

---

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — mover lote independente da composição | | |
| Não — bloquear move se lote vazio | Botão Mover ausente/desabilitado se sem animais ativos. | ✓ |

**User's choice:** Não — bloquear move se lote sem animais ativos

---

| Option | Description | Selected |
|--------|-------------|----------|
| Não — botão Mover ausente para lote arquivado | Lote arquivado é histórico imutável. | ✓ |
| Sim — permitir mover arquivado | Sem caso de uso claro. | |

**User's choice:** Não — ausente para arquivados

---

## Pós-move: navegação e feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Fica na ficha, atualiza o lote exibido | SnackBar 'Animal movido para [Lote X]'. Provider invalidation. | ✓ |
| Navega de volta para o lote anterior | Pop da rota. | |
| Navega para o novo lote | context.go('/lotes/:novoLoteId'). | |

**User's choice:** Fica na AnimalDetailScreen, provider invalidation, SnackBar

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fica na tela, atualiza o piquete exibido no header | SnackBar 'Lote movido para [Piquete Y]'. Provider invalidation. | ✓ |
| Navega para o piquete destino | context.go('/piquetes/:novoPiqueteId'). | |
| Navega de volta para a tela anterior | Pop da rota. | |

**User's choice:** Fica na LoteDetailScreen, provider invalidation, SnackBar

---

## Claude's Discretion

- Layout exato do dialog de seleção de lote/piquete
- Se loteListByPropertyProvider usa JOIN ou query separada para count
- Estrutura interna do RPC move_lot_to_paddock (SECURITY DEFINER vs INVOKER)
- Animação/loading durante operação atômica

## Deferred Ideas

- Histórico de movimentações (auditoria) — pós-MVP
- Mover múltiplos animais selecionados — nova feature além do escopo
- Mover animal para outra propriedade — explicitamente fora do escopo
